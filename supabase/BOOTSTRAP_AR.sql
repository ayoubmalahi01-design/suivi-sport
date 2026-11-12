-- Execute in Supabase SQL Editor after creating the first user through Authentication.
-- Replace values below. This creates the institution and activates the first platform owner.
-- Never paste a service_role key into the app or share it in chat.
do $$ declare v_user uuid; v_inst uuid; begin
  select id into v_user from auth.users where email = 'OWNER_EMAIL_HERE';
  if v_user is null then raise exception 'Create the owner account in Authentication first'; end if;
  insert into public.institutions(name,slug) values('INSTITUTION_NAME_HERE','INSTITUTION_SLUG_HERE') returning id into v_inst;
  insert into public.profiles(id,full_name,email,role,status,institution_id)
  values(v_user,'OWNER_FULL_NAME_HERE','OWNER_EMAIL_HERE','platform_owner','active',v_inst)
  on conflict(id) do update set role='platform_owner',status='active',institution_id=excluded.institution_id;
  insert into public.institution_memberships(institution_id,user_id,role,status)
  values(v_inst,v_user,'platform_owner','active')
  on conflict(institution_id,user_id) do update set role='platform_owner',status='active';
  insert into public.school_years(institution_id,name,start_date,is_current) values(v_inst,'SCHOOL_YEAR_NAME_HERE','SCHOOL_YEAR_START_DATE_HERE'::date,true);
  insert into public.test_definitions(institution_id,name,unit,higher_is_better,is_active,duration_seconds) values
   (v_inst,'NAVETTE 20m','palier',true,true,null),
   (v_inst,'Pompes','répétitions',true,true,60),
   (v_inst,'Abdominaux','répétitions',true,true,60),
   (v_inst,'Barre fixe / Perfix','répétitions ou secondes',true,true,null)
  on conflict(institution_id,name) do nothing;
end $$;
