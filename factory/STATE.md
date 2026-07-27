# Factory State
project: timetap
stage: 6
stage_name: Fresh-eyes review (of the fix pass)
last_updated: 2026-07-27 07:00
next_action: Run /factory-review once more, in a NEW context, on the fix diff only (the last commit). The fixes were written by the same agent that found the findings, so they have not been independently checked — that is the one gap left. If that review comes back SHIP, stage 7 is the proof video with auto-loom-proof.
notes: |
  Round complete and fixed. Two documents carry the history: factory/REVIEW.md is the
  independent review as written (left unedited — it is the record of what was true
  before the fix), and the FIX PASS SUMMARY at the top of factory/progress.md is what
  changed afterwards.

  THE HUMAN'S THREE DECISIONS, ruled 2026-07-27, recorded as amendments A1-A3 under
  "Contract amendments" in factory/HANDOFF.md:
    A1. D2's criterion 6 is RETIRED, not met — no check in smoke.js is
        viewport-sensitive (verified twice: no metas at all still passes all 17 at a
        980px layout). Replaced by the layout-width control, 390 vs 980.
    A2. Contract item 6 corrected from one OAuth scope to three. The manifest was
        never wrong and is still byte-identical to main; the sentence was.
    A3. The rollup's invariant is per-tab honesty, AND a failed write must never blank
        a tab. Item 16 rewritten; assertions 24-27 added to the contract.

  HANDOFF.md has now been edited twice, both sanctioned: the Orientation Q&A block
  during the run, and these amendments by human decision. Nothing else in it changed.

  FIXES APPLIED (all five findings, plus the two cosmetic ones):
    F-1 the blocking data-loss bug. DISCARD arms then acts, reusing the app's own
        arm/confirm idiom rather than a timing guard — structural, so it holds however
        fast the taps are. Pinned by tier-1 37f/37g/37h/37i AND a real-browser
        double-tap at fixed coordinates in test/headless.js.
    F-2 both grids built before either is written; writeGrid_ writes then trims
        instead of clearing first. §39e's stub now breaks getRange rather than
        writeGrid_, which is why the loop's version could not see the blanking.
    F-3 NUL byte gone, plus a lint rule over every text file.
    F-4 progress.md's status line now matches its own table.
    F-5 README corrected, plus a lint rule comparing doc scope counts to the manifest.
    F-6 drawer refreshes while open; closing it leaves no rows behind.

  Every fix was vacuity-checked by reverting it in a fixture copy and confirming the
  new test fails. Details per finding in factory/log.md.

  VERIFIED AFTER THE FIX: 492 assertions (was 459), green twice in a row under all
  four timezones. lint all clear, 17 rules. headless green at both viewports plus the
  new drawer phase. deploy.sh re-exercised with a stub clasp first on PATH — nothing
  pushed, real binary never invoked. Golden rollup fixture untouched and still
  byte-identical in all four zones.

  WHAT IS STILL UNCHECKED: the fixes themselves, by anyone other than their author.
  That is why next_action is another review rather than the video.

  Plan explained to user 2026-07-26 (GUIDE.md Part 1, post-office scene).
  Build explained 2026-07-27 (GUIDE.md Part 2, same scene). Part 2 predates this fix
  pass — it describes the double-tap bug as open. Worth a short Part 3, or an edit to
  Part 2, once the fix has been independently reviewed.

  Product law still intact: nothing built or fixed this round interprets, scores or
  advises. "TAP AGAIN TO DISCARD" states what the next tap will do and stops.
