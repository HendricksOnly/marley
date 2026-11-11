-- MARLEY ED. II (EIGHT-QUESTION EDITION) · VERSIONED INSTALLER
-- Run ONCE in Supabase SQL Editor, after reviewing. Does not alter Ed. I or the older fruit-only alpha tables.
-- Existing fruit alpha tables remain marley_ii_players / marley_ii_answers / marley_ii_guesses.
-- This edition uses distinct marley_ii_v2_* tables to preserve all existing data.
--
-- Before launch: Supabase Dashboard > Authentication > Providers > Anonymous Sign-ins > Enabled.

create or replace function public.marley_ii_v2_valid(a jsonb)
returns boolean language plpgsql immutable set search_path = ''
as $$
declare
  choice text;
  c integer;
  dc integer;
  allowed_centuries text[] := array['8th century BCE','7th century BCE','6th century BCE','5th century BCE','4th century BCE','3rd century BCE','2nd century BCE','1st century BCE','1st century CE','2nd century CE','3rd century CE','4th century CE','5th century CE','6th century CE','7th century CE','8th century CE','9th century CE','10th century CE','11th century CE','12th century CE','13th century CE','14th century CE','15th century CE','16th century CE','17th century CE','18th century CE','19th century CE','20th century CE'];
  allowed_sports text[] := array['Soccer / association football','American football','Basketball','Baseball','Ice hockey','Cricket','Rugby union','Rugby league','Volleyball','Beach volleyball','Handball','Field hockey','Lacrosse','Australian rules football','Gaelic football','Hurling','Water polo','Tennis','Badminton','Table tennis','Squash','Golf','Snooker / billiards','Darts','Boxing','Mixed martial arts (MMA)','Amateur wrestling','Professional wrestling','Gymnastics','Figure skating','Athletics / track and field','Swimming','Formula 1','NASCAR','MotoGP','Cycling','Horse racing','Skiing','Snowboarding','Surfing','Skateboarding','Esports'];
  allowed_fruits text[] := array['Apple','Banana','Strawberry','Mango','Watermelon','Pineapple','Peach','Orange','Grape','Cherry','Blueberry','Raspberry','Kiwi','Pear','Pomegranate','Plum','Fig','Cantaloupe','Grapefruit','Coconut'];
  allowed_likert text[] := array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree'];
begin
  if a is null or jsonb_typeof(a) <> 'object' then return false; end if;
  if not (a ?& array['century','deterrence','sports','college','classics','exploration','movies','fruit']) then return false; end if;
  if a->>'century' <> all(allowed_centuries) then return false; end if;
  if not (a->>'deterrence' = any(allowed_likert) and a->>'college' = any(allowed_likert) and a->>'classics' = any(allowed_likert)) then return false; end if;
  if not (a->>'exploration' = any(array['Outer space','The deep sea'])) then return false; end if;
  if not (a->>'movies' = any(array['Mob movies','Westerns'])) then return false; end if;
  foreach choice in array array['sports','fruit'] loop
    if jsonb_typeof(a->choice) <> 'array' or jsonb_array_length(a->choice) <> 3 then return false; end if;
    select count(*),count(distinct z.v) into c,dc from jsonb_array_elements_text(a->choice) z(v);
    if c<>3 or dc<>3 then return false; end if;
    if choice='sports' then
      if exists (select 1 from jsonb_array_elements_text(a->choice) z(v) where not (z.v = any(allowed_sports))) then return false; end if;
    else
      if exists (select 1 from jsonb_array_elements_text(a->choice) z(v) where not (z.v = any(allowed_fruits))) then return false; end if;
    end if;
  end loop;
  return true;
exception when others then return false;
end;
$$;

create table if not exists public.marley_ii_v2_players (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text not null check (char_length(btrim(nickname)) between 1 and 40),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create unique index if not exists marley_ii_v2_names_unique on public.marley_ii_v2_players(lower(btrim(nickname)));

create table if not exists public.marley_ii_v2_answers (
  player_id uuid primary key references public.marley_ii_v2_players(id) on delete cascade,
  answers jsonb not null check(public.marley_ii_v2_valid(answers)),
  submitted_at timestamptz not null default now()
);

create table if not exists public.marley_ii_v2_guesses (
  guesser_id uuid not null references public.marley_ii_v2_players(id) on delete cascade,
  target_id uuid not null references public.marley_ii_v2_players(id) on delete cascade,
  guesses jsonb not null check(public.marley_ii_v2_valid(guesses)),
  score integer not null check(score between 0 and 100),
  result jsonb not null,
  submitted_at timestamptz not null default now(),
  primary key(guesser_id,target_id),
  check(guesser_id <> target_id)
);

alter table public.marley_ii_v2_players enable row level security;
alter table public.marley_ii_v2_answers enable row level security;
alter table public.marley_ii_v2_guesses enable row level security;

revoke all on public.marley_ii_v2_players from public,anon,authenticated;
revoke all on public.marley_ii_v2_answers from public,anon,authenticated;
revoke all on public.marley_ii_v2_guesses from public,anon,authenticated;
grant select on public.marley_ii_v2_players to authenticated;
grant insert(id,nickname) on public.marley_ii_v2_players to authenticated;
grant update(nickname) on public.marley_ii_v2_players to authenticated;
grant select on public.marley_ii_v2_answers to authenticated;
grant select on public.marley_ii_v2_guesses to authenticated;

create policy "ed2_completed_directory_or_self" on public.marley_ii_v2_players
 for select to authenticated using (id=(select auth.uid()) or completed_at is not null);
create policy "ed2_create_my_player" on public.marley_ii_v2_players
 for insert to authenticated with check(id=(select auth.uid()) and completed_at is null);
create policy "ed2_rename_my_player" on public.marley_ii_v2_players
 for update to authenticated using(id=(select auth.uid()) and completed_at is null)
 with check(id=(select auth.uid()) and completed_at is null);
create policy "ed2_read_my_answers" on public.marley_ii_v2_answers
 for select to authenticated using(player_id=(select auth.uid()));
create policy "ed2_read_my_guesses" on public.marley_ii_v2_guesses
 for select to authenticated using(guesser_id=(select auth.uid()));

-- Atomic, immutable publication. Only the authenticated user's complete valid answer sheet is accepted.
create or replace function public.marley_ii_v2_publish(p_answers jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Sign in to publish'; end if;
  if not public.marley_ii_v2_valid(p_answers) then raise exception 'Complete every question before publishing'; end if;
  if not exists(select 1 from public.marley_ii_v2_players where id=me) then raise exception 'Register a nickname first'; end if;
  insert into public.marley_ii_v2_answers(player_id,answers) values(me,p_answers);
  update public.marley_ii_v2_players set completed_at=now() where id=me and completed_at is null;
  return jsonb_build_object('published',true);
exception when unique_violation then
  raise exception 'You have already published your answers for this edition';
end;
$$;

-- Score only after locking guesses. Full target answer sheet is never directly granted to browsers.
create or replace function public.marley_ii_v2_submit_guess(p_target uuid, p_guesses jsonb)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  me uuid := auth.uid();
  actual jsonb;
  labels text[] := array['century','deterrence','sports','college','classics','exploration','movies','fruit'];
  agreement text[] := array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree'];
  q text;
  g text;
  points integer;
  total integer := 0;
  weights integer[];
  i integer;
  ga text;
  a text;
  d integer;
  parts jsonb := '{}'::jsonb;
  result jsonb;
  breakdown jsonb;
begin
  if me is null then raise exception 'Sign in before guessing'; end if;
  if p_target is null or p_target=me then raise exception 'Choose another player'; end if;
  if not public.marley_ii_v2_valid(p_guesses) then raise exception 'Complete all eight guesses'; end if;
  if not exists(select 1 from public.marley_ii_v2_answers where player_id=me) then
    raise exception 'Complete your own answers before guessing';
  end if;
  if exists(select 1 from public.marley_ii_v2_guesses where guesser_id=me and target_id=p_target) then
    raise exception 'You have already guessed this player';
  end if;
  select answers into actual from public.marley_ii_v2_answers where player_id=p_target;
  if actual is null then raise exception 'This player has not finished the edition'; end if;
  foreach q in array labels loop
    points:=0;
    if q=any(array['sports','fruit']) then
      weights := case when q='sports' then array[8,7,5] else array[8,7,5] end;
      breakdown := '[]'::jsonb;
      for i in 0..2 loop
        ga:=p_guesses->q->>i;
        if ga=actual->q->>i then
          d:=weights[i+1];
        elsif exists (select 1 from jsonb_array_elements_text(actual->q) z(v) where z.v=ga) then
          d:=weights[i+1]/2;
        else d:=0;
        end if;
        points:=points+d;
        breakdown:=breakdown||jsonb_build_array(d);
      end loop;
      parts:=parts||jsonb_build_object(q,jsonb_build_object('earned',points,'by_rank',breakdown));
    elsif q=any(array['deterrence','college','classics']) then
      d:=abs(array_position(agreement,p_guesses->>q)-array_position(agreement,actual->>q));
      points:=(array[10,7,4,1,0])[d+1];
      parts:=parts||jsonb_build_object(q,jsonb_build_object('earned',points));
    else
      if p_guesses->>q=actual->>q then points:=10; end if;
      parts:=parts||jsonb_build_object(q,jsonb_build_object('earned',points));
    end if;
    total:=total+points;
  end loop;
  result:=jsonb_build_object('total',total,'points',parts,'actual',actual,'guesses',p_guesses);
  insert into public.marley_ii_v2_guesses(guesser_id,target_id,guesses,score,result)
  values(me,p_target,p_guesses,total,result);
  return result;
end;
$$;

revoke all on function public.marley_ii_v2_publish(jsonb) from public,anon;
revoke all on function public.marley_ii_v2_submit_guess(uuid,jsonb) from public,anon;
grant execute on function public.marley_ii_v2_publish(jsonb) to authenticated;
grant execute on function public.marley_ii_v2_submit_guess(uuid,jsonb) to authenticated;

-- Sanity check: Run these after installer to confirm tables.
-- select table_name from information_schema.tables where table_schema='public' and table_name like 'marley_ii_v2_%';
