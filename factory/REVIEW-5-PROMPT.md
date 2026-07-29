# Prompt for review 5 — the FIXES-4 pass

Paste this into a fresh session, in `/Users/Sam/Desktop/timetap`, with no prior
context. That is deliberate: reviews 1–4 were run by reviewers who were not
given the builder's reasoning, and this one has to be too.

---

## The task

Review the fix pass at `2a15553..HEAD` — 13 commits, 11 files, +2259/−574.
It claims to close all 24 items in `factory/FIXES-4.md`, which is the fix list
compiled from `factory/REVIEW-4.md`, which is itself the review of the Day Rail
redesign.

**Read these:**

- `factory/FIXES-4.md` — the contract. Every item, and the criterion each was
  supposed to be built against.
- `factory/REVIEW-4.md` — what was wrong, with the reproductions.
- `~/Downloads/design_handoff_dayrail_redesign/README.md` — the design contract.
  The prototype is `prototype_all_options.html`; section 2a is the design.
- The code in the diff: `Index.html`, `Code.gs`, `test/`.

**Do NOT read, before forming your own view:**

- the commit messages in the range
- `factory/log-2.md`'s "The FIXES-4 pass" section
- `factory/STATE.md`'s new notes

Those are the builder's account of its own work. Read them at the END, to check
whether the account matches what you found — a mismatch between them is itself
a finding, and round 2's verifier found exactly that kind.

## How to run it

Three independent reviewers, each on a different angle, none given the others'
findings:

1. **Did it actually fix what it claimed?** Take REVIEW-4's five blocking
   faults and reproduce each one from scratch — do not run the suite and
   believe it. Then take the other 19 items and check each against its stated
   criterion rather than against the code's own comments.
2. **What did the fixes break?** This pass touched the undo path, one server op
   (`opUndoSwitch_`), the layout in three places (the grid's scrolling, the mark
   strip's stacking, a margin under the ribbon), the client's persisted state,
   and the lint rules. Every one of those has something downstream of it.
3. **How does it fail a user?** Drive the app. Long days, ten categories, a
   flaky network, a second device, midnight, a screen reader, a keyboard only.

**Measure, do not read.** A comment saying a thing is true is not evidence that
it is. Round 4's most useful findings all came from measuring something the
prose had already described correctly.

**Reproduce before writing down.** Every fault in REVIEW-4 was reproduced by
hand before it was recorded. Hold this review to the same bar.

## What is claimed

From `factory/STATE.md`, so you can try to falsify each:

- 1101 assertions, green **twice** under all four contracted timezones
  (`America/New_York`, `Europe/London`, `Australia/Sydney`, `UTC`).
- Lint clear on 20 rules. One rule was **retired** and one **added**.
- Headless ok at both viewports, 26 smoke checks each, three new phases.
- `appsscript.json` and `test/fixtures/rollup-golden.json` byte-identical to
  `a256bdf`.
- All five blocking faults gone, re-run by hand.

## Three things to be sceptical about specifically

Not because they are known wrong — because they are where a wrong thing would
hide, and a reviewer who is told nothing looks everywhere equally.

1. **The undo path now has more branches than any other code in the app.**
   Queued vs sent vs mid-flush; block, successor and sitting halves; Body's
   coupling; a set-aside compensating op; another device having moved or closed
   the block underneath it. Some combinations have no test. Find one that is
   wrong rather than one that is merely untested.
2. **A rule was retired.** `test/lint.js` no longer pins `MISTAP_SECONDS` below
   `CONFIRM_WITHIN_SECONDS`, because the second constant was deleted. Confirm
   the constant really is unreachable and that retiring the rule did not take
   anything else with it. A weakened rule that looks like a cleanup is the
   worst kind.
3. **`S.today` and `S.lastTapMs` were removed from persisted state.** Check
   nothing reads either after a reload, on any path — including a reload during
   an in-flight write, and a reload with a queue that has not drained.

## Three decisions are settled — do not reopen them

The human ruled on all three before the work started. Report a consequence if
you find one; do not re-argue the choice.

1. **STOP acts on one tap** and the ribbon is the way back. No arm-and-confirm.
2. **The mis-tap merge stays out.** Tapping the right category after a wrong one
   costs the block. One level of undo, no merge. This is to be judged in use.
3. **The Add row is last**, at the end of the list, nearest the thumb.

## Known and accepted — not defects to re-report

These are in `factory/STATE.md` and were accepted in earlier rounds:

- "week of" holds text, not a date value.
- A day of nothing but guessed time reads waking h 0 beside a non-zero category
  column. Test 56b pins it as a stated limit.
- A "?" typed by hand into Google Calendar reads as the app's guess.
- A day whose STOP writes never reach the server still becomes a night block.
- A double tap on SITTING writes a 12-millisecond event, and an UNLOGGED block
  can span 25 hours.
- `factory/GUIDE.md` Part 2 describes the round-1 double-tap bug as live. Part 3
  corrects it. The explain stage owes that a proper repair.

## What to produce

`factory/REVIEW-5.md`, in the shape of `factory/REVIEW-4.md`:

- a verdict per reviewer
- **Blocking**, with a reproduction for each
- **Should fix**
- **Cosmetic**
- **What is right, for calibration** — this matters. A review that lists only
  faults cannot be told apart from a review that found everything.
- **Decisions for you** — genuine open questions only. Everything else is fact.

If nothing blocks, say so plainly and say what you did to try to make something
block. "I found nothing" and "I looked hard and found nothing" are different
claims, and only the second is worth anything.

## The state of the repo

`main`, 44 commits ahead of `origin/main`. **Nothing has been pushed and nothing
is deployed.** Version 30 on the phone is the pre-redesign build, so nothing
under review here is on anyone's device. You are free to break things while
testing.

Never point a test at a real calendar.
