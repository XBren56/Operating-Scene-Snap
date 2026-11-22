-- Scene Snap shared data model (Supabase/PostgreSQL starter).
-- Apply only after creating a Supabase project and reviewing RLS policies.
create extension if not exists pgcrypto;
create extension if not exists citext;

create type public.scene_role as enum ('customer','event_assistant','designer','operations_manager','ceo');
create type public.event_status as enum ('inquiry','quoted','approved','booked','in_progress','completed','cancelled');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  phone text,
  created_at timestamptz not null default now()
);

-- Explicit invitations/approval. Never infer staff access from an email suffix alone.
create table public.staff_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  work_email citext not null unique,
  role public.scene_role not null check (role <> 'customer'),
  active boolean not null default true,
  invited_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  description text not null default '',
  base_price numeric(10,2) not null check (base_price >= 0),
  active boolean not null default true,
  seasonal_start date,
  seasonal_end date,
  created_at timestamptz not null default now()
);

create table public.design_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  description text not null default '',
  preview_path text,
  options jsonb not null default '{}'::jsonb,
  base_price numeric(10,2) not null default 0 check (base_price >= 0),
  is_published boolean not null default false,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id),
  title text not null,
  event_type text not null,
  event_date date not null,
  venue text,
  guest_count integer check (guest_count is null or guest_count >= 0),
  budget numeric(10,2) check (budget is null or budget >= 0),
  status public.event_status not null default 'inquiry',
  customer_notes text not null default '',
  staff_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.event_services (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  service_name text not null,
  planned_minutes integer not null default 0 check (planned_minutes >= 0),
  labor_cost numeric(10,2) not null default 0 check (labor_cost >= 0),
  travel_minutes integer not null default 0 check (travel_minutes >= 0),
  price numeric(10,2) not null default 0 check (price >= 0),
  details text not null default ''
);

create table public.event_designs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  template_id uuid references public.design_templates(id) on delete set null,
  customer_id uuid not null references auth.users(id),
  design_data jsonb not null default '{}'::jsonb,
  proof_path text,
  approval_status text not null default 'draft' check (approval_status in ('draft','submitted','changes_requested','approved')),
  created_at timestamptz not null default now()
);

create table public.event_assignments (
  event_id uuid not null references public.events(id) on delete cascade,
  staff_user_id uuid not null references public.staff_members(user_id),
  task text not null,
  starts_at timestamptz,
  ends_at timestamptz,
  status text not null default 'assigned' check (status in ('assigned','accepted','completed','cancelled')),
  primary key (event_id, staff_user_id, task)
);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  contact_name text,
  email text,
  phone text,
  website text,
  notes text not null default '',
  active boolean not null default true
);

create table public.sourcing_items (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete set null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  item_name text not null,
  quantity numeric(10,2) not null default 1 check (quantity > 0),
  expected_cost numeric(10,2) not null default 0 check (expected_cost >= 0),
  actual_cost numeric(10,2) check (actual_cost is null or actual_cost >= 0),
  status text not null default 'to_order' check (status in ('to_order','ordered','awaiting_delivery','received','reserved','returned','cancelled')),
  due_at timestamptz,
  notes text not null default ''
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  quantity_on_hand numeric(10,2) not null default 0 check (quantity_on_hand >= 0),
  reorder_at numeric(10,2) not null default 0 check (reorder_at >= 0),
  unit text not null default 'each',
  replacement_cost numeric(10,2) not null default 0 check (replacement_cost >= 0),
  storage_location text,
  updated_at timestamptz not null default now()
);

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  version integer not null default 1 check (version > 0),
  subtotal numeric(10,2) not null default 0 check (subtotal >= 0),
  tax numeric(10,2) not null default 0 check (tax >= 0),
  deposit numeric(10,2) not null default 0 check (deposit >= 0),
  status text not null default 'draft' check (status in ('draft','sent','accepted','declined','expired')),
  expires_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(event_id, version)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete set null,
  kind text not null check (kind in ('income','expense','refund')),
  amount numeric(10,2) not null check (amount >= 0),
  category text not null,
  memo text not null default '',
  occurred_on date not null default current_date,
  external_payment_ref text,
  recorded_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.business_records (
  id uuid primary key default gen_random_uuid(),
  record_type text not null check (record_type in ('plan','goal','policy','license','insurance','tax','pricing','marketing','season_plan','meeting','other')),
  title text not null,
  content jsonb not null default '{}'::jsonb,
  storage_path text,
  visibility text not null default 'ceo' check (visibility in ('ceo','manager','staff')),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  table_name text not null,
  record_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.current_scene_role()
returns public.scene_role language sql stable security definer set search_path = '' as $$
  select coalesce((select sm.role from public.staff_members sm
    join auth.users u on u.id = sm.user_id
    where sm.user_id = (select auth.uid()) and sm.active and sm.approved_at is not null
      and u.email_confirmed_at is not null and lower(u.email) = lower(sm.work_email)), 'customer'::public.scene_role)
$$;

create or replace function public.is_scene_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.current_scene_role() <> 'customer'::public.scene_role
$$;

create or replace function public.is_scene_ceo()
returns boolean language sql stable security definer set search_path = '' as $$
  select public.current_scene_role() = 'ceo'::public.scene_role
$$;

-- Enable RLS everywhere. Public storefront reads only active published catalog rows.
alter table public.profiles enable row level security;
alter table public.staff_members enable row level security;
alter table public.products enable row level security;
alter table public.design_templates enable row level security;
alter table public.events enable row level security;
alter table public.event_services enable row level security;
alter table public.event_designs enable row level security;
alter table public.event_assignments enable row level security;
alter table public.suppliers enable row level security;
alter table public.sourcing_items enable row level security;
alter table public.inventory_items enable row level security;
alter table public.quotes enable row level security;
alter table public.transactions enable row level security;
alter table public.business_records enable row level security;
alter table public.audit_log enable row level security;

create policy "profile owner or authorized staff read" on public.profiles for select to authenticated using (
  id = (select auth.uid()) or public.is_scene_ceo() or public.current_scene_role() = 'operations_manager'::public.scene_role
  or exists(select 1 from public.event_assignments a where a.staff_user_id=(select auth.uid())
    and exists(select 1 from public.events e where e.id=a.event_id and e.customer_id=profiles.id))
);
create policy "profile owner insert" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "profile owner update" on public.profiles for update to authenticated using (id = (select auth.uid()) or public.is_scene_ceo()) with check (id = (select auth.uid()) or public.is_scene_ceo());

create policy "staff records owner only" on public.staff_members for select to authenticated using (public.is_scene_ceo());
create policy "staff inserts owner only" on public.staff_members for insert to authenticated with check (public.is_scene_ceo());
create policy "staff updates owner only" on public.staff_members for update to authenticated using (public.is_scene_ceo()) with check (public.is_scene_ceo());
create policy "staff deletes owner only" on public.staff_members for delete to authenticated using (public.is_scene_ceo());

create policy "active products public read" on public.products for select to anon, authenticated using (active or public.is_scene_staff());
create policy "catalog changes staff" on public.products for all to authenticated using (public.is_scene_staff()) with check (public.is_scene_staff());
create policy "published templates read" on public.design_templates for select to anon, authenticated using (is_published or public.is_scene_staff());
create policy "template edits staff" on public.design_templates for all to authenticated using (public.is_scene_staff()) with check (public.is_scene_staff());

create policy "customer or assigned staff sees events" on public.events for select to authenticated using (
  customer_id = (select auth.uid())
  or public.current_scene_role() in ('operations_manager','ceo')
  or exists(select 1 from public.event_assignments a where a.event_id=events.id and a.staff_user_id=(select auth.uid()))
);
create policy "customer creates own inquiry" on public.events for insert to authenticated with check (customer_id = (select auth.uid()));
create policy "customer updates own inquiry or staff manages" on public.events for update to authenticated using ((customer_id = (select auth.uid()) and status = 'inquiry') or public.is_scene_staff()) with check ((customer_id = (select auth.uid())) or public.is_scene_staff());
create policy "event services authorized read" on public.event_services for select to authenticated using (exists(select 1 from public.events e where e.id=event_id and (e.customer_id=(select auth.uid()) or public.current_scene_role() in ('operations_manager','ceo') or exists(select 1 from public.event_assignments a where a.event_id=e.id and a.staff_user_id=(select auth.uid())))));
create policy "event services staff writes" on public.event_services for all to authenticated using (public.current_scene_role() in ('operations_manager','event_assistant','ceo')) with check (public.current_scene_role() in ('operations_manager','event_assistant','ceo'));
create policy "design owner or assigned staff reads" on public.event_designs for select to authenticated using (
  customer_id=(select auth.uid()) or public.current_scene_role() in ('designer','operations_manager','ceo')
  or exists(select 1 from public.event_assignments a where a.event_id=event_designs.event_id and a.staff_user_id=(select auth.uid()))
);
create policy "customer submits own design" on public.event_designs for insert to authenticated with check (customer_id=(select auth.uid()));
create policy "design owner or authorized staff updates" on public.event_designs for update to authenticated using (customer_id=(select auth.uid()) or public.current_scene_role() in ('designer','operations_manager','ceo')) with check (customer_id=(select auth.uid()) or public.current_scene_role() in ('designer','operations_manager','ceo'));

create policy "staff sees assigned events" on public.event_assignments for select to authenticated using (staff_user_id=(select auth.uid()) or public.current_scene_role() in ('operations_manager','designer','ceo'));
create policy "managers assign staff" on public.event_assignments for all to authenticated using (public.current_scene_role() in ('operations_manager','ceo')) with check (public.current_scene_role() in ('operations_manager','ceo'));

create policy "supplier records staff read" on public.suppliers for select to authenticated using (public.is_scene_staff());
create policy "supplier records managers write" on public.suppliers for all to authenticated using (public.current_scene_role() in ('operations_manager','ceo')) with check (public.current_scene_role() in ('operations_manager','ceo'));
create policy "sourcing staff read" on public.sourcing_items for select to authenticated using (public.is_scene_staff());
create policy "sourcing staff writes" on public.sourcing_items for all to authenticated using (public.current_scene_role() in ('event_assistant','operations_manager','ceo')) with check (public.current_scene_role() in ('event_assistant','operations_manager','ceo'));
create policy "inventory staff read" on public.inventory_items for select to authenticated using (public.is_scene_staff());
create policy "inventory managers write" on public.inventory_items for all to authenticated using (public.current_scene_role() in ('operations_manager','ceo')) with check (public.current_scene_role() in ('operations_manager','ceo'));

create policy "customer or staff quote read" on public.quotes for select to authenticated using (exists(select 1 from public.events e where e.id=event_id and (e.customer_id=(select auth.uid()) or public.is_scene_staff())));
create policy "staff manages quotes" on public.quotes for all to authenticated using (public.is_scene_staff()) with check (public.is_scene_staff());
create policy "CEO transaction access" on public.transactions for all to authenticated using (public.is_scene_ceo()) with check (public.is_scene_ceo());
create policy "business record permissions" on public.business_records for select to authenticated using (public.is_scene_ceo() or (visibility='manager' and public.current_scene_role() in ('operations_manager','designer')) or visibility='staff' and public.is_scene_staff());
create policy "CEO business record writes" on public.business_records for all to authenticated using (public.is_scene_ceo()) with check (public.is_scene_ceo());
create policy "CEO audit access" on public.audit_log for select to authenticated using (public.is_scene_ceo());

grant usage on schema public to anon, authenticated;
grant select on public.products, public.design_templates to anon, authenticated;
grant select, insert, update on public.profiles, public.events, public.event_designs to authenticated;
grant select on public.staff_members, public.event_assignments, public.event_services, public.suppliers, public.sourcing_items, public.inventory_items, public.quotes, public.transactions, public.business_records, public.audit_log to authenticated;

-- IMPORTANT SETUP NOTES:
-- 1. Use a private Supabase Edge Function/service-role operation for the first CEO bootstrap.
-- 2. Keep the one CEO email in a server-only secret; verify auth.users.email_confirmed_at,
--    exact normalized email match, and assign role='ceo' only during that bootstrap.
-- 3. Never let a client insert/update its own staff_members row or role.
-- 4. Add audit triggers for writes before production; add storage bucket policies for proofs.
-- 5. Review each policy against the final UI and laws before storing real customer/payment data.
