-- Auto-create a profile row whenever a new user signs up via phone OTP
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
    insert into public.profiles (id, email, display_name)
    values (
        new.id,
        coalesce(new.email, new.id::text),
        coalesce(new.raw_user_meta_data->>'display_name',
                 split_part(coalesce(new.email, ''), '@', 1))
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function handle_new_user();
