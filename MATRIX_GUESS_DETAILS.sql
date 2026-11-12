-- Marley Relationship Matrix: detailed read-only guess scorecards.
-- Executed by an authenticated player who has completed this edition.
-- To avoid answer spoilers, full details of guesses targeting another
-- player unlock ONLY after the viewer has also guessed that target.
-- The target may always inspect guesses made about themselves.
-- This function NEVER creates or changes answers, guesses, or scores.

create or replace function public.marley_matrix_guess_detail(
  p_edition text,
  p_guesser uuid,
  p_target uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $marley_detail$
declare
  viewer uuid := auth.uid();
  edition_name text;
  item record;
begin
  if viewer is null then
    raise exception 'Sign in to view the Relationship Matrix'
      using errcode = '42501';
  end if;
  if p_guesser is null or p_target is null or p_guesser = p_target then
    raise exception 'Select a scored cell from the matrix'
      using errcode = '22023';
  end if;

  if lower(btrim(coalesce(p_edition,''))) in ('i','1','ed1','edition i') then
    edition_name := 'I';
    if not exists (
      select 1 from public.marley_answers where player_id = viewer
    ) then
      raise exception 'Complete Edition I before viewing its scorecards'
        using errcode = '42501';
    end if;
    if viewer <> p_target and not exists (
      select 1 from public.marley_guesses
      where guesser_id = viewer and target_id = p_target
    ) then
      raise exception 'Guess this target yourself to unlock other predictions about them'
        using errcode = '42501';
    end if;
    select g.score, g.result, g.submitted_at,
           guesser.nickname as guesser_name, target.nickname as target_name
      into item
      from public.marley_guesses g
      join public.marley_players guesser
        on guesser.id = g.guesser_id and guesser.completed_at is not null
      join public.marley_players target
        on target.id = g.target_id and target.completed_at is not null
      where g.guesser_id=p_guesser and g.target_id=p_target;

  elsif lower(btrim(coalesce(p_edition,''))) in ('ii','2','ed2','edition ii') then
    edition_name := 'II';
    if not exists (
      select 1 from public.marley_ii_v2_answers where player_id = viewer
    ) then
      raise exception 'Complete Edition II before viewing its scorecards'
        using errcode = '42501';
    end if;
    if viewer <> p_target and not exists (
      select 1 from public.marley_ii_v2_guesses
      where guesser_id = viewer and target_id = p_target
    ) then
      raise exception 'Guess this target yourself to unlock other predictions about them'
        using errcode = '42501';
    end if;
    select g.score, g.result, g.submitted_at,
           guesser.nickname as guesser_name, target.nickname as target_name
      into item
      from public.marley_ii_v2_guesses g
      join public.marley_ii_v2_players guesser
        on guesser.id = g.guesser_id and guesser.completed_at is not null
      join public.marley_ii_v2_players target
        on target.id = g.target_id and target.completed_at is not null
      where g.guesser_id=p_guesser and g.target_id=p_target;

  elsif lower(btrim(coalesce(p_edition,''))) in ('iii','3','ed3','edition iii') then
    edition_name := 'III';
    if not exists (
      select 1 from public.marley_iii_answers where player_id = viewer
    ) then
      raise exception 'Complete Edition III before viewing its scorecards'
        using errcode = '42501';
    end if;
    if viewer <> p_target and not exists (
      select 1 from public.marley_iii_guesses
      where guesser_id = viewer and target_id = p_target
    ) then
      raise exception 'Guess this target yourself to unlock other predictions about them'
        using errcode = '42501';
    end if;
    select g.score, g.result, g.submitted_at,
           guesser.nickname as guesser_name, target.nickname as target_name
      into item
      from public.marley_iii_guesses g
      join public.marley_iii_players guesser
        on guesser.id = g.guesser_id and guesser.completed_at is not null
      join public.marley_iii_players target
        on target.id = g.target_id and target.completed_at is not null
      where g.guesser_id=p_guesser and g.target_id=p_target;

  else
    raise exception 'Unknown Marley edition' using errcode = '22023';
  end if;

  if not found then
    raise exception 'This pair has no completed guess' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'edition', edition_name,
    'guesser', jsonb_build_object('id',p_guesser,'nickname',item.guesser_name),
    'target', jsonb_build_object('id',p_target,'nickname',item.target_name),
    'score', item.score,
    'submitted_at', item.submitted_at,
    'result', item.result
  );
end;
$marley_detail$;

revoke all on function public.marley_matrix_guess_detail(text,uuid,uuid)
  from PUBLIC, anon, authenticated;
grant execute on function public.marley_matrix_guess_detail(text,uuid,uuid)
  to authenticated;
