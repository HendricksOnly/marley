-- MARLEY RELATIONSHIP MATRIX / READ-ONLY SCORE SUMMARY
-- Install once in Supabase SQL Editor. No tables or player records are changed.
-- A player must have published their own answers in the selected edition.
-- This exposes only public player nicknames, opaque player IDs and locked score totals:
-- NEVER raw answers, written explanations, or guess choices.
create or replace function public.marley_relationship_matrix(p_edition text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $marley_matrix$
declare
  viewer uuid := auth.uid();
  players jsonb := '[]'::jsonb;
  scores jsonb := '[]'::jsonb;
  selected_edition text;
begin
  if viewer is null then
    raise exception 'Sign in to view the Marley relationship matrix' using errcode = '42501';
  end if;

  if lower(btrim(p_edition)) in ('i','1','ed1','edition i') then
    selected_edition := 'I';
    if not exists (select 1 from public.marley_answers where player_id=viewer) then
      raise exception 'Complete Edition I before viewing its relationship matrix' using errcode = '42501';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'nickname',p.nickname) order by lower(p.nickname),p.id),'[]'::jsonb)
      into players from public.marley_players p where p.completed_at is not null;
    select coalesce(jsonb_agg(jsonb_build_object('guesser_id',g.guesser_id,'target_id',g.target_id,'score',g.score)
      order by g.guesser_id,g.target_id),'[]'::jsonb)
      into scores
      from public.marley_guesses g
      join public.marley_players a on a.id=g.guesser_id and a.completed_at is not null
      join public.marley_players b on b.id=g.target_id and b.completed_at is not null;

  elsif lower(btrim(p_edition)) in ('ii','2','ed2','edition ii') then
    selected_edition := 'II';
    if not exists (select 1 from public.marley_ii_v2_answers where player_id=viewer) then
      raise exception 'Complete Edition II before viewing its relationship matrix' using errcode = '42501';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'nickname',p.nickname) order by lower(p.nickname),p.id),'[]'::jsonb)
      into players from public.marley_ii_v2_players p where p.completed_at is not null;
    select coalesce(jsonb_agg(jsonb_build_object('guesser_id',g.guesser_id,'target_id',g.target_id,'score',g.score)
      order by g.guesser_id,g.target_id),'[]'::jsonb)
      into scores
      from public.marley_ii_v2_guesses g
      join public.marley_ii_v2_players a on a.id=g.guesser_id and a.completed_at is not null
      join public.marley_ii_v2_players b on b.id=g.target_id and b.completed_at is not null;
  elsif lower(btrim(p_edition)) in ('iii','3','ed3','edition iii') then
    selected_edition := 'III';
    if not exists (select 1 from public.marley_iii_answers where player_id=viewer) then
      raise exception 'Complete Edition III before viewing its relationship matrix' using errcode = '42501';
    end if;
    select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'nickname',p.nickname) order by lower(p.nickname),p.id),'[]'::jsonb)
      into players from public.marley_iii_players p where p.completed_at is not null;
    select coalesce(jsonb_agg(jsonb_build_object('guesser_id',g.guesser_id,'target_id',g.target_id,'score',g.score)
      order by g.guesser_id,g.target_id),'[]'::jsonb)
      into scores
      from public.marley_iii_guesses g
      join public.marley_iii_players a on a.id=g.guesser_id and a.completed_at is not null
      join public.marley_iii_players b on b.id=g.target_id and b.completed_at is not null;
  else
    raise exception 'Unknown Marley edition' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'edition',selected_edition,
    'viewer_id',viewer,
    'players',players,
    'scores',scores
  );
end;
$marley_matrix$;

-- Keep the function inaccessible to unauthenticated callers and default PUBLIC.
revoke all on function public.marley_relationship_matrix(text) from PUBLIC, anon, authenticated;
grant execute on function public.marley_relationship_matrix(text) to authenticated;
