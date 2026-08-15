# Prompt for the FIXES-6 pass

Paste this into a fresh session, in `/Users/Sam/Desktop/timetap`, with no prior
context.

---

## The task

Work through `factory/FIXES-6.md`. It is the fix list compiled from
`factory/REVIEW-6.md`, which is the sixth review of this app and the review of
the FIXES-5 pass.

**What blocks is two faults.** A1: a declined undo's corrective state read is
cancelled forever by any local write during the round trip. A2: D9's Add-row
scroll moves the list under a reflex double tap (regression vs `89058d2`). A2
needs a human decision before you build it. B1 makes the lit-row checks actually
run. C1 and C2 are older; also decision-gated.

**Read, in this order:**

- `factory/STATE.md` — where the project is, and the three rulings still in
  force. Read the notes above the divider; below it is earlier record.
- `factory/FIXES-6.md` — the list. Every item, and the criterion each is to be
  built against.
- `factory/REVIEW-6.md` — the reproductions. Each blocking fault was reproduced
  twice.
- `factory/FIXES-5.md` — only for A1/A2/D9 context (what the last pass thought it
  closed). Do not re-open closed items that REVIEW-6 said hold.
- `~/Downloads/design_handoff_dayrail_redesign/README.md` — the design contract.
  The prototype is `prototype_all_options.html`; section 2a is the design.
- `test/README.md` — the three test layers and what each is blind to. Read this
  before writing a test; section 62's DOM-shim double-tap cannot see layout, and
  that is why D9's fault survived.

## The operating loop

The same one this project has used. Do not vary it.

1. One item at a time.
2. Write its criterion **before** its fix, and **watch the criterion fail**.
3. Fix it. Watch the criterion pass.
4. **Put the fix back the wrong way round and watch the criterion fail again.** A
   criterion that stays green through the revert is not a criterion.
5. Commit that item on its own, with a message that says what the fault was, what
   the fix is, and what pins it.
6. Keep the suite green under all four contracted timezones.

Never point a test at a real calendar. Never deploy — that is the human's call.
The redesign is already on the phone; do not invent a mass calendar experiment
against the live project.

## Where it stands, and how to confirm it

```bash
node test/tests.js                  # 1183 passed, 0 failed
node test/lint.js                   # all clear, 21 rules
node test/headless.js               # exit 0; skips named when they skip

for z in America/New_York Europe/London Australia/Sydney UTC; do
  TZ=$z node test/tests.js | tail -1
done
```

`appsscript.json` and `test/fixtures/rollup-golden.json` must stay byte-identical
to `a256bdf`:

```bash
for f in appsscript.json test/fixtures/rollup-golden.json; do
  diff <(git show a256bdf:$f) $f && echo "$f unchanged"
done
```

## Suggested order

`A1` first. It is the last place the screen states a running block the calendar
does not have, both reviewers who finished reached it, and the repair is the
same shape as `stateAfterBootDrain`. A2's rail inheritance closes with it.

Then put `A2`'s three options to the human (recommendation: reserve strip height
if cheap, else drop `revealAddRow` from `showStrip`). Build only after they pick.

Then `B1` (seed a running block so lit-row checks run). Then `C1` / `C2` if the
human wants them this pass.

## Decisions that need the human before you build

Put each to the human with the recommendation from FIXES-6 / REVIEW-6, one at a
time. Do not assume an answer.

1. **A2 — D9 vs reflex double tap** (options 1 / 2 / 3 in FIXES-6).
2. **C1 — STOP then posture under the same finger** (fix, or accept Ruling 2's
   cost in writing).
3. **C2 — ten-category "list continues" cue** (fix, or defer B2's second branch).

## Three decisions are settled — do not reopen them

Report a consequence if you find one; do not re-argue the choice.

1. **A category tap has no implications for the posture, and the posture none for
   the block.** Body↔sitting coupling is gone on category paths; `BODY_KEY` is
   gone. Section 68 is the pin.
2. **STOP is the exception and keeps its coupling.** Ending the day ends the
   sitting; the ribbon owes both halves. `sitRef` / `killSitRef` are live.
3. **STOP acts on one tap**; **mis-tap merge stays out**; **Add row is last**.

## Known and accepted — not defects

- "week of" holds text, not a date value.
- A day of nothing but guessed time can read waking h 0 beside a non-zero
  category column (test 56b).
- A "?" typed by hand into Calendar reads as the app's guess.
- A day whose STOP writes never reach the server still becomes a night block.
- A double tap on SITTING can write a 12-millisecond event; an UNLOGGED block can
  span 25 hours.
- Body and an open sitting at once is a legal state under ruling 1.

## The harness, and ways it will mislead you

`test/harness.js` is deliberately unhelpful in places. The ones that matter for
this pass:

1. **`H.setCallLag('getState', ms)`** computes the answer now and delivers it
   later — that is how A1's race is driven. Pass `null` to restore the default.
2. **`wait(n)` takes minutes**, not milliseconds. `wait(40)` is forty minutes of
   virtual time.
3. **`reset()` puts the shim back online.** Call `H.setOnline(false)` after it.
4. **Online, the queue drains before your assertion.** Drive queue-shape checks
   offline.
5. **Layout races need a real browser.** Headless / Chromium with touch — not
   the DOM shim — for A2. Section 62 cannot fail on D9's scroll.

`H.fireDoc(type, ev)` delivers a document-level event and returns how many
handlers heard it.

## The voice of the files

`CLAUDE.md` asks for replies to the human in ASD-STE100 Simplified Technical
English. That rule is **about replies only**.

The code, the code comments, the commit messages, and the documents in
`factory/`, `README.md` and `SETUP.md` keep the voice they already have. Match
it. Do not write them in Simplified Technical English.

When you delete an assertion, say in the file where its property went, or that it
deliberately has no successor and why.

## What to produce

A commit per item, and at the end an update to `factory/STATE.md` and a section
in `factory/log-2.md` saying what was done, what was measured, and what is left.
If you find something the list does not cover, add it to the list rather than
fixing it silently.

If an item turns out to be wrong — the review made a mistake, or the fix costs
more than the fault — say so with the measurement and put it to the human.

Do not redeploy unless the human asks. The owed post-smoke redeploy is theirs.

---

## Kickoff paste (one new chat)

```
Work in /Users/Sam/Desktop/timetap. No prior context.

Read factory/FIXES-6-PROMPT.md and follow it exactly. Work through
factory/FIXES-6.md one item at a time (criterion → fail → fix → pass → mutate
→ commit). Put every "Decision first" item to me before you build it, with the
recommendation from the list.

A1 first. Then A2 only after I pick an option. Then B1. C1/C2 only if I say so.

Never point tests at a real calendar. Never deploy unless I ask.
```
