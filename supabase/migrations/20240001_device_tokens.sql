-- Device tokens for push notifications
create table if not exists device_tokens (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    token       text not null,
    platform    text not null default 'ios',
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    unique (user_id, token)
);

-- Only the owning user can read/write their own tokens
alter table device_tokens enable row level security;

create policy "Users manage own tokens"
    on device_tokens for all
    using  (auth.uid()::text = user_id::text)
    with check (auth.uid()::text = user_id::text);

-- Supabase Edge Function: send-notification
-- Deploy at: supabase/functions/send-notification/index.ts
-- Triggered by: database webhook on friendships INSERT / event_invites INSERT
--
-- Required secrets (set via `supabase secrets set`):
--   APNS_KEY_ID       — 10-char key ID from Apple Developer
--   APNS_TEAM_ID      — 10-char Team ID from Apple Developer
--   APNS_PRIVATE_KEY  — contents of the .p8 file (AuthKey_KEYID.p8)
--   APNS_BUNDLE_ID    — com.dominictatakis.calendarapp
--
-- The function should:
--   1. Look up the target user's device_tokens
--   2. Build an APNs JWT (ES256, kid=APNS_KEY_ID, iss=APNS_TEAM_ID)
--   3. POST to https://api.sandbox.push.apple.com/3/device/{token}
--      with payload: { aps: { alert, badge, sound }, type, invite_id? }
