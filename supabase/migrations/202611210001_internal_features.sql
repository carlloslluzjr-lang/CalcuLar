-- Recursos internos do CalcuLar: estimativa local de custos e captação pública de leads.
alter table public.organizations
  add column if not exists itbi_rate_pct numeric(8,4) not null default 0 check (itbi_rate_pct between 0 and 100),
  add column if not exists registry_fee_estimate numeric(14,2) not null default 0 check (registry_fee_estimate >= 0),
  add column if not exists fee_reference text not null default '';
grant update(itbi_rate_pct,registry_fee_estimate,fee_reference) on public.organizations to authenticated;

create table if not exists public.lead_capture_forms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null unique references public.organizations(id) on delete cascade,
  public_token uuid not null unique default gen_random_uuid(),
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table if not exists public.inbound_leads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  form_id uuid not null references public.lead_capture_forms(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 120),
  email text,
  phone text,
  consent boolean not null default false check (consent),
  source text not null default 'formulario_publico',
  created_at timestamptz not null default now(),
  check (coalesce(nullif(trim(email),''),nullif(trim(phone),'')) is not null)
);
create index if not exists inbound_leads_org_recent_idx on public.inbound_leads(organization_id,created_at desc);
create index if not exists inbound_leads_dedupe_idx on public.inbound_leads(form_id,created_at desc);
alter table public.lead_capture_forms enable row level security;
alter table public.inbound_leads enable row level security;
revoke all on public.lead_capture_forms,public.inbound_leads from anon;
grant select,insert,update,delete on public.lead_capture_forms to authenticated;
grant select,delete on public.inbound_leads to authenticated;

drop policy if exists lead_capture_forms_read_member on public.lead_capture_forms;
create policy lead_capture_forms_read_member on public.lead_capture_forms for select to authenticated using (public.is_org_member(organization_id));
drop policy if exists lead_capture_forms_insert_manager on public.lead_capture_forms;
create policy lead_capture_forms_insert_manager on public.lead_capture_forms for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','manager']) and created_by=(select auth.uid()));
drop policy if exists lead_capture_forms_update_manager on public.lead_capture_forms;
create policy lead_capture_forms_update_manager on public.lead_capture_forms for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager'])) with check (public.has_org_role(organization_id,array['owner','admin','manager']));
drop policy if exists lead_capture_forms_delete_admin on public.lead_capture_forms;
create policy lead_capture_forms_delete_admin on public.lead_capture_forms for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin']));
drop policy if exists inbound_leads_read_member on public.inbound_leads;
create policy inbound_leads_read_member on public.inbound_leads for select to authenticated using (public.is_org_member(organization_id));
drop policy if exists inbound_leads_delete_team on public.inbound_leads;
create policy inbound_leads_delete_team on public.inbound_leads for delete to authenticated using (public.has_org_role(organization_id,array['owner','admin','manager','broker']));

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
  insert into public.inbound_leads(organization_id,form_id,name,email,phone,consent)
  values(v_form.organization_id,v_form.id,trim(p_name),v_email,v_phone,true);
end $$;
revoke all on function public.submit_public_lead(uuid,text,text,text,boolean,text) from public;
grant execute on function public.submit_public_lead(uuid,text,text,text,boolean,text) to anon,authenticated;
comment on table public.inbound_leads is 'Leads voluntariamente enviados pelo formulário público do CalcuLar.';
