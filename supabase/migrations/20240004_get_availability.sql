-- RPC function: get_availability
-- Returns availability slots for a given friend that the current user
-- is allowed to see (i.e. they share at least one group via event_shares).

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
as $$
    select
        a.id,
        a.owner_id,
        a.start_date,
        a.end_date,
        -- Only reveal the title when the owner opted to share details
        case when es.is_details_visible then a.title else null end as title,
        a.is_all_day
    from availability_slots a
    join event_shares es
        on es.owner_id = a.owner_id
    join group_members gm
        on gm.group_id = es.group_id
       and gm.user_id  = viewer_id
    where a.owner_id = friend_id
      and a.start_date < range_end
      and a.end_date   > range_start
    group by a.id, a.owner_id, a.start_date, a.end_date, a.title, a.is_all_day,
             es.is_details_visible
    order by a.start_date;
$$;
