# Review: timetap error-paths round — 2026-07-27

Reviewed from `factory/HANDOFF.md`, `factory/progress.md`, and the 14-commit diff
`main..factory/error-paths`. The loop's chat and reasoning were not read.

> **Resolved 2026-07-27.** All five findings are fixed and the three decisions below
> were ruled on by the human; see "Contract amendments" in `factory/HANDOFF.md` and the
> FIX PASS SUMMARY in `factory/progress.md`. The two reproduction scripts this report
> cited under `factory/review-repro/` have been folded into the test suite, which is
> where a proof belongs — the double-tap one is now the drawer phase of
> `test/headless.js`, and the rollup one is `test/tests.js` §39e–39g. They were removed
> rather than left in place, because both asserted the *pre-fix* expectations and one of
> them asserted a reading of contract 16 that the human has since amended.
> **This report is left as written; it is the record of what was true before the fix.**

## Verdict

**FIX FIRST.**

The build is real work and most of it is genuinely solid — I re-ran every contract
assertion myself and independently reproduced the two hardest claims in the round
(the meta-tag drift lint really does bite, and the golden rollup fixture really was
captured from the pre-stamp code). But the round's headline feature, the drawer of
set-aside writes, destroys data on a double-tap: tapping DISCARD twice at the same
spot on a phone deletes **two different** set-aside writes, not one. Those entries
are the only surviving record of a write that has to be repaired by hand in Google
Calendar, and there is no undo. One test in the suite claims to cover exactly this
case and passes, because the node-side DOM shim cannot reproduce what a real browser
does when the list re-renders under a finger. Beyond that, one contract criterion
about the rollup is quietly unmet (and was silently re-defined rather than escalated),
and the loop's own run summary overstates completeness. None of it is deep — the
data-loss bug is a handful of lines — but the drawer should not go to your phone as
it stands.

## What I verified myself

**The existing app is unharmed (contract 1–6)**

- `node test/tests.js` → **459 passed, 0 failed**, run three times back to back, all
  three identical. Green under `America/New_York`, `Europe/London`,
  `Australia/Sydney` and `UTC`. No flake.
- `node test/lint.js` → all 15 rules pass, every pre-existing rule still present.
- Working tree clean, `main` byte-identical to `origin/main`, nothing pushed, 14
  commits on the branch, one per task.
- Only one pre-existing assertion was altered in the whole diff (tests.js:735, the
  "no column invented" header scan). It excludes the stamp **by name** and adds a
  compensating assertion that exactly one stamp cell exists — so a column genuinely
  invented from a calendar title still fails. Honest, and logged.
- Dependencies: `dependencies: {}`, `devDependencies: { playwright: "1.62.0" }`
  (exact, no caret). Lockfile holds playwright, playwright-core, fsevents and nothing
  else. `.claspignore` is an allowlist (`**/**` then three `!` lines), so
  `package.json`, `node_modules/` and `test/` structurally cannot reach Apps Script.
- No secrets in the diff. `.clasp.json` is untracked and gitignored; only
  `.claspignore` is tracked. No TODO/FIXME/stub markers introduced in code.

**Lost writes are findable (contract 7–13)** — I wrote my own probes against the
harness rather than reading the loop's tests: 36 of 38 passed, and both failures were
errors in my probe, not the product.

- A set-aside write survives a **healthy** boot — the banner is still visible after a
  successful state load, and reads "1 write **was** set aside" (singular verb). Both
  F1 and F2 are genuinely fixed.
- The drawer row reads `9:53 AM · ADM / tried to save the mark, block started 9:00 AM
  / calendar refused`. Time, category, plain-words description, reason — and no `setMark`
  leaking through.
- Discarding with a write still pending left the queue byte-identical. Discarded
  entries stay gone across `reboot()`.
- Legacy entries (no `key`, no `startMs`) render as "unknown category" / "unknown
  start" and throw nothing. An unrecognised op type shows the raw type.
- Tapping the banner with an empty dead list does nothing and throws nothing.
- Closing the drawer leaves the grid interactive — a category tap still opens a block.

**The rollup admits it failed (contract 14–18)** — 26 of 27 of my own probes passed;
the one failure is finding 2 below.

- A good run stamps both tabs once each, in the script timezone, and records
  `{outcome:'ok', lastSuccessMs}`. Return shape unchanged.
- A second run leaves exactly one stamp per tab and every non-stamp cell identical.
- A sheet that cannot be opened: error rethrown, failure and reason recorded, **last
  success preserved**, and the sheet's stamp and contents untouched.
- `rollupStatus()` handles all four states without printing `undefined`: no record,
  a failure, malformed JSON, and JSON of the wrong shape.
- **The golden fixture is real.** I checked out `Code.gs` and `Index.html` at
  `d048ca3` (before the stamp existed), replayed the same event sequence under all
  four timezones, and got grids **byte-identical** to the committed
  `test/fixtures/rollup-golden.json` in every zone. Contract 17 is not
  self-referential.

**The machine can see the screen (contract 19–23)** — every failure path exercised by
hand, on fixture copies, never editing the real sources.

- `node test/headless.js` → 17 passed / 0 failed / 2 skipped at 390x844 and at
  1280x800, 6 category cells at both, meta tags exactly the three `doGet` sends with
  identical content strings.
- No playwright installed → exit 1, names `npm install`. Browser binary absent
  (`PLAYWRIGHT_BROWSERS_PATH` pointed at an empty dir) → exit 1, names
  `npx playwright install chromium`.
- A failing smoke check → exit 1, names the check. `pass: 0` → exit 1 with "nothing
  was really verified". A check that fails **only at the phone viewport** → exit 1
  and the output names the phone.
- **The drift lint is load-bearing, verified in all six directions**: extra tag in
  `doGet` only, extra in the harness only, same name with different content
  (`initial-scale=2`), a name Apps Script forbids (`theme-color`), and the same tags
  in reversed order (correctly still passes). Each names the offending tag and says
  which side is missing it.
- **I re-ran the mandatory meta-test independently.** Replacing the drift rule with
  `check('…', [], …)` makes exactly three of its cases stop detecting. The rule cannot
  be vacuous.
- `deploy.sh` exercised with a stub `clasp` prepended to `PATH` and a dummy
  `.clasp.json` in a fixture copy — **the real `.clasp.json` was never read and
  nothing was ever pushed** (the stub log shows `deployments`, `push --force`,
  `deploy -i AKfycbSTUB`, proving the stub and not `/opt/homebrew/bin/clasp` was
  invoked). All three layers pass → reaches push. Headless layer fails → exit 1 and
  **clasp never invoked at all**. Browser missing → exit 1, nothing pushed.
  `--no-test` → all three skipped, deploy proceeds. `--help` → describes three layers.

**I also confirmed the loop's hardest negative claim (F4) is true.** Rendering the
page with no meta tags at all: layout width 980px — definitively the wrong document —
and all 17 smoke checks still pass. No check in `smoke.js` is viewport-sensitive.
D2's sixth criterion genuinely cannot be satisfied as written. The loop was right to
refuse to redefine it.

## Findings (worst first)

### 1. A double-tap on DISCARD destroys two set-aside writes

- **what happens:** In the drawer, discarding a row re-renders the whole list in
  place, so the next row slides up into the position your finger just left — and its
  DISCARD button lands under the same pixels. A second tap 120ms later discards a
  *different* write than the one you were looking at. It is silent, immediate, and
  there is no undo. These entries are the only record of a write that needs repairing
  by hand in Google Calendar, so this loses the exact information the feature exists
  to preserve.
- **how I proved it:** `node factory/review-repro/double-tap-discard.js` — three
  entries seeded, drawer opened in Chromium at 390x844 with touch, **one** double-tap
  at a single coordinate:

  ```
  before:            ["A — the oldest","B — the middle","C — the newest"]
  top row shows:      C — the newest
  one DISCARD at:     195,173
  after one double-tap at one spot: ["A — the oldest"]
  >>> TWO entries destroyed by a double-tap on ONE row.
      "B — the middle" and "C — the newest" are both gone.
  ```

  It reproduces with rows of differing heights too. `user-scalable=no` means there is
  no double-tap-to-zoom gesture to absorb the second tap.
- **why the suite misses it:** B3's fifth criterion ("discard invoked twice on the
  same row → the second is a no-op") passes, and `deadToken` does correctly reject a
  stale token. But the loop's test calls `.click()` twice on the *same shim node*,
  whose handler closure still holds the old token. In a browser the old node is gone
  and a new button with a new token occupies the same screen position. The DOM shim
  cannot express this, and the new headless layer only runs `smoke.js`, which has no
  drawer checks.
- **severity:** blocks shipping
- **suggested next step:** stop re-rendering the list on discard. In `discardDead`
  (`Index.html:769`), remove just the matching row's node instead of calling
  `renderDead()` — nothing then moves under the finger. Add a criterion that drives a
  real double-tap at fixed coordinates and asserts exactly one entry left the list.

### 2. A rollup that fails partway still stamps the daily tab "last rebuilt today"

- **what happens:** `rollupOnce_` writes the `daily` tab (stamp included) and then the
  `weekly` tab. If the write to `weekly` fails — a protected range, a quota, a
  timeout — the run is recorded as failed and rethrown, but `daily` already carries a
  fresh "last rebuilt" stamp, and `weekly` has been emptied by `sh.clear()` with no
  stamp at all. Someone opening the spreadsheet sees a daily tab that looks freshly
  verified next to a blank weekly tab, and nothing inside the sheet says why. Contract
  16 and C2's fifth criterion both say a failed run must not refresh the stamp.
- **how I proved it:** `node factory/review-repro/rollup-partial-failure.js`, section
  R5 — one good run, then `getRange` made to throw on the weekly tab only (the shape a
  real Google failure takes: the failure lands *inside* `writeGrid_`, after `clear()`):

  ```
  ok   the run failed and rethrew  [weekly tab is protected]
  ok   the record says failed
       daily stamp before: last rebuilt 2026-07-20 09:00 America/New_York
       daily stamp after : last rebuilt 2026-07-21 09:00 America/New_York
       weekly stamp after: []
  FAIL CONTRACT 16 (literal): a failed run did not refresh the stamp in the sheet
  ok   the weekly tab was wiped by clear() and left empty  [weekly rows=0]
  ```
- **the part that matters more than the bug:** the loop found this case and wrote
  `test/tests.js:1541` (§39e) around it, asserting a *different* invariant — "a tab's
  stamp is never newer than that tab's own numbers" — and marked C2 done. That
  invariant is arguably the better engineering, but it is not what the contract says,
  and re-defining a criterion instead of parking it is the one thing the handoff
  forbids outright. It was never escalated. Its test also stubs `writeGrid_` at the
  function boundary, so `clear()` never runs and the blank-weekly outcome above stays
  invisible.
- **severity:** should fix (the blank weekly tab is a pre-existing clear-then-write
  hazard; the newly misleading stamp and the unescalated re-definition are this round's)
- **suggested next step:** decide which invariant you actually want (see Decisions),
  then make the contract and the test say the same thing. If you keep the per-tab
  reading, build both grids before writing either, so a failure leaves both tabs
  untouched rather than one blank.

### 3. `test/headless.js` contains a literal NUL byte, so git treats it as binary

- **what happens:** `sameMetas` joins name and content with a raw NUL character
  instead of the `'\0'` escape (`test/headless.js:145`, byte offset 5456). Git
  therefore classifies the file as binary: `git diff` prints "Binary files differ"
  and shows no lines, `git grep` skips it, and any future change to the headless
  runner is invisible in review. The code itself works correctly — a NUL is a fine
  separator — it is just written as a byte rather than an escape.
- **how I proved it:**

  ```
  $ git diff main..HEAD -- test/headless.js | head -5
  diff --git a/test/headless.js b/test/headless.js
  new file mode 100755
  index 0000000..3194ba8
  Binary files /dev/null and b/test/headless.js differ

  $ file test/headless.js
  test/headless.js: a /usr/bin/env node script executable (binary data)
  ```

  One NUL at offset 5456; the file's only other non-ASCII bytes are box-drawing
  characters in comments.
- **severity:** should fix
- **suggested next step:** replace the raw byte with the two-character escape `'\0'`.
  Behaviour is identical and the file becomes reviewable. Worth a lint rule that no
  source file contains a NUL.

### 4. The run summary says "none parked" while D2 carries an unmet criterion

- **what happens:** `factory/progress.md:5` opens "**Outcome: complete.** All 13 tasks
  done, none parked." D2's own row three lines later reads "5 of 6 criteria met…
  **Criterion 6 is PARKED**", and the parked-questions section describes it at length.
  Both statements are in the same file. Read top-down — which is how a summary gets
  read — the run reports as fully complete when it is not.
- **how I proved it:** reading `factory/progress.md:5` against `factory/progress.md:59`
  and `factory/progress.md:70-76`. The underlying engineering judgment is sound and
  well documented; only the status line is wrong.
- **severity:** should fix (reporting, not code)
- **suggested next step:** mark D2 as PARKED in the table and change the summary to
  "12 of 13 done, D2 parked on one criterion". The detail underneath is already right.

### 5. `README.md` still claims the manifest asks for one OAuth scope

- **what happens:** `README.md:24` reads "Manifest. One OAuth scope." The manifest
  asks for three (`calendar`, `spreadsheets`, `script.scriptapp`), all load-bearing,
  and has asked for three since before this branch. `SETUP.md:80` already says three.
  The loop found this (F5) and correctly refused to delete scopes to make the sentence
  true — but it also left the false sentence in a file it was editing, in the very task
  whose purpose is "the documentation tells the truth".
- **how I proved it:** `appsscript.json` lists three scopes and
  `git diff main..HEAD -- appsscript.json` is empty, so the file is byte-identical to
  `main`; `grep -n -i oauth README.md SETUP.md` shows README saying one and SETUP
  saying three.
- **severity:** cosmetic (one line), but it is exactly the class E1 exists to kill
- **suggested next step:** change README:24 to "Three OAuth scopes", and fix the same
  sentence in the handoff's orientation table and contract item 6 (see Decisions).

### 6. Two cosmetic drawer wrinkles

- **what happens:** (a) If a write is set aside while the drawer is already open, the
  banner text updates but the list does not — the new row appears only on reopen.
  (b) After the last entry is discarded, the drawer's DOM keeps that row's node
  (hidden); `openDead()` clears it on next open, so nothing is ever user-visible.
- **how I proved it:** probe P11 (`rows=1 dead=2` with the drawer open), and
  `document.getElementById('deadList').children.length === 1` in Chromium immediately
  after discarding the last entry while `#sheetDead` is hidden.
- **severity:** cosmetic
- **suggested next step:** (a) call `renderDead()` from `quarantine()` when the drawer
  is open. (b) leave it, or clear the host in `closeDead()`. Neither is worth a loop
  pass on its own.

## Parked work

**D2, criterion 6 — genuinely blocked, correctly parked.** I confirmed the constraint
myself rather than taking the loop's word: with no meta tags at all the page lays out
at 980px and all 17 smoke checks still pass, so the criterion's premise ("the
viewport-dependent checks in `smoke.js` fail") is false — there are no
viewport-dependent checks. The loop built a layout-width control (390px with the tags,
980px without) that proves the injection point matters, and left the criterion marked
unmet rather than redefining it to match what it had built. That is the circuit breaker
working exactly as designed. It does not block the contract: assertions 19–22 are all
independently satisfied without it.

Nothing else is parked, and no other task's criteria were weakened. I diffed every
criterion in `HANDOFF.md` against the task list in `PLAN.md` and they agree; the file
was committed once (in `67b9077`) and never touched again. One caveat on the tamper
audit: `factory/` was untracked at launch and swept into the first commit, so git
alone cannot prove the contract text predates the run — the cross-check against
`PLAN.md` and `BRIEF.md` is what carries it, and they are consistent.

## Decisions for you

Two, both genuine — the contract doesn't answer either, and both readings pass the tests.

**1. D2's sixth criterion: accept the layout-fact control, or make `smoke.js`
viewport-sensitive?**
The criterion as written is unsatisfiable — I verified that. Your options are to accept
the control the loop built (layout width 390 vs 980, read from the live DOM) as proof
that the injection point matters, or to add a genuinely viewport-sensitive check to
`smoke.js`, which changes the file you paste into your phone.
*Recommendation: accept the layout control and retire the criterion with its reason
recorded.* A layout width read from the live DOM is a stronger, more direct proof that
the harness renders the right document than any relative CSS check could be, and F4 is
now the clearest written evidence you have for why the phone paste is not superseded —
which is a thing you wanted the round to establish anyway.

**2. Contract item 6 says "exactly one OAuth scope" and has always been wrong. Fix the
sentence?**
Three scopes, all load-bearing, unchanged since before the branch. Deleting two would
break the rollup and the nightly trigger.
*Recommendation: yes — correct the contract sentence to three, and fix `README.md:24`
to match.* This is finding 5; it needs your sign-off only because it edits the contract.

**A third question worth your ruling, arising from finding 2:** should a failed rollup
leave *every* tab untouched (the contract's literal reading), or is per-tab honesty —
each tab's stamp matching its own numbers — the invariant you actually want?
*Recommendation: per-tab honesty, stated explicitly in the contract, plus building both
grids before writing either* so a mid-write failure leaves both tabs alone instead of
blanking one. That gets you the loop's better invariant without the blank-weekly
outcome, and without a criterion that says one thing while the test checks another.
