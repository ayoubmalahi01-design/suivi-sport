-- Sport Performance hardening migration 0003.
-- Additive, data-preserving. Run after 0001 and 0002 on the new Sport Performance schema.
-- No audit-log objects are created.

-- Composite keys ensure every relation stays inside the same institution/year.
create unique index if not exists institutions_id_id_uq on public.institutions(id);
create unique index if not exists school_years_id_institution_uq on public.school_years(id,institution_id);
create unique index if not exists lesson_plans_id_institution_uq on public.lesson_plans(id,institution_id);
create unique index if not exists lesson_plans_id_institution_year_uq on public.lesson_plans(id,institution_id,school_year_id);
create unique index if not exists classes_id_institution_uq on public.classes(id,institution_id);
create unique index if not exists classes_id_institution_year_uq on public.classes(id,institution_id,school_year_id);
create unique index if not exists students_id_institution_year_uq on public.students(id,institution_id,school_year_id);
create unique index if not exists sessions_id_institution_year_uq on public.sessions(id,institution_id,school_year_id);
create unique index if not exists test_definitions_id_institution_uq on public.test_definitions(id,institution_id);
create unique index if not exists scale_versions_id_institution_test_uq on public.scale_versions(id,institution_id,test_id);
create unique index if not exists test_results_one_per_student_test_day_uq on public.test_results(school_year_id,student_id,test_id,tested_on);

alter table public.coach_notebook add column if not exists school_year_id uuid;
alter table public.coach_notebook alter column school_year_id set not null;
create index if not exists coach_notebook_owner_year_idx on public.coach_notebook(owner_id,school_year_id,created_at desc);
alter table public.test_definitions add column if not exists duration_seconds integer check(duration_seconds is null or duration_seconds>0);
do $$ begin if not exists(select 1 from pg_constraint where conname='scale_versions_version_positive') then alter table public.scale_versions add constraint scale_versions_version_positive check(version>0); end if; end $$;
update public.test_definitions set duration_seconds=60 where duration_seconds is null and lower(name) in ('pompes','abdominaux');
do $$ begin
  if not exists(select 1 from pg_constraint where conname='students_number_nonblank') then alter table public.students add constraint students_number_nonblank check(length(trim(student_number))>0); end if;
  if not exists(select 1 from pg_constraint where conname='students_name_nonblank') then alter table public.students add constraint students_name_nonblank check(length(trim(full_name))>0); end if;
  if not exists(select 1 from pg_constraint where conname='classes_name_nonblank') then alter table public.classes add constraint classes_name_nonblank check(length(trim(name))>0); end if;
  if not exists(select 1 from pg_constraint where conname='observations_body_nonblank') then alter table public.observations add constraint observations_body_nonblank check(length(trim(body))>0); end if;
  if not exists(select 1 from pg_constraint where conname='coach_notebook_body_nonblank') then alter table public.coach_notebook add constraint coach_notebook_body_nonblank check(length(trim(body))>0); end if;
end $$;
create or replace function public.normalize_student_identity() returns trigger language plpgsql as $$
begin
  new.student_number:=translate(trim(coalesce(new.student_number,'')),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789');
  new.full_name:=trim(coalesce(new.full_name,''));
  return new;
end $$;
drop trigger if exists student_identity_normalize on public.students;
create trigger student_identity_normalize before insert or update of student_number,full_name on public.students for each row execute function public.normalize_student_identity();
revoke all on function public.normalize_student_identity() from public;

alter table public.test_results add column if not exists duration_seconds numeric(8,2) check(duration_seconds is null or duration_seconds>0);
alter table public.test_results add column if not exists speed_kmh numeric(8,3) check(speed_kmh is null or speed_kmh>0);
alter table public.test_results add column if not exists speed_ms numeric(8,3) check(speed_ms is null or speed_ms>0);
alter table public.test_results add column if not exists distance_m numeric(10,2) check(distance_m is null or distance_m>=0);
alter table public.test_results add column if not exists rate_per_minute numeric(10,2) check(rate_per_minute is null or rate_per_minute>=0);
alter table public.test_results add column if not exists rate_per_second numeric(10,4) check(rate_per_second is null or rate_per_second>=0);
alter table public.test_results add column if not exists average_rep_seconds numeric(10,4) check(average_rep_seconds is null or average_rep_seconds>=0);
alter table public.test_results add column if not exists shuttle_seconds numeric(8,3) check(shuttle_seconds is null or shuttle_seconds>0);
alter table public.test_results add column if not exists shuttles_completed integer check(shuttles_completed is null or shuttles_completed>=0);
do $$ begin
  if not exists(select 1 from pg_constraint where conname='test_results_raw_nonnegative') then alter table public.test_results add constraint test_results_raw_nonnegative check(raw_value>=0); end if;
  if not exists(select 1 from pg_constraint where conname='test_definitions_duration_positive') then alter table public.test_definitions add constraint test_definitions_duration_positive check(duration_seconds is null or duration_seconds>0); end if;
  if not exists(select 1 from pg_constraint where conname='test_results_duration_positive') then alter table public.test_results add constraint test_results_duration_positive check(duration_seconds is null or duration_seconds>0); end if;
  if not exists(select 1 from pg_constraint where conname='test_results_speed_positive') then alter table public.test_results add constraint test_results_speed_positive check(speed_kmh is null or speed_kmh>0); end if;
  if not exists(select 1 from pg_constraint where conname='test_results_shuttle_positive') then alter table public.test_results add constraint test_results_shuttle_positive check(shuttle_seconds is null or shuttle_seconds>0); end if;
  if not exists(select 1 from pg_constraint where conname='test_results_shuttles_nonnegative') then alter table public.test_results add constraint test_results_shuttles_nonnegative check(shuttles_completed is null or shuttles_completed>=0); end if;
  if not exists(select 1 from pg_constraint where conname='test_results_distance_nonnegative') then alter table public.test_results add constraint test_results_distance_nonnegative check(distance_m is null or distance_m>=0); end if;
end $$;
alter table public.rehab_alerts add column if not exists returned_at timestamptz;
alter table public.rehab_alerts add column if not exists last_counted_session_id uuid;

create table if not exists public.institution_facilities(
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  name text not null,
  facility_type text not null default '',
  description text not null default '',
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  unique(institution_id,name)
);
do $$ begin if not exists(select 1 from pg_constraint where conname='institution_facilities_name_nonblank') then alter table public.institution_facilities add constraint institution_facilities_name_nonblank check(length(trim(name))>0); end if; end $$;
create index if not exists institution_facilities_inst_idx on public.institution_facilities(institution_id);
alter table public.institution_facilities enable row level security;
create policy facilities_read on public.institution_facilities for select to authenticated using(institution_id=public.current_institution_id());
create policy facilities_admin_insert on public.institution_facilities for insert to authenticated with check(institution_id=public.current_institution_id() and public.is_institution_admin());
create policy facilities_admin_update on public.institution_facilities for update to authenticated using(institution_id=public.current_institution_id() and public.is_institution_admin()) with check(institution_id=public.current_institution_id() and public.is_institution_admin());
create policy facilities_admin_delete on public.institution_facilities for delete to authenticated using(institution_id=public.current_institution_id() and public.is_institution_admin());
grant select,insert,update,delete on public.institution_facilities to authenticated;

-- Signup links the pending account to an institution by its published slug/code.
-- The user cannot assign a role or activate their own account.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_institution uuid; v_slug text;
begin
  v_slug:=lower(trim(coalesce(new.raw_user_meta_data->>'institution_slug','')));
  if v_slug='' then
    if exists(select 1 from public.institutions) then raise exception 'Institution code is required'; end if;
    insert into public.profiles(id,email,full_name,role,status,institution_id)
    values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'full_name',''),'coach','pending',null)
    on conflict(id) do nothing;
    return new;
  end if;
  select id into v_institution from public.institutions where slug=v_slug;
  if v_institution is null then raise exception 'Institution code was not found'; end if;
  insert into public.profiles(id,email,full_name,role,status,institution_id)
  values(new.id,coalesce(new.email,''),coalesce(new.raw_user_meta_data->>'full_name',''),'coach','pending',v_institution)
  on conflict(id) do nothing;
  if v_institution is not null then
    insert into public.institution_memberships(institution_id,user_id,role,status)
    values(v_institution,new.id,'coach','pending') on conflict(institution_id,user_id) do nothing;
  end if;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
revoke all on function public.handle_new_user() from public;

-- Archived-year protection checks both sides of an UPDATE so rows cannot be moved out of an archived year.
create or replace function public.guard_active_year() returns trigger language plpgsql as $$
begin
  if tg_op='DELETE' then
    if exists(select 1 from public.school_years where id=old.school_year_id and (archived_at is not null or not is_current)) then raise exception 'Archived school year is read-only'; end if;
    return old;
  elsif tg_op='UPDATE' then
    if exists(select 1 from public.school_years where id=old.school_year_id and (archived_at is not null or not is_current))
       or exists(select 1 from public.school_years where id=new.school_year_id and (archived_at is not null or not is_current)) then raise exception 'Archived school year is read-only'; end if;
    return new;
  else
    if exists(select 1 from public.school_years where id=new.school_year_id and (archived_at is not null or not is_current)) then raise exception 'Archived school year is read-only'; end if;
    return new;
  end if;
end $$;

-- Validate all cross-table ownership paths at the database boundary.
do $$ begin
  if not exists(select 1 from pg_constraint where conname='coach_notebook_year_same_institution_fk') then
    alter table public.coach_notebook add constraint coach_notebook_year_same_institution_fk foreign key(school_year_id,institution_id) references public.school_years(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='classes_year_same_institution_fk') then
    alter table public.classes add constraint classes_year_same_institution_fk foreign key(school_year_id,institution_id) references public.school_years(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='students_year_same_institution_fk') then
    alter table public.students add constraint students_year_same_institution_fk foreign key(school_year_id,institution_id) references public.school_years(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='lesson_plans_year_same_institution_fk') then
    alter table public.lesson_plans add constraint lesson_plans_year_same_institution_fk foreign key(school_year_id,institution_id) references public.school_years(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='scale_test_same_institution_fk') then
    alter table public.scale_versions add constraint scale_test_same_institution_fk foreign key(test_id,institution_id) references public.test_definitions(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='students_class_same_year_fk') then
    alter table public.students add constraint students_class_same_year_fk foreign key(class_id,institution_id,school_year_id) references public.classes(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='students_class_same_institution_fk') then
    alter table public.students add constraint students_class_same_institution_fk foreign key(class_id,institution_id) references public.classes(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='sessions_year_same_institution_fk') then
    alter table public.sessions add constraint sessions_year_same_institution_fk foreign key(school_year_id,institution_id) references public.school_years(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='sessions_plan_same_year_fk') then
    alter table public.sessions add constraint sessions_plan_same_year_fk foreign key(lesson_plan_id,institution_id,school_year_id) references public.lesson_plans(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='sessions_plan_same_institution_fk') then
    alter table public.sessions add constraint sessions_plan_same_institution_fk foreign key(lesson_plan_id,institution_id) references public.lesson_plans(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='attendance_student_same_year_fk') then
    alter table public.attendance add constraint attendance_student_same_year_fk foreign key(student_id,institution_id,school_year_id) references public.students(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='attendance_session_same_year_fk') then
    alter table public.attendance add constraint attendance_session_same_year_fk foreign key(session_id,institution_id,school_year_id) references public.sessions(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='results_student_same_year_fk') then
    alter table public.test_results add constraint results_student_same_year_fk foreign key(student_id,institution_id,school_year_id) references public.students(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='results_test_same_institution_fk') then
    alter table public.test_results add constraint results_test_same_institution_fk foreign key(test_id,institution_id) references public.test_definitions(id,institution_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='results_scale_same_test_fk') then
    alter table public.test_results add constraint results_scale_same_test_fk foreign key(scale_version_id,institution_id,test_id) references public.scale_versions(id,institution_id,test_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='measurements_student_same_year_fk') then
    alter table public.student_measurements add constraint measurements_student_same_year_fk foreign key(student_id,institution_id,school_year_id) references public.students(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='observations_student_same_year_fk') then
    alter table public.observations add constraint observations_student_same_year_fk foreign key(student_id,institution_id,school_year_id) references public.students(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='rehab_last_session_same_year_fk') then
    alter table public.rehab_alerts add constraint rehab_last_session_same_year_fk foreign key(last_counted_session_id,institution_id,school_year_id) references public.sessions(id,institution_id,school_year_id);
  end if;
  if not exists(select 1 from pg_constraint where conname='rehab_student_same_year_fk') then
    alter table public.rehab_alerts add constraint rehab_student_same_year_fk foreign key(student_id,institution_id,school_year_id) references public.students(id,institution_id,school_year_id);
  end if;
end $$;

drop trigger if exists coach_notebook_year_guard on public.coach_notebook;
create trigger coach_notebook_year_guard before insert or update or delete on public.coach_notebook for each row execute function public.guard_active_year();

create policy observations_coach_insert on public.observations for insert to authenticated with check(institution_id=public.current_institution_id() and author_id=auth.uid());

create or replace function public.calculate_measurement_bmi() returns trigger language plpgsql as $$
begin
  if new.weight_kg is not null and new.height_m is not null and new.weight_kg>0 and new.height_m>0 then
    new.bmi:=round(new.weight_kg/(new.height_m*new.height_m),2);
  else
    new.bmi:=null;
  end if;
  return new;
end $$;
drop trigger if exists student_measurement_bmi_calc on public.student_measurements;
create trigger student_measurement_bmi_calc before insert or update on public.student_measurements for each row execute function public.calculate_measurement_bmi();

create or replace function public.guard_measurement_date_in_year() returns trigger
language plpgsql set search_path=public as $$
begin
  if not exists(select 1 from public.school_years y where y.id=new.school_year_id and y.institution_id=new.institution_id and y.is_current and y.archived_at is null and new.measured_on>=y.start_date and (y.end_date is null or new.measured_on<=y.end_date)) then
    raise exception 'Measurement date is outside the active school year';
  end if;
  return new;
end $$;
drop trigger if exists measurement_date_in_year_guard on public.student_measurements;
create trigger measurement_date_in_year_guard before insert or update of measured_on,school_year_id,institution_id on public.student_measurements for each row execute function public.guard_measurement_date_in_year();
revoke all on function public.guard_measurement_date_in_year() from public;

-- Snapshot the actual active coach name server-side; clients cannot forge session attribution.
create or replace function public.set_session_coach_snapshot() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_name text;
begin
  select full_name into v_name from public.profiles where id=new.coach_id and institution_id=new.institution_id and status='active';
  if not found or nullif(trim(coalesce(v_name,'')),'') is null then raise exception 'Session coach must be an active member of this institution'; end if;
  new.coach_name_snapshot:=v_name;
  return new;
end $$;
drop trigger if exists session_coach_snapshot_guard on public.sessions;
create trigger session_coach_snapshot_guard before insert or update of coach_id on public.sessions for each row execute function public.set_session_coach_snapshot();
revoke all on function public.set_session_coach_snapshot() from public;

create or replace function public.guard_session_date_in_year() returns trigger
language plpgsql set search_path=public as $$
begin
  if not exists(select 1 from public.school_years y where y.id=new.school_year_id and y.institution_id=new.institution_id and y.is_current and y.archived_at is null and new.session_date>=y.start_date and (y.end_date is null or new.session_date<=y.end_date)) then
    raise exception 'Session date is outside the active school year';
  end if;
  return new;
end $$;
drop trigger if exists session_date_in_year_guard on public.sessions;
create trigger session_date_in_year_guard before insert or update of session_date,school_year_id,institution_id on public.sessions for each row execute function public.guard_session_date_in_year();
revoke all on function public.guard_session_date_in_year() from public;

create or replace function public.protect_session_attribution() returns trigger
language plpgsql set search_path=public as $$
begin
  if new.coach_id is distinct from old.coach_id
     or new.coach_name_snapshot is distinct from old.coach_name_snapshot
     or new.institution_id is distinct from old.institution_id
     or new.school_year_id is distinct from old.school_year_id
     or new.session_date is distinct from old.session_date
     or new.start_time is distinct from old.start_time then
    raise exception 'Session attribution and original start details are immutable';
  end if;
  return new;
end $$;
drop trigger if exists session_attribution_immutable on public.sessions;
create trigger session_attribution_immutable before update on public.sessions for each row execute function public.protect_session_attribution();
revoke all on function public.protect_session_attribution() from public;

create or replace function public.guard_closed_session() returns trigger language plpgsql as $$
begin
  if tg_op='UPDATE' and old.end_time is not null then raise exception 'Closed sessions are immutable'; end if;
  if tg_op='DELETE' and old.end_time is not null then raise exception 'Closed sessions cannot be deleted'; end if;
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
drop trigger if exists closed_session_guard on public.sessions;
create trigger closed_session_guard before update or delete on public.sessions for each row execute function public.guard_closed_session();

do $$ begin
  if not exists(select 1 from pg_constraint where conname='attendance_late_flag_consistent') then
    alter table public.attendance add constraint attendance_late_flag_consistent check(is_late=(status='late'));
  end if;
  if not exists(select 1 from pg_constraint where conname='attendance_reason_only_when_absent') then
    alter table public.attendance add constraint attendance_reason_only_when_absent check(absence_reason is null or status='absent');
  end if;
  if not exists(select 1 from pg_constraint where conname='attendance_absence_requires_reason') then
    alter table public.attendance add constraint attendance_absence_requires_reason check(status<>'absent' or absence_reason is not null);
  end if;
end $$;

-- A coach can record attendance only in their own session; administrators can correct institution records.
create or replace function public.guard_attendance_session_owner() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_coach uuid; v_end_time time; v_session_date date;
begin
  if new.session_id is null then raise exception 'Attendance must be attached to an actual PE session'; end if;
  select coach_id,end_time,session_date into v_coach,v_end_time,v_session_date from public.sessions where id=new.session_id and institution_id=new.institution_id and school_year_id=new.school_year_id;
  if v_coach is null then raise exception 'Session does not belong to this institution/year'; end if;
  if new.attendance_date is distinct from v_session_date then raise exception 'Attendance date must match its PE session date'; end if;
  if v_end_time is not null and not public.is_institution_admin() then raise exception 'Session is closed; attendance cannot be changed by a coach'; end if;
  if not public.is_institution_admin() and v_coach<>auth.uid() then raise exception 'A coach may only record attendance in their own session'; end if;
  if not public.is_institution_admin() and new.recorded_by<>auth.uid() then raise exception 'Attendance recorder must be the signed-in coach'; end if;
  return new;
end $$;
drop trigger if exists attendance_session_owner_guard on public.attendance;
create trigger attendance_session_owner_guard before insert or update on public.attendance for each row execute function public.guard_attendance_session_owner();

create or replace function public.is_institution_head() returns boolean language sql stable security definer set search_path=public as $$ select coalesce(public.current_member_role()='institution_admin',false) $$;
create or replace function public.approve_institution_member(p_user_id uuid,p_role public.member_role,p_approve boolean default true)
returns void language plpgsql security definer set search_path=public as $$
declare i uuid; v_profile public.profiles%rowtype;
begin
  i:=public.current_institution_id();
  if i is null or not public.is_institution_head() then raise exception 'Institution administrator only'; end if;
  if p_role not in ('admin','coach') then raise exception 'Invalid member role'; end if;
  select * into v_profile from public.profiles where id=p_user_id for update;
  if not found or v_profile.institution_id is distinct from i or v_profile.status not in ('pending','rejected') then
    raise exception 'Pending profile not found in this institution';
  end if;
  if exists(select 1 from public.institution_memberships m where m.user_id=p_user_id and m.institution_id<>i and m.status='active') then
    raise exception 'This account already belongs to another institution';
  end if;
  update public.profiles set role=p_role,status=case when p_approve then 'active'::public.member_status else 'rejected'::public.member_status end
  where id=p_user_id and institution_id=i and status in ('pending','rejected');
  if not found then raise exception 'Pending profile changed; reload and retry'; end if;
  insert into public.institution_memberships(institution_id,user_id,role,status)
  values(i,p_user_id,p_role,case when p_approve then 'active'::public.member_status else 'rejected'::public.member_status end)
  on conflict(institution_id,user_id) do update set role=excluded.role,status=excluded.status;
end $$;

create or replace function public.approve_institution_admin(p_user_id uuid,p_institution_id uuid,p_full_name text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_profile public.profiles%rowtype;
begin
  if not public.is_platform_owner() then raise exception 'Platform owner only'; end if;
  if not exists(select 1 from public.institutions where id=p_institution_id) then raise exception 'Institution not found'; end if;
  select * into v_profile from public.profiles where id=p_user_id for update;
  if not found or v_profile.status not in ('pending','rejected') or (v_profile.institution_id is not null and v_profile.institution_id<>p_institution_id) then
    raise exception 'Pending profile is not eligible for this institution';
  end if;
  if exists(select 1 from public.institution_memberships m where m.user_id=p_user_id and m.institution_id<>p_institution_id and m.status='active') then
    raise exception 'This account already belongs to another institution';
  end if;
  update public.profiles set institution_id=p_institution_id,role='institution_admin',status='active',full_name=coalesce(nullif(p_full_name,''),full_name)
  where id=p_user_id and status in ('pending','rejected') and (institution_id is null or institution_id=p_institution_id);
  if not found then raise exception 'Pending profile changed; reload and retry'; end if;
  insert into public.institution_memberships(institution_id,user_id,role,status) values(p_institution_id,p_user_id,'institution_admin','active')
  on conflict(institution_id,user_id) do update set role='institution_admin',status='active';
end $$;
revoke all on function public.is_institution_head() from public;
grant execute on function public.is_institution_head() to authenticated;


-- Only institution administrators can alter institution identity and branding.
create policy institution_admin_update on public.institutions for update to authenticated
using(id=public.current_institution_id() and public.is_institution_admin())
with check(id=public.current_institution_id() and public.is_institution_admin());

-- Storage writes are restricted to institutional administrators; members may read files in their institution.
drop policy if exists sp_storage_insert on storage.objects;
create policy sp_storage_insert on storage.objects for insert to authenticated
with check(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text and public.is_institution_admin());
drop policy if exists sp_storage_update on storage.objects;
create policy sp_storage_update on storage.objects for update to authenticated
using(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text and public.is_institution_admin())
with check(bucket_id='sport-performance' and (storage.foldername(name))[1]=public.current_institution_id()::text and public.is_institution_admin());

create or replace function public.validate_scale_rules() returns trigger language plpgsql set search_path=public as $$
declare v_row jsonb; v_raw numeric; v_score numeric; v_seen numeric[]:=array[]::numeric[];
begin
  if jsonb_typeof(new.rules)<>'array' or jsonb_array_length(new.rules)=0 then raise exception 'BARÈME must contain at least one row'; end if;
  for v_row in select value from jsonb_array_elements(new.rules) loop
    if jsonb_typeof(v_row->'rawValue') is distinct from 'number' or jsonb_typeof(v_row->'score') is distinct from 'number' then raise exception 'Each BARÈME row must contain numeric rawValue and score'; end if;
    v_raw:=(v_row->>'rawValue')::numeric; v_score:=(v_row->>'score')::numeric;
    if v_raw<0 or v_score<0 then raise exception 'BARÈME values and scores must be non-negative'; end if;
    if v_raw=any(v_seen) then raise exception 'Duplicate BARÈME raw value: %',v_raw; end if;
    v_seen:=array_append(v_seen,v_raw);
  end loop;
  return new;
end $$;
drop trigger if exists scale_rules_validate on public.scale_versions;
create trigger scale_rules_validate before insert on public.scale_versions for each row execute function public.validate_scale_rules();

update storage.buckets set allowed_mime_types=array[
  'image/png','image/jpeg','image/webp','application/pdf','application/msword','application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/plain','text/csv'
] where id='sport-performance';

-- Immutable scale snapshots: a new BARÈME means a new version, never editing an old one.
create or replace function public.prevent_scale_version_mutation() returns trigger
language plpgsql set search_path=public as $$
begin raise exception 'BARÈME versions are immutable; create a new version instead'; end $$;
drop trigger if exists scale_version_immutable on public.scale_versions;
create trigger scale_version_immutable before update or delete on public.scale_versions for each row execute function public.prevent_scale_version_mutation();

-- Official results remain editable by institution administrators for correction; coaches have no write policy.

-- Rehab alerts start after five consecutive absences in real PE sessions.
-- The return session and the next attended PE session are counted only when the session ends.
create or replace function public.consume_rehab_session(p_student_id uuid,p_school_year_id uuid,p_session_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  -- Count only an actually attended/late session, never the fifth absence itself.
  -- The session-end trigger makes the return session and the next attended session
  -- count exactly once, even if attendance was entered after the session ended.
  update public.rehab_alerts r set
    remaining_sessions=greatest(0,r.remaining_sessions-1),
    last_counted_session_id=p_session_id
  where r.student_id=p_student_id and r.school_year_id=p_school_year_id
    and r.returned_at is not null and r.remaining_sessions>0 and r.handled_at is null
    and r.last_counted_session_id is distinct from p_session_id
    and exists(select 1 from public.attendance a where a.student_id=p_student_id
      and a.school_year_id=p_school_year_id and a.session_id=p_session_id
      and a.status in ('present','late'));
end $$;

create or replace function public.update_rehab_after_attendance() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_absence_streak integer; v_session_end time; v_session_date date; v_session_start time;
begin
  if new.session_id is null then return new; end if;
  select session_date,start_time,end_time into v_session_date,v_session_start,v_session_end from public.sessions where id=new.session_id and institution_id=new.institution_id and school_year_id=new.school_year_id;
  if not found then raise exception 'Attendance session does not exist in this institution/year'; end if;
  if new.status='absent' then
    select count(*) into v_absence_streak from (
      select a.status from public.attendance a join public.sessions s on s.id=a.session_id
      where a.student_id=new.student_id and a.school_year_id=new.school_year_id
        and (s.session_date,s.start_time)<=(v_session_date,v_session_start)
      order by s.session_date desc,s.start_time desc,a.created_at desc limit 5
    ) last_sessions where status='absent';
    if v_absence_streak=5 then
      insert into public.rehab_alerts(institution_id,school_year_id,student_id,triggered_on,remaining_sessions)
      select new.institution_id,new.school_year_id,new.student_id,new.attendance_date,2
      where not exists(select 1 from public.rehab_alerts r where r.student_id=new.student_id and r.school_year_id=new.school_year_id and r.remaining_sessions>0 and r.handled_at is null);
    end if;
  elsif new.status in ('present','late') then
    update public.rehab_alerts set returned_at=coalesce(returned_at,now())
      where student_id=new.student_id and school_year_id=new.school_year_id and remaining_sessions>0 and handled_at is null;
    if v_session_end is not null then perform public.consume_rehab_session(new.student_id,new.school_year_id,new.session_id); end if;
  end if;
  return new;
end $$;
drop trigger if exists attendance_rehab_lifecycle on public.attendance;
create trigger attendance_rehab_lifecycle after insert or update of status on public.attendance for each row execute function public.update_rehab_after_attendance();

create or replace function public.update_rehab_after_session_end() returns trigger
language plpgsql security definer set search_path=public as $$
declare v_row record;
begin
  if old.end_time is null and new.end_time is not null then
    for v_row in select student_id from public.attendance where session_id=new.id and school_year_id=new.school_year_id loop
      perform public.consume_rehab_session(v_row.student_id,new.school_year_id,new.id);
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists session_rehab_lifecycle on public.sessions;
create trigger session_rehab_lifecycle after update of end_time on public.sessions for each row execute function public.update_rehab_after_session_end();
revoke all on function public.consume_rehab_session(uuid,uuid,uuid) from public;
revoke all on function public.update_rehab_after_session_end() from public;
revoke all on function public.update_rehab_after_attendance() from public;

create or replace function public.mark_rehab_alert_handled(p_alert_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
  update public.rehab_alerts set handled_at=now(),remaining_sessions=0
  where id=p_alert_id and institution_id=public.current_institution_id() and public.current_member_role() is not null and returned_at is not null and remaining_sessions>0 and handled_at is null;
  if not found then raise exception 'Alert not found or not authorized'; end if;
end $$;
revoke all on function public.mark_rehab_alert_handled(uuid) from public;
grant execute on function public.mark_rehab_alert_handled(uuid) to authenticated;

-- Rehab alerts are lifecycle-managed only by database triggers and the guarded handled RPC.
revoke insert,update,delete on public.rehab_alerts from authenticated;
-- Attendance corrections use upsert/update; deleting an attendance row would invalidate the rehab streak history.
revoke delete on public.attendance from authenticated;

-- Administrative CSV/paste import RPC: validates institution/year and skips duplicate student codes.
create or replace function public.bulk_add_students(p_school_year_id uuid,p_rows jsonb)
returns table(inserted_count integer,duplicate_count integer)
language plpgsql security definer set search_path=public as $$
declare v_inserted integer:=0; v_duplicates integer:=0; v_row jsonb; v_number text; v_name text; v_class uuid;
begin
  if not public.is_institution_admin() then raise exception 'Institution administrator only'; end if;
  if p_school_year_id is null or not exists(select 1 from public.school_years where id=p_school_year_id and institution_id=public.current_institution_id() and is_current and archived_at is null) then raise exception 'Invalid or archived school year'; end if;
  if p_rows is null or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>5000 then raise exception 'Rows must be a JSON array of at most 5000 students'; end if;
  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_number:=nullif(translate(trim(v_row->>'student_number'),'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789'),''); v_name:=nullif(trim(v_row->>'full_name'),'');
    if v_number is null or v_name is null then raise exception 'Student number and full name are required'; end if;
    v_class:=nullif(v_row->>'class_id','')::uuid;
    if v_class is not null and not exists(select 1 from public.classes where id=v_class and institution_id=public.current_institution_id() and school_year_id=p_school_year_id) then raise exception 'Class does not belong to this institution and year'; end if;
    insert into public.students(institution_id,school_year_id,student_number,full_name,class_id)
    values(public.current_institution_id(),p_school_year_id,v_number,v_name,v_class) on conflict(institution_id,school_year_id,student_number) do nothing;
    if found then v_inserted:=v_inserted+1; else v_duplicates:=v_duplicates+1; end if;
  end loop;
  return query select v_inserted,v_duplicates;
end $$;
revoke all on function public.bulk_add_students(uuid,jsonb) from public;
grant execute on function public.bulk_add_students(uuid,jsonb) to authenticated;

-- Atomic bulk result import. The database recalculates the official BARÈME score and all derived metrics.
create or replace function public.bulk_add_test_results(p_school_year_id uuid,p_rows jsonb)
returns table(inserted_count integer)
language plpgsql security definer set search_path=public as $$
declare v_row jsonb; v_student uuid; v_test_id uuid; v_scale_id uuid; v_raw numeric; v_score numeric; v_expected numeric; v_duration numeric; v_speed numeric; v_test public.test_definitions%rowtype; v_scale public.scale_versions%rowtype; v_date date; v_count integer:=0; v_rate_min numeric; v_rate_sec numeric; v_avg_sec numeric; v_ms numeric; v_shuttle_seconds numeric; v_distance numeric; v_shuttles integer;
begin
  if not public.is_institution_admin() then raise exception 'Institution administrator only'; end if;
  if p_school_year_id is null or not exists(select 1 from public.school_years where id=p_school_year_id and institution_id=public.current_institution_id() and is_current and archived_at is null) then raise exception 'Invalid or archived school year'; end if;
  if p_rows is null or jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)=0 or jsonb_array_length(p_rows)>2000 then raise exception 'Rows must be a JSON array containing 1 to 2000 results'; end if;
  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_student:=nullif(v_row->>'student_id','')::uuid; v_test_id:=nullif(v_row->>'test_id','')::uuid; v_scale_id:=nullif(v_row->>'scale_version_id','')::uuid;
    if jsonb_typeof(v_row->'raw_value') is distinct from 'number' then raise exception 'Raw performance must be numeric'; end if;
    v_raw:=(v_row->>'raw_value')::numeric; if v_raw<0 then raise exception 'Raw performance cannot be negative'; end if; v_date:=coalesce(nullif(v_row->>'tested_on','')::date,current_date);
    if not exists(select 1 from public.school_years y where y.id=p_school_year_id and y.institution_id=public.current_institution_id() and y.is_current and y.archived_at is null and v_date>=y.start_date and (y.end_date is null or v_date<=y.end_date)) then raise exception 'Test date is outside the selected school year'; end if;
    select * into v_test from public.test_definitions where id=v_test_id and institution_id=public.current_institution_id() and is_active;
    if not found then raise exception 'Test is inactive or belongs to another institution'; end if;
    if (lower(v_test.name) like '%pompe%' or lower(v_test.name) like '%abdominaux%' or lower(v_test.name) like '%abdos%') and v_raw<>trunc(v_raw) then raise exception 'Repetition count must be an integer'; end if;
    if not exists(select 1 from public.students where id=v_student and institution_id=public.current_institution_id() and school_year_id=p_school_year_id and not archived) then raise exception 'Student is not active in this school year'; end if;
    if exists(select 1 from public.test_results where student_id=v_student and test_id=v_test_id and school_year_id=p_school_year_id and tested_on=v_date) then raise exception 'A result for this student/test/date already exists; use result correction instead'; end if;
    v_duration:=coalesce(nullif(v_row->>'duration_seconds','')::numeric,v_test.duration_seconds::numeric);
    v_speed:=nullif(v_row->>'speed_kmh','')::numeric; v_shuttles:=nullif(v_row->>'shuttles_completed','')::integer;
    if v_duration is not null and v_duration<=0 then raise exception 'Duration must be positive'; end if;
    if v_speed is not null and (v_speed<=0 or lower(v_test.name) not like '%navette%') then raise exception 'Speed is only accepted for NAVETTE and must be positive'; end if;
    if v_shuttles is not null and (v_shuttles<0 or lower(v_test.name) not like '%navette%') then raise exception 'Completed shuttle count is only accepted for NAVETTE'; end if;
    v_expected:=null; v_score:=nullif(v_row->>'score','')::numeric;
    select * into v_scale from public.scale_versions where institution_id=public.current_institution_id() and test_id=v_test_id and valid_from<=v_date order by valid_from desc,version desc limit 1;
    if v_scale.id is distinct from v_scale_id then raise exception 'Selected BARÈME version is not the version effective on the test date'; end if;
    if v_scale.id is not null then
      select (r->>'score')::numeric into v_expected from jsonb_array_elements(v_scale.rules) r where (r->>'rawValue')::numeric>=v_raw order by (r->>'rawValue')::numeric limit 1;
    end if;
    if v_score is distinct from v_expected then raise exception 'Submitted score does not match the selected BARÈME version'; end if;
    v_ms:=case when v_speed is null then null else round(v_speed/3.6,3) end;
    v_shuttle_seconds:=case when v_speed is null then null else round(72/v_speed,3) end;
    v_distance:=case when v_shuttles is null then null else v_shuttles*20 end;
    v_rate_min:=null;v_rate_sec:=null;v_avg_sec:=null;
    if v_duration is not null and (lower(v_test.name) like '%pompe%' or lower(v_test.name) like '%abdominaux%' or lower(v_test.name) like '%abdos%') then
      v_rate_min:=round(v_raw*60/v_duration,2);v_rate_sec:=round(v_raw/v_duration,4);if v_raw>0 then v_avg_sec:=round(v_duration/v_raw,4);end if;
    end if;
    insert into public.test_results(institution_id,school_year_id,student_id,test_id,scale_version_id,raw_value,score,tested_on,recorded_by,duration_seconds,speed_kmh,speed_ms,shuttle_seconds,shuttles_completed,distance_m,rate_per_minute,rate_per_second,average_rep_seconds)
    values(public.current_institution_id(),p_school_year_id,v_student,v_test_id,v_scale_id,v_raw,v_score,v_date,auth.uid(),v_duration,v_speed,v_ms,v_shuttle_seconds,v_shuttles,v_distance,v_rate_min,v_rate_sec,v_avg_sec);
    v_count:=v_count+1;
  end loop;
  return query select v_count;
end $$;
revoke all on function public.bulk_add_test_results(uuid,jsonb) from public;
grant execute on function public.bulk_add_test_results(uuid,jsonb) to authenticated;

-- Single-result correction is also server-calculated and preserves the correct immutable scale version.
create or replace function public.correct_test_result(p_result_id uuid,p_raw_value numeric,p_tested_on date,p_shuttles_completed integer default null)
returns void language plpgsql security definer set search_path=public as $$
declare v_result public.test_results%rowtype; v_test public.test_definitions%rowtype; v_scale public.scale_versions%rowtype; v_expected numeric; v_duration numeric; v_speed numeric; v_rate_min numeric; v_rate_sec numeric; v_avg_sec numeric; v_ms numeric; v_shuttle_seconds numeric; v_distance numeric; v_shuttles integer;
begin
  if not public.is_institution_admin() then raise exception 'Institution administrator only'; end if;
  if p_raw_value is null or p_raw_value<0 then raise exception 'Raw performance must be non-negative'; end if;
  select * into v_result from public.test_results where id=p_result_id and institution_id=public.current_institution_id() for update;
  if not found or not exists(select 1 from public.school_years where id=v_result.school_year_id and institution_id=v_result.institution_id and is_current and archived_at is null and coalesce(p_tested_on,current_date)>=start_date and (end_date is null or coalesce(p_tested_on,current_date)<=end_date)) then raise exception 'Result not found, its school year is archived, or the correction date is outside the year'; end if;
  select * into v_test from public.test_definitions where id=v_result.test_id and institution_id=v_result.institution_id;
  if not found then raise exception 'Test definition not found'; end if;
  if (lower(v_test.name) like '%pompe%' or lower(v_test.name) like '%abdominaux%' or lower(v_test.name) like '%abdos%') and p_raw_value<>trunc(p_raw_value) then raise exception 'Repetition count must be an integer'; end if;
  if exists(select 1 from public.test_results where student_id=v_result.student_id and test_id=v_result.test_id and school_year_id=v_result.school_year_id and tested_on=coalesce(p_tested_on,current_date) and id<>p_result_id) then raise exception 'Another result already exists for this student/test/date'; end if;
  select * into v_scale from public.scale_versions where test_id=v_result.test_id and institution_id=v_result.institution_id and valid_from<=coalesce(p_tested_on,current_date) order by valid_from desc,version desc limit 1;
  v_expected:=null;
  if found then select (r->>'score')::numeric into v_expected from jsonb_array_elements(v_scale.rules) r where (r->>'rawValue')::numeric>=p_raw_value order by (r->>'rawValue')::numeric limit 1; end if;
  v_duration:=v_result.duration_seconds;v_speed:=v_result.speed_kmh;v_shuttles:=coalesce(p_shuttles_completed,v_result.shuttles_completed);
  if p_shuttles_completed is not null and (p_shuttles_completed<0 or lower(v_test.name) not like '%navette%') then raise exception 'Completed shuttle count is only accepted for NAVETTE'; end if;
  v_ms:=case when v_speed is null then null else round(v_speed/3.6,3) end;
  v_shuttle_seconds:=case when v_ms is null then null else round(72/v_speed,3) end;
  v_distance:=case when v_shuttles is null then null else v_shuttles*20 end;
  v_rate_min:=null;v_rate_sec:=null;v_avg_sec:=null;
  if v_duration is not null and (lower(v_test.name) like '%pompe%' or lower(v_test.name) like '%abdominaux%' or lower(v_test.name) like '%abdos%') then
    v_rate_min:=round(p_raw_value*60/v_duration,2);v_rate_sec:=round(p_raw_value/v_duration,4);if p_raw_value>0 then v_avg_sec:=round(v_duration/p_raw_value,4);end if;
  end if;
  update public.test_results set raw_value=p_raw_value,score=v_expected,scale_version_id=case when v_scale.id is null then null else v_scale.id end,tested_on=coalesce(p_tested_on,current_date),duration_seconds=v_duration,speed_ms=v_ms,shuttle_seconds=v_shuttle_seconds,shuttles_completed=v_shuttles,distance_m=v_distance,rate_per_minute=v_rate_min,rate_per_second=v_rate_sec,average_rep_seconds=v_avg_sec where id=p_result_id;
end $$;
revoke all on function public.correct_test_result(uuid,numeric,date,integer) from public;
grant execute on function public.correct_test_result(uuid,numeric,date,integer) to authenticated;

create or replace function public.create_school_year(p_name text,p_start_date date) returns uuid
language plpgsql security definer set search_path=public as $$
declare i uuid; v_current public.school_years%rowtype; v_id uuid;
begin
  i:=public.current_institution_id();
  if i is null or not public.is_institution_admin() then raise exception 'Institution administrator only'; end if;
  if nullif(trim(coalesce(p_name,'')),'') is null or p_start_date is null then raise exception 'Year name and start date are required'; end if;
  select * into v_current from public.school_years where institution_id=i and is_current for update;
  if found then
    if p_start_date<=v_current.start_date then raise exception 'New school year must start after the current school year start date'; end if;
    update public.school_years set is_current=false,end_date=p_start_date-1,archived_at=now() where id=v_current.id;
  end if;
  insert into public.school_years(institution_id,name,start_date,is_current) values(i,trim(p_name),p_start_date,true) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.create_school_year(text,date) from public;
grant execute on function public.create_school_year(text,date) to authenticated;
create or replace function public.platform_create_institution(p_name text,p_slug text) returns uuid
language plpgsql security definer set search_path=public as $$
declare i uuid;
begin
  if not public.is_platform_owner() then raise exception 'Platform owner only'; end if;
  if p_name is null or length(trim(p_name))<2 or p_slug is null or trim(p_slug) !~ '^[a-z0-9][a-z0-9-]{1,62}$' then raise exception 'Invalid institution name or slug'; end if;
  insert into public.institutions(name,slug) values(trim(p_name),lower(trim(p_slug))) returning id into i;
  insert into public.test_definitions(institution_id,name,unit,higher_is_better,is_active,duration_seconds) values
    (i,'NAVETTE 20m','palier',true,true,null),
    (i,'Pompes','répétitions',true,true,60),
    (i,'Abdominaux','répétitions',true,true,60),
    (i,'Barre fixe / Perfix','répétitions ou secondes',true,true,null);
  return i;
end $$;
revoke all on function public.platform_create_institution(text,text) from public;
grant execute on function public.platform_create_institution(text,text) to authenticated;

revoke all on function public.approve_institution_admin(uuid,uuid,text) from public;
grant execute on function public.approve_institution_admin(uuid,uuid,text) to authenticated;
revoke all on function public.approve_institution_member(uuid,public.member_role,boolean) from public;
grant execute on function public.approve_institution_member(uuid,public.member_role,boolean) to authenticated;

-- School years can only be created through the guarded RPC; official result rows cannot be deleted.
revoke insert,update,delete on public.school_years from authenticated;
revoke insert,update,delete on public.test_results from authenticated;

-- A single authenticated admin may close/open academic years; archived data remains read-only.
revoke all on function public.create_school_year(text,date) from public;
grant execute on function public.create_school_year(text,date) to authenticated;
revoke all on function public.approve_institution_admin(uuid,uuid,text) from public;
revoke all on function public.approve_institution_member(uuid,public.member_role,boolean) from public;
revoke all on function public.platform_create_institution(text,text) from public;
grant execute on function public.approve_institution_admin(uuid,uuid,text) to authenticated;
grant execute on function public.approve_institution_member(uuid,public.member_role,boolean) to authenticated;
grant execute on function public.platform_create_institution(text,text) to authenticated;
