-- Security hardening based on Supabase advisor findings.

-- 1) get_availability: never trust the caller-supplied viewer_id — use auth.uid().
--    Signature kept for client compatibility; the viewer_id argument is ignored.
create or replace function get_availability(
    friend_id uuid,
    viewer_id uuid,
    range_start timestamptz,
    range_end   timestamptz
)
returns table (
    id         uuid,
    owner_id   uuid,
    start_date timestamptz,
    end_date   timestamptz,
    title      text,
    is_all_day boolean
)
language sql
stable
security definer
set search_path = public
as $$
    select
        a.id,
        a.owner_id,
        a.start_date,
        a.end_date,
        case when es.is_details_visible then a.title else null end as title,
        a.is_all_day
    from availability_slots a
    join event_shares es
        on es.owner_id = a.owner_id
    join group_members gm
        on gm.group_id = es.group_id
       and gm.user_id  = auth.uid()
    where a.owner_id = friend_id
      and a.start_date < range_end
      and a.end_date   > range_start
    group by a.id, a.owner_id, a.start_date, a.end_date, a.title, a.is_all_day,
             es.is_details_visible
    order by a.start_date;
$$;

-- 2) Lock down internal functions from the exposed RPC surface.
revoke execute on function get_availability(uuid, uuid, timestamptz, timestamptz) from anon;
revoke execute on function handle_new_user() from anon, authenticated, public;
revoke execute on function notify_push(text, jsonb) from anon, authenticated, public;
revoke execute on function on_friendship_insert() from anon, authenticated, public;
revoke execute on function on_event_invite_insert() from anon, authenticated, public;
revoke execute on function set_updated_at() from anon, authenticated, public;

-- 3) Pin search_path on remaining functions (advisor: function_search_path_mutable).
alter function set_updated_at() set search_path = public;
alter function handle_new_user() set search_path = public;
alter function on_friendship_insert() set search_path = public;
alter function on_event_invite_insert() set search_path = public;
alter function notify_push(text, jsonb) set search_path = public, net;

-- 4) Profiles: friend search requires sign-in; anonymous visitors can't scrape emails.
drop policy if exists "Users can search profiles by phone" on profiles;
create policy "Signed-in users can search profiles"
    on profiles for select
    to authenticated
    using (true);
