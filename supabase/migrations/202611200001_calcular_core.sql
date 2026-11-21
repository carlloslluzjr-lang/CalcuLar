-- CalcuLar multiempresa: esquema inicial e isolamento por Row Level Security.
-- Aplicar no projeto Supabase do produto antes de habilitar usuários externos.
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 120),
  slug text not null unique,
  plan text not null default 'individual' check (plan in ('individual','team','enterprise')),
  status text not null default 'active' check (status in ('active','suspended','trial')),
  brand_color text not null default '#1468d4',
  brand_logo_data_url text,
  disclaimer text not null default 'Simulação estimada; confirme as condições com a instituição responsável.',
  correction_months integer not null default 12 check (correction_months between 1 and 120),
  income_limit_pct numeric(5,2) not null default 30 check (income_limit_pct between 1 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  email text,
  role text not null default 'broker' check (role in ('owner','admin','manager','broker','viewer')),
  created_at timestamptz not null default now(),
  primary key (organization_id,user_id)
);
create index if not exists organization_members_user_idx on public.organization_members(user_id);

create table if not exists public.organization_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null,
  role text not null default 'broker' check (role in ('manager','broker','viewer')),
  token uuid not null unique default gen_random_uuid(),
  created_by uuid not null references auth.users(id),
  accepted_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz
);
create index if not exists organization_invitations_org_idx on public.organization_invitations(organization_id);

create table if not exists public.rate_profiles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  product_type text not null check (product_type in ('casa','imovel','terreno','loteamento','comercial')),
  method_code text not null check (method_code in ('SAC','PRICE','SACOQ2','SAC_INDEXED','PRICE_INDEXED','CUSTOM')),
  annual_rate_pct numeric(10,6) not null check (annual_rate_pct >= 0),
  rate_basis text not null default 'effective' check (rate_basis in ('effective','nominal')),
  index_name text not null default 'none',
  index_rate_pct numeric(10,6) not null default 0 check (index_rate_pct >= 0),
  correction_months integer not null default 12 check (correction_months between 1 and 120),
  version integer not null default 1 check (version > 0),
  valid_from date not null,
  valid_to date,
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id,name,version),
  unique (organization_id,id)
);
create index if not exists rate_profiles_org_lookup_idx on public.rate_profiles(organization_id,product_type,method_code,valid_from desc);

create table if not exists public.developments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  product_type text not null check (product_type in ('casa','imovel','terreno','loteamento','comercial')),
  city text,
  state char(2),
  units_count integer check (units_count is null or units_count >= 0),
  reference_value numeric(14,2) not null default 0 check (reference_value >= 0),
  lot_area numeric(12,2) check (lot_area is null or lot_area >= 0),
  payment_rules jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id,id)
);
create index if not exists developments_org_name_idx on public.developments(organization_id,name);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  email text,
  phone text,
  source text,
  owner_label text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id,id)
);
create index if not exists customers_org_created_idx on public.customers(organization_id,created_at desc);

create table if not exists public.simulations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid,
  development_id uuid,
  created_by uuid not null references auth.users(id),
  client_label text,
  product_type text not null check (product_type in ('casa','imovel','terreno','loteamento','comercial')),
  method_code text not null check (method_code in ('SAC','PRICE','SACOQ2','SAC_INDEXED','PRICE_INDEXED','CUSTOM')),
  property_value numeric(14,2) not null check (property_value >= 0),
  entry_amount numeric(14,2) not null default 0 check (entry_amount >= 0),
  financed_amount numeric(14,2) not null check (financed_amount >= 0),
  term_months integer not null check (term_months between 1 and 480),
  annual_rate_pct numeric(10,6) not null default 0,
  index_name text not null default 'none',
  index_rate_pct numeric(10,6) not null default 0,
  first_payment numeric(14,2) not null default 0,
  last_payment numeric(14,2) not null default 0,
  total_interest numeric(16,2) not null default 0,
  total_correction numeric(16,2) not null default 0,
  total_payments numeric(16,2) not null default 0,
  calculation jsonb not null default '{}'::jsonb,
  status text not null default 'simulated' check (status in ('simulated','proposal','archived')),
  created_at timestamptz not null default now(),
  unique (organization_id,id),
  foreign key (organization_id,customer_id) references public.customers(organization_id,id),
  foreign key (organization_id,development_id) references public.developments(organization_id,id)
);
create index if not exists simulations_org_recent_idx on public.simulations(organization_id,created_at desc);
create index if not exists simulations_creator_recent_idx on public.simulations(organization_id,created_by,created_at desc);

create table if not exists public.proposals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  simulation_id uuid not null,
  title text,
  status text not null default 'received' check (status in ('received','pending','conditional','approved','rejected')),
  document_pending boolean not null default false,
  notes text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id,simulation_id) references public.simulations(organization_id,id) on delete cascade
);
create index if not exists proposals_org_status_idx on public.proposals(organization_id,status,created_at desc);

create or replace function public.is_org_member(p_org uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=(select auth.uid())) $$;

create or replace function public.has_org_role(p_org uuid,p_roles text[])
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=(select auth.uid()) and m.role=any(p_roles)) $$;

create or replace function public.create_organization(p_name text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_id uuid; v_slug text;
begin
  if auth.uid() is null then raise exception 'Autenticação necessária'; end if;
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'Informe o nome da empresa'; end if;
  v_id := gen_random_uuid();
  v_slug := trim(both '-' from regexp_replace(lower(trim(p_name)), '[^a-z0-9]+', '-', 'g')) || '-' || substr(replace(v_id::text,'-',''),1,6);
  insert into public.organizations(id,name,slug) values(v_id,trim(p_name),v_slug);
  insert into public.organization_members(organization_id,user_id,email,role) values(v_id,auth.uid(),auth.jwt()->>'email','owner');
  return v_id;
end $$;

create or replace function public.create_org_invitation(p_organization_id uuid,p_email text,p_role text default 'broker')
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_token uuid;
begin
  if not public.has_org_role(p_organization_id,array['owner','admin','manager']) then raise exception 'Sem permissão para convidar membros'; end if;
  if lower(trim(p_role)) not in ('manager','broker','viewer') then raise exception 'Papel inválido'; end if;
  insert into public.organization_invitations(organization_id,email,role,created_by)
  values(p_organization_id,lower(trim(p_email)),lower(trim(p_role)),auth.uid())
  returning token into v_token;
  return v_token;
end $$;

create or replace function public.accept_org_invitation(p_token uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_inv public.organization_invitations%rowtype;
begin
  if auth.uid() is null then raise exception 'Autenticação necessária'; end if;
  select * into v_inv from public.organization_invitations i where i.token=p_token and i.accepted_at is null and i.expires_at>now() for update;
  if not found then raise exception 'Convite inválido, expirado ou já utilizado'; end if;
  if lower(v_inv.email) <> lower(coalesce(auth.jwt()->>'email','')) then raise exception 'Entre com o e-mail que recebeu o convite'; end if;
  insert into public.organization_members(organization_id,user_id,email,role) values(v_inv.organization_id,auth.uid(),v_inv.email,v_inv.role)
  on conflict(organization_id,user_id) do nothing;
  update public.organization_invitations set accepted_by=auth.uid(),accepted_at=now() where id=v_inv.id;
  return v_inv.organization_id;
end $$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at=now(); return new; end $$;
drop trigger if exists organizations_touch_updated_at on public.organizations;
create trigger organizations_touch_updated_at before update on public.organizations for each row execute function public.touch_updated_at();
drop trigger if exists proposals_touch_updated_at on public.proposals;
create trigger proposals_touch_updated_at before update on public.proposals for each row execute function public.touch_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(user_id,full_name,phone)
  values(new.id,new.raw_user_meta_data->>'full_name',new.phone)
  on conflict(user_id) do update set full_name=excluded.full_name,phone=coalesce(excluded.phone,public.profiles.phone);
  return new;
end $$;
drop trigger if exists on_auth_user_created_calcular on auth.users;
create trigger on_auth_user_created_calcular after insert or update of phone on auth.users for each row execute function public.handle_new_auth_user();

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.organization_members enable row level security;
alter table public.organization_invitations enable row level security;
alter table public.rate_profiles enable row level security;
alter table public.developments enable row level security;
alter table public.customers enable row level security;
alter table public.simulations enable row level security;
alter table public.proposals enable row level security;

revoke all on public.organizations,public.profiles,public.organization_members,public.organization_invitations,public.rate_profiles,public.developments,public.customers,public.simulations,public.proposals from anon;
grant select on public.organizations to authenticated;
grant update(name,brand_color,brand_logo_data_url,disclaimer,correction_months,income_limit_pct) on public.organizations to authenticated;
grant select,insert,update,delete on public.profiles to authenticated;
grant select on public.organization_members to authenticated;
grant select,insert,update,delete on public.organization_invitations to authenticated;
grant select,insert,update,delete on public.rate_profiles,public.developments,public.customers,public.simulations,public.proposals to authenticated;
revoke all on function public.is_org_member(uuid) from public,anon;
revoke all on function public.has_org_role(uuid,text[]) from public,anon;
revoke all on function public.create_organization(text) from public,anon;
revoke all on function public.create_org_invitation(uuid,text,text) from public,anon;
revoke all on function public.accept_org_invitation(uuid) from public,anon;
revoke all on function public.touch_updated_at() from public,anon;
revoke all on function public.handle_new_auth_user() from public,anon;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.has_org_role(uuid,text[]) to authenticated;
grant execute on function public.create_organization(text) to authenticated;
grant execute on function public.create_org_invitation(uuid,text,text) to authenticated;
grant execute on function public.accept_org_invitation(uuid) to authenticated;

create policy organizations_read_member on public.organizations for select to authenticated using (public.is_org_member(id));
create policy organizations_update_admin on public.organizations for update to authenticated using (public.has_org_role(id,array['owner','admin'])) with check (public.has_org_role(id,array['owner','admin']));
create policy profiles_read_self on public.profiles for select to authenticated using (user_id=(select auth.uid()));
create policy profiles_insert_self on public.profiles for insert to authenticated with check (user_id=(select auth.uid()));
create policy profiles_update_self on public.profiles for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy organization_members_read_member on public.organization_members for select to authenticated using (public.is_org_member(organization_id));
create policy organization_members_remove_admin on public.organization_members for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin']));
create policy invitations_read_admin on public.organization_invitations for select to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']));
create policy invitations_create_admin on public.organization_invitations for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']) and created_by=(select auth.uid()));
create policy invitations_update_admin on public.organization_invitations for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager'])) with check (public.has_org_role(organization_id,array['owner','admin','manager']));

create policy rate_profiles_read_member on public.rate_profiles for select to authenticated using (public.is_org_member(organization_id));
create policy rate_profiles_insert_admin on public.rate_profiles for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']) and created_by=(select auth.uid()));
create policy rate_profiles_update_admin on public.rate_profiles for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager'])) with check (public.has_org_role(organization_id,array['owner','admin','manager']));
create policy rate_profiles_delete_admin on public.rate_profiles for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin']));

create policy developments_read_member on public.developments for select to authenticated using (public.is_org_member(organization_id));
create policy developments_insert_admin on public.developments for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']) and created_by=(select auth.uid()));
create policy developments_update_admin on public.developments for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager'])) with check (public.has_org_role(organization_id,array['owner','admin','manager']));
create policy developments_delete_admin on public.developments for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin']));

create policy customers_read_member on public.customers for select to authenticated using (public.is_org_member(organization_id));
create policy customers_insert_member on public.customers for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager','broker']) and created_by=(select auth.uid()));
create policy customers_update_member on public.customers for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager','broker'])) with check (public.has_org_role(organization_id,array['owner','admin','manager','broker']));
create policy customers_delete_admin on public.customers for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']));

create policy simulations_read_member on public.simulations for select to authenticated using (public.is_org_member(organization_id));
create policy simulations_insert_member on public.simulations for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager','broker']) and created_by=(select auth.uid()));
create policy simulations_update_owner_or_admin on public.simulations for update to authenticated using ((created_by=(select auth.uid()) and public.has_org_role(organization_id,array['broker'])) or public.has_org_role(organization_id,array['owner','admin','manager'])) with check (public.has_org_role(organization_id,array['owner','admin','manager']) or (created_by=(select auth.uid()) and public.has_org_role(organization_id,array['broker'])));
create policy simulations_delete_owner_or_admin on public.simulations for delete to authenticated using ((created_by=(select auth.uid()) and public.has_org_role(organization_id,array['broker'])) or public.has_org_role(organization_id,array['owner','admin','manager']));

create policy proposals_read_member on public.proposals for select to authenticated using (public.is_org_member(organization_id));
create policy proposals_insert_member on public.proposals for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager','broker']) and created_by=(select auth.uid()));
create policy proposals_update_manager on public.proposals for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager'])) with check (public.has_org_role(organization_id,array['owner','admin','manager']));
create policy proposals_delete_manager on public.proposals for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager']));

comment on table public.organizations is 'Tenant raiz de isolamento de dados do CalcuLar.';
comment on table public.rate_profiles is 'Taxas configuradas e versionadas por empresa.';
comment on table public.simulations is 'Simulações e memória de cálculo pertencentes a uma empresa.';
