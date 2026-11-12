-- Marley: privacy-preserving answer diagnostics, all four editions.
-- Show the viewer's answers and answers for targets whom the viewer has already guessed.
-- Other completed players appear ONLY as locked names/IDs, never with their answers
-- or explanation text until that viewer has guessed them. No data is written.

create or replace function public.marley_answer_diagnostics(p_edition text)
returns jsonb
language plpgsql stable security definer
set search_path = ''
as $answer_diagnostics$
declare
 viewer uuid := auth.uid();
 selected_edition text;
 players jsonb := '[]'::jsonb;
 revealed jsonb := '[]'::jsonb;
begin
 if viewer is null then
   raise exception 'Sign in to view answer diagnostics' using errcode='42501';
 end if;

 if lower(btrim(coalesce(p_edition,''))) in ('i','1','ed1','edition i') then
   selected_edition := 'I';
   if not exists (select 1 from public.marley_answers where player_id=viewer) then
     raise exception 'Complete Edition I to view its answer diagnostics' using errcode='42501';
   end if;
   select coalesce(jsonb_agg(
     jsonb_build_object('id',p.id,'nickname',p.nickname,'unlocked',
       p.id=viewer or exists (select 1 from public.marley_guesses g
         where g.guesser_id=viewer and g.target_id=p.id))
     order by lower(p.nickname),p.id),'[]'::jsonb)
   into players from public.marley_players p
   where p.completed_at is not null;
   select coalesce(jsonb_agg(jsonb_build_object('player_id',a.player_id,'answers',a.answers)),'[]'::jsonb)
   into revealed from public.marley_answers a
   join public.marley_players p on p.id=a.player_id and p.completed_at is not null
   where a.player_id=viewer or exists (
       select 1 from public.marley_guesses g
       where g.guesser_id=viewer and g.target_id=a.player_id);

 elsif lower(btrim(coalesce(p_edition,''))) in ('ii','2','ed2','edition ii') then
   selected_edition := 'II';
   if not exists (select 1 from public.marley_ii_v2_answers where player_id=viewer) then
     raise exception 'Complete Edition II to view its answer diagnostics' using errcode='42501';
   end if;
   select coalesce(jsonb_agg(
     jsonb_build_object('id',p.id,'nickname',p.nickname,'unlocked',
       p.id=viewer or exists (select 1 from public.marley_ii_v2_guesses g
         where g.guesser_id=viewer and g.target_id=p.id))
     order by lower(p.nickname),p.id),'[]'::jsonb)
   into players from public.marley_ii_v2_players p
   where p.completed_at is not null;
   select coalesce(jsonb_agg(jsonb_build_object('player_id',a.player_id,'answers',a.answers)),'[]'::jsonb)
   into revealed from public.marley_ii_v2_answers a
   join public.marley_ii_v2_players p on p.id=a.player_id and p.completed_at is not null
   where a.player_id=viewer or exists (
       select 1 from public.marley_ii_v2_guesses g
       where g.guesser_id=viewer and g.target_id=a.player_id);

 elsif lower(btrim(coalesce(p_edition,''))) in ('iii','3','ed3','edition iii') then
   selected_edition := 'III';
   if not exists (select 1 from public.marley_iii_answers where player_id=viewer) then
     raise exception 'Complete Edition III to view its answer diagnostics' using errcode='42501';
   end if;
   select coalesce(jsonb_agg(
     jsonb_build_object('id',p.id,'nickname',p.nickname,'unlocked',
       p.id=viewer or exists (select 1 from public.marley_iii_guesses g
         where g.guesser_id=viewer and g.target_id=p.id))
     order by lower(p.nickname),p.id),'[]'::jsonb)
   into players from public.marley_iii_players p
   where p.completed_at is not null;
   select coalesce(jsonb_agg(jsonb_build_object('player_id',a.player_id,'answers',a.answers)),'[]'::jsonb)
   into revealed from public.marley_iii_answers a
   join public.marley_iii_players p on p.id=a.player_id and p.completed_at is not null
   where a.player_id=viewer or exists (
       select 1 from public.marley_iii_guesses g
       where g.guesser_id=viewer and g.target_id=a.player_id);

 elsif lower(btrim(coalesce(p_edition,''))) in ('iv','4','ed4','edition iv') then
   selected_edition := 'IV';
   if not exists (select 1 from public.marley_iv_answers where player_id=viewer) then
     raise exception 'Complete Edition IV to view its answer diagnostics' using errcode='42501';
   end if;
   select coalesce(jsonb_agg(
     jsonb_build_object('id',p.id,'nickname',p.nickname,'unlocked',
       p.id=viewer or exists (select 1 from public.marley_iv_guesses g
         where g.guesser_id=viewer and g.target_id=p.id))
     order by lower(p.nickname),p.id),'[]'::jsonb)
   into players from public.marley_iv_players p
   where p.completed_at is not null;
   select coalesce(jsonb_agg(jsonb_build_object('player_id',a.player_id,'answers',a.answers)),'[]'::jsonb)
   into revealed from public.marley_iv_answers a
   join public.marley_iv_players p on p.id=a.player_id and p.completed_at is not null
   where a.player_id=viewer or exists (
       select 1 from public.marley_iv_guesses g
       where g.guesser_id=viewer and g.target_id=a.player_id);

 else
   raise exception 'Unknown Marley edition' using errcode='22023';
 end if;

 return jsonb_build_object(
   'edition',selected_edition,
   'viewer_id',viewer,
   'players',players,
   'revealed',revealed);
end;
$answer_diagnostics$;

revoke all on function public.marley_answer_diagnostics(text)
  from PUBLIC,anon,authenticated;
grant execute on function public.marley_answer_diagnostics(text) to authenticated;
