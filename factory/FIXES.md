# FIX LIST: timetap error-paths — post-review pass
source: factory/REVIEW.md · branch: `factory/error-paths` (continue on it)
baseline: 459 assertions green under 4 timezones, lint clear, headless green both viewports

---

## Operating loop

Same as `factory/HANDOFF.md`: GATHER → ACT → VERIFY → RECORD, one task per pass,
append to `factory/progress.md` and `factory/log.md`. Same guardrails, same circuit
breakers, same product law. `factory/HANDOFF.md` stays authoritative for everything
this file does not override.

**Every guardrail from HANDOFF.md still applies.** In particular: never run
`./deploy.sh` without a stub `clasp` prepended to `PATH`; never edit `Code.gs` or
`Index.html` in place to make a divergence test pass; never weaken a criterion.

**Regression floor:** `node test/tests.js` must stay at **459 or more** assertions and
the count only goes up. `node test/lint.js` and `node test/headless.js` must stay green.

---

## F-1. A double-tap on DISCARD must not destroy a second write (BLOCKING)

- **what:** `discardDead` (`Index.html:769`) calls `renderDead()`, which rebuilds the
  whole list. The next row slides into the position the finger just left and its
  DISCARD button lands under the same pixels, so a second tap discards a different
  write. Remove only the discarded row's node instead of re-rendering, so nothing
  moves under the finger.
- **risk:** low to fix, but it is the round's data-loss path — these entries are the
  only record of a write needing manual repair, and there is no undo.
- **acceptance criteria:**
  - [tier 3] Given three set-aside writes and the drawer open, when a real browser
    double-taps DISCARD twice at one fixed coordinate 120ms apart, then exactly one
    entry has left the dead list and the other two remain.
    Proof today: `node factory/review-repro/double-tap-discard.js` reports
    `>>> TWO entries destroyed`. After the fix it must report only one gone.
  - [tier 3] Given the same double-tap, then the entry that left is the one whose row
    was tapped — identified by its `why` string, not by position.
  - [tier 1] Given two entries and the drawer open, when one is discarded, then one
    row remains, the dead list holds one, and the drawer stays open. (B3 criterion 1,
    must keep passing.)
  - [tier 1] Given one entry, when it is discarded, then the dead list is empty, the
    drawer closes and the banner hides. (B3 criterion 2, must keep passing.)
  - [tier 1, error] Given discard is invoked twice with the same token, then the second
    is a no-op and nothing throws. (B3 criterion 5, must keep passing — the token
    guard stays; this fix is in addition to it, not instead of it.)
  - [tier 3, error] Given rows of differing heights, then the double-tap still removes
    exactly one — the fix must not depend on rows being the same height.
- **test notes:** the tier-3 criteria need a browser, so they belong in a runner under
  `test/`. `factory/review-repro/double-tap-discard.js` is a working harness for it
  (serves the real `doGet` output over a routed http origin so `localStorage` has a
  real origin, stubs `google.script.run` with an always-succeeding server). Fold it
  into the test tooling rather than leaving it in `factory/`. If it becomes a fourth
  layer rather than part of `test/headless.js`, `deploy.sh` and `test/README.md` both
  need to say so.

## F-2. A failed rollup must not leave a tab looking current

- **what:** `rollupOnce_` (`Code.gs:920`) writes `daily` then `weekly`. A failure in
  the second leaves `daily` stamped with today's timestamp and `weekly` blank
  (`writeGrid_` clears before it writes). Contract 16 and C2's fifth criterion say a
  failed run must not refresh the stamp.
- **⚠ Read `factory/REVIEW.md` "Decisions for you", question 3, before starting.** The
  human's ruling decides which of the two shapes below you build. **If it has not been
  answered, PARK this task** — do not pick one and proceed.
  - *If the ruling is "no tab is touched on failure":* build both grids fully before
    writing either, so a throw in construction or in the first write leaves both tabs
    untouched.
  - *If the ruling is "per-tab honesty":* keep the write order, and additionally
    ensure a tab is never left blank — `writeGrid_` must not `clear()` until it is
    about to write, or must restore on failure. Then correct contract 16 and C2's
    criterion 5 in `HANDOFF.md` to state the per-tab invariant, and note in
    `progress.md` that the contract text was changed by human decision.
- **risk:** medium — `dailyRollup` is the nightly trigger's entry point.
- **acceptance criteria:**
  - [tier 1, error] Given a good run, then a run where the write to the `weekly` tab
    throws **from inside `writeGrid_`** (make `getRange` throw, not `writeGrid_`
    itself — the loop's §39e stub hides the `clear()`), then no tab is left blank:
    every tab that had numbers before still has numbers.
  - [tier 1, error] Given that same partway failure, then whichever stamp invariant
    the human chose holds, asserted by name.
    Proof today: `node factory/review-repro/rollup-partial-failure.js` section R5
    reports `FAIL CONTRACT 16` and `weekly rows=0`.
  - [tier 1, error] Given that failure, then it is recorded in `ROLLUP_LAST` with its
    reason, the last success is preserved, and the error is rethrown. (C1, must keep
    passing.)
  - [tier 1] Given a good run, then the golden grid comparison still passes in all
    four timezones — `test/fixtures/rollup-golden.json` must not be regenerated.
  - [tier 1] Given `tests.js` §39e, then it either still passes or is replaced by a
    test of the chosen invariant. If it is replaced, say so in `log.md` and say why.

## F-3. `test/headless.js` must be a text file

- **what:** a raw NUL byte at offset 5456 (`test/headless.js:145`, the separator in
  `sameMetas`) makes git classify the file as binary, so `git diff` shows nothing and
  `git grep` skips it. Replace the byte with the escape `'\0'`. Behaviour identical.
- **risk:** none
- **acceptance criteria:**
  - [tier 1] Given `test/headless.js`, then it contains no byte `0x00`.
  - [tier 1] Given the repo, then no file under `test/` and none of the four source
    files contains a NUL byte — a new lint rule, so this cannot come back.
  - [tier 1] Given `git diff`, then a one-line change to `test/headless.js` shows as a
    text diff rather than "Binary files differ".
  - [tier 3] Given the fix, then `node test/headless.js` is still green at both
    viewports and the meta comparison still works — the separator still separates.
    (Add a case where one tag's name+content concatenation could collide with
    another's if the separator were dropped, so the rule is not vacuous.)

## F-4. The run summary must match the task table

- **what:** `factory/progress.md:5` says "All 13 tasks done, none parked" while D2's
  row and the parked-questions section both say criterion 6 is parked.
- **risk:** none — this is a records fix, not a code change.
- **acceptance criteria:**
  - [tier 1] Given `factory/progress.md`, then D2's status is `PARKED` in the table.
  - [tier 1] Given the RUN SUMMARY, then its first line states the parked count
    accurately, and no sentence in the file claims the run is complete.
  - [tier 1] Given the file, then the reason D2 is parked is still recorded in full —
    do not delete F4's evidence while fixing the status line.

## F-5. `README.md` must not claim one OAuth scope

- **what:** `README.md:24` says "Manifest. One OAuth scope." It asks for three, all
  load-bearing, unchanged since before this branch. `SETUP.md:80` already says three.
- **⚠ The contract sentence itself (HANDOFF contract item 6) is the human's to change.**
  Fix `README.md` either way; edit `HANDOFF.md` only if the human has answered
  Decision 2 in `factory/REVIEW.md` with a yes.
- **risk:** none
- **acceptance criteria:**
  - [tier 1] Given `README.md`, then its description of `appsscript.json` matches the
    scopes the file actually lists.
  - [tier 1] Given the docs, then no file in the repo claims a scope count that
    disagrees with `appsscript.json`. Prefer a lint rule that counts them, so the
    next scope change cannot make the docs lie again.
  - [tier 1] Given `appsscript.json`, then it is still byte-identical to `main` —
    the fix is to the sentence, never to the manifest.

## F-6. Two drawer wrinkles (do these last, or not at all)

- **what:** (a) a write set aside while the drawer is open does not appear until the
  drawer is reopened; (b) after the last discard, the discarded row's node stays in
  `#deadList` (hidden, cleared on next open).
- **risk:** none. Cosmetic. Skip both if anything above is still open.
- **acceptance criteria:**
  - [tier 1] Given the drawer is open, when a write is set aside, then the new row
    appears without closing and reopening.
  - [tier 1] Given the last entry is discarded, then `#deadList` holds no child nodes.
  - [tier 1] Given either change, then every B2 and B3 criterion still passes.

---

## When done

All fix criteria pass, the full suite is green twice in a row under all four
timezones, lint clear, headless green at both viewports → write a `## FIX PASS
SUMMARY` at the top of `factory/progress.md` and end with the baton pass:

> The fixes are in and self-checked. Next step: run /factory-review again on the fix
> diff. Don't skip it; I graded my own homework.
