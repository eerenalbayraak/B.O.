create table if not exists public.site_notes (
    id uuid primary key default gen_random_uuid(),
    author text not null check (char_length(btrim(author)) between 1 and 80),
    content text not null check (char_length(btrim(content)) between 1 and 1000),
    created_at timestamptz not null default now()
);

alter table public.site_notes enable row level security;

revoke all on public.site_notes from anon, authenticated;
grant insert on public.site_notes to anon, authenticated;
grant select on public.site_notes to authenticated;

drop policy if exists "Public can submit notes" on public.site_notes;
create policy "Public can submit notes"
    on public.site_notes
    for insert
    to anon, authenticated
    with check (
        char_length(btrim(author)) between 1 and 80
        and char_length(btrim(content)) between 1 and 1000
    );

drop policy if exists "Configured admin can read notes" on public.site_notes;
create policy "Configured admin can read notes"
    on public.site_notes
    for select
    to authenticated
    using ((auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com');

create table if not exists public.site_content (
    content_key text primary key check (content_key in ('gallery', 'favorites', 'music', 'inspiration_cards', 'site_texts')),
    content_value jsonb not null,
    updated_by uuid references auth.users(id) on delete set null,
    updated_at timestamptz not null default now()
);

alter table public.site_content enable row level security;
revoke all on public.site_content from anon, authenticated;
grant select on public.site_content to anon, authenticated;
grant insert, update, delete on public.site_content to authenticated;

drop policy if exists "Anyone can read published site content" on public.site_content;
create policy "Anyone can read published site content"
    on public.site_content
    for select
    to anon, authenticated
    using (true);

drop policy if exists "Configured admin can manage site content" on public.site_content;
create policy "Configured admin can manage site content"
    on public.site_content
    for all
    to authenticated
    using ((auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com')
    with check ((auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('site-content', 'site-content', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Anyone can view site content images" on storage.objects;
create policy "Anyone can view site content images"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id = 'site-content');

drop policy if exists "Configured admin can upload site content images" on storage.objects;
create policy "Configured admin can upload site content images"
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'site-content'
        and (auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com'
    );

drop policy if exists "Configured admin can update site content images" on storage.objects;
create policy "Configured admin can update site content images"
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'site-content'
        and (auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com'
    )
    with check (
        bucket_id = 'site-content'
        and (auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com'
    );

drop policy if exists "Configured admin can delete site content images" on storage.objects;
create policy "Configured admin can delete site content images"
    on storage.objects
    for delete
    to authenticated
    using (
        bucket_id = 'site-content'
        and (auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com'
    );

create table if not exists public.community_stories (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    author text not null check (char_length(btrim(author)) between 1 and 60),
    title text not null check (char_length(btrim(title)) between 1 and 100),
    content text not null check (char_length(btrim(content)) between 1 and 5000),
    created_at timestamptz not null default now()
);

alter table public.community_stories enable row level security;

revoke all on public.community_stories from anon, authenticated;
grant select on public.community_stories to anon, authenticated;
grant insert on public.community_stories to authenticated;

drop policy if exists "Anyone can read community stories" on public.community_stories;
create policy "Anyone can read community stories"
    on public.community_stories
    for select
    to anon, authenticated
    using (true);

drop policy if exists "Members can publish their own stories" on public.community_stories;
create policy "Members can publish their own stories"
    on public.community_stories
    for insert
    to authenticated
    with check (
        user_id = (select auth.uid())
        and char_length(btrim(author)) between 1 and 60
        and char_length(btrim(title)) between 1 and 100
        and char_length(btrim(content)) between 1 and 5000
    );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Members can view their profile photos" on storage.objects;
create policy "Members can view their profile photos"
    on storage.objects
    for select
    to authenticated
    using (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

drop policy if exists "Members can upload their profile photos" on storage.objects;
create policy "Members can upload their profile photos"
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

drop policy if exists "Members can update their profile photos" on storage.objects;
create policy "Members can update their profile photos"
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    )
    with check (
        bucket_id = 'profile-photos'
        and (storage.foldername(name))[1] = (select auth.uid())::text
    );

create table if not exists public.member_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
    bio text not null default '' check (char_length(bio) <= 300),
    avatar_url text not null default '',
    updated_at timestamptz not null default now()
);

alter table public.member_profiles enable row level security;
revoke all on public.member_profiles from anon, authenticated;
grant select, insert, update on public.member_profiles to authenticated;

drop policy if exists "Members can search public member profiles" on public.member_profiles;
create policy "Members can search public member profiles"
    on public.member_profiles
    for select
    to authenticated
    using (true);

drop policy if exists "Members can create their own profile" on public.member_profiles;
create policy "Members can create their own profile"
    on public.member_profiles
    for insert
    to authenticated
    with check (user_id = (select auth.uid()));

drop policy if exists "Members can update their own profile" on public.member_profiles;
create policy "Members can update their own profile"
    on public.member_profiles
    for update
    to authenticated
    using (user_id = (select auth.uid()))
    with check (user_id = (select auth.uid()));

create or replace function public.sync_member_profile_from_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.member_profiles (user_id, display_name, bio, avatar_url)
    values (
        new.id,
        left(coalesce(
            nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''),
            nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
            'Üye'
        ), 60),
        left(coalesce(new.raw_user_meta_data ->> 'bio', ''), 300),
        coalesce(new.raw_user_meta_data ->> 'avatar_url', '')
    )
    on conflict (user_id) do update
    set display_name = case
            when nullif(btrim(new.raw_user_meta_data ->> 'display_name'), '') is not null
                then excluded.display_name
            else member_profiles.display_name
        end,
        bio = case
            when new.raw_user_meta_data ? 'bio' then excluded.bio
            else member_profiles.bio
        end,
        avatar_url = case
            when new.raw_user_meta_data ? 'avatar_url' then excluded.avatar_url
            else member_profiles.avatar_url
        end,
        updated_at = now();
    return new;
end;
$$;

revoke all on function public.sync_member_profile_from_auth_user() from public, anon, authenticated;

drop trigger if exists sync_member_profile_from_auth_user on auth.users;
create trigger sync_member_profile_from_auth_user
    after insert or update of email, raw_user_meta_data on auth.users
    for each row execute function public.sync_member_profile_from_auth_user();

insert into public.member_profiles (user_id, display_name, bio, avatar_url)
select
    users.id,
    left(coalesce(
        nullif(btrim(users.raw_user_meta_data ->> 'display_name'), ''),
        nullif(split_part(coalesce(users.email, ''), '@', 1), ''),
        'Üye'
    ), 60),
    left(coalesce(users.raw_user_meta_data ->> 'bio', ''), 300),
    coalesce(users.raw_user_meta_data ->> 'avatar_url', '')
from auth.users as users
on conflict (user_id) do nothing;

create table if not exists public.friend_requests (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references auth.users(id) on delete cascade,
    recipient_id uuid not null references auth.users(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
    created_at timestamptz not null default now(),
    constraint friend_requests_distinct_members check (sender_id <> recipient_id)
);

create unique index if not exists friend_requests_one_pending_per_pair
    on public.friend_requests (least(sender_id, recipient_id), greatest(sender_id, recipient_id))
    where status = 'pending';

create unique index if not exists friend_requests_one_friendship_per_pair
    on public.friend_requests (least(sender_id, recipient_id), greatest(sender_id, recipient_id))
    where status = 'accepted';

create index if not exists friend_requests_sender_idx on public.friend_requests (sender_id, created_at desc);
create index if not exists friend_requests_recipient_idx on public.friend_requests (recipient_id, created_at desc);

alter table public.friend_requests enable row level security;
revoke all on public.friend_requests from anon, authenticated;
grant select, insert, delete on public.friend_requests to authenticated;
grant update (status) on public.friend_requests to authenticated;

drop policy if exists "Members can view their friend requests" on public.friend_requests;
create policy "Members can view their friend requests"
    on public.friend_requests
    for select
    to authenticated
    using (
        sender_id = (select auth.uid())
        or recipient_id = (select auth.uid())
    );

drop policy if exists "Members can send friend requests" on public.friend_requests;
create policy "Members can send friend requests"
    on public.friend_requests
    for insert
    to authenticated
    with check (
        sender_id = (select auth.uid())
        and recipient_id <> (select auth.uid())
        and exists (
            select 1
            from public.member_profiles profile
            where profile.user_id = recipient_id
        )
        and not exists (
            select 1
            from public.friend_requests existing
            where existing.status in ('pending', 'accepted')
              and (
                  (existing.sender_id = (select auth.uid()) and existing.recipient_id = friend_requests.recipient_id)
                  or (existing.sender_id = friend_requests.recipient_id and existing.recipient_id = (select auth.uid()))
              )
        )
    );

create or replace function public.find_member_by_email(p_email text)
returns table (user_id uuid, display_name text, avatar_url text)
language sql
stable
security definer
set search_path = ''
as $$
    select profile.user_id, profile.display_name, profile.avatar_url
    from auth.users as account
    join public.member_profiles as profile on profile.user_id = account.id
    where auth.uid() is not null
      and account.id <> auth.uid()
      and lower(btrim(account.email)) = lower(btrim(p_email))
    limit 1;
$$;

revoke all on function public.find_member_by_email(text) from public, anon;
grant execute on function public.find_member_by_email(text) to authenticated;

create or replace function public.send_friend_request_by_email(p_email text)
returns table (request_id uuid, recipient_id uuid, display_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_sender_id uuid := auth.uid();
    v_recipient_id uuid;
    v_display_name text;
    v_existing_status text;
    v_existing_sender uuid;
    v_request_id uuid;
begin
    if v_sender_id is null then
        raise exception using errcode = '42501', message = 'Arkadaşlık isteği göndermek için giriş yapmalısın.';
    end if;

    if nullif(btrim(p_email), '') is null then
        raise exception using errcode = '22023', message = 'Bir e-posta adresi yazmalısın.';
    end if;

    select account.id, profile.display_name
    into v_recipient_id, v_display_name
    from auth.users as account
    join public.member_profiles as profile on profile.user_id = account.id
    where account.id <> v_sender_id
      and lower(btrim(account.email)) = lower(btrim(p_email))
    limit 1;

    if not found then
        raise exception using errcode = '22023', message = 'Bu e-posta adresiyle kayıtlı başka bir üye bulunamadı.';
    end if;

    select request.status, request.sender_id
    into v_existing_status, v_existing_sender
    from public.friend_requests as request
    where request.status in ('pending', 'accepted')
      and (
          (request.sender_id = v_sender_id and request.recipient_id = v_recipient_id)
          or (request.sender_id = v_recipient_id and request.recipient_id = v_sender_id)
      )
    order by (request.status = 'accepted') desc, request.created_at desc
    limit 1;

    if found and v_existing_status = 'accepted' then
        raise exception using errcode = 'P0001', message = 'Bu kullanıcıyla zaten arkadaşsınız.';
    elsif found and v_existing_sender = v_sender_id then
        raise exception using errcode = 'P0001', message = 'Bu kullanıcıya bekleyen bir arkadaşlık isteğin zaten var.';
    elsif found then
        raise exception using errcode = 'P0001', message = 'Bu kullanıcıdan gelen bekleyen isteği arkadaşlar bölümünden kabul et.';
    end if;

    insert into public.friend_requests (sender_id, recipient_id)
    values (v_sender_id, v_recipient_id)
    returning id into v_request_id;

    return query select v_request_id, v_recipient_id, v_display_name;
exception
    when unique_violation then
        raise exception using errcode = 'P0001', message = 'Bu kullanıcıyla zaten bekleyen bir istek veya arkadaşlık var.';
end;
$$;

revoke all on function public.send_friend_request_by_email(text) from public, anon;
grant execute on function public.send_friend_request_by_email(text) to authenticated;

drop policy if exists "Recipients can respond to friend requests" on public.friend_requests;
create policy "Recipients can respond to friend requests"
    on public.friend_requests
    for update
    to authenticated
    using (
        recipient_id = (select auth.uid())
        and status = 'pending'
    )
    with check (
        recipient_id = (select auth.uid())
        and status in ('accepted', 'rejected')
    );

drop policy if exists "Members can remove their friendships" on public.friend_requests;
create policy "Members can remove their friendships"
    on public.friend_requests
    for delete
    to authenticated
    using (
        status = 'accepted'
        and (
            sender_id = (select auth.uid())
            or recipient_id = (select auth.uid())
        )
    );

create table if not exists public.private_messages (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references auth.users(id) on delete cascade,
    recipient_id uuid not null references auth.users(id) on delete cascade,
    content text not null check (char_length(btrim(content)) between 1 and 2000),
    created_at timestamptz not null default now(),
    read_at timestamptz,
    constraint private_messages_distinct_members check (sender_id <> recipient_id)
);

alter table public.private_messages
    add column if not exists read_at timestamptz;

create index if not exists private_messages_conversation_idx
    on public.private_messages (sender_id, recipient_id, created_at);
create index if not exists private_messages_recipient_idx
    on public.private_messages (recipient_id, sender_id, created_at);

alter table public.private_messages enable row level security;
revoke all on public.private_messages from anon, authenticated;
grant select, insert on public.private_messages to authenticated;
grant update (read_at) on public.private_messages to authenticated;

create or replace function public.is_configured_admin(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from auth.users as account
        where account.id = p_user_id
          and auth.uid() is not null
          and lower(account.email) = 'erenalbayrak_55@hotmail.com'
    );
$$;

revoke all on function public.is_configured_admin(uuid) from public, anon;
grant execute on function public.is_configured_admin(uuid) to authenticated;

drop policy if exists "Members can read their private messages" on public.private_messages;
create policy "Members can read their private messages"
    on public.private_messages
    for select
    to authenticated
    using (
        sender_id = (select auth.uid())
        or recipient_id = (select auth.uid())
    );

drop policy if exists "Friends can send private messages" on public.private_messages;
create policy "Friends can send private messages"
    on public.private_messages
    for insert
    to authenticated
    with check (
        sender_id = (select auth.uid())
        and recipient_id <> (select auth.uid())
        and char_length(btrim(content)) between 1 and 2000
        and (
            (auth.jwt() ->> 'email') = 'erenalbayrak_55@hotmail.com'
            or exists (
                select 1
                from public.friend_requests friendship
                where friendship.status = 'accepted'
                  and (
                      (friendship.sender_id = (select auth.uid())
                       and friendship.recipient_id = private_messages.recipient_id)
                      or (friendship.recipient_id = (select auth.uid())
                          and friendship.sender_id = private_messages.recipient_id)
                  )
            )
            or exists (
                select 1
                from public.private_messages admin_message
                where admin_message.sender_id = private_messages.recipient_id
                  and admin_message.recipient_id = (select auth.uid())
                  and public.is_configured_admin(admin_message.sender_id)
            )
        )
    );

drop policy if exists "Recipients can mark private messages as read" on public.private_messages;
create policy "Recipients can mark private messages as read"
    on public.private_messages
    for update
    to authenticated
    using (recipient_id = (select auth.uid()))
    with check (recipient_id = (select auth.uid()));

notify pgrst, 'reload schema';
