-- Fix: pg_net installs http_post in the `net` schema, not `extensions`,
-- so the original notify_push crashed every friendships/event_invites INSERT.
-- Also wrap in an exception handler so push delivery is best-effort and can
-- never abort the insert that triggered it.

create or replace function notify_push(notification_type text, payload jsonb)
returns void
language plpgsql
security definer
as $$
declare
    edge_url text;
    service_key text;
begin
    edge_url := current_setting('app.settings.edge_function_url', true);
    service_key := current_setting('app.settings.service_role_key', true);

    if edge_url is null or edge_url = '' then
        edge_url := concat(
            'https://',
            current_setting('app.settings.supabase_project_ref', true),
            '.supabase.co/functions/v1/push-notification'
        );
    end if;

    perform net.http_post(
        url := edge_url,
        body := jsonb_build_object(
            'type', notification_type,
            'record', payload
        )::jsonb,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', concat('Bearer ', service_key)
        )::jsonb
    );
exception when others then
    -- Push delivery is best-effort; never block the insert that triggered it.
    raise warning 'notify_push failed: %', sqlerrm;
end;
$$;
