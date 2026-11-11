-- Marley reset: deletes player records, answers, and guesses from both editions.
-- Destructive: run only when you intentionally want a completely fresh start.
-- Preserves all schemas, functions, policies, and Supabase auth users.
-- Both editions' tables are present in the active Marley project.
BEGIN;
TRUNCATE TABLE
  public.marley_guesses,
  public.marley_answers,
  public.marley_players,
  public.marley_ii_v2_guesses,
  public.marley_ii_v2_answers,
  public.marley_ii_v2_players;
COMMIT;

-- Verification query (run separately if desired):
SELECT 'Ed I players' AS category, count(*) AS records FROM public.marley_players
UNION ALL SELECT 'Ed I answers', count(*) FROM public.marley_answers
UNION ALL SELECT 'Ed I guesses', count(*) FROM public.marley_guesses
UNION ALL SELECT 'Ed II players', count(*) FROM public.marley_ii_v2_players
UNION ALL SELECT 'Ed II answers', count(*) FROM public.marley_ii_v2_answers
UNION ALL SELECT 'Ed II guesses', count(*) FROM public.marley_ii_v2_guesses;
