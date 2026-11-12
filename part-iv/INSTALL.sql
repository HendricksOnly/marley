-- Marley Edition IV / eight-screen online multiplayer installer
-- New namespace only. Editions I and II remain untouched.
-- Requires Supabase Anonymous sign-ins enabled.
BEGIN;

CREATE OR REPLACE FUNCTION public.marley_iv_valid_answers(a jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $valid_iv$
DECLARE q text; key_name text; value_text jsonb;
allowed_agreement text[] := array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree'];
allowed_poe text[] := array['Extremely overrated','Somewhat overrated','Properly rated','Somewhat underrated','Extremely underrated'];
BEGIN
 IF a IS NULL OR jsonb_typeof(a)<>'object' THEN RETURN false; END IF;
 IF NOT (a ?& array['toxin','stoicism','mcgilchrist','cadmus','dunbar','poe','ubi','salt']) THEN RETURN false; END IF;
 FOR q IN SELECT jsonb_object_keys(a) LOOP
  IF NOT q=any(array['toxin','stoicism','mcgilchrist','cadmus','dunbar','poe','ubi','salt','explanations']) THEN RETURN false; END IF;
 END LOOP;
 FOREACH q IN ARRAY array['stoicism','mcgilchrist','cadmus','dunbar'] LOOP
   IF NOT coalesce(a->>q=any(allowed_agreement),false) THEN RETURN false; END IF;
 END LOOP;
 IF NOT coalesce(a->>'poe'=any(allowed_poe),false) THEN RETURN false; END IF;
 IF NOT coalesce(a->>'salt'=any(array['Yes — taste before seasoning','No — season whenever you like']),false) THEN RETURN false; END IF;
 IF jsonb_typeof(a->'toxin')<>'object'
    OR NOT (a->'toxin' ?& array['intent','drink'])
    OR (SELECT count(*) FROM jsonb_object_keys(a->'toxin'))<>2 THEN RETURN false; END IF;
 IF NOT coalesce(a->'toxin'->>'intent'=any(allowed_agreement),false)
    OR NOT coalesce(a->'toxin'->>'drink'=any(allowed_agreement),false) THEN RETURN false; END IF;
 IF jsonb_typeof(a->'ubi')<>'object'
    OR NOT (a->'ubi' ?& array['welfare','yang'])
    OR (SELECT count(*) FROM jsonb_object_keys(a->'ubi'))<>2 THEN RETURN false; END IF;
 IF NOT coalesce(a->'ubi'->>'welfare'=any(allowed_agreement),false)
    OR NOT coalesce(a->'ubi'->>'yang'=any(allowed_agreement),false) THEN RETURN false; END IF;
 IF a ? 'explanations' THEN
   IF jsonb_typeof(a->'explanations')<>'object' THEN RETURN false; END IF;
   FOR key_name,value_text IN SELECT key,value FROM jsonb_each(a->'explanations') LOOP
     IF NOT key_name=any(array['toxin','stoicism','mcgilchrist','cadmus','dunbar','poe','ubi','salt']) THEN RETURN false; END IF;
     IF jsonb_typeof(value_text)<>'string' OR char_length(value_text#>>'{}')>1200 THEN RETURN false; END IF;
   END LOOP;
 END IF;
 RETURN true;
EXCEPTION WHEN others THEN RETURN false;
END;
$valid_iv$;

CREATE TABLE IF NOT EXISTS public.marley_iv_players (
 id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 nickname text NOT NULL CHECK (char_length(btrim(nickname)) BETWEEN 1 AND 40),
 created_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS marley_iv_nickname_unique ON public.marley_iv_players(lower(btrim(nickname)));

CREATE TABLE IF NOT EXISTS public.marley_iv_answers (
 player_id uuid PRIMARY KEY REFERENCES public.marley_iv_players(id) ON DELETE CASCADE,
 answers jsonb NOT NULL CHECK (public.marley_iv_valid_answers(answers)),
 submitted_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.marley_iv_guesses (
 guesser_id uuid NOT NULL REFERENCES public.marley_iv_players(id) ON DELETE CASCADE,
 target_id uuid NOT NULL REFERENCES public.marley_iv_players(id) ON DELETE CASCADE,
 guesses jsonb NOT NULL CHECK (public.marley_iv_valid_answers(guesses)),
 score integer NOT NULL CHECK (score BETWEEN 0 AND 100),
 result jsonb NOT NULL,
 submitted_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (guesser_id,target_id),
 CHECK (guesser_id<>target_id)
);

ALTER TABLE public.marley_iv_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marley_iv_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marley_iv_guesses ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.marley_iv_players,public.marley_iv_answers,public.marley_iv_guesses FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.marley_iv_players TO authenticated;
GRANT INSERT(id,nickname) ON public.marley_iv_players TO authenticated;
GRANT UPDATE(nickname) ON public.marley_iv_players TO authenticated;
GRANT SELECT ON public.marley_iv_answers TO authenticated;
GRANT SELECT ON public.marley_iv_guesses TO authenticated;

CREATE POLICY "ed4_read_completed_players_or_self" ON public.marley_iv_players FOR SELECT TO authenticated
 USING (id=(select auth.uid()) OR completed_at IS NOT NULL);
CREATE POLICY "ed4_register_self" ON public.marley_iv_players FOR INSERT TO authenticated
 WITH CHECK (id=(select auth.uid()) AND completed_at IS NULL);
CREATE POLICY "ed4_rename_self" ON public.marley_iv_players FOR UPDATE TO authenticated
 USING (id=(select auth.uid()) AND completed_at IS NULL)
 WITH CHECK (id=(select auth.uid()) AND completed_at IS NULL);
CREATE POLICY "ed4_read_own_answers" ON public.marley_iv_answers FOR SELECT TO authenticated
 USING (player_id=(select auth.uid()));
CREATE POLICY "ed4_read_own_guesses" ON public.marley_iv_guesses FOR SELECT TO authenticated
 USING (guesser_id=(select auth.uid()));

CREATE OR REPLACE FUNCTION public.marley_iv_publish(p_answers jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $publish_iv$
DECLARE me uuid:=auth.uid();
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in before publishing'; END IF;
 IF NOT public.marley_iv_valid_answers(p_answers) THEN RAISE EXCEPTION 'Complete all eight answers; explanations are optional'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.marley_iv_players WHERE id=me AND completed_at IS NULL) THEN
   RAISE EXCEPTION 'Register a nickname before publishing or you already completed this edition';
 END IF;
 INSERT INTO public.marley_iv_answers(player_id,answers) VALUES(me,p_answers);
 UPDATE public.marley_iv_players SET completed_at=now() WHERE id=me AND completed_at IS NULL;
 RETURN jsonb_build_object('published',true);
EXCEPTION WHEN unique_violation THEN
 RAISE EXCEPTION 'Edition IV answers have already been published';
END;
$publish_iv$;

-- Independent deterministic scoring helper. Ranked papers: exact rank=10;
-- a paper misplaced one rank earns 3, two ranks away earns 0.
CREATE OR REPLACE FUNCTION public.marley_iv_score(p_actual jsonb,p_guesses jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $score_iv$
DECLARE
 questions text[]:=array['toxin','stoicism','mcgilchrist','cadmus','dunbar','poe','ubi','salt'];
 agreement text[]:=array['Strongly disagree','Disagree','Neither agree nor disagree','Agree','Strongly agree'];
 poe_scale text[]:=array['Extremely overrated','Somewhat overrated','Properly rated','Somewhat underrated','Extremely underrated'];
 q text; p text; earned integer; part_points integer; total integer:=0;
 names text[]; breakdown jsonb; points jsonb:='{}'::jsonb;
BEGIN
 FOREACH q IN ARRAY questions LOOP
   earned:=0;
   IF q=any(array['toxin','ubi']) THEN
     names:=CASE WHEN q='toxin' THEN array['intent','drink'] ELSE array['welfare','yang'] END;
     breakdown:='{}'::jsonb;
     FOREACH p IN ARRAY names LOOP
       part_points:=public.marley_scale_points(
         array_position(agreement,p_actual->q->>p),
         array_position(agreement,p_guesses->q->>p));
       earned:=earned+part_points;
       breakdown:=breakdown||jsonb_build_object(p,part_points);
     END LOOP;
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned,'by_part',breakdown));
   ELSIF q='poe' THEN
     earned:=public.marley_scale_points(
       array_position(poe_scale,p_actual->>q),
       array_position(poe_scale,p_guesses->>q));
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
   ELSIF q=any(array['stoicism','mcgilchrist','cadmus','dunbar']) THEN
     earned:=public.marley_scale_points(
       array_position(agreement,p_actual->>q),
       array_position(agreement,p_guesses->>q));
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
   ELSE
     IF p_actual->>q=p_guesses->>q THEN earned:=10; END IF;
     points:=points||jsonb_build_object(q,jsonb_build_object('earned',earned));
   END IF;
   total:=total+earned;
 END LOOP;
 RETURN jsonb_build_object('total',total,'points',points,'actual',p_actual,'guesses',p_guesses,'scoring_version',1);
END;
$score_iv$;

CREATE OR REPLACE FUNCTION public.marley_iv_submit_guess(p_target uuid,p_guesses jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $submit_iv$
DECLARE me uuid:=auth.uid(); actual jsonb; result jsonb;
BEGIN
 IF me IS NULL THEN RAISE EXCEPTION 'Sign in before guessing'; END IF;
 IF p_target IS NULL OR p_target=me THEN RAISE EXCEPTION 'Choose somebody else to guess'; END IF;
 IF NOT public.marley_iv_valid_answers(p_guesses) THEN
   RAISE EXCEPTION 'Complete eight valid guesses; explanations are optional';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.marley_iv_answers WHERE player_id=me) THEN
   RAISE EXCEPTION 'Publish your answers before guessing';
 END IF;
 IF EXISTS(SELECT 1 FROM public.marley_iv_guesses WHERE guesser_id=me AND target_id=p_target) THEN
   RAISE EXCEPTION 'You have already guessed this player';
 END IF;
 SELECT answers INTO actual FROM public.marley_iv_answers WHERE player_id=p_target;
 IF actual IS NULL THEN RAISE EXCEPTION 'This player has not completed Edition IV'; END IF;
 result:=public.marley_iv_score(actual,p_guesses);
 INSERT INTO public.marley_iv_guesses(guesser_id,target_id,guesses,score,result)
 VALUES(me,p_target,p_guesses,(result->>'total')::integer,result);
 RETURN result;
END;
$submit_iv$;

REVOKE ALL ON FUNCTION public.marley_iv_valid_answers(jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.marley_iv_score(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.marley_iv_publish(jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.marley_iv_submit_guess(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.marley_iv_publish(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.marley_iv_submit_guess(uuid,jsonb) TO authenticated;
COMMIT;
