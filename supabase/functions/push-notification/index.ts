// Supabase Edge Function: push-notification
// Sends APNs push notifications when friend requests or event invites are created.
//
// Required secrets (set via `supabase secrets set`):
//   APNS_KEY_ID       — Apple Push Notification Key ID
//   APNS_TEAM_ID      — Apple Developer Team ID
//   APNS_PRIVATE_KEY  — Contents of the .p8 key file
//   APNS_BUNDLE_ID    — App bundle ID (com.dominictatakis.calendarapp)
//
// This function is called by database webhooks (pg_net) configured in the
// migration 20240005_push_notification_hooks.sql.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";

const APNS_HOST = "https://api.push.apple.com";
// Use sandbox during development:
// const APNS_HOST = "https://api.sandbox.push.apple.com";

interface PushPayload {
  type: "friend_request" | "event_invite";
  record: Record<string, unknown>;
}

serve(async (req) => {
  try {
    const payload: PushPayload = await req.json();
    const { type, record } = payload;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Determine the target user and notification content
    let targetUserId: string;
    let title: string;
    let body: string;
    let extraData: Record<string, string> = { type };

    if (type === "friend_request") {
      targetUserId = record.addressee_id as string;
      const { data: requester } = await supabase
        .from("profiles")
        .select("display_name")
        .eq("id", record.requester_id)
        .single();
      const name = requester?.display_name ?? "Someone";
      title = "New Friend Request";
      body = `${name} wants to connect with you`;
    } else if (type === "event_invite") {
      targetUserId = record.invitee_id as string;
      const { data: event } = await supabase
        .from("shared_events")
        .select("title, organizer_name")
        .eq("id", record.event_id)
        .single();
      const eventTitle = event?.title ?? "an event";
      const organizer = event?.organizer_name ?? "Someone";
      title = "New Event Invite";
      body = `${organizer} invited you to ${eventTitle}`;
      extraData.invite_id = record.id as string;
    } else {
      return new Response(JSON.stringify({ error: "Unknown type" }), { status: 400 });
    }

    // Fetch device tokens for the target user
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", targetUserId)
      .eq("platform", "ios");

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No device tokens found" }), { status: 200 });
    }

    // Build the APNs JWT
    const apnsJwt = await buildApnsJwt();

    // Send to each device token
    const results = await Promise.allSettled(
      tokens.map((t) => sendApnsPush(t.token, apnsJwt, title, body, extraData)),
    );

    const sent = results.filter((r) => r.status === "fulfilled").length;
    const failed = results.filter((r) => r.status === "rejected").length;

    return new Response(
      JSON.stringify({ sent, failed }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Push notification error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500 },
    );
  }
});

async function buildApnsJwt(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY")!;

  const privateKey = await jose.importPKCS8(privateKeyPem, "ES256");

  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(privateKey);

  return jwt;
}

async function sendApnsPush(
  deviceToken: string,
  jwt: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.dominictatakis.calendarapp";

  const apnsPayload = {
    aps: {
      alert: { title, body },
      sound: "default",
      badge: 1,
    },
    ...data,
  };

  const response = await fetch(
    `${APNS_HOST}/3/device/${deviceToken}`,
    {
      method: "POST",
      headers: {
        Authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(apnsPayload),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`APNs error ${response.status}: ${text}`);
  }
}
