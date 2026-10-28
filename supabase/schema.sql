-- Run this in the Supabase SQL editor after creating a project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 90),
  type text not null check (type in ('lost','found')),
  category text not null check (category in ('Electronics','IDs & Cards','Keys','Bags & Backpacks','Clothing','Books & Stationery','Bottles & Accessories','Wallets & Personal Items','Other')),
  location text not null check (char_length(location) between 2 and 100),
  item_date date,
  description text not null check (char_length(description) between 20 and 700),
  image_path text,
  reporter text not null check (char_length(reporter) between 1 and 80),
  contact_preference text not null default 'CampusConnect messages' check (contact_preference in ('CampusConnect messages','Meet at a public campus desk')),
  status text not null default 'open' check (status in ('open','claim_pending','reunited')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists items_created_at_idx on public.items(created_at desc);
create index if not exists items_type_category_idx on public.items(type,category,status);
create index if not exists items_owner_idx on public.items(owner_id);

create table if not exists public.claims (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  claimant_id uuid not null references auth.users(id) on delete cascade,
  claimant_name text not null check (char_length(claimant_name) between 1 and 80),
  explanation text not null check (char_length(explanation) between 12 and 1000),
  distinguishing_details text not null check (char_length(distinguishing_details) between 8 and 1000),
  message text not null default '' check (char_length(message) <= 1000),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists claims_item_idx on public.claims(item_id,created_at desc);
create index if not exists claims_claimant_idx on public.claims(claimant_id,created_at desc);
create unique index if not exists one_pending_claim_per_person on public.claims(item_id,claimant_id) where status='pending';

create table if not exists public.listing_reports (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (char_length(reason) between 4 and 120),
  created_at timestamptz not null default now(),
  unique(item_id,reporter_id)
);
create index if not exists listing_reports_created_idx on public.listing_reports(created_at desc);

alter table public.profiles enable row level security;
alter table public.items enable row level security;
alter table public.claims enable row level security;
alter table public.listing_reports enable row level security;

create policy "profiles are readable by their owner" on public.profiles for select to authenticated using (id=auth.uid());
create policy "users create their own profile" on public.profiles for insert to authenticated with check (id=auth.uid());
create policy "users update their own profile" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());

create policy "community can read public item listings" on public.items for select to anon,authenticated using (true);
create policy "signed-in users create their own listings" on public.items for insert to authenticated with check (owner_id=auth.uid());
create policy "owners update their own listings" on public.items for update to authenticated using (owner_id=auth.uid()) with check (owner_id=auth.uid());
create policy "owners delete their own listings" on public.items for delete to authenticated using (owner_id=auth.uid());

create or replace function public.guard_item_status_transition() returns trigger language plpgsql as $$
begin
  if old.status='reunited' and new.status<>'reunited' then
    raise exception 'A reunited listing cannot be reopened';
  end if;
  if old.status='claim_pending' and new.status not in ('claim_pending','reunited') then
    raise exception 'An item with an approved claim cannot be reopened';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists item_status_transition_guard on public.items;
create trigger item_status_transition_guard before update on public.items for each row execute function public.guard_item_status_transition();

create policy "claimant and item owner can read a claim" on public.claims for select to authenticated using (claimant_id=auth.uid() or exists(select 1 from public.items i where i.id=item_id and i.owner_id=auth.uid()));
create policy "signed-in users create claims for others items" on public.claims for insert to authenticated with check (claimant_id=auth.uid() and exists(select 1 from public.items i where i.id=item_id and i.owner_id<>auth.uid() and i.status='open'));
create policy "listing owners review pending claims" on public.claims for update to authenticated using (status='pending' and exists(select 1 from public.items i where i.id=item_id and i.owner_id=auth.uid())) with check (status in ('approved','rejected') and exists(select 1 from public.items i where i.id=item_id and i.owner_id=auth.uid()));

-- A reviewer may change only the decision; claimant-supplied private fields stay immutable.
create or replace function public.guard_claim_review() returns trigger language plpgsql as $$
begin
  if old.status <> 'pending' or new.status not in ('approved','rejected')
     or new.item_id <> old.item_id or new.claimant_id <> old.claimant_id
     or new.claimant_name <> old.claimant_name or new.explanation <> old.explanation
     or new.distinguishing_details <> old.distinguishing_details or new.message <> old.message
     or new.created_at <> old.created_at then
    raise exception 'Only a pending claim decision may be updated';
  end if;
  if new.status='approved' then
    perform 1 from public.items i where i.id=old.item_id and i.status='open' for update;
    if not found then
      raise exception 'Another claim has already been approved for this item';
    end if;
  end if;
  new.reviewed_at := now();
  return new;
end;
$$;
drop trigger if exists claim_review_guard on public.claims;
create trigger claim_review_guard before update on public.claims for each row execute function public.guard_claim_review();

create or replace function public.mark_item_claim_pending() returns trigger language plpgsql as $$
begin
  if new.status='approved' and old.status='pending' then
    update public.items set status='claim_pending',updated_at=now() where id=new.item_id and status='open';
  end if;
  return new;
end;
$$;
drop trigger if exists claim_approval_updates_item on public.claims;
create trigger claim_approval_updates_item after update on public.claims for each row execute function public.mark_item_claim_pending();

create policy "users submit a report as themselves" on public.listing_reports for insert to authenticated with check (reporter_id=auth.uid() and exists(select 1 from public.items i where i.id=item_id));
create policy "reporters can see their own reports" on public.listing_reports for select to authenticated using (reporter_id=auth.uid());

-- Private bucket: images get short-lived signed URLs. Only images referenced by a public listing
-- can be read; uploads and deletes are scoped to the owner's first path segment (their auth UUID).
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('item-photos','item-photos',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=array['image/jpeg','image/png','image/webp'];

create policy "listing photos are readable when attached to a public item" on storage.objects for select to anon,authenticated using (
  bucket_id='item-photos' and exists(select 1 from public.items i where i.image_path=name)
);
create policy "users upload photos under their own folder" on storage.objects for insert to authenticated with check (
  bucket_id='item-photos' and (storage.foldername(name))[1]=auth.uid()::text
);
create policy "users delete photos under their own folder" on storage.objects for delete to authenticated using (
  bucket_id='item-photos' and (storage.foldername(name))[1]=auth.uid()::text
);
