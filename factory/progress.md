# Progress — timetap error paths round

handoff: factory/HANDOFF.md
branch: factory/error-paths
baseline at launch: 298 assertions green under 4 timezones, `node test/lint.js` clear

Status values: `pending` · `in progress` · `done` · `PARKED`
A task is `done` only after the CHECKER step has independently re-verified it.

| Task | Title | Status | Attempts | Notes |
|---|---|---|---|---|
| A1 | Force a server failure; prove a write is set aside | done | 1 | All 5 criteria pass against **unmodified** `Index.html` — no finding, nothing to park. 21 new assertions (298 → 319), green under all 4 zones, lint clear. Checker: mutation-tested, see log. |
| B1 | A set-aside write identifies its block | pending | 0 | |
| B2 | Banner opens a drawer of set-aside writes | pending | 0 | |
| B3 | Discard an entry; banner clears with the last | pending | 0 | |
| C1 | A failed rollup records why | pending | 0 | |
| C2 | Both tabs carry a last-rebuilt stamp | pending | 0 | |
| C3 | Last outcome readable by hand | pending | 0 | |
| D1 | A real browser opens Index.html | pending | 0 | |
| D2 | Harness serves the page as Apps Script does | pending | 0 | |
| D3 | Desktop viewport too, reported separately | pending | 0 | |
| D4 | Drift lint on the meta tags (HIGH RISK) | pending | 0 | |
| D5 | deploy.sh gains a third gate | pending | 0 | |
| E1 | Docs describe what now exists | pending | 0 | |

## Parked questions for the human

<!-- Anything the handoff does not answer. Write the question and what you did
     instead (park the task, or proceed on a stated assumption). -->

_none yet_

## Bugs found while building

<!-- Standing rule: a bug gets a criterion here FIRST, then the fix. -->

_none yet_
