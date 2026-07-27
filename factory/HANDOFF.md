# HANDOFF: timetap — error paths round
compiled: 2026-07-26 · source: factory/BRIEF.md + factory/PLAN.md
branch: `factory/error-paths` · baseline: 298 assertions green under 4 timezones, lint clear

---

## How to launch (human instructions — the loop ignores this section)

Launch is two steps: **orientation** while you're still at the keyboard, then **begin**.

**Step 1 — orientation.** Open this project, start a new agent chat, and paste:

> Read factory/HANDOFF.md fully. Do NOT start work yet. First: summarize the goal
> and plan back to me in 5 plain sentences, then ask me anything — questions,
> missing context, access you need — that would improve the result. If you have no
> questions, say so and why.

Answer whatever it asks, have it append the Q&A to the Orientation section below,
**then** step 2.

**Step 2 — begin.**

*Claude Code:*

```
/loop work through factory/HANDOFF.md exactly as written
```

If you don't have a `/loop` command, paste this instead:

> Begin. Execute factory/HANDOFF.md exactly as written. Work the operating loop
> continuously — pick the next unfinished task, build it, verify it, record it in
> factory/progress.md and factory/log.md, then move straight to the next task
> without waiting for me. Only stop when a stop condition or circuit breaker in the
> file triggers; park questions in progress.md and keep going.

*Cursor:* same two steps, using a background/loop agent so it continues unattended.
Enable auto-run only if you accept it running commands without asking — the
guardrails below are your protection.

**The machine must stay awake.** In a spare terminal:

```bash
caffeinate -dims
```

---

## Orientation (executing agent: do this before your first pass)

A different model wrote this document than the one reading it. Before any work:
read this entire file, summarize your understanding to the human, and ask for
anything that would improve the result — unclear criteria, missing context, how to
run things. Append every answer below.

### Orientation Q&A

<!-- executing agent: record each question and the human's answer here. This section
is your memory of the answers — chat history won't survive a restart. If you had no
questions, write "None — <one line why>." -->

Recorded 2026-07-27. Six questions asked, human answered **"yes to all"** — every
recommendation below is approved. These are now standing decisions for the run; do not
re-ask them after a restart.

1. **Editing this file.** The launch instructions say to append the Q&A here; Guardrails
   say never edit this file. Resolution: **this Orientation Q&A block is the single
   sanctioned exception.** Append here and nowhere else in HANDOFF.md. Everything else in
   the file stays byte-identical for the whole run.

2. **Headless browser = Playwright, pinned to an exact version** (no caret) in
   `devDependencies`, so D1's tier-4 canary means something. **`npm install` is approved**
   to run unattended; the registry is reachable and Playwright browsers are already cached
   at `~/Library/Caches/ms-playwright` (chromium build 1234) as of 2026-07-27.

3. **`deploy.sh` may be executed during testing**, but **only** with a stub `clasp` in a
   temp dir *prepended* to `PATH` so it always shadows the real one. Real `clasp` is on
   this machine at `/opt/homebrew/bin/clasp` and `.clasp.json` points at a live script —
   a `PATH` mistake here is a real deployment. Never run `deploy.sh` without the stub in
   front, and assert in the test that the stub, not the real binary, was the one invoked.

4. **B1 captures the category at quarantine time, not at op creation.** The op payload on
   the wire stays exactly as it is today, so `applyOps` on the server sees an unchanged
   shape and the "no behaviour change in normal use" guardrail stays airtight.

5. **C2's golden test gets a committed fixture** under `test/` — capture the grid today's
   unmodified code produces for a fixed event set, commit it, then assert the new code
   reproduces those rows and columns with only the stamp added. Dev-only file; not one of
   the four sources.

6. **No known real-world rollup failure** to design around, and **the drawer's plain-words
   vocabulary is the executing agent's to choose** — within the product law: state the
   fact, stop. "Couldn't save the mark on Deep Work" is a fact. Any wording that advises,
   scores, urges or interprets is out.

Mid-run: if you hit a genuine ambiguity this file doesn't answer, do NOT guess
silently — park the task with your question written in factory/progress.md and move
on. Parked questions get answered by the human in the morning.

---

## Goal

timetap is a personal time-logging web app on Google Apps Script: four source files
at the repo root, no build step, no dependencies, no framework. Tapping a category
writes an event to a Google Calendar, which is the source of truth rather than the
browser. It already works and is already well tested.

This round builds three things, all of which live on code paths that only run after
something has already gone wrong: **a headless smoke test** so a machine can check
the rendered page instead of only a human with a phone and a paste; **a drawer for
lost writes** so a write the app gave up on tells you where to go fix it by hand
instead of vanishing behind a count; and **a rollup that admits it failed** so stale
numbers announce themselves rather than being trusted for weeks. Nothing in normal
use changes — tapping a category, closing a block, the mark strip, the posture
button, split and sit-edit all behave exactly as they do today.

**Done means every Contract assertion passes when run, not when read.**

---

## Operating loop (follow exactly)

You are the BUILDER. Each pass:

1. **GATHER** — read `factory/progress.md` and this file's task list. Pick the first
   unfinished, unblocked task. Tasks are in dependency order; do not reorder them.
2. **ACT** — implement that one task only.
3. **VERIFY** — run the task's acceptance criteria, plus all tier-1 tests and any
   tier-3 tests that exist yet:
   ```bash
   node test/tests.js && node test/lint.js
   ```
   At every stage boundary, also run the suite under all four timezones:
   ```bash
   for z in America/New_York Europe/London Australia/Sydney UTC; do TZ=$z node test/tests.js | tail -1; done
   ```
   Every day boundary in this app is timezone-dependent; a suite that is green in one
   zone and red in another has a real bug, not a flaky test.
4. **RECORD** — update `factory/progress.md` (task status, attempt count) and append
   one line to `factory/log.md`: `## [date time] <task id> | <what happened>`.
5. Repeat. **Assume you may be killed and restarted at any moment — those two files
   are your only memory.**

---

## Checker (independent verification)

When a task's criteria pass, verify as a CHECKER before marking it done: re-run the
tests fresh and confirm the observable behaviour directly. If your tool supports
subagents, spawn a fresh one with only this file and the diff, instructed to try to
**prove the task does NOT meet its criteria**.

The builder never gets the final vote on its own work.

**Specific to this round:** every feature here lives on an error path that normal use
never reaches. A criterion "verified" by observing the happy path and inferring the
rest is not verified. Force the failure — a server that always rejects, a sheet id
that cannot open, a deliberately desynchronised tag list — and watch what actually
happens.

---

## Circuit breakers (hard limits)

- Same task fails verification **3 times** → mark it PARKED in `factory/progress.md`
  with what you tried and why you think it failed, then move to the next unblocked
  task. **Never delete or weaken a parked task's criteria to make it "pass".**
- **3 tasks parked**, or every remaining task blocked → STOP. Write the summary and
  end the run.
- A **tier-4 canary** fails (the pinned browser won't launch) → that is the outside
  world, not your code. Log it, flag it in progress.md, and never "fix" working code
  in response.
- **Hard cap: 25 passes or 8 hours, whichever comes first** → stop and summarize.

---

## Restart permission

If an approach is truly unsalvageable, you may throw away uncommitted work on the
current task and rebuild it from this document. Log the restart. A restart resets
that task's failure count.

Restarting a task is the loop working. Silently narrowing its criteria is the loop
failing.

---

## Guardrails (never violate)

- Work only on branch **`factory/error-paths`**. Never commit to `main`. Never
  force-push. Pushing to the remote is not required by any task in this run.
- Commit after each task passes verification, message: `<task id>: <task title>`.
- **Never edit this file.** Never delete or weaken an acceptance criterion — if one
  seems wrong, PARK the task with a note instead.
- **Never write to the PLAN calendar.** PLAN is hand-written by the human and
  read-only to this app, structurally and permanently. `test/lint.js` has a rule
  enforcing that no writable handle to it exists; that rule stays.
- **Never add a dependency that the four source files import.** `Code.gs`,
  `Index.html`, `appsscript.json` and `SETUP.md` stay dependency-free with no build
  step. The headless browser is dev-only tooling that runs on the developer's
  machine, never in the deployed app.
- Do not change normal-use behaviour: the grid, category taps, the mark strip,
  posture, split and sit-edit are out of scope. Their existing tests must keep
  passing unmodified.
- Do not touch `.github/workflows/pages.yml`. CI stays as it is; this round adds no
  CI job.
- Do not test against a deployed URL, and do not run `./deploy.sh` in a way that
  actually pushes to Apps Script. Deploy-related criteria are exercised with a
  stubbed `clasp` on `PATH`.
- Secrets stay out of the repo. `.clasp.json` is gitignored and machine-specific;
  never commit it, never print its contents.

### The product law this codebase is built on

From `README.md`: **automate capture, never automate judgment.** The app never
interprets, scores, advises, summarises, reminds or nudges. Its non-goals are
binding and explicit: no notifications, no automatic detection of anything, no
streaks/scores/badges, no AI summaries or insights, no charts, no settings screen,
no onboarding.

Everything you build this round states facts and stops. A stale timestamp is a fact.
"⚠ Your rollup is 11 days out of date, you should check it" is judgment. If a choice
you're about to make would add interpretation, take the plainer option.

---

## Contract (component-level — final sign-off runs ALL of these)

**The existing app is unharmed**

1. `node test/tests.js` passes with **at least 298 assertions** — the count measured
   green on 2026-07-26, before this round began — and the count only ever goes up.
   (`test/README.md` says 253; it is stale, and E1 fixes it.)
2. `node test/tests.js` passes under `TZ=America/New_York`, `Europe/London`,
   `Australia/Sydney` and `UTC`.
3. `node test/lint.js` passes, with every existing rule still present.
4. No behaviour change in normal use: opening a block, closing it, the mark strip,
   posture, split and sit-edit all behave exactly as their existing tests assert.
5. The four source files (`Code.gs`, `Index.html`, `appsscript.json`, `SETUP.md`)
   import nothing and require no build step. Anything added is dev-only tooling.
6. `appsscript.json` still asks for exactly one OAuth scope.

**Lost writes are findable**

7. Given writes that the server rejects every time, when a write is retried
   `MAX_OP_TRIES` (5) times, then it leaves the queue and appears in the dead list.
8. Given a network failure rather than a server rejection, when flush is retried any
   number of times, then nothing is ever set aside — network failures are what
   retrying is for (`Index.html:490`).
9. Given at least one set-aside write, when the app loads, then the error banner is
   visible and can be opened.
10. Given the drawer is open, then every set-aside write shows when it happened,
    which category it belonged to, what it was trying to do in words, and why it
    failed.
11. Given an entry is discarded, then it is gone from the dead list and does not
    return after a reload.
12. Given every entry is discarded, then the banner is hidden and the boot-time
    message does not appear on the next load.
13. Nothing in the drawer ever writes to a calendar. Discarding touches the dead list
    only, never the queue.

**The rollup admits it failed**

14. Given a working spreadsheet, when `dailyRollup` runs, then both tabs carry a
    last-rebuilt timestamp in the script timezone, and the outcome is recorded in a
    script property.
15. Given a spreadsheet id that cannot be opened, when `dailyRollup` runs, then the
    failure and its reason are recorded in the script property, and the record of the
    last *successful* run is preserved.
16. Given a run fails, then the last-rebuilt stamp in the sheet is **not** refreshed —
    a failed run must never make the numbers look current.
17. Given the rollup runs twice, then exactly one stamp exists per tab, and the day
    rows and category columns are byte-identical to what the same run produced before
    this round (the stamp shifts no existing row or column).
18. Given no rollup has ever run, when the hand-run report function is called, then it
    says so plainly rather than throwing or printing `undefined`.

**The machine can see the screen**

19. Given a checkout with dev dependencies installed, when the headless run executes,
    then it renders `Index.html` at a phone viewport and a desktop viewport, runs
    `test/smoke.js` itself in the page, and reports non-zero check counts for each
    viewport.
20. Given the rendered page, then the meta tags present are exactly the ones `doGet`
    adds (`Code.gs:180-182`), same names and same content strings.
21. Given the meta tag list in `Code.gs` and the one in the headless harness differ —
    in either direction, by name or by content — then `node test/lint.js` fails and
    names the offending tag.
22. Given zero checks ran, or the browser is not installed, then the headless run
    exits non-zero. A skipped run is never reported as a pass.
23. Given any test layer fails, when `./deploy.sh` runs, then it exits non-zero and
    pushes nothing.

**Tiers used this round.** Tier 1 (offline) and tier 3 (end-to-end smoke) only. There
is no tier 2 — nothing in this round touches a live external service, since testing
against the deployed URL is explicitly out of scope. One tier 4 canary is noted in D1
and never blocks the loop.

**Two standing rules.**

- **Every bug found later gets a criterion here first, then the fix.** If you discover
  a bug while building, add its criterion to `factory/progress.md` under the relevant
  task before you fix it.
- **The builder never grades its own work.** Criteria are checked by running them;
  final judgment belongs to an independent review that never sees your reasoning.

---

## What you are working on (orientation facts)

Read these before your first task; they will save you a wrong turn.

**The four source files.**

| File | What it is |
|---|---|
| `Code.gs` (1104 lines) | Server. CONFIG block at the top, calendar reads/writes, day aggregation, the rollup. |
| `Index.html` (1063 lines) | Client. All HTML/CSS/JS inlined. No CDN, no build step. |
| `appsscript.json` | Manifest. One OAuth scope. |
| `SETUP.md` | Deployment steps and required Google Calendar settings. |

**How the app works.** The calendar is the source of truth, not localStorage. Tapping
a category immediately creates an event with `start = now`, `end = now + 1 minute`
and `#open` in the description. The next tap patches the end to that instant, applies
the mark, and strips `#open`. On load, the open block is found by querying the
calendar rather than by trusting the browser. The UI updates on tap and the write
happens in the background; a failed write is queued in localStorage, ordered and
idempotent, and retried on the next interaction and on load.

**The three test layers** (documented in `test/README.md`):

- `node test/tests.js` — assertions against the real `Code.gs` and the real script
  extracted from `Index.html`, run in node behind a shim for `CalendarApp`,
  `SpreadsheetApp`, `PropertiesService`, `ScriptApp`, `HtmlService`, `LockService` and
  a small DOM. A virtual clock lets a test wait ninety minutes in a millisecond.
- `node test/lint.js` — static checks over the source. Every rule exists because a bug
  of exactly that shape shipped, and none is reachable by running the code.
- `test/smoke.js` — pasted into a browser console with the app open; returns
  `{ pass, fail, failed }`. The only layer that has ever seen a pixel. **This round
  gives it a machine runner. It does not retire it** — two of the three bug classes it
  exists for only ever appeared on a phone.

**Harness facts that matter for this round** (`test/harness.js`):

- The DOM shim only resolves ids the markup actually declares (line 220). A handler
  wired to an undeclared id returns `null` and throws on next access, exactly as in a
  browser. This is deliberate and has caught two real bugs.
- `querySelector` mirrors two real parser behaviours (line 192): a selector absent
  from the markup matches nothing, and interactive content inside a `<button>` is
  dropped.
- `setOnline(false)` simulates a **network** failure — it fires the failure handler.
  A **server** rejection is different: `applyOps` returns an `errors` array through the
  *success* handler (`Code.gs:629`, `Index.html:472`). Only server rejections count
  against an op's try count. A1 exists to make that second path reachable.
- `SCRIPT_PROPS`, `SHEETS`, `TRIGGERS` and `LOGGED` are exported and cleared by
  `reset()`. `SpreadsheetApp.openById` already throws for an unknown id (line 120), so
  C1's failure path needs no new shim machinery.
- `reboot()` reruns the real client script against the same `localStorage` — that is
  how you test "does it come back after a reload".

**A warning recorded in `test/README.md:63`, worth repeating because this round is
full of chances to repeat the mistake:** an assertion that cannot fail is worse than
no assertion, because it is counted. `smoke.js` once used `!!cond`, and an empty array
is truthy, so two checks passed vacuously no matter what they found.

---

## Tasks

### Stage A — Prove a failure can be forced

The whole round is error-path code. Before building any of it, the harness has to be
able to *reach* those paths on demand. This is the walking skeleton: it proves the
loop can force a failure and observe the result, which every later stage depends on.

#### A1. A test can make every server call fail, and prove a write ends up set aside

- **what:** Extend the shim in `test/harness.js` so a test can put the server into a
  mode where `applyOp_` throws, which makes the real `applyOps` return a non-empty
  `errors` array (`Code.gs:629`). That is the path a *server* rejection travels —
  distinct from `setOnline(false)`, which fires the failure handler and is deliberately
  not counted against an op's tries (`Index.html:490`). Then assert today's behaviour:
  after `MAX_OP_TRIES` rejections the op leaves the queue and lands in the dead list,
  capped at 50 entries.
- **proves:** Nothing user-visible on its own. It is the precondition for B1-B3 having
  honest tests instead of happy-path ones.
- **risk:** low
- **acceptance criteria:**
  - [tier 1] Given the harness in server-reject mode, when a queued write is flushed,
    then the real `applyOps` returns `errors` with one entry carrying the op's `id` and
    the thrown message — the failure travels the server path, not the harness's offline
    shortcut.
  - [tier 1] Given server-reject mode, when the queue is flushed and the retry timer is
    advanced until 5 attempts have been made, then the op is no longer in the queue, the
    dead list holds exactly one entry, and that entry's reason is the server's message.
  - [tier 1] Given server-reject mode, when only 4 attempts have been made, then the op
    is still in the queue and the dead list is empty — the threshold is exact, not
    approximate.
  - [tier 1, error] Given `setOnline(false)` — a network failure, not a server rejection
    — when flush is retried 8 times, then the op is still in the queue and the dead list
    is still empty.
  - [tier 1, error] Given 60 writes have been set aside, then the dead list holds exactly
    50 and the ones it kept are the newest.
- **test notes:** `test/harness.js` gains the reject switch and exports it alongside
  `setOnline`; assertions live in `test/tests.js`. Retries are driven by advancing the
  virtual clock (`retryDelay` starts at 4s and doubles to a 60s ceiling,
  `Index.html:522`), not by real waiting.
- **⚠ If any of these fail against today's unmodified code, that is a finding: record
  it in `factory/progress.md`, PARK the task, and move on. Do not edit `Index.html` to
  make an assertion about existing behaviour go green.**

---

### Stage B — Lost writes are findable

After this stage: a write the app gave up on can be found and fixed by hand in Google
Calendar, instead of vanishing behind a count.

#### B1. A set-aside write records enough to identify the block it belonged to

- **what:** Today `quarantine()` stores `{ at, why, op }` (`Index.html:508`). That is
  not always enough to find anything: ops carry `type`, `id`, `ts` and `ref`, but only
  `openActual` and `splitActual` carry a category `key` (`Index.html:411`). A dead
  `setMark`, `closeActual` or `setText` names no category at all. Capture the category
  and the block's start time at the point the op is created or quarantined, so every
  entry is self-describing.
- **proves:** "which category, what it was trying to do" from the done-test.
- **risk:** low
- **acceptance criteria:**
  - [tier 1] Given a `setMark` write is set aside, then its dead entry names the category
    of the block the mark belonged to and that block's start time.
  - [tier 1] Given a `closeActual` write is set aside, then its dead entry names the
    category of the block being closed.
  - [tier 1] Given an `openActual` write is set aside, then its dead entry names the
    category that was tapped.
  - [tier 1, error] Given a set-aside write whose category has since been removed with
    `removeCategory` (`Code.gs:358`), then the entry still names that key rather than
    rendering blank or throwing.
  - [tier 1, error] Given a dead entry written by an older version, missing the new
    fields entirely, when it is read, then it is rendered with the missing parts shown as
    unknown and nothing throws.
- **test notes:** `test/tests.js`, using A1's reject switch. The last criterion is seeded
  by writing a legacy-shaped entry straight into `localStorage` before boot.

#### B2. Tapping the error banner opens a drawer listing the set-aside writes

- **what:** Make `#err` (`Index.html:307`) tappable when the dead list is non-empty,
  opening a third full-screen overlay sheet built the same way as `#sheetSplit` and
  `#sheetSit` (`Index.html:311`, `Index.html:332`). One row per set-aside write, newest
  first: when it happened, which category, what it was trying to do, and why it failed —
  in words, not op types. Reachable by keyboard and announced, the same way the grid's
  cells already are (`Index.html:726`).
- **proves:** "the app's error banner is tappable... opens a sheet listing each set-aside
  write."
- **risk:** low
- **acceptance criteria:**
  - [tier 1] Given two set-aside writes, when the app boots and the banner is tapped, then
    the drawer is visible and holds exactly two rows, newest first.
  - [tier 1] Given the drawer is open, then each row shows a clock time, a category, a
    description in ordinary words (not `setMark` or `closeActual`), and the failure reason.
  - [tier 1] Given the dead list is empty, when the app boots, then the banner is hidden
    and tapping where it would be does nothing.
  - [tier 1] Given the drawer is open, when it is closed, then the grid is interactive
    again and a category tap still opens a block.
  - [tier 1, error] Given a dead entry whose op type the drawer has no wording for, then
    the row renders showing the raw type rather than a blank row, and nothing throws.
  - [tier 1] Given the drawer's markup, then every id its script reads is declared and no
    interactive content sits inside a `<button>` — the existing lint rules cover the new
    markup too.
- **test notes:** `test/tests.js` for behaviour; `test/lint.js` already enforces the markup
  rules and must be run against the new elements. The DOM shim only resolves ids the markup
  actually declares (`test/harness.js:220`), so a drawer wired to an undeclared id fails
  loudly rather than silently.

#### B3. An entry can be discarded, and the banner clears when the last one goes

- **what:** Each row can be discarded once it has been dealt with by hand. Discarding the
  last entry empties the dead list, closes the drawer, and hides the banner, so the
  boot-time message (`Index.html:964`) does not reappear on next load.
- **proves:** "Each entry can be discarded once handled."
- **risk:** low
- **acceptance criteria:**
  - [tier 1] Given two entries, when one is discarded, then one row remains, the dead list
    in `localStorage` holds one, and the drawer stays open.
  - [tier 1] Given one entry, when it is discarded, then the dead list is empty, the drawer
    closes, and the banner is hidden.
  - [tier 1] Given every entry has been discarded, when the app reloads, then no set-aside
    message appears.
  - [tier 1, error] Given a pending write is sitting in the queue, when a dead entry is
    discarded, then the queue is unchanged — discarding never touches pending work.
  - [tier 1, error] Given discard is invoked twice on the same row, then the second is a
    no-op and nothing throws.
- **test notes:** `test/tests.js`. Reload is `reboot()` from the harness, which reruns the
  real client script against the same `localStorage`.

---

### Stage C — The rollup admits it failed

After this stage: numbers in the sheet are as fresh as they look, or visibly are not.

#### C1. A failed rollup records why, where the failure cannot erase it

- **what:** `dailyRollup` (`Code.gs:817`) has no try/catch and no memory. Wrap it so the
  outcome — success or failure, with reason and timestamp — is recorded in a script
  property, which stays writable even when the likeliest failure is `openSheet_` itself
  refusing a bad or revoked sheet id (`Code.gs:972`). **Record, then rethrow**, so the
  platform's own execution list still shows the run as failed; the recording is what makes
  it findable, not a reason to swallow the error.
- **proves:** "Breaking the sheet id and running the rollup records the failure where it
  can still be read."
- **risk:** medium (it is the daily trigger's entry point; a mistake here silently stops the
  rollup entirely, which is the exact failure the task exists to prevent)
- **acceptance criteria:**
  - [tier 1] Given a working spreadsheet, when `dailyRollup` runs, then it still returns
    `{ days, categories, sheet }` exactly as today, and the script property records a
    success with a timestamp.
  - [tier 1, error] Given a spreadsheet id that cannot be opened, when `dailyRollup` runs,
    then the script property records the failure and its reason, and the error is rethrown
    so the platform marks the execution failed.
  - [tier 1, error] Given a successful run followed by a failing run, then the record still
    shows when the last *success* was — a failure must never erase the only evidence of the
    last good run.
  - [tier 1, error] Given `openSheet_` succeeds but `writeGrid_` throws partway, then the
    failure is recorded with its reason.
  - [tier 1] Given a failing run followed by a successful one, then the record shows the
    success as current.
- **test notes:** `test/tests.js`. The harness's `SpreadsheetApp.openById` already throws
  for an unknown id (`test/harness.js:120`) and `SCRIPT_PROPS` is exported and cleared by
  `reset()`, so both paths are reachable without new shim machinery.

#### C2. Both generated tabs carry a "last rebuilt" line

- **what:** `writeGrid_` (`Code.gs:985`) rebuilds each tab wholesale, so the stamp is
  written as part of the grid rather than patched in afterwards. Both `daily` and `weekly`
  carry it. **The stamp goes in row 1, in the first column after the last data column** —
  not a new row above the data. `README.md` tells the user to point formulas from their own
  tabs at these ones; a stamp row at the top would silently shift every row reference they
  already have.
- **proves:** "Opening the rollup spreadsheet shows a 'last rebuilt' line in both tabs...
  the stamp in the sheet stays old."
- **risk:** low
- **acceptance criteria:**
  - [tier 1] Given a successful rollup, then the `daily` tab carries a last-rebuilt
    timestamp formatted in the script timezone.
  - [tier 1] Given a successful rollup, then the `weekly` tab carries the same.
  - [tier 1] Given the rollup runs twice, then each tab holds exactly one stamp — it is
    rewritten, not appended.
  - [tier 1] Given a rollup that produced grids before this round, then the day rows and
    category columns are unchanged in position and content; only cells beyond the last data
    column are new.
  - [tier 1, error] Given a rollup that fails, then the stamp already in the sheet is
    unchanged — a failed run never refreshes it.
  - [tier 1] Given `TZ` is set to `Australia/Sydney`, then the stamp reflects the script
    timezone rather than UTC.
- **test notes:** `test/tests.js`, reading `SHEETS.book` rows via the existing `FSheet`
  shim. The fourth criterion is best written as a golden test: capture the grid the current
  code produces for a fixed set of events, then assert the new code produces the same rows
  and columns with only the stamp added.

#### C3. The last outcome can be read by hand when the sheet cannot be opened at all

- **what:** A function runnable from the editor that reports the recorded outcome through
  `say_` (`Code.gs:811`), so that when the stamp is stale the next question — *why* — has
  an answer that does not require reading execution history.
- **proves:** Completes "recorded somewhere always writable".
- **risk:** low
- **acceptance criteria:**
  - [tier 1] Given a recorded failure, when the report function runs, then its returned
    string names when the last success was and what the last failure was, and the same
    string is written to the log.
  - [tier 1, error] Given no rollup has ever run, then it says so in plain words and neither
    throws nor prints `undefined`.
  - [tier 1, error] Given a script property holding malformed data, then it reports that it
    cannot read the record rather than throwing.
- **test notes:** `test/tests.js`, asserting on the returned string and on `LOGGED`, which
  the harness already collects (`test/harness.js:64`).

---

### Stage D — The machine can see the screen

The expensive stage, and the one to expect a stall in. Ordered so that even a partial
Stage D leaves the repo working: nothing here changes app behaviour, and `deploy.sh` is
not touched until the last task.

#### D1. A real browser engine opens Index.html and reports a result

- **what:** The thinnest end-to-end slice of this stage. Add the repo's first
  `package.json` with a headless-browser dev dependency, and a runner under `test/` that
  opens `Index.html` in a real engine and reports something true about the rendered page.
  `node_modules/` is already ignored (`.gitignore:1`).
- **proves:** The stack works before anything is built on it.
- **risk:** medium (first dependency in a repo whose README opens with "no dependencies";
  source files must stay dependency-free — this is dev-only tooling)
- **acceptance criteria:**
  - [tier 3] Given dev dependencies are installed, when the runner runs, then it exits 0 and
    prints a fact derived from the rendered page — the number of category cells actually
    present in the grid — rather than a hardcoded string.
  - [tier 1] Given `package.json`, then the browser sits under `devDependencies`, and
    `Code.gs`, `Index.html` and `appsscript.json` contain no import, require or CDN URL.
  - [tier 1, error] Given the browser is not installed, when the runner runs, then it exits
    non-zero with a message naming the exact install command. It never exits 0.
  - [tier 4, canary] The pinned browser version still launches on this machine. Failure is
    logged and flagged, and never blocks the loop or triggers a "fix".
- **test notes:** New runner file under `test/`. The tier-1 criterion is a rule in
  `test/lint.js`, so it runs with no install. Tier 3 is the runner itself.

#### D2. The harness serves the page the way Apps Script serves it, and runs the real smoke checks

- **what:** Apps Script ignores meta tags written into the HTML file and injects three of
  the four names it permits — `viewport`, `apple-mobile-web-app-capable` and
  `mobile-web-app-capable` (`Code.gs:180-182`). The harness must inject the same three, with
  the same content strings, before the page renders, or it is testing a document the phone
  never loads. It must also substitute the `bootstrap` placeholder with real config, exactly
  as `doGet` does — the client script throws without it (`test/harness.js:279`). Then load
  `test/smoke.js` itself into the page and read its `{ pass, fail, failed }`. **Do not
  reimplement its checks in the runner.**
- **proves:** "renders `Index.html` at a phone viewport... runs the checks that are already
  in `test/smoke.js`, and reports pass/fail counts."
- **risk:** medium (if the tags are injected after render, or the page is loaded in a way
  that changes what `smoke.js` sees, the run passes while testing the wrong document)
- **acceptance criteria:**
  - [tier 3] Given the harness renders the page, when the document's meta tags are read from
    the live DOM, then they are exactly the three `doGet` adds, with identical content strings.
  - [tier 3] Given the rendered page, then the bootstrap placeholder has been replaced with
    real config and the client script has run without error — the grid holds one cell per
    configured category.
  - [tier 3] Given the page is rendered at a phone viewport, when `test/smoke.js` is evaluated
    in it, then it returns a `pass` count equal to the number of checks the file contains, and
    `fail` is 0.
  - [tier 3, error] Given a check inside `smoke.js` fails, then the runner exits non-zero and
    prints the contents of `failed`, naming which check broke.
  - [tier 1, error] Given `smoke.js` returns `pass: 0`, then the runner treats it as a failure
    and exits non-zero. **Zero checks is never a pass** — this is the vacuous-assertion guard,
    and `test/README.md:63` records why.
  - [tier 3, error] Given the meta tags are injected after the page has rendered rather than
    before, then the viewport-dependent checks in `smoke.js` fail — proving the injection point
    actually matters and is not decorative.
- **test notes:** The runner asserts against the live DOM, never against the file on disk. The
  count in the third criterion should be derived from `smoke.js` rather than hardcoded, so
  adding a check there cannot silently go unrun.

#### D3. It runs at a desktop viewport too, and reports per viewport

- **what:** Same checks at a desktop viewport, with results attributed to the viewport they
  came from, so a failure names which one broke.
- **proves:** "at a phone viewport and a desktop viewport."
- **risk:** low
- **acceptance criteria:**
  - [tier 3] Given the runner runs, then it reports a separate pass/fail count for the phone
    viewport and for the desktop viewport, each labelled with its dimensions.
  - [tier 3] Given both viewports pass, then the runner exits 0.
  - [tier 3, error] Given a check fails at the phone viewport only, then the runner exits
    non-zero and its output names the phone viewport as the failing one.
  - [tier 3, error] Given one viewport produced zero checks, then the runner exits non-zero even
    if the other viewport passed.
- **test notes:** Same runner. The failing-viewport criterion is exercised by temporarily
  narrowing a CSS assumption in a fixture, not by editing `Index.html`.

#### D4. Changing the meta tags in only one place fails the lint by name

- **what:** A rule in `test/lint.js` that compares the tag list `doGet` actually injects
  (`Code.gs:180-182`) against the list the headless harness injects, and fails when they
  diverge. **This is the single check that makes rendering locally honest rather than a
  convenient fiction.**
- **proves:** "Deliberately changing the meta-tag list in `Code.gs` without changing the harness
  makes a lint check fail by name."
- **risk:** HIGH (load-bearing, and the easiest check in the round to write so that it cannot
  fail — the vacuous-assertion bug `test/README.md:63` already records)
- **acceptance criteria:**
  - [tier 1] Given `Code.gs` and the harness agree, when `node test/lint.js` runs, then the rule
    passes.
  - [tier 1, error] Given a fourth tag added to `doGet` and not to the harness, then lint fails,
    exits non-zero, and the message names that tag and says which side is missing it.
  - [tier 1, error] Given a tag added to the harness and not to `doGet`, then lint fails the same
    way — the check runs in both directions.
  - [tier 1, error] Given both sides declare `viewport` but with different content strings, then
    lint fails and names `viewport`. Comparing names alone is not enough; the viewport's content
    is the load-bearing part.
  - [tier 1, error] Given a tag whose name `doGet` uses is outside the four Apps Script permits
    (`test/harness.js:88`), then lint fails — that is a deploy-time crash otherwise.
  - [tier 1] Given the same tags declared in a different order, then lint passes — order is not
    meaningful.
  - [tier 1] **Meta-test: given the rule is replaced with one that always returns true, then at
    least three of the criteria above fail.** The rule's tests must be capable of failing; a check
    that cannot fail is worse than no check, because it is counted.
- **test notes:** The divergence cases are run against fixture copies of the two sources in a temp
  directory — **never by editing `Code.gs` in place**, which would leave the repo dirty if the run
  dies partway. The meta-test can be a scripted assertion or a documented manual step, but it must
  actually be performed and its result recorded in `factory/log.md`.

#### D5. deploy.sh runs it as a third gate, and a missing browser blocks the deploy

- **what:** `deploy.sh` runs `tests.js` and `lint.js` before pushing; add the headless run as a
  third gate. If the browser is not installed, say so unmissably and **exit without deploying** —
  never report a skipped run as a pass. `--no-test` keeps skipping everything, as it does today.
- **proves:** "Running `./deploy.sh` runs three test layers, not two... If the browser isn't
  installed, it says so loudly and the deploy does not proceed."
- **risk:** medium (touches the path between an edit and the phone; a mistake here either blocks
  every deploy or silently gates nothing)
- **acceptance criteria:**
  - [tier 3] Given all three layers pass, when `./deploy.sh` runs, then it reaches the push step.
  - [tier 3, error] Given the headless layer exits non-zero, when `./deploy.sh` runs, then it exits
    non-zero and `clasp` is never invoked.
  - [tier 3, error] Given the browser is not installed, when `./deploy.sh` runs, then it prints an
    unmissable message and exits non-zero without pushing.
  - [tier 3] Given `--no-test`, then all three layers are skipped and the deploy proceeds, exactly
    as today.
  - [tier 1] Given `./deploy.sh --help`, then the output describes three test layers.
- **test notes:** Exercised with a stubbed `clasp` on `PATH` that records whether it was called, so
  **no real deployment happens during testing**. `set -euo pipefail` is already in force
  (`deploy.sh:14`), so a non-zero gate aborts the script by default — the criteria confirm it rather
  than assume it.

---

### Stage E — The documentation tells the truth

#### E1. README and test/README describe what now exists

- **what:** `README.md` opens with "no dependencies", which after Stage D is true of the four source
  files and no longer true of the repo. Restate it accurately rather than letting it quietly become
  false. `test/README.md` describes three layers, one of them "a paste into a browser console" that
  is "the only one that has ever seen a pixel" — update it to describe the headless run, the drift
  rule, and the fact that the phone paste is still required and still not superseded.
- **proves:** "the manual phone paste stays exactly as it is" survives contact with a reader six
  months from now.
- **risk:** low
- **acceptance criteria:**
  - [tier 1] Given `README.md`, then it states that the four source files have no dependencies and
    that the test tooling is dev-only — no unqualified claim that the repo has none.
  - [tier 1] Given `test/README.md`, then it documents the headless runner, how to install it, the
    drift rule and what bug it prevents, in the same table idiom the file already uses for lint rules.
  - [tier 1] Given `test/README.md`, then the instruction to run `smoke.js` on the phone is still
    present, and no sentence anywhere claims the headless run replaces it.
  - [tier 1] Given `test/README.md`, then the assertion count it quotes matches what
    `node test/tests.js` actually reports. It currently says 253; the real count on 2026-07-26 was 298.
  - [tier 1, error] Given the docs, then no command they tell you to run is one that does not exist —
    every command named is runnable as written.
- **test notes:** Checked by reading, and by running every command the docs name. The third criterion
  is the one most likely to be quietly violated by a helpful rewrite.

---

## When done

All contract assertions pass and the full test suite is green twice in a row, under all four
timezones → write `## RUN SUMMARY` at the top of `factory/progress.md`: outcome first, then per-task
status, parked items with reasons, and the exact commands a human can run to see it work.

End your final message to the human with the baton pass, verbatim:

> The build is done and self-checked. Next step: an independent review that tries to break it — open
> Claude Code and run /factory (or /factory-review). Don't skip it; I graded my own homework.

The same applies if you stopped early (circuit breaker, cap): say exactly where things stand and that
/factory is the next step either way.
