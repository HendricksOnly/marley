-- Marley Edition III / eight-question online multiplayer installer
-- New namespace only. Editions I and II remain untouched.
-- Requires Supabase Anonymous sign-ins enabled.
BEGIN;

CREATE OR REPLACE FUNCTION public.marley_iii_valid_answers(a jsonb)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $valid_iii$
DECLARE
  key_name text;
  value_text jsonb;
  q text;
  count_all integer;
  count_unique integer;
  allowed_papers text[] := array['Possible Girls','After-birth abortion','Antinatalism—Solving everything everywhere all at once?']::text[];
  allowed_poetry text[] := array['Strongly prefer the ordinary','Somewhat prefer the ordinary','Equally moved by both','Somewhat prefer the extraordinary','Strongly prefer the extraordinary']::text[];
  allowed_agreement text[] := array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree']::text[];
BEGIN
  IF a IS NULL OR jsonb_typeof(a)<>'object' THEN RETURN false; END IF;
  IF NOT (a ?& array['commonsense','deextinction','papers','poetry','technology','athletes','comedy','pizza']) THEN RETURN false; END IF;
  FOR q IN SELECT jsonb_object_keys(a) LOOP
    IF NOT (q=any(array['commonsense','deextinction','papers','poetry','technology','athletes','comedy','pizza','explanations'])) THEN RETURN false; END IF;
  END LOOP;
  FOREACH q IN ARRAY array['commonsense','deextinction','technology','athletes','comedy'] LOOP
    IF NOT coalesce(a->>q=any(allowed_agreement),false) THEN RETURN false; END IF;
  END LOOP;
  IF NOT coalesce(a->>'poetry'=any(allowed_poetry),false) THEN RETURN false; END IF;
  IF NOT coalesce(a->>'pizza'=any(array['Square-cut slices','Triangular slices']),false) THEN RETURN false; END IF;
  IF jsonb_typeof(a->'papers')<>'array' THEN RETURN false; END IF;
  IF jsonb_array_length(a->'papers')<>3 THEN RETURN false; END IF;
  SELECT count(*),count(distinct p.value) INTO count_all,count_unique
    FROM jsonb_array_elements_text(a->'papers') AS p(value);
  IF count_all<>3 OR count_unique<>3 THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(a->'papers') AS p(value)
    WHERE NOT (p.value=any(allowed_papers))) THEN RETURN false; END IF;
  IF a ? 'explanations' THEN
    IF jsonb_typeof(a->'explanations')<>'object' THEN RETURN false; END IF;
    FOR key_name,value_text IN SELECT key,value FROM jsonb_each(a->'explanations') LOOP
      IF NOT (key_name=any(array['commonsense','deextinction','papers','poetry','technology','athletes','comedy','pizza'])) THEN RETURN false; END IF;
      IF jsonb_typeof(value_text)<>'string' OR char_length(value_text#>>'{}')>1200 THEN RETURN false; END IF;
    END LOOP;
  END IF;
  RETURN true;
EXCEPTION WHEN others THEN RETURN false;
END;
$valid_iii$;

CREATE TABLE IF NOT EXISTS public.marley_iii_players (
 id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 nickname text NOT NULL CHECK (char_length(btrim(nickname)) BETWEEN 1 AND 40),
 created_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS marley_iii_nickname_unique ON public.marley_iii_players(lower(btrim(nickname)));

CREATE TABLE IF NOT EXISTS public.marley_iii_answers (
 player_id uuid PRIMARY KEY REFERENCES public.marley_iii_players(id) ON DELETE CASCADE,
 answers jsonb NOT NULL CHECK (public.marley_iii_valid_answers(answers)),
 submitted_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.marley_iii_guesses (
 guesser_id uuid NOT NULL REFERENCES public.marley_iii_players(id) ON DELETE CASCADE,
 target_id uuid NOT NULL REFERENCES public.marley_iii_players(id) ON DELETE CASCADE,
 guesses jsonb NOT NULL CHECK (public.marley_iii_valid_answers(guesses)),
 score integer NOT NULL CHECK (score BETWEEN 0 AND 100),
 result jsonb NOT NULL,
 submitted_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (guesser_id,target_id),
 CHECK (guesser_id<>target_id)
);

ALTER TABLE public.marley_iii_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marley_iii_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marley_iii_guesses ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.marley_iii_players,public.marley_iii_answers,public.marley_iii_guesses FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.marley_iii_players TO authenticated;
GRANT INSERT(id,nickname) ON public.marley_iii_players TO authenticated;
GRANT UPDATE(nickname) ON public.marley_iii_players TO authenticated;
GRANT SELECT ON public.marley_iii_answers TO authenticated;
GRANT SELECT ON public.marley_iii_guesses TO authenticated;

CREATE POLICY "ed3_read_completed_players_or_self" ON public.marley_iii_players FOR SELECT TO authenticated
 USING (id=(select auth.uid()) OR completed_at IS NOT NULL);
CREATE POLICY "ed3_register_self" ON public.marley_iii_players FOR INSERT TO authenticated
 WITH CHECK (id=(select auth.uid()) AND completed_at IS NULL);
CREATE POLICY "ed3_rename_self" ON public.marley_iii_players FOR UPDATE TO authenticated
 USING (id=(select auth.uid()) AND completed_at IS NULL)
 WITH CHECK (id=(select auth.uid()) AND completed_at IS NULL);
CREATE POLICY "ed3_read_own_answers" ON public.marley_iii_answers FOR SELECT TO authenticated
 USING (player_id=(select auth.uid()));
CREATE POLICY "ed3_read_own_guesses" ON public.marley_iii_guesses FOR SELECT TO authenticated
 USING (guesser_id=(select auth.uid()));

CREATE OR REPLACE FUNCTION public.marley_iii_publish(p_answers jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $publish_iii$
DECLARE me uuid:=auth.uid();
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in before publishing'; END IF;
 IF NOT public.marley_iii_valid_answers(p_answers) THEN RAISE EXCEPTION 'Complete all eight answers; explanations are optional'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.marley_iii_players WHERE id=me AND completed_at IS NULL) THEN
   RAISE EXCEPTION 'Register a nickname before publishing or you already completed this edition';
 END IF;
 INSERT INTO public.marley_iii_answers(player_id,answers) VALUES(me,p_answers);
 UPDATE public.marley_iii_players SET completed_at=now() WHERE id=me AND completed_at IS NULL;
 RETURN jsonb_build_object('published',true);
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'Edition III answers have already been published';
END;
$publish_iii$;

-- Independent deterministic scoring helper. Ranked papers: exact rank=10;
-- a paper misplaced one rank earns 3, two ranks away earns 0.
CREATE OR REPLACE FUNCTION public.marley_iii_score(p_actual jsonb,p_guesses jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $score_iii$
DECLARE
 questions text[]:=array['commonsense','deextinction','papers','poetry','technology','athletes','comedy','pizza'];
 agreement text[]:=array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree']::text[];
 poetry_scale text[]:=array['Strongly prefer the ordinary','Somewhat prefer the ordinary','Equally moved by both','Somewhat prefer the extraordinary','Strongly prefer the extraordinary']::text[];
 paper_names text[]:=array['Possible Girls','After-birth abortion','Antinatalism—Solving everything everywhere all at once?']::text[];
 q text;
 earned integer;
 total integer:=0;
 i integer;
 position_actual integer;
 rank_points integer;
 by_rank jsonb;
 points jsonb:='{}'::jsonb;
BEGIN
 FOREACH q IN ARRAY questions LOOP
   earned:=0;
   IF q='papers' THEN
     by_rank:='[]'::jsonb;
     FOR i IN 0..2 LOOP
       SELECT idx INTO position_actual
       FROM jsonb_array_elements_text(p_actual->'papers') WITH ORDINALITY AS v(name,idx)
       WHERE name=p_guesses->'papers'->>i;
       IF position_actual=i+1 THEN rank_points:=10;
       ELSIF abs(position_actual-(i+1))=1 THEN rank_points:=3;
       ELSE rank_points:=0;
       END IF;
       earned:=earned+rank_points;
       by_rank:=by_rank||jsonb_build_array(rank_points);
     END LOOP;
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned,'by_rank',by_rank));
   ELSIF q='poetry' THEN
     earned:=public.marley_scale_points(array_position(poetry_scale,p_actual->>q),array_position(poetry_scale,p_guesses->>q));
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
   ELSIF q=ANY(array['commonsense','deextinction','technology','athletes','comedy']) THEN
     earned:=public.marley_scale_points(array_position(agreement,p_actual->>q),array_position(agreement,p_guesses->>q));
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
   ELSE
     IF p_actual->>q=p_guesses->>q THEN earned:=10; END IF;
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
   END IF;
   total:=total+earned;
 END LOOP;
 RETURN jsonb_build_object('total',total,'points',points,'actual',p_actual,'guesses',p_guesses,'scoring_version',1);
END;
$score_iii$;

CREATE OR REPLACE FUNCTION public.marley_iii_submit_guess(p_target uuid,p_guesses jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $submit_iii$
DECLARE me uuid:=auth.uid(); actual jsonb; result jsonb;
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in before guessing'; END IF;
 IF p_target IS NULL OR p_target=me THEN RAISE EXCEPTION 'Choose somebody else to guess'; END IF;
 IF NOT public.marley_iii_valid_answers(p_guesses) THEN
   RAISE EXCEPTION 'Complete eight valid guesses; explanations are optional';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.marley_iii_answers WHERE player_id=me) THEN
   RAISE EXCEPTION 'Publish your answers before guessing';
 END IF;
 IF EXISTS(SELECT 1 FROM public.marley_iii_guesses WHERE guesser_id=me AND target_id=p_target) THEN
   RAISE EXCEPTION 'You have already guessed this player';
 END IF;
 SELECT answers INTO actual FROM public.marley_iii_answers WHERE player_id=p_target;
 IF actual IS NULL THEN RAISE EXCEPTION 'This player has not completed Edition III'; END IF;
 result:=public.marley_iii_score(actual,p_guesses);
 INSERT INTO public.marley_iii_guesses(guesser_id,target_id,guesses,score,result)
 VALUES(me,p_target,p_guesses,(result->>'total')::integer,result);
 RETURN result;
END;
$submit_iii$;

REVOKE ALL ON FUNCTION public.marley_iii_valid_answers(jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.marley_iii_score(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.marley_iii_publish(jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.marley_iii_submit_guess(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.marley_iii_publish(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.marley_iii_submit_guess(uuid,jsonb) TO authenticated;
COMMIT;
