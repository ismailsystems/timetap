# Fix list 3 — round 2's rulings and its review, in one pass

compiled: 2026-07-28 · branch `factory/honest-record`
sources: the human's rulings on the 16 parked questions (`factory/progress-2.md`,
`## ANSWERS FROM THE HUMAN`) and the three-reviewer review
(`factory/REVIEW-3.md`, verdict FIX FIRST).

Same operating loop as `factory/HANDOFF-2.md`: one item at a time, its criterion
written before its fix, verified by running it, and the suite green under all
four contracted timezones at the end. The guardrails of that document still
apply in full — `HANDOFF-2.md` and round 1's files are never edited,
`appsscript.json` stays byte-identical, `test/fixtures/rollup-golden.json` stays
frozen (the human's ruling on Q14), and nothing points at a real calendar.

**Counts, stated exactly, because the last summary got them wrong:**
**9 code changes from the rulings, 5 from the review, 5 corrections of fact,
and 6 rewordings.** 25 items.

---

## A. Code changes the human ruled on

| # | From | Change | Criterion to write first |
|---|---|---|---|
| A1 | Q12+Q18 | Close the SPLIT sheet and the SIT time sheet when the block they name stops being the one in hand | A sheet aimed at a block closes when `S.open` changes ref or goes null, whether the cause is a refresh from the server or a set-aside write. Nothing in the sheet can then act on a block the user did not aim at. |
| A2 | Q9 | A guessed block's **start** may bound the waking span; its end may not | The row can no longer report more category hours than waking hours *because of the start*. `UNLOGGED` still bounds neither end. Contract 22 is reworded (F1 below). |
| A3 | Q10 | `keyFor_` reserves `UNLOGGED` and `UNFILED` | A category named "Unlogged" derives `UNLOGGE2`, exactly as a second category named "Deep work" derives `DW2`. Neither reserved key can be taken. |
| A4 | Q2 | Protect all four marks from a note that ends in one | A note ending ` +`, ` =`, ` -` or ` ?` never applies a mark the user did not choose. Contract 17's protection, widened from one character to four. |
| A5 | Q4 | `validOp_` refuses `mark: '?'` | An op carrying `?` is dropped, as before this round. A1's criterion 4 is reworded (F3 below). |
| A6 | Q17 | After a set-aside `splitActual`, put the first block back in hand | Where the client holds the record of the block the split was cutting, the grid shows that block again and STOP can end it. Where it does not, the grid is idle. D3's criterion 4 is reworded (F6 below). |
| A7 | Q8 | The strip's three mark buttons reach 44x44, and A4's rule covers them | Every interactive control in the posture row meets the floor, whether the strip is showing or hidden. |
| A8 | Q13 | Opening SPLIT clears an armed category | No armed label survives into a sheet, so no label promises an action the next tap will not take. |
| A9 | Q6 | `buildTitle_` writes the bare `UNLOGGED` form when there is no text | `"UNLOGGED ?"` and `"UNLOGGED -"` round-trip byte-identical, making contract 18 true as written. |

## B. Code changes the review found

| # | Finding | Change | Criterion to write first |
|---|---|---|---|
| B1 | 1 | `sitting %` counts only the sitting time inside the waking span | On a forgotten-STOP day the percentage is never above 100. `sitting h` keeps the true total. A day with no waking span still leaves the cell blank. |
| B2 | 8 | An armed STOP does not cover the posture button | While STOP is armed, a tap at the posture button's coordinates cancels the arm and does not end the day. The armed label still differs in text and styling and still fits. |
| B3 | 9 | The banner names an open block the app cannot read | With such a block open, the message bar says so and names the title. The grid keeps its running look, because a block really is running. |
| B4 | 10 | A close does not move an end time the user set | A second close of an already-closed block leaves its end alone. A close may still replace an end that carries `?`, because that end is the app's own guess. |
| B5 | cosmetic | The set-aside banner counts what it set aside | With four writes set aside the message says four, not one. |

## C. Corrections of fact — no decision needed

| # | What is wrong | Where |
|---|---|---|
| C1 | *"so that formulas pointed at the columns already there keep working"* — false; 19 pre-round columns moved | `SETUP.md` |
| C2 | *"point formulas at `daily!A:Z`"* — the tab is 65 columns wide | `SETUP.md` |
| C3 | STOP is documented nowhere, and `?` is used but never defined. The note-character rule (A4 above) is also undocumented | `README.md`, `SETUP.md` |
| C4 | *"Exactly one pre-existing test assertion has been removed all round"* — six lines changed, in four commits, and the drawer one is disclosed nowhere | `factory/progress-2.md` |
| C5 | *"nothing parked, no circuit breaker fired"* and *"two criteria are unmet"* — one fired, and three are unmet | `factory/progress-2.md` |

## D. `switches` counts events the user did not switch to

The forgotten-STOP day reports three switches for two taps, because `UNLOGGED`
and `UNFILED` events are counted. Criterion: `switches` counts only blocks that
began with a user action. Listed separately because it changes a number that
already exists, like A2 and B1.

## E. Rewordings — the human approved each

| # | Document | What changes | Ruling |
|---|---|---|---|
| F1 | contract 20 | which columns may move | Q14 |
| F2 | contract 22 | what a guessed block does to the waking span | Q9 |
| F3 | A1 criterion 4 | `validOp_` refuses `?` | Q4 |
| F4 | A1 criterion 6 | how `?` is parsed | Q1 |
| F5 | D2 criterion 4 | what `week of` holds | Q16 |
| F6 | D3 criterion 4 | the grid after a set-aside split | Q17 |

`factory/HANDOFF-2.md` is not edited. The amendments live in
`factory/progress-2.md` under `## CONTRACT AMENDMENTS`, each naming the ruling
that authorised it.

---

## Done means

Every item above implemented and verified by running it; `node test/tests.js`
green twice in a row and under all four contracted timezones; `node test/lint.js`
all clear; `node test/headless.js` ok at both viewports; `appsscript.json` and
`test/fixtures/rollup-golden.json` still byte-identical to `a256bdf`; and the
three reviewers' two blocking findings re-run by hand and shown to be gone.
