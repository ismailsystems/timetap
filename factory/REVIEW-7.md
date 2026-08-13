# Review: Path 3 (SwiftUI writes Calendar itself) — 2026-08-13

Reviews 1–2 are round 1. Review 3 is round 2. Review 4 is the redesign.
Review 5 is FIXES-4. Review 6 is FIXES-5. This is the seventh, and it reviews
Path 3 on `path-3-ios` (`1f84fce..4bd123f`, thirteen task commits A1–D2).

**How it was run.** The contract is `factory/HANDOFF-3.md` (28 assertions plus
per-task criteria). `factory/progress-3.md` was treated as a claimed-done list,
not as proof. `factory/log-3.md` and the commit messages were read only at the
end. Three independent Task reviewers were launched (GPT 5.6 Sol Max / Fable 5
Max / Opus 5) and told to stay read-only. Angle 1 (GPT) returned **NOT DONE**.
Angles 2 and 3 were still running at this amend. Probe mutations to
`ApplyOps.swift` / `TimeTapApp.swift` / `project.yml` were reverted before the
numbers below were taken. Every finding that would block, and the two new
auth findings from angle 1, were reproduced by the orchestrator on the
restored tree.

---

## Verdicts

| Reviewer | Verdict |
|---|---|
| orchestrator | **FIX FIRST** — suite green twice, GAS unharmed; the phone does not read Calendar, and `staleGuard` never writes back |
| angle 1 (GPT 5.6 Sol Max, contract) | **NOT DONE** — boot-read hole; cancel/sign-out pin the test seam |
| angle 3 (Claude Opus 5, user-fail) | **FIX FIRST** — same two holes, plus extra-category `colorId ""`, picker trap, and a SYNCING lie |
| angle 2 | **NOT IN** — still running at this amend |

**The loop built a real Path 3 and it is not finished.** Capture ops, title
grammar, flush/401/403, add-category, settings, and the README all exist and
the tests that name them pass. What blocks shipping is that `getState` on the
phone is an in-memory function: cold launch never lists Calendar, and
`staleGuard` / duplicate-`#open` repairs run only after `pushDiff`, so the
22:00→07:00 `?` + `UNLOGGED` case in contract 16 cannot reach Google. Cancel
in the Google sheet also pins a test seam and locks Sign-In until force-quit.

---

## What I verified myself

**Gates, run twice on the restored tree (2026-08-13):**

| Gate | Pass 1 | Pass 2 |
|---|---|---|
| `node test/tests.js` | 1196 passed, 0 failed | 1196 passed, 0 failed |
| `node test/lint.js` | all clear (23 `check(` rules) | all clear |
| `node test/headless.js` | 31 passed, 0 skipped per viewport | same |
| XCTest iPhone 17 Pro Max OS 26.5, `-parallel-testing-enabled NO` | 86 tests, 0 failures | 86 tests, 0 failures |

`git diff main -- Code.gs Index.html appsscript.json test/fixtures/rollup-golden.json` is empty. Assertion floor 1196 held. `TimetapAPI` is gone from `ios/TimeTap`. `EventKit` / Google Calendar SDK / `LockService` are absent. `Google.xcconfig` and `ios/.secrets/` are gitignored.

D2 vacuity, run by hand: delete the last-write-wins sentence from `ios/README.md` → lint **FAIL** names `ios/README.md`; restore → all clear.

**Contract 1–28**

| # | Result | Proof |
|---|---|---|
| 1 | MET | 1196 / 0 twice |
| 2 | MET | lint all clear twice; Path 3 added two rules, did not drop old ones |
| 3 | MET | `Code.gs` byte-identical to `main` at `1f84fce` |
| 4 | MET | headless 31/0 twice |
| 5 | MET (tier 1) | Settings has no token form; cold `TapStore` with no session sets `showSignIn`. Live Sign-In is tier 2, skipped |
| 6 | MET | A2Tests first-match / preselect |
| 7 | MET | A2 persist via UserDefaults |
| 8 | MET | Confirm disabled without SITTING |
| 9 | MET against FakeCalendar | A3 colour 9, `#ref:`/`#open`, +60s. Not proven on a live ACTUAL |
| 10 | MET | grep: no `script.google.com` / `macros/s/` on the write path |
| 11 | MET | B1 golden roundtrip vs `test/fixtures/title-golden.json` |
| 12 | MET | B1 colour table |
| 13 | MET | B2 already-closed / guessed close |
| 14 | MET | B2 second open closes first |
| 15 | MET | B3 overtaken undo |
| 16 | **NOT MET on the phone** | ApplyOps `getState` matches GAS on a preloaded FakeCalendar (B4). Production boot never lists Calendar — see Blocking 1. GAS `today` skips UNLOGGED (Code.gs:824); Swift matches GAS, not the stale HANDOFF sentence |
| 17 | MET | B3 STOP closes both, opens nothing |
| 18 | MET | B3 category tap does not touch SITTING |
| 19 | MET | B2 `mark: '?'` dropped |
| 20 | MET | Lunch with Ada → UNFILED |
| 21 | MET | C1 five rejects → dead, `open` cleared |
| 22 | MET | C1 401 refresh once; second 401 no loop |
| 23 | MET | no `TimetapAPI` in TimeTap sources |
| 24 | MET | C2 seed + DEEPREAD + cap 10; `Code.gs` CATEGORIES still six |
| 25 | MET (tier 1) | D1 sign-out keeps IDs; signed-out tap does not insert |
| 26 | MET | D1 next insert uses `a2` |
| 27 | MET | ios/README.md + lint pins |
| 28 | MET as a skip | no `RUN_LIVE=1`; Swift tests never hit live Calendar |

**Contract additions in progress-3.md** (HANDOFF vs GAS). Verified against `test/tests.js` 41d and `Code.gs`, which predate Path 3. Not tampering. GAS wins, Swift matches GAS:

- `DW: memo ??` → mark null, text `memo ??` (41d). HANDOFF B1's "mark `?` / text `memo ?`" is still wrong in the handoff file.
- Fresh-open window is `MISTAP_SECONDS` 20s, not HANDOFF's 30s.
- `today` skips UNLOGGED (and the open block). HANDOFF 16's "includes UNLOGGED" is the stale half.

---

## Findings (worst first)

### 1. Boot never reads Calendar, and `staleGuard` never writes back

- what happens: Signed in, three IDs saved, queue empty. `boot()` → `loadServerState()` → `ApplyOps.getState()`. `ApplyOps.actual` / `.sitting` are nil on a fresh process. `getState` throws. The banner is `The operation couldn’t be completed. (TimeTap.ApplyOps.ReadError error 0.)`. `today` is not persisted and stays `[]`. The rail only shows the current `open` (and blocks closed later in this session via `railClosed`).

  Second half: `staleGuard` is called only from `getState` (`ApplyOps.swift:49,65`). `liveFlush` lists, `apply`s, then `pushDiff`s (`CalendarAPI.swift:297-299`). `getState` after a flush mutates that in-memory copy **after** `pushDiff` has finished. A 07:00 category tap uses `opOpenActual`, which ends the overnight DW at 07:00 with no `?` and no `UNLOGGED` gap. Contract 16 / B3 night case therefore cannot happen on a phone. `findOpen`'s duplicate-`#open` close is the same class of unpushed repair.

- how I proved it: Temporary XCTest `testBootWithNoInMemoryCalendarLeavesTodayEmpty` failed twice with the ReadError banner. Grep: one `staleGuard` definition, callers only inside `getState`; `liveFlush` order is apply then pushDiff; `apply` does not call `staleGuard`. Angle 3's PROBE-U1 matched the same banner.
- severity: **blocks shipping**
- suggested next step: List ACTUAL + SITTING on boot / post-sign-in / picker Confirm / `refreshOnReturn`. After `staleGuard` (and duplicate-open repair), push the diff the way `liveFlush` already pushes apply. Test the Chicago 22:00→07:00 case against the fake calendar **after** that push, not only against `getState`'s return value. Vacuity: skip the push after `staleGuard`; the calendar must still hold an unmarked open DW.

Angle 1 independently named the unread boot. Angle 3 named the unpushed `staleGuard`. Assertion 20's parse (Lunch → UNFILED) holds on FakeCalendar; the live miss is this same unread `getState`.

### 2. Cancel or sign-out pins `testHasSession = false`, so the next SDK sign-in is invisible

- what happens: Production `applyCancelledSignIn` and `signOut` write `GoogleAuth.testHasSession = false`. `hasSession` returns that Bool whenever it is non-nil, and never reads `GIDSignIn.currentUser` again. `signInFromKeyWindow` on success does not clear the seam. `SignInView` still dismisses the sheet; the next DW tap sees `hasSession == false` and shows Sign-In again.
- how I proved it: Temporary XCTest `testCancelDoesNotPinTheTestSeamOff`: `testHasSession = nil`, then `applyCancelledSignIn()`, then `XCTAssertNil(testHasSession)`. Failed:

```
XCTAssertNil failed: "false" - production cancel must not pin testHasSession; a later SDK sign-in becomes invisible
XCTAssertNil failed: "false" - sign-out must not pin testHasSession either
```

  Code: `GoogleAuth.swift` 16–24, 55–68, 38–52. The A1 cancel test (finding 3) hid this: it *wants* `hasSession == false` after cancel, which the stuck seam provides.
- severity: **blocks shipping** (first-run: cancel the Google sheet, then sign in again, without force-quit)
- suggested next step: Cancel and sign-out must `signOut()` the SDK and set `testHasSession = nil` unless a test explicitly set the seam. After a successful `signInFromKeyWindow`, `hasSession` must follow `GIDSignIn.currentUser`.

### 3. Cold restore of a Google session does not update the store

- what happens: `@StateObject private var store = TapStore()` runs before `TimeTapApp.init()` calls `GoogleAuth.restore()`. Restore's callback is `{ _, _ in }` — it does not set session, dismiss Sign-In, or boot. A relaunch can show Sign-In while Google still has a user, or skip boot if `currentUser` is already present and `TapStore.init` raced ahead of restore.
- how I proved it: `TimeTapApp.swift` 6–18; `GoogleAuth.restore` at 71–73; `TapStore.init` 110–116 reads `hasSession` once. No later callback.
- severity: **should fix**
- suggested next step: Restore must complete (or fail) before the store decides Sign-In vs capture, and a successful restore must `boot()`.

### 4. A1's cancel criterion is a stub

- what happens: `testCancelledSignInStoresNothingAndDoesNotTalkToCalendar` sets `testHasSession` / `didFetchCalendarList` / `didAttemptCalendarWrite` to true, then calls `GoogleAuth.applyCancelledSignIn()`, then asserts those flags are false. It never presents Sign-In or cancels it.
- how I proved it: read `A1Tests.swift` and `GoogleAuth.applyCancelledSignIn()`. Production `signInFromKeyWindow` does call `applyCancelledSignIn` on `GIDSignInError.canceled`, so the wiring exists; the test does not drive it.
- severity: **should fix**
- suggested next step: Keep the production cancel path. Replace the stub with a test that calls the same `isCancel` branch without inventing a live Google sheet, or mark the criterion as the live Sign-In skip it actually is.

### 5. Dead A3 insert path still sits next to the queue

- what happens: `tapCategory` calls `CalendarAPI.openActual` only when `testCalendar != nil` (A3 tests). Production enqueues and flushes. `TapStore.pushInsert` / `CalendarAPI.httpInsertPending` are never called. `retryLastInsert` is the A3 fail/retap path, not the queue.
- how I proved it: grep `pushInsert(` — definition only. `tapCategory` lines 196–204.
- severity: **cosmetic** (the queue is the real writer) unless a future change starts calling `pushInsert` and double-writes.
- suggested next step: Delete `pushInsert` / `httpInsertPending`, or call one of them on purpose. Do not leave both.

### 6. Shared mutable test seams

- what happens: `ApplyOps.actual`, `CalendarAPI.testCalendar`, `GoogleAuth.testHasSession`, and `Credentials` IDs are process globals. A parallel or overlapping run can make A3 see `colorId ""` and B1 see `?` fail to parse — both were observed in this session while another agent had mutated `ApplyOps` / `Grammar` for vacuity and had not put them back yet. On the restored tree, serial XCTest is 86/0 twice.
- how I proved it: dirty-tree XCTest red (A3 colour, B1 `?` parse, B2 guessed close) vs restored-tree 86/0. `git checkout --` on the mutated files recovered green.
- severity: **should fix** for the suite's honesty, not a user-facing Path 3 fault
- suggested next step: Reset seams in `tearDown` as well as `setUp`. Do not mutate product files for vacuity on a shared tree.

### 7. An added category writes `colorId ""`

- what happens: `addCategory("Deep reading")` stores `color: "2"` on the `Category`. `Grammar.colorId(for:)` reads only `TT.colorIdByKey` (the seven seed keys) and returns `""` for `DEEPREAD`. `applyCatColor` skips an empty id. `eventBody` always sends `"colorId": ""`. The grid shows `#33b679`; Google gets no colour (default, or HTTP 400 — live unproven).
- how I proved it: `C2Tests` asserts `extra.color == "2"` on the category, not on the event. `Grammar.swift:103-105`; `ApplyOps.applyCatColor` 245-248; `CalendarAPI.eventBody` 373-379. `Grammar.colorId("DEEPREAD")` is `""` by construction.
- severity: **should fix** (contract 24's add path; colour is how rollup readers scan the calendar)
- suggested next step: `applyCatColor` / `openActual` must use `Category.color` (or `Grammar.nextColor`'s id) for unknown keys. Vacuity: leave `colorIdByKey` as the only source; a DEEPREAD insert must go red on `colorId != "2"`.

### 8. The calendar picker has no way out when the list fails

- what happens: `fullScreenCover` + `interactiveDismissDisabled()`. No Cancel, Close, or Retry. `listCalendars` throw → `pick = .loaded([])`, Confirm stays disabled, raw `NSURLError` text. First sign-in on a bad radio, and Settings → Change calendars while offline, both trap until force-quit. Contract 8 is met to the letter (Confirm disabled); it did not ask for a way back.
- how I proved it: `CalendarPickerView.swift` 9-46, 58-66. Angle 3 drove it on the simulator (Confirm disabled, swipe-down still on picker).
- severity: **should fix**
- suggested next step: Close (keep saved IDs) and Retry. Do not strand Settings.

### 9. The header says SYNCING after the flush has stopped

- what happens: A second 401 returns without `quarantine`, without a banner, without Sign-In (`TapStore.flushAsync` 738-742). Any other 4xx (400) calls `scheduleRetry` without `quarantine`, so `tries` never increments and the op never reaches dead-letter. `paintSync` still shows `SYNCING · N` while `syncFailed` is false.
- how I proved it: `flushAsync` 737-760 vs 748-755 (403/429/5xx do quarantine). `paintSync` 1005-1009: nonempty queue → `SYNCING`. Angle 3 PROBE-U14–U16.
- severity: **should fix**
- suggested next step: Second 401 must prompt Sign-In (or dead-letter). Other 4xx must count a try. Do not paint SYNCING when no retry is scheduled.

### 10. The eleventh add is refused by hiding Add, with no ceiling text

- what happens: `CaptureView` wraps Add in `if store.canAddCategory`. At 10 the row disappears. The banner `"That is 10 categories already."` is only reachable from `addCategory`, which the UI can no longer call. C2's store test still sees the banner.
- how I proved it: `CaptureView.swift:184-187`; `TapStore.canAddCategory` 554-556; C2Tests `testEleventhAddIsRefusedWithCeiling`.
- severity: **cosmetic** (cap is real; the user is not told why Add left)
- suggested next step: Keep the row disabled and show the ceiling, or show the banner when the count hits 10.

Not a Path 3 regression: the keyboard covers STOP / undo / marks (`CaptureView` `.ignoresSafeArea(.keyboard)`). That file is not in `1f84fce..HEAD`. Report it; do not spend the fix loop on it unless the human asks.

---

## Parked work

None from the loop. Circuit breaker did not fire.

Tier-2 still owed by the human, as the handoff required (`RUN_LIVE=1` on the phone, never overnight):

- A1 live Sign-In token + calendar scope
- A2 live `calendarList`
- A3 live DW insert
- A4 leftover `API_TOKEN` / live HTTPS
- C3 live parity + rollup sees titles

Those skips are honest. They are not a pass. Finding 1 is not in that list — it is a tier-1 hole the fake-calendar tests did not look at.

---

## What is right, for calibration

- GAS writer, HTML capture, rollup golden: untouched. 1196 held.
- Swift `Grammar` / `ApplyOps` match `Code.gs` on the B1–B4 tables, including the three GAS-wins cases the loop recorded.
- Queue: 401 once, 403 then dead, 429/500 backoff, five `openActual` rejects clear `open`, `setMark` dead leaves the block running, applied `undoSwitch` calls `getState` (against the in-memory calendar the tests already filled).
- Category tap does not close sitting. STOP does. Add category is local, cap 10, `DEEPREAD` from "Deep reading", no `removeCategory`.
- Settings: change IDs, sign-out keeps IDs, empty SITTING does not overwrite. Last-write-wins is in `ios/README.md` and lint-pinned.
- Product law: no scoring, no lock.

---

## Decisions for you

1. **Fix the boot read and the unpushed `staleGuard` before daily use?** Recommendation: fix. The contract already says the phone ports `staleGuard_`. Computing `?` / `UNLOGGED` in memory and throwing them away is worse than leaving that work on Apps Script.
2. **Run the five tier-2 live checks on the iPhone after those reads write, not before.** A live DW insert today would write; it would not prove the rail or the overnight bound.

---

## Mini-handoff (if you run another loop)

Three tasks. Same operating loop as HANDOFF-3. Criteria first. Fake calendars only. No `RUN_LIVE=1`. No `Code.gs` edits.

**P3-R7-1. Empty-queue boot lists Calendar and adopts state**

- [tier 1] Given a Google session, saved PLAN/ACTUAL/SITTING IDs, empty queue, and a list seam holding a closed `DW:` and an `#open` `MTG:`, when `bootNow()` runs, then `open.key == "MTG"`, `today` contains the DW block, and `banner` is nil.
- [tier 1] Given the same with `ApplyOps.actual == nil` and no list seam, when boot runs, then the UI does **not** claim SYNCED-and-idle as if the calendars were empty; it shows a read error it can retry. (Today's code already errors — the first criterion is the one that must start failing if you only keep the error.)
- [tier 1] Given Sign-In succeeds and IDs are already saved, when the sheet dismisses, then the same getState path runs.
- [tier 1] Given picker Confirm writes three IDs, then the same getState path runs.
- [tier 1, error] Given list throws, then `open`/`today` from persist are not wiped to a fake idle day (same spirit as B4's read-error criterion).
- [tier 1] Given DW opened at local 22:00 Chicago and no further ops, when getState runs at 07:00 the next local day **and the result is pushed**, then the fake ACTUAL holds `DW` ending at midnight with mark `?` and `UNLOGGED -` from midnight to 07:00. Vacuity: skip that push; the calendar after getState must still show an unmarked open DW.
- Vacuity: comment out the list call on the boot path; the first criterion goes red; put it back.

**P3-R7-3. Extra categories keep the colour `nextColor` assigned**

- [tier 1] Given `addCategory("Deep reading")` then `openActual` DEEPREAD, then the event's `colorId` is `"2"` (not `""`).
- Vacuity: `Grammar.colorId` stays seed-only; that insert criterion goes red.

**P3-R7-2. Cancel and sign-out must not pin the test seam**

- [tier 1] Given `testHasSession == nil` (production), when cancel or sign-out runs, then `testHasSession` is still nil and `hasSession` follows `GIDSignIn.currentUser`.
- [tier 1] Given a successful `signInFromKeyWindow` after a cancel in the same process, then `hasSession` is true (or follows the SDK user), and a DW tap is not bounced back to Sign-In for lack of session.
- Vacuity: leave `testHasSession = false` in `applyCancelledSignIn`; the first criterion goes red; put it back.

Should-fix 3, 8, 9 and restore (finding 3) may ride along if they stay small. Do not "fix" Google Sign-In because tier-2 is still skipped. Do not reopen the keyboard/STOP overlap unless the human asks.
