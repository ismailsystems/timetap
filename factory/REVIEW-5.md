# Review: the FIXES-4 pass — 2026-07-29

Reviews 1 and 2 are round 1's (`REVIEW.md`, `REVIEW-2.md`). Review 3 is round 2's
(`REVIEW-3.md`). Review 4 is the redesign's (`REVIEW-4.md`). This is the fifth,
and it reviews the fix pass that answered the fourth.

**Under review:** `2a15553..HEAD` — 12 commits of work, plus the commit that wrote
the record and the commit that wrote review 5's own prompt. Eleven files carry the
work. It claims to close all 24 items in `factory/FIXES-4.md`.

**How it was run.** Three independent reviewers, none given the builder's
reasoning and none given each other's findings: one on whether it fixed what it
claimed, one on what the fixes broke, one on how it fails a user. Each measured
rather than read. Every finding below was then **reproduced a second time, by
hand, by the reviewer who assembled this file**, in a fourth clean clone —
including the ones that turned out to be regressions, which were re-run against
`2a15553` to prove the pass caused them. The builder's own account
(`factory/log-2.md`, `factory/STATE.md`, the commit messages) was read only at
the very end, and it is compared against the findings in the last section.

---

## Verdicts

| Reviewer | Verdict |
|---|---|
| did it fix what it claimed | **SHOULD NOT SHIP** — all 24 items are substantively fixed, but the project's own gate is red |
| what the fixes broke | **SHOULD NOT SHIP** — the fix for A3 introduced a silent data-loss path |
| how it fails a user | **SHOULD NOT SHIP** — a keyboard or VoiceOver user can double-bill the record |

**The pass is real work and it is not finished.** All five of REVIEW-4's blocking
faults are genuinely gone, re-reproduced from the review's own descriptions
rather than from the suite, and each fix is caught by a mutation. Twenty-two of
the twenty-four items close exactly against their written criteria. What blocks
is three things: one new data-loss path the fix for the sitting created, one gate
that fails for a third of every day, and one corruption path that predates the
pass and that nobody has found until now.

---

## Blocking

### C1. Undo throws the sitting away when the writes are still queued

The user is offline. They are sitting. They mis-tap — STOP, or BODY — which
closes the sitting, so the footer now reads `NOT SITTING` while they can see they
are sitting down. They tap the footer to say so. Then they notice the ribbon and
tap UNDO.

`takeUndo` drops the queued `closeSit` for the original sitting, enqueues a
`closeSit` for the new one, and points `S.sit` back at the original
(`Index.html:1261-1265`). But the **`openSit` for the new sitting is still in the
queue**, and when it reaches the server `opOpenSit_`'s self-healing closes the
original one on its way in (`Code.gs:1041-1045`). Nothing reopens it. The footer
then claims `SITTING` for the rest of the session against a calendar with no open
SIT block, and a reload discards the claim for good.

```
offline · sitting since 9:00 · DW running · mis-tap BODY · sit again · UNDO

  after the mis-tap  : footer = stand   ribbon = "SWITCHED TO BODY"
  after sitting again: footer = sit     queue = [closeActual,openActual,closeSit,openSit]
  after UNDO         : footer = sit     queue = [openSit,closeSit]
  two hours later    : the footer says SIT
  SIT calendar       : "SIT" 09:00-09:50 | "SIT" 09:50-09:50
  open SIT blocks    : 0
  sitting recorded   : 50 minutes of the 170 the app claims
  after a reload     : STAND          <- the claim is gone for good
```

**This is a regression.** The same script against `2a15553`:

```
  SIT calendar       : "SIT" 09:00-09:50 | "SIT" 09:50-09:51 OPEN
  open SIT blocks    : 1
  after a reload     : SIT
```

Before the pass, undo had no sitting branch, so `S.sit` went on pointing at the
new sitting — which really was open. The footer and the record agreed. The fix
for A3 made the footer right in the case it was written for and wrong in this
one, and this one loses data.

The trigger needs the second posture tap and the undo both inside the ribbon's
five seconds. A randomised walk of 700 sessions found it once without being told
where to look.

### C2. `node test/headless.js` is red for the first ten hours of every local day, and `deploy.sh` stops on it

The new D2 phase seeds a day of `n` fifteen-minute blocks counting **backwards
from now** (`test/headless.js:1687-1695`), so 40 blocks reach 10h15m back.
`railBlocks` correctly drops every block that ended before local midnight
(`Index.html:1741-1742`) — which is F4's midnight fix. Before about 10:15 local,
most of the fixture is yesterday, the rail assembles 20-something segments
instead of 41, and the phase's own honesty guard fires and exits non-zero.

```
local 05:02 CDT  node test/headless.js                    exit=1
  40 blocks: rail drew 21 segments, last ends at 728.3px of 844
  phone 390px, 40 blocks: the rail drew 21 segments for a day of 40 blocks,
    so this was never the screen the check below is about

local 19:02      TZ=Asia/Tokyo node test/headless.js       exit=0
  40 blocks: rail drew 41 segments, last ends at 728.3px of 844, NOW ▲ at 746.3px
  headless: ok (26 checks per viewport)

local 00:03      TZ=Pacific/Honolulu node test/headless.js exit=1
  40 blocks: rail drew 1 segments        (the 20-block phase fails too)
```

Two consequences, and the second is worse than the first. `deploy.sh:92-94` runs
this and `die`s — "headless checks failed. Nothing deployed." — so a morning
deploy is refused with a message that reads like a product fault. And FIXES-4's
"Done means" requires *headless ok*, which means **D2 is unverified whenever the
gate is red**. The product itself is right: measured in a timezone where the
phase can assemble, 41 segments, the last ending at 728.3px of an 844px screen,
`NOW ▲` at 746.3px inside a rail column ending at 758, six category rows visible,
and no page scroll. Fix the fixture, not the rail.

### C3. Behind an open sheet, a keyboard or VoiceOver user can bill the same minutes twice

The three sheets are opaque, and they are not modal. `.view` (`Index.html:264`)
is `position:fixed; inset:0` over `var(--ground)` with **no `role`, no
`aria-modal`, no `inert`, and no focus management**, and they sit *after* `#app`
in the document (`Index.html:417,427,448`). `Escape` closes nothing.

```
Chromium, 390x844, SPLIT opened by re-tapping the running row:

  sheet   : {"open":true,"opacity":"1","pos":"fixed","role":null,
             "ariaModal":null,"inertAttr":false,"appInert":false}
  covered : stopBtn -> sheetSplit   MTG row -> sheetSplit   (touch cannot reach them)
  tab order with SPLIT open:
     1. note   2. DW  3. MTG  4. ADM  5. BODY  6. REL  7. FRAG  8. DIV
     9. postureBtn   10. stopBtn        <- all ten are BEHIND the sheet
    11. spClose  12. spRange  ...       <- the sheet's own controls start here
  escape closes it? false
```

`doSplit` states the invariant it relies on in its own comment
(`Index.html:1902-1905`) — *"The sheet closes when the block it names stops being
the one in hand"* — and nothing enforces it. `closeBlockSheets` is called from
`quarantine` (`:831`) and `adoptServerState` (`:2011`) only. `tapCategory`,
`endDay` and `toggleSit` never call it. So the tenth Tab ends the day with the
SPLIT sheet still on screen, and the third Tab switches the block while the sheet
goes on naming the old one and holding its start:

```
  SPLIT open, spLab "OPEN BLOCK · DEEP WORK", DW started 09:00
  tap MTG behind the sheet
    -> SPLIT still open, spLab still "OPEN BLOCK · DEEP WORK"
    -> the block in hand is MTG, started 09:43
  pick ADM as the remainder in the stale sheet, and the calendar becomes:
      "DW: ="  09:00-09:43   43m
      "ADM:"   09:22-09:43   21m  OPEN   <- opens 21 minutes before its own block began
      "MTG:"   09:43-09:44    1m
  21.0 minutes of DEEP WORK also billed to ADMIN. Zero errors.
```

`opSplitActual_` accepts the backwards cut (`Code.gs:1020-1036`) and
`endEventAt_` clamps it (`Code.gs:621-627`), so it lands clean. The undo ribbon
is armed the whole time, and `elementFromPoint` at its centre returns
`sheetSplit` — the way back is under the sheet and expires there.

**This predates the pass.** The identical script against `2a15553` produces the
identical calendar, and `.view` had no `aria-modal` there either. It is here
because it is live, because REVIEW-4 did not find it, and because D1 — making the
ribbon `tabindex="0"` — is the first thing in the redesign that invites a
keyboard into this surface. It needs Tab-based navigation: an external keyboard,
iOS Full Keyboard Access, or VoiceOver's swipe navigation, which walks exactly
the tree above because nothing is `aria-modal` or `inert`. It is not reachable by
touch.

---

## Should fix

**The undo path**

1. **When the server declines the whole undo, nothing tells the screen.** All
   three reviewers found this independently. `opUndoSwitch_` correctly returns
   early when another device has moved or closed the block (`Code.gs:966`), but
   `takeUndo` has already rewritten `S.open` optimistically (`Index.html:1252`),
   the compensating op is fire-and-forget, and `flush()`'s success handler never
   re-reads state (`Index.html:719-737`). `refreshOnReturn` needs ten minutes
   *and* a visibility change (`:2067-2073`).

   ```
   the mis-tap landed   : "DW: =" 09:00-09:40 | "MTG:" 09:40-09:41 OPEN
   the other device     : "DW: =" 09:00-09:40 | "MTG:" 09:40-09:40
   after UNDO, calendar : unchanged, open blocks = 0
   the screen says      : DW · Deep work · 40m · GOOGLE CALENDAR · SYNCED
   fifty minutes later  : DW · 1h30, and the calendar still ends at 09:40
   the next switch      : "ADM:" 10:30 OPEN — the 50 minutes are on no calendar
   ```

   B1's criterion says undo "leaves exactly one open block on the calendar —
   never two". Never two holds in all eight second-device variants driven. It
   leaves **zero** here, and the screen claims one. Smallest honest repair: one
   `loadServerState()` after an `undoSwitch` lands.

2. **Undo of a category switch closes a sitting that predates the switch.**
   `Index.html:1266-1282` calls `closeSit(now)` whenever the restored block is
   BODY and the undo closed no sitting of its own. Its comment says *"The sitting
   closed here is one the user opened AFTER the switch"* — that is not what the
   code does.

   ```
   HEAD      BODY running, tap posture (BODY+SIT open at once), switch to DW,
             UNDO  ->  running BODY, sit open 0, SIT written 09:05-09:25
   2a15553   the same steps  ->  running BODY, sit open 1, SIT 09:05-09:06 OPEN
   ```

   A regression, and posture has no undo, so there is no way back. The handoff's
   coupling does say *"opening Body … or undo … closes any open SIT"*, so an
   argument for the behaviour exists — see "Decisions for you".

3. **`dropOps`' all-or-nothing half is asserted nowhere, and the state it guards
   is reachable.** `Index.html:1318` `if (hit < n) return false;`. Weaken it to
   `if (!hit) return false;` and the suite is still `1101 passed, 0 failed`.
   `applyOps` stops at the first failing op, so the half-landed state is real:

   ```
   server refuses openActual only:
     queue after the half-landed flush : [openActual]
     calendar                          : "DW: =" 09:00-09:40   (closed, no MTG)
     UNDO -> queue [openActual, undoSwitch]      <- the real code compensates: right
     drains to "DW:" 09:00-09:40 OPEN, screen DW, reload DW
   with the guard weakened: the calendar keeps "DW: =" closed and the undo
     silently did nothing; the screen says DW until a reload says null.
   ```

4. **The rail draws the reopened block twice when a state refresh lands inside
   the undo window.** `railReopen` matches on `ref` (`Index.html:1734`), and
   `getState`'s `today` rows carry only `key`, `startMs`, `endMs` — no `ref`
   (`Code.gs:694`). Once `adoptServerState` has replaced `S.today`, the row
   cannot be found.

   ```
   2 closed + 1 open                  : 3 segments
   switch to PEOPLE                   : 4 segments, ribbon up
   a foreground refresh lands here    : 4 segments, ribbon still up
   UNDO                               : 4 segments   <- the calendar has 3 events
   the calendar: "DW: =" 09:00-09:40 | "MTG: =" 09:40-10:10 | "ADM:" 10:10-10:32 OPEN
   ```

   Display only, and it self-repairs on the next refresh. The rail overstates the
   day by that block's duration while it lasts.

**Reach and accessibility**

5. **The two sheet sliders have no accessible name and no readable value.**
   `Index.html:435` and `:455` are bare `<input type="range">`. A screen reader
   announces `slider, 344` while the screen reads `4:45 AM`. `#sitEdit`'s
   `aria-label` likewise overrides the `1h01` inside it, so the sit duration is
   never spoken, and the three mark buttons are announced as `+`, `=`, `−` with
   no link to `#stripHead`.

6. **At `MAX_CATEGORIES` with both guardrails up, half the list is off screen and
   nothing says so.** `#grid { flex:1; min-height:0; overflow-y:auto }`
   (`Index.html:140`) is the deliberate A2 fix and it is the right trade — the
   list gives way, the guardrail does not. The residue is that
   `grep -c scrollIntoView Index.html` is **0** and there is no fade or
   persistent scrollbar:

   ```
   10 categories, 40 blocks, sitting, 2 set aside, after a switch:
     grid box 330.4px, content 560px, scrollable true
     hidden: Fragments, Reading, Errands, Practice, Correspondence
   with category 10 running: 9 of 10 rows on screen, and the LIT one is not
     among them — so the app opens with nine rows and none of them lit, and the
     row you would re-tap to reach SPLIT is not there.
   ```

7. **The reflex double tap still destroys the way back.** REVIEW-4's finding 17,
   which FIXES-4 did not carry. `openSplit` calls `clearUndo()`
   (`Index.html:1856`) by design, and round 1 taught users to double tap.
   Related: a tap 12px below the ribbon lands on `#err` and opens SET ASIDE
   **over** an armed ribbon, which then counts down invisibly under the sheet.

**The record about itself**

8. **`test/README.md` still documents the retired lint rule as live.** The file
   is untouched by the pass. Line 61 lists *"the correction window nests inside
   the confirm window"*, retired this round. The two assertions the pass added
   are documented nowhere, and neither are the four new smoke checks.

9. **`test/lint.js`'s retire comment gives the wrong reason.** `:356-363` says
   the rule *"cannot fail, and a rule that cannot fail is worse than no rule"*.
   Run against this tree it fails loudly:

   ```
   against HEAD     MISTAP_SECONDS = 20  CONFIRM_WITHIN_SECONDS = null
                    FAIL -> could not read CONFIRM_WITHIN_SECONDS out of Code.gs
   against 2a15553  MISTAP_SECONDS = 20  CONFIRM_WITHIN_SECONDS = 60   PASS
   ```

   Retiring it was right and the contract asked for it. The reason recorded for
   it is not the reason.

10. **D2's fix is pinned only by the phase that does not run in the morning, and
    its two halves cover for each other.** Nothing in `test/tests.js` can see the
    rail's height. `railBudget()` returning the old constant, the share cap alone,
    or the total scaling alone each leave **both** layers green; only removing
    both turns the headless phase red — and only after 10:00.

---

## Cosmetic

- **F4's "the chip that never shows `0`" was not done.** `Index.html:1208` is
  byte-identical to `2a15553`, and the diff touches `#undoChip` only to add
  `aria-hidden="true"`. Measured `5 5 5 5 4 4 4 4 3 3 3 3 2 2 2 2 1 1 1 1`, never
  `0`. `test/tests.js:4341` now *pins* `/^UNDO · [1-5]$/`, which enforces the
  reported behaviour rather than repairing it.
- `test/headless.js:1853` prints `headless: ok (26 checks per viewport)` when 24
  ran and 2 skipped. The total is verified (`:1341` sums pass + fail + skip
  against the file's own `ok(` count), so nothing can vanish — but the printed
  line overstates what happened, and the two skips are never named.
- `test/headless.js:1747` guards `g.count < blocks`, where the honest count is
  `blocks + 1` — n closed segments plus the open one. A rail one segment short
  passes; at 20 blocks it drew 20 and the guard stayed quiet.
- The landed variant of C1 leaves a two-second SIT block overlapping the reopened
  one (`"SIT" 09:00-09:50 OPEN | "SIT" 09:50-09:50`). `dayStats_`
  (`Code.gs:1400-1403`) sums sit events without merging overlaps, so it
  double-counts that span.
- `validOp_` (`Code.gs:790-793`) accepts the STOP undo's `newRef: null` only
  because `String(null)` is `"null"` — four alphanumeric characters that happen
  to satisfy `/^[A-Za-z0-9]{4,64}$/`. Tightening that regex would silently drop
  every STOP undo and report it applied.
- `#postureRow` carries `cursor: pointer` (`Index.html:241`) and has no click
  listener. The design's *"Row tap toggles sitting"* is not implemented — safer
  than the alternative, but the cursor is a lie.
- `#spGridLab` reads `REMAINDER IS`; the handoff says `REMAINDER BECOMES`.
- The note box is `354x38` — 6px under the 44px floor, and the only control that
  is.
- Past midnight the same block reads `2h30` in the NOW panel and `1h30` on the
  rail, with nothing saying why. Both are correct; nothing explains the pair.
- The ribbon moves 38px up when the error banner is present (652..708 against
  690..746), so where UNDO appears depends on whether writes are set aside.
- Focus drops to `BODY` when the ribbon expires under it. One Tab recovers.
- The Add row is clipped out of the scrolling grid while the mark strip is up
  (grid box 240.6..609, Add row 576.6..624.6). It returns when the strip
  dismisses.

---

## Not counted against this pass

Reproduced, real, and present at `2a15553` — recorded so they are not found
again as if new.

- **A reload with an undrained queue empties the rail.** Four segments before,
  one after, and coming back online does not restore it, because `flush()`
  success never re-reads state. Identical at `2a15553`, where `today` *was*
  persisted but `boot()` never read it back — so B4 took nothing with it.
- **`opCloseSit_` has no already-closed guard**, unlike `opCloseActual_`. Once
  the screen has diverged, standing up stretches a closed SIT block:
  `"SIT" 09:00-09:50` becomes `"SIT" 09:00-12:50`.
- **BODY and an open SIT at once is reachable in two taps** — tap BODY, then tap
  the footer. `toggleSit` has no BODY guard and is byte-identical to `2a15553`.
  It survives a reload. This matters because should-fix 2 depends on it.

---

## What is right, for calibration

**All five of REVIEW-4's blocking faults are gone**, re-reproduced from the
review's own descriptions rather than from the suite, and each one is held by a
mutation that turns the suite red: A1 twelve failures, B1 and A4 four each, A3,
B2 and B3 three each, B4 two.

- **A1**, end to end and in the hard direction. UNDO *inside* the flight window
  at 100, 600, 1200, 2500 and 4000 ms: the compensating op is always emitted, the
  calendar ends `"DW:" 09:00-09:40 OPEN` — one open block, the original start,
  the auto-mark stripped, no trace of MEETINGS — the queue empties, no write is
  set aside, and a reboot agrees. `dropOps` now carries the `flushing` guard and
  counts distinct non-null ids, so `dropped < 2` can fail.
- **A2 and D3**, sixteen states in Chromium at 390×844 (6/7/8/10 categories ×
  plain / error banner / sitting / both): the ribbon is **56 of 56px** on screen
  every time and `elementFromPoint` at its centre returns `undo`; all three mark
  buttons are 44×44 and each hits itself. A tap 2, 4 and 11px below the ribbon
  hits `#bottom`; 13px reaches the posture row. An 11px dead zone from
  `margin-bottom: 12px`, present only while the ribbon is.
- **A3 and A4.** Sitting → mis-tap BODY → UNDO restores the SIT with its
  **original start, byte-identical**, footer `SITTING`, `aria-pressed="true"`.
  Same on the STOP path. BODY → switch → sit → UNDO gives BODY open and no SIT.
- **A5.** One tap ends the day; `stopBtn` keeps the label `STOP` and never gains
  `arming`; the ribbon reads `STOPPED — NOW UNLOGGED` byte-exact;
  `grep "TAP AGAIN"` over `Index.html` and `Code.gs` finds two lines, both the
  drawer's — `DISCARD_ARMED` and the comment explaining it.
- **B1's letter holds in all eight second-device variants** — closed, moved,
  deleted, deleted-and-replaced, stopped, retitled, previous-block's-end moved —
  and on the sitting half. Never two open blocks.
- **B3.** 9:00–11:00, 9:30–10:00 and 11:00–11:30 draw `DEEP WORK 2h00 |
  MEETINGS 30m | ADMIN 30m` with **zero** hatched segments.
- **B5.** The drawer row reads `9:41 AM · DEEP WORK / tried to take back a
  switch, block started 9:00 AM / the server said no` — the real start time,
  plain words, no op name, no epoch date — and the grid stops claiming the block
  the undo failed to restore and shows the one the calendar really has.
- **B6.** Offline STOP → UNDO, switch → UNDO, and sitting → BODY → UNDO all
  leave **no `undoSwitch` in the queue**.
- **C1 to C6 are byte-exact**: `OPEN BLOCK · DEEP WORK`, `20m stays DEEP WORK ·
  23m becomes ↓`, `DEEP WORK · 43m — MARK IT`, `4:52 PM · MEETINGS`,
  `SET ASIDE · 2`, `sitting for 16m if applied`. `#splitGrid` holds exactly five
  rows and none of them is Deep work, rebuilt per block. The mark strip label
  needs 160 of 230px, and 204 of 230 at the longest configured name; a 24-char
  name — the app's own cap — clips at a stated 230px with a real ellipsis.
- **C2 is measured, not asserted.** Seventy-nine `.tnum` observations across five
  screen states, including both sheets open and the rail's runtime `.segDur`
  spans, all compute `tabular-nums`. Deleting the rule turns the headless run red
  naming `undoChip=normal`.
- **D1.** `role="button" tabindex="0"`, reached in eleven Tabs, `aria-label`
  = `undo: SWITCHED TO MEETINGS`, and `#undoSay` — a polite live region present
  and unhidden at rest — announces `SWITCHED TO MEETINGS — undo available for 5
  seconds` **once**, not on every tick. Enter, Space and `' '` each take the
  undo. The chip is `aria-hidden`, correctly.
- **D2's product half is right**, at 20, 40, 60 and 80 blocks.
- **D4.** The Add row's position is stated where the old rule used to live and
  pinned by section 27d, including after a runtime `addCategory`.
- **E1** sweeps all 121 seconds and asserts every one of those taps really
  switched, so the sweep cannot pass on a build where nothing happens. **E2**
  runs the note check offline and adds the positive control. **E3** is a
  strengthening rather than the requested literal: `INIT_CLS` is now derived from
  the markup, so it cannot drift, and the three ids the old literal named but the
  derivation drops have zero occurrences in `Index.html`. **E4** names each of
  the four orphaned assertions with the section that inherited it — `50f`→74,
  `50g`→68, `52k`→66g, the note→75, all four of which exist and assert the
  property — and names what deliberately has no successor, with reasons.
- **F1.** Zero live references to `arm(`, `willRetitle`, `confirmLabel`,
  `CONFIRM_RETITLE/SWITCH`, `colsFor`, `layoutCells`, `#syncN`. `armed` survives
  only in comments and in the drawer's DISCARD, which the design keeps.
- **F2.** `MISTAP_SECONDS` is load-bearing, not merely surviving: a block five
  seconds old across midnight is left alone and one twenty-five seconds old is
  bounded. Its value is still pinned, through `SETUP.md`. `clientConfig_` ships
  neither retired value. `codeNoComments` still feeds five other rules, so the
  retirement took no other check with it.
- **F3.** The rail says it in words: `group "today so far, drawn to scale":
  12:00 AM DEEP WORK 59m UNLOGGED 2h00 MEETINGS 30m UNLOGGED 47m DEEP WORK 43m
  NOW ▲`.
- **F4.** The midnight rail is fixed and fixed live: at 00:15, with the app open
  the whole time and no reload, `railStart` resets to `12:00 AM` and yesterday's
  blocks leave the rail. A 30-second block reads `<1m`, not `0m`. `pump()` now
  **throws**, with a message that says the cap is the bug and not the app — the
  cleanest repair in the group.
- **The compensating op is idempotent on all six shapes** — switch, switch into
  BODY, switch from idle, STOP with a block, STOP with block and sitting, STOP
  with only a sitting — applied twice and three times, changing nothing.
- **Retry and quarantine semantics are preserved.** Twelve offline flush attempts
  leave `tries=[0,0]` and no dead letter; with the server rejecting, the head op
  reaches `tries=5` and is set aside while the op behind it keeps `tries=0`.
- **`S.today` and `S.lastTapMs` are cleanly gone.** `tt.state.v1` holds exactly
  `open,sit` and is **93 bytes** after 120 offline switches. Nothing reads either
  back on any of five reload paths — clean, undrained queue, dead letters
  present, ribbon up, just after midnight — because pre-fix `boot()` never read
  `saved.today` either. `lastTapMs` had exactly two readers, both deleted with
  the mechanism.
- **A cross product of 32 undo cells** — eight actions × four write states — and
  a separate 21-cell table of the awkward dimensions, plus 700 randomised
  sessions, produced exactly one wrong invariant, which is C1. The same fuzz
  against `2a15553` produces none, which is how C1 was known to be new.
- **Measured, twice, in four timezones: 1101 passed / 0 failed**, eight runs. The
  count of `ok` lines equals 1101 exactly, so `passed` is not inflated, and there
  are zero skips. A fifth zone skips sections 39d and 46 by name and counts
  neither anywhere near `passed`. `node test/lint.js` all clear on 20 rules, each
  of which I confirmed can fail. `appsscript.json` and
  `test/fixtures/rollup-golden.json` are sha256-identical to `a256bdf` and appear
  in no commit in the range.

The suite is green, it is much stronger than it was, and it is still not enough —
which is the same finding review 4 ended on, and it is still the one that matters
most.

---

## The builder's account against what was found

Read last, on purpose. `factory/log-2.md`'s "The FIXES-4 pass" section and
`factory/STATE.md`'s new notes are detailed and mostly accurate, and they name
four things the pass added to the list and three checks it wrote that could not
fail — self-reporting that no reviewer would have found. Five claims do not hold.

| the record says | what is true |
|---|---|
| "Headless ok at both viewports" | Red before ~10:15 local, and `deploy.sh` stops on it. C2. |
| "Body-and-sitting-at-once is unreachable" | Two taps reach it — tap BODY, tap the footer — and it survives a reload. No test asserts it. |
| "Lint clear on 20 rules — one retired, one added" | 21 → 20. **No rule was added**; two assertions were added inside a rule that already existed. log-2.md's own detail bullet says "extended", which is right; the headline is not. |
| "26 smoke checks each" | 26 exist, 24 run, 2 skip. |
| "Nine commits" | Twelve commits of work, plus the record. |

"Three new phases" is fair in substance — three new groups of checks, in two new
phase functions.

Nothing in the account is dishonest and nothing hides a fault. But "headless ok"
is the claim the contract's "Done means" turns on, and it was not true on the
machine that ran this review at the hour it ran.

---

## Decisions for you

Only genuine open questions are here. Everything above is a fact with a
reproduction.

1. **C1 — whose intention wins.** When the user re-sits after a mis-tap and then
   undoes, two things they did are in conflict: the sitting they just started and
   the sitting the undo is putting back. The repair can drop the queued `openSit`
   for the new sitting and restore the old one (what the code means to do, and
   the record then shows one continuous sitting), or leave the new sitting alone
   and not restore the old one (the undo takes back the work block only, and says
   so). Recommendation: the first. It matches what the ribbon promises, and it is
   the smaller change — `takeUndo` already drops a pending `setMark` this way.
2. **Should-fix 2 — the coupling, or the user's sitting.** The handoff says
   opening Body by undo closes any open SIT, and the code obeys it. But the
   sitting it closes here was running before the switch and has nothing to do
   with it, and posture has no undo. Either narrow the branch to the sitting the
   undo actually closed and fix the comment, or keep the coupling and guard the
   posture button so BODY-plus-sitting never happens in the first place.
   Recommendation: guard the posture button. The coupling is a model invariant and
   the hole is on the other side of it.
3. **F4's undo chip.** It was on the list and it was not done, and a test now
   pins the current behaviour. Fix it, or take it off the list and say why `1` is
   the right floor. Recommendation: take it off. A chip reading `UNDO · 0` offers
   something that is already gone.

---

## The state of the repo

`main`, 45 commits ahead of `origin/main`. Nothing has been pushed and nothing is
deployed. Version 30 on the phone is the pre-redesign build, so nothing in this
review is on anyone's device.

`node test/tests.js` and `node test/lint.js` were re-run after this file was
written, with it in the tree: `1101 passed, 0 failed` and `all clear`. The working
tree holds no change but this file — every mutation any reviewer made was made in
a throwaway clone.
