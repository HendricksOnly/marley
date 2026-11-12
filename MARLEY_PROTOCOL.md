# Marley Edition Protocol

The Marley collection has one homepage and permanent URLs for all editions.

## Official links

- Collection: https://hendricksonly.github.io/marley/
- Ed. I: https://hendricksonly.github.io/marley/part-i/
- Ed. II (eight questions): https://hendricksonly.github.io/marley/part-ii/
- Ed. III (eight questions): https://hendricksonly.github.io/marley/part-iii/
- Ed. IV (eight screens, ten scored answers): https://hendricksonly.github.io/marley/part-iv/
- Relationship Matrix: https://hendricksonly.github.io/marley/matrix/

## House style

- Homepage cards are simply **Edition I–IV** with their respective quotations: Hemingway, Djokovic, David K. Lewis and Andrew Yang. Do not preview or spoil the question topics in edition cards.

- Brand: dotted **m.** monogram with **marley.** wordmark
- Charcoal / slate base with restrained purple accent; accessible text contrast
- Edition labels: **Ed. I**, **Ed. II**, **Ed. III**, **Ed. IV** (not Part I/Part II)
- In-game phases: **Phase 1 — Your answers** and **Phase 2 — Guessing**
- An edition's own introduction, question-per-screen flow, final answer sheet, and 100-point guessing comparison
- Every answer question includes an **Explanation (optional)** writing box; explanations are included in the submitted answer JSON and are revealed alongside actual answers only after a guess is locked, including correctly guessed answers.
- Light, atmospheric imagery should never obscure text

## Repository structure

```text
index.html                         collection homepage
config.js                          browser-safe Supabase URL + publishable key
assets/classical.svg               classical illustration
assets/exploration.svg             space/ocean illustration
part-i/index.html                  frozen Ed. I (eight original questions)
part-ii/index.html                 Ed. II app (eight new questions)
part-ii/data.js                    Ed. II question content and answer choices
part-ii/INSTALL.sql                ONE-TIME Ed. II database installation
part-iii/index.html                Ed. III standalone game
part-iii/data.js                   Ed. III questions, sources, and choices
part-iii/INSTALL.sql               Ed. III independent database installer
part-iv/index.html                 Ed. IV standalone game
part-iv/data.js                    Ed. IV questions and short literary excerpts
part-iv/INSTALL.sql                Ed. IV independent database installer
assets/edition-iii.svg             unique Ed. III illustration
assets/edition-iv.svg              unique Ed. IV illustration
MARLEY_PROTOCOL.md                 this document
```

## Database isolation

- Ed. I original: `marley_players`, `marley_answers`, `marley_guesses` (do not alter).
- Ed. II eight-question: `marley_ii_v2_players`, `marley_ii_v2_answers`, `marley_ii_v2_guesses`.
- Ed. III: `marley_iii_players`, `marley_iii_answers`, `marley_iii_guesses`. Independent server scoring and private explanations.
- Ed. IV: `marley_iv_players`, `marley_iv_answers`, `marley_iv_guesses`. Independent scoring and privacy.
- Future Ed. V and beyond: create a fresh `marley_v_*` namespace.

Never clear or overwrite earlier edition responses as part of publishing a new edition. New versions of an already released edition must use distinct table prefixes when their answer formats change.

Use the same Supabase project and anonymous account session, but distinct table sets and per-edition browser draft keys. Anonymous sessions are per browser/site origin, not permanent verified identities.

## Security and scoring

- Completed player nicknames may appear in the directory.
- Other people's answers must never be available via browser SELECT before submission.
- Use Row Level Security for all personal data.
- Publish complete answers through an authenticated server RPC with immutable final submissions.
- Score guesses through a separate server RPC and save a single immutable attempt per guesser/target pairing.
- Return comparison details only after guesses have been locked in.
- Never expose Supabase service-role, secret, or administrator keys in public web files.

## Resetting all banked answers

Run [RESET_ALL_ANSWERS.sql](RESET_ALL_ANSWERS.sql) **in the Supabase SQL Editor** when the owner explicitly requests a fresh start. This clears registered players, answer sheets, and scored guesses across both live editions (and any discontinued fruit prototype tables that still exist), but leaves auth.users, the tables, functions, and site code intact. The active pages use versioned browser draft storage keys so previous drafts do not return after the reset.

## New-edition release checklist

1. Prepare questions and choices; explicitly decide how ranking, Likert, and single choices score. Total 100.
2. Build the edition in its own directory, e.g. `part-iii/`, without replacing `part-ii/`.
3. Add a new database installer or migration file to that edition; validate all choices and lock guesses on the server.
4. Review and run that installer in Supabase SQL Editor **once**. Check tables and RPCs.
5. Play all questions locally as both respondent and guesser.
6. Publish the app, add a homepage card, and test the live URL.
7. Test two different signed-in browsers, including a completed answer sheet, player directory, guess submission, scoring, printing/export, and mobile layout.
8. Verify older editions and old data still work.

## Ed. II (November 2026)

Ed. II consists of eight questions and requires the one-time migration in `part-ii/INSTALL.sql`. It uses separate versioned database tables, preserving existing rows. Questions are in `part-ii/data.js`, kept in sync with the SQL validation lists. If any answer choices change after collecting responses, release a separate versioned data migration instead of silently changing stored semantics.

## Relationship Matrix

The collection homepage links to `matrix/index.html`. The matrix switches between Editions I and II and displays only completed player nicknames, locked pair scores, and averages. It never displays answer JSON, written explanations, or guess JSON.

The Supabase read-only RPC `public.marley_relationship_matrix(text)` is installed using `RELATIONSHIP_MATRIX.sql`. It is executable only by authenticated sessions that have submitted their own answers for the requested edition. Its `SECURITY DEFINER` access is intentionally limited to hardcoded edition-specific table sets and sanitized score fields; no arbitrary SQL or caller-supplied table names are accepted. `anon` and `PUBLIC` cannot execute it. When changing the schema, review these privacy guarantees.

Empty cells mean no scored attempt, not a zero score. Averages are calculated only from recorded guesses; comparisons are directional. No data was inserted to populate the matrix, and the matrix is expected to be empty after a reset until players finish and guess.

## Scoring Version 2 (November 2026)

Scoring is calculated by the two authenticated server-side functions and their helper functions, installed from [SCORING_V2.sql](SCORING_V2.sql). This migration also re-scores previously locked guesses without altering either player's answers or explanation text.

- Agreement and prose five-point scales: **10 exact, 8 same side (moderate/strong), 3 neutral vs moderate, 1 neutral vs strong, 0 opposite sides**. There is no credit for being on the wrong side of the issue.
- Edition I professions: 10 for correct item and rank; 6 for correct item in another rank; 1 for different item of the same profession group in the same rank; otherwise 0.
- Edition II sports and fruits: position weights 8/7/5, unchanged. Right item at wrong rank earns half of the position weight (rounded down); different items from the same category in that position earn 1; unrelated 0. Sport categories follow the visible sports groups. Fruit categories use a smaller, curated grouping, not the one general "contenders" label.
- Other single-choice questions remain all-or-nothing. Every edition still totals at most 100 points.

During the guessing round, each question also offers **Why do you think they would choose this? (optional)**, up to 1,200 characters. These prediction rationales are saved in the guesses JSON, and are shown after scoring alongside the target player's own optional explanation. They do not affect points. Existing answer sheets are unchanged.

## Edition III (November 2026)

Edition III contains eight questions: first principles/common sense, ethics of de-extinction, a three-paper scholarly absurdity ranking, ordinary versus extraordinary poetry, technology and ethical progress, athletic prestige and compensation, comedians as philosophers, and square versus triangular pizza. The ranking is explicitly **least stupid to most stupid**. Philosophical and scientific claims are framed as competing arguments, not predetermined answers. Sources and short quotations are included directly in `part-iii/data.js`.

The new database was installed on the existing Marley Supabase project using `part-iii/INSTALL.sql`. It does not change Edition I or II. The new game preserves user nicknames, anonymous browser sessions, resumable draft answers, one-time final submissions, private answers and optional explanations, one-time guesses with optional prediction reasoning, downloadable answer sheets, printable scorecards, and 100-point server-side scoring.

Scoring: six five-position preference/agreement questions worth 10 each, one three-paper ranking worth 30, one pizza choice worth 10, for a maximum of 100. Five-position scoring uses the same conviction-aware scale as previous editions: 10 exact / 8 same side / 3 or 1 neutral near/far / 0 opposite sides. Paper ranking awards 10 exact, 3 one position away, 0 two positions away, for each of the three ranked papers. A complete self-comparison scores 100/100.

The relationship-matrix RPC and matrix website now support Edition III with the same complete-player permission rules as Editions I and II. The main collection homepage carries a third understated edition card.

## Relationship Matrix — Third-party guess scorecards

The Relationship Matrix contains clickable score cells for completed guesser → target attempts. Clicking a scored cell opens a comparison of each submitted prediction, the target's actual answer, points for each question, the guesser's optional prediction reasoning, and the target's optional answer explanation.

**Spoiler protection:** Detailed scorecards are served exclusively by the authenticated `public.marley_matrix_guess_detail(text,uuid,uuid)` RPC, installed from [MATRIX_GUESS_DETAILS.sql](MATRIX_GUESS_DETAILS.sql). It allows access only after the viewer has published their own responses in that edition AND either (a) is the target whose answers were guessed, or (b) has themselves submitted a locked guess for the same target. A person may view other people's scores in the matrix but not their detailed answers before guessing the target. The function does not perform any writes, does not change scoring, and supports Editions I, II, III and IV. `anon` and `PUBLIC` have no execute privileges; the `authenticated` role requires explicit in-function authorization. The browser never reads third-party answers or explanations directly from their tables.

Score cells without a recorded guess remain non-clickable. Locked cells display the score and an explanation of the unlock condition. Always preserve this anti-spoiler access rule when extending the matrix.

## Edition IV (November 2026)

Eight screens, ten separate scored choices: 1) Kavka's toxin, with distinct intention and follow-through predictions; 2) Stoicism's contemporary revival; 3) Iain McGilchrist's hemisphere attentional theory and subsequent metaphysics; 4) Ovid's Cadmus and whether happiness can be judged during an unfinished life; 5) Dunbar's number and social media (the claimed precise 150-person limit is disputed); 6) recurring **Overrated or Underrated?** featuring Edgar Allan Poe, with passages from <em>The Tell-Tale Heart</em>, <em>Annabel Lee</em>, and <em>The Pit and the Pendulum</em>; 7) two independent political questions on replacement-oriented UBI and Andrew Yang as a potential president; 8) seasoning food before tasting it.

Each of the two double questions contributes 20 points, with 10 per sub-answer; all other screens contribute 10 points. The five-position questions use existing conviction-aware 10/8/3/1/0 logic; the final culinary choice is exact-match only. Total possible: 100. The two subparts of each double question are required for both answer sheets and guesses. Optional written explanations still attach to each screen, not individual subparts.

The edition's own public homepage card carries the Andrew Yang quotation supplied by the creator and its custom unique raven, pendulum, and toxin-vial artwork in `assets/edition-iv.svg`. Its full intro and question header likewise use that artwork rather than reusing Edition III art. All quiz data is in `part-iv/data.js`. Dedicated backend is installed from `part-iv/INSTALL.sql` without changing earlier edition responses. The Relationship Matrix and protected guess detail RPC both support edition IV with the same spoiler-protection conditions.

One requested political prompt regarding a real person's unverified sexual conduct was deliberately replaced by a question about Yang's potential suitability for office. No speculative allegation is presented as factual background.
