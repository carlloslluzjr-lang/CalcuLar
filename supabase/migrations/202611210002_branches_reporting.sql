-- Filiais por empresa e atribuição de dados para relatórios gerenciais.
create table if not exists public.organization_branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 120),
  city text,
  state char(2),
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id,id),
  unique (organization_id,name)
);

alter table public.organization_members add column if not exists branch_id uuid;
alter table public.developments add column if not exists branch_id uuid;
alter table public.customers add column if not exists branch_id uuid;
alter table public.simulations add column if not exists branch_id uuid;
alter table public.lead_capture_forms add column if not exists branch_id uuid;
alter table public.inbound_leads add column if not exists branch_id uuid;

DO $$ BEGIN
  if not exists(select 1 from pg_constraint where conname='organization_members_branch_org_fk') then
    alter table public.organization_members add constraint organization_members_branch_org_fk foreign key(organization_id,branch_id) references public.organization_branches(organization_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='developments_branch_org_fk') then
    alter table public.developments add constraint developments_branch_org_fk foreign key(organization_id,branch_id) references public.organization_branches(organization_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='customers_branch_org_fk') then
    alter table public.customers add constraint customers_branch_org_fk foreign key(organization_id,branch_id) references public.organization_branches(organization_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='simulations_branch_org_fk') then
    alter table public.simulations add constraint simulations_branch_org_fk foreign key(organization_id,branch_id) references public.organization_branches(organization_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='lead_forms_branch_org_fk') then
    alter table public.lead_capture_forms add constraint lead_forms_branch_org_fk foreign key(organization_id,branch_id) references public.organization_branches(organization_id,id);
  end if;
  if not exists(select 1 from pg_constraint where conname='inbound_leads_branch_org_fk') then
    alter table public.inbound_leads add constraint inbound_leads_branch_org_fk foreign key(organization_id,branch_id) references public.organization_branches(organization_id,id);
  end if;
END $$;

create index if not exists sims_org_branch_recent_idx on public.simulations(organization_id,branch_id,created_at desc);
create index if not exists customers_org_branch_recent_idx on public.customers(organization_id,branch_id,created_at desc);
create index if not exists leads_org_branch_recent_idx on public.inbound_leads(organization_id,branch_id,created_at desc);
alter table public.organization_branches enable row level security;
grant select,insert,update,delete on public.organization_branches to authenticated;
grant update(branch_id) on public.organization_members to authenticated;

drop policy if exists organization_branches_read_member on public.organization_branches;
create policy organization_branches_read_member on public.organization_branches for select to authenticated using (public.is_org_member(organization_id));
drop policy if exists organization_branches_insert_manager on public.organization_branches;
create policy organization_branches_insert_manager on public.organization_branches for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']) and created_by=(select auth.uid()));
drop policy if exists organization_branches_update_manager on public.organization_branches;
create policy organization_branches_update_manager on public.organization_branches for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager'])) with check (public.has_org_role(organization_id,array['owner','admin','manager']));
drop policy if exists organization_branches_delete_admin on public.organization_branches;
create policy organization_branches_delete_admin on public.organization_branches for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin']));
drop policy if exists organization_members_assign_branch on public.organization_members;
create policy organization_members_assign_branch on public.organization_members for update to authenticated using (public.has_org_role(organization_id,array['owner','admin'])) with check (public.has_org_role(organization_id,array['owner','admin']));

create or replace function public.submit_public_lead(p_token uuid,p_name text,p_email text,p_phone text,p_consent boolean,p_website text default '')
returns void language plpgsql security definer set search_path = ''
as $$
declare v_form public.lead_capture_forms%rowtype; v_email text; v_phone text;
begin
  if coalesce(trim(p_website),'')<>'' then return; end if;
  if p_consent is distinct from true then raise exception 'Confirme a autorização para contato'; end if;
  if length(trim(coalesce(p_name,''))) not between 2 and 120 then raise exception 'Informe seu nome'; end if;
  v_email:=nullif(lower(trim(coalesce(p_email,''))), ''); v_phone:=nullif(trim(coalesce(p_phone,'')), '');
  if v_email is null and v_phone is null then raise exception 'Informe um e-mail ou telefone'; end if;
  select * into v_form from public.lead_capture_forms f where f.public_token=p_token and f.active=true;
  if not found then raise exception 'Este formulário não está disponível'; end if;
  if exists(select 1 from public.inbound_leads l where l.form_id=v_form.id and l.created_at>now()-interval '60 seconds' and ((v_email is not null and lower(l.email)=v_email) or (v_phone is not null and l.phone=v_phone))) then return; end if;
  insert into public.inbound_leads(organization_id,form_id,branch_id,name,email,phone,consent)
  values(v_form.organization_id,v_form.id,v_form.branch_id,trim(p_name),v_email,v_phone,true);
end $$;
revoke all on function public.submit_public_lead(uuid,text,text,text,boolean,text) from public;
grant execute on function public.submit_public_lead(uuid,text,text,text,boolean,text) to anon,authenticated;
comment on table public.organization_branches is 'Filiais e unidades de operação dentro da empresa CalcuLar.';
