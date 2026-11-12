-- Security foundation and private institutional Storage.
-- The final approval/signup/rehab RPCs are installed by 0003_integrity_and_lifecycle.sql.
-- Run all three migrations before creating user accounts.

create or replace function public.is_platform_owner() returns boolean
language sql stable security definer set search_path=public as $$
  select exists(
    select 1 from public.profiles p
    where p.id=auth.uid() and p.role='platform_owner' and p.status='active'
  )
$$;
revoke all on function public.is_platform_owner() from public;
grant execute on function public.is_platform_owner() to authenticated;

-- Private bucket for institution branding and lesson-plan documents.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'sport-performance','sport-performance',false,20971520,
  array[
    'image/png','image/jpeg','image/webp','application/pdf','application/msword','application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/plain','text/csv'
  ]
) on conflict(id) do nothing;

create policy sp_storage_read on storage.objects for select to authenticated
using(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text);
create policy sp_storage_insert on storage.objects for insert to authenticated
with check(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text and public.is_institution_admin());
create policy sp_storage_update on storage.objects for update to authenticated
using(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text and public.is_institution_admin())
with check(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text and public.is_institution_admin());
create policy sp_storage_delete on storage.objects for delete to authenticated
using(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text and public.is_institution_admin());

-- Platform owner may inspect institutions and profiles to provision institution administrators.
create policy platform_owner_institutions_read on public.institutions for select to authenticated
using(public.is_platform_owner());
create policy platform_owner_profiles_read on public.profiles for select to authenticated
using(public.is_platform_owner());

-- Archived school years can only transition to archive through the guarded RPC in migration 0003.
create or replace function public.guard_school_year_mutation() returns trigger
language plpgsql set search_path=public as $$
begin
  if tg_op='DELETE' and old.archived_at is not null then
    raise exception 'Archived school year cannot be deleted';
  end if;
  if tg_op='UPDATE' and old.archived_at is not null then
    raise exception 'Archived school year is read-only';
  end if;
  if tg_op='UPDATE' and new.archived_at is not null then
    if (to_jsonb(new)-'is_current'-'end_date'-'archived_at') <> (to_jsonb(old)-'is_current'-'end_date'-'archived_at') then
      raise exception 'Only archive transition is allowed';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
create trigger school_year_readonly_guard before update or delete on public.school_years
for each row execute function public.guard_school_year_mutation();
revoke all on function public.guard_school_year_mutation() from public;
