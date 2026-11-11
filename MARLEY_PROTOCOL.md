# Marley Edition Protocol

This repository is the permanent home for every Marley edition.

## Public URLs

- Collection homepage: `https://thecorrections.github.io/marley/`
- Part I (original eight questions): `https://thecorrections.github.io/marley/part-i/`
- Part II (fruit): `https://thecorrections.github.io/marley/part-ii/`

## Non-negotiable rules for every future edition

1. Give each new Marley its own stable folder: `part-iii/`, `part-iv/`, and so on. Each folder contains an `index.html`.
2. Never overwrite an older edition's released questions or scoring logic. Preserve its public URL, unless making a disclosed bug fix.
3. Put each edition's database in separate Supabase tables and functions, with its own distinct prefix (for example, `marley_iii_`). Never drop, truncate, or rename older edition tables as part of a new release.
4. Give each edition its own local draft storage key so progress from other editions cannot collide.
5. All editions can use the same Supabase project, anonymous authentication, and root `config.js`. Nested editions reference the config with `../config.js`.
6. Apply Row Level Security: other players' answer sheets must not be readable before guesses are submitted. Score and reveal answers in a server-side RPC that records each guess permanently.
7. Add one new card to the root `index.html` to publish a new edition. Test direct URLs to all earlier editions after every change.
8. Keep SQL migrations in version control when practical. Run **new** migrations through Supabase SQL Editor after review; do not rerun old destructive installers.
9. Prefer fixing incomplete content before release. After a game has collected answers, meaningful question/choice changes require a new edition or an explicit versioned migration.
10. Before launch, check anonymous sign-in, complete self-play, cross-player directory, score calculation, results confidentiality, mobile layout, and preservation of previous edition data.

## Current structure

```text
index.html             ← homepage / edition selection
config.js              ← shared, browser-safe Supabase project URL + publishable key
part-i/index.html      ← frozen original eight-question Marley (online beta)
part-ii/index.html     ← fruit-ranking multiplayer edition
```

## Part II setup

Part II requires a **one-time** Supabase SQL migration, `Marley_Part_II_Database.sql`, provided in the Marley conversation. Open Supabase → SQL Editor → New query, paste the SQL, and run it. This creates:

- `marley_ii_players`
- `marley_ii_answers`
- `marley_ii_guesses`

plus its own validation and secure scoring RPC functions. Part I's tables and scores remain untouched.

## Player identity note

Anonymous sessions are browser-scoped. Different browser profiles, devices, or cleared site data may produce new user IDs. Nicknames are not verified identities; this is appropriate for casual friends' games but not a secure ranked competition.

## Release routine

For a new edition: draft the question(s), agree on fixed answers/scoring, create unique tables and server functions, build `part-N/index.html`, run/test the database migration, add the homepage card, test both new and old links, then announce the launch.
