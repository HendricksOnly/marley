# Marley Edition Protocol

The Marley collection has one homepage and permanent URLs for all editions.

## Official links

- Collection: https://hendricksonly.github.io/marley/
- Ed. I: https://hendricksonly.github.io/marley/part-i/
- Ed. II (eight questions): https://hendricksonly.github.io/marley/part-ii/
- Relationship Matrix: https://hendricksonly.github.io/marley/matrix/

## House style

- Homepage cards are simply **Edition I** and **Edition II**, with Hemingway and Djokovic quotations respectively. Do not preview or spoil the question topics in edition cards.

- Brand: dotted **m.** monogram with **marley.** wordmark
- Charcoal / slate base with restrained purple accent; accessible text contrast
- Edition labels: **Ed. I**, **Ed. II**, **Ed. III** (not Part I/Part II)
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
MARLEY_PROTOCOL.md                 this document
```

## Database isolation

- Ed. I original: `marley_players`, `marley_answers`, `marley_guesses` (do not alter).
- Ed. II eight-question: `marley_ii_v2_players`, `marley_ii_v2_answers`, `marley_ii_v2_guesses`.
- Future Ed. III: create its own `marley_iii_*` tables and scoring functions.

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

The Supabase read-only RPC `public.marley_relationship_matrix(text)` is installed using `RELATIONSHIP_MATRIX.sql`. It is executable only by authenticated sessions that have submitted their own answers for the requested edition. Its `SECURITY DEFINER` access is intentionally limited to a hardcoded pair of edition-specific table sets and sanitized score fields; no arbitrary SQL or caller-supplied table names are accepted. `anon` and `PUBLIC` cannot execute it. When changing the schema, review these privacy guarantees.

Empty cells mean no scored attempt, not a zero score. Averages are calculated only from recorded guesses; comparisons are directional. No data was inserted to populate the matrix, and the matrix is expected to be empty after a reset until players finish and guess.

## Scoring Version 2 (November 2026)

Scoring is calculated by the two authenticated server-side functions and their helper functions, installed from [SCORING_V2.sql](SCORING_V2.sql). This migration also re-scores previously locked guesses without altering either player's answers or explanation text.

- Agreement and prose five-point scales: **10 exact, 8 same side (moderate/strong), 3 neutral vs moderate, 1 neutral vs strong, 0 opposite sides**. There is no credit for being on the wrong side of the issue.
- Edition I professions: 10 for correct item and rank; 6 for correct item in another rank; 1 for different item of the same profession group in the same rank; otherwise 0.
- Edition II sports and fruits: position weights 8/7/5, unchanged. Right item at wrong rank earns half of the position weight (rounded down); different items from the same category in that position earn 1; unrelated 0. Sport categories follow the visible sports groups. Fruit categories use a smaller, curated grouping, not the one general "contenders" label.
- Other single-choice questions remain all-or-nothing. Every edition still totals at most 100 points.

During the guessing round, each question also offers **Why do you think they would choose this? (optional)**, up to 1,200 characters. These prediction rationales are saved in the guesses JSON, and are shown after scoring alongside the target player's own optional explanation. They do not affect points. Existing answer sheets are unchanged.
