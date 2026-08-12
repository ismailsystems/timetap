# Fix list 6 — after review 6

compiled: 2026-07-29 · branch `main` · source: `factory/REVIEW-6.md`

**Start here.** Read `factory/REVIEW-6.md` first — it holds the reproductions.
Each blocking fault was reproduced twice: once by an independent reviewer, once
by hand by the orchestrator who assembled the file. The design contract is
`~/Downloads/design_handoff_dayrail_redesign/README.md` plus the prototype.

**Operating loop**, the same one this project has used: one item at a time; write
its criterion before its fix; watch the criterion fail; fix it; watch it pass;
then put the fix back the wrong way round and watch the criterion fail again.
Commit each item. Keep the suite green under all four contracted timezones.
Never point a test at a real calendar.

**State when this was written:** 1183 assertions green under all four contracted
zones, lint clear on 21 rules, headless ok at both viewports with skips named,
goldens byte-identical to `a256bdf`. The redesign is live on the phone; one
redeploy is still owed to drop the temporary smoke injection from the live
project (human call — not an item below).

---

## A. Correctness — the screen says something the calendar does not

| # | Fix | Criterion to write first |
|---|---|---|
| A1 | When `opUndoSwitch_` declines the undo and `flush` asks for a state read, any local write during that round trip (posture, STOP, category) must not cancel the repair forever. Today `adoptServerState` refuses the answer (`gen !== localGen`), `lastStateMs` still advances, and nothing re-reads — the screen claims the previous block against zero open ACTUAL events until a visibility change after ten stale minutes. Same shape as `stateAfterBootDrain`: remember that a corrective read is owed, re-issue once the queue drains with no newer local write pending, and do not advance `lastStateMs` on a read that was thrown away. Closing this also closes the A2 rail-duplication inheritance that rests only on that read. | Another device closes the mis-tapped block, then UNDO, then a posture tap (or STOP, or another category) while `getState` is still in flight (`H.setCallLag('getState', 800)`): within one round trip **after the interleaved write's queue drains**, the screen stops claiming a running block, or says it cannot tell. Drive the posture path and at least one other enqueue path. The quiet path (no interleaved write) must stay green. A mutation that drops the after-drain retry, or that advances `lastStateMs` on a refused adopt, must fail a named check. |
| A2 | **Decision first (review item 2).** D9's `revealAddRow()` in `showStrip()` scrolls the category list 78–190px under the finger at 7–9 categories the moment a ≥15-minute switch raises the mark strip. A reflex second tap at the same point switches again (or hits a mark button). Three options: (1) drop `revealAddRow` from `showStrip` and let Add clip while the strip is up, as at `89058d2`; (2) keep the scroll but ignore grid taps for ~300ms after a switch (same shape as B3's running-row guard); (3) reserve the strip's height in the layout so showing it moves nothing. Recommendation: (3) if cheap, else (1). Add does not earn a mis-switch. After the human picks, write the criterion, fail it, fix it, mutate it. | At 7 categories on a real 390×844 layout with touch (headless or Chromium), restore a 40-minute open block, aim at another row's centre, tap twice ~100ms apart: the second tap must not switch to a third category and must not apply a mark to the closed block. Measure `scrollTop` / `elementFromPoint` if the chosen repair is about movement. The Add-visible claim D9 bought must either still hold or be deliberately retired in the same commit with a stated reason. A DOM-shim double-tap with no layout (section 62) is not this criterion. |

## B. The tests' own honesty

| # | Fix | Criterion |
|---|---|---|
| B1 | Headless (and any phone smoke paste) skips both lit-row checks whenever the page is idle. F2 corrected the inset-4px assertion but never ran it against a running row on the handset; the second phone paste was `29/0` with two skips. Seed a running block on the cold-load path that is supposed to prove the lit edge, so those checks run rather than skip. | `node test/headless.js` at both viewports runs the two lit-row checks (they appear in `passed`, not only as named skips). Reverting the smoke assertion to forbid `inset` fails them. Idle-only pages may still skip; the path that claims to pin Day Rail's edge must not be idle. |

## C. Older than this round — recorded so they are not found again as new

Reproduced, real, and present at `89058d2`. Not caused by FIXES-5, so not
counted against it — but live.

| # | Fix |
|---|---|
| C1 | **Decision first.** A reflex second tap after STOP lands on the posture control (STOP has gone) and opens a SIT block. Byte-identical before this pass. B3 took on the category-row reflex; this is the same reflex on the one control with nothing after it to undo. Fix it, or leave it and write why Ruling 2's stated cost is the answer. Recommendation: ignore posture taps for a short window after STOP, or move posture so it is not under the same point — put the choice to the human. |
| C2 | **Decision first / cheap.** At ten categories, B2's "running row on screen" branch holds when the restored block is in row 10, but `#grid` still has no mask, fade, scrollbar, or aria cue that the list continues. When the running block is in row 1, rows sit off screen with no signal. Fix the cue, or say the "or the list says it continues" half of B2 is deferred. |

---

## Done means

Every item above implemented and verified by running it (or consciously deferred
in a commit that says so); the suite green twice under all four contracted
timezones; lint clear; headless ok at both viewports **and** the lit-row checks
actually run on a seeded path; `appsscript.json` and
`test/fixtures/rollup-golden.json` still byte-identical to `a256bdf`; and the
reproductions in `REVIEW-6.md` re-run by hand and shown to be gone.

Then a seventh review, a redeploy, or daily use. All are the human's call.

---

## Kickoff paste

See `factory/FIXES-6-PROMPT.md`.
