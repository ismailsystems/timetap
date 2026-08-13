# Progress — Path 3 (SwiftUI writes Calendar itself)

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
| B3 | B | pending | 0 | |
| B4 | B | pending | 0 | |
| C1 | C | pending | 0 | |
| C2 | C | pending | 0 | |
| C3 | C | pending | 0 | |
| D1 | D | pending | 0 | |
| D2 | D | pending | 0 | |

## Contract additions

- B1 `DW: memo ??`: HANDOFF says mark `?` / text `memo ?`. Code.gs `MARK_TAIL_RE_` and `test/tests.js` 41d say mark null / text `memo ??`. GAS is the spec; Swift matches 41d.

## Parked tasks

_None. Three parked tasks trips the circuit breaker and ends the run._

## Skipped overnight (tier 2)

Do not set `RUN_LIVE=1`. Record each skipped live criterion here when you hit it.

- A1 live Sign-In — SKIP 2026-08-12. No `RUN_LIVE=1`. Token+scope proof is morning / iPhone.
- A2 live calendar list — SKIP 2026-08-12. No `RUN_LIVE=1`. List is `CalendarAPI.testList` overnight.
- A3 live DW insert — SKIP 2026-08-12. No `RUN_LIVE=1`. FakeCalendar only.
- A4 leftover API_TOKEN / live HTTPS — SKIP 2026-08-12. No `RUN_LIVE=1`. Grep + XCTest only.
- C3 live phone parity + rollup sees titles
