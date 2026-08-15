# Prompt for the FIXES-5 pass

Paste this into a fresh session, in `/Users/Sam/Desktop/timetap`, with no prior
context.

---

## The task

Work through `factory/FIXES-5.md`. It is the fix list compiled from
`factory/REVIEW-5.md`, which is the fifth review of this app and the second of the
Day Rail redesign.

**The three faults that blocked are already fixed and committed** (`23dcc6e`,
`7c63226`, `8253299`). FIXES-5 lists them as closed so its lettering makes sense.
What is left is nine should-fix, eleven cosmetic, two items older than this round,
and two the record owes.

**Read, in this order:**

- `factory/STATE.md` — where the project is, and the three rulings the human made
  this round. Read the notes above the divider; below it is the record as it stood
  a round earlier, kept deliberately.
- `factory/FIXES-5.md` — the list. Every item, and the criterion each is to be
  built against.
- `factory/REVIEW-5.md` — the reproductions. Each was reproduced twice: once by
  the reviewer who found it, once by hand in a clean clone.
- `~/Downloads/design_handoff_dayrail_redesign/README.md` — the design contract.
  The prototype is `prototype_all_options.html`; section 2a is the design. It is a
  bundler export, so the readable markup is a JSON-encoded template on its last
  `<script>` line rather than the file itself.
- `test/README.md` — the three test layers and what each is blind to. Read this
  before writing a test; it will save you writing one that cannot fail.

## The operating loop

The same one this project has used four times. Do not vary it.

1. One item at a time.
2. Write its criterion **before** its fix, and **watch the criterion fail**.
3. Fix it. Watch the criterion pass.
4. **Put the fix back the wrong way round and watch the criterion fail again.** A
   criterion that stays green through the revert is not a criterion. This step
   found three checks last round that could not fail, and one wrong comment.
5. Commit that item on its own, with a message that says what the fault was, what
   the fix is, and what pins it.
6. Keep the suite green under all four contracted timezones.

Never point a test at a real calendar. Never deploy — that is the human's call,
and version 30 on the phone is the pre-redesign build, so nothing you break is on
anyone's device.

## Where it stands, and how to confirm it

```bash
node test/tests.js                  # 1162 passed, 0 failed   (~70 seconds — it is not hung)
node test/lint.js                   # all clear, 20 rules
node test/headless.js               # exit 0, "headless: ok (30 checks per viewport)"

for z in America/New_York Europe/London Australia/Sydney UTC; do
  TZ=$z node test/tests.js | tail -1
done
```

A fifth zone reports `1160 passed, 2 skipped` and names both skips. A skip is
never counted as a pass. `appsscript.json` and `test/fixtures/rollup-golden.json`
must stay byte-identical to `a256bdf`:

```bash
for f in appsscript.json test/fixtures/rollup-golden.json; do
  diff <(git show a256bdf:$f) $f && echo "$f unchanged"
done
```

## Suggested order

`A1` first. It is the last item where the screen states something the record does
not, all three reviewers reached it independently, and the repair is one call in
the right place. Then `A2` and `A3`, which finish the undo path. Then `C1` and
`C2`, which are about whether the tests can still fail. Then `B`, then `D`.

`E1` may fall out of `A1` — check before writing anything for it.

## Five decisions are open

Marked *Decision first* in FIXES-5. Put each to the human before building it, with
a recommendation, one at a time. Do not assume an answer.

## Three decisions are settled — do not reopen them

The human ruled on all three. Report a consequence if you find one; do not
re-argue the choice.

1. **A category tap has no implications for the posture, and the posture none for
   the block.** The Body-closes-sitting coupling is gone on all four paths, and
   `BODY_KEY` with it. This deviates from a design contract the human accepted —
   the handoff lists the coupling under "Preserve, do not rewrite" — deliberately.
   `FIXES-4`'s item A4 is therefore inverted. `test/tests.js` section 68 is the
   record of it.
2. **STOP is the exception and keeps its coupling.** It ends the day, ending the
   day ends the sitting, and the ribbon owes both halves back. That is why the
   compensating op still carries `sitRef` and `killSitRef` — that is live code, not
   residue. The stated cost is in `test/tests.js` section 43: a day ended at 21:00
   leaves the sitting running, and `staleGuard_` bounds it at midnight.
3. **STOP acts on one tap** and the ribbon is the way back. **The mis-tap merge
   stays out.** **The Add row is last**, nearest the thumb. All from earlier
   rounds.

## Known and accepted — not defects

- "week of" holds text, not a date value.
- A day of nothing but guessed time reads waking h 0 beside a non-zero category
  column. Test 56b pins it as a stated limit.
- A "?" typed by hand into Google Calendar reads as the app's guess.
- A day whose STOP writes never reach the server still becomes a night block.
- A double tap on SITTING writes a 12-millisecond event, and an UNLOGGED block can
  span 25 hours.
- Body and an open sitting at once is now a legal state, by ruling 1 above.
- `factory/GUIDE.md` Part 2 describes the round-1 double-tap bug as live; Part 3
  corrects it. That is FIXES-5 item F1 and belongs to the explain stage.

## The harness, and five ways it will mislead you

`test/harness.js` is the shim the suite runs behind. It is deliberately unhelpful
in places, and these five cost real time last round:

1. **`reset()` puts the shim back online.** Call `H.setOnline(false)` *after* it,
   not around it. Doing it before made three test cells into one cell.
2. **A dynamically created child is a stub to `querySelector`.** The shim returns
   an empty `<span>` for any selector it cannot find in the node's own markup, so
   reading a drawer row built at runtime gives you empty strings. Read
   `node.children.map(c => c.textContent)` instead.
3. **`textContent` is own-text only.** It does not aggregate descendants.
4. **The queue drains before your assertion.** Online, `Q()` is empty by the time
   you read it, so "no such op was queued" passes against a build that queued one.
   Drive queue assertions offline. Two of my own checks were vacuous this way and
   the revert step is what caught them.
5. **`advance(ms)` fires every timer in between**, one at a time, and the client
   ticks once a second. `wait(120)` is 7200 tick calls. That is why a run takes
   seventy seconds; it is also why `pump(cond)` exists — use it instead of a fixed
   loop when you are waiting for something to become true.

`H.fireDoc(type, ev)` delivers a document-level event and returns how many
handlers heard it. Assert on that count, not just on the effect.

## The voice of the files

`CLAUDE.md` asks for replies to the human in ASD-STE100 Simplified Technical
English. That rule is **about replies only**.

The code, the code comments, the commit messages, and the documents in `factory/`,
`README.md` and `SETUP.md` keep the voice they already have. That voice is part of
the record and it is deliberate: comments say what the bug was and why the fix has
the shape it has, not what the line does. Match it. Do not rewrite existing
comments into a different register, and do not write new ones in Simplified
Technical English.

Two habits in that voice are load-bearing, not decorative:

- When you delete an assertion, **say in the file where its property went**, or
  that it deliberately has no successor and why. Section 66 is the model.
- When you retire a check, **state the true reason**. A wrong reason recorded is a
  finding in its own right — that is FIXES-5's should-fix 9, closed this round.

## What to produce

A commit per item, and at the end an update to `factory/STATE.md` and a section in
`factory/log-2.md` saying what was done, what was measured, and what is left. If
you find something the list does not cover, add it to the list rather than fixing
it silently.

If an item turns out to be wrong — the review made a mistake, or the fix costs
more than the fault — say so with the measurement and put it to the human. Two of
last round's blocking faults were repairs that went one step too far.
