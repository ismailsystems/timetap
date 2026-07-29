# Prompt for review 6 — the FIXES-5 pass

Paste this into a fresh session in `/Users/Sam/Desktop/timetap`, with no prior
context. That is deliberate: reviews 1–5 were run by reviewers who were not
given the builder's reasoning, and this one has to be too.

This is the last planned review before daily use of the redesign.

---

## Preferred: one chat, three subagents

Open **one** fresh Cursor chat. Paste the kickoff at the bottom of this file.
The parent chat is an **orchestrator only**:

1. Read this whole file.
2. In a **single** turn, launch **three** `Task` subagents in parallel.
3. Give each subagent the full contract below plus **only its angle**. Subagents
   do not see this chat; put everything they need in the Task `prompt`.
4. Set `model` on each Task as in the table. Do **not** use Composer /
   `composer-2.5-fast` for any reviewer.
5. When all three return, you (parent) do the **fourth** hand pass: re-reproduce
   every finding that would block, then write `factory/REVIEW-6.md` in the shape
   of `factory/REVIEW-5.md`.

Parent may use any model; it must not invent findings the subagents did not
produce. It may only merge, falsify by re-running, and write the file.

### Model map (Cursor Task `model` slugs)

| Angle | Role | Task `model` |
|---|---|---|
| 1 | Did it fix what it claimed? | `claude-sonnet-5-thinking-high` |
| 2 | What did the fixes break? | `gpt-5.6-sol-medium` (or `gpt-5.6-terra-medium`) |
| 3 | How does it fail a user? | `claude-opus-5-thinking-high` |

`subagent_type`: `generalPurpose` for each. `description`: short, e.g.
`Review6 angle 1`, `Review6 angle 2`, `Review6 angle 3`.

---

## Models (if running as three separate chats instead)

Same angles and models as the table above. None may be Composer.

---

## The task

Review the FIXES-5 pass at `89058d2..HEAD` (through `3c39593`, and any later
commits that only prepare this review) — about 25 commits of fix work on
`main`. It claims to close every item in `factory/FIXES-5.md`, which is the fix
list compiled from `factory/REVIEW-5.md`.

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
findings until assembly:

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
   have it; otherwise headless + the suite. Never invent a phone paste you did
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

## What each subagent returns

Plain text (not yet a full REVIEW-6.md):

- Angle number and model used
- Verdict for this angle: SHIP / FIX FIRST / NOT DONE — one paragraph
- Findings, worst first: what happens, how proved, severity
- What is right (calibration)
- Decisions for the human (only real tradeoffs)

## What the orchestrator produces

`factory/REVIEW-6.md`, in the shape of `factory/REVIEW-5.md`:

- a verdict per reviewer
- **Blocking**, with a reproduction for each (re-run by the orchestrator)
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

Replies to the human use ASD-STE100 Simplified Technical English. Code,
comments, commit messages, and `factory/` docs keep their existing voice.

---

## Kickoff paste (one new chat)

```
Work in /Users/Sam/Desktop/timetap. No prior context.

You are the orchestrator for review 6. Read factory/REVIEW-6-PROMPT.md and
follow it exactly — especially "Preferred: one chat, three subagents".

In one turn, launch three Task subagents in parallel (subagent_type
generalPurpose):

1. description "Review6 angle 1", model claude-sonnet-5-thinking-high
   — Did FIXES-5 fix what it claimed?
2. description "Review6 angle 2", model gpt-5.6-sol-medium
   — What did the fixes break?
3. description "Review6 angle 3", model claude-opus-5-thinking-high
   — How does it fail a user?

Each Task prompt must include everything from factory/REVIEW-6-PROMPT.md that
the reviewer needs (repo path, read list, forbid list, settled rulings, their
angle only). Say: return your angle section only; do not write REVIEW-6.md.

Do not review the code yourself before they finish. Do not use Composer /
composer-2.5-fast as a reviewer model.

When all three return: re-reproduce anything Blocking by hand yourself, then
write factory/REVIEW-6.md shaped like factory/REVIEW-5.md. Commit only if I ask.
```
