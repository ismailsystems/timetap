# Brief: timetap — the honest record round
date: 2026-07-27
round: 2
supersedes nothing. Round 1's record is `factory/ROUND-1.md`.

## What we're building

Six changes to an app that already works, all of them aimed at one thing: **the
app should never state something it does not know.**

A stress test of the conceptual model (2026-07-27, read against `Code.gs` and
`Index.html` directly, not the docs) found that timetap currently captures more
than it reports and infers more than it admits. Not by interpreting — it never
does that — but by *fabricating* (a phantom block every night) and by *silently
discarding* (the marks you tap, the plan you wrote).

1. **A way to stop.** The app can transition but never end, so every night
   produces a block it invented and two derived numbers that measure nothing.
2. **Guesses that look like guesses.** When the app has to invent an end time,
   the calendar and the sheet say so.
3. **Marks that reach the numbers.** You tap `+ = -` two to four times a day;
   nothing has ever counted them.
4. **A PLAN that admits it read nothing.** The planned-versus-actual ratio is
   the weekly ritual and it currently has no data in it.
5. **Tap windows that nest.** No destructive action without a confirmation, and
   a block shorter than 90 seconds becomes possible to record.
6. **Three small honesty fixes.** Admin stops absorbing unparseable titles,
   partial weeks stop looking complete, and the grid stops showing a live block
   whose write was set aside.

## Who it's for and what they get

One user: the person who built it and logs their time with it. Round 1 gave them
the ability to trust that failures are findable. This round gives them the
ability to trust the *numbers* — specifically, to open the weekly tab on a Sunday
and know that every hour in it is either something they said or something visibly
marked as the app's guess.

The stated goal, in the user's words: to settle the app's trustworthiness and
usability well enough to **start using it religiously**.

## Done looks like

The morning it works, in concrete behaviour:

- **Ending the day.** With a block running, pressing STOP in the posture row arms
  it; pressing again closes the block at that instant and closes any open SIT at
  the same instant, and opens nothing. The grid goes to its idle (dimmed) state.
  The mark strip appears for the closed block exactly as it does on any
  transition. With nothing open, STOP is visibly inert and does nothing.

- **A night you forgot.** Tap a category at 22:00, leave the app, return at
  07:00. The block is bounded as it is today, but its title now carries the mark
  `?` — `DW: memo drafting ?` — meaning *the app guessed this end; you never said
  it*. It is distinguishable from a real block at a glance in Google Calendar,
  which a `=` block ending at midnight currently is not.

- **A night you didn't forget.** Same 22:00 tap, STOP at 23:00, return at 07:00.
  No stale bounding runs, no `UNLOGGED` block is written, and the block carries
  a real mark. The stale guard has become the fallback, not the normal path.

- **The numbers.** Opening the rollup spreadsheet, `daily` and `weekly` each
  carry a column per category per mark, appended after every column that exists
  today. `DW ?` holds the guessed hours; `DW =` holds the ones you closed
  yourself. Subtracting one from the other is arithmetic the reader does, and the
  sheet never does it for them.

- **`waking h` and `sitting %` mean something.** They no longer start at 00:00
  every day by construction. Guessed and unlogged spans are excluded from the
  waking span rather than silently inflating it.

- **PLAN says what it read.** Running `setupRollup` or `rollupStatus` from the
  editor reports how many PLAN events were found *and* how many parsed into a
  configured category. Finding 12 and parsing 0 is stated in that many words.
  `SETUP.md` and `README.md` say out loud that a PLAN event only counts if its
  title begins with a category key and a colon (`DW: ...`).

- **Fast switching.** Tapping a different category within ~20 seconds of the last
  tap arms a button reading `TAP AGAIN TO RETITLE`; confirming rewrites the open
  block's category. Between ~20 and 60 seconds it reads `TAP AGAIN TO SWITCH`;
  confirming closes the old block and opens a new one. Past 60 seconds it
  switches immediately, as today. A deliberate 45-second block can be recorded.

- **Fixing a whole block.** Re-tapping the lit block opens SPLIT as it does
  today; the sheet now also offers to recategorise the block *whole* rather than
  only its remainder. Three hours into a misfiled block, the app has an answer.

- **The small ones.** A title that does not parse lands under a key named for
  what it is, not under `ADM`. The `weekly` tab marks any week the 90-day window
  only partly covers. An `openActual` that gets set aside stops the grid from
  showing that block as running.

## Not in this version

- **No retry in the set-aside drawer.** Round 1's reasoning stands unchanged.
- **No week screen, no charts, no highlighting.** The numbers still go to a
  sheet. This round widens what the sheet says; it does not move where it is read.
- **No CI changes.** Local is still where checking works.
- **No change to the mark's meaning.** `+ = -` still mean what you decide they
  mean. `?` is not a judgment — it is the absence of one.
- **No automatic stopping.** No idle detection, no timeout that ends your day for
  you, no notification reminding you to press STOP. The app does not know you
  went to bed and will not pretend to. Forgetting is handled by labelling the
  guess, never by inventing a stop.
- **No rename of categories, ever.** Unchanged, and for the unchanged reason.
- **Nothing from the README's non-goals.**

## Facts (discovered, not asked)

**Stack.** Google Apps Script web app. No build step. Four deployed files at the
repo root: `Code.gs` (1243 lines), `Index.html` (1383 lines), `appsscript.json`
(three OAuth scopes), `SETUP.md`. Dev-only tooling with one pinned dependency
(`playwright@1.62.0`), none of it deployed.

**Tests, as they stand at the start of this round.**
- `node test/tests.js` — 492 assertions against the real `Code.gs` and the real
  script extracted from `Index.html`, behind shims. Virtual clock. Run under four
  contracted timezones.
- `node test/lint.js` — 17 static rules; every rule maps to a bug that shipped.
- `node test/headless.js` — real Chromium, two viewports, plus the drawer and
  tap-count phases.
- `test/smoke.js` — 17 checks, pasted into a browser console on the phone.

Test command: `node test/tests.js && node test/lint.js`. `deploy.sh` gates on all
three layers before pushing via clasp; `--no-test` skips them.

**Code locations this round touches.**

| Concern | Location |
|---|---|
| Stale bounding + `UNLOGGED` | `Code.gs:563` `staleGuard_` |
| Title build / parse (the mark slot) | `Code.gs:394` `buildTitle_`, `Code.gs:408` `parseTitle_` |
| Mark regex, the one-character change | `Code.gs:422` — `/(?:^|\s)([+=\-])$/` |
| Op validation of marks | `Code.gs:625` — `'+=-'.indexOf(op.mark)` |
| `ADM` silent fallback, four sites | `Code.gs:541`, `579`, `704`, `743` |
| Day statistics, where the mark is dropped | `Code.gs:958` `dayStats_` — parses `p.mark`, never reads it |
| `waking` span computation | `Code.gs:980` |
| Grid builders | `Code.gs:995` `dailyGrid_`, `Code.gs:1017` `weeklyGrid_` |
| Rollup keys | `Code.gs:950` `rollupKeys_` |
| Rollup record + status | `Code.gs:824` `ROLLUP_PROP`, `Code.gs:888` `rollupStatus` |
| Recategorise op (already exists, unused by any deliberate affordance) | `Code.gs:711` `opRecategorize_` |
| Posture row markup (72px, fixed) | `Index.html:295`-`312` |
| Mark strip, covers the row for 6s | `Index.html:314`-`321`, `Index.html:930` `showStrip` |
| The only `closeActual` enqueue, always paired with an open | `Index.html:912` |
| Tap windows | `Index.html:874` `tapCategory`; `Code.gs:52` `MISTAP_SECONDS`, `Code.gs:61` `CONFIRM_WITHIN_SECONDS` |
| Arm/confirm idiom to mirror | `Index.html:759` `armDead`, `Index.html:859` `arm` |
| Quarantine | `Index.html:589` |
| SPLIT sheet (where whole-block recategorise joins) | `Index.html:339`, `Index.html:1196` `openSplit` |

**Two facts that shape stage A.** `closeActual` already exists as a server op and
already works standalone (`Code.gs:700`): it finds by ref, applies title and mark,
ends the event and clears `#open`. STOP needs no new server op. Likewise
`opRecategorize_` already does whole-block recategorisation correctly; finding 5
is a missing client affordance, not missing server behaviour.

**Environment.** node v26.5.0. Branch `main`, level with `origin/main`.

**Product law, from README.md.** Automate capture, never automate judgment. The
app never interprets, scores, advises, summarises, reminds or nudges.

## Decisions made

1. **All six findings this round**, staged so the trust spine lands first. ~15
   tasks, above the 9-12 that round 1 established as one clean overnight run.
   Accepted knowingly: stage boundaries are what make a partial night survivable,
   and an unreached stage is a named remainder rather than a half-built one.
2. **Both halves of finding 1**: an explicit STOP *and* honest labelling of what
   the guard invents. Neither alone is sufficient — STOP alone leaves the nights
   you forget lying, labelling alone means you never get to state a real boundary.
3. **A guessed end is recorded as a fourth mark, `?`**, in the mark slot that
   already exists at the end of every title. Chosen over a hidden `#unbounded`
   description token (invisible in the calendar view, which is the one place it
   matters) and over a separate `UNBOUNDED` event (would need a split point the
   app has no evidence for). Parser change is one character; op validation and
   `buildTitle_` change with it.
4. **Mark columns are per category per mark, appended** after every column that
   exists today, on both `daily` and `weekly`. Appending rather than interleaving
   is load-bearing: `README.md` tells the reader to point formulas from their own
   tabs at these, and inserting columns would silently break every one of them.
   Daily goes to roughly 50 columns; that is accepted, because these tabs are
   feedstock, not a reading surface.
5. **The tap windows nest**: the correction window shrinks well inside the
   confirm window (~20s inside 60s), and the armed button states which of the two
   outcomes the next tap produces — `TAP AGAIN TO RETITLE` or `TAP AGAIN TO
   SWITCH`. A lint rule pins `MISTAP_SECONDS < CONFIRM_WITHIN_SECONDS` so the
   nesting can never silently regress.
6. **STOP lives in the posture row**, chosen by the user over a grid cell and
   over a long-press. Two known costs, accepted and carried into the plan as
   constraints rather than reopened — see Open risks.
7. **STOP closes the open block and any open SIT at the same instant**, and opens
   nothing. It shows the mark strip for the closed block, because ending a block
   is a close and the mark belongs to the block that closed.
8. **STOP arms and confirms**, mirroring DISCARD and the category buttons. A
   mis-pressed STOP would create a spurious gap in the record.
9. **PLAN honesty is reported, not enforced.** The rollup reports found-versus-
   parsed; it does not guess at what an unparsed title meant. Discovering keys
   from titles was already rejected in round 1 for good reasons (`Code.gs:941`)
   and stays rejected.
10. **Unparseable titles get their own key**, joining `rollupKeys_` the way
    `UNLOGGED` already does, rather than defaulting to `ADM` at four call sites.
11. **Partial weeks are marked with a column**, not a suffix on `week of` —
    a suffix would change that cell from a date to a string and break sorting.

## Assumptions (stated, not asked — flag any that are wrong)

- The whole-block recategorise is reached from the existing SPLIT sheet, which
  already lists every category and is already reached by re-tapping the lit
  block. No new overlay, no new gesture.
- `?` is written by the stale guard only. Nothing the user taps ever produces it.
- The found-versus-parsed PLAN count surfaces through `setupRollup` and
  `rollupStatus` and is kept in the existing rollup script property. It does not
  go into the grids, which stay pure numbers.
- Excluding guessed spans from `waking` means `UNLOGGED` events and `?`-marked
  events do not extend the waking span. They keep their own columns.
- `MISTAP_SECONDS` starts at 20. The exact value is a judgment call; the
  invariant that it sits inside `CONFIRM_WITHIN_SECONDS` is the contract.

## Open risks

- **The posture row is the tightest surface in the app and STOP makes it
  tighter.** In the common case (`#sync` hidden when synced, `#sitEdit` hidden
  when not sitting) the row holds the posture button alone. The worst case —
  pending writes *and* sitting *and* STOP — puts four things in a 72px row on a
  390px phone. This needs a measured acceptance criterion at the phone viewport
  in the worst case specifically, not a check that it looks fine when idle.
- **STOP's armed label may not fit the button it lives in.** `TAP AGAIN TO STOP`
  in a narrow slot is not going to render. The armed state may need to take the
  row the way the mark strip does. Either way the armed state must be
  unmistakable, because an unnoticed armed STOP is a stop that does not happen.
- **The mark slot is load-bearing and this round widens it.** Round 1 found two
  separate bugs in title handling. A fourth mark character touches `buildTitle_`,
  `parseTitle_`, `validOp_`, `markFor`, the autoMark path, and every test that
  asserts on titles. This is the single most regression-prone change in the round
  and it is in stage A, where a mistake poisons every later stage.
- **`waking` changing meaning is a silent break in historical comparison.** Days
  before this ships have a `waking h` computed the old way; days after do not.
  The two are not comparable and nothing in the sheet will say so. Worth a
  decision at review time about whether the column is renamed to force the issue.
- **Fifteen tasks is above what one night has been shown to finish here.** Round
  1 ran 9-12 tasks, came back with 5 review findings and needed two fix passes.
  Expect stage D to be where the night ends; the plan must be ordered so that is
  survivable.
- **Round 1's fix pass 2 was never independently reviewed.** Stage A touches
  `staleGuard_` and stage C touches the arm/confirm idiom — both areas fix pass 2
  worked in. Treat that code as self-checked only and verify rather than assume.
- **`GUIDE.md` Part 2 still describes the round-1 double-tap bug as live** and
  proposes a fix that is not what shipped. Part 3 corrects it and five inline
  markers point there, but a reader who skips the markers gets the wrong story.
  Worth fixing whenever `GUIDE.md` is next opened, which this round will do.
