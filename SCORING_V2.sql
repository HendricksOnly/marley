-- MARLEY SCORING v2 / TWO EDITIONS
-- Exact scale match = 10; same substantive side = 8; neutral v moderate = 3,
-- neutral v extreme = 1; opposite sides = 0. Equivalent for the prose scale.
-- Profession / sports / fruit ranking: exact position receives original full credit,
-- correct item in another position receives original partial credit, related
-- category but different item in same position receives 1 point, unrelated = 0.
-- This SQL rescales previously stored guesses and retains all answer sheets.
begin;

create or replace function public.marley_scale_points(p_actual integer,p_guess integer)
returns integer language sql immutable set search_path = '' as $scale$
select case
  when p_actual is null or p_guess is null or p_actual not between 1 and 5 or p_guess not between 1 and 5 then 0
  when p_actual=p_guess then 10
  when (p_actual<3 and p_guess<3) or (p_actual>3 and p_guess>3) then 8
  when p_actual=3 or p_guess=3 then case when (p_actual=2 or p_actual=4 or p_guess=2 or p_guess=4) then 3 else 1 end
  else 0 end;
$scale$;

create or replace function public.marley_job_group(v text)
returns text language plpgsql immutable set search_path = '' as $group$
begin
  case
    when v = any(array['Surgeon','Nurse','Paramedic','Research scientist','Astronaut','Physician','Civil engineer','University professor']::text[]) then 'Medicine & science'
    when v = any(array['Judge','Public defender','Firefighter','Diplomat','Military officer','Teacher','Police detective','Elected official','Social worker']::text[]) then 'Public service & leadership'
    when v = any(array['Novelist','Investigative journalist','Musician','Film director','Religious leader','Architect','Philosopher']::text[]) then 'Arts, culture & ideas'
    when v = any(array['Entrepreneur','Farmer','Airline pilot','Skilled tradesperson','Software engineer','Chef','Small-business owner']::text[]) then 'Commerce, craft & daily life'
    else return null;
  end case;
end;
$group$;

create or replace function public.marley_sport_group(v text)
returns text language plpgsql immutable set search_path = '' as $group$
begin
  case
    when v = any(array['Soccer / association football','American football','Basketball','Baseball','Ice hockey','Cricket','Rugby union','Rugby league','Volleyball','Beach volleyball','Handball','Field hockey','Lacrosse','Australian rules football','Gaelic football','Hurling','Water polo']::text[]) then 'Team sports'
    when v = any(array['Tennis','Badminton','Table tennis','Squash','Golf','Snooker / billiards','Darts']::text[]) then 'Racquet & precision'
    when v = any(array['Boxing','Mixed martial arts (MMA)','Amateur wrestling','Professional wrestling','Gymnastics','Figure skating','Athletics / track and field','Swimming']::text[]) then 'Combat & performance'
    when v = any(array['Formula 1','NASCAR','MotoGP','Cycling','Horse racing','Skiing','Snowboarding','Surfing','Skateboarding','Esports']::text[]) then 'Racing & outdoors'
    else return null;
  end case;
end;
$group$;

create or replace function public.marley_fruit_group(v text)
returns text language plpgsql immutable set search_path = '' as $group$
begin
  case
    when v = any(array['Apple','Pear']::text[]) then 'Orchard fruit'
    when v = any(array['Orange','Grapefruit']::text[]) then 'Citrus'
    when v = any(array['Mango','Peach','Cherry','Plum']::text[]) then 'Stone fruit'
    when v = any(array['Strawberry','Raspberry','Blueberry','Grape']::text[]) then 'Berries & grapes'
    when v = any(array['Watermelon','Cantaloupe']::text[]) then 'Melons'
    when v = any(array['Banana','Pineapple','Coconut','Kiwi']::text[]) then 'Tropical fruit'
    when v = any(array['Pomegranate']::text[]) then 'Pomegranate'
    when v = any(array['Fig']::text[]) then 'Fig'
    else return null;
  end case;
end;
$group$;


-- Limit optional guesser explanations to 1200 characters per question. In
-- particular, don't allow arbitrary JSON payloads to bypass the question validator.
create or replace function public.marley_guess_explanations_valid(p_guesses jsonb)
returns boolean language plpgsql immutable set search_path = '' as $validate$
declare v_key text; v_value jsonb;
begin
  if not p_guesses ? 'explanations' then return true; end if;
  if jsonb_typeof(p_guesses->'explanations')<>'object' then return false; end if;
  for v_key,v_value in select key,value from jsonb_each(p_guesses->'explanations') loop
    if not (v_key=any(array['vietnam','workweek','waterboarding','jobs','prose','illiteracy-ray','science','superpower','century','deterrence','sports','college','classics','exploration','movies','fruit'])) then return false; end if;
    if jsonb_typeof(v_value)<>'string' or char_length(v_value#>>'{}')>1200 then return false; end if;
  end loop;
  return true;
exception when others then return false;
end;
$validate$;

create or replace function public.marley_score_edition_i(p_actual jsonb,p_guesses jsonb)
returns jsonb language plpgsql immutable set search_path='' as $score_i$
declare
  questions text[]:=array['vietnam','workweek','waterboarding','jobs','prose','illiteracy-ray','science','superpower'];
  agreement text[]:=array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree'];
  style text[]:=array['Strongly minimalist (Hemingway)','Mostly minimalist','A balance of both','Mostly maximalist','Strongly maximalist (Joyce)'];
  q text; g text; earned integer; total integer:=0; i integer;
  points jsonb:='{}'::jsonb;
begin
  foreach q in array questions loop
    earned:=0;
    if q='jobs' then
      for i in 0..2 loop
        g:=p_guesses->'jobs'->>i;
        if g=p_actual->'jobs'->>i then
          earned:=earned+10;
        elsif p_actual->'jobs' ? g then
          earned:=earned+6;
        elsif public.marley_job_group(g) is not null
          and public.marley_job_group(g)=public.marley_job_group(p_actual->'jobs'->>i) then
          earned:=earned+1;
        end if;
      end loop;
    elsif q=any(array['vietnam','waterboarding','illiteracy-ray','science','prose']) then
      if q='prose' then
        earned:=public.marley_scale_points(array_position(style,p_actual->>q),array_position(style,p_guesses->>q));
      else
        earned:=public.marley_scale_points(array_position(agreement,p_actual->>q),array_position(agreement,p_guesses->>q));
      end if;
    elsif p_guesses->>q=p_actual->>q then
      earned:=10;
    end if;
    points:=points||jsonb_build_object(q,earned);
    total:=total+earned;
  end loop;
  return jsonb_build_object('total',total,'points',points,'actual',p_actual,'guesses',p_guesses,'scoring_version',2);
end;
$score_i$;

create or replace function public.marley_score_edition_ii(p_actual jsonb,p_guesses jsonb)
returns jsonb language plpgsql immutable set search_path='' as $score_ii$
declare
  questions text[]:=array['century','deterrence','sports','college','classics','exploration','movies','fruit'];
  agreement text[]:=array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree'];
  q text; g text; i integer; earned integer; partial integer; total integer:=0;
  group_guess text; group_actual text;
  points jsonb:='{}'::jsonb; breakdown jsonb; weights integer[]:=array[8,7,5];
begin
  foreach q in array questions loop
    earned:=0;
    if q=any(array['sports','fruit']) then
      breakdown:='[]'::jsonb;
      for i in 0..2 loop
        g:=p_guesses->q->>i;
        partial:=0;
        if g=p_actual->q->>i then
          partial:=weights[i+1];
        elsif p_actual->q ? g then
          partial:=weights[i+1]/2;
        else
          if q='sports' then
            group_guess:=public.marley_sport_group(g);
            group_actual:=public.marley_sport_group(p_actual->q->>i);
          else
            group_guess:=public.marley_fruit_group(g);
            group_actual:=public.marley_fruit_group(p_actual->q->>i);
          end if;
          if group_guess is not null and group_guess=group_actual then partial:=1; end if;
        end if;
        earned:=earned+partial;
        breakdown:=breakdown||jsonb_build_array(partial);
      end loop;
      points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned,'by_rank',breakdown));
    elsif q=any(array['deterrence','college','classics']) then
      earned:=public.marley_scale_points(array_position(agreement,p_actual->>q),array_position(agreement,p_guesses->>q));
      points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
    else
      if p_actual->>q=p_guesses->>q then earned:=10; end if;
      points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
    end if;
    total:=total+earned;
  end loop;
  return jsonb_build_object('total',total,'points',points,'actual',p_actual,'guesses',p_guesses,'scoring_version',2);
end;
$score_ii$;

-- Authentication and immutable guesses remain enforced by existing table constraints.
create or replace function public.marley_submit_guess(p_target uuid,p_guesses jsonb)
returns jsonb language plpgsql security definer set search_path='' as $submit_i$
declare me uuid:=auth.uid(); a jsonb; calculated jsonb;
begin
  if me is null then raise exception 'Sign in before playing'; end if;
  if p_target is null or p_target=me then raise exception 'You cannot guess your own answers'; end if;
  if not public.marley_valid_answers(p_guesses) or not public.marley_guess_explanations_valid(p_guesses)
     then raise exception 'Complete valid guesses; explanations are optional (up to 1200 characters each)'; end if;
  if not exists (select 1 from public.marley_answers where player_id=me)
     then raise exception 'Complete Edition I before guessing'; end if;
  if exists (select 1 from public.marley_guesses where guesser_id=me and target_id=p_target)
     then raise exception 'You have already guessed this player'; end if;
  select answers into a from public.marley_answers where player_id=p_target;
  if a is null then raise exception 'That player has not completed Edition I'; end if;
  calculated:=public.marley_score_edition_i(a,p_guesses);
  insert into public.marley_guesses(guesser_id,target_id,guesses,score,result)
  values(me,p_target,p_guesses,(calculated->>'total')::integer,calculated);
  return calculated;
end;
$submit_i$;

create or replace function public.marley_ii_v2_submit_guess(p_target uuid,p_guesses jsonb)
returns jsonb language plpgsql security definer set search_path='' as $submit_ii$
declare me uuid:=auth.uid(); a jsonb; calculated jsonb;
begin
  if me is null then raise exception 'Sign in before playing'; end if;
  if p_target is null or p_target=me then raise exception 'You cannot guess your own answers'; end if;
  if not public.marley_ii_v2_valid(p_guesses) or not public.marley_guess_explanations_valid(p_guesses)
     then raise exception 'Complete valid guesses; explanations are optional (up to 1200 characters each)'; end if;
  if not exists (select 1 from public.marley_ii_v2_answers where player_id=me)
     then raise exception 'Complete Edition II before guessing'; end if;
  if exists (select 1 from public.marley_ii_v2_guesses where guesser_id=me and target_id=p_target)
     then raise exception 'You have already guessed this player'; end if;
  select answers into a from public.marley_ii_v2_answers where player_id=p_target;
  if a is null then raise exception 'That player has not completed Edition II'; end if;
  calculated:=public.marley_score_edition_ii(a,p_guesses);
  insert into public.marley_ii_v2_guesses(guesser_id,target_id,guesses,score,result)
  values(me,p_target,p_guesses,(calculated->>'total')::integer,calculated);
  return calculated;
end;
$submit_ii$;

-- Hide helpers; allow authenticated clients to submit guesses only.
revoke all on function public.marley_scale_points(integer,integer) from public,anon,authenticated;
revoke all on function public.marley_job_group(text) from public,anon,authenticated;
revoke all on function public.marley_sport_group(text) from public,anon,authenticated;
revoke all on function public.marley_fruit_group(text) from public,anon,authenticated;
revoke all on function public.marley_guess_explanations_valid(jsonb) from public,anon,authenticated;
revoke all on function public.marley_score_edition_i(jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.marley_score_edition_ii(jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.marley_submit_guess(uuid,jsonb) from public,anon,authenticated;
revoke all on function public.marley_ii_v2_submit_guess(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.marley_submit_guess(uuid,jsonb) to authenticated;
grant execute on function public.marley_ii_v2_submit_guess(uuid,jsonb) to authenticated;

-- Re-score existing locked guesses in place. Their choices do not change.
with recalculated as (
  select g.guesser_id,g.target_id,public.marley_score_edition_i(a.answers,g.guesses) as new_result
  from public.marley_guesses g
  join public.marley_answers a on a.player_id=g.target_id
)
update public.marley_guesses g set score=(r.new_result->>'total')::integer,result=r.new_result
from recalculated r where g.guesser_id=r.guesser_id and g.target_id=r.target_id;

with recalculated as (
  select g.guesser_id,g.target_id,public.marley_score_edition_ii(a.answers,g.guesses) as new_result
  from public.marley_ii_v2_guesses g
  join public.marley_ii_v2_answers a on a.player_id=g.target_id
)
update public.marley_ii_v2_guesses g set score=(r.new_result->>'total')::integer,result=r.new_result
from recalculated r where g.guesser_id=r.guesser_id and g.target_id=r.target_id;

commit;
