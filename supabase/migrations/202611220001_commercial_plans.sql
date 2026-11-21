-- Planos comerciais editáveis por organização, restritos a proprietários e administradores.
alter table public.organizations
  add column if not exists commercial_plans jsonb not null default '[]'::jsonb
  check (jsonb_typeof(commercial_plans) = 'array');
grant update(commercial_plans) on public.organizations to authenticated;
comment on column public.organizations.commercial_plans is 'Ofertas comerciais editáveis por owner/admin da empresa. Não ativa cobrança.';
