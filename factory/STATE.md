# Factory State
project: timetap
stage: 7
stage_name: Proof video (stage 6 skipped by human decision)
last_updated: 2026-07-27 (fix pass 2 complete; third review declined)
next_action: "Stage 6 SKIPPED — the human declined the third fresh-eyes review on 2026-07-27, satisfied with fix pass 2. Fix pass 2 therefore stands self-checked only; its author is the only thing that has verified it. Before or instead of stage 7: factory/GUIDE.md Part 2 is now WRONG, not merely stale — its section \"The one thing that is broken, in plain words\" describes the double-tap data loss as a live bug and proposes a fix (remove one card instead of redrawing) that is not the fix that shipped and would not have been sufficient alone. The build uses arm/confirm. Fix that before anyone reads it. Also outstanding: branch factory/error-paths is 19 commits ahead of main, nothing pushed, main untouched at 0ad0214 — the round is not merged."
notes: |
  FIX PASS 2 COMPLETE (2026-07-27). All five items in factory/FIXES-2.md done,
  five commits, nothing parked, nothing escalated, no questions for the human.

    F2-1 Index.html's discardDead docblock claimed "the list is NOT redrawn…
         Nothing may move while a finger is down" — the second half is false, rows
         do slide up. Rewritten per amendment A4 to name the guard the build has:
         arm/confirm. factory/review-repro-2/tap-count.js folded into
         test/headless.js as a checkTapCount phase and deleted from factory/.
         Measured 1, 1, 2, 3 destroyed at 2, 3, 4, 6 taps — A4's table exactly —
         with every destruction preceded by TAP AGAIN TO DISCARD under the finger.
    F2-2 NUL rule now drives off git ls-files (or a walk with no .git) instead of
         14 hand-written paths. Binary files get a named exemption, never an
         extension filter; an unreadable file is a failure, not a silent skip.
    F2-3 factory/BRIEF.md:71 and factory/PLAN.md:33 corrected to three scopes; the
         rule widened from two files to every .md, with eight record files exempt
         by name and reason. HANDOFF.md is on that list and is the weakest entry —
         flagged in the comment rather than left to be found.
    F2-4 §39d skips by name instead of crashing outside the four contracted zones.
         Harness gained skip(), mirroring smoke.js. A skip is never counted in
         passed; the summary prints ", 1 skipped" and lists it.
    F2-5 progress.md's parked question marked ruled (A1) with its original text
         kept, plus four more places in the file that read as open.

  TWO THINGS FOUND WHILE FIXING, BOTH FIXED IN PLACE:
    - .gitignore's `node_modules/` does not match a symlink pointing at a
      directory, so a symlinked checkout handed the whole tree to the new NUL rule
      (EISDIR). Non-regular files are now skipped out loud.
    - §39d's old "there is a golden for this timezone" check could not survive as
      written without becoming an assertion that cannot fail. Replaced by one that
      can (the golden holds a non-empty grid for both tabs), vacuity-checked.

  VERIFIED: 492 assertions green TWICE under all four contracted timezones — the
  count is deliberately unchanged, F2-4's criteria require it. lint all clear, 17
  rules. headless green at both viewports plus the drawer and tap-count phases.
  deploy.sh re-exercised in a fixture copy with a stub clasp first on PATH: all
  four failure gates (lint, suite, headless, missing browser) exit non-zero with
  zero clasp calls, --no-test still deploys, and the happy path reached the push
  step calling only the stub. appsscript.json byte-identical to main, golden rollup
  fixture untouched, Code.gs untouched, Index.html changed in comments only.

  WHAT IS STILL UNCHECKED: fix pass 2, by anyone other than its author.

  Review 2 history, unchanged below.

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
