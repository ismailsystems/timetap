# Progress — Path 3 (SwiftUI writes Calendar itself)

Branch: `path-3-ios`
Handoff: `factory/HANDOFF-3.md`
Baseline (2026-08-12, `main` at `1f84fce`): **1196 passed / 0 failed** · lint all clear.

| Task | Stage | Status | Attempts | Notes |
|---|---|---|---|---|
| A1 | A | done | 1 | Google Sign-In + URL scheme; Settings has no token form. Checker PASS (cursor-grok-4.5-high). Cancel test is a stub; live Sign-In skipped. |
| A2 | A | pending | 0 | |
| A3 | A | pending | 0 | |
| A4 | A | pending | 0 | |
| B1 | B | pending | 0 | |
| B2 | B | pending | 0 | |
| B3 | B | pending | 0 | |
| B4 | B | pending | 0 | |
| C1 | C | pending | 0 | |
| C2 | C | pending | 0 | |
| C3 | C | pending | 0 | |
| D1 | D | pending | 0 | |
| D2 | D | pending | 0 | |

## Contract additions

_None yet. Bugs found later get a criterion here first, then the fix._

## Parked tasks

_None. Three parked tasks trips the circuit breaker and ends the run._

## Skipped overnight (tier 2)

Do not set `RUN_LIVE=1`. Record each skipped live criterion here when you hit it.

- A1 live Sign-In — SKIP 2026-08-12. No `RUN_LIVE=1`. Token+scope proof is morning / iPhone.
- A2 live calendar list
- A3 live DW insert
- C3 live phone parity + rollup sees titles
