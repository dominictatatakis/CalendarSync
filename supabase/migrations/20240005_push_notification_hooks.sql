-- Database webhooks to trigger push notifications via the Edge Function.
-- Requires the pg_net extension (enabled by default on Supabase).

create extension if not exists pg_net with schema extensions;

-- Helper: invoke the push-notification Edge Function
create or replace function notify_push(notification_type text, payload jsonb)
returns void
language plpgsql
security definer
as $$
declare
    edge_url text;
    service_key text;
begin
    -- These are automatically available in Supabase Edge Function invocations
    edge_url := current_setting('app.settings.edge_function_url', true);
    service_key := current_setting('app.settings.service_role_key', true);

    -- Fallback: construct the URL from the Supabase project ref
    if edge_url is null or edge_url = '' then
        edge_url := concat(
            'https://',
            current_setting('app.settings.supabase_project_ref', true),
            '.supabase.co/functions/v1/push-notification'
        );
    end if;

    perform extensions.http_post(
        url := edge_url,
        body := jsonb_build_object(
            'type', notification_type,
            'record', payload
        )::text,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', concat('Bearer ', service_key)
        )::text
    );
end;
$$;

-- Trigger: new friend request -> push notification
create or replace function on_friendship_insert()
returns trigger
language plpgsql
security definer
as $$
begin
    if new.status = 'pending' then
        perform notify_push('friend_request', to_jsonb(new));
    end if;
    return new;
end;
$$;

create trigger friendship_push_notification
    after insert on friendships
    for each row
    execute function on_friendship_insert();

-- Trigger: new event invite -> push notification
create or replace function on_event_invite_insert()
returns trigger
language plpgsql
security definer
as $$
begin
    perform notify_push('event_invite', to_jsonb(new));
    return new;
end;
$$;

create trigger event_invite_push_notification
    after insert on event_invites
    for each row
    execute function on_event_invite_insert();
