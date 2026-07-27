# Progress — timetap error paths round

handoff: factory/HANDOFF.md
branch: factory/error-paths
baseline at launch: 298 assertions green under 4 timezones, `node test/lint.js` clear

Status values: `pending` · `in progress` · `done` · `PARKED`
A task is `done` only after the CHECKER step has independently re-verified it.

| Task | Title | Status | Attempts | Notes |
|---|---|---|---|---|
| A1 | Force a server failure; prove a write is set aside | done | 1 | All 5 criteria pass against **unmodified** `Index.html` — no finding, nothing to park. 21 new assertions (298 → 319), green under all 4 zones, lint clear. Checker: mutation-tested, see log. |
| B1 | A set-aside write identifies its block | done | 1 | All 5 criteria verified. 1-4 in section 35-35d; criterion 5 verified in section 36f once B2 gave it a surface to render on. Found F1 and F2 on the way. |
| B2 | Banner opens a drawer of set-aside writes | done | 1 | 35 assertions (337 → 372, 4 zones, lint clear). Fixes F1 and F2. CHECKER: 7 mutations, all caught — one of them (singular verb) only after I noticed my tests covered the plural case alone. |
| B3 | Discard an entry; banner clears with the last | done | 1 | 19 assertions (372 → 391, 4 zones, lint clear). CHECKER: 3 mutations, all caught — position-based identity, discard reaching into the queue, drawer not closing on the last entry. |
| C1 | A failed rollup records why | done | 1 | 19 assertions (391 → 410, 4 zones, lint clear). Record-then-rethrow into script property `ROLLUP_LAST`. CHECKER: 3 mutations, all caught. |
| C2 | Both tabs carry a last-rebuilt stamp | done | 1 | 30 assertions (410 → 440, 4 zones, lint clear). Golden fixture `test/fixtures/rollup-golden.json` captured from d048ca3, before the stamp existed. CHECKER: 5 mutations, all caught. One existing test amended (see log). |
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

### F1 — FIXED in B2 — the boot-time "set aside" banner erases itself (found during B1)

`boot()` calls `showErr(...)` with the set-aside count (`Index.html:964`), then drains and
calls `loadServerState()`, whose success handler calls `hideErr()` (`Index.html:906`). On
any healthy load the message is wiped before it can be read. It survives only when the
state load *also* fails — i.e. the message is visible exactly when it is least useful.
Contract item 9 requires the banner visible whenever a write has been set aside, so this
blocks B2 rather than being cosmetic.

Criteria (must pass before F1 is considered fixed):

- [tier 1] Given at least one set-aside write and a *healthy* server, when the app boots
  and the state load succeeds, then the banner is still visible.
- [tier 1] Given no set-aside writes, when the app boots and a transient error is shown
  and then cleared, then the banner is hidden — `hideErr()` still works for its own cases.
- [tier 1] Given a set-aside write and a later successful flush, then the banner does not
  get erased by that success either.

### F2 — FIXED in B2 — the count reads "1 write were set aside" (found during B1)

`Index.html:964` pluralises the noun but not the verb, so a single entry reads
`1 write were set aside after repeated failures`.

- [tier 1] Given exactly one set-aside write, then the message reads "1 write was set
  aside"; given two, "2 writes were set aside".
