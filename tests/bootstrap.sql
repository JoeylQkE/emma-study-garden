-- Only for an empty local test PostgreSQL instance, not a Supabase project.
create schema auth;
create table auth.users(id uuid primary key,email text);
create role anon nologin;
create role authenticated nologin;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth,public to authenticated,anon;
grant execute on function auth.uid() to authenticated,anon;
