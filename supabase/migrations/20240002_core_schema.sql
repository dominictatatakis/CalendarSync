-- ============================================================
-- Core schema for CalendarApp
-- Run this in Supabase SQL Editor (or via `supabase db push`)
-- ============================================================

-- ── Profiles ─────────────────────────────────────────────────
create table if not exists profiles (
    id           uuid primary key references auth.users(id) on delete cascade,
    email        text not null unique,
    display_name text not null default '',
    avatar_url   text,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "Users read own profile"
    on profiles for select using (auth.uid() = id);

create policy "Users update own profile"
    on profiles for update using (auth.uid() = id);

create policy "Users insert own profile"
    on profiles for insert with check (auth.uid() = id);

-- Allow users to find each other by phone (for friend search)
create policy "Users can search profiles by phone"
    on profiles for select using (true);

-- ── Friendships ───────────────────────────────────────────────
create table if not exists friendships (
    id           uuid primary key default gen_random_uuid(),
    requester_id uuid not null references profiles(id) on delete cascade,
    addressee_id uuid not null references profiles(id) on delete cascade,
    status       text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    unique (requester_id, addressee_id)
);

alter table friendships enable row level security;

create policy "Users see own friendships"
    on friendships for select
    using (auth.uid() = requester_id or auth.uid() = addressee_id);

create policy "Users create friend requests"
    on friendships for insert
    with check (auth.uid() = requester_id);

create policy "Addressee can update status"
    on friendships for update
    using (auth.uid() = addressee_id);

-- ── Groups ────────────────────────────────────────────────────
create table if not exists groups (
    id         uuid primary key default gen_random_uuid(),
    owner_id   uuid not null references profiles(id) on delete cascade,
    name       text not null,
    created_at timestamptz not null default now()
);

alter table groups enable row level security;

create policy "Owners manage their groups"
    on groups for all using (auth.uid() = owner_id);

-- ── Group Members ─────────────────────────────────────────────
create table if not exists group_members (
    group_id   uuid not null references groups(id) on delete cascade,
    user_id    uuid not null references profiles(id) on delete cascade,
    added_at   timestamptz not null default now(),
    primary key (group_id, user_id)
);

alter table group_members enable row level security;

create policy "Group owner manages members"
    on group_members for all
    using (
        exists (
            select 1 from groups
            where groups.id = group_members.group_id
            and groups.owner_id = auth.uid()
        )
    );

-- ── Event Shares (availability sharing) ──────────────────────
create table if not exists event_shares (
    id                 uuid primary key default gen_random_uuid(),
    owner_id           uuid not null references profiles(id) on delete cascade,
    event_id           text not null,
    source             text not null check (source in ('apple', 'google', 'outlook')),
    group_id           uuid not null references groups(id) on delete cascade,
    is_details_visible boolean not null default false,
    created_at         timestamptz not null default now(),
    unique (owner_id, event_id, group_id)
);

alter table event_shares enable row level security;

create policy "Owners manage their shares"
    on event_shares for all using (auth.uid() = owner_id);

create policy "Group members can read shares"
    on event_shares for select
    using (
        exists (
            select 1 from group_members
            where group_members.group_id = event_shares.group_id
            and group_members.user_id = auth.uid()
        )
    );

-- ── Availability Slots ────────────────────────────────────────
-- Denormalised busy-slot cache written by a server sync job.
-- Visibility is controlled by event_shares (group membership).
create table if not exists availability_slots (
    id         uuid primary key default gen_random_uuid(),
    owner_id   uuid not null references profiles(id) on delete cascade,
    start_date timestamptz not null,
    end_date   timestamptz not null,
    title      text,
    is_all_day boolean not null default false,
    created_at timestamptz not null default now()
);

alter table availability_slots enable row level security;

create policy "Owners manage own slots"
    on availability_slots for all using (auth.uid() = owner_id);

-- Friends who are in the same group as the owner can read slots
create policy "Friends in shared groups can read slots"
    on availability_slots for select
    using (
        exists (
            select 1
            from event_shares es
            join group_members gm on gm.group_id = es.group_id
            where es.owner_id = availability_slots.owner_id
            and gm.user_id = auth.uid()
        )
    );

-- ── Shared Events & Invites ───────────────────────────────────
create table if not exists shared_events (
    id             uuid primary key default gen_random_uuid(),
    organizer_id   uuid not null references profiles(id) on delete cascade,
    organizer_name text not null,
    title          text not null,
    start_date     timestamptz not null,
    end_date       timestamptz not null,
    location       text,
    notes          text,
    created_at     timestamptz not null default now()
);

alter table shared_events enable row level security;

create policy "Organisers manage their events"
    on shared_events for all using (auth.uid() = organizer_id);

create table if not exists event_invites (
    id             uuid primary key default gen_random_uuid(),
    event_id       uuid not null references shared_events(id) on delete cascade,
    invitee_id     uuid not null references profiles(id) on delete cascade,
    invitee_email  text,
    status         text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    unique (event_id, invitee_id)
);

alter table event_invites enable row level security;

create policy "Invitees see and update their invites"
    on event_invites for all using (auth.uid() = invitee_id);

create policy "Organisers see all invites for their events"
    on event_invites for select
    using (
        exists (
            select 1 from shared_events
            where shared_events.id = event_invites.event_id
            and shared_events.organizer_id = auth.uid()
        )
    );

-- ── Triggers: updated_at timestamps ──────────────────────────
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger profiles_updated_at
    before update on profiles
    for each row execute function set_updated_at();

create trigger friendships_updated_at
    before update on friendships
    for each row execute function set_updated_at();

create trigger event_invites_updated_at
    before update on event_invites
    for each row execute function set_updated_at();
