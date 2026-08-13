# HANDOFF: timetap — Path 3 (SwiftUI writes Calendar itself)
compiled: 2026-08-12 · source: factory/BRIEF-3.md + factory/PLAN-3.md
round: 3 · branch: `path-3-ios`

## How to launch (human instructions — the loop ignores this section)

Launch is two steps: **orientation** (while you're still at the keyboard), then
**begin**.

**Cursor:** open this project, start a new Agent chat, paste:

> "Read factory/HANDOFF-3.md fully. Do NOT start work yet. First: summarize the
> goal and plan back to me in 5 plain sentences, then ask me anything —
> questions, missing context, access you need — that would improve the result. If
> you have no questions, say so and why."

Answer its questions, have it append the Q&A to this file's Orientation section,
then say: "Begin. Execute this file exactly as written." Use a loop/background
agent so it continues unattended. Enable auto-run (yolo) only if you accept it
running commands without asking — the guardrails below are your protection.

**Claude Code:** same two steps, then

    /loop work through factory/HANDOFF-3.md exactly as written

No `/loop`? Paste this instead:

> "Begin. Execute factory/HANDOFF-3.md exactly as written. Work the operating
> loop continuously — pick the next unfinished task, build it, verify it, record
> it in factory/progress-3.md and factory/log-3.md, then move straight to the
> next task without waiting for me. Only stop when a stop condition or circuit
> breaker in the file triggers; park questions in progress-3.md and keep going."

**Before you walk away:** the machine must stay awake overnight. On a Mac, run
`caffeinate -dims` in a spare terminal.

**In the morning:** read the `## RUN SUMMARY` at the top of
`factory/progress-3.md`, then run `/factory` to start the independent review.
Tier-2 live checks (`RUN_LIVE=1` on the iPhone) are yours, not the overnight
loop's.

---

## Orientation (executing agent: do this before your first pass)

A different model wrote this document than the one reading it. Before any work:
read this entire file, summarize your understanding to the human, and ask for
anything that would improve the result — unclear criteria, missing context,
Google iOS OAuth client ID, how to run the iOS tests. Append every answer below.

### Orientation Q&A

**Q1. Google iOS OAuth client ID — do you have one?**
A: Yes. Use GCP project `timetap-505402` (number `1044461934978`) only. Do **not** use `bottle-484122`. iOS client name `timetap`, bundle `app.timetap.ios`. Client ID written to `ios/.secrets/GOOGLE_IOS_CLIENT_ID` (gitignored). Calendar API enabled on `timetap-505402`. Overnight wires this ID; tier-2 live Sign-In still skipped until morning.

**Q2. Checker?**
A: Spawn checkers (not fresh-shell only).

**Q3. Simulator destination?**
A: `iPhone 17 Pro Max` (human pick). `iPhone 16 Pro Max` is not installed. Prefer the iOS 26.5 runtime if two exist; else any available `iPhone 17 Pro Max`.

Mid-run: if you hit a genuine ambiguity this file doesn't answer, do NOT guess
silently — park the task with your question written in `factory/progress-3.md`
and move on. Parked questions get answered by the human in the morning.

---

## Goal

The Path 2 iPhone app already captures time. It posts ops to Apps Script with
an `API_TOKEN`. Path 3 removes that hop. The phone signs in with Google, picks
PLAN / ACTUAL / SITTING, and writes Google Calendar itself. Capture stays at
Path 2 parity. Rollup, Sheets, and the HTML app stay on Apps Script. Events
must match `Code.gs` title grammar, colours, `#ref:` / `#open`, stale `?`,
undo, and STOP, or the rollup lies.

**Done means every Contract assertion passes when run, not when read.**

---

## Operating loop (follow exactly)

You are the BUILDER. Each pass:

1. **GATHER** — read `factory/progress-3.md` and this file's task list. Pick the
   first unfinished, unblocked task. Tasks are in dependency order; do not
   reorder them.
2. **ACT** — implement that one task only. Ponytail (full): the laziest
   solution that meets the criteria. Google Sign-In SDK + `URLSession` to
   Calendar REST. No Google Calendar SDK. No EventKit. No new architecture
   layer `TapStore` does not already need.
3. **VERIFY** — run the task's acceptance criteria plus all tier-1 tests and
   the offline tier-3 tests. At stage boundaries, run the GAS suite again.
   **Do not set `RUN_LIVE=1`.** Skip tier-2; record the skip in
   `factory/progress-3.md`.
4. **RECORD** — update `factory/progress-3.md` (task status, attempt count)
   and append one line to `factory/log-3.md`:
   `## [date time] <task id> | <what happened>`
5. Repeat. **Assume you may be killed and restarted at any moment — those two
   files are your only memory.**

**The commands.** PLAN-3 says `node test/run.js`. That file does not exist.
Whenever a criterion names it, run:

    node test/tests.js && node test/lint.js     # GAS tier 1, every pass
    node test/headless.js                       # GAS HTML tier 3, every pass
                                                # (Path 3 must not break the web app)

    cd ios && xcodegen generate
    xcodebuild -scheme TimeTap \
      -destination 'generic/platform=iOS Simulator' \
      build-for-testing
    xcodebuild -scheme TimeTap \
      -destination 'platform=iOS Simulator,name=iPhone 16' \
      test

If the simulator name is missing, list simulators and use an iPhone 16 /
iPhone 16 Pro destination. Do not require a physical phone overnight.

**Baseline measured green on 2026-08-12, before this path began:**
1196 assertions passed / 0 failed · lint all clear · `main` at `1f84fce` ·
branch `path-3-ios` checked out from that commit.

**Never point a test at a real calendar or spreadsheet.** Fake calendars
only. Never run `deploy.sh`. Never `clasp push`. Never `git push`.

---

## Checker (independent verification)

When a task's criteria pass, verify as a CHECKER before marking it done: re-run
the tests in a **fresh shell** and confirm the observable behaviour. If your
session forbids unsolicited subagents, that fresh-shell re-run **is** the
checker — record `checker: fresh shell` in `factory/log-3.md`. Do not spawn
subagents unless the human asked. The builder never gets the final vote on its
own work.

Five tasks carry a **mandatory vacuity check** — record in `factory/log-3.md`
what was reverted and what went red:

- **A3** — omit `colorId` on the insert; the colour criterion must go red.
- **B1** — revert the Swift mark regex to `[+=\\-]`; the `?` parse criteria
  must go red.
- **B2** — remove the already-closed `closeActual` guard; the stretch
  criterion must go red.
- **B3** — skip the `if (ne) return` early-return; the double-open criterion
  must go red.
- **D2** — delete the last-write-wins sentence from `ios/README.md`; lint
  must fail and name that file. Put the sentence back.

---

## Circuit breakers (hard limits)

- Same task fails verification **3 times** → mark it PARKED in
  `factory/progress-3.md` with what you tried, move to the next unblocked task.
  **Never delete a parked task's criteria to make it "pass".**
- **3 tasks parked**, or every remaining task blocked → STOP. Write the summary
  and end the run.
- Hard cap: **25 total passes or 8 hours**, whichever comes first → stop and
  summarize.
- A tier-4 canary fails → it is Google, not your code. Log it, flag it in
  `factory/progress-3.md`, never "fix" working Sign-In in response.
- A test that fails against *today's unmodified Path 2 GAS code* where this
  file says the web app is unharmed is **a finding, not a task**: report it,
  park, do not edit `Code.gs` to make the phone look right.

---

## Restart permission

If an approach is truly unsalvageable, you may throw away uncommitted work on
the current task and rebuild it from this document. Log the restart. A restart
resets that task's failure count.

**Restarting a task is the loop working; silently narrowing its criteria is the
loop failing.**

---

## Guardrails (never violate)

- Work only on branch **`path-3-ios`**. Never commit to `main`. Never push.
  Never force-push.
- Commit after each task passes verification, message: `<task id>: <title>`.
- **Never edit this file.** Never delete or weaken an acceptance criterion —
  if one seems wrong, PARK the task with a note instead.
- **Round 1 and 2 records are read-only.** Do not edit `factory/BRIEF.md`,
  `factory/PLAN.md`, `factory/HANDOFF.md`, `factory/progress.md`,
  `factory/log.md`, `factory/BRIEF-2.md`, `factory/PLAN-2.md`,
  `factory/HANDOFF-2.md`, `factory/progress-2.md`, `factory/log-2.md`,
  `factory/REVIEW*.md`, `factory/FIXES*.md`, or `factory/ROUND-1.md`. Path 3
  writes `factory/progress-3.md` and `factory/log-3.md`. Do not rewrite
  `factory/BRIEF-3.md` or `factory/PLAN-3.md`.
- **Do not change the GAS writer** (`applyOps`, `staleGuard_`, `undoSwitch`,
  title helpers, colour table) to make Swift look right. Swift copies
  `Code.gs`. `CATEGORIES` in `Code.gs` stays six entries.
- **Never touch a real calendar or spreadsheet.** No `RUN_LIVE=1` overnight.
- Secrets stay out of git. `ios/.secrets/` is gitignored. Never print tokens.
  Never commit `API_TOKEN` or a real Google client secret.
- Product law, from `README.md`: *Automate capture. Never automate judgment.*
  Path 3 does not add scoring, advice, or a lock between HTML and iPhone.
  Last-write-wins is accepted. Document it in D2; do not build a lock.
- FIXES-5 ruling still holds: a category tap does not close sitting. STOP
  still closes sitting, because STOP ends the day.

---

## Contract (component-level — final sign-off runs ALL of these)

Everything below must be true at the end. **28 assertions.**

**The existing app is unharmed**

1. `node test/tests.js` passes, and the assertion count is at least **1196** —
   the count measured green on `main` at `1f84fce` before this path began. The
   count only ever goes up. (`node test/run.js` in PLAN-3 means this command
   plus `node test/lint.js`.)
2. `node test/lint.js` passes with every existing rule still present.
3. `Code.gs` still writes ACTUAL / SITTING the way Path 2 tests already
   assert. Path 3 does not change the GAS writer to make the phone look
   right.
4. The HTML web app still serves capture for a signed-in browser. Rollup
   and `setupRollup` still run from the editor. `node test/headless.js` still
   passes.

**Sign-in and calendars**

5. Given a cold launch with no Google session, when the app opens, then
   Google Sign-In is shown and Settings has no `/exec` URL field and no
   `API_TOKEN` field.
6. Given calendars named `PLAN`, `ACTUAL`, and `SITTING` in the list, when
   the picker opens, then those three are pre-selected (first match on a
   duplicate name).
7. Given all three slots filled, when Confirm is tapped, then the three
   calendar IDs are on the device after a kill and relaunch.
8. Given any slot empty, when Confirm is tapped, then nothing is saved and
   the picker stays open.

**The tap writes Path 2's event**

9. Given signed-in IDs and an empty ACTUAL day, when `DW` is tapped, then
   ACTUAL holds one event: title `DW:`, eventColorId `9`, description
   contains `#ref:` plus a 16-char `[A-Za-z0-9]` ref and `#open`, end is
   start + 60_000 ms.
10. Given that tap, then no request is made to an Apps Script `/exec` URL.

**The op machine matches `Code.gs`**

11. Given every combination of marks `+ = - ?` and unmarked with the text
    table in `test/tests.js` section 41b, when Swift `buildTitle` then
    `parseTitle` then `buildTitle` runs, then the result is byte-identical
    to `Code.gs` `buildTitle_` / `parseTitle_` on the same inputs.
12. Given keys DW / MTG / ADM / BODY / REL / FRAG, then eventColorId is
    9 / 3 / 8 / 10 / 6 / 4 and the hex matches `COLOR_HEX` in `Code.gs`.
13. Given a closed ACTUAL block, when a later `closeActual` arrives, then
    the end time does not move. Given the title mark is `?`, then the later
    close does move the end.
14. Given an open ACTUAL, when `openActual` runs for a different ref, then
    the previous event loses `#open` and ends at the new start, and exactly
    one event carries `#open`.
15. Given `undoSwitch` where the new block was not deleted (the `ne`
    early-return in `Code.gs`), then the previous block is not reopened and
    the calendar does not hold two `#open` ACTUAL events.
16. Given a `DW` block opened at 22:00 and no further interaction, when
    `getState` runs at 07:00 the next local day, then that title ends with
    `?` (not `=`), it is bounded at the day border, and an `UNLOGGED -`
    event covers from there to now.
17. Given a running ACTUAL and an open SIT, when STOP is confirmed, then
    both calendars hold exactly one closed event at that instant, neither
    gained an event, and nothing carries `#open`.
18. Given an open SIT, when a category is tapped, then the SITTING calendar
    is untouched. A category tap says nothing about posture.
19. Given an op carrying `mark: '?'`, when `applyOps` runs, then it is
    dropped (id still listed in `applied` so the queue lets go). No user
    action produces `?`.
20. Given an ACTUAL title `Lunch with Ada`, when `getState` runs, then
    `open.key` / `today[].key` is `UNFILED`, not `ADM`.

**The queue talks to Calendar**

21. Given Calendar rejects every write, when an `openActual` is retried
    `MAX_OP_TRIES` (5) times, then it leaves the queue and appears in the
    dead-letter drawer, and the grid does not show that block as running.
22. Given a 401 on flush, then the app refreshes the Google token once and
    retries the same batch. A second 401 does not loop forever.
23. After C1, no TimeTap source file calls `TimetapAPI`.
    `ios/.secrets/API_TOKEN` is unused.

**Categories, settings, docs**

24. The device seed is the six `CATEGORIES` in `Code.gs` plus `POOP`.
    `addCategory` appends on the device up to `MAX_CATEGORIES` (10) and
    does not call Apps Script. The eleventh add is refused.
25. Sign-out clears the Google session. Saved calendar IDs survive a
    relaunch. After sign-out the app writes nothing to Calendar.
26. Settings can change the three calendar IDs. The next flush uses the
    new IDs.
27. `ios/README.md` states: iOS OAuth client + URL scheme; calendar
    picker; last-write-wins if HTML and iPhone both write; rollup stays
    on Apps Script; `/exec` + `API_TOKEN` is not the iOS setup path.
28. Device proof of C3 is the user's Google Calendar, not curl against
    `/exec`. Offline Swift tests never call a live Calendar API.

**Two standing rules for the whole path.**

- **Every bug found later gets a criterion here first, then the fix.** Add it
  to `factory/progress-3.md` under `## Contract additions`, then fix it.
- **The builder never grades its own work.** These criteria are checked by
  running them, and final judgment belongs to a fresh reviewer that never
  saw the code being written.

**How the loop runs the tiers.**

| Tier | When |
|---|---|
| 1 | Every pass. Swift XCTest against a fake calendar. `node test/tests.js`. |
| 2 | **Skip overnight.** Gated by `RUN_LIVE=1`. Human in the morning. |
| 3 | Every pass if offline (compile, grep, README lint, `node test/headless.js`). |
| 4 | Never blocks. Google outage is logged, not "fixed". |

---

## Orientation facts (so you never have to go looking)

**What already ships.** Path 2 SwiftUI capture is `ios/TimeTap/`. Queue, dead
letter, undo ribbon, marks, notes, split, sit, STOP, day rail live in
`TapStore.swift`. `TimetapAPI.swift` POSTs those ops to Apps Script. Path 3
replaces that client. Do not rebuild the capture UI.

**GAS is the spec, not the runtime.** Port `Code.gs`: `buildTitle_`,
`parseTitle_`, `writeDesc_`, `applyOps` / `applyOp_`, `staleGuard_`,
`findOpen_`, `findByRef_`, `endEventAt_`, `opUndoSwitch_`. Line numbers move;
names do not.

Pinned constants from `Code.gs` (must match):

| Name | Value |
|---|---|
| `MIN_MARK_MINUTES` | 15 |
| `MISTAP_SECONDS` | 20 |
| `STALE_OPEN_HOURS` | 5 |
| `UNDO_SECONDS` | 5 |
| `MAX_CATEGORIES` | 10 |
| `MAX_OP_TRIES` | 5 |
| `OPEN_TOKEN` | `#open` |
| `REF_PREFIX` | `#ref:` |
| `UNLOGGED_TITLE` | `UNLOGGED -` |
| `UNFILED_KEY` | `UNFILED` |
| `SIT_TITLE` | `SIT` |

Colour IDs: DW=9 `#3f51b5`, MTG=3 `#8e24aa`, ADM=8 `#616161`, BODY=10
`#0b8043`, REL=6 `#f4511e`, FRAG=4 `#e67c73`. `POOP` is a device extra, not
in `Code.gs` `CATEGORIES`. Give it an unused palette id via the same rule as
`nextColor_` (`Code.gs`). Pin the id in the seed test.

`addCategory` key rule (`keyFor_`): uppercase, strip non `[A-Z0-9]`, max 8,
fallback `CAT`, collide → `base.slice(0,7)+n`. Reserve `UNLOGGED` and
`UNFILED`. Labels trim, max 24 chars. Empty name adds nothing.

**iOS project.** `ios/project.yml` → XcodeGen. Bundle id `app.timetap.ios`.
Team `Y3NGT7263T`. iOS 17+. Add a `TimeTapTests` unit-test target. Add
GoogleSignIn-iOS via SPM. Calendar HTTP: `calendar/v3` with the OAuth token.
Scope: `https://www.googleapis.com/auth/calendar`.

**Google iOS client ID.** If `ios/.secrets/GOOGLE_IOS_CLIENT_ID` is missing,
write `ios/.secrets/GOOGLE_IOS_CLIENT_ID.example`, wire Info.plist / URL
scheme from a Debug placeholder of the form `….apps.googleusercontent.com`,
and PARK only the live Sign-In criterion. Do not invent and commit a real
client id. `ios/README.md` (D2) tells the human how to mint one.

**Open event shape.** `createEvent` start=now, end=start+60_000, description
`#ref:<16 chars>\n#open`, colour from the key.

**Queue is the lock.** No `LockService`. Apply ops in array order on one
thread.

**Not in this version.** Rollup on the phone, `removeCategory`, widgets,
Watch, App Store, GAS `doPost` fallback, cross-phone lock, pushing extras
back to GAS, EventKit.

**Existing test helpers to mirror, not call from Swift:** `test/tests.js`
41b (title table), 41c (`?` dropped), 60 / 60c (no stretch), REVIEW-4
finding 7 (undo `ne` return).

---

## Tasks

### Stage A — Sign in and write one event

After A: sign in, pick calendars, tap DW, see the event. Split / sit / STOP
may be inert until C.

#### A1. Google Sign-In on the phone asks for Calendar, not an API token

- what: First launch shows Google Sign-In. After success the app holds a
  Google access token with scope
  `https://www.googleapis.com/auth/calendar`. Settings no longer require
  `/exec` URL or `API_TOKEN` to leave the sheet. The Google Cloud **iOS**
  OAuth client ID and the Xcode URL scheme are in the project; `ios/README.md`
  says how to mint them. Sign-in in a Google "testing" project may show a
  warning; that is accepted.
- proves: Done-test 1 (sign-in) and 6 (no token). Brief decision: Google
  Sign-In, not EventKit.
- risk: **high** (external OAuth. Wrong client ID or URL scheme means
  nothing else in this plan can run on a device.)
- acceptance criteria:
  - [tier 1] Given the Xcode target, when Info.plist / generated keys are
    read, then a Google URL scheme (`com.googleusercontent.apps.…`) is
    present and a Google iOS client ID is present.
  - [tier 1] Given `SettingsView.swift` and `Credentials.swift`, when
    grepped, then they contain no `API_TOKEN`, no `/exec` URL field, and
    no `TimetapAPI` call.
  - [tier 1] Given no Google session and no calendar IDs, when
    `Credentials.isConfigured` (or its replacement) is read, then it is
    false and the capture grid does not enqueue an `openActual`.
  - [tier 1, error] Given Sign-In is cancelled, when the sheet dismisses,
    then no access token is stored, no calendar list is fetched, and no
    Calendar write is attempted.
  - [tier 3] Given a Debug build, when it launches on the simulator, then
    the first screen is Google Sign-In (or a button that starts it), not
    a URL/token form.
  - [tier 2] SKIP overnight. Given `RUN_LIVE=1` on the iPhone 16 Pro Max,
    when Sign-In completes, then the app holds a token whose scope includes
    `https://www.googleapis.com/auth/calendar`.
  - [tier 4] Google's OAuth consent screen still accepts a testing iOS
    client. Failure is logged; the loop does not rewrite Sign-In to
    "fix" Google.
- test notes: `ios/TimeTapTests` for the plist/grep/isConfigured checks.
  Live Sign-In is `RUN_LIVE=1` only.

#### A2. First sign-in lists calendars; PLAN / ACTUAL / SITTING are pre-selected by name

- what: After Sign-In, a picker lists the user's calendars. If calendars
  named `PLAN`, `ACTUAL`, and `SITTING` exist, those three are pre-selected.
  Confirm writes the three calendar IDs on the device. The picker does not
  proceed with a missing slot. Settings can open the same picker later (D1
  owns the change path; this task only has to save the first pick).
- proves: Done-test 1.
- risk: medium (Calendar list API + matching by summary name. Duplicate
  names: first match wins, stated in the picker.)
- acceptance criteria:
  - [tier 1] Given a fixture list containing summaries `PLAN`, `ACTUAL`,
    `SITTING` with ids `p1`/`a1`/`s1`, when the picker builds its
    selection, then PLAN=`p1`, ACTUAL=`a1`, SITTING=`s1`.
  - [tier 1] Given two calendars named `ACTUAL` with ids `a-old` then
    `a-new`, when the picker pre-selects, then ACTUAL is `a-old` (first
    match). The picker states that rule.
  - [tier 1] Given the three IDs confirmed, when the process is killed
    and the store reloads, then the same three IDs are present.
  - [tier 1, error] Given the list has `PLAN` and `ACTUAL` but no
    `SITTING`, when Confirm is tapped, then no IDs are saved and Confirm
    is disabled until SITTING is chosen by hand.
  - [tier 1, error] Given an empty calendar list, when the picker opens,
    then it shows that there are no calendars and Confirm is disabled.
  - [tier 2] SKIP overnight. Given `RUN_LIVE=1` after Sign-In, when the
    picker opens, then it shows calendars from `users/me/calendarList`.
- test notes: Pure function over `[CalendarSummary]`. Do not call Calendar
  list in unattended runs.

#### A3. Tap DW writes the same open ACTUAL event Path 2 would

- what: With IDs saved, tap `DW` on the capture grid. Google Calendar shows
  an event on the ACTUAL calendar: title starts `DW:`, colour is Blueberry
  (eventColorId `9`, hex `#3f51b5`), description carries `#ref:` plus a
  16-char ref and `#open`, start is now, end is start + 1 minute. No Apps
  Script `doPost` ran. This task may be a thin insert; Stage B replaces it
  with the full op machine.
- proves: Done-test 2.
- risk: **high** (colour IDs vs `CalendarApp.EventColor`.)
- acceptance criteria:
  - [tier 1] Given a fake ACTUAL calendar and saved IDs, when `openActual`
    for `DW` at `t` runs, then the calendar holds one event: title `DW:`,
    colorId `9`, description matches `/#ref:[A-Za-z0-9]{16}/` and contains
    `#open`, start `t`, end `t + 60_000`.
  - [tier 1] Given the same, then the insert payload is sent to the ACTUAL
    calendar id, not PLAN or SITTING.
  - [tier 1, error] Given no ACTUAL calendar id, when `DW` is tapped,
    then no insert is attempted and the UI shows that calendars are not
    picked yet.
  - [tier 1, error] Given the fake insert fails, then the event is not
    treated as synced, and a retry path exists. The UI must not show
    SYNCED.
  - [tier 3] Given TimeTap sources, when grepped for
    `script.google.com` / `macros/s/`, then no capture write path contains
    those hosts.
  - [tier 2] SKIP overnight. Live DW insert on the phone.
- test notes: Fake insert. **Vacuity:** if colorId is omitted, the colour
  criterion goes red.

#### A4. Path 2 HTTPS is gone from the phone

- what: `TimetapAPI` is not called. `Credentials` no longer stores
  `API_TOKEN` or the `/exec` URL as the way to run. `ios/.secrets/API_TOKEN`
  is unused. Until C1, actions other than the A3 tap may be inert — the UI
  must not pretend a GAS flush succeeded.
- proves: Done-test 6.
- risk: low
- acceptance criteria:
  - [tier 1] Given `ios/TimeTap`, when searched, then no file references
    `TimetapAPI` except a deleted-or-absent `TimetapAPI.swift`.
  - [tier 1] Given `Credentials`, then it has no `apiURL` / `apiToken`
    used as the configured gate. Configured means Google session plus
    three calendar IDs.
  - [tier 3] Given `xcodegen generate && xcodebuild build`, then the
    TimeTap target builds.
  - [tier 1, error] Given a leftover `ios/.secrets/API_TOKEN` on disk,
    when the app boots, then it is not read and not sent anywhere.
  - [tier 3] Given `node test/tests.js && node test/lint.js`, then it
    still passes.

---

### Stage B — The op machine on the phone

Highest-risk stage. After B the phone can apply every capture op against a
fake calendar and read state back.

#### B1. Title, colour, and description refs match `Code.gs`

- what: Swift copies of `buildTitle_`, `parseTitle_`, `writeDesc_`,
  `COLOR_HEX`, `CATEGORIES` (plus extra `POOP`), `#open`, `#ref:`.
- proves: If this is wrong, rollup lies.
- risk: **high**
- acceptance criteria:
  - [tier 1] Given `buildTitle('DW', 'memo drafting', '?')`, then it
    returns exactly `DW: memo drafting ?`.
  - [tier 1] Given title `DW: memo drafting ?`, when parsed, then key
    `DW`, text `memo drafting`, mark `?`.
  - [tier 1] Given marks `+`, `=`, `-`, `?`, `null` × texts `''`,
    `'memo'`, `'memo drafting'`, `'  padded   spaces  '`, `'memo +'`,
    `'a ?'`, `'C++'`, when each is built then parsed then rebuilt, then
    the result is byte-identical to the first build **and** byte-identical
    to `Code.gs` `buildTitle_` / `parseTitle_` on the same pair.
  - [tier 1] Given `UNLOGGED` with empty text and mark `-`, then the
    title is `UNLOGGED -` (no colon). Given `UNLOGGED: something`, the
    colon stays.
  - [tier 1] Given `writeDesc` on `'hello'` with ref `abc` open true,
    then the description is `hello\n#ref:abc\n#open`. A second write
    with open false replaces the tokens and does not duplicate them.
  - [tier 1] Given DW/MTG/ADM/BODY/REL/FRAG, then colorId is 9/3/8/10/6/4
    and hex is `#3f51b5` / `#8e24aa` / `#616161` / `#0b8043` / `#f4511e`
    / `#e67c73`.
  - [tier 1] Given Swift constants, then `minMarkMinutes=15`,
    `mistapSeconds=20`, `staleOpenHours=5`, `undoSeconds=5`,
    `maxCategories=10`, `maxOpTries=5`.
  - [tier 1] Given the seed, then it contains keys DW, MTG, ADM, BODY,
    REL, FRAG, POOP, and POOP is not in `Code.gs` `CATEGORIES`.
  - [tier 1, error] Given title `Lunch with Ada`, when parsed, then the
    result is null (not `{key:'ADM'}`).
  - [tier 1, error] Given title `DW: memo ??`, when parsed, then mark is
    one `?` and text is `memo ?`.
- test notes: Dump GAS goldens to `test/fixtures/title-golden.json` if
  useful. **Vacuity:** revert the Swift mark regex to `[+=\\-]`; `?` parse
  criteria go red.

#### B2. Every capture op applies against a fake calendar, same as `applyOps`

- what: `openActual`, `closeActual`, `recategorize`, `setMark`, `setText`,
  `splitActual`, `openSit`, `closeSit`, `setSitStart`, `deleteSit` against
  an in-memory calendar. `SIT_TITLE` is `SIT`.
- proves: Done-test 3 writes.
- risk: **high**
- acceptance criteria:
  - [tier 1] Given empty ACTUAL, when `openActual` DW at `t` then
    `closeActual` at `t+3600000` mark `=` run, then one event, title
    `DW: =`, no `#open`, end `t+3600000`.
  - [tier 1] Given that open, when a second `openActual` MTG at `t+60000`
    runs, then DW is closed at `t+60000` without `#open`, and MTG is the
    only `#open`.
  - [tier 1] Given the same `openActual` replayed, then still one event.
  - [tier 1] Given a closed block ended at `e`, when `closeActual` with
    `endMs = e+7200000` mark `=` runs, then the end is still `e`.
  - [tier 1] Given a block titled with mark `?` ended at `e`, when
    `closeActual` with a later `endMs` runs, then the end moves and the
    mark becomes the op's mark.
  - [tier 1] Given `splitActual` at `atMs` with `newKey` MTG, then the
    first event ends at `atMs` closed, and a new `#open` MTG starts at
    `atMs`.
  - [tier 1] Given `recategorize` DW→MTG, then the title key is MTG, the
    note and mark survive, and colorId is `3`.
  - [tier 1] Given `setText` / `setMark`, then only that field changes.
  - [tier 1] Given `openSit` then `closeSit`, then SITTING holds one
    closed event titled `SIT`, no `#open`.
  - [tier 1] Given a closed SIT, when a later `closeSit` runs, then the
    end does not move.
  - [tier 1] Given `endEventAt` with `endMs <= start`, then the end is
    start + 60_000.
  - [tier 1, error] Given `closeActual` with `mark: '?'`, then it is in
    `dropped` and `applied`, and the calendar is unchanged.
  - [tier 1, error] Given `type: 'nope'`, then it is dropped, later ops
    in the same batch still run.
  - [tier 1, error] Given `endMs: NaN`, then the op is dropped.
  - [tier 1] Given two ops in one `applyOps` call, then they run in
    array order on one thread. There is no `LockService.busy` path.
- test notes: **Vacuity:** remove the already-closed guard; stretch
  criterion goes red.

#### B3. Undo, stale guard, and STOP match `Code.gs`

- what: `undoSwitch` `ne` early-return, prev reopen, STOP sitting half.
  `staleGuard_` writes `?` not `=`. STOP closes both, opens nothing.
  Category taps do not close sitting.
- risk: **high**
- acceptance criteria:
  - [tier 1] Given DW open, switched to MTG at `atMs`, when `undoSwitch`
    runs with matching refs, then MTG is deleted, DW is `#open` again,
    DW's mark is gone.
  - [tier 1] Given the same setup but MTG was not deleted, when
    `undoSwitch` runs, then DW is **not** reopened and exactly one
    `#open` remains. **Contract 15.**
  - [tier 1] Given STOP closed DW and a SIT at `atMs`, when undo carries
    `sitRef` and `newRef` null, then DW reopens and the SIT reopens, and
    no new ACTUAL is created.
  - [tier 1] Given `killSitRef`, when undo runs, then that sitting is
    deleted, not closed.
  - [tier 1] Given DW opened at local 22:00, when `staleGuard` /
    `getState` runs at 07:00 the next local day, then DW ends at local
    midnight with title ending `?`, and `UNLOGGED -` runs midnight→07:00.
  - [tier 1] Given BODY opened at 22:00, when bounded the next morning,
    then the title ends with `?` not `+`.
  - [tier 1] Given a block opened 30 seconds ago, including across
    midnight, when `staleGuard` runs, then it is left open.
  - [tier 1] Given an open SIT across midnight, when bounded, then it is
    bounded at the day border, no `UNLOGGED` on SITTING, no `?` on the
    title.
  - [tier 1] Given running DW and open SIT, when STOP closes both at `t`
    and opens nothing, then each calendar has one event ending at `t`,
    no `#open`, counts unchanged.
  - [tier 1] Given open SIT, when `openActual` MTG runs, then SITTING is
    untouched.
  - [tier 1, error] Given `undoSwitch` replayed, then a second run is a
    no-op.
- test notes: Fake clock. Night case under `America/Chicago`.
  **Vacuity:** skip `if (ne) return`; double-open criterion goes red.

#### B4. The phone reads Calendar and returns the state `TapStore` already consumes

- what: `getState` lists today, runs `staleGuard_` / `findOpen_`, returns
  `ServerState`. Timezone is the device timezone.
- risk: medium
- acceptance criteria:
  - [tier 1] Given one `#open` DW and two closed today blocks, when
    `getState` runs, then `open.key=='DW'`, `today` has the closed
    blocks, `nowMs` is the fake now, `tz` is the device timezone
    identifier.
  - [tier 1] Given two `#open` ACTUAL events, when `getState` runs, then
    only the newest stays open; the older is closed at the newest start.
  - [tier 1] Given a stale open (contract 16 setup), when `getState`
    runs, then `open` is null and `today` includes the `?` block and
    `UNLOGGED`.
  - [tier 1] Given title `Lunch with Ada` as the open event, when
    `getState` runs, then the client is not told the block is `ADM`.
  - [tier 1] Given `ServerState` JSON from Swift, when decoded by the
    existing `ServerState` struct, then it decodes.
  - [tier 1, error] Given Calendar list throws, then `getState` returns
    an error the store can show; it does not invent an idle day that
    wipes local optimistic state.
  - [tier 1, error] Given an all-day event on ACTUAL, then it is ignored.

---

### Stage C — Capture talks to Calendar, not GAS

After C: full Path 2 capture on the phone, no token.

#### C1. The op queue and dead letter flush to Calendar HTTP

- what: `TapStore` flush calls the Swift op machine + Calendar API, not
  `TimetapAPI`. 401 refreshes once. 429/5xx backs off.
- risk: medium
- acceptance criteria:
  - [tier 1] Given a successful fake Calendar apply, when flush runs,
    then applied ids leave the queue, and `TimetapAPI` is not invoked.
  - [tier 1] Given rejects every write, when an `openActual` is flushed
    5 times, then it is in `dead`, not in `queue`, and `open` is not
    shown as running.
  - [tier 1] Given a `setMark` is set aside while a block is running,
    then the block **is** still shown running.
  - [tier 1] Given flush returns 401 once then 200, then token refresh
    ran once and the batch was applied.
  - [tier 1] Given a second 401 after refresh, then refresh is not
    called in a tight loop (one refresh per flush attempt).
  - [tier 1] Given 429 or 500, then backoff grows and ops stay in the
    queue until `MAX_OP_TRIES`.
  - [tier 1] Given an applied `undoSwitch`, then a corrective `getState`
    runs after the flush.
  - [tier 1, error] Given 403 on ACTUAL, then the UI is not SYNCED, and
    the op is retried then set aside rather than silently dropped.
  - [tier 3] Given `ios/TimeTap`, when grepped, then `TimetapAPI` does
    not appear.

#### C2. Add category stays on the device

- what: Seed is `CATEGORIES` plus `POOP`. Add is local, cap 10. No
  `removeCategory`. `Code.gs` `CATEGORIES` unchanged.
- risk: low
- acceptance criteria:
  - [tier 1] Given a fresh store offline, then categories include
    DW…FRAG and POOP.
  - [tier 1] Given 7 categories, when `addCategory('Deep reading')`
    runs, then an eighth exists with a new uppercase key, and no
    Calendar/GAS HTTP fired.
  - [tier 1] Given 10 categories, when add is attempted, then the count
    stays 10 and the user sees the ceiling is 10.
  - [tier 1] Given extras persisted, when the app relaunches offline,
    then the extra is still on the grid.
  - [tier 1, error] Given label `   `, when add runs, then no category
    is added.
  - [tier 1, error] Given `ios/TimeTap`, when searched, then
    `removeCategory` is absent.
  - [tier 3] Given `Code.gs` `CATEGORIES`, then it is unchanged.

#### C3. Capture parity on the phone: split, sit, STOP, undo, marks, notes, rail

- what: Drive `TapStore` the way Path 2 drives `tap()`. Live phone proof
  is skipped overnight.
- risk: medium
- acceptance criteria:
  - [tier 1] Given `TapStore` on a fake calendar, when tap DW, tap MTG,
    undo, STOP, sit, split remainder, recategorize whole, set mark, set
    note run, then the fake calendar matches B2/B3's writer.
  - [tier 1] Given a closed block and a gap before the next, when the
    rail is built, then an UNLOGGED gap item exists.
  - [tier 3] Given `node test/tests.js && node test/lint.js`, then it
    passes.
  - [tier 2] SKIP overnight. Live parity on the iPhone 16 Pro Max.
  - [tier 2] SKIP overnight. Rollup / ACTUAL read sees the keys.
  - [tier 1, error] Given unreadable `#open`, then the UI shows
    unreadable rather than lighting ADM.

---

### Stage D — Settings and leftovers

After D: complete.

#### D1. Settings can change calendar IDs; sign-out clears Google, not the IDs

- what: Same picker as A2. Sign-out clears the Google session. IDs stay.
  After sign-out the app does not write. No lock.
- risk: low
- acceptance criteria:
  - [tier 1] Given saved IDs `a1`/`p1`/`s1`, when Settings confirms
    ACTUAL=`a2`, then the next `openActual` insert uses calendar `a2`.
  - [tier 1] Given a Google session and saved IDs, when sign-out runs,
    then the access token is gone and the three IDs are still present
    after relaunch.
  - [tier 1] Given signed-out, when `DW` is tapped, then no Calendar
    insert is attempted and Sign-In is shown.
  - [tier 1, error] Given Settings Confirm with SITTING cleared, then
    IDs are not overwritten.
  - [tier 1] Given TimeTap sources, when searched for `LockService` or
    a cross-device lock, then none exists.

#### D2. Path 3 setup is written; Path 2 token docs stop being the way in

- what: `ios/README.md` is the Path 3 setup. Last-write-wins is stated.
- risk: low
- acceptance criteria:
  - [tier 1] Given `ios/README.md`, then it contains: iOS OAuth client,
    URL scheme, Google Sign-In, calendar picker, last-write-wins,
    rollup stays on Apps Script.
  - [tier 1] Given `ios/README.md`, then the iOS setup path does not
    tell the reader to paste `API_TOKEN` or an Anyone `/exec` URL as
    the way to run this app.
  - [tier 1] Given `node test/lint.js`, then it still passes, and a new
    rule fails by name if `ios/README.md` loses the last-write-wins
    sentence or the Sign-In sentence.
  - [tier 1, error] Given the last-write-wins sentence is deleted,
    then lint fails and names `ios/README.md`.
  - [tier 3] Given `node test/tests.js && node test/lint.js`, then it
    still passes.
- test notes: **Vacuity:** delete the last-write-wins sentence, watch
  lint go red, put it back.

---

## When done

All contract assertions that are not tier-2 pass, and the GAS suite plus
Swift tests are green **twice in a row** → write `## RUN SUMMARY` at the
top of `factory/progress-3.md`: outcome first, then per-task status, parked
items with reasons, the five vacuity checks and what each proved, which
tier-2 checks the human still owes, and the exact commands a human can run
to see it work.

End your final message to the human with the baton pass, verbatim:

> "The build is done and self-checked. Next step: an independent review that tries
> to break it — open Claude Code and run /factory (or /factory-review). Don't skip
> it; I graded my own homework."

The same applies if you stopped early (circuit breaker, cap): say exactly where
things stand, which stage boundary was the last complete one, and that /factory
is the next step either way.
