-- Perfis pessoais sem dados de autenticação/sensíveis e controle de papéis por empresa.
alter table public.profiles
  add column if not exists job_title text check (job_title is null or length(job_title) <= 100),
  add column if not exists department text check (department is null or length(department) <= 100),
  add column if not exists city text check (city is null or length(city) <= 100),
  add column if not exists state text check (state is null or length(state) <= 2),
  add column if not exists bio text check (bio is null or length(bio) <= 240);

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before update on public.profiles
for each row execute function public.touch_updated_at();

-- Métodos de amortização aceitos pelas tabelas locais.
alter table public.rate_profiles drop constraint if exists rate_profiles_method_code_check;
alter table public.rate_profiles add constraint rate_profiles_method_code_check
  check (method_code in ('SAC','PRICE','SACOQ2','SACOQ12','SAC_INDEXED','PRICE_INDEXED','CUSTOM'));
alter table public.simulations drop constraint if exists simulations_method_code_check;
alter table public.simulations add constraint simulations_method_code_check
  check (method_code in ('SAC','PRICE','SACOQ2','SACOQ12','SAC_INDEXED','PRICE_INDEXED','CUSTOM'));

create or replace function public.update_org_member_role(p_organization_id uuid,p_user_id uuid,p_role text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_current_role text;
begin
  if auth.uid() is null then raise exception 'Autenticação necessária'; end if;
  if not public.has_org_role(p_organization_id,array['owner','admin']) then raise exception 'Sem permissão para alterar papéis'; end if;
  if p_user_id=auth.uid() then raise exception 'Você não pode alterar seu próprio papel'; end if;
  if p_role not in ('admin','manager','broker','viewer') then raise exception 'Papel inválido'; end if;
  if p_role='admin' and not public.has_org_role(p_organization_id,array['owner']) then raise exception 'Somente o proprietário pode nomear administradores'; end if;
  select m.role into v_current_role from public.organization_members m
    where m.organization_id=p_organization_id and m.user_id=p_user_id for update;
  if not found then raise exception 'Usuário não encontrado nesta empresa'; end if;
  if v_current_role='owner' then raise exception 'O papel do proprietário não pode ser alterado'; end if;
  update public.organization_members set role=p_role where organization_id=p_organization_id and user_id=p_user_id;
end $$;

create or replace function public.remove_org_member(p_organization_id uuid,p_user_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_current_role text;
begin
  if auth.uid() is null then raise exception 'Autenticação necessária'; end if;
  if not public.has_org_role(p_organization_id,array['owner','admin']) then raise exception 'Sem permissão para revogar usuários'; end if;
  if p_user_id=auth.uid() then raise exception 'Você não pode revogar seu próprio acesso'; end if;
  select m.role into v_current_role from public.organization_members m
    where m.organization_id=p_organization_id and m.user_id=p_user_id for update;
  if not found then raise exception 'Usuário não encontrado nesta empresa'; end if;
  if v_current_role='owner' and not public.has_org_role(p_organization_id,array['owner']) then raise exception 'Somente o proprietário pode revogar outro proprietário'; end if;
  if v_current_role='owner' then raise exception 'Transfira a propriedade antes de remover o proprietário'; end if;
  delete from public.organization_members where organization_id=p_organization_id and user_id=p_user_id;
end $$;

revoke all on function public.update_org_member_role(uuid,uuid,text) from public,anon;
revoke all on function public.remove_org_member(uuid,uuid) from public,anon;
grant execute on function public.update_org_member_role(uuid,uuid,text) to authenticated;
grant execute on function public.remove_org_member(uuid,uuid) to authenticated;
