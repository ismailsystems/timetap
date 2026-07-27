# Factory State
project: timetap
stage: 5
stage_name: One more loop pass (fix list from review 2)
last_updated: 2026-07-27 (review 2)
next_action: Run factory/FIXES-2.md as one loop pass on branch factory/error-paths. Five items, all small — a comment and a tier-3 check (F2-1), two lint rules widened to match their own assertions (F2-2, F2-3), a crash turned into a named skip (F2-4), and a stale parked question (F2-5). Then stage 6, a third fresh-eyes review, which should be short. Then stage 7, the proof video with auto-loom-proof.
notes: |
  REVIEW 2 (2026-07-27), fresh context, on the fix pass — verdict FIX FIRST.
  Written to factory/REVIEW-2.md. factory/REVIEW.md is round 1, left unedited.

  WHAT ROUND 2 CONFIRMED, by breaking the code at points it chose itself rather
  than the ones the suite uses:
    - The double-tap data loss is genuinely gone. Real Chromium, real coordinates:
      two taps at one point remove exactly the entry aimed at. Arm/confirm survives
      a late second tap, a drawer close and reopen, and a re-render underneath it.
    - The rollup's per-tab honesty holds at three independent failure points
      (second tab's write, first tab's write, grid build). No tab blanked, no stamp
      newer than its own numbers, the two stamps visibly different after a partial
      failure.
    - 492 assertions green TWICE under all four contracted timezones. lint 17 rules
      clear. headless green at both viewports. All three deploy.sh gates block and
      the stub clasp is never called.
    - Amendment A1's factual basis re-verified independently: with no meta tags the
      page lays out at 980px and all 17 smoke checks still pass, 0 fail.
    - HANDOFF.md contains only the three sanctioned amendments. No tampering.
    - No secrets, no stubs, no out-of-scope files, one pinned dev dependency.

  FIX LIST (findings 2-5 need no decision):
    2. The NUL-byte lint rule covers 14 named files, not "any file in the repo" as
       assertion 26 says — a NUL appended to factory/log.md passed lint, exit 0.
       Drive the rule off the tracked file list instead.
    3. The scope-count rule reads README.md and SETUP.md only; factory/BRIEF.md:71
       and factory/PLAN.md:33 still say "one OAuth scope" and pass.
    4. test/tests.js crashes (TypeError at 39d) instead of skipping in any timezone
       outside the contracted four — verified in Asia/Kolkata and Pacific/Chatham.
    5. progress.md's "Parked questions" section still reads as an open question
       that amendment A1 already answered.

  THE ONE DECISION, RULED 2026-07-27 — Option A. Assertion 24's second sentence
  ("discarding a row must not move another row's controls into the space it vacated")
  described a mechanism the build does not use. Rows do still move; arm/confirm is
  what makes that safe, and it is verified holding at 2, 3, 4 and 6 taps — every
  destruction preceded by a button reading TAP AGAIN TO DISCARD. Recorded as
  HANDOFF amendment A4, with assertion 24 rewritten in place. Freezing the layout was
  considered and rejected: it puts an empty gap on screen, which is furniture that
  says something the app has not decided to say.

  Fix list written to factory/FIXES-2.md, with factory/review-repro-2/tap-count.js as
  a working harness for F2-1's tier-3 check (currently green, and it is the loop's job
  to prove it goes red when arm/confirm is reverted).

  Round 1 history, unchanged below.

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
