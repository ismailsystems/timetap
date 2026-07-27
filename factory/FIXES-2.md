# FIX LIST 2: timetap error-paths — after the second review
source: `factory/REVIEW-2.md` · branch: `factory/error-paths` (continue on it)
baseline: **492 assertions** green twice under 4 timezones, `node test/lint.js` clear
(17 rules), `node test/headless.js` green at both viewports

---

## Operating loop

Same as `factory/HANDOFF.md`: GATHER → ACT → VERIFY → RECORD, one task per pass,
append to `factory/progress.md` and `factory/log.md`. Same guardrails, same circuit
breakers, same product law. `factory/HANDOFF.md` stays authoritative for everything
this file does not override, **including contract amendment A4**, which the human
ruled after review 2 and which F2-1 implements.

**Every guardrail from HANDOFF.md still applies.** In particular: never run
`./deploy.sh` without a stub `clasp` prepended to `PATH`; never edit `Code.gs` or
`Index.html` in place to make a divergence test pass; never weaken a criterion.

**Regression floor:** `node test/tests.js` must stay at **492 or more** assertions and
the count only goes up. `node test/lint.js` and `node test/headless.js` must stay
green, and the golden rollup fixture must stay byte-identical under all four zones.

**Vacuity rule, standing:** every new check gets reverted in a fixture copy to confirm
it fails without the thing it is checking. A check that passes either way is worse
than none, because it is counted.

---

## F2-1. Pin arm/confirm as the guard, and stop the comment claiming otherwise

Contract amendment A4. Assertion 24's second sentence has been replaced: the guard is
arm/confirm, not a frozen layout. Nothing about the *code's behaviour* needs to
change — this is a test and a comment.

- **what:**
  1. `Index.html:812-817` says "The discarded row is removed on its own, and the list
     is NOT redrawn… Nothing may move while a finger is down." That last sentence is
     not true of the code: removing one row from a flex column slides every row below
     it up by exactly the amount redrawing did. Rewrite the comment to say what
     actually holds — the rows do move, and arm/confirm is what makes that safe,
     because a row that slides under the finger arrives unarmed. (The comment at
     `Index.html:738-742` already says this correctly; the two contradict each other.)
  2. Add the tier-3 check that pins it. `factory/review-repro-2/tap-count.js` is a
     working harness: it taps one fixed coordinate N times in a real browser and
     records what the button said *before* each tap that destroyed something. Fold it
     into `test/headless.js` as a phase alongside the existing drawer phase — do not
     leave it in `factory/`.
- **risk:** low. No behaviour change; if you find yourself editing the discard logic,
  stop and re-read A4.
- **acceptance criteria:**
  - [tier 3] Given five set-aside writes and the drawer open, when one fixed
    coordinate is tapped 2, 3, 4 and 6 times, then exactly 1, 1, 2 and 3 entries have
    left the dead list respectively.
  - [tier 3] Given any of those runs, then **every** tap that destroyed an entry was
    preceded, at that same coordinate, by a button reading `TAP AGAIN TO DISCARD` —
    no entry is ever destroyed by a tap onto an unarmed button.
  - [tier 3] Given the same runs, then the page throws nothing.
  - [tier 3, vacuity] Given `armDead` is reverted to discard on the first tap in a
    fixture copy, then the new check **fails** and says which tap destroyed an entry
    without arming first.
  - [tier 1] The existing §37f, §37g, §37h, §37i, §37j and §37k assertions all keep
    passing unchanged.
- **test notes:** the harness needs a real http origin (`localStorage` on the
  `about:blank` document `setContent` produces is a different store) — that is why it
  routes `http://timetap.invalid/` rather than using `setContent`, the same way the
  existing drawer phase does. If the check count per viewport changes, `test/README.md`
  needs to say so.

## F2-2. The NUL-byte rule must cover every file, as assertion 26 says it does

- **what:** `test/lint.js:225-233` lists seven root files plus a non-recursive read of
  `test/`. Assertion 26 says "given **any file in the repo**", and `progress.md` calls
  it "a lint rule over every text file". Neither is true: `factory/`, `site/`,
  `.github/`, `test/fixtures/`, `.gitignore`, `.claspignore` and `package-lock.json`
  are all outside it. Drive the rule off the tracked file list instead of a
  hand-written one, so it cannot go stale when a directory is added.
- **risk:** low. Watch out for genuinely binary tracked files — there are none today,
  and if one is ever added it needs an explicit, named exemption rather than a silent
  extension filter.
- **acceptance criteria:**
  - [tier 1] Given a NUL byte appended to `factory/log.md` in a fixture copy, then
    `node test/lint.js` fails and names `factory/log.md`.
    Proof today: it prints `all clear` and exits 0.
  - [tier 1] Given a NUL byte appended to `site/index.html`, to
    `.github/workflows/pages.yml`, and to `test/fixtures/rollup-golden.json` in a
    fixture copy, then lint fails and names each one.
  - [tier 1] Given the repo as it stands, then the rule passes — it must not start
    failing on files that are fine.
  - [tier 1] Given a file that is tracked but not readable as text, then the rule says
    what it skipped and why, rather than skipping silently.
- **test notes:** if you shell out to `git ls-tree`, the rule must still work in a
  checkout with no git directory — fall back to a recursive walk that skips
  `node_modules` and `.git`, and say which mode it used.

## F2-3. The scope-count rule reads two files; two live docs still state the wrong number

- **what:** `test/lint.js:237-253` scans `README.md` and `SETUP.md`. Assertion 27 says
  "no sentence **anywhere**". Still wrong today: `factory/BRIEF.md:71` ("Manifest, one
  OAuth scope.") and `factory/PLAN.md:33` ("`appsscript.json` still asks for exactly
  one OAuth scope."). BRIEF's orientation table states it as a current fact about the
  repo, which is exactly how the wrong number got quoted into a build contract.
  Correct both lines, and widen the rule to every `.md` in the repo.
- **risk:** low, with one trap: `factory/REVIEW.md`, `factory/REVIEW-2.md`,
  `factory/log.md` and `factory/progress.md` **quote the old sentence on purpose** —
  they are the record of what was wrong and when. Widening the rule naively will fail
  on them. Exempt them by name, in a list with a comment saying why, not by a pattern
  that could quietly swallow a real doc.
- **acceptance criteria:**
  - [tier 1] Given the repo after the fix, then `node test/lint.js` passes.
  - [tier 1] Given `factory/BRIEF.md` reverted to "one OAuth scope" in a fixture copy,
    then lint fails and names the file and the sentence.
    Proof today: it passes.
  - [tier 1] Given the same for `factory/PLAN.md`, then lint fails and names it.
  - [tier 1] Given the historical files are left exactly as they are, then lint
    passes — the exemption is load-bearing and must be tested, not assumed.
  - [tier 1] Given a new `.md` added anywhere with a wrong count, then lint fails and
    names it — the rule must not need editing when a doc is added.
- **test notes:** `appsscript.json` is not to be touched. It is byte-identical to
  `main` and all three scopes are load-bearing (amendment A2).

## F2-4. The suite must skip, not crash, in a timezone it has no golden for

- **what:** `test/tests.js:1710-1724`. §39d looks up `GOLD.byZone[<script timezone>]`,
  reports `FAIL there is a golden for this timezone`, and then the next line
  dereferences the missing golden and throws — aborting the run before anything after
  §39d executes. Contract item 2 names four zones, so this is not a contract
  violation; it is a developer in a fifth zone getting a stack trace and a partial
  run instead of a clear reason.
- **risk:** low. Do **not** make the missing golden a silent pass — that is the
  counted-assertion-that-cannot-fail class `test/README.md:63` records. It reports as
  a skip, with the zone named, the way `smoke.js` reports skips.
- **acceptance criteria:**
  - [tier 1] Given `TZ=Asia/Kolkata`, then `node test/tests.js` runs to completion,
    exits 0, and reports §39d as **skipped** with the zone named — not as passed.
    Proof today: `TypeError: Cannot read properties of undefined (reading 'days')` at
    `test/tests.js:1724`, run aborted.
  - [tier 1] Given `TZ=Pacific/Chatham` (a 45-minute offset), then the same.
  - [tier 1] Given each of the four contracted zones, then §39d runs in full as it
    does now and the assertion count is unchanged from 492 in each.
  - [tier 1] Given a skipped §39d, then the skip is not counted in `passed` — a run
    with a skip must be visibly different from a run without one.
  - [tier 1, error] Given the golden fixture file is corrupt or missing entirely in a
    fixture copy, then the suite says so plainly and exits non-zero rather than
    throwing a `TypeError`.
- **test notes:** the fixture stays byte-identical. This is about how a missing entry
  is handled, not about adding entries.

## F2-5. `progress.md`'s parked question was answered

- **what:** `factory/progress.md:103-109` still ends "**Your call: accept the
  layout-fact control, or add a genuinely viewport-sensitive check to `smoke.js`?**"
  That was ruled on 2026-07-27 (amendment A1). The top of the same file says so; the
  parked section does not.
- **risk:** none.
- **acceptance criteria:**
  - [tier 1] Given `factory/progress.md`, then the parked section marks the question
    *ruled 2026-07-27, HANDOFF amendment A1*, states which way it went, and keeps the
    original question text so the record still shows what was asked.
  - [tier 1] Given the file, then no section of it presents a decision as open that
    `HANDOFF.md`'s amendments have closed.

---

## When done

Run all of it, twice: `node test/tests.js` under the four zones, `node test/lint.js`,
`node test/headless.js`, and `./deploy.sh` with a stub `clasp` first on `PATH` in a
fixture copy. Then write a run summary at the top of `factory/progress.md` the way the
last one did, and set `factory/STATE.md` to stage 6 for a third fresh-eyes review —
which should be short, since this list is four small items and a comment.

`factory/review-repro-2/` is scaffolding for F2-1 and comes out of the tree once that
check lives in `test/`.
