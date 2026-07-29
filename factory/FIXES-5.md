# Fix list 5 — after review 5

compiled: 2026-07-29 · branch `main` · source: `factory/REVIEW-5.md`

**Start here.** Read `factory/REVIEW-5.md` first — it holds the reproductions, and
every one of them was reproduced twice: once by the reviewer who found it and once
by hand in a clean clone before it was written down. The design contract is
`~/Downloads/design_handoff_dayrail_redesign/README.md` plus the prototype.

**Operating loop**, the same one this project has used three times: one item at a
time; write its criterion before its fix; watch the criterion fail; fix it; watch
it pass; then put the fix back the wrong way round and watch the criterion fail
again, because a criterion that stays green through the revert is not a criterion.
Commit each item. Keep the suite green under all four contracted timezones. Never
point a test at a real calendar.

**State when this was written:** 1162 assertions green twice under all four
contracted zones, lint clear on 20 rules, headless ok at both viewports with 30
smoke checks each — and green at every hour of the day, which it was not before.
`main` is **not deployed**; the live app is version 30, the pre-redesign build.

---

## Closed already — the three that blocked

These are done, verified, and committed. They are listed so the next reader knows
what the review's letters refer to.

| # | Fix | Commit |
|---|---|---|
| C1 | Undo threw the sitting away when the writes were still queued. The sitting the user restarts joins the undo's all-or-nothing set; where it cannot be dropped, the one compensating op deletes it through a new `killSitRef`. | `23dcc6e` |
| C2 | `node test/headless.js` was red for the first ten hours of every local day, and `deploy.sh` stops on it. The rail fixture pins the page clock. The same commit fixes the off-by-one in its own guard. | `7c63226` |
| C3 | A sheet could act on a block it was not about, billing 21 minutes twice; and the sheets were not modal, so a keyboard user reached the app behind them. `split.ref` guards the write; `inert`, focus management and `Escape` make the sheets modal. | `8253299` |

Two more closed on the way. **Should-fix 2** — an undo closing a sitting that
predated the switch — went by deletion: the human ruled that a category tap has no
implications for the posture, so the Body↔sitting coupling is gone on all four
paths and `BODY_KEY` with it. `STOP` keeps its coupling, because it ends the day
rather than choosing a category. That deviates from a design contract the human
accepted, deliberately, and is recorded where a reader meets it. **Should-fix 8**
and **9** are closed by the documentation pass that produced this file.

---

## A. Correctness — the record says something the calendar does not

| # | Fix | Criterion to write first |
|---|---|---|
| A1 | When `opUndoSwitch_` declines the whole undo — another device moved or closed the block — the client must find out. `flush()` never re-reads state on success, and `refreshOnReturn` needs ten minutes *and* a visibility change. | Another device closes the mis-tapped block, then UNDO: within one round trip the screen stops claiming a running block, or says it cannot tell. Today it reads `Deep work · 1h30` fifty minutes later against a calendar that ended at 09:40, with the header on `SYNCED`. |
| A2 | `railReopen` matches on `ref`; `getState`'s `today` rows carry only `key`, `startMs`, `endMs`. Once `adoptServerState` has replaced `S.today` the row cannot be found. | A state refresh lands between a switch and its undo: the rail draws three segments for three calendar events, not four. Today it draws the reopened block twice and overstates the day by its duration. |
| A3 | `dropOps`' all-or-nothing rule is asserted nowhere. Weaken `if (hit < n)` to `if (!hit)` and 1162 assertions still pass, while the state it guards is reachable — `applyOps` stops at the first failing op, so a close can land while its open stays queued. | The mutation fails at least one named assertion. The reachable half-landed state is driven, not argued: server refuses `openActual` only, then UNDO. |

## B. Reach and accessibility

| # | Fix | Criterion |
|---|---|---|
| B1 | Both sheet sliders are bare `<input type="range">` — no name, no readable value. A screen reader says `slider, 344` where the screen says `4:45 AM`. `#sitEdit`'s `aria-label` likewise overrides the `1h01` inside it, and the three mark buttons are announced as `+`, `=`, `−` with no link to `#stripHead`. | Every slider and every mark button has a name and a value a screen reader can read, checked against a real accessibility tree in `smoke.js`. The sit chip announces its duration. |
| B2 | At ten categories `#grid` scrolls and nothing says so: no fade, no mask, no persistent scrollbar, and `grep -c scrollIntoView Index.html` is 0. With category 10 running, the app opens with nine rows and none of them lit, and the row you would re-tap to reach SPLIT is not on screen. | At 10 categories with a block running, the running row is on screen after load, or the list says it continues. The guardrails stay where A2 put them — the list gives way, not the ribbon. |
| B3 | **Decision first.** The reflex double tap on a row just switched to opens SPLIT, and `openSplit` clears the undo by design. Round 1 taught users to double tap. REVIEW-4's finding 17, which FIXES-4 did not carry. | Whatever is chosen is stated in a comment and pinned by a test. |

## C. The tests' own honesty

| # | Fix | Criterion |
|---|---|---|
| C1 | D2's fix has two halves — the share cap and the total scaling — and either alone still passes. Only both gone turns the phase red. Nothing pins `railBudget()` either: returning the old constant leaves the rail drawn at 609.8px in a 758px column, and everything green. | A mutation to either half alone, and to `railBudget`, each fails a named check. Likely needs a claim about the rail FILLING its column, not only fitting inside it. |
| C2 | `headless: ok (30 checks per viewport)` prints when 28 ran and 2 skipped. The total is verified against the file, so nothing can vanish — but the line overstates what happened and the skips are never named. | The line says what ran, what skipped, and which. |

## D. Cosmetic

| # | Fix |
|---|---|
| D1 | **Closed by decision.** `1` is the last actionable second. At expiry the ribbon disappears; it does not show `0` beside an undo that is no longer available. The floor is stated beside `paintUndo` and section 66e pins both the source and the boundary. |
| D2 | **Fixed.** `validOp_` now permits `null` explicitly as an absent optional reference, while requiring every present reference to already be a string. Section 66q pins both sides of that rule. |
| D3 | `#postureRow` carries `cursor: pointer` and has no click listener. The design's *"Row tap toggles sitting"* is not implemented — safer than the alternative, but the cursor is a lie. |
| D4 | `#spGridLab` renders `REMAINDER IS`; the handoff says `REMAINDER BECOMES`. The markup has it right and `setSplitScope` overwrites it. |
| D5 | The note box is 354×38 — six pixels under the 44px floor, and the only control that is. |
| D6 | Past midnight the same block reads `2h30` in the NOW panel and `1h30` on the rail. Both are correct; nothing explains the pair. |
| D7 | The undo ribbon moves 38px up when the error banner is present, so where UNDO appears depends on whether writes are set aside. |
| D8 | Focus drops to `BODY` when the ribbon expires under it. One Tab recovers. |
| D9 | The Add row is clipped out of the scrolling grid while the mark strip is up, and returns when the strip dismisses. |

## E. Older than this round, recorded so they are not found again as new

Reproduced, real, and present at `2a15553`. Not caused by the FIXES-4 pass, so
they were not counted against it — but they are live.

| # | Fix |
|---|---|
| E1 | A reload with an undrained queue empties the rail: four segments before, one after, and coming back online does not restore it, because `flush()` success never re-reads state. Fixing A1 may fix this too. |
| E2 | `opCloseSit_` has no already-closed guard, unlike `opCloseActual_`. Once the screen has diverged, standing up stretches a closed SIT block — `09:00-09:50` became `09:00-12:50`. |

## F. The record

| # | Fix |
|---|---|
| F1 | `factory/GUIDE.md` Part 2 describes the round-1 double-tap bug as live; Part 3 corrects it. The explain stage has owed that a proper repair since round 1. |
| F2 | `test/smoke.js` gained eight checks across the Day Rail rounds and has never been pasted into a phone console since. Two of the three bug classes it exists for only ever appeared on the handset. |

---

## Done means

Every item above implemented and verified by running it; the suite green twice
and under all four contracted timezones; lint clear; headless ok at both
viewports **and at an hour before 10:00 local**, which is the check C2 bought;
`appsscript.json` and `test/fixtures/rollup-golden.json` still byte-identical to
`a256bdf`; and the reproductions in `REVIEW-5.md` re-run by hand and shown to be
gone.

Then a sixth review, or a deploy. Both are the human's call, and neither has
happened. Check the spreadsheet formulas note in `factory/STATE.md` before
deploying — it still holds, because nothing since has moved a column.
