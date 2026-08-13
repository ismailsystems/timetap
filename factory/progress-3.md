# Progress — Path 3 (SwiftUI writes Calendar itself)

## RUN SUMMARY

Outcome: **all remaining tasks C1–D2 done.** Stages A–D complete on `path-3-ios`. No parked tasks. Circuit breaker did not fire. GAS 1196 / 0 twice. Lint all clear twice. Headless 31/0 twice. XCTest 86/0 twice on iPhone 17 Pro Max, OS 26.5. Nothing was pushed.

| Task | Status |
|---|---|
| A1–B4 | done (prior run) |
| C1 | done (2 attempts; checker FAIL then PASS) |
| C2 | done |
| C3 | done (3 attempts; checker FAIL ×2 on weak asserts, then PASS) |
| D1 | done |
| D2 | done |

Parked: none.

Vacuity (five required):
- A3 omit `colorId` → colour criterion red (`""` ≠ `"9"`); restored.
- B1 mark regex `[+=\\-]` → `?` parse red (19 fails); restored `[+=\\-?]`.
- B2 drop already-closed guard → stretch red; restored.
- B3 skip `if ne != nil return` → 2 `#open`; restored.
- D2 delete last-write-wins sentence → lint FAIL names `ios/README.md`; restored.

Tier-2 the human still owes (`RUN_LIVE=1` on the iPhone, not overnight):
- A1 live Sign-In token+scope
- A2 live calendarList
- A3 live DW insert
- A4 leftover API_TOKEN / live HTTPS
- C3 live phone parity + rollup sees titles

Commands to see it work:

```bash
node test/tests.js && node test/lint.js
node test/headless.js
cd ios && ./scripts/sync-google-config.sh && xcodegen generate
xcodebuild -scheme TimeTap \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' \
  test
```

On a phone: Sign in with Google (GCP `timetap-505402`), pick PLAN/ACTUAL/SITTING, tap DW, check Calendar. Do not paste `API_TOKEN` or an `/exec` URL.

Branch: `path-3-ios`
Handoff: `factory/HANDOFF-3.md`
Baseline (2026-08-12, `main` at `1f84fce`): **1196 passed / 0 failed** · lint all clear.

| Task | Stage | Status | Attempts | Notes |
|---|---|---|---|---|
| A1 | A | done | 1 | Google Sign-In + URL scheme; Settings has no token form. Checker PASS (cursor-grok-4.5-high). Cancel test is a stub; live Sign-In skipped. |
| A2 | A | done | 2 | Picker preselect + first-match + persist via UserDefaults. Attempt 1: checker FAIL (vacuous tests). Attempt 2: Pick state + hand-pick SITTING; checker PASS. |
| A3 | A | done | 2 | Thin DW insert on fake calendar, colorId 9. Attempt 1 checker FAIL (UserDefaults leak + retry was split). Attempt 2: persist reset + retap retries; checker PASS twice. Vacuity: omit colorId → "" ≠ "9", restored. |
| A4 | A | done | 2 | Deleted TimetapAPI. Attempt 1 checker FAIL: config nil → empty grid, no DW. Attempt 2: seed CATEGORIES+POOP (color 1). Checker PASS. |
| B1 | B | done | 1 | Swift Grammar matches Code.gs titles/colours/desc. Vacuity: `[+=\\-]` → ? parse red (19 fails); restored. Checker PASS. HANDOFF `??` sentence is stale; GAS 41d wins. |
| B2 | B | done | 1 | ApplyOps against FakeCalendar. Vacuity: drop already-closed guard → stretch red (1700010800000 ≠ 1700003600000); restored. Checker PASS. |
| B3 | B | done | 1 | undoSwitch + staleGuard Chicago. Vacuity: skip `if ne != nil return` → overtaken test red (2 #open); restored. Checker PASS. MISTAP 20s not HANDOFF 30s. |
| B4 | B | done | 1 | getState: findOpen + staleGuard + today. Lunch → UNFILED. Read error throws. Checker PASS. today skips UNLOGGED (GAS). |
| C1 | C | done | 2 | Flush → ApplyOps + Calendar HTTP. 401 refresh once; second 401 no loop. 429/500 backoff then dead at 5. 403 retried then set aside. Attempt 1 checker FAIL (getState discarded). Attempt 2: adoptServerState; undo leaves open=DW. Checker PASS (cursor-grok-4.6-high-fast). |
| C2 | C | done | 1 | Local addCategory. DEEPREAD from Deep reading. Cap 10. Persist extras. No removeCategory. Code.gs CATEGORIES still six. Checker PASS (cursor-grok-4.6-high-fast). |
| C3 | C | done | 3 | TapStore clock + fake calendar: DW/MTG/undo/sit/split/recat/note/mark/STOP match B2 writer. Rail UNLOGGED gap. Lunch→UNFILED unreadable. Attempts 1–2 checker FAIL (weak asserts). Attempt 3 PASS (cursor-grok-4.6-high-fast). Tier-2 live skipped. |
| D1 | D | done | 1 | Settings picker keeps saved IDs; Confirm ACTUAL=a2 used on next insert. Sign-out clears token, IDs survive relaunch. Empty SITTING does not overwrite. No lock. Checker PASS (cursor-grok-4.6-high-fast). |
| D2 | D | done | 1 | Path 3 ios/README.md: OAuth client, URL scheme, Sign-In, picker, last-write-wins, rollup on Apps Script. Lint rules pin last-write-wins + Sign-In. Vacuity: delete last-write-wins → lint FAIL names ios/README.md; restored. Checker PASS (cursor-grok-4.6-high-fast). |

## Contract additions

- B1 `DW: memo ??`: HANDOFF says mark `?` / text `memo ?`. Code.gs `MARK_TAIL_RE_` and `test/tests.js` 41d say mark null / text `memo ??`. GAS is the spec; Swift matches 41d.
- B3 fresh-open: HANDOFF says 30s across midnight stays open. Code.gs uses `age < MISTAP_SECONDS` (20s). Swift matches GAS.
- B4 stale today: HANDOFF says today includes the `?` block and UNLOGGED. GAS skips UNLOGGED and a block that ends at local midnight. Swift matches GAS.
- Review 8 vs `main`: `CalendarAPI.refreshState` and `flushOps` share one serial gate so boot getState cannot drop a tap write. A 401 on getState refreshes the token once, then Sign-In. Return-from-background flushes a non-empty queue. HTTP 400 on a multi-op batch retries the batch and does not dead-letter `queue.first`. A set-aside `splitActual` / `undoSwitch` restores the block still running on Calendar (Path 2 `quarantine`). The mark row names the closed block. UNDO sits 12pt above TAP TO SIT. TAP TO SIT without a session does not enqueue. Remainder SPLIT will not cut after now.

## Parked tasks

_None. Three parked tasks trips the circuit breaker and ends the run._

## Skipped overnight (tier 2)

Do not set `RUN_LIVE=1`. Record each skipped live criterion here when you hit it.

- A1 live Sign-In — SKIP 2026-08-12. No `RUN_LIVE=1`. Token+scope proof is morning / iPhone.
- A2 live calendar list — SKIP 2026-08-12. No `RUN_LIVE=1`. List is `CalendarAPI.testList` overnight.
- A3 live DW insert — SKIP 2026-08-12. No `RUN_LIVE=1`. FakeCalendar only.
- A4 leftover API_TOKEN / live HTTPS — SKIP 2026-08-12. No `RUN_LIVE=1`. Grep + XCTest only.
- C3 live phone parity + rollup sees titles

