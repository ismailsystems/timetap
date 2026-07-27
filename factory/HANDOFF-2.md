# HANDOFF: timetap — the honest record round
compiled: 2026-07-27 · source: factory/BRIEF-2.md + factory/PLAN-2.md
round: 2 · branch: `factory/honest-record`

## How to launch (human instructions — the loop ignores this section)

Launch is two steps: **orientation** (while you're still at the keyboard), then
**begin**.

**Claude Code:**

    /loop work through factory/HANDOFF-2.md exactly as written

No `/loop`? It isn't part of stock Claude Code. Paste this instead:

> "Begin. Execute factory/HANDOFF-2.md exactly as written. Work the operating
> loop continuously — pick the next unfinished task, build it, verify it, record
> it in factory/progress-2.md and factory/log-2.md, then move straight to the
> next task without waiting for me. Only stop when a stop condition or circuit
> breaker in the file triggers; park questions in progress-2.md and keep going."

**Cursor:** open this project, start a new Agent chat, paste:

> "Read factory/HANDOFF-2.md fully. Do NOT start work yet. First: summarize the
> goal and plan back to me in 5 plain sentences, then ask me anything —
> questions, missing context, access you need — that would improve the result. If
> you have no questions, say so and why."

Answer its questions, have it append the Q&A to this file's Orientation section,
then say: "Begin. Execute this file exactly as written." Use a loop/background
agent so it continues unattended.

**Before you walk away:** the machine must stay awake overnight. On a Mac, run
`caffeinate -dims` in a spare terminal.

**In the morning:** read the `## RUN SUMMARY` at the top of
`factory/progress-2.md`, then run `/factory` to start the independent review.

---

## Orientation (executing agent: do this before your first pass)

A different model wrote this document than the one reading it. Before any work:
read this entire file, summarize your understanding to the human, and ask for
anything that would improve the result — unclear criteria, missing context, how
to run things. Append every answer below.

### Orientation Q&A

<!-- executing agent: record each question and the human's answer here.
This section is your memory of the answers — chat history won't survive a
restart. If you had no questions, write "None — <one line why>." -->

Mid-run: if you hit a genuine ambiguity this file doesn't answer, do NOT guess
silently — park the task with your question written in `factory/progress-2.md`
and move on. Parked questions get answered by the human in the morning.

---

## Goal

timetap is a personal time-logging web app on Google Apps Script. It works. A
stress test of its conceptual model on 2026-07-27 — read against `Code.gs` and
`Index.html` directly, not the docs — found that it **captures more than it
reports and infers more than it admits.** Not by interpreting, which it never
does, but by *fabricating* (a phantom block every night) and by *silently
discarding* (the marks the user taps, the plan they wrote).

The headline: **the app can transition but never end.** `closeActual` is enqueued
in exactly one place (`Index.html:912`) and is always paired with a new
`openActual`. So every night the last block is extended to midnight by
`staleGuard_`, marked `=`, and is indistinguishable from a real block — and
because `UNLOGGED` lands on the ACTUAL calendar, every day's waking span starts
at 00:00, which makes both `waking h` and `sitting %` measure nothing.

This round fixes that and five related findings, in four stages, so that every
hour in the rollup is traceable to either something the user said or something
visibly marked as the app's guess.

**Done means every Contract assertion passes when run, not when read.**

---

## Operating loop (follow exactly)

You are the BUILDER. Each pass:

1. **GATHER** — read `factory/progress-2.md` and this file's task list. Pick the
   first unfinished, unblocked task. Tasks are in dependency order; do not
   reorder them.
2. **ACT** — implement that one task only.
3. **VERIFY** — run the task's acceptance criteria plus all tier-1 tests and the
   offline tier-3 tests. At stage boundaries, run the full suite under all four
   contracted timezones.
4. **RECORD** — update `factory/progress-2.md` (task status, attempt count) and
   append one line to `factory/log-2.md`:
   `## [date time] <task id> | <what happened>`
5. Repeat. **Assume you may be killed and restarted at any moment — those two
   files are your only memory.**

**The commands:**

    node test/tests.js && node test/lint.js     # tier 1, every pass
    node test/headless.js                       # tier 3, every pass
    TZ=America/New_York node test/tests.js      # stage boundaries
    TZ=Europe/London node test/tests.js
    TZ=Australia/Sydney node test/tests.js
    TZ=UTC node test/tests.js

There are no tier-2 (live, gated) tests in this round. Everything runs offline
against shims. **Never point a test at a real calendar or spreadsheet.**

**Baseline measured green on 2026-07-27, before this round began:**
492 assertions passed / 0 failed · lint all clear, 17 rules, 38 files scanned ·
headless ok, 19 checks per viewport including the drawer and tap-count phases.
`main` level with `origin/main` at `a256bdf`.

---

## Checker (independent verification)

When a task's criteria pass, verify as a CHECKER before marking it done: re-run
the tests fresh and confirm the observable behaviour directly. If your tool
supports subagents, spawn a fresh one with only this file and the diff,
instructed to try to **PROVE the task does NOT meet its criteria.**

**The builder never gets the final vote on its own work.**

Three tasks carry a **mandatory vacuity check** — a required demonstration that
the new test can actually fail. These are not optional and must be recorded in
`factory/log-2.md` with what was reverted and what went red:

- **A1** — revert the regex to `[+=\-]`; the parse criteria must go red.
- **A2** — revert `?` to `=` in the guard; the mark criteria must go red **while
  the boundary criteria stay green.** That separation is the point: it proves the
  boundary assertions are testing arithmetic and not the mark.
- **B5** — delete the documented sentence from each file **one at a time**; lint
  must fail and name that file, both times. A rule that only fires when both
  files change is a rule that will not fire.

---

## Circuit breakers (hard limits)

- Same task fails verification **3 times** → mark it PARKED in
  `factory/progress-2.md` with what you tried, move to the next unblocked task.
  **Never delete a parked task's criteria to make it "pass".**
- **3 tasks parked**, or every remaining task blocked → STOP. Write the summary
  and end the run.
- Hard cap: **25 total passes or 8 hours**, whichever comes first → stop and
  summarize.
- A test that fails against *today's unmodified code* where this file says it
  should pass is **a finding, not a task**: report it, park the task, do not edit
  source to make an assertion about existing behaviour go green.

---

## Restart permission

If an approach is truly unsalvageable, you may throw away uncommitted work on the
current task and rebuild it from this document. Log the restart. A restart resets
that task's failure count.

**Restarting a task is the loop working; silently narrowing its criteria is the
loop failing.**

---

## Guardrails (never violate)

- Work only on branch **`factory/honest-record`**. Never commit to `main`. Never
  push. Never force-push.
- Commit after each task passes verification, message: `<task id>: <title>`.
- **Never edit this file.** Never delete or weaken an acceptance criterion — if
  one seems wrong, PARK the task with a note instead.
- **Round 1's record is read-only.** Do not edit `factory/BRIEF.md`,
  `factory/PLAN.md`, `factory/HANDOFF.md`, `factory/progress.md`,
  `factory/log.md`, `factory/REVIEW.md`, `factory/REVIEW-2.md`,
  `factory/FIXES.md`, `factory/FIXES-2.md`, or `factory/ROUND-1.md`. Round 2
  writes `factory/progress-2.md` and `factory/log-2.md`.
- **Never touch a real calendar or spreadsheet.** Every test runs against the
  shims in `test/harness.js`. Never run `deploy.sh` without `--no-test`, and
  never run it in a way that reaches `clasp push`.
- `appsscript.json` must stay byte-identical to `main` at `a256bdf`. This round
  changes no OAuth scopes.
- Secrets stay out of the repo. The three calendar IDs and `SHEET_ID` live in
  script properties, never in committed source.
- `test/fixtures/rollup-golden.json` changes exactly twice this round — in
  B2/B3 and again in D1. **Any other change to it is a finding.**

---

## Contract (component-level — final sign-off runs ALL of these)

Everything below must be true at the end. **31 assertions.**

**The existing app is unharmed**

1. `node test/tests.js` passes with **at least 492 assertions** — the count
   measured green on 2026-07-27, before this round began — and the count only
   ever goes up.
2. `node test/tests.js` passes under `TZ=America/New_York`, `Europe/London`,
   `Australia/Sydney` and `UTC`, and skips by name rather than crashing in any
   other zone.
3. `node test/lint.js` passes with all 17 existing rules still present, plus the
   rules added by B5 and C1.
4. `node test/headless.js` passes at both viewports, including round 1's drawer
   and tap-count phases, plus the phases added by A4 and D3.
5. The four deployed files (`Code.gs`, `Index.html`, `appsscript.json`,
   `SETUP.md`) import nothing and need no build step. Anything added is dev-only.
6. `appsscript.json` still asks for exactly three OAuth scopes and is
   byte-identical to `main` at `a256bdf`.
7. Untouched by this round and still behaving exactly as their existing tests
   assert: posture toggling, sit-edit, SPLIT's remainder path, the set-aside
   drawer, category add and remove, and the offline queue's ordering and
   idempotency.

**The day can end**

8. Given a running block and an open SIT, when STOP is armed and confirmed, then
   the block closes at that instant, the SIT block closes at the same instant,
   **no event is created on either calendar**, and the grid shows the idle state.
9. Given a running block, when STOP is armed once and `CONFIRM_TIMEOUT_MS`
   elapses, then nothing was queued and the block is still running.
10. Given nothing is running, when STOP is armed and confirmed, then nothing is
    written to any calendar and no error banner appears.
11. Given a block that ran at least `MIN_MARK_MINUTES`, when STOP closes it, then
    the mark strip appears for that block exactly as it does on a transition.
12. Given STOP closed the day, when the app is reloaded, then no block renders as
    running and `getState` finds no `#open` event on either calendar.

**A guess says it is a guess**

13. Given a block opened at 22:00 and no further interaction, when the app loads
    at 07:00 the next day, then the block's title ends with `?` and not `=`.
14. Given the same, then the bounding arithmetic is **unchanged from before this
    round** — the block ends at the day border and an `UNLOGGED` event covers
    from there to now.
15. Given a `BODY` block, whose category carries `autoMark: '+'`, that the app had
    to bound, then its title still ends with `?`. An autoMark never overrides a
    guess.
16. Given the user closed the day with STOP, when the app loads the next morning,
    then no stale bounding runs, no `UNLOGGED` is written, and the title carries
    the mark the close applied.
17. **No action a user can take produces `?`.** Only `staleGuard_` writes it.
18. Given any title carrying `?`, when it is parsed and rebuilt, then it
    round-trips byte-identical.

**The numbers say only what you told them**

19. Given a day holding `DW =` 2h and `DW ?` 1h, when the rollup runs, then
    `daily` shows `DW` 3h, `DW =` 2h and `DW ?` 1h — a key's total always equals
    the sum of its mark buckets.
20. Given the rollup runs, then **every column that existed before this round is
    at the same index it was at before**, on both tabs, and exactly one
    last-rebuilt stamp sits after the last data column of each.
21. Given a day with `UNLOGGED` 00:00-07:00 and logged blocks 09:00-17:00, then
    `waking h` is 8, not 17.
22. Given a day containing a `?`-marked block, then that block's hours appear in
    its own column but do **not** extend the waking span.
23. Given 12 PLAN events of which 3 parse to a configured key, when
    `rollupStatus` runs, then it states 12 found and 3 parsed, in words.
24. Given `SETUP.md` and `README.md`, then both state that a PLAN event counts
    only if its title begins with a category key and a colon, and a lint rule
    fails if either stops saying so.

**It stops fighting you**

25. `MISTAP_SECONDS < CONFIRM_WITHIN_SECONDS` in `Code.gs`, pinned by a lint rule
    that fails if the ordering ever inverts.
26. Given a block running 45 seconds, when a different category is tapped and
    confirmed, then **two** blocks exist — the first closed at 45s, still its
    original category.
27. Given a block running 10 seconds, when a different category is tapped and
    confirmed, then **one** block exists, carrying the new category and the
    original start time.
28. **There is no elapsed time at which a single unconfirmed tap on a different
    category changes an existing block's category.** Swept second by second
    across the whole window.
29. Given a block running 3 hours, when it is recategorised whole from the SPLIT
    sheet, then exactly one block exists, carrying the new category, with its
    start and end unchanged.

**The small honesty fixes**

30. Given an ACTUAL event whose title does not parse to a configured category,
    when the rollup runs, then its hours appear under a key named for what it is,
    and `ADM` is unchanged.
31. Given a 90-day window whose oldest week is only partly covered, when the
    rollup runs, then that week's row is marked partial and a fully covered
    week's row is not — and `week of` is still a date, not a string.

**Two standing rules for the whole round.**

- **Every bug found later gets a criterion here first, then the fix.** Add it to
  `factory/progress-2.md` under `## Contract additions`, then fix it.
- **The builder never grades its own work.** These criteria are checked by
  running them, and final judgment belongs to a fresh reviewer that never saw the
  code being written.

---

## Orientation facts (so you never have to go looking)

**Stack.** Google Apps Script web app. No build step, no runtime dependencies.
Four deployed files at the repo root: `Code.gs` (1243 lines, server),
`Index.html` (1383 lines, client — all CSS/JS inlined), `appsscript.json`
(manifest, three OAuth scopes), `SETUP.md`. Dev-only tooling with one pinned
dependency (`playwright@1.62.0`); none of it is deployed.

**Product law, from README.md.** *Automate capture. Never automate judgment.* The
app never interprets, scores, advises, summarises, reminds or nudges. Nothing in
this round breaks that: a stop button states a fact, a mark column sums what the
user already said, "found 12 plan events, parsed 0" is a count. `?` is not a
judgment — it is the absence of one.

**Test harness** (`test/harness.js`) exports, among others: `tap(key)`,
`tapSit()`, `tapMark(m)`, `wait(min)`, `advance(ms)`, `settle()`, `reset(atMs)`,
`reboot()`, `setOnline(v)`, `setServerReject(msg)`, `setNow(v)`, `nowMs()`,
`A()` and `S()` (ACTUAL and SITTING events, sorted by start), `SHEETS`,
`SCRIPT_PROPS`, `TRIGGERS`, `LOGGED` (the `say_` log), `chk`, `skip`, `near`.
Virtual clock throughout — **never use real waiting.**

**Code locations this round touches.**

| Concern | Location |
|---|---|
| Stale bounding + `UNLOGGED` | `Code.gs:563` `staleGuard_` |
| Title build / parse (the mark slot) | `Code.gs:394` `buildTitle_`, `Code.gs:408` `parseTitle_` |
| Mark regex, the one-character change | `Code.gs:422` — `/(?:^\|\s)([+=\-])$/` |
| Op validation of marks | `Code.gs:625` — `'+=-'.indexOf(op.mark)` |
| `ADM` silent fallback, four sites | `Code.gs:541`, `579`, `704`, `743` |
| Day statistics, where the mark is dropped | `Code.gs:958` `dayStats_` |
| `waking` span computation | `Code.gs:980` |
| Grid builders | `Code.gs:995` `dailyGrid_`, `Code.gs:1017` `weeklyGrid_` |
| Rollup keys | `Code.gs:950` `rollupKeys_` |
| Rollup record + status | `Code.gs:824` `ROLLUP_PROP`, `Code.gs:888` `rollupStatus` |
| Recategorise op (exists, no affordance reaches it deliberately) | `Code.gs:711` `opRecategorize_` |
| Posture row markup (72px, fixed) | `Index.html:295`-`312` |
| Mark strip, covers the row for 6s | `Index.html:314`-`321`, `Index.html:930` `showStrip` |
| The only `closeActual` enqueue, always paired with an open | `Index.html:912` |
| Tap windows | `Index.html:874` `tapCategory`; `Code.gs:52`, `Code.gs:61` |
| Arm/confirm idiom to mirror | `Index.html:759` `armDead`, `Index.html:859` `arm` |
| Quarantine | `Index.html:589` |
| SPLIT sheet | `Index.html:339`, `Index.html:1196` `openSplit` |

**Two facts that shape Stage A.** `closeActual` already exists as a server op and
already works standalone (`Code.gs:700`). STOP needs **no new server op**.
Likewise `opRecategorize_` already does whole-block recategorisation correctly;
task C3 is a missing client affordance, not missing server behaviour.

**Carried forward from round 1, and load-bearing here:** round 1's fix pass 2 was
never independently reviewed. Stage A touches `staleGuard_` and Stage C touches
the arm/confirm idiom — both fix-pass-2 territory. **Verify rather than assume.**

---

## Tasks

16 tasks in four stages, in dependency order. Every stage leaves the app runnable,
deployable and coherent on its own.

| Ends after | You have |
|---|---|
| A | A day with a real boundary. Guessed blocks visible as guesses. `waking h` and `sitting %` mean something. Guessed hours not yet separable in the sheet. |
| B | The whole trust question closed. **This is the milestone that matters.** |
| C | It stops fighting you on fast days, and a misfiled block can be fixed in-app. |
| D | Complete. |

This round **does** change normal-use behaviour: Stage A adds a control and Stage
C changes what a tap does inside the first minute. Existing tests for untouched
behaviour must stay green throughout.

---

### Stage A — The day can end, and a guess says so

Finding 1, both halves. The most regression-prone stage in the round, because A1
widens a format that four other things parse. It is first because everything in
Stage B counts what A1 and A2 produce.

#### A1. A title can carry a fourth mark, and it survives a round trip

- what: `?` becomes a valid mark everywhere a mark is handled. `buildTitle_`
  (`Code.gs:394`) accepts it; `parseTitle_`'s regex (`Code.gs:422`) recognises
  it; `validOp_` (`Code.gs:625`) stops dropping ops that carry it; and the
  client's `markFor` (`Index.html:852`) never produces it. Nothing user-visible
  changes — no code path writes a `?` yet. This task exists so that A2 has
  somewhere to write it and so the widening is proved on its own, before anything
  depends on it.
- risk: **high** (the title format is load-bearing and round 1 found two separate
  bugs in it. Four call sites default to `ADM` when parsing fails, so a
  regression here does not throw — it silently misfiles time. A mistake in this
  task poisons every stage after it.)
- acceptance criteria:
  - [tier 1] Given `buildTitle_('DW', 'memo drafting', '?')`, then it returns
    exactly `DW: memo drafting ?`.
  - [tier 1] Given the title `DW: memo drafting ?`, when parsed, then key is `DW`,
    text is `memo drafting`, and mark is `?` — the `?` is not left in the text.
  - [tier 1] Given every combination of the four marks and a text with and without
    spaces, when each is built then parsed then rebuilt, then the result is
    byte-identical to the first build.
  - [tier 1] Given an op carrying `mark: '?'`, when `applyOps` runs, then it is
    applied and its id appears in `applied` — not in `dropped`.
  - [tier 1, error] Given an op carrying `mark: 'x'`, when `applyOps` runs, then it
    is still dropped. Widening the class admits exactly one new character.
  - [tier 1, error] Given the title `DW: memo ??`, when parsed, then the mark is a
    single `?` and the text is `memo ?` — the regex anchors to one trailing
    character, exactly as it already does for `=`.
  - [tier 1] Given every configured category and durations from 0 to 8 hours, then
    `markFor` never returns `?`. **Contract 17.**
- test notes: `test/tests.js`. Pure functions, so no clock or calendar needed for
  most of it; the `validOp_` criteria go through the real `applyOps` with the
  harness's calendar shim. The round-trip criterion is a loop over a fixture table
  rather than seven hand-written cases, so a fifth mark added later is covered by
  construction.
- **VACUITY CHECK REQUIRED:** revert the regex to `[+=\-]` and confirm the parse
  criteria go red. Record it in `factory/log-2.md`.

#### A2. A block the app had to guess the end of says so in its title

- what: `staleGuard_` (`Code.gs:563`) currently marks a bounded block `=` when it
  is long enough (`Code.gs:584`), which makes a phantom block indistinguishable
  from a real one. It writes `?` instead. The bounding arithmetic — start +
  `STALE_OPEN_HOURS`, capped at the day border and at now — is unchanged; only
  what the title claims changes. A category's `autoMark` must not override `?`.
- risk: medium (`staleGuard_` is code fix pass 2 worked in, and fix pass 2 was
  never independently reviewed. Its `UNLOGGED` behaviour must not change.)
- acceptance criteria:
  - [tier 1] Given a `DW` block opened at 22:00 and no further interaction, when
    `getState` runs at 07:00 the next day, then the block's title ends with `?`.
  - [tier 1] Given the same, then the block runs 22:00 to 00:00 and an `UNLOGGED`
    event runs 00:00 to 07:00 — **identical to the boundaries this code produces
    today.** Assert the times, not just the mark.
  - [tier 1] Given a `BODY` block (`autoMark: '+'`) opened at 22:00, when bounded
    the next morning, then its title ends with `?` and not `+`.
  - [tier 1] Given a `FRAG` block (`autoMark: '-'`), same setup, then its title
    ends with `?`.
  - [tier 1] Given a block opened at 09:00, when `getState` runs at 09:00:30 —
    inside `MISTAP_SECONDS` — then nothing is bounded, no mark is applied, and the
    block is still open.
  - [tier 1] Given a block opened at 09:00, when `getState` runs at 13:00 the same
    day — under `STALE_OPEN_HOURS`, no day crossed — then nothing is bounded.
  - [tier 1, error] Given a SIT block left open across midnight, when it is
    bounded, then it is bounded at the day border, no `UNLOGGED` is written to the
    SITTING calendar, and its title is unchanged. `?` is an ACTUAL-calendar
    concept; SIT blocks carry no mark at all.
  - [tier 1, error] Given a block bounded to under `MIN_MARK_MINUTES` — opened
    23:59, bounded at midnight — then it carries `?` anyway. The guess is a fact
    about the end time, not about the duration.
- test notes: `test/tests.js`, driven by `reset(atMs)` and `setNow`/`advance`.
  `A()` and `S()` return the two calendars' events sorted by start. Run under all
  four contracted timezones — the day-border cap is where a timezone bug hides.
- **VACUITY CHECK REQUIRED:** revert `?` to `=` in the guard and confirm the first
  three criteria go red **while the boundary criteria stay green.** That
  separation is the point. Record it in `factory/log-2.md`.

#### A3. STOP ends the day, and opens nothing

- what: A STOP control in the posture row (`Index.html:295`-`312`). It arms on the
  first press and acts on the second, mirroring `armDead` (`Index.html:759`) and
  `arm` (`Index.html:859`). Acting closes the open block at that instant and
  closes any open SIT at the same instant, and opens nothing — `S.open` and `S.sit`
  both go null and the grid enters its existing idle state (`Index.html:1159`). It
  shows the mark strip for the closed block exactly as a transition does, because
  ending a block is a close. With nothing open it is visibly inert. **No new
  server op is needed**: `closeActual` (`Code.gs:700`) and `closeSit`
  (`Code.gs:768`) already work standalone.
- risk: medium (it is the first control that closes without opening, so it is the
  first thing that can leave the app in a state no existing test covers: nothing
  open, queue draining, `adoptServerState` arriving afterwards.)
- acceptance criteria:
  - [tier 1] Given a running `DW` block and an open SIT, when STOP is armed and
    confirmed, then ACTUAL holds exactly one event, ending at that instant with no
    `#open`; SITTING holds exactly one, ending at the same instant with no
    `#open`; and **neither calendar gained an event.** Assert the counts.
  - [tier 1] Given a running block and no open SIT, when STOP is confirmed, then
    the block closes and the SITTING calendar is untouched.
  - [tier 1] Given an open SIT and no running block, when STOP is confirmed, then
    the SIT closes and the ACTUAL calendar is untouched.
  - [tier 1] Given a running block, when STOP is armed once and
    `CONFIRM_TIMEOUT_MS` elapses, then the queue is empty, the block is still
    open, and the control has returned to its resting label.
  - [tier 1] Given nothing running and no open SIT, when STOP is armed and
    confirmed, then no op is queued and no error banner appears.
  - [tier 1] Given a `DW` block that ran 40 minutes, when STOP closes it, then the
    mark strip is visible and names that block and its duration.
  - [tier 1] Given a `DW` block that ran 5 minutes, when STOP closes it, then no
    strip appears and the closed block carries no mark — `markFor`'s existing
    threshold applies to a STOP close exactly as to a transition.
  - [tier 1] Given STOP closed the day, when the client reboots and `getState`
    runs, then no block renders as active and no `#open` event exists on either
    calendar.
  - [tier 1, error] Given the server is rejecting every call, when STOP is
    confirmed, then the UI shows nothing running immediately, and the close ops sit
    in the queue in the order they were made. STOP is a write like any other and
    must not bypass the queue.
  - [tier 1, error] Given a running block, when STOP is confirmed twice in quick
    succession, then exactly one close is queued.
- test notes: `test/tests.js`, using `setServerReject` and `reboot()`. Ordering of
  `closeActual` versus `closeSit` in the queue is an implementation choice —
  assert that both are present and that neither is an open, rather than pinning an
  order the code has no reason to guarantee.

#### A4. STOP is reachable and unmistakable on a phone, in the worst case

- what: The posture row is `flex: 0 0 72px` and already holds `#sync`,
  `#postureBtn` and `#sitEdit`. In the common case `#sync` is hidden (synced) and
  `#sitEdit` is hidden (not sitting), so the row holds one thing — but the worst
  case puts four in it: pending writes, sitting, the sit clock and STOP, on a
  390px viewport. This task pins that case specifically. It also resolves the
  armed label: `TAP AGAIN TO STOP` will not render in a narrow slot, so the armed
  state may need to take the row the way `#strip` does (`Index.html:314`). **An
  unnoticed armed STOP is a stop that does not happen.**
- risk: medium (the one failure mode is a control that is present, passes every
  logic test, and is too small or too ambiguous to actually use at 23:00 — which
  would waste the whole of Stage A.)
- acceptance criteria:
  - [tier 3] Given a 390px viewport with pending writes **and** an open SIT **and**
    a running block — every element in the posture row visible at once — then every
    interactive control in that row has a hit box of at least 44 by 44 CSS pixels.
  - [tier 3] Given the same worst case, then no element in the posture row
    overlaps another, and the row does not overflow horizontally.
  - [tier 3] Given the same worst case, then the posture label is still legible —
    it renders its full text or an explicit truncation, never a partial word.
  - [tier 3] Given STOP is armed, then its rendered state differs from its resting
    state in **both** text and styling, not colour alone.
  - [tier 3] Given the mark strip is showing over the posture row, when the strip
    is tapped once anywhere that is not a mark, then the strip dismisses and STOP
    is visible and hittable.
  - [tier 3, error] Given a 980px desktop viewport, then the same row still passes
    every check above. STOP must not be a phone-only control.
  - [tier 1] `test/smoke.js` gains a check that the STOP control exists, is
    reachable, and carries an accessible label.
- test notes: A new phase in `test/headless.js`, following the shape of
  `checkViewport` and `checkDrawer`. The worst case is forced by seeding a pending
  queue into `localStorage` before load, opening a SIT and opening a block. Hit
  boxes come from `getBoundingClientRect`; overlap is a pairwise rectangle
  intersection over the row's children. The smoke check raises the count in
  `test/smoke.js` from 17, and `test/README.md` must be updated to match.

#### A5. Waking hours stop counting time nobody logged

- what: `dayStats_` computes `waking` as first-event-start to last-event-end over
  everything on the ACTUAL calendar (`Code.gs:969`-`980`). `UNLOGGED` events live
  on that calendar, so the nightly one drags every day's waking span back to
  00:00. Guessed and unlogged spans stop extending the waking span. They keep
  their own hours columns; only their contribution to `first` and `last` goes.
- risk: medium (this changes the meaning of an existing column. Days logged before
  this ships are not comparable with days after, and nothing in the sheet will say
  so — parked for the human at review time, **not a decision for the loop**.)
- acceptance criteria:
  - [tier 1] Given a day with `UNLOGGED` 00:00-07:00 and `DW` 09:00-17:00, when
    the rollup runs, then `waking h` is 8.
  - [tier 1] Given a day with a `?`-marked block 22:00-00:00 and `DW` 09:00-17:00,
    then `waking h` counts 09:00-17:00 only.
  - [tier 1] Given both of the above days, then `UNLOGGED` and the `?` block still
    contribute their full hours to their own columns. Only the waking span changed.
  - [tier 1] Given a day containing no unlogged and no guessed time, then
    `waking h` is byte-identical to what `test/fixtures/rollup-golden.json` records
    for it. **The common case must not move.**
  - [tier 1] Given a day whose logged blocks straddle a guessed one — `DW`
    09:00-12:00, `?` 12:00-14:00, `MTG` 14:00-17:00 — then `waking h` is 8, the
    span from the first logged start to the last logged end, and the guessed hours
    inside it are not subtracted. **The span is a span, not a sum.**
  - [tier 1, error] Given a day whose only events are `UNLOGGED`, then `waking h`
    is 0 and `sitting %` is blank rather than a division by zero or `Infinity`.
  - [tier 1, error] Given a day with no events at all, then `waking h` is 0 and
    nothing throws — today's behaviour, and it must survive the change.
- test notes: `test/tests.js`, against the existing rollup fixtures. The golden
  comparison is the load-bearing one. Run under all four contracted timezones.

---

### Stage B — The numbers say only what you told them

Findings 2 and 3. **The milestone stage**: at the end of it, every hour in the
rollup is traceable to something the user said or something visibly marked as the
app's guess.

#### B1. The day's statistics know how each hour was marked

- what: `dayStats_` (`Code.gs:958`) parses `p.mark` and then never reads it, so
  the mark is discarded at the exact point it would become a number. It gains a
  per-key, per-mark breakdown alongside the per-key totals it already produces.
  Marks are `+`, `=`, `-`, `?` and unmarked — five buckets, and unmarked is a real
  bucket (blocks under `MIN_MARK_MINUTES` legitimately carry no mark). The
  existing per-key totals stay exactly as they are.
- risk: low
- acceptance criteria:
  - [tier 1] Given a day holding `DW =` 2h, `DW -` 1h and `MTG ?` 30m, when
    `dayStats_` runs, then the breakdown holds exactly those three values and
    `d.actual.DW` is 3.
  - [tier 1] Given a fixture exercising all five mark states across every
    configured category, then for every key the sum of its five buckets equals its
    existing total, to two decimal places. **Asserted per key, not in aggregate.**
  - [tier 1] Given a block under `MIN_MARK_MINUTES` and therefore unmarked, then
    its hours land in the unmarked bucket and are not dropped.
  - [tier 1] Given the golden fixture, then every per-key total is byte-identical
    to what it was before this round.
  - [tier 1, error] Given a title ending in an unrecognised trailing character —
    `DW: memo !` — then it parses as unmarked and lands in the unmarked bucket. No
    sixth bucket is created.
  - [tier 1, error] Given a day with no ACTUAL events, then every bucket is 0 and
    nothing throws.
- test notes: `test/tests.js`. Pure arithmetic over the existing fixtures, so no
  clock needed. The per-key sum criterion catches a bucket being double-counted or
  silently dropped, and should be a loop over keys rather than hand-picked cases.

#### B2. The daily tab carries a column per category per mark

- what: `dailyGrid_` (`Code.gs:995`) gains the breakdown from B1 as columns,
  **appended after every column that exists today**. Appending rather than
  interleaving is load-bearing: `README.md` tells the reader to point formulas
  from their own tabs at these, and inserting columns would silently break every
  one of them. `stampGrid_` (`Code.gs:1095`) puts the stamp after the last data
  column, so it moves with the width.
- risk: medium (existing column positions are a contract with formulas that live
  outside this repo and cannot be tested from inside it. A test must assert
  positions, not just presence.)
- acceptance criteria:
  - [tier 1] Given the rollup runs, then **every header that existed before this
    round is at the same zero-based index as before**, asserted against the header
    row recorded in `test/fixtures/rollup-golden.json`.
  - [tier 1] Given a day holding `DW =` 2h and `DW ?` 1h, then that day's row shows
    2 in `DW =`, 1 in `DW ?`, and 3 in the existing `DW` column.
  - [tier 1] Given the rollup runs, then exactly one last-rebuilt stamp exists in
    the daily tab, in row 1, after the last data column.
  - [tier 1] Given the rollup runs twice against a fixed clock, then the daily grid
    is byte-identical both times.
  - [tier 1] Given every row in the grid, then its length equals the header row's
    length. A short row is how a column silently shifts.
  - [tier 1, error] Given a retired category with logged history
    (`removeCategory`, `Code.gs:358`), then it still gets its full set of mark
    columns.
  - [tier 1, error] Given a rollup that fails partway through building the weekly
    grid, then the daily tab keeps its previous contents and its previous stamp —
    round 1's F-2 behaviour, unchanged by the new width.
- test notes: `test/tests.js`, reading `SHEETS.book.sheets` after `dailyRollup`.
  The golden fixture's header row must be updated as part of this task, and the
  update is itself reviewable: the diff should show columns **appended**, with no
  existing entry moving. Run under all four contracted timezones.
- **If the index assertion fails against today's unmodified code, that is a
  finding: report it and stop.** It asserts a property the current code has.

#### B3. The weekly tab carries the same breakdown

- what: `weeklyGrid_` (`Code.gs:1017`) gains the same columns on the same rule —
  appended, existing positions untouched. Weekly already carries three columns per
  key (plan, actual, ratio), so it is the wider of the two tabs and the one where
  an interleaving mistake would be most expensive.
- risk: medium (same contract as B2, on a wider grid.)
- acceptance criteria:
  - [tier 1] Given the rollup runs, then every weekly header that existed before
    this round is at the same zero-based index as before.
  - [tier 1] Given a week whose days hold known mark buckets, then each of the
    week's mark cells equals the sum of its days' corresponding cells.
  - [tier 1] Given the rollup runs, then exactly one last-rebuilt stamp exists in
    the weekly tab, after the last data column.
  - [tier 1] Given every weekly row, then its length equals the weekly header row's
    length.
  - [tier 1, error] Given a week with zero planned hours for a key, then that key's
    ratio cell is still blank rather than an error, and its new mark columns are
    present and populated.
  - [tier 1, error] Given a week in which every block was guessed — every hour
    `?` — then the week's `?` columns carry all its hours and its other mark
    columns are 0, not blank. **Zero is a number; blank is a different claim.**
- test notes: As B2. The day-to-week summation criterion catches a bucket being
  summed into the wrong key, which the per-key totals would not reveal because
  they would still add up.

#### B4. The rollup says how much of PLAN it could actually read

- what: `dayStats_` only counts a PLAN event whose title parses to a key already
  in the configured set (`Code.gs:964`-`967`), so a plan written as
  `Deep work — memo` contributes exactly zero and every ratio column reads blank
  forever, with nothing saying why. The rollup counts PLAN events found and PLAN
  events parsed, keeps both in the existing rollup script property
  (`Code.gs:824`), and reports them through `setupRollup` (`Code.gs:1145`) and
  `rollupStatus` (`Code.gs:888`). It reports and stops — it **never** guesses what
  an unparsed title meant, which round 1 rejected for reasons that still hold
  (`Code.gs:941`).
- risk: low
- acceptance criteria:
  - [tier 1] Given 12 PLAN events of which 3 have titles parsing to a configured
    key, when `dailyRollup` runs, then the rollup record holds 12 found and 3
    parsed.
  - [tier 1] Given the same, when `rollupStatus` runs, then its output states both
    numbers in words a person would read, not as a bare pair of integers.
  - [tier 1] Given the same, when `setupRollup` runs, then its report states both.
  - [tier 1] Given a PLAN event titled `9:00 standup`, then it counts as found and
    **not** as parsed — it parses to key `9`, which is not configured. The count is
    of events that reached a category, not of events the regex matched.
  - [tier 1] Given the daily and weekly grids, then neither contains the counts.
    The grids stay pure numbers.
  - [tier 1, error] Given a PLAN calendar that cannot be read at all, then found
    and parsed are both 0 and nothing throws — `readCal_` (`Code.gs:1220`) is
    already tolerant and must stay so.
  - [tier 1, error] Given zero PLAN events, then the report says so plainly and
    prints neither `undefined` nor `NaN`.
  - [tier 1, error] Given a rollup that fails before it reads PLAN, then the
    previous run's counts are preserved rather than overwritten with zeroes — same
    rule round 1 set for `lastSuccessMs` (`Code.gs:843`).
- test notes: `test/tests.js`, seeding `CALS.plan.events` and reading
  `SCRIPT_PROPS` plus `LOGGED`. The `9:00 standup` criterion distinguishes "the
  regex matched" from "the event counted", which is the point of the task.

#### B5. The docs say the one thing about PLAN that was never written down

- what: `SETUP.md`'s PLAN section currently reads, in full, "Nothing to
  configure" — and then documents `plan DW` and `DW ratio` columns as though they
  populate themselves. Nothing in the repo states that a PLAN event only counts if
  its title begins with a category key and a colon. `SETUP.md` and `README.md`
  both say it, with an example. A lint rule pins the claim.
- risk: low
- acceptance criteria:
  - [tier 1] `SETUP.md` states that a PLAN event counts only if its title begins
    with a category key followed by a colon, and shows a worked example using a key
    that exists in `CATEGORIES`.
  - [tier 1] `README.md` states the same rule where it describes the PLAN calendar.
  - [tier 1] The example key shown in each file is one that `Code.gs`'s
    `CATEGORIES` array actually defines — the lint rule reads both, so the docs
    cannot drift into showing a key the app does not have.
  - [tier 1] `node test/lint.js` passes with the new rule present and named.
  - [tier 1, error] Given the sentence is deleted from `SETUP.md`, then lint fails
    and names that file. Given it is deleted from `README.md`, then lint fails and
    names that file.
- test notes: `test/lint.js`, following the existing `check(name, bad, why)` shape.
  Same family as round 1's scope-count rule: a claim in prose checked against the
  source it describes.
- **VACUITY CHECK REQUIRED:** both halves of the last criterion, demonstrated one
  file at a time. Record it in `factory/log-2.md`.

---

### Stage C — It stops fighting you

Findings 4 and 5. Everything before this made the record honest; this makes the
app usable on a fast day.

#### C1. The tap windows nest, so nothing destructive happens unconfirmed

- what: `CONFIRM_WITHIN_SECONDS` is 60 and `MISTAP_SECONDS` is 90 (`Code.gs:52`,
  `Code.gs:61`), so between 60 and 90 seconds a tap on a different category acts
  immediately **and** destructively — it retitles the block you are in rather than
  starting a new one (`Index.html:895`-`906`). The correction window shrinks well
  inside the confirm window (20s inside 60s), which makes every destructive path
  confirmed by construction rather than by luck, and makes a deliberate 45-second
  block recordable for the first time. A lint rule pins the ordering.
- risk: medium (this is the arm/confirm idiom, which fix pass 2 worked in and
  which was never independently reviewed. The interaction between `S.lastTapMs`,
  the armed state and the correction branch is subtle: **arming does not update
  `lastTapMs`**, so both windows are measured from the original tap.)
- acceptance criteria:
  - [tier 1] `MISTAP_SECONDS < CONFIRM_WITHIN_SECONDS` in `Code.gs`, and
    `node test/lint.js` fails by name if the two values are ever swapped.
  - [tier 1] Given a `DW` block running 45 seconds, when `MTG` is tapped and then
    confirmed, then **two** blocks exist: `DW` from 0 to 45s, closed, still keyed
    `DW`; and `MTG` open from 45s.
  - [tier 1] Given a `DW` block running 10 seconds, when `MTG` is tapped and then
    confirmed, then **one** block exists, keyed `MTG`, with the original start
    time.
  - [tier 1] Given a `DW` block running 45 seconds, when `MTG` is tapped once and
    `CONFIRM_TIMEOUT_MS` elapses, then nothing was queued and `DW` is still the
    open block.
  - [tier 1] Given a `DW` block running 5 minutes, when `MTG` is tapped once, then
    it acts immediately and two blocks exist — past the confirm window, a tap is
    still a tap.
  - [tier 1, error] **Sweep:** for every whole second of elapsed time from 0 to
    120, given a running block, when a different category is tapped exactly once,
    then no existing block's key ever changes. **Contract 28.** This is the
    assertion that proves the windows nest, rather than testing the two values that
    happen to be configured today.
  - [tier 1, error] Given `BODY` is tapped as a correction inside the mis-tap
    window while a SIT is open, then the SIT still closes — the one coupling in the
    app (`Index.html:903`) survives the window change.
- test notes: `test/tests.js`, driven by `advance`. **The sweep is the criterion
  that matters most**: the individual window tests would all pass against a build
  where the two constants were merely different, and only the sweep proves there is
  no reachable gap. The lint rule reads both constants out of `Code.gs` rather than
  being told their values.

#### C2. The armed button says which of the two things the next tap will do

- what: Today the armed state reads `TAP AGAIN` (`Index.html:1178`), which does
  not disclose whether confirming will retitle the block you are in or start a new
  one. Inside the correction window it reads `TAP AGAIN TO RETITLE`; outside it,
  `TAP AGAIN TO SWITCH`. Same rule round 1 settled on for `TAP AGAIN TO DISCARD`:
  state what the next tap will do, and stop.
- risk: low
- acceptance criteria:
  - [tier 1] Given a `DW` block running 10 seconds, when `MTG` is tapped once, then
    the armed cell's confirm text reads `TAP AGAIN TO RETITLE`.
  - [tier 1] Given a `DW` block running 45 seconds, when `MTG` is tapped once, then
    it reads `TAP AGAIN TO SWITCH`.
  - [tier 1] Given either armed state, when the confirm times out, then the text is
    empty and the arming style is removed.
  - [tier 1] Given an armed cell, then the text it shows always names the action
    that the next tap actually performs — asserted by reading the label and then
    confirming and checking which of the two outcomes occurred, for both windows.
  - [tier 1, error] Given a block is armed inside the correction window and the
    clock advances past it before the second tap, then the label and the action
    agree at the moment of the tap. **A stale label that promises the wrong action
    is the exact bug this task exists to prevent.**
  - [tier 3] Given a 390px viewport, then both labels render inside the cell
    without overflowing or wrapping to an unreadable size.
- test notes: `test/tests.js` for the logic, one added assertion in the existing
  `checkViewport` phase of `test/headless.js` for the rendering. The stale-label
  criterion needs `advance` between the two taps.

#### C3. A whole block can be recategorised, not just its remainder

- what: Past the correction window the app has no way to fix a misfiled block — a
  different category starts a new one, and re-tapping the lit one opens SPLIT
  (`Index.html:1196`), which only reassigns the remainder. The SPLIT sheet
  (`Index.html:339`) already lists every category and is already reached by
  re-tapping the lit block; it gains the option to apply the choice to the whole
  block instead of the remainder. The server op already exists and already does
  this correctly — `opRecategorize_` (`Code.gs:711`) is what the mis-tap correction
  uses. **This is a missing client affordance, not missing behaviour.**
- risk: low (the write path is existing, exercised code.)
- acceptance criteria:
  - [tier 1] Given a `DW` block running 3 hours, when it is recategorised whole to
    `MTG`, then exactly one block exists, keyed `MTG`, with its original start
    time, and still open.
  - [tier 1] Given the same, then the block's colour on the calendar is `MTG`'s —
    `applyCatColor_` runs, as it does for the mis-tap correction.
  - [tier 1] Given the block carries a note, when it is recategorised whole, then
    the note survives.
  - [tier 1] Given SPLIT's existing remainder path is used instead, then it still
    produces two blocks exactly as it does today. **The new option must not change
    the old one.**
  - [tier 1] Given the block is recategorised whole to `BODY` while a SIT is open,
    then the SIT closes — the coupling applies here as it does to a tap.
  - [tier 1, error] Given the server is rejecting, when recategorise-whole is
    confirmed, then the UI shows the new category immediately and the op is queued;
    and when the client reboots before the queue drains, the queued op is still
    there and still correct.
  - [tier 1, error] Given no block is open, then the whole-block option is not
    reachable.
  - [tier 3] Given the SPLIT sheet is open at 390px, then both options are visible
    and visually distinguishable without scrolling.
- test notes: `test/tests.js` plus one added assertion in `test/headless.js`. The
  "must not change the old one" criterion is best written by keeping the existing
  SPLIT tests untouched and asserting they still pass, rather than by writing new
  ones that restate them.

---

### Stage D — The small honesty fixes

Finding 6 and the tier-3 findings. Three unrelated bugs of the same shape: the app
states something it does not actually know. Last because each is independent,
cheap, and survivable as a named remainder.

#### D1. An unparseable title stops being filed as Admin

- what: Two distinct holes, same shape. First, four sites do
  `parseTitle_(...) || { key: 'ADM' }` (`Code.gs:541`, `579`, `704`, `743`), so a
  title that fails to parse is silently *claimed* to be Admin on the write and
  display paths. Second, in `dayStats_` an ACTUAL event whose title either fails to
  parse **or** parses to a key nobody configured (`Re: the thing` → `RE`,
  `9:00 standup` → `9`) contributes nothing at all — its hours vanish from the
  rollup rather than being misfiled. Both get the same answer: a key named for what
  it is, joining `rollupKeys_` (`Code.gs:950`) the way `UNLOGGED` already does.
- risk: medium (four call sites in different contexts — `getState`, `staleGuard_`,
  `opCloseActual_`, `opSplitActual_` — and each needs the fallback to make sense
  locally, not just globally. Also widens the rollup's key set, which changes grid
  width after B2 and B3 have already fixed the column contract.)
- acceptance criteria:
  - [tier 1] Given an ACTUAL event titled `Lunch with Ada`, when the rollup runs,
    then its hours appear under the unparsed key and `ADM` is 0.
  - [tier 1] Given an ACTUAL event titled `Re: the thing` — which parses to key
    `RE`, not configured — then its hours also appear under the unparsed key.
    **Parsed-but-unknown and unparseable get the same home.**
  - [tier 1] Given `rollupKeys_`, then the unparsed key appears exactly once,
    alongside `UNLOGGED`, and every grid built from it has matching columns.
  - [tier 1] Given the open block's title has been hand-edited to something
    unparseable, when `getState` runs, then the client is not told the block is
    `ADM`.
  - [tier 1] Given a configured category is genuinely `ADM`, then nothing about it
    changes — real Admin blocks still land in `ADM`.
  - [tier 1, error] Given `staleGuard_` bounds a block whose title does not parse,
    then it does not write `ADM:` into that title, and the title's original text is
    not destroyed.
  - [tier 1, error] Given B2 and B3 have run, then the new key gets its full set of
    mark columns like every other key, and the golden fixture's header row is
    updated to match.
- test notes: `test/tests.js`. The golden fixture changes again in this task, which
  is expected and reviewable — the diff should show one key's worth of columns
  appended. **The four call sites should each get their own assertion**; a single
  test that only exercises one of them would pass while three stayed wrong.

#### D2. A week the window only partly covers says so

- what: `weeklyGrid_` groups the 90-day window into Monday-to-Sunday weeks
  (`Code.gs:1023`-`1040`), so the oldest row is almost always a partial week
  presented exactly like a complete one — and its plan-versus-actual ratio is
  misleading by construction. The tab marks partial weeks in a column. **Not** a
  suffix on `week of`: that would change the cell from a date to a string and break
  sorting.
- risk: low
- acceptance criteria:
  - [tier 1] Given a 90-day window that begins mid-week, when the rollup runs, then
    the oldest weekly row is marked partial and states how many of its seven days
    the window covered.
  - [tier 1] Given a week the window covers completely, then its row is not marked
    partial.
  - [tier 1] Given the newest week — the current one, which is incomplete unless
    today is Sunday — then it is also marked partial.
  - [tier 1] Given any weekly row, then its `week of` cell is still a date value,
    not a string. Sorting and formulas are unaffected.
  - [tier 1, error] Given a window that happens to start on a Monday and end on a
    Sunday, then no row is marked partial. The rule is about coverage, not about
    position in the list.
  - [tier 1, error] Given the window is shortened so that it covers a single
    partial week, then that one row is marked partial and the tab is otherwise
    well-formed.
- test notes: `test/tests.js`, varying `ROLLUP_DAYS` and the fixed clock so the
  window's edges land on known weekdays. Run under all four contracted timezones —
  `mondayStartMs_` (`Code.gs:523`) is local-midnight arithmetic and is exactly
  where a timezone bug would hide.

#### D3. The grid stops showing a live block whose write was set aside

- what: When an `openActual` is quarantined (`Index.html:589`), the block was never
  created on the calendar — so every later op for that ref is a silent no-op
  (`findByRef_` returns null, `opCloseActual_` returns early), while the grid keeps
  showing the block lit and its clock ticking. The banner does persist, so it is
  findable; **the grid is what lies.**
- risk: low
- acceptance criteria:
  - [tier 1] Given the server rejects every call and an `openActual` is set aside
    after `MAX_OP_TRIES`, then no cell in the grid renders as active.
  - [tier 1] Given the same, then `S.open` no longer holds that ref, so no later
    close is queued against a block that was never created.
  - [tier 1] Given a `setMark` — not an open — is set aside while a block is
    running, then the block **is** still shown running. Only a set-aside open
    clears the grid.
  - [tier 1] Given a `splitActual` is set aside, whose `newRef` is the open block,
    then the grid also stops showing it as running — the split's new block is an
    open by another name.
  - [tier 1, error] Given the set-aside open is then discarded from the drawer,
    then the grid is still idle and nothing throws.
  - [tier 1, error] Given the set-aside open is cleared and the user taps a
    category again, then a fresh block opens normally with a new ref.
  - [tier 3] Given a real browser with the server forced to reject, when an open is
    set aside, then the drawer opens from the banner and no lit cell is visible.
- test notes: `test/tests.js` using `setServerReject` and `advance`, plus a phase in
  `test/headless.js` following `checkDrawer`'s shape. The third criterion stops
  this task from over-correcting into "any set-aside write clears the grid", which
  would be a different lie.

---

## When done

All contract assertions pass and the full test suite is green **twice in a row**,
under all four contracted timezones → write `## RUN SUMMARY` at the top of
`factory/progress-2.md`: outcome first, then per-task status, parked items with
reasons, the three vacuity checks and what each proved, and the exact commands a
human can run to see it work.

End your final message to the human with the baton pass, verbatim:

> "The build is done and self-checked. Next step: an independent review that tries
> to break it — open Claude Code and run /factory (or /factory-review). Don't skip
> it; I graded my own homework."

The same applies if you stopped early (circuit breaker, cap): say exactly where
things stand, which stage boundary was the last complete one, and that /factory is
the next step either way.
