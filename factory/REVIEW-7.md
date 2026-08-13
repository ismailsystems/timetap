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
| orchestrator (contract + suite + boot probe) | **FIX FIRST** — the overnight suite is green twice, GAS is unharmed, and the phone still does not read Calendar on boot |
| angle 1 (GPT 5.6 Sol Max, contract) | **NOT DONE** — same boot-read hole; also cancel/sign-out pin the test seam so a later SDK sign-in is invisible |
| angles 2 and 3 | **NOT IN** — still running at this amend |

**The loop built a real Path 3 and it is not finished.** Capture ops, title
grammar, flush/401/403, add-category, settings, and the README all exist and
the tests that name them pass. What blocks shipping is that `getState` on the
phone is an in-memory function. Cold launch with a Google session and three
calendar IDs never lists ACTUAL / SITTING over HTTP. The banner becomes
`ApplyOps.ReadError error 0`, `today` stays empty, and the day rail only shows
blocks closed in this process. That is B4 / contract 16's job, and it is not
done on the path a user hits.

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

### 1. Boot with saved Google IDs never reads Calendar

- what happens: Signed in, three IDs saved, queue empty. `RootView.onAppear` calls `boot()` → `loadServerState()` → `ApplyOps.getState()`. `ApplyOps.actual` / `.sitting` are nil on a fresh process. `getState` throws. The banner is `The operation couldn’t be completed. (TimeTap.ApplyOps.ReadError error 0.)`. `today` is not persisted and stays `[]`. The rail only shows the current `open` (and blocks closed later in this session via `railClosed`). HTML / yesterday's ACTUAL events are invisible.
- how I proved it: Temporary XCTest `testBootWithNoInMemoryCalendarLeavesTodayEmpty` (session+IDs, `ApplyOps.resetForTests()`, `bootNow()`, `XCTAssertNil(store.banner)`). Failed twice:

```
XCTAssertNil failed: "The operation couldn’t be completed. (TimeTap.ApplyOps.ReadError error 0.)"
- boot with saved IDs must read Calendar, not fail closed
```

  Code: `TapStore.swift` `loadServerState` only calls `ApplyOps.getState()`. `CalendarAPI.listEvents` is reached only from `liveFlush`. `liveFlush` runs only when `GoogleAuth.testHasSession == nil` (production flush with a real token). Sign-in success (`SignInView`) and picker Confirm (`CalendarPickerView.confirm`) do not call `boot()`. `refreshOnReturn` also calls `ApplyOps.getState()`, so it cannot repair a process that has never flushed. After the first successful flush, `ApplyOps.actual` is the last flush's snapshot — still not a dedicated read.
- severity: **blocks shipping**
- suggested next step: Give `CalendarAPI` a getState path that lists ACTUAL + SITTING the way `liveFlush` already lists, then `ApplyOps.getState()`. Call it from empty-queue boot, from post-sign-in, from picker Confirm, and from `refreshOnReturn`. Test: boot with session+IDs and a list seam populated with a closed DW + an `#open` MTG; `today`/`open` must match; banner must be nil. Vacuity: boot with the list seam nil must go red.

Angle 1 independently named this hole (B4 / assertions 16 and 20 on the live path). Assertion 20's parse (Lunch → UNFILED) holds on FakeCalendar; the live miss is this same unread `getState`.

### 2. Cancel or sign-out pins `testHasSession = false`, so the next SDK sign-in is invisible

- what happens: Production `applyCancelledSignIn` and `signOut` write `GoogleAuth.testHasSession = false`. `hasSession` returns that Bool whenever it is non-nil, and never reads `GIDSignIn.currentUser` again. `signInFromKeyWindow` on success does not clear the seam. `SignInView` still dismisses the sheet; the next DW tap sees `hasSession == false` and shows Sign-In again.
- how I proved it: Temporary XCTest `testCancelDoesNotPinTheTestSeamOff`: `testHasSession = nil`, then `applyCancelledSignIn()`, then `XCTAssertNil(testHasSession)`. Failed:

```
XCTAssertNil failed: "false" - production cancel must not pin testHasSession; a later SDK sign-in becomes invisible
XCTAssertNil failed: "false" - sign-out must not pin testHasSession either
```

  Code: `GoogleAuth.swift` 16–24, 55–68, 38–52. The A1 cancel test (finding 3) hid this: it *wants* `hasSession == false` after cancel, which the stuck seam provides.
- severity: **should fix** (user-facing in one process: cancel or sign out, then sign in without killing the app)
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

1. **Fix the boot read before daily use, or accept a first-session-blind phone?** Recommendation: fix. Last-write-wins only works if the phone reads. The loop claimed B4 done against a FakeCalendar that tests preloaded; a user with an existing ACTUAL calendar does not get that preload.
2. **Run the five tier-2 live checks on the iPhone after the boot fix, not before.** A live DW insert today would write; it would not prove the rail shows this morning's HTML blocks.

No other open product tradeoff. Do not reopen: Google Sign-In not EventKit; no Calendar SDK; no lock; `CATEGORIES` stays six in `Code.gs`; no `git push` of Path 3 onto `main` from this review.

---

## Mini-handoff (if you run another loop)

One task. Same operating loop as HANDOFF-3. Criteria first. Fake calendars only. No `RUN_LIVE=1`. No `Code.gs` edits.

**P3-R7-1. Empty-queue boot lists Calendar and adopts state**

- [tier 1] Given a Google session, saved PLAN/ACTUAL/SITTING IDs, empty queue, and a list seam holding a closed `DW:` and an `#open` `MTG:`, when `bootNow()` runs, then `open.key == "MTG"`, `today` contains the DW block, and `banner` is nil.
- [tier 1] Given the same with `ApplyOps.actual == nil` and no list seam, when boot runs, then the UI does **not** claim SYNCED-and-idle as if the calendars were empty; it shows a read error it can retry. (Today's code already errors — the first criterion is the one that must start failing if you only keep the error.)
- [tier 1] Given Sign-In succeeds and IDs are already saved, when the sheet dismisses, then the same getState path runs.
- [tier 1] Given picker Confirm writes three IDs, then the same getState path runs.
- [tier 1, error] Given list throws, then `open`/`today` from persist are not wiped to a fake idle day (same spirit as B4's read-error criterion).
- Vacuity: comment out the list call on the boot path; the first criterion goes red; put it back.

**P3-R7-2. Cancel and sign-out must not pin the test seam**

- [tier 1] Given `testHasSession == nil` (production), when cancel or sign-out runs, then `testHasSession` is still nil and `hasSession` follows `GIDSignIn.currentUser`.
- [tier 1] Given a successful `signInFromKeyWindow` after a cancel in the same process, then `hasSession` is true (or follows the SDK user), and a DW tap is not bounced back to Sign-In for lack of session.
- Vacuity: leave `testHasSession = false` in `applyCancelledSignIn`; the first criterion goes red; put it back.

Should-fix 3–4 may ride along if they stay small. Do not "fix" Google Sign-In because tier-2 is still skipped.
