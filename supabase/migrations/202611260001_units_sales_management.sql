-- CalcuLar: Módulo de Controle de Unidades e Vendas
-- Empreendimentos avançados, unidades, tabelas de preços, regras comerciais e histórico de status.

-- 1. Ampliação da tabela de empreendimentos
alter table public.developments
  add column if not exists address text,
  add column if not exists description text,
  add column if not exists stage text not null default 'em_obras' check (stage in ('breve_lancamento','lancamento','em_obras','pronto','entregue')),
  add column if not exists archived boolean not null default false;

-- 2. Tabela de tabelas de preços
create table if not exists public.price_tables (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  development_id uuid,
  name text not null check (length(trim(name)) between 2 and 120),
  valid_from date not null default current_date,
  valid_to date,
  base_meter_price numeric(14,2) check (base_meter_price is null or base_meter_price >= 0),
  payment_conditions text,
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, development_id) references public.developments(organization_id, id) on delete cascade
);
create index if not exists price_tables_org_dev_idx on public.price_tables(organization_id, development_id);

-- 3. Tabela de unidades do empreendimento
create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  development_id uuid not null,
  block text,
  unit_number text not null check (length(trim(unit_number)) between 1 and 60),
  category text not null default 'padrao' check (category in ('apartamento','casa','casa_condominio','sobrado','lote','cobertura','studio','sala_comercial','galpao','padrao','outro')),
  area_built numeric(12,2) check (area_built is null or area_built >= 0),
  area_total numeric(12,2) check (area_total is null or area_total >= 0),
  allow_fractional boolean not null default false,
  min_fractional_area numeric(12,2) check (min_fractional_area is null or min_fractional_area > 0),
  base_price numeric(14,2) not null default 0 check (base_price >= 0),
  pricing_model text not null default 'direct' check (pricing_model in ('direct','per_meter','price_table','commercial_rule')),
  price_per_meter numeric(14,2) check (price_per_meter is null or price_per_meter >= 0),
  price_table_id uuid,
  status text not null default 'disponivel' check (status in ('disponivel','reservada','vendida','bloqueada')),
  features jsonb not null default '{}'::jsonb,
  notes text,
  images jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, development_id) references public.developments(organization_id, id) on delete cascade,
  foreign key (organization_id, price_table_id) references public.price_tables(organization_id, id) on delete set null
);
create index if not exists units_org_dev_status_idx on public.units(organization_id, development_id, status);
create index if not exists units_org_category_idx on public.units(organization_id, category);

-- 4. Tabela de regras comerciais de precificação e bônus/descontos
create table if not exists public.commercial_rules (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  development_id uuid,
  unit_id uuid,
  unit_category text check (unit_category is null or unit_category in ('apartamento','casa','casa_condominio','sobrado','lote','cobertura','studio','sala_comercial','galpao','padrao','outro')),
  name text not null check (length(trim(name)) between 2 and 120),
  description text,
  scope text not null default 'development' check (scope in ('company','development','unit')),
  min_area numeric(12,2) check (min_area is null or min_area >= 0),
  max_area numeric(12,2) check (max_area is null or max_area >= 0),
  discount_pct numeric(5,2) not null default 0 check (discount_pct between 0 and 100),
  discount_val numeric(14,2) not null default 0 check (discount_val >= 0),
  bonus_val numeric(14,2) not null default 0 check (bonus_val >= 0),
  bonus_desc text,
  fixed_meter_price numeric(14,2) check (fixed_meter_price is null or fixed_meter_price >= 0),
  priority integer not null default 10 check (priority between 1 and 1000),
  valid_from date not null default current_date,
  valid_to date,
  rounding_mode text not null default 'cents' check (rounding_mode in ('cents','round_10','round_100','round_1000','none')),
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, development_id) references public.developments(organization_id, id) on delete cascade,
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete cascade
);
create index if not exists commercial_rules_org_priority_idx on public.commercial_rules(organization_id, priority desc, valid_from desc);

-- 5. Histórico de alterações de situação da unidade (Auditoria & Jornada de Vendas)
create table if not exists public.unit_status_history (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  unit_id uuid not null,
  previous_status text,
  new_status text not null check (new_status in ('disponivel','reservada','vendida','bloqueada')),
  customer_id uuid,
  simulation_id uuid,
  proposal_id uuid,
  notes text,
  changed_by uuid not null references auth.users(id),
  changed_at timestamptz not null default now(),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete cascade,
  foreign key (organization_id, customer_id) references public.customers(organization_id, id) on delete set null,
  foreign key (organization_id, simulation_id) references public.simulations(organization_id, id) on delete set null,
  foreign key (organization_id, proposal_id) references public.proposals(organization_id, id) on delete set null
);
create index if not exists unit_history_org_unit_idx on public.unit_status_history(organization_id, unit_id, changed_at desc);

-- 6. Ampliação da tabela de simulações para vincular unidade e snapshot de precificação
alter table public.simulations
  add column if not exists unit_id uuid,
  add column if not exists pricing_snapshot jsonb not null default '{}'::jsonb;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='simulations_unit_org_fk') then
    alter table public.simulations add constraint simulations_unit_org_fk foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete set null;
  end if;
end $$;

-- 7. Triggers de atualização automática de data (touch_updated_at)
drop trigger if exists units_touch_updated_at on public.units;
create trigger units_touch_updated_at before update on public.units for each row execute function public.touch_updated_at();

drop trigger if exists price_tables_touch_updated_at on public.price_tables;
create trigger price_tables_touch_updated_at before update on public.price_tables for each row execute function public.touch_updated_at();

drop trigger if exists commercial_rules_touch_updated_at on public.commercial_rules;
create trigger commercial_rules_touch_updated_at before update on public.commercial_rules for each row execute function public.touch_updated_at();

-- 8. Row Level Security (RLS)
alter table public.price_tables enable row level security;
alter table public.units enable row level security;
alter table public.commercial_rules enable row level security;
alter table public.unit_status_history enable row level security;

revoke all on public.price_tables, public.units, public.commercial_rules, public.unit_status_history from anon;
grant select, insert, update, delete on public.price_tables, public.units, public.commercial_rules, public.unit_status_history to authenticated;

-- Políticas de RLS para price_tables
drop policy if exists price_tables_read_member on public.price_tables;
create policy price_tables_read_member on public.price_tables for select to authenticated using (public.is_org_member(organization_id));

drop policy if exists price_tables_insert_manager on public.price_tables;
create policy price_tables_insert_manager on public.price_tables for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager']) and created_by=(select auth.uid()));

drop policy if exists price_tables_update_manager on public.price_tables;
create policy price_tables_update_manager on public.price_tables for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager'])) with check (public.has_org_role(organization_id, array['owner','admin','manager']));

drop policy if exists price_tables_delete_admin on public.price_tables;
create policy price_tables_delete_admin on public.price_tables for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']));

-- Políticas de RLS para units
drop policy if exists units_read_member on public.units;
create policy units_read_member on public.units for select to authenticated using (public.is_org_member(organization_id));

drop policy if exists units_insert_manager on public.units;
create policy units_insert_manager on public.units for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager']) and created_by=(select auth.uid()));

drop policy if exists units_update_member on public.units;
create policy units_update_member on public.units for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager','broker'])) with check (public.has_org_role(organization_id, array['owner','admin','manager','broker']));

drop policy if exists units_delete_admin on public.units;
create policy units_delete_admin on public.units for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']));

-- Políticas de RLS para commercial_rules
drop policy if exists commercial_rules_read_member on public.commercial_rules;
create policy commercial_rules_read_member on public.commercial_rules for select to authenticated using (public.is_org_member(organization_id));

drop policy if exists commercial_rules_insert_manager on public.commercial_rules;
create policy commercial_rules_insert_manager on public.commercial_rules for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager']) and created_by=(select auth.uid()));

drop policy if exists commercial_rules_update_manager on public.commercial_rules;
create policy commercial_rules_update_manager on public.commercial_rules for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','manager'])) with check (public.has_org_role(organization_id, array['owner','admin','manager']));

drop policy if exists commercial_rules_delete_admin on public.commercial_rules;
create policy commercial_rules_delete_admin on public.commercial_rules for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']));

-- Políticas de RLS para unit_status_history
drop policy if exists unit_status_history_read_member on public.unit_status_history;
create policy unit_status_history_read_member on public.unit_status_history for select to authenticated using (public.is_org_member(organization_id));

drop policy if exists unit_status_history_insert_team on public.unit_status_history;
create policy unit_status_history_insert_team on public.unit_status_history for insert to authenticated with check (public.has_org_role(organization_id, array['owner','admin','manager','broker']) and changed_by=(select auth.uid()));

-- 9. Configuração do Storage para imagens de unidades (Bucket: unit-images)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('unit-images', 'unit-images', false, 10485760, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Políticas de Storage por Empresa (caminho: <org_id>/<dev_id>/<filename>)
drop policy if exists "Unit Images Read Member" on storage.objects;
create policy "Unit Images Read Member" on storage.objects for select to authenticated
using (bucket_id = 'unit-images' and public.is_org_member((storage.foldername(name))[1]::uuid));

drop policy if exists "Unit Images Insert Manager" on storage.objects;
create policy "Unit Images Insert Manager" on storage.objects for insert to authenticated
with check (
  bucket_id = 'unit-images'
  and public.has_org_role((storage.foldername(name))[1]::uuid, array['owner','admin','manager'])
);

drop policy if exists "Unit Images Update Manager" on storage.objects;
create policy "Unit Images Update Manager" on storage.objects for update to authenticated
using (
  bucket_id = 'unit-images'
  and public.has_org_role((storage.foldername(name))[1]::uuid, array['owner','admin','manager'])
);

drop policy if exists "Unit Images Delete Admin" on storage.objects;
create policy "Unit Images Delete Admin" on storage.objects for delete to authenticated
using (
  bucket_id = 'unit-images'
  and public.has_org_role((storage.foldername(name))[1]::uuid, array['owner','admin'])
);

comment on table public.units is 'Estoque e controle de unidades, lotes e imóveis da empresa.';
comment on table public.price_tables is 'Tabelas de preços cadastradas pela empresa ou por empreendimento.';
comment on table public.commercial_rules is 'Regras comerciais, faixas de metragem, descontos e bônus aplicáveis.';
comment on table public.unit_status_history is 'Histórico e auditoria de alterações de situação (reserva/venda/bloqueio) de unidades.';
