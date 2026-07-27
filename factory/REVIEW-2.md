# Review 2: timetap — error paths round — 2026-07-27

Second independent review, run in a fresh context on the fix pass (commit `7a9b731`),
which was written by the same agent that found round 1's findings and so had never
been checked by anyone else. Round 1's report is `factory/REVIEW.md`, left untouched
as the record of what was true before the fix.

Worked from `factory/HANDOFF.md`, `factory/progress.md`, the code and the diff. No
loop transcript read.

## Verdict

**FIX FIRST.**

The two substantive fixes are real, and I proved both myself by breaking the code at
points I chose rather than the ones the suite uses. The data-loss bug is gone: a
double tap on DISCARD now removes exactly the entry it was aimed at, in a real
browser, at real coordinates. The rollup's per-tab honesty holds at three different
failure points — a write that fails on the second tab, on the first tab, and a
failure while the grid is still being built — and in none of them is a tab left
blank or left with a stamp newer than its own numbers. Everything else in the
contract that can be run, I ran, twice, and it is green.

What stops this from being SHIP is not a product bug. It is that three of the round's
own written rules are enforced more narrowly than they are written, and one code
comment states something about the code that is not true. Each is small and each is
the exact failure class this review exists to catch: a criterion that reads stronger
than the thing actually checking it. The fix list at the end is one short loop pass.

## What I verified myself

**The existing app is unharmed (items 1–6)**
- `node test/tests.js` → **492 passed, 0 failed**. Run twice under
  `America/New_York`, `Europe/London`, `Australia/Sydney`, `UTC` — eight green runs,
  identical counts, no flake.
- `node test/lint.js` → all clear, **17 rules**, exit 0.
- `appsscript.json` is byte-identical to `main` (`git diff main..HEAD` empty). Three
  scopes, matching item 6 as amended.
- Nothing pushed. `main` untouched. One dev dependency on the branch (`playwright`,
  pinned exact at 1.62.0), justified by stage D.

**Lost writes are findable (items 7–13, 24)**
Driven in a real Chromium at a 390×844 phone viewport, seeding the dead list and
clicking at fixed screen coordinates:
- 2 taps at one point → exactly 1 entry gone, and it is the one that was aimed at.
- One tap arms and says `TAP AGAIN TO DISCARD`; it discards nothing.
- Arm, wait past the confirm window, tap again → **does not discard**, it re-arms.
- Arm a row, close the drawer, reopen, single tap → **does not discard**.
- Arm a row, let a new set-aside write land and re-render, tap the same point →
  **does not discard**.
- Discard one, reload → it stays gone. Discard all → banner hidden, drawer closed,
  and after a reload the banner is still hidden and the boot message does not return.
- The queue is byte-identical after a discard — nothing in the drawer reaches a
  pending write.
- Corrupt dead lists (`not json`, `{"a":1}`, `null`, `[null,null]`, `[{"at":"x"}]`)
  produce no page errors; the unreadable ones show no banner, the malformed rows
  render as "unknown time / unknown category".

**The rollup admits it failed (items 14–18, 25)**
I patched the sheet shim myself to throw inside `setValues` on a tab of my choosing,
which is a different injection point from the one `§39e` uses:
- Break the **second** tab written: run throws, the weekly tab is byte-identical to
  before — 15 rows, still there, **not blanked** — and still carries its own older
  stamp (`09:00`) while the daily tab carries the newer one (`12:00`). Item 16 and
  item 25 both hold, with the two stamps visibly different.
- Break the **first** tab written: the whole book is identical to before. Nothing
  moved.
- Break `weeklyGrid_` at build time: the whole book is identical to before — which is
  what building both grids before writing either one buys.
- A healthy run afterwards restores both tabs, exactly one stamp per tab.
- `rollupStatus()` prints last run, last success and last failure with its reason.

**The machine can see the screen (items 19–23)**
- `node test/headless.js` → green. Phone 390×844 and desktop 1280×800, 17 smoke
  checks passed / 0 failed at each, 3 meta tags matching `doGet`, plus the drawer
  phase.
- Meta-tag drift, one side only: lint fails and names it —
  `mobile-web-app-capable — same tag, different content: doGet has "no",
  test/headless.js has "yes"`.
- Zero checks in `smoke.js` → headless exits **1** ("Found no checks in test/smoke.js
  to run"). Playwright removed → exits **1** with install instructions. A skipped run
  is never a pass.
- `deploy.sh` with a stub `clasp` first on `PATH` and a dummy `.clasp.json`, in a
  throwaway copy of the tree: breaking lint, breaking the offline suite, and breaking
  the headless layer each exit **1** with `Nothing deployed.`, and the stub clasp is
  **never called once**. The real `.clasp.json` was never read and no deployment
  happened.

**Amendment A1, checked at its factual root.** A1 retires D2's sixth criterion on the
claim that no check in `smoke.js` is viewport-sensitive. I rendered the page with and
without the meta tags and ran the real `smoke.js` in each:

| metas | layout width | smoke |
|---|---|---|
| present | 390px | 17 pass, 0 fail |
| absent | **980px** | **17 pass, 0 fail** |

The claim is true. At 980px the page is definitively the wrong document and every
check still passes. The criterion could not have been met without changing
`smoke.js`, and the human's ruling rests on a fact, not on convenience.

**Contract tampering check.** `HANDOFF.md` has been edited exactly twice on this
branch. The fix commit's diff against it contains only: item 6 rewritten (one scope →
three), item 16 rewritten (per-tab honesty), assertions 24–27 added, the amendments
section added, and one orientation-table row corrected. Nothing weakened, nothing
deleted, nothing reinterpreted. The three amendments match the three decisions
recorded in `STATE.md` as the human's.

**Landmines.** No secrets, no API keys, no deployment ids in the diff. No TODO, FIXME
or stub left behind in `Code.gs`, `Index.html`, `deploy.sh` or the test files. One
dependency added, pinned, dev-only. No file changed outside the round's scope. No
tracked file contains a NUL byte.

## Findings (worst first)

### 1. Discarding a row still slides the next row's button under the finger — assertion 24's second sentence is unmet, and the comment explaining the fix says the opposite

- **what happens:** Assertion 24 says "Discarding a row must not move another row's
  controls into the space it vacated." It still does. The fix stopped removing and
  rebuilding the whole list, but removing a single row from a flex column moves every
  row below it up by exactly the same amount. What actually prevents the data loss is
  the new arm/confirm, not the absence of movement. The practical consequence: two
  taps at one point destroy one write (correct, intended), **four taps destroy two,
  and six destroy three** — each extra pair landing on a row that slid under the
  finger and confirming it.
- **how I proved it:** In Chromium at 390×844 with five seeded entries, reading the
  DISCARD buttons' y-positions before and after a discard:

  ```
  before: [153, 303, 452, 602, 751]
  after : [153, 303, 452, 602]
  elementFromPoint at the original finger point, after the discard:
      BUTTON of row token=4|3|setMark|r3  text="DISCARD"
  ```

  and, tapping the same fixed point N times, 90ms apart:

  ```
  taps=2: 5 entries -> 4 left (destroyed 1)
  taps=3: 5 entries -> 4 left (destroyed 1)
  taps=4: 5 entries -> 3 left (destroyed 2)
  taps=6: 5 entries -> 2 left (destroyed 3)
  ```

  The false comment is [Index.html:812](Index.html:812)–817: "The discarded row is
  removed on its own, and the list is NOT redrawn… Nothing may move while a finger is
  down." The last sentence is the rule the code does not implement.
- **severity:** should fix. The bug round 1 found — an ordinary accidental double tap
  silently destroying a second, unread write — is genuinely gone, and every further
  destruction now costs its own deliberate confirm against a button that reads `TAP
  AGAIN TO DISCARD`. This is a contract sentence that is not true of the code, and a
  comment that will mislead the next person to touch this, more than it is a live
  hazard.
- **suggested next step:** this is the one genuine decision in this review — see
  *Decisions for you*, question 1.

### 2. The NUL-byte rule guards 14 named files, not "any file in the repo"

- **what happens:** Assertion 26 reads "Given **any file in the repo**, then it
  contains no NUL byte", and `progress.md` calls it "a lint rule over every text
  file". The rule's list is seven named root files plus a non-recursive read of
  `test/`. A NUL landing in `factory/`, `site/`, `.github/`, `test/fixtures/`,
  `.gitignore`, `.claspignore` or `package-lock.json` passes silently — the same
  invisible-to-review condition that hid `test/headless.js` for a whole round.
- **how I proved it:** appended one `0x00` byte to `factory/log.md`, confirmed it was
  there, then ran the linter:

  ```
  factory/log.md now has a NUL: true
  all clear
  lint exit=0
  ```

  (file restored immediately; `git status` clean.)
- **severity:** should fix — small, and it is this round's own rule falling short of
  its own wording.
- **suggested next step:** replace the hand-written list with the tracked file list
  (`git ls-tree -r --name-only HEAD`), skipping anything genuinely binary. One line,
  and then the assertion says what the rule does.

### 3. The scope-count rule reads two files, and two live docs still state the wrong count

- **what happens:** Assertion 27 reads "Given the docs, then **no sentence anywhere**
  states a scope count that disagrees with `appsscript.json`." The rule scans
  `README.md` and `SETUP.md` only. Two documents still carry the old claim:
  `factory/BRIEF.md:71` — "Manifest, one OAuth scope." — and `factory/PLAN.md:33` —
  "`appsscript.json` still asks for exactly one OAuth scope." BRIEF's orientation
  table states it as a current fact about the repo, which is how the wrong number got
  copied into a build contract in the first place.
- **how I proved it:** grepped every stated scope count in the repo with the rule's
  own regex; both lines are present, and `node test/lint.js` is clear.
- **severity:** cosmetic. (`factory/REVIEW.md`, `log.md` and `progress.md` also quote
  the old sentence — correctly, as historical record. Those should stay.)
- **suggested next step:** correct BRIEF.md:71 and PLAN.md:33, and widen the rule to
  every `.md` outside the deliberately historical files.

### 4. The suite crashes, rather than skips, in any timezone outside the contracted four

- **what happens:** `§39d` looks up a golden fixture by script timezone. There are
  four. In a fifth zone the check fails and then the very next line throws, aborting
  the run before the sections after 39d execute — so a developer in, say, India gets
  a stack trace and a partial run rather than a clear "no golden for this zone".
- **how I proved it:**

  ```
  $ TZ=Asia/Kolkata node test/tests.js
  39d. the stamp shifts no row and no column that was there before
    FAIL there is a golden for this timezone
           Asia/Kolkata
  TypeError: Cannot read properties of undefined (reading 'days')
      at .../test/tests.js:1724:21
  ```

  Same in `Pacific/Chatham`. All four contracted zones are green.
- **severity:** should fix — small. Contract item 2 names four zones, so this is not
  a contract violation; it is a sharp edge on the suite itself.
- **suggested next step:** guard the section on `gz` — skip it with a named reason
  when there is no golden for the running zone, the way `smoke.js` reports skips.

### 5. `progress.md`'s "Parked questions" section still reads as an open question

- **what happens:** The section ends "**Your call: accept the layout-fact control, or
  add a genuinely viewport-sensitive check to `smoke.js`?**" That call was made
  (amendment A1). The top of the same file says so, but a reader who jumps to the
  parked section sees a live question that has been closed.
- **how I proved it:** `factory/progress.md:103-109` against
  `factory/HANDOFF.md:327-339`.
- **severity:** cosmetic.
- **suggested next step:** mark it *ruled 2026-07-27, amendment A1* in place.

## Parked work

Nothing is parked. All 13 tasks are `done`; D2's sixth criterion is retired by human
decision, and I verified the fact that ruling rests on (see amendment A1 above).
Nothing the contract's top assertions depend on has been deferred.

Two small things I looked at and am **not** raising as findings, recorded so the next
review does not re-derive them:
- If the dead list is emptied in another tab while the drawer is open, tapping DISCARD
  leaves the row on screen and the banner counting entries that no longer exist. Not
  reachable on a phone, where there is one document.
- `deadToken` is `at|op.id|op.type|op.ref`. Two entries set aside in the same
  millisecond with identical op fields would collide, and the storage splice and the
  DOM removal would then pick opposite ends of the list. The rows are identical, so
  nothing observable goes wrong.

## Decisions for you

### 1. Assertion 24's second sentence: should the rows actually hold still, or should the sentence say what you meant?

Both readings pass the first sentence, which is the one about user harm, and both are
already true today. The second sentence — "discarding a row must not move another
row's controls into the space it vacated" — is a statement about *mechanism*, written
during round 1 before the arm/confirm existed, and the build met the goal by a
different route.

- **Option A (recommended): amend assertion 24 to describe the guard you have.** Keep
  "exactly one entry leaves, and it is the one under the finger", drop the
  no-movement clause, and add "no entry can be discarded without its own arm and
  confirm on a button that says so". Then fix the comment at Index.html:812 to
  describe arm/confirm as the guard, and add a tier-3 check that four rapid taps at
  one point destroy at most two entries and that the second one was armed and
  labelled first. Cheapest, and it pins the property that actually protects the data.
- **Option B: make the rows genuinely hold still.** Leave the discarded row in place
  as a spent slot until the drawer is closed and reopened, so nothing below it ever
  moves. Satisfies the sentence literally and makes any number of taps at one point
  destroy at most one write. Costs a visible artefact in the drawer — an empty gap —
  which is new interpretation on screen and needs a decision about what it says.

My recommendation is A: the harm the assertion exists to prevent is verified gone in
a real browser, and B buys strictly less than it costs in screen furniture.

## Close out

Findings 2–5 are facts and need no decision — they belong in a fix list. Finding 1
needs your answer to the question above before it can be written as a criterion.
`STATE.md` is updated to stage 5 (one more loop pass) with these as the fix list.

A code-level review is a different net from this one — this graded contract
compliance, not implementation quality. `/code-review` on this branch would be worth
running before the proof video.
