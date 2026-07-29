# Factory State
project: timetap
stage: 6
stage_name: Reviewed a fifth time; the three faults that blocked are fixed, the rest is a list
last_updated: 2026-07-29 (FIXES-5 done; review 6 ready)
next_action: "RUN REVIEW 6. Fresh chats, no builder context. Prompt: factory/REVIEW-6-PROMPT.md. Three angles, three models — (1) Claude Sonnet 5 thinking: did FIXES-5 fix what it claimed; (2) GPT-5.6 medium: what did the fixes break; (3) Claude Opus 5 thinking: how does it fail a user. None may be Composer. Assemble factory/REVIEW-6.md after a fourth hand re-reproduction of anything that would block. Redesign is LIVE on the phone. Goldens still match a256bdf. Never point tests at a real calendar."
old_next_action_4: "WORK THROUGH factory/FIXES-5.md, in a fresh session. Read factory/REVIEW-5.md first — it holds the reproductions, and every one was reproduced twice before it was written down. THE THREE BLOCKING FAULTS ARE ALREADY FIXED AND COMMITTED (23dcc6e, 7c63226, 8253299) and FIXES-5 lists them so its letters make sense; what is left is nine should-fix and eleven cosmetic, grouped A to F, plus two items older than this round and two the record owes. FIVE DECISIONS ARE OPEN and they are marked *Decision first* in FIXES-5: the reflex double tap (B3), the undo chip (D1), and the three the review lists at its end. THE LIVE APP IS NOT AFFECTED: deployed version 30 is the pre-redesign build, and nothing since has been pushed. State: 1162 assertions green twice in all four contracted zones, lint clear on 20 rules, headless ok at both viewports and now at EVERY HOUR of the day, which it was not before. Optional and still not done: the proof video (auto-loom-proof) and the plain-language explainer (factory-explain, which also owes GUIDE.md Part 2 a correction carried over from round 1). BEFORE DEPLOYING, read the spreadsheet-formulas note below — it still holds, because nothing since has moved a column."
old_next_action_3: "THE HUMAN ACCEPTS AND DEPLOYS. All 24 items in factory/FIXES-4.md are done, each written criterion-first and verified by running it; nine commits on main, nothing pushed. 1101 assertions green TWICE under all four contracted timezones, lint clear on 20 rules, headless ok at both viewports with three new phases. REVIEW-4's four blocking reproductions were re-run BY HAND at the end and printed gone — the record is in factory/log-2.md under 'The FIXES-4 pass'. Three decisions were put to the human before anything was built and all three were answered: STOP acts on one tap and the ribbon is the way back; the mis-tap merge stays out, to be judged in use; the Add row follows the design and sits at the end of the list. BEFORE DEPLOYING, read the spreadsheet-formulas note below — it still holds, because this pass changed no column. Optional and still not done: the proof video (auto-loom-proof) and the plain-language explainer (factory-explain, which also owes GUIDE.md Part 2 a correction carried over from round 1). A FIFTH REVIEW IS WORTH IT: this pass touched the undo path, the server op, the layout in three places and the lint rules, and no independent eye has seen any of it."
old_next_action_2: "WORK THROUGH factory/FIXES-4.md, in a fresh session. Read factory/REVIEW-4.md first — it holds the reproductions. Three reviewers returned BROKEN, NOT DONE and MINOR DRIFT on the redesign; five faults block, and three of them break the redesign's own central claim that nothing is lost to one tap. Three decisions are open and are listed at the end of REVIEW-4; the STOP one should be settled before it is built. THE LIVE APP IS NOT AFFECTED: deployed version 30 is the pre-redesign build, and the redesign has never been pushed or deployed. The round-2 work below is complete and was accepted."
old_next_action: "THE HUMAN ACCEPTS AND DEPLOYS. The work is 25 commits on factory/honest-record; main is untouched at a256bdf and nothing has been pushed. Read factory/REVIEW-3.md, above all its 'Decisions for you' — all five are answered and the answers are in progress-2.md. Then merge, deploy, and CHECK YOUR OWN SPREADSHEET FORMULAS: D1 added a rollup key, which moved 13 of the 22 columns the daily tab had. SETUP.md says which, and shows a formula that survives the next change. Optional and offered, not done: the proof video (auto-loom-proof) and the plain-language explainer (factory-explain, which also owes GUIDE.md Part 2 a correction carried over from round 1)."
notes: |
  FIXES-5 IS DONE — 2026-07-29.

  Every letter in factory/FIXES-5.md is closed. F1 put GUIDE Part 2 into the past
  tense and pinned it with a lint rule. F2 ran smoke on a real iPhone (Chrome)
  after Safari could not open /exec; a temporary ?smoke=1 runner carried the
  paste, then left the tree. Phone results: 30/1 found the lit-row inset drift,
  smoke was corrected, then 29/0 with two idle skips. Record in factory/log-2.md.

  The redesign is on the phone because F2 required it. One redeploy is still
  owed to drop the temporary smoke injection from the live project.

  NEXT is the human's: sixth review, and whether that deploy stays.

  ---
  REVIEWED A FIFTH TIME, AND THREE FAULTS BLOCKED — 2026-07-29.

  factory/REVIEW-5.md. Three independent reviewers, one per angle, none given the
  builder's reasoning and none given each other's findings. Every finding was then
  reproduced a second time by hand in a fourth clean clone, and every finding that
  looked like a regression was re-run against 2a15553 to prove the FIXES-4 pass
  had caused it. All three returned SHOULD NOT SHIP.

  Twenty-two of the twenty-four FIXES-4 items closed exactly against their written
  criteria, and all five of REVIEW-4's blocking faults were genuinely gone — each
  one re-reproduced from the review's own description rather than from the suite,
  and each held by a mutation. What blocked was three things:

    C1  an undo that threw the sitting away when the writes were still queued,
        then claimed SITTING for the rest of the session. A regression.
    C2  node test/headless.js red for the first ten hours of every local day,
        with deploy.sh refusing to deploy behind it and D2 unverified when it was.
    C3  a sheet acting on a block it was not about — 21 minutes billed to two
        categories, zero errors — reachable because the sheets were not modal.

  ALL THREE ARE NOW FIXED, verified, and committed: 23dcc6e, 7c63226, 8253299.
  Criteria written first and watched fail in every case; each removal then put
  back one at a time to prove a test bites.

  FIVE CLAIMS IN THE OLD RECORD DID NOT HOLD, and the review says so in its own
  section: "headless ok"; "Body-and-sitting-at-once is unreachable" (two taps
  reached it, and it survived a reload); "one rule retired, one added" (21 to 20,
  and nothing was added); "26 smoke checks each" (26 existed, 24 ran, 2 skipped);
  "nine commits" (twelve of work). Nothing in the account hid a fault, but
  "headless ok" is the claim the contract's Done means turns on.

  WHAT THE HUMAN RULED THIS ROUND:
    1. C1 joins the two sittings rather than leaving a seam in the record.
    2. A CATEGORY TAP HAS NO IMPLICATIONS FOR THE POSTURE. The Body-closes-sitting
       coupling is gone on all four paths the handoff named, and BODY_KEY with it.
       This DEVIATES FROM A DESIGN CONTRACT the human accepted — the handoff lists
       the coupling under "Preserve, do not rewrite" — deliberately, and it is
       recorded where a reader meets it: Code.gs where BODY_KEY was, tests.js
       section 68, README and SETUP. FIXES-4's item A4 is therefore INVERTED.
       It also answered REVIEW-5's should-fix 2 by deletion.
    3. STOP KEEPS ITS COUPLING. It ends the day, and ending the day ends the
       sitting; the ribbon owes both halves back. That is an exception about the
       day rather than about a category, which is why it survived a ruling that
       removed every other one — and it is why C1's machinery is live code rather
       than dead. The stated cost: a day ended at 21:00 leaves the sitting
       running, and staleGuard_ bounds it at midnight, so the day reports sitting
       hours nobody sat. Tap the footer as well. Section 43 says so.

  WHAT IS LEFT: factory/FIXES-5.md. Nine should-fix, eleven cosmetic, two items
  older than this round, two the record owes, and five open decisions. Nothing on
  the list makes the record wrong in a way a user would meet by touch alone; the
  worst of it — A1 — makes the SCREEN wrong for up to ten minutes after another
  device intervenes.

  NOT DONE, and the human's call: deploying, and whether a sixth review is worth
  it. Version 30 on the phone is still the pre-redesign build and nothing has been
  pushed.

  ---
  WHAT FOLLOWS IS THE RECORD AS IT STOOD AFTER THE FIXES-4 PASS.
  ---
  THE FIX PASS IS DONE — factory/FIXES-4.md, all 24 items, 2026-07-28.

  970 -> 1101 assertions, green twice under all four contracted timezones. Lint
  clear on 20 rules (one retired, one added). Headless ok at both viewports, 26
  smoke checks each, three new phases: the guardrails at 6/7/8/10 categories,
  the rail at 6/20/40 blocks, and the dead zone under the ribbon.
  appsscript.json and test/fixtures/rollup-golden.json still byte-identical to
  a256bdf.

  THE FIVE THAT BLOCKED ARE GONE, and were re-run by hand rather than trusted
  to the suite. The mid-flight undo leaves the original block open and a reload
  agrees. The ribbon and all three mark buttons are on screen and under the tap
  at every category count to MAX_CATEGORIES. Undo puts back the sitting it
  closed, on the switch path and the STOP path. Body-and-sitting-at-once is
  unreachable. STOP acts on one tap and has no armed state.

  WHAT THE HUMAN RULED, before anything was built:
    1. STOP follows the handoff — one tap, and the ribbon is the way back.
    2. The mis-tap merge stays out. See whether it hurts in use.
    3. The Add row follows the design and sits at the end of the list.

  FOUR THINGS THIS PASS ADDED TO THE REVIEW'S LIST, each because leaving it
  would have made a fix dishonest rather than merely incomplete: S.lastTapMs
  (dead state, read nowhere); the headless C2 phase (measuring a span the
  client never fills); INIT_CLS reading the markup rather than mirroring it
  (pulled forward from E3, because a criterion of A3's passed vacuously without
  it); and the docs rule extended to the undo ribbon (it pinned STOP but not
  the control the redesign turns on).

  THREE CHECKS THIS PASS WROTE COULD NOT FAIL and were caught by reverting the
  fix and watching the criterion stay green. Two read a drawer string for a
  year the drawer never prints; one compared the rail's segments to a box that
  grows with them. Reverting after every fix is what found them.

  NOT DONE, and the human's call: DEPLOY. Version 30 on the phone is still the
  pre-redesign build and nothing has been pushed.

  WORTH DOING: a fifth review. This pass touched the undo path, one server op,
  the layout in three places and the lint rules, and no independent eye has
  seen any of it.

  ---
  WHAT FOLLOWS IS THE RECORD AS IT STOOD WHEN THE REDESIGN WAS REVIEWED.
  ---
  THE DAY RAIL REDESIGN — built 2026-07-28, reviewed the same day, NOT SHIPPED.

  Design 2a from ~/Downloads/design_handoff_dayrail_redesign/ (README plus an
  interactive prototype; the prototype extracted and readable at
  scratchpad/prototype-2a.html, section 2a from line 555). Two commits:
  37bcf77 (the shell, the list, the NOW panel, the rail) and 4b26e0a (undo
  replacing arm-and-confirm, plus one new server op, undoSwitch).

  REVIEWED BY THREE INDEPENDENT REVIEWERS: BROKEN / NOT DONE / MINOR DRIFT.
  factory/REVIEW-4.md has all of it; factory/FIXES-4.md is the work.

  THE FIVE THAT BLOCK:
    - undo does nothing while the write is still travelling, and says it worked.
      This is round 2's addition 4 repeated: the guard exists in
      mutatePendingOpen and was not written into the new dropOps.
    - the undo ribbon leaves the screen at seven categories; at seven a tap
      where it appears toggles sitting and writes a block.
    - undo never puts back the sitting it closed.
    - undo into BODY does not close an open SIT — the one coupling, broken on
      the one path the handoff names explicitly.
    - STOP still arms and confirms, which is the pattern the redesign exists to
      remove, on the most destructive control.

  THE LESSON WORTH CARRYING: 970 assertions were green throughout. Two of the
  five blocking faults were covered by tests that were DELETED along with the
  mechanism they tested — 52k (a lagged flush) and 50g (the coupling) — and no
  successor was written. When a mechanism is replaced, its tests describe a
  property that usually survives it. Read them before deleting them.

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
