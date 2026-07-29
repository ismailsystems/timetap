# Prompt for review 6 — the FIXES-5 pass

Paste this into a fresh session in `/Users/Sam/Desktop/timetap`, with no prior
context. That is deliberate: reviews 1–5 were run by reviewers who were not
given the builder's reasoning, and this one has to be too.

This is the last planned review before daily use of the redesign.

---

## Models (cost / variety — fixed for this round)

Three independent reviewers. Different models. None of them may be Composer
(that is the FIXES-5 builder voice).

| Angle | Model to use |
|---|---|
| 1. Did it fix what it claimed? | Claude Sonnet 5 thinking |
| 2. What did the fixes break? | GPT-5.6 (sol or terra medium) |
| 3. How does it fail a user? | Claude Opus 5 thinking (or Opus 4.8 thinking) |

Run each angle in its **own** fresh chat (or an isolated subagent with that
model). Do not share findings between angles until a fourth pass assembles
`factory/REVIEW-6.md`.

A fourth, short hand pass then re-reproduces every finding that would block
shipping — same bar as review 5.

---

## The task

Review the FIXES-5 pass at `89058d2..HEAD` (through `3c39593`) — about 25
commits on `main`. It claims to close every item in `factory/FIXES-5.md`, which
is the fix list compiled from `factory/REVIEW-5.md`.

The three faults that blocked in review 5 were fixed first (`a540787`,
`0df0282`, `fd12407`) and listed as closed in FIXES-5 so its lettering works.
The rest of the range is A–F.

**Read these:**

- `factory/FIXES-5.md` — the contract. Every item, and the criterion each was
  supposed to be built against.
- `factory/REVIEW-5.md` — what was wrong, with the reproductions.
- `~/Downloads/design_handoff_dayrail_redesign/README.md` — the design contract.
  The prototype is `prototype_all_options.html`; section 2a is the design. Note
  the deliberate deviation below: category↔sitting coupling is gone on purpose.
- The code in the diff: `Index.html`, `Code.gs`, `test/` (and `factory/GUIDE.md`
  for F1).

**Do NOT read, before forming your own view:**

- the commit messages in the range
- `factory/log-2.md` entries for the FIXES-5 pass
- `factory/STATE.md`'s new notes above the divider
- `factory/FIXES-5-PROMPT.md`

Those are the builder's account of its own work. Read them at the END, to check
whether the account matches what you found — a mismatch is itself a finding.

## How to run it

Three independent reviewers, each on a different angle, none given the others'
findings:

1. **Did it actually fix what it claimed?** Take REVIEW-5's three blocking
   faults and reproduce each one from scratch — do not run the suite and
   believe it. Then walk every FIXES-5 item against its stated criterion
   rather than against the code's own comments.
2. **What did the fixes break?** This pass touched undo (server decline,
   rail reopen after refresh, `dropOps` all-or-nothing), sitting close
   idempotency, a11y names, scroll-into-view, rail sizing halves, headless
   skip naming, sheet modality (already closed, still load-bearing), GUIDE
   Part 2, and phone smoke. Find a seam between items.
3. **How does it fail a user?** Drive the app. Long days, ten categories, a
   flaky network, a second device, midnight, a screen reader, a keyboard only,
   a reflex double tap after a switch. Prefer the **live /exec** redesign if you
   have it; otherwise headless + the suite. Never invent a phone pass you did
   not run.

**Measure, do not read.** A comment saying a thing is true is not evidence.

**Reproduce before writing down.** Every fault you list needs a reproduction
you performed.

## What is claimed

Falsify each (do not copy them forward as fact):

- Suite green under all four contracted timezones
  (`America/New_York`, `Europe/London`, `Australia/Sydney`, `UTC`).
- Lint clear (21 rules at end of FIXES-5 — count them; do not trust the prose).
- Headless ok at both viewports; cold load **names** its skips; green before
  10:00 local because the rail fixture pins the clock.
- `appsscript.json` and `test/fixtures/rollup-golden.json` byte-identical to
  `a256bdf`.
- Every FIXES-5 item closed against its criterion.
- Phone smoke was run on a handset; lit-row check matches Day Rail’s inset
  4px accent edge (not an outer ring).

## Things to be sceptical about specifically

Not because they are known wrong — because a wrong thing would hide here.

1. **Undo vs another device.** A1 says the screen stops lying within one round
   trip when the server declines. Find a path where it still claims a running
   block after a declined undo.
2. **Criteria that cannot fail.** C1-style: each half of a fix must have a
   named check that goes red alone. Revert one half of anything expensive and
   watch.
3. **The Body↔sitting uncoupling.** Deliberate product ruling; STOP keeps the
   coupling. Confirm the four category paths are free of it, and that STOP’s
   path still joins sittings. Section 68 / 43 are the stated pins — verify
   them by mutation if needed.
4. **Phone smoke vs headless.** Headless skips the lit-row checks on a cold
   load. A green headless line is not a phone paste. Confirm what F2 actually
   proved.

## Three decisions are settled — do not reopen them

Report a consequence if you find one; do not re-argue the choice.

1. **A category tap has no implications for the posture, and the posture none
   for the block.** Body↔sitting coupling is gone on category paths; `BODY_KEY`
   is gone. Deviations from the handoff’s “Preserve” list are deliberate.
2. **STOP is the exception and keeps its coupling.** Ending the day ends the
   sitting; the ribbon owes both halves. `sitRef` / `killSitRef` are live.
3. **STOP acts on one tap**; **mis-tap merge stays out**; **Add row is last**.

## Known and accepted — not defects to re-report

- "week of" holds text, not a date value.
- A day of nothing but guessed time can read waking h 0 beside a non-zero
  category column (test 56b).
- A "?" typed by hand into Calendar reads as the app's guess.
- A day whose STOP writes never reach the server still becomes a night block.
- A double tap on SITTING can write a 12-millisecond event; an UNLOGGED block
  can span 25 hours.
- Body and an open sitting at once is a legal state under ruling 1.

## What to produce

`factory/REVIEW-6.md`, in the shape of `factory/REVIEW-5.md`:

- a verdict per reviewer
- **Blocking**, with a reproduction for each
- **Should fix**
- **Cosmetic**
- **What is right, for calibration**
- **Decisions for you** — genuine open questions only

If nothing blocks, say so plainly and say what you did to try to make something
block. "I found nothing" and "I looked hard and found nothing" are different
claims; only the second is worth anything.

## The state of the repo

`main`, ahead of `origin/main`. Goldens still match `a256bdf`.

**The redesign is live on the phone** (deployed for F2 and redeployed to drop a
temporary `?smoke=1` runner). Treat the live app as the redesign, not version
30. Prefer not to invent destructive calendar experiments — never point the
suite at a real calendar. Manual probing of the live URL is allowed; do not
burn the user's day with mass deletes.

Never deploy from this review unless the human asks.
