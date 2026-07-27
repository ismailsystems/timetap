# Progress — round 2, the honest record round

handoff: factory/HANDOFF-2.md · branch: `factory/honest-record`
started: _not yet — created 2026-07-27 at handoff time_

Round 1's progress record is `factory/progress.md` and is **read-only**.

## Status

Not started. 0 of 16 tasks complete.

## Tasks

| Task | Stage | Status | Attempts | Notes |
|---|---|---|---|---|
| A1 | A | pending | 0 | vacuity check required |
| A2 | A | pending | 0 | vacuity check required |
| A3 | A | pending | 0 | |
| A4 | A | pending | 0 | |
| A5 | A | pending | 0 | |
| B1 | B | pending | 0 | |
| B2 | B | pending | 0 | golden fixture changes here |
| B3 | B | pending | 0 | golden fixture changes here |
| B4 | B | pending | 0 | |
| B5 | B | pending | 0 | vacuity check required |
| C1 | C | pending | 0 | the sweep is the load-bearing criterion |
| C2 | C | pending | 0 | |
| C3 | C | pending | 0 | |
| D1 | D | pending | 0 | golden fixture changes here, second and last time |
| D2 | D | pending | 0 | |
| D3 | D | pending | 0 | |

## Baseline, measured 2026-07-27 before any work

```
node test/tests.js      492 passed, 0 failed
node test/lint.js       all clear — 17 rules, 38 files scanned
node test/headless.js   ok — 19 checks per viewport, drawer + tap-count green
```

`main` level with `origin/main` at `a256bdf`. `appsscript.json` byte-identical
to that commit and must stay so.

## Vacuity checks (mandatory — record what was reverted and what went red)

| Check | Task | Status |
|---|---|---|
| Revert regex to `[+=\-]`, parse criteria go red | A1 | not run |
| Revert `?` to `=`, mark criteria go red **while boundary criteria stay green** | A2 | not run |
| Delete the PLAN sentence from each doc **one at a time**, lint names that file | B5 | not run |

## Orientation

`HANDOFF-2.md`'s Orientation section asks for the Q&A to be appended to that
file. Its Guardrails say never to edit that file, under a heading reading "never
violate". The guardrail wins; orientation is recorded here, which the operating
loop already names as the loop's memory across restarts. Conflict flagged for
the reviewer.

**Questions to the human: none.** 112 criteria are specified against exact line
numbers, and the document's own instruction for genuine mid-run ambiguity is to
park it here rather than ask.

**Two naming choices made rather than parked** — both cheap to change at review,
neither worth stalling the run over:

- D1's "a key named for what it is" does not name the key. Using `UNPARSED`.
- D2's partial-week marker does not name the column. Will be decided at D2 and
  recorded here.

**Pre-flight finding, before task A1.** The baseline recorded above as green was
not. `node test/lint.js` failed on `factory/log-2.md:22` — the handoff's own
pre-flight entry quotes the stale round-1 scope claim, so the scope-count rule
caught its own paperwork. Resolved by adding `factory/log-2.md` to
`SCOPE_QUOTE_EXEMPT` on the rationale `factory/log.md` already carries. Full
reasoning and the cost of that choice are in `factory/log-2.md`. Baseline is
green as of that fix, and it is the real starting line: 492 / 0, lint all clear,
headless ok at 19 checks per viewport.

## Parked questions

_None yet. Anything the handoff does not answer goes here with the task parked,
rather than being guessed at silently._

## Contract additions

_Every bug found during the run gets a criterion written here first, then the
fix. Empty means nothing has been found yet, not that nothing was looked for._

## Parked tasks

_None. Three parked tasks trips the circuit breaker and ends the run._
