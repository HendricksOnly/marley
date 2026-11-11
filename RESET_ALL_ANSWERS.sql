-- MARLEY · FRESH START / ALL ANSWERS RESET
-- Intended for the Supabase SQL Editor run by the project owner.
--
-- DESTRUCTIVE: irreversibly clears saved players, submitted answers, and guess scores
-- for Marley Edition I and Edition II, including the obsolete fruit prototype if present.
-- Does NOT delete the tables, SQL functions, your project, or Supabase auth.users.
-- Run this once when you are ready for every player to start over.
--
-- After running, ask players to refresh the Marley website. The website versions now
-- use fresh browser draft keys so old unfinished answers don't resurface.
begin;

-- Both current editions (all six tables simultaneously to satisfy foreign keys).
truncate table
  public.marley_guesses,
  public.marley_answers,
  public.marley_players,
  public.marley_ii_v2_guesses,
  public.marley_ii_v2_answers,
  public.marley_ii_v2_players;

-- Also clean up any saved data from the discontinued fruit-only alpha
-- if those legacy tables still exist. Leave the schema intact.
do $$
begin
  if to_regclass('public.marley_ii_players') is not null
     and to_regclass('public.marley_ii_answers') is not null
     and to_regclass('public.marley_ii_guesses') is not null then
    execute 'truncate table public.marley_ii_guesses, public.marley_ii_answers, public.marley_ii_players';
  end if;
end $$;

commit;

-- Optional verification after running:
-- select (select count(*) from public.marley_players) as edition_i_players,
--        (select count(*) from public.marley_answers) as edition_i_answers,
--        (select count(*) from public.marley_guesses) as edition_i_guesses,
--        (select count(*) from public.marley_ii_v2_players) as edition_ii_players,
--        (select count(*) from public.marley_ii_v2_answers) as edition_ii_answers,
--        (select count(*) from public.marley_ii_v2_guesses) as edition_ii_guesses;
