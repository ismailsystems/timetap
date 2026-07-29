# Fix list 4 — the Day Rail redesign, after review

compiled: 2026-07-28 · branch `main` · source: `factory/REVIEW-4.md`

**Start here.** Read `factory/REVIEW-4.md` first — it holds the reproductions.
The design contract is `~/Downloads/design_handoff_dayrail_redesign/README.md`
plus the prototype, extracted and readable at
`scratchpad/prototype-2a.html` (section 2a from line 555; runtime values
1267–1376; the rail's geometry in `rail()` near 1143).

**Operating loop**, the same one this project has used twice: one item at a
time; write its criterion before its fix; verify by running it; commit each
item; keep the suite green under all four contracted timezones. Never point a
test at a real calendar.

**State when this was written:** 970 assertions green, lint clear, headless ok
at 21 checks per viewport. `main` holds the redesign and is **not deployed** —
the live app is version 30, the pre-redesign build. Nothing broken here is on
anyone's phone.

**Three decisions are open** — REVIEW-4's "Decisions for you". B5 in particular
should be settled before it is built.

---

## A. Blocking — the redesign does not ship without these

| # | Fix | Criterion to write first |
|---|---|---|
| A1 | `dropOps` must refuse to drop while a flush is in flight, exactly as `mutatePendingOpen` does. When it cannot drop, `takeUndo` must send the compensating op instead. | With a lagged `applyOps` (`H.setCallLag`), a switch followed by UNDO leaves the calendar with the ORIGINAL block open and no trace of the new one — at 100, 600, 1200 and 2500 ms round trips. The screen and the calendar agree after a reboot. |
| A2 | The undo ribbon and the mark strip must stay on screen at every category count up to `MAX_CATEGORIES`. | At 6, 7, 8 and 10 categories, at 390×844: the ribbon's hit box is fully on screen, at least 44px tall, and `elementFromPoint` at its centre returns the ribbon. The same for each mark button. |
| A3 | Undo restores the sitting it closed, on both the switch path and the STOP path. | Sitting, then a mis-tap on BODY, then UNDO: the SIT block is open again with its original start, and the footer says SITTING. Same after STOP + UNDO. |
| A4 | Undo into BODY closes an open SIT, as every other path into BODY does. | BODY running → switch away → sit → UNDO: BODY is open and no SIT is open. This is the deleted `50g`, rewritten for the successor path. |
| A5 | **Decision first (REVIEW-4, decision 1).** If the handoff is followed: STOP closes at once and the ribbon offers `STOPPED — NOW UNLOGGED`. | One tap on STOP ends the day. The ribbon appears. No `TAP AGAIN` state exists. Undo restores the block AND the sitting. |

## B. Correctness

| # | Fix | Criterion |
|---|---|---|
| B1 | `opUndoSwitch_` reopens the previous block only if it deleted the new one. | With another device having closed or moved the new block, undo leaves exactly one open block on the calendar — never two. |
| B2 | `doSplit` calls `railClosed` for the half it closes. | After a split, the rail shows both halves and no gap between them. |
| B3 | `paintRail` handles overlapping blocks without inventing a gap. | Blocks 9:00–11:00, 9:30–10:00 and 11:00–11:30 draw no hatched segment. |
| B4 | `S.today` is not persisted and does not grow without bound. | `tt.state.v1` has no `today` key. 120 offline switches leave the stored state under 2KB. |
| B5 | The set-aside drawer tells the truth about an undo write. | A set-aside `undoSwitch` shows its real start time, plain words rather than the op name, and clears the grid the way a set-aside open does. |
| B6 | STOP + undo drops its write when it is still queued. | Offline: STOP then UNDO leaves no `undoSwitch` in the queue. |

## C. Copy and type — the handoff calls these final

| # | Fix | Criterion |
|---|---|---|
| C1 | Route the four remaining sites through `faceOf()`: SPLIT kicker, SPLIT sub-copy, the mark strip, the set-aside row. | No screen shows a raw category key. `OPEN BLOCK · DEEP WORK`, `20m stays DEEP WORK · 23m becomes ↓`, `DEEP WORK · 43m — MARK IT`, `4:52 PM · MEETINGS`. |
| C2 | Make `.tnum` survive. Every rule that sets the `font:` shorthand resets `font-variant-numeric`; put the shorthand first, or stop using it on those elements. | Computed `font-variant-numeric` is `tabular-nums` on every element carrying `.tnum` — the NOW elapsed, the row clocks, the rail durations and start, the sit chip, both sheet clocks, the slider ends. |
| C3 | SPLIT lists every category except the running one. | With Deep work open, `#splitGrid` has five rows and none of them is Deep work. |
| C4 | The mark strip label fits, or truncates deliberately at a stated width. | At 390×840 with the longest configured name, the label is fully readable or ends in an explicit ellipsis, and the three buttons stay 44×44. |
| C5 | `SET ASIDE · n` carries its count. | With two set aside, the sheet title reads `SET ASIDE · 2`. |
| C6 | The SIT sub-copy reads `sitting for 16m if applied`. | Byte-exact against the spec string. |

## D. Reach, layout and accessibility

| # | Fix | Criterion |
|---|---|---|
| D1 | The undo ribbon is operable from a keyboard and announced: `role`, `tabindex`, Enter/Space, and `aria-live` so it is heard when it appears. | It is in the tab order; Enter takes the undo; a screen reader is told the ribbon appeared and what it will undo. |
| D2 | The rail fits its box at any block count. | 40 blocks in one day: the rail's last segment and `NOW ▲` are on screen at 390×844, the page does not scroll, and the category column stays visible. |
| D3 | A dead zone between the ribbon and the footer, or an undo for posture. | A tap 4px below the ribbon does not toggle sitting. |
| D4 | **Decision first (REVIEW-4, decision 3).** The Add row's position. | Whatever is chosen is stated in a comment and pinned by a test, so the rule is enforced rather than merely written down. |

## E. Tests the deletions left behind

| # | Fix | Criterion |
|---|---|---|
| E1 | The sweep, rewritten for undo (was `50f`). | For every whole second from 0 to 120, one tap on a different category never changes an existing block's key. |
| E2 | A note may only title the running block (was "an unlit box cannot write a note"). | Typing with nothing running queues nothing and writes nothing. |
| E3 | `test/harness.js` `INIT_CLS` gains `undo: 'hidden'`. | After `reboot()` with nothing switched, the ribbon reads as hidden. |
| E4 | Correct section 66's claim. | It says which arm/confirm assertions have successors and which do not, or the sentence goes. |

## F. Housekeeping

| # | Fix |
|---|---|
| F1 | Delete the dead code: `arm()`, `willRetitle()`, `confirmLabel()`, `CONFIRM_RETITLE/SWITCH`, `armed`, `colsFor()`, `layoutCells()`, `#syncN`. |
| F2 | Retire the lint rule pinning the correction window, and stop shipping `mistapSeconds`/`confirmWithinSeconds` to a client that no longer uses them. `MISTAP_SECONDS` stays — the server still uses it in `staleGuard_`. |
| F3 | Give the rail a text equivalent so "hatched means unlogged" is not carried by colour alone. |
| F4 | Cosmetics from REVIEW-4: the midnight rail, `0m` blocks, the chip that never shows `0`, the mark discarded by undo, `pump()`'s discarded return. |

---

## Done means

Every item above implemented and verified by running it; the suite green twice
and under all four contracted timezones; lint clear; headless ok at both
viewports; `appsscript.json` and `test/fixtures/rollup-golden.json` still
byte-identical to `a256bdf`; and the four blocking reproductions in REVIEW-4
re-run by hand and shown to be gone.

Then, and only then, deploy — and check the spreadsheet formulas note in
`factory/STATE.md` still holds.
