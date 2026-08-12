# Review: the FIXES-5 pass — 2026-07-29

Reviews 1 and 2 are round 1's (`REVIEW.md`, `REVIEW-2.md`). Review 3 is round 2's
(`REVIEW-3.md`). Review 4 is the redesign's (`REVIEW-4.md`). Review 5 is the
FIXES-4 pass (`REVIEW-5.md`). This is the sixth, and it reviews the fix pass that
answered the fifth.

**Under review:** `89058d2..HEAD` — about 25 commits of fix work through
`3c39593`, plus the commits that wrote the record and prepared this review. It
claims to close every item in `factory/FIXES-5.md`.

**How it was run.** Three independent Task reviewers were launched in one
orchestrator chat, none given the builder's reasoning and none given each
other's findings. Angle 2 (`gpt-5.6-sol-medium`, what the fixes broke) and
angle 3 (`claude-opus-5-thinking-high`, how it fails a user) returned full
measured reports. Angle 1 (`claude-sonnet-5-thinking-high`, did it fix what it
claimed) did not finish: the first attempt hit an API usage limit, and the
retry was interrupted before it produced a verdict. The assemble step below
therefore has no independent "claim check" angle. Every finding that would
block was then **reproduced a second time, by hand, by the orchestrator who
assembled this file** — the declined-undo race in the node harness with a
lagged `getState`, and the D9 double-tap in Chromium at 390×844 with touch. The
builder's own account (`factory/log-2.md`, `factory/STATE.md`, the commit
messages) was read only at the very end.

---

## Verdicts

| Reviewer | Verdict |
|---|---|
| did it fix what it claimed | **NOT RUN** — angle 1 did not finish; no independent claim-check verdict |
| what the fixes broke | **FIX FIRST** — a posture tap inside the declined-undo state read cancels the repair A1 added |
| how it fails a user | **FIX FIRST** — the same undo lie reaches a user by touch; D9's Add scroll makes a reflex double tap switch twice |

**The pass is real work and it is not finished.** REVIEW-5's three blocking
faults are gone on the paths the suite drives. Gates that reviewers measured —
suite under four zones, lint on 21 rules, headless naming its skips, goldens
matching `a256bdf` — are green. What blocks is two things a user can reach by
touch: A1's repair is one state read that any `enqueue` during the round trip
throws away with nothing to re-read it; and D9's `revealAddRow` moves the list
78px under the finger at seven categories the moment the mark strip appears, so
a second tap at the same point switches to the next row. The second is a
regression against `89058d2`.

---

## Blocking

### 1. A declined undo still lies when anything is written during the state read

A1 added `loadServerState()` after an applied `undoSwitch`. That closes the
fault REVIEW-5 described when nothing else happens in the round trip. It does
not close A1's criterion when something does.

`adoptServerState` returns early when `gen !== localGen` (`Index.html:2293`).
Every `enqueue` increments `localGen` (`Index.html:594`). A posture tap (or
STOP, or another category tap) during the `getState` flight bumps the
generation, the answer is refused, `lastStateMs` has already been moved, and
nothing re-issues the read. The screen keeps the optimistic previous block.
`refreshOnReturn` needs ten stale minutes **and** a visibility change.

```
DW runs 40m · tap MTG · another device closes MTG
tap UNDO · 300ms later tap the footer to sit
getState lag 800ms

  screen   : DW          header: GOOGLE CALENDAR · SYNCED
  calendar : "DW: =" 09:00-09:40 | "MTG:" 09:40-09:40
  open ACTUAL blocks : 0
  queue              : []
  after +10m, same tab, no visibility change: still DW against 0 open
```

**Reproduced by the orchestrator** with `H.setCallLag('getState', 800)` in the
node harness (pass 5 / fail 0 on the probe's own checks). Without the
interleaved tap, the same script ends with `activeKey() === null` — A1's happy
path is real. With the tap, the false claim is real. Angle 3 swept taps at 0,
100, 300, 500, 700 and 790ms against an 800ms read; all broke it; 810ms
recovered.

The STOP path fails the same way: STOP, another device already moved the block's
end, UNDO, posture tap — screen claims the previous block against a closed
calendar.

**Smallest honest repair:** remember a refused adopt and re-read once the queue
drains with no newer local write pending; do not advance `lastStateMs` on a read
that was thrown away. Same shape as `stateAfterBootDrain`.

A2's rail-duplication fix rests only on this read. Through this hole, the
duplicated rail comes back (angle 3 finding 3). Closing this closes that.

### 2. Showing the mark strip scrolls the list under a reflex double tap

D9 added `revealAddRow()` to `showStrip()` so Add stays visible beside the strip.
At seven categories on a 390×844 phone viewport, that scroll is 78px the moment
a 40-minute switch raises the strip. The second tap of a double tap, aimed at
the same point, lands on the next category.

```
7 categories · Chromium 390×844 · touch · DW restored for 40m
aim at MTG centre (265, 330.6) · two taps 100ms apart

  after tap 1: active=MTG  strip up  scrollTop 0→78
               same point now hits ADM
  after tap 2: active=ADM  nowName=Admin

  (zero-second MTG block on a real calendar path; here the optimistic
   UI alone is enough to prove the mis-aim)
```

**Reproduced by the orchestrator** in Chromium with touch. At `89058d2`,
`showStrip` does not call `revealAddRow` — this pass caused it. Angle 3 also
measured −134px at 8 categories and −190px at 9; at 8 categories some second
taps land on `MARK −` and write `setMark(-)` onto the closed block.

Section 62 double-taps through the DOM shim with no layout and a 30-second
block, so the strip never appears. Headless `checkReach` drives a real
40-minute switch at 6/7/8/10 categories and never taps a second time. Nothing
caught this.

---

## Should fix

### F2's corrected lit-row check never ran on the handset (or in headless)

The first phone paste failed one check and found the inset edge the old
outer-ring assertion rejected. Smoke was corrected. The second phone run was
idle: `29 passed, 0 failed, 2 skipped` — both lit-row checks skipped because no
block was running. Headless cold load skips the same two every time, and names
them. F2 proved the criterion change and an idle paste; it did not prove the
corrected check against a running row on a phone. Angle 3 measured the running
row in Chromium as `rgb(236, 48, 19) 4px 0px 0px 0px inset`, which matches Day
Rail. Seed a running block in headless (and in any future phone paste) so the
checks actually run.

### A reflex double tap on STOP re-opens the sitting

Not caused by this pass — byte-identical at `89058d2`. After STOP, the posture
control sits under the finger where STOP was. A second tap opens a SIT block.
Ruling 2's cost (sitting until `staleGuard_`) applies. Reported because B3 took
on the reflex double tap, and STOP is the one tap with nothing after it to undo.

---

## Cosmetic

### Ten categories still give no sign that the list continues

B2's first branch holds: with the running block in row 10 it is revealed after
load. `#grid` still has no mask, fade, persistent scrollbar, or aria cue. With
the running block in row 1, rows sit off screen with no signal.

---

## What is right, for calibration

Measured by angles 2 and 3; goldens and lint re-checked by the orchestrator.

- **Suite.** 1183 passed, 0 failed, under `America/New_York`, `Europe/London`,
  `Australia/Sydney`, and `UTC`.
- **Lint.** `all clear`. 21 `check(` calls in `test/lint.js`; the claim of 21
  rules is correct.
- **Headless.** Green at both viewports. Skips are named. Green before 10:00
  local with the rail fixture's pinned clock (C2 is really fixed — angle 3 also
  drove 08:04 Honolulu / Kiritimati and 03:05 Tokyo).
- **Goldens.** `appsscript.json` and `test/fixtures/rollup-golden.json` are
  sha256-identical to `a256bdf`.
- **A1 happy path.** Without an interleaved write, declined undo clears the
  running claim within one round trip. The orchestrator's B1b probe agrees.
- **C1 (rail halves).** Mutations to `railBudget`, the share cap, and total
  scaling each fail a named check alone.
- **Ruling 1.** `closeSit(` has exactly two callers in `Index.html`:
  `toggleSit` and `endDay`. Reintroducing BODY→`closeSit` in `tapCategory` turns
  many named checks red.
- **Ruling 2.** Removing `closeSit` from `endDay` turns STOP checks red,
  including section 43.
- **A3.** Weakening `if (hit < n)` to `if (!hit)` fails a named assertion.
- **C3.** Sheets stay modal (`inert`, Escape, own controls only) — still
  load-bearing.
- **D2, D4, D6–D8, E1, E2, F1.** Angle 3 drove each against its criterion; they
  hold. D9 holds its own "Add visible" criterion and creates Blocking 2.
- **B1.** Spoken names live in a real accessibility tree (checked in headless,
  not only in a console paste).
- **Body↔sitting uncoupling** on the four category paths, with STOP still
  joining sittings — structural, not only asserted.

The suite is green and stronger than it was. It still does not catch either
blocking fault above.

---

## The builder's account against what was found

Read last, on purpose. `factory/log-2.md` and `factory/STATE.md` match most of
what was measured, including the 21 lint rules and the goldens. Three claims to
carry forward:

| the record says | what is true |
|---|---|
| "A–F closed" | A1's written criterion passes on the quiet path and fails when any local write lands in the same round trip. A2 is a test on that path and inherits the hole. D9 is closed against its Add-visible criterion and creates Blocking 2. |
| F2 phone smoke proved the inset lit edge | The failing first paste found the inset edge against the old check. The corrected second paste skipped both lit-row checks (idle). Headless skips them on every cold load. |
| Redesign is live on the phone; one redeploy owed | Angle 3 confirmed the tree itself is clean of `?smoke=1`. The build a user is holding is still not a commit until that redeploy. |

Nothing in the account looks dishonest. "A–F closed" is the claim "Done means"
turns on, and for A1/D9 it overstates what the criteria actually locked.

---

## Decisions for you

Only genuine open questions are here. Everything above is a fact with a
reproduction.

1. **The post-undo read.** Either re-issue the read when `adoptServerState`
   refuses one that was asked for because of a declined undo, or say on screen
   that the app could not check. Recommendation: re-issue after the queue
   drains, and do not move `lastStateMs` on a refused read. It is the smaller
   change and it closes the A2 inheritance as well.
2. **D9 against the reflex double tap.** Keeping Add visible costs a 78–190px
   jump under the finger at 7–9 categories after every switch long enough to earn
   a mark. Three ways out: drop `revealAddRow` and let Add clip while the strip
   is up (as at `89058d2`); keep the scroll but ignore grid taps for ~300ms after
   a switch (same shape as B3's running-row guard); or reserve the strip's height
   in the layout so showing it moves nothing. Recommendation: reserve the height
   if it is cheap, otherwise drop the scroll. The Add row does not earn a
   mis-switch.
3. **The live deploy.** The phone runs a build that is in no commit until the
   owed redeploy drops the temporary smoke runner. Whatever follows this review,
   that redeploy is owed.

---

## The state of the repo

`main`, ahead of `origin/main`. Goldens still match `a256bdf`. The redesign is
on the phone for F2; one redeploy is still owed. Never point the suite at a real
calendar. Nothing was deployed from this review.

Throwaway probes used for the orchestrator's re-reproduction were removed; the
working tree holds this file (and any pre-existing untracked files the human
already had) and no other change from the assemble step.
