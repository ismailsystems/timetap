# Factory State
project: timetap
stage: 7
stage_name: Built, reviewed, fixed and verified — waiting on the human to accept and deploy
last_updated: 2026-07-28 (round 2 complete)
next_action: "THE HUMAN ACCEPTS AND DEPLOYS. The work is 25 commits on factory/honest-record; main is untouched at a256bdf and nothing has been pushed. Read factory/REVIEW-3.md, above all its 'Decisions for you' — all five are answered and the answers are in progress-2.md. Then merge, deploy, and CHECK YOUR OWN SPREADSHEET FORMULAS: D1 added a rollup key, which moved 13 of the 22 columns the daily tab had. SETUP.md says which, and shows a formula that survives the next change. Optional and offered, not done: the proof video (auto-loom-proof) and the plain-language explainer (factory-explain, which also owes GUIDE.md Part 2 a correction carried over from round 1)."
notes: |
  ROUND 2 IS COMPLETE. 16 of 16 tasks, then a three-reviewer review, then a
  26-item fix pass, then an independent verification of that fix pass.

  WHERE IT ENDED: 994 assertions / 0 failed, green twice and under all four
  contracted timezones; lint all clear on 21 rules; headless ok at 20 checks per
  viewport across 7 phases. appsscript.json and test/fixtures/rollup-golden.json
  byte-identical to a256bdf. Baseline at the start of the round was 492.

  THE REVIEW (factory/REVIEW-3.md) returned FIX FIRST. Three reviewers, none
  given factory/log-2.md, one on a different model. 28 of 31 contract assertions
  independently re-derived and holding; guardrails exact; 14 planted faults all
  caught. Two findings blocked: a forgotten-STOP day reported sitting % of 500,
  and SETUP.md claimed the columns had not moved when 19 of them had.

  THE FIX PASS (factory/FIXES-3.md) closed all 26 items and both blocking
  findings. An independent verifier reverted ten of the changes and watched each
  go red, and reconstructed both findings from scratch rather than running the
  suite. It returned INCOMPLETE — on the RECORD, not the code: a duplicate of a
  corrected false claim was still standing, and two numbers in a commit message
  were wrong. Corrected in 05f1d83 rather than amended, so the mistakes stay
  visible.

  WHAT THE HUMAN RULED, and where it lives: all 16 parked questions and the
  review's 5 decisions are answered, in progress-2.md under
  '## ANSWERS FROM THE HUMAN' and the review's own section. Six contract
  amendments are recorded under '## CONTRACT AMENDMENTS'; HANDOFF-2.md itself is
  untouched, as its guardrails require.

  KNOWN AND ACCEPTED, not defects to re-report:
    - 'week of' holds text, not a date value. It always did (Q16).
    - A day of nothing but guessed time reads waking h 0 beside a category
      column that is not 0. A span needs two known ends and that day has one.
      Test 56b pins it as a stated limit (Q9).
    - A '?' typed by hand into Google Calendar still reads as the app's guess.
      It follows from encoding the guess as a trailing mark (Q5).
    - A day whose STOP writes never reach the server still becomes a night
      block. The banner and the drawer say so (Q7).
    - A double tap on SITTING writes a 12-millisecond event, and an UNLOGGED
      block can span 25 hours. Both predate round 2.

  ONE ROUND-1 DEBT STILL OPEN: factory/GUIDE.md Part 2 describes the round-1
  double-tap bug as live and proposes a fix that is not what shipped. Part 3
  corrects it. The explain stage still owes that a proper repair.

  ---
  WHAT FOLLOWS IS THE ROUND-2 HANDOFF RECORD, written 2026-07-27, kept as the
  record of what was agreed before the work started. One paragraph pair that
  appeared twice ('HOW THIS ROUND WAS CHOSEN' / 'THE FINDING THAT DROVE IT') was
  duplicated in this file; the second copy is removed.
  ---
  ROUND 2 — "the honest record round". Brief: factory/BRIEF-2.md.
  Plan: factory/PLAN-2.md, 16 tasks in four stages, all criteria written.

  HANDED OFF 2026-07-27. factory/HANDOFF-2.md is the one self-contained file the
  loop obeys. factory/progress-2.md and factory/log-2.md created so the loop's
  first GATHER finds them. Branch factory/honest-record created off main at
  a256bdf and checked out. Round 1's progress.md and log.md are read-only and the
  handoff says so; round 2 writes the -2 files.

  PRE-FLIGHT, run before handing over: 492 assertions / 0 failed; lint all clear
  across 17 rules and 38 files; headless ok at 19 checks per viewport including
  the drawer and tap-count phases. One repo change made to get there —
  test/lint.js gained a ninth SCOPE_QUOTE_EXEMPT entry for factory/ROUND-1.md,
  which quotes "one OAuth scope" twice as historical record. That text was
  already exempt while it lived in STATE.md; archiving it moved the exemption
  with it. The rule was verified still live (false claim appended to BRIEF-2.md,
  lint failed by name, claim removed). NOT a weakening — but a reviewer should
  confirm that judgment rather than take it on trust.

  CIRCUIT BREAKERS SET: 3 failures parks a task, 3 parked tasks ends the run,
  hard cap 25 passes or 8 hours.

  PROOF DEFINED 2026-07-27. A 31-assertion contract at the top of PLAN-2.md,
  plus 6-10 acceptance criteria on every one of the 16 tasks, each tagged with
  a test tier and each naming an action and an observable. Every task carries at
  least one error-path criterion.

  FOUR THINGS IN THE CRITERIA THAT ARE LOAD-BEARING, and that a review should
  check are still honest rather than softened:
    - C1's SWEEP (contract 28). For every whole second 0-120, one unconfirmed
      tap on a different category must never change an existing block's key.
      The individual window tests all pass against any two different constants;
      only the sweep proves there is no reachable gap. Do not let it be replaced
      by spot checks at 10s/45s.
    - B2/B3's COLUMN INDEX assertions (contract 20). Existing column positions
      are a contract with spreadsheet formulas that live outside this repo and
      cannot be tested from inside it. Asserted against the golden fixture's
      header row; the fixture diff must show columns APPENDED with nothing
      moving. Flagged in B2 as a finding-and-stop if it fails against unmodified
      code, because today's code already has the property.
    - A5's GOLDEN comparison. It is what proves A5 changed the abnormal case
      (guessed/unlogged time) and left the normal one alone. Without it, "waking
      hours got smaller" is indistinguishable from "waking hours got broken".
    - THREE MANDATORY VACUITY CHECKS, written into the tasks: A1 (revert the
      regex, parse criteria must go red), A2 (revert ? to =, mark criteria go
      red while boundary criteria stay green — the separation is the point), and
      B5 (delete the sentence from each doc file ONE AT A TIME; a rule that only
      fires when both change is a rule that will not fire).

  THE GOLDEN FIXTURE CHANGES TWICE this round, in B2/B3 and again in D1. Both
  are expected and both are reviewable as diffs. Any other change to
  test/fixtures/rollup-golden.json is a finding.

  HOW THIS ROUND WAS CHOSEN. The user did not pick a feature; they asked to
  stress test the app's conceptual model first, to settle whether it is
  trustworthy and usable enough to adopt religiously. That stress test was run
  against Code.gs and Index.html directly on 2026-07-27 and found six things.
  The round is the fix list, not a feature.

  THE FINDING THAT DROVE IT: the app can transition but never end. closeActual
  is enqueued in exactly one place (Index.html:912) and is always paired with a
  new openActual. So every night the last block is extended to midnight by
  staleGuard_, marked "=", and is indistinguishable from a real block — and
  because UNLOGGED lands on the ACTUAL calendar, every day's waking span starts
  at 00:00, which makes both waking h and sitting % measure nothing.

  THE SEVEN DECISIONS THE USER RULED (all in BRIEF-2 "Decisions made"):
    1. All six findings this round, staged. ~16 tasks, above the 9-12 round 1
       showed one night finishes cleanly. Knowingly accepted; stage boundaries
       are what make a partial night survivable.
    2. Finding 1 gets BOTH halves — an explicit STOP and honest labelling of
       what the guard invents.
    3. A guessed end is a fourth mark, "?", in the existing mark slot. Chosen
       over a hidden #unbounded description token (invisible in the calendar,
       the one place it matters) and over a separate UNBOUNDED event (needs a
       split point the app has no evidence for).
    4. Mark columns are per category per mark, APPENDED after every existing
       column. Appending is load-bearing — README tells readers to point their
       own formulas at these tabs.
    5. The tap windows nest: MISTAP (20s) inside CONFIRM (60s), pinned by a lint
       rule, and the armed button states which outcome the next tap produces.
    6. STOP lives in the POSTURE ROW. The user chose this over a grid cell and
       over a long-press, after both costs were put to them. Not to be reopened;
       A4 exists to solve them.
    7. STOP closes the open block AND any open SIT, opens nothing, and shows the
       mark strip — ending a block is a close.

  FIVE ASSUMPTIONS STATED RATHER THAN ASKED (BRIEF-2 "Assumptions"). The user
  was shown all five and did not object. Flag if any turn out wrong:
  whole-block recategorise reuses the existing SPLIT sheet; "?" is written by
  the stale guard only; the PLAN parse count surfaces in the editor not the
  grids; MISTAP starts at 20s; guessed and unlogged spans stop extending waking.

  THE ONE THING PARKED FOR REVIEW TIME: A5 changes what waking h means, so days
  before and after this ships are not comparable and nothing in the sheet says
  so. Whether the column gets renamed to force the issue is a decision for
  stage 6, not for the loop.

  CARRIED FORWARD FROM ROUND 1 (full record in factory/ROUND-1.md):
    - Fix pass 2 was never independently reviewed. Stage A touches staleGuard_
      and stage C touches the arm/confirm idiom, both fix-pass-2 territory.
      Verify rather than assume.
    - factory/GUIDE.md Part 2 still describes the round-1 double-tap bug as live
      and proposes a fix that is not what shipped. Part 3 corrects it, five
      inline markers point there, but a reader who skips them gets the wrong
      story. This round's explain stage should fix it properly.

  BASELINE AT THE START OF THIS ROUND: 492 assertions green under four
  contracted timezones, lint clear on 17 rules, headless green at both viewports
  plus the drawer and tap-count phases. main level with origin/main at a256bdf.

  PRODUCT LAW, still binding: the app does not interpret, score or advise. Note
  that nothing in this round breaks it — a stop button states a fact, a mark
  column sums what you already said, and "found 12 plan events, parsed 0" is a
  count. "?" is not a judgment; it is the absence of one.
