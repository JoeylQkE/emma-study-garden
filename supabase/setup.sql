-- Run in the Supabase SQL Editor. No passwords or privileged keys belong here.
begin;
create table if not exists public.garden_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null unique check (role in ('emma','joey'))
);
create table if not exists public.garden_shared (
  id boolean primary key default true check (id),
  state jsonb not null default '{"version":3,"days":[],"tasks":{},"luck":{},"probabilities":{},"draws":[],"unlocked":[],"bonus":0,"makeupEarned":[],"makeups":{},"rewards":[]}',
  revision bigint not null default 0,
  imported boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.garden_shared add column if not exists daily_quotes jsonb not null default '{}';
create table if not exists public.garden_requests (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  response jsonb not null,
  primary key (user_id,request_id)
);
insert into public.garden_shared(id) values(true) on conflict do nothing;
alter table public.garden_members enable row level security;
alter table public.garden_shared enable row level security;
alter table public.garden_requests enable row level security;
revoke all on public.garden_members,public.garden_shared,public.garden_requests from anon,authenticated;
grant select on public.garden_members,public.garden_shared to authenticated;
drop policy if exists garden_member_self on public.garden_members;
create policy garden_member_self on public.garden_members for select to authenticated using (user_id=auth.uid());
drop policy if exists garden_member_read on public.garden_shared;
create policy garden_member_read on public.garden_shared for select to authenticated using (exists(select 1 from public.garden_members where user_id=auth.uid()));

create or replace function public.garden_today() returns date language sql stable set search_path='' as $$
  select (now() at time zone 'Europe/Berlin')::date;
$$;
create or replace function public.garden_append_day(s jsonb,d date) returns jsonb language sql immutable set search_path='' as $$
  select jsonb_set(s,'{days}',coalesce((select jsonb_agg(day order by day) from (select distinct value as day from jsonb_array_elements(s->'days') union select to_jsonb(d::text)) x),'[]'));
$$;
create or replace function public.garden_add_reward(s jsonb,rid text,d date,n text,src text,art text) returns jsonb language plpgsql immutable set search_path='' as $$
begin
  if exists(select 1 from jsonb_array_elements(s->'rewards') r where r->>'id'=rid) then return s; end if;
  return jsonb_set(s,'{rewards}',(s->'rewards')||jsonb_build_array(jsonb_build_object('id',rid,'date',d::text,'name',n,'source',src,'art',art)));
end; $$;
create or replace function public.garden_unlock(s jsonb,d date) returns jsonb language plpgsql immutable set search_path='' as $$
declare best integer; m record; full_count integer;
begin
  select coalesce(max(n),0) into best from (select count(*) n from (select x::date-row_number() over(order by x)::integer grp from (select distinct value x from jsonb_array_elements_text(s->'days')) v) groups group by grp) runs;
  for m in select * from (values (3,'一份外卖','meal'),(7,'巧克力','chocolate'),(14,'零食大礼包','snacks')) v(days,name,art) loop
    if best>=m.days and not (s->'unlocked') @> to_jsonb(array[m.days]) then
      s:=jsonb_set(s,'{unlocked}',(s->'unlocked')||to_jsonb(m.days));
      s:=public.garden_add_reward(s,'milestone-'||m.days,d,m.name,'连续签到 '||m.days||' 天',m.art);
    end if;
  end loop;
  select count(distinct value) into full_count from jsonb_array_elements_text(s->'days') where value::date between date '2026-10-11' and date '2026-11-09';
  if full_count=30 then s:=public.garden_add_reward(s,'attendance',d,'神秘惊喜','考前全勤','mystery'); end if;
  return s;
end; $$;

create or replace function public.garden_snapshot() returns jsonb language plpgsql security definer set search_path='' as $$
declare who text; g public.garden_shared%rowtype;
begin
  select role into who from public.garden_members where user_id=auth.uid();
  if who is null then raise exception '这个账号还没有加入 Emma 的花园，请联系 Joey。' using errcode='42501'; end if;
  select * into g from public.garden_shared where id for update;
  if not g.daily_quotes ? public.garden_today()::text then
    update public.garden_shared set daily_quotes=jsonb_set(daily_quotes,array[public.garden_today()::text],to_jsonb(floor(random()*100)::integer)) where id returning * into g;
  end if;
  return jsonb_build_object('role',who,'quoteIndex',(g.daily_quotes->>public.garden_today()::text)::integer,'state',g.state,'revision',g.revision,'day',public.garden_today()::text,'timezone','Europe/Berlin','importAvailable',not g.imported and jsonb_array_length(g.state->'days')=0 and jsonb_array_length(g.state->'draws')=0,'updatedAt',g.updated_at);
end; $$;

create or replace function public.garden_action(p_action text,p_request_id uuid,p_task integer default null,p_completed boolean default null,p_target date default null,p_local jsonb default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare who text; g public.garden_shared%rowtype; s jsonb; d date:=public.garden_today(); k text; checked jsonb; extras integer; is_weekend boolean; probability numeric; lucky boolean; available integer; result jsonb:='{}'; response jsonb; previous_rewards integer; idx integer; rid text; prize text; art text; mark jsonb; imported_state jsonb; n integer; x text;
begin
  select role into who from public.garden_members where user_id=auth.uid();
  if who is distinct from 'emma' then raise exception '只有 Emma 可以修改学习记录。' using errcode='42501'; end if;
  if p_request_id is null then raise exception '缺少操作编号。'; end if;
  select * into g from public.garden_shared where id for update;
  select r.response into response from public.garden_requests r where r.user_id=auth.uid() and r.request_id=p_request_id;
  if response is not null then return public.garden_snapshot()||jsonb_build_object('result',response->'result'); end if;
  s:=g.state; k:=d::text; previous_rewards:=jsonb_array_length(s->'rewards');
  if p_action='task' then
    if p_task is null or p_task<0 or p_task>4 or p_completed is null then raise exception '无效的学习任务。'; end if;
    if (s->'days') @> to_jsonb(array[k]) then raise exception '这一天已签到，任务已经锁定。'; end if;
    checked:=coalesce(s->'tasks'->k,'[]');
    select coalesce(jsonb_agg(v order by v),'[]') into checked from (select distinct value::integer v from jsonb_array_elements_text(checked) where value::integer<>p_task union select p_task where p_completed) items;
    s:=jsonb_set(s,array['tasks',k],checked);
  elsif p_action='check_in' then
    if (s->'days') @> to_jsonb(array[k]) then result:=jsonb_build_object('already',true);
    else
      checked:=coalesce(s->'tasks'->k,'[]'); is_weekend:=extract(isodow from d)>=6;
      select count(*) into extras from jsonb_array_elements_text(checked) where value::integer between 1 and 4;
      if not checked @> '[0]' or (not is_weekend and extras<2) then raise exception '先完成背单词；工作日还需要至少两项练习。'; end if;
      probability:=case when extras>=4 then .8 when extras=3 then .55 when extras=2 then .35 else 0 end;
      lucky:=probability>0 and random()<probability;
      s:=public.garden_append_day(s,d); s:=jsonb_set(s,array['luck',k],to_jsonb(lucky)); s:=jsonb_set(s,array['probabilities',k],to_jsonb(probability));
      if is_weekend and extras>=2 then s:=jsonb_set(s,'{makeupEarned}',(s->'makeupEarned')||to_jsonb(k)); end if;
      s:=public.garden_unlock(s,d);
      result:=jsonb_build_object('lucky',lucky,'probability',probability,'makeup',is_weekend and extras>=2);
    end if;
  elsif p_action='draw' then
    select count(*) into available from jsonb_each(s->'luck') where value='true'::jsonb;
    available:=available+coalesce((s->>'bonus')::integer,0)-jsonb_array_length(s->'draws');
    if available<=0 then raise exception '还没有抽奖机会。'; end if;
    idx:=floor(random()*4)::integer; rid:='draw-'||(jsonb_array_length(s->'draws')+1);
    select v.name,v.art into prize,art from (values(0,'一次爱心外卖','meal'),(1,'为你唱一首歌','song'),(2,'为你读一个故事','story'),(3,'一杯喜欢的奶茶','tea')) v(i,name,art) where i=idx;
    s:=jsonb_set(s,'{draws}',(s->'draws')||jsonb_build_array(jsonb_build_object('id',rid,'date',k,'index',idx,'prize',prize)));
    s:=public.garden_add_reward(s,rid,d,prize,'幸运转盘',art); result:=jsonb_build_object('index',idx,'rewardId',rid);
  elsif p_action='makeup' then
    available:=jsonb_array_length(s->'makeupEarned')-(select count(*) from jsonb_object_keys(s->'makeups'));
    if available<=0 then raise exception '还没有补签机会。'; end if;
    if p_target is null or p_target<date '2026-10-11' or p_target>date '2026-11-09' or p_target>=d or (s->'days') @> to_jsonb(array[p_target::text]) then raise exception '这个日期不能补签。'; end if;
    s:=public.garden_append_day(s,p_target);s:=jsonb_set(s,array['makeups',p_target::text],jsonb_build_object('usedOn',k));s:=public.garden_unlock(s,d);result:=jsonb_build_object('target',p_target::text);
  elsif p_action='import' then
    if g.imported or jsonb_array_length(s->'days')>0 or jsonb_array_length(s->'draws')>0 then raise exception '云端已有记录，不能被本机记录覆盖。'; end if;
    if p_local is null or octet_length(p_local::text)>300000 or jsonb_typeof(p_local->'days') is distinct from 'array' or jsonb_typeof(p_local->'tasks') is distinct from 'object' or jsonb_typeof(p_local->'luck') is distinct from 'object' or jsonb_typeof(p_local->'draws') is distinct from 'array' or jsonb_typeof(p_local->'makeupEarned') is distinct from 'array' or jsonb_typeof(p_local->'makeups') is distinct from 'object' then raise exception '本机记录格式不完整。'; end if;
    -- Legacy records are imported once by Emma, with dates, task IDs, and amounts validated.
    for x in select value from jsonb_array_elements_text(p_local->'days') loop
      if x!~'^\d{4}-\d{2}-\d{2}$' or x::date<date '2026-10-11' or x::date>d then raise exception '本机记录含有学习区间外或未来的签到日。'; end if;
      s:=public.garden_append_day(s,x::date);
      checked:=coalesce(p_local->'tasks'->x,'[0,1,2]');
      if jsonb_typeof(checked)<>'array' then raise exception '本机任务格式不正确。'; end if;
      select coalesce(jsonb_agg(v order by v),'[]') into checked from (select distinct value::integer v from jsonb_array_elements_text(checked)) t;
      if exists(select 1 from jsonb_array_elements_text(checked) where value::integer not between 0 and 4) then raise exception '本机任务编号不正确。'; end if;
      if not (p_local->'makeups') ? x and (not checked @> '[0]' or (extract(isodow from x::date)<6 and jsonb_array_length(checked)<3)) then raise exception '本机签到未达到当天的最低要求。'; end if;
      s:=jsonb_set(s,array['tasks',x],checked);s:=jsonb_set(s,array['luck',x],to_jsonb(coalesce(p_local->'luck'->x,'false')='true'::jsonb));
      probability:=coalesce((p_local->'probabilities'->>x)::numeric,0);if probability not in (0,.35,.5,.55,.8) then raise exception '本机抽奖概率不正确。'; end if;
      s:=jsonb_set(s,array['probabilities',x],to_jsonb(probability));
    end loop;
    n:=coalesce((p_local->>'bonus')::integer,0);if n<0 or n>100 then raise exception '本机抽奖机会数量不正确。'; end if;s:=jsonb_set(s,'{bonus}',to_jsonb(n));
    for x in select distinct value from jsonb_array_elements_text(p_local->'makeupEarned') loop
      if not (s->'days') @> to_jsonb(array[x]) or extract(isodow from x::date)<6 or jsonb_array_length(s->'tasks'->x)<3 then raise exception '本机补签机会不正确。'; end if;
      s:=jsonb_set(s,'{makeupEarned}',(s->'makeupEarned')||to_jsonb(x));
    end loop;
    for x,mark in select key,value from jsonb_each(p_local->'makeups') loop
      if not (s->'days') @> to_jsonb(array[x]) or x::date>date '2026-11-09' or mark->>'usedOn' is null or (mark->>'usedOn')::date<=x::date or (mark->>'usedOn')::date>d then raise exception '本机补签日期不正确。'; end if;
      s:=jsonb_set(s,array['makeups',x],jsonb_build_object('usedOn',mark->>'usedOn'));
    end loop;
    if (select count(*) from jsonb_object_keys(s->'makeups'))>jsonb_array_length(s->'makeupEarned') then raise exception '本机补签次数超出已有机会。'; end if;
    select count(*) into available from jsonb_each(s->'luck') where value='true'::jsonb;
    if jsonb_array_length(p_local->'draws')>available+n then raise exception '本机抽奖次数超出已有机会。'; end if;
    for mark in select value from jsonb_array_elements(p_local->'draws') loop
      idx:=(mark->>'index')::integer;if idx is null or idx not between 0 and 3 or mark->>'date' is null or (mark->>'date')::date>d or (mark->>'date')::date<date '2026-10-11' then raise exception '本机中奖记录不正确。'; end if;
      rid:='draw-'||(jsonb_array_length(s->'draws')+1);
      select v.name,v.art into prize,art from (values(0,'一次爱心外卖','meal'),(1,'为你唱一首歌','song'),(2,'为你读一个故事','story'),(3,'一杯喜欢的奶茶','tea')) v(i,name,art) where i=idx;
      s:=jsonb_set(s,'{draws}',(s->'draws')||jsonb_build_array(jsonb_build_object('id',rid,'date',mark->>'date','index',idx,'prize',prize)));
      s:=public.garden_add_reward(s,rid,(mark->>'date')::date,prize,'幸运转盘',art);
    end loop;
    s:=public.garden_unlock(s,d);update public.garden_shared set imported=true where id;result:=jsonb_build_object('imported',true);
  else raise exception '未知操作。'; end if;
  update public.garden_shared set state=s,revision=revision+1,updated_at=now() where id;
  select coalesce(jsonb_agg(r),'[]') into mark from jsonb_array_elements(s->'rewards') with ordinality items(r,i) where i>previous_rewards;
  result:=result||jsonb_build_object('unlocked',mark);response:=public.garden_snapshot()||jsonb_build_object('result',result);
  insert into public.garden_requests(user_id,request_id,response) values(auth.uid(),p_request_id,response);
  return response;
end; $$;

-- Internal helpers cannot be called from browsers. Only these two RPCs are exposed.
revoke all on function public.garden_today(),public.garden_append_day(jsonb,date),public.garden_add_reward(jsonb,text,date,text,text,text),public.garden_unlock(jsonb,date),public.garden_snapshot(),public.garden_action(text,uuid,integer,boolean,date,jsonb) from public,anon,authenticated;
grant execute on function public.garden_snapshot(),public.garden_action(text,uuid,integer,boolean,date,jsonb) to authenticated;
commit;
