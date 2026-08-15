# Plan: timetap — Path 3 (SwiftUI writes Calendar itself)
brief: factory/BRIEF-3.md
date: 2026-08-12
tests defined: 2026-08-12

13 tasks in four stages. Ordered so the first green run is a signed-in tap
that writes a real ACTUAL event. The op machine ports next. The existing
capture UI is rewired last. Settings and leftover Path 2 HTTPS die at the
end.

Path 2 capture UI already ships in `ios/TimeTap/`. This plan does not rebuild
it. It replaces `TimetapAPI` + `API_TOKEN` with Google Sign-In and a Swift
port of `Code.gs`'s writer.

**Where each stage leaves you, if the night ends there:**

| Ends after | You have |
|---|---|
| A | Sign in, pick PLAN / ACTUAL / SITTING, tap DW, see the event on Calendar. Split / sit / STOP still talk to GAS or do nothing — walking skeleton only. |
| B | The phone can apply every capture op against Calendar and read state back. Capture UI may still flush to GAS until C1. |
| C | Full Path 2 capture on the phone, no GAS in the tap path. Rollup still Apps Script. |
| D | Complete. Settings, sign-out, docs. Path 2 HTTPS gone. |

Apps Script `doGet` / rollup / HTML stay. `node test/run.js` stays green.
Never point tests at a live calendar.

---

## Contract

Done for the whole path, as things that can be checked by running something.
Everything below must be true at the end. **28 assertions.**

**The existing app is unharmed**

1. `node test/run.js` passes, and the assertion count is at least the count
   measured green on `main` at `1f84fce` before this path began. The count
   only ever goes up.
2. `node test/lint.js` passes with every existing rule still present.
3. `Code.gs` still writes ACTUAL / SITTING the way Path 2 tests already
   assert. Path 3 does not change the GAS writer to make the phone look
   right.
4. The HTML web app still serves capture for a signed-in browser. Rollup
   and `setupRollup` still run from the editor.

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
    early-return in `Code.gs:1109`), then the previous block is not
    reopened and the calendar does not hold two `#open` ACTUAL events.
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

- **Every bug found later gets a criterion here first, then the fix.** The
  contract grows to match reality.
- **The builder never grades its own work.** These criteria are checked by
  running them, and final judgment belongs to a fresh reviewer that never
  saw the code being written.

**How the loop runs the tiers.**

| Tier | When |
|---|---|
| 1 | Every pass. Swift XCTest against a fake calendar. `node test/run.js`. |
| 2 | End of each stage, gated by `RUN_LIVE=1`. Real Google account, calendars the user owns. Never in unattended CI. |
| 3 | Every pass if offline (compile, grep, README lint). Device smoke at stage end. |
| 4 | Never blocks. Google Sign-In or Calendar API outage is logged, not "fixed". |

---

## Stage A — Sign in and write one event

Walking skeleton. After A3 the stack is proved: OAuth, calendar IDs, one
insert that rollup can already read.

### A1. Google Sign-In on the phone asks for Calendar, not an API token

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
  - [tier 2] Given `RUN_LIVE=1` on the iPhone 16 Pro Max, when Sign-In
    completes, then the app holds a token whose scope includes
    `https://www.googleapis.com/auth/calendar`.
  - [tier 4] Google's OAuth consent screen still accepts a testing iOS
    client. Failure is logged; the loop does not rewrite Sign-In to
    "fix" Google.
- test notes: `ios/TimeTapTests` for the plist/grep/isConfigured checks.
  `rg 'API_TOKEN|TimetapAPI|/exec' ios/TimeTap --glob '!**/TimetapAPI.swift'`
  must be empty after A4; after A1 it must already be empty in Settings
  and Credentials. Live Sign-In is manual / `RUN_LIVE=1` only.

### A2. First sign-in lists calendars; PLAN / ACTUAL / SITTING are pre-selected by name

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
  - [tier 2] Given `RUN_LIVE=1` after Sign-In, when the picker opens,
    then it shows calendars from `users/me/calendarList` and not a
    hardcoded trio.
- test notes: Pure function over `[CalendarSummary]`. Persist via
  UserDefaults keys named in the test. Do not call Calendar list in
  unattended runs.

### A3. Tap DW writes the same open ACTUAL event Path 2 would

- what: With IDs saved, tap `DW` on the capture grid. Google Calendar shows
  an event on the ACTUAL calendar: title starts `DW:`, colour is Blueberry
  (eventColorId `9`, hex `#3f51b5`), description carries `#ref:` plus a
  16-char ref and `#open`, start is now, end is start + 1 minute (the open
  shape `insertActual_` / `opOpenActual_` already use). No Apps Script
  `doPost` ran. This task may be a thin insert; Stage B replaces it with
  the full op machine.
- proves: Done-test 2. The morning-it-works test.
- risk: **high** (colour IDs vs `CalendarApp.EventColor`; open-event
  grammar is load-bearing for rollup and for every later op.)
- acceptance criteria:
  - [tier 1] Given a fake ACTUAL calendar and saved IDs, when `openActual`
    for `DW` at `t` runs, then the calendar holds one event: title `DW:`,
    colorId `9`, description matches `/#ref:[A-Za-z0-9]{16}/` and contains
    `#open`, start `t`, end `t + 60_000`.
  - [tier 1] Given the same, then the HTTP body (or fake insert payload)
    is sent to the ACTUAL calendar id, not PLAN or SITTING.
  - [tier 1, error] Given no ACTUAL calendar id, when `DW` is tapped,
    then no insert is attempted and the UI shows that calendars are not
    picked yet.
  - [tier 1, error] Given the fake insert fails, then the event is not
    treated as synced, and a retry path exists (queue or visible error).
    The UI must not show SYNCED.
  - [tier 3] Given TimeTap sources, when grepped for
    `script.google.com` / `macros/s/`, then no capture write path contains
    those hosts.
  - [tier 2] Given `RUN_LIVE=1` on the phone, when `DW` is tapped, then
    Google Calendar's ACTUAL calendar shows that event within 10 seconds,
    and Apps Script Executions shows no `doPost` in that window.
- test notes: Fake `CalendarClient.insert`. Live check is a human looking
  at Calendar plus the GAS executions log. **Vacuity:** if colorId is
  omitted, the colour criterion goes red.

### A4. Path 2 HTTPS is gone from the phone

- what: `TimetapAPI` is not called. `Credentials` no longer stores
  `API_TOKEN` or the `/exec` URL as the way to run. `ios/.secrets/API_TOKEN`
  is unused. Capture still compiles and launches. Until C1, actions other
  than the A3 tap may be inert — that is allowed, and the UI must not
  pretend a GAS flush succeeded.
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
  - [tier 3] Given `node test/run.js`, then it still passes. Removing
    the phone's HTTPS client must not touch GAS tests.
- test notes: Ripgrep in `test/lint.js` or a Swift test that fails if
  `TimetapAPI` reappears. Build: `cd ios && xcodegen generate &&
  xcodebuild -scheme TimeTap -destination 'generic/platform=iOS
  Simulator' build`.

---

## Stage B — The op machine on the phone

Highest-risk stage. Port `applyOps` / `staleGuard_` / `undoSwitch` /
title+ref+colour. No `LockService`: the queue is the lock. One phone writes.

### B1. Title, colour, and description refs match `Code.gs`

- what: Swift copies of `buildTitle_`, `parseTitle_`, `writeDesc_`,
  `COLOR_HEX`, `CATEGORIES` (plus extra `POOP`), `OPEN_TOKEN` `#open`,
  `REF_PREFIX` `#ref:`. Round-trip titles byte-match the GAS helpers.
  Event colour IDs match the table in `Code.gs` (DW=9, MTG=3, ADM=8,
  BODY=10, REL=6, FRAG=4). Constants (`MIN_MARK_MINUTES`, `MISTAP_SECONDS`,
  `STALE_OPEN_HOURS`, `UNDO_SECONDS`, `MAX_CATEGORIES`, `MAX_OP_TRIES`)
  match `Code.gs`. Seed lives on the device; Apps Script `CATEGORIES` is
  not fetched.
- proves: "Events on Calendar match Path 2's writer." If this is wrong,
  rollup lies.
- risk: **high** (silent misfile, same class as round 2 A1.)
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
- test notes: `ios/TimeTapTests` plus a Node dump of `buildTitle_` /
  `parseTitle_` over the 41b table (`test/fixtures/title-golden.json` is
  fine) so Swift cannot drift from GAS. **Vacuity:** revert the Swift
  mark regex to `[+=\\-]` and confirm the `?` parse criteria go red.

### B2. Every capture op applies against a fake calendar, same as `applyOps`

- what: `openActual`, `closeActual`, `recategorize`, `setMark`, `setText`,
  `splitActual`, `openSit`, `closeSit`, `setSitStart`, `deleteSit` run in
  Swift against an in-memory calendar. Replay is a no-op (`findByRef_`).
  `openActual` closes any other open ACTUAL at the new start. `closeActual`
  does not stretch an already-closed block unless the title mark is `?`.
  `endEventAt_` never writes a zero-length event. Unknown op types drop.
  `validOp_` still rejects user-produced `?`. No `LockService`; callers
  run ops in queue order on one thread.
- proves: Done-test 3 (the writes behind split / sit / marks / notes).
- risk: **high** (wrong patch orphans an open block or double-opens.)
- acceptance criteria:
  - [tier 1] Given empty ACTUAL, when `openActual` DW at `t` then
    `closeActual` at `t+3600000` mark `=` run, then one event, title
    `DW: =`, no `#open`, end `t+3600000`.
  - [tier 1] Given that open, when a second `openActual` MTG at `t+60000`
    runs, then DW is closed at `t+60000` without `#open`, and MTG is the
    only `#open`.
  - [tier 1] Given the same `openActual` replayed, then still one event
    (idempotent `findByRef_`).
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
  - [tier 1] Given `openSit` then `closeSit` at the same instants as
    ACTUAL close, then SITTING holds one closed event, title unchanged
    (`SITTING` / whatever `SIT_TITLE` is), no `#open`.
  - [tier 1] Given a closed SIT, when a later `closeSit` runs, then the
    end does not move (FIXES-5 E2).
  - [tier 1] Given `endEventAt` with `endMs <= start`, then the end is
    start + 60_000.
  - [tier 1, error] Given `closeActual` with `mark: '?'`, then
    `validOp_` is false, the op is in `dropped` and `applied`, and the
    calendar is unchanged. **Contract 19.**
  - [tier 1, error] Given `type: 'nope'`, then it is dropped, later ops
    in the same batch still run.
  - [tier 1, error] Given `endMs: NaN`, then the op is dropped.
  - [tier 1] Given two ops in one `applyOps` call, then they run in
    array order on one thread. There is no `LockService.busy` path.
- test notes: In-memory `FakeCalendar` with events `{id,title,description,
  start,end,colorId,calendarId}`. Mirror `test/tests.js` sections 60,
  60c, 41c. **Vacuity:** remove the already-closed guard and watch the
  stretch criterion go red.

### B3. Undo, stale guard, and STOP match `Code.gs`

- what: `undoSwitch` ports the `ne` early-return (do not reopen if the new
  block was not deleted), the prev-ref reopen, and the STOP sitting half
  (`sitRef` / `killSitRef`). `staleGuard_` bounds an open ACTUAL older
  than `STALE_OPEN_HOURS` or across the local day border, writes `?` not
  `=`, writes `UNLOGGED -` from the bound to now, and does not invent `?`
  on SITTING. STOP closes ACTUAL and SITTING at the same instant and opens
  nothing. Category taps still do not close sitting (FIXES-5 ruling).
- proves: Done-test 3 (undo, STOP). Brief: night `?` bound must match or
  rollup lies.
- risk: **high** (the two bugs Path 2 already paid for: undo double-open,
  forgotten-STOP sitting %.)
- acceptance criteria:
  - [tier 1] Given DW open, switched to MTG at `atMs` (DW closed, MTG
    `#open` starting at `atMs`), when `undoSwitch` runs with matching
    `newRef`/`prevRef`/`atMs`, then MTG is deleted, DW is `#open` again,
    DW's mark is gone, DW's end is a live open end.
  - [tier 1] Given the same setup but MTG has already been closed or
    moved so it is not deleted, when `undoSwitch` runs, then DW is **not**
    reopened and exactly one `#open` remains (the MTG that was left).
    **Contract 15.**
  - [tier 1] Given STOP closed DW and a SIT at `atMs`, when undo carries
    `sitRef` and `newRef` null, then DW reopens and the SIT reopens, and
    no new ACTUAL is created.
  - [tier 1] Given `killSitRef` on the sitting started after the action,
    when undo runs, then that sitting is deleted, not closed.
  - [tier 1] Given DW opened at local 22:00, when `staleGuard` / `getState`
    runs at 07:00 the next local day, then DW ends at local midnight with
    title ending `?`, and `UNLOGGED -` runs midnight→07:00. **Contract 16.**
  - [tier 1] Given BODY (`autoMark: '+'`) opened at 22:00, when bounded
    the next morning, then the title ends with `?` not `+`.
  - [tier 1] Given a block opened 30 seconds ago, including across
    midnight, when `staleGuard` runs, then it is left open
    (`MISTAP_SECONDS`).
  - [tier 1] Given an open SIT across midnight, when bounded, then it is
    bounded at the day border, no `UNLOGGED` is written to SITTING, and
    the title is not given `?`.
  - [tier 1] Given running DW and open SIT, when STOP applies
    `closeActual` + `closeSit` at `t` and no open, then each calendar has
    one event ending at `t`, no `#open`, counts unchanged. **Contract 17.**
  - [tier 1] Given open SIT, when `openActual` MTG runs, then SITTING is
    untouched. **Contract 18.**
  - [tier 1, error] Given `undoSwitch` replayed, then a second run is a
    no-op (no second delete, no second reopen).
- test notes: Fake clock (`nowMs`). Run the night case under
  `America/Chicago` at least (device tz). Port `test/tests.js` 42 / 43 /
  REVIEW-4 finding 7. **Vacuity:** skip the `if (ne) return` and watch
  the double-open criterion go red.

### B4. The phone reads Calendar and returns the state `TapStore` already consumes

- what: A `getState` equivalent lists today's ACTUAL and SITTING events,
  runs `staleGuard_` / `findOpen_`, and returns `open`, `sit`, `today`,
  `nowMs`, `tz`. Shape stays `ServerState` so `TapStore` does not grow a
  second model. Timezone is the device timezone. Unreadable titles do not
  become `ADM`.
- proves: Day rail, NOW panel, and refresh-on-return keep working after
  C1 cuts GAS.
- risk: medium (`findOpen_` closes extras; a bad window orphans `#open`.)
- acceptance criteria:
  - [tier 1] Given one `#open` DW and two closed today blocks, when
    `getState` runs, then `open.key=='DW'`, `today` has the closed
    blocks with start/end, `nowMs` is the fake now, `tz` is the device
    timezone identifier.
  - [tier 1] Given two `#open` ACTUAL events, when `getState` runs, then
    only the newest stays open; the older is closed at the newest start
    (`findOpen_`).
  - [tier 1] Given a stale open (contract 16 setup), when `getState`
    runs, then `open` is null and `today` includes the `?` block and
    `UNLOGGED`.
  - [tier 1] Given title `Lunch with Ada` as the open event, when
    `getState` runs, then the client is not told the block is `ADM`
    (`UNFILED` or equivalent). **Contract 20.**
  - [tier 1] Given `ServerState` JSON from Swift, when decoded by the
    existing `ServerState` struct, then it decodes without a second
    model type.
  - [tier 1, error] Given Calendar list throws, then `getState` returns
    an error the store can show; it does not invent an idle day that
    wipes local optimistic state.
  - [tier 1, error] Given an all-day event on ACTUAL, then it is ignored
    (`findOpen_` already skips all-day).
- test notes: Same `FakeCalendar`. Decode through `JSONDecoder` into
  `ServerState`. Do not change `Models.swift` field names to make tests
  pass if `TapStore` still reads the old ones.

---

## Stage C — Capture talks to Calendar, not GAS

The UI already exists. This stage changes where the queue drains.

### C1. The op queue and dead letter flush to Calendar HTTP

- what: `TapStore` enqueue / retry / dead-letter keep their Path 2 shape
  (`MAX_OP_TRIES`, drawer, arm-to-discard). Flush calls the Swift op
  machine + Calendar API, not `TimetapAPI.applyOps`. A 401 re-auths once
  then retries. A 429 / 5xx backs off. Corrective `getState` after undo
  still runs. Optimistic UI stays; Calendar lag is a queue problem, not a
  new spinner.
- proves: Done-test 3 (dead letter) and 6 (HTTPS client gone).
- risk: medium (token expiry and Calendar 403/409 are new failure modes.)
- acceptance criteria:
  - [tier 1] Given a successful fake Calendar apply, when flush runs,
    then queued ops whose ids return in `applied` leave the queue, and
    `TimetapAPI` is not invoked.
  - [tier 1] Given the fake client rejects every write, when an
    `openActual` is flushed `MAX_OP_TRIES` times, then it is in `dead`,
    not in `queue`, and `open` is not shown as running. **Contract 21.**
  - [tier 1] Given a `setMark` (not an open) is set aside while a block
    is running, then the block **is** still shown running.
  - [tier 1] Given flush returns 401 once then 200, then token refresh
    ran once and the batch was retried and applied. **Contract 22.**
  - [tier 1] Given a second 401 after refresh, then the batch stays in
    the queue or dead path; refresh is not called in a tight loop
    (cap: one refresh per flush attempt).
  - [tier 1] Given 429 or 500, then `retryDelay` grows (Path 2 backoff)
    and the ops stay in the queue, not the dead letter, until
    `MAX_OP_TRIES`.
  - [tier 1] Given an applied `undoSwitch`, then a corrective `getState`
    runs after the flush (Path 2 `loadCorrectiveState`).
  - [tier 1, error] Given 403 on the ACTUAL calendar, then the UI shows
    a failure (not SYNCED), and the op is retried then set aside rather
    than silently dropped.
  - [tier 3] Given `ios/TimeTap`, when grepped, then `TimetapAPI` does
    not appear. **Contract 23.**
- test notes: Inject a `CalendarApplying` fake into `TapStore`. Drive
  retries without real waiting (stub clock / call `flush` N times).
  Keep Path 2 dead-letter persistence keys working or migrate them once
  in this task and test the migration.

### C2. Add category stays on the device

- what: Seed is `CATEGORIES` from `Code.gs` plus `POOP`. `addCategory`
  appends on the device up to `MAX_CATEGORIES`. It does not call Apps
  Script. The HTML grid does not gain the new button until someone edits
  GAS extras by hand. No `removeCategory`.
- proves: Brief decisions: device extras on device; not pushing extras
  back to GAS.
- risk: low
- acceptance criteria:
  - [tier 1] Given a fresh store, when config loads without a network,
    then categories include DW…FRAG and POOP.
  - [tier 1] Given 7 categories (seed), when `addCategory('Deep reading')`
    runs, then an eighth category exists with a new uppercase key, and
    no Calendar/GAS HTTP fired.
  - [tier 1] Given 10 categories, when add is attempted, then the count
    stays 10 and the user sees that the ceiling is 10.
  - [tier 1] Given extras persisted, when the app relaunches offline,
    then the extra is still on the grid.
  - [tier 1, error] Given label `   `, when add runs, then no category
    is added (empty name cancels, Path 2 behaviour).
  - [tier 1, error] Given `ios/TimeTap`, when searched, then
    `removeCategory` is absent.
  - [tier 3] Given `Code.gs` `CATEGORIES`, then it is unchanged by this
    task (the HTML grid still has six buttons).
- test notes: UserDefaults extras. Key generation should match GAS
  `addCategory` well enough that titles `KEY: …` still parse; pin the
  key rule in the test. `node test/run.js` still green.

### C3. Capture parity on the phone: split, sit, STOP, undo, marks, notes, rail

- what: On the iPhone 16 Pro Max, every Path 2 capture action still works
  and the Calendar events match Path 2's writer. Split remainder and
  whole-block recategorize. Sit toggle + sit-edit. STOP + undo ribbon.
  Mark strip. Notes. Day rail with UNLOGGED gaps. Dead-letter drawer.
  Device proof is Calendar itself, not curl against `/exec`. `node test/run.js`
  still passes (GAS untouched).
- proves: Done-test 3 and 5 (rollup still sees the events).
- risk: medium (parity on a real device; colour and `#open` must survive
  a round trip through Calendar API.)
- acceptance criteria:
  - [tier 1] Given `TapStore` on a fake calendar, when the Path 2
    capture actions are driven (tap DW, tap MTG, undo, STOP, sit, split
    remainder, recategorize whole, set mark, set note), then the fake
    calendar events match B2/B3's writer for those ops.
  - [tier 1] Given a closed block and a gap before the next, when the
    rail is built, then an UNLOGGED gap item exists (Path 2 rail).
  - [tier 3] Given `node test/run.js`, then it passes.
  - [tier 2] Given `RUN_LIVE=1` on the iPhone 16 Pro Max, when the human
    (or harness) does: sign-in, pick calendars, tap DW, split, sit,
    STOP, undo, mark, note, add category — then Google Calendar shows
    the matching events and Apps Script Executions shows no `doPost`
    for those taps.
  - [tier 2] Given those live events, when Apps Script `dailyRollup`
    (or a read of ACTUAL) runs, then it sees the keys in the titles.
  - [tier 1, error] Given the fake calendar returns unreadable `#open`,
    then the capture UI shows unreadable rather than lighting ADM.
- test notes: Drive `TapStore` from tests the way Path 2 `test/tests.js`
  drives `tap()`. Live C3 is gated and is the brief's morning-it-works
  test. Do not use `curl` against `/exec` as proof.

---

## Stage D — Settings and leftovers

### D1. Settings can change calendar IDs; sign-out clears Google, not the IDs

- what: Settings opens the same calendar picker as A2. Changing an ID
  takes effect on the next flush. Sign-out clears the Google session.
  Saved calendar IDs stay until the user picks again. After sign-out the
  app does not write. Last-write-wins with the HTML app is accepted; no
  lock is built.
- proves: Done-test 4.
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
    IDs are not overwritten (same as A2).
  - [tier 1] Given TimeTap sources, when searched for `LockService` or
    a cross-device lock, then none exists. Last-write-wins is the
    behaviour, not a bug to "fix".
- test notes: Unit tests on stored IDs + session flag. No live Google
  revoke required for tier 1 (fake `signOut()` that drops the token).

### D2. Path 3 setup is written; Path 2 token docs stop being the way in

- what: `ios/README.md` tells how to add the iOS OAuth client, the URL
  scheme, Sign-In, and the calendar picker. It states last-write-wins if
  HTML and iPhone both write. It states rollup stays on Apps Script. Path
  2 `/exec` + `API_TOKEN` is no longer the iOS setup path. GAS Anyone
  deploy may remain for the old Path 2 binary; this app does not use it.
- proves: Done-test 4–6, open risk "document the lock, do not build it."
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
  - [tier 3] Given `node test/run.js`, then it still passes.
- test notes: `test/lint.js` `check(name, bad, why)` like round 2 B5.
  **Vacuity:** delete the last-write-wins sentence, watch the new rule
  go red, put it back.
