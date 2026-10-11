-- First create Emma and Joey under Supabase Authentication → Users → Add user.
-- Replace these two placeholder email addresses, then run this script in SQL Editor.
-- Passwords are set in Authentication only; do not put them in this script.
begin;
do $$
declare emma_email text:='REPLACE_WITH_EMMA_EMAIL'; joey_email text:='REPLACE_WITH_JOEY_EMAIL'; emma_id uuid; joey_id uuid;
begin
  select id into emma_id from auth.users where lower(email)=lower(emma_email);
  select id into joey_id from auth.users where lower(email)=lower(joey_email);
  if emma_id is null or joey_id is null or emma_id=joey_id then raise exception '请先创建两个不同的账号，并替换上方两处邮箱。'; end if;
  if exists(select 1 from public.garden_members where role='emma' and user_id<>emma_id) or exists(select 1 from public.garden_members where role='joey' and user_id<>joey_id) then raise exception '已有其他账号绑定角色，请先在后台确认，不会自动替换。'; end if;
  insert into public.garden_members(user_id,role) values(emma_id,'emma'),(joey_id,'joey') on conflict(user_id) do update set role=excluded.role;
end; $$;
commit;
