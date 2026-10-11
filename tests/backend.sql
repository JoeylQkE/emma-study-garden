-- Local PostgreSQL test fixture only. Everything is rolled back.
begin;
delete from public.garden_requests;
update public.garden_shared set state='{"version":3,"days":[],"tasks":{},"luck":{},"probabilities":{},"draws":[],"unlocked":[],"bonus":0,"makeupEarned":[],"makeups":{},"rewards":[]}',imported=false;
insert into auth.users(id,email) values ('11111111-1111-1111-1111-111111111111','emma@test.invalid'),('22222222-2222-2222-2222-222222222222','joey@test.invalid'),('33333333-3333-3333-3333-333333333333','outsider@test.invalid') on conflict do nothing;
insert into public.garden_members(user_id,role) values ('11111111-1111-1111-1111-111111111111','emma'),('22222222-2222-2222-2222-222222222222','joey') on conflict do nothing;
create or replace function public.garden_today() returns date language sql stable set search_path='' as $$ select date '2026-10-12' $$;
set local role authenticated;
set local request.jwt.claim.sub='11111111-1111-1111-1111-111111111111';
do $$ declare r jsonb; begin
  begin perform public.garden_action('check_in','00000000-0000-0000-0000-000000000001');raise exception 'FAIL: incomplete check-in accepted'; exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
  perform public.garden_action('task','00000000-0000-0000-0000-000000000002',0,true);
  perform public.garden_action('task','00000000-0000-0000-0000-000000000003',3,true);
  perform public.garden_action('task','00000000-0000-0000-0000-000000000004',4,true);
  r:=public.garden_action('check_in','00000000-0000-0000-0000-000000000005');
  if (r->'result'->>'probability')::numeric<>.35 then raise exception 'FAIL: wrong chance';end if;
  if jsonb_array_length(r->'state'->'days')<>1 then raise exception 'FAIL: missing check-in';end if;
  if public.garden_action('check_in','00000000-0000-0000-0000-000000000005')<>r then raise exception 'FAIL: idempotency changed response';end if;
  r:=public.garden_action('check_in','00000000-0000-0000-0000-000000000006');
  if r->'result'->>'already'<>'true' then raise exception 'FAIL: check-in duplicate not detected';end if;
  begin perform public.garden_action('task','00000000-0000-0000-0000-000000000007',1,true);raise exception 'FAIL: signed tasks editable';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end; $$;
set local request.jwt.claim.sub='22222222-2222-2222-2222-222222222222';
do $$ declare r jsonb;begin
 r:=public.garden_snapshot();if r->>'role'<>'joey' or jsonb_array_length(r->'state'->'days')<>1 then raise exception 'FAIL: viewer cannot see shared record';end if;
 begin perform public.garden_action('draw','00000000-0000-0000-0000-000000000008');raise exception 'FAIL: viewer wrote';exception when insufficient_privilege then null;end;
 begin update public.garden_shared set state='{}';raise exception 'FAIL: direct table write accepted';exception when insufficient_privilege then null;end;
end; $$;
set local request.jwt.claim.sub='33333333-3333-3333-3333-333333333333';
do $$ begin
 begin perform public.garden_snapshot();raise exception 'FAIL: outsider read';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.garden_shared) then raise exception 'FAIL: RLS leaked state';end if;
end; $$;
set local role anon;
do $$ begin begin perform public.garden_snapshot();raise exception 'FAIL: anonymous read';exception when insufficient_privilege then null;end;end; $$;
reset role;
-- Deterministic fixture: one ticket; replaying draw must not spend twice.
update public.garden_shared set state=jsonb_set(state,'{luck,2026-10-12}','true');
set local role authenticated;
set local request.jwt.claim.sub='11111111-1111-1111-1111-111111111111';
do $$ declare first jsonb;begin
 first:=public.garden_action('draw','00000000-0000-0000-0000-000000000009');
 if public.garden_action('draw','00000000-0000-0000-0000-000000000009')<>first then raise exception 'FAIL: draw replay changed';end if;
 if jsonb_array_length(first->'state'->'draws')<>1 or jsonb_array_length(first->'state'->'rewards')<>1 then raise exception 'FAIL: draw record missing';end if;
 begin perform public.garden_action('draw','00000000-0000-0000-0000-000000000010');raise exception 'FAIL: overdraw accepted';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end; $$;
reset role;
create or replace function public.garden_today() returns date language sql stable set search_path='' as $$ select date '2026-10-17' $$;
update public.garden_shared set state='{"version":3,"days":["2026-10-11","2026-10-12","2026-10-13","2026-10-15","2026-10-16"],"tasks":{},"luck":{},"probabilities":{},"draws":[],"unlocked":[],"bonus":0,"makeupEarned":[],"makeups":{},"rewards":[]}';
set local role authenticated;
set local request.jwt.claim.sub='11111111-1111-1111-1111-111111111111';
do $$ declare r jsonb;begin
 perform public.garden_action('task','00000000-0000-0000-0000-000000000011',0,true);
 perform public.garden_action('task','00000000-0000-0000-0000-000000000012',1,true);
 perform public.garden_action('task','00000000-0000-0000-0000-000000000013',2,true);
 r:=public.garden_action('check_in','00000000-0000-0000-0000-000000000014');
 if jsonb_array_length(r->'state'->'makeupEarned')<>1 then raise exception 'FAIL: weekend credit missing';end if;
 r:=public.garden_action('makeup','00000000-0000-0000-0000-000000000015',null,null,'2026-10-14');
 if not (r->'state'->'unlocked') @> '[3,7]' then raise exception 'FAIL: makeup did not unlock seven-day milestone';end if;
 if not exists(select 1 from jsonb_array_elements(r->'state'->'rewards') a where a->>'id'='milestone-7') then raise exception 'FAIL: seven-day card missing';end if;
 begin perform public.garden_action('makeup','00000000-0000-0000-0000-000000000016',null,null,'2026-10-14');raise exception 'FAIL: credit used twice';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end; $$;
reset role;
-- Weekend vocabulary-only works without lottery or makeup credit.
update public.garden_shared set state='{"version":3,"days":[],"tasks":{},"luck":{},"probabilities":{},"draws":[],"unlocked":[],"bonus":0,"makeupEarned":[],"makeups":{},"rewards":[]}',imported=false;
set local role authenticated;
do $$ declare r jsonb;begin
 perform public.garden_action('task','00000000-0000-0000-0000-000000000017',0,true);
 r:=public.garden_action('check_in','00000000-0000-0000-0000-000000000018');
 if r->'result'->>'probability'<>'0' or r->'result'->>'lucky'<>'false' or jsonb_array_length(r->'state'->'makeupEarned')<>0 then raise exception 'FAIL: words-only weekend reward incorrect';end if;
end; $$;
reset role;
update public.garden_shared set state='{"version":3,"days":[],"tasks":{},"luck":{},"probabilities":{},"draws":[],"unlocked":[],"bonus":0,"makeupEarned":[],"makeups":{},"rewards":[]}',imported=false;
set local role authenticated;
do $$ declare r jsonb;begin
 r:=public.garden_action('import','00000000-0000-0000-0000-000000000019',null,null,null,'{"version":3,"days":["2026-10-12"],"tasks":{"2026-10-12":[0,1,2]},"luck":{"2026-10-12":true},"probabilities":{"2026-10-12":0.35},"draws":[{"date":"2026-10-12","index":3}],"bonus":0,"makeupEarned":[],"makeups":{}}');
 if r->>'importAvailable'<>'false' or jsonb_array_length(r->'state'->'draws')<>1 or r->'state'->'rewards'->0->>'name'<>'一杯喜欢的奶茶' then raise exception 'FAIL: import lost reward';end if;
 begin perform public.garden_action('import','00000000-0000-0000-0000-000000000020',null,null,null,'{}');raise exception 'FAIL: import overwrote cloud';exception when raise_exception then if sqlerrm like 'FAIL:%' then raise;end if;end;
end; $$;
select 'PASS: PostgreSQL task rules, idempotent check-in/draw, member-only RLS, viewer read-only, weekend, makeup recovery, one-time import';
rollback;
