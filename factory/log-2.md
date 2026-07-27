# Build log — round 2, the honest record round

Append-only. One entry per event, newest at the bottom.
Format: `## [date time] <task id> | <what happened>`

Round 1's log is `factory/log.md` and is **read-only**.

## [2026-07-27 handoff] — | Round 2 compiled and handed off

Branch `factory/honest-record` created off `main` at `a256bdf`.

Sources: `factory/BRIEF-2.md` (six findings from a conceptual-model stress test
run against `Code.gs` and `Index.html` directly), `factory/PLAN-2.md` (16 tasks,
four stages, 31-assertion contract, 112 acceptance criteria).

Baseline measured green before any work: 492 assertions / 0 failed, lint all
clear across 17 rules and 38 files, headless ok at 19 checks per viewport
including round 1's drawer and tap-count phases.

One repo change made during pre-flight, before the loop starts: `test/lint.js`
gained a ninth entry in `SCOPE_QUOTE_EXEMPT` for `factory/ROUND-1.md`. That file
is round 1's archived record and quotes "one OAuth scope" twice — once from
review 2's finding 3, once from amendment A2's own wording. The text was already
exempt while it lived in `factory/STATE.md`; archiving it into its own file moved
the exemption with it rather than creating a new one. The rule was verified still
live by appending a false scope claim to `factory/BRIEF-2.md`, watching lint fail
by name, and removing it.

Loop has not started.

## [2026-07-27 10:0x] — | FINDING: the recorded green baseline was already red

First act of the loop was to measure the baseline the handoff records. Two of
the three commands matched it. `node test/lint.js` did not:

```
FAIL the docs agree with the manifest about how many scopes it asks for
     - factory/log-2.md:22 — "one OAuth scope" but appsscript.json asks for 3
```

The handoff commit `978ff54` introduced this file, and its pre-flight entry
above quotes the stale round-1 scope claim while describing the exemption it
was adding for `factory/ROUND-1.md`. The rule caught its own paperwork. So the
"lint all clear" written into HANDOFF-2.md, progress-2.md and the entry above
was measured before that entry existed, and was false by the time the loop was
launched.

Reported rather than quietly fixed, because a documented-green baseline that is
not green is the exact class of thing this round exists to stop.

Resolution: `factory/log-2.md` added to `SCOPE_QUOTE_EXEMPT` in `test/lint.js`,
carrying the rationale `factory/log.md` already carries — "append-only build log
— records the finding in its own words". Round 2's log is the same kind of file
as round 1's, so this is an existing category gaining its obvious member, not a
new exemption and not a weakened rule. The two alternatives were both worse:
editing an append-only entry, or leaving tier-1 lint red for every pass of the
run, which would make every task unverifiable.

Cost, stated plainly: a wrong scope count written anywhere else in this file now
goes unchecked. That is the same gap `factory/log.md` already has, and it is
named here so the reviewer sees it rather than finds it.

Baseline after the fix, and the real starting line for this round:

```
node test/tests.js      492 passed, 0 failed
node test/lint.js       all clear — 17 rules, 10 of 20 .md files checked
node test/headless.js   ok — 19 checks per viewport
```

## [2026-07-27 10:0x] — | Orientation

`HANDOFF-2.md` asks the executing agent to append its orientation Q&A to the
file's Orientation section. Its Guardrails say **never edit this file**, under a
heading reading "never violate". Honoured the guardrail; orientation lives in
`factory/progress-2.md` instead, which the operating loop already names as the
loop's memory across restarts. The purpose the Orientation section states — a
record that survives a restart, since chat history will not — is met either way.
Flagged for the reviewer as a conflict inside the document, not a decision taken
lightly.

No blocking questions to the human. 112 acceptance criteria specified against
exact line numbers, and the file's own instruction for genuine mid-run ambiguity
is to park it in `progress-2.md`, not to ask.

## [2026-07-27 10:4x] A1 | A title can carry a fourth mark, and it survives a round trip

`MARKS = '+=-?'` is now the single source of truth for the mark set, with
`isMark_` and a derived `MARK_TAIL_RE_` built from it. Three sites had been
carrying their own copy of the character set — `buildTitle_` an explicit
three-way comparison, `parseTitle_` a literal regex, `validOp_` an `indexOf`
against a string literal — and round 1 found two separate bugs in this format
already. They now cannot drift apart.

`isMark_` also tightened one thing on the way past: `'+=-'.indexOf('+=')` is 0,
so `validOp_` used to accept a two-character mark. `buildTitle_` refused to write
it, so nothing reached a calendar, but the op survived validation when it should
not have. A length check closes it. Tightening, not widening — asserted in 41c.

**Tests: 41, 41b, 41c, 41d, 41e, 41f. 492 → 527 assertions.**
All four contracted timezones green. Lint clear. Headless ok, 19 checks per
viewport.

**VACUITY CHECK — done.** Reverted `MARKS` to `'+=-'`, which reverts the parse
regex to `[+=\-]` by construction, and ran the suite:

```
FAIL buildTitle_ writes "?"
FAIL and parseTitle_ reads it back as the mark
FAIL leaving the "?" out of the text
FAIL and not dropped
FAIL so the title carries the guess
FAIL a single trailing "?" is a mark
521 passed, 6 failed
```

Restored, 527 / 0. Worth naming: the round-trip table in 41b does **not** go red
under this revert, because build and parse compensate for each other — with no
`?` written, nothing round-trips a `?`. So 41b cannot detect this class of
regression on its own, and the criteria that can are the six above.

**CHECKER — an independent agent, given only the contract and the diff, and told
to prove A1 does not meet its criteria.** It confirmed criteria 1-5 and 7 as
worded, verified the criterion-6 contradiction independently against `a256bdf`
rather than taking my word for it, and found a defect I had missed.

**The defect it found, and the fix.** A1 as first written violated contract 17.
`?` became a mark on the read side, but nothing stopped a user's note from
ending in one:

```
note typed : "is this right ?"     (block under MIN_MARK_MINUTES, so no mark)
title      : "DW: is this right ?"
parses as  : {key:'DW', text:'is this right', mark:'?'}
```

A block the user annotated became indistinguishable from one the app guessed,
and the user's `?` silently vanished from the note. It would have poisoned A2
and all of Stage B, where a `?` block is excluded from the waking span.

Recorded as contract addition 1 in `progress-2.md` **before** being fixed, per
the standing rule. Fix: `buildTitle_` strips a trailing mark-position `?` from
user text only when no mark follows. Deliberately narrow — when a mark does
follow, it occupies the trailing slot, the note's `?` is unambiguous, and it is
kept exactly as typed. `"DW: is this right ? ="` parses back to text
`"is this right ?"` and mark `"="`, which is better than the pre-round behaviour
rather than worse. Tests in 41f.

The same hole exists for `+`, `=` and `-` and predates this round — a note
ending in one has always been read back as that mark and eaten from the note.
Not touched: contract 17 names `?`, contract 7 says leave existing behaviour
alone. Parked as Q2 for the human.

**Two findings the checker raised about this log, both fair, both fixed here.**

1. Commit `a0b6f33` — the one titled "the recorded green baseline was red, and
   now is not" — was **itself red**. Writing the words "round-1 scope claim"
   into `progress-2.md` tripped the scope-count rule, which reads `-1 scope` as
   a claim that the manifest asks for one. The "all clear" recorded above was
   measured before that prose existed and was false by the time it was
   committed. Exactly the mistake the commit was fixing, made again in the same
   commit. Fixed forward by rewording rather than by amending, because this
   round is about the record being honest and an amended commit would erase the
   lesson. Noted for the reviewer: the lint rule cannot tell `round-1 scope`
   from `1 scope`, which is a false positive in the rule itself. Left alone —
   the rule is not this round's to widen, and prose can route around it.
2. The vacuity check was run before the checker ran, but had not been written
   down yet, and `test/tests.js` 41d referenced a parked question that did not
   yet exist in `progress-2.md`. Both now written. A record that describes work
   accurately only after someone checks is not a record.

## [2026-07-27 11:2x] A2 | A block the app had to guess the end of says so in its title

`staleGuard_` writes `?`. The block that used to derive a mark from the
category's `autoMark` or from `MIN_MARK_MINUTES` is gone; a bounded ACTUAL block
is marked `?` unconditionally. **The bounding arithmetic is untouched** — same
`Math.min` of start + `STALE_OPEN_HOURS`, the day border and now.

**Tests: 42, 42b, 42c, 42d, 42e, 42f, 42g, 42h. 527 → 553 assertions.**
Four contracted timezones green; skips by name, not crashes, in others.

One pre-existing assertion moved, and only one:
`chk('DW marked', a10[0].t === 'DW: =')` → `'DW: ?'`. That assertion pinned the
exact behaviour A2 exists to change. Its replacement is equally strict, and
`git diff a256bdf -- test/tests.js | grep '^-'` shows it is the only removal in
the round so far.

**VACUITY CHECK — done, and the separation is the point.** Reverted `?` to `=`
in the guard:

```
FAIL DW marked as a guess, not as settled        FAIL BODY is marked "?", not "+"
FAIL the block's title ends with "?"             FAIL FRAG is marked "?", not "-"
FAIL and not with "="                            FAIL and exactly one mark is on the title
FAIL it parses back as a guess                   FAIL the one-minute block still carries "?"
541 passed, 8 failed
```

Eight mark assertions red. **Every boundary assertion stayed green** — 22:00 to
midnight, UNLOGGED midnight to now, the 5h cap, the SIT day border, the
sub-`MIN_MARK_MINUTES` duration. That is what proves the boundary assertions are
testing arithmetic and not the mark.

**CHECKER — independent agent, contract and diff only, told to prove A2 fails.**
It could not break the two things A2 is about. On the boundary arithmetic it did
better than my own test: it built worktrees at `a256bdf` and at HEAD, ran 15
scenarios across 8 timezones plus 16 DST scenarios, and diffed raw millisecond
values rather than `near()`. Result — **nine differences, all of them titles,
zero of them times.** It also constructed the cases I had not: a spring-forward
inside the bounded span, Chile's non-existent local midnight, quarter-hour
offsets (Chatham, Kathmandu), and the 299/300/301-minute threshold. Identical in
every one.

**Two defects it found, both fixed here.**

1. **A category could be configured into producing a guess.** Categories added at
   runtime come from the `EXTRA_CATEGORIES` script property, which nothing
   validates, so `autoMark: '?'` made `markFor` return `?` on an ordinary tapped
   close with `staleGuard_` nowhere near it. That breaks contract 17 *and* A1's
   criterion 7, which says `markFor` never produces `?`. Before this round
   `validOp_` rejected the resulting op — so A1's widening removed the backstop
   that had been quietly making `Code.gs`'s own documentation true. Fixed in
   `markFor`, the place the criterion names. Recorded as contract addition 2,
   pinned by test 42g.
2. **Bounding silently overwrote a mark already on an open block.** Deleting
   `var mark = p.mark;` changed behaviour the code comment did not mention and no
   test covered. The new behaviour is right — the app really did guess the end
   time, and a stale `=` outliving its truth is the thing this round is removing
   — but shipping it unrecorded is what the standing rule forbids. Recorded as
   contract addition 3, pinned by test 42h. Only reachable by hand-editing a
   title in Google Calendar; the app never marks an open block.

**Three things it found that I did not fix, all parked with reasons** — Q4
(contract 17 and A1 criterion 4 contradict each other at `validOp_`; fixing it
would violate an explicit criterion), Q5 (a title hand-edited in Google Calendar
can still read as a guess — unclosable while the guess lives in the trailing
mark slot, which contracts 13 and 18 mandate), Q6 (`UNLOGGED ?` does not
round-trip; pre-existing for every mark, so contract 18's "any title" is what is
wrong). Details in `progress-2.md`.

One test-hygiene fix on the way past: 42b had two `chk`s with the identical
condition, counting one assertion twice. Merged.

## [2026-07-27 12:1x] A3 | STOP ends the day, and opens nothing

A `#stopBtn` in the posture row. First tap arms, second ends the day: the open
block closes at that instant, any open SIT closes at the same instant, and
nothing opens. No new server op — `closeActual` and `closeSit` already worked
standalone, so `Code.gs` is untouched by this task.

**Tests: 43 through 43l. 553 → 616 assertions.** Four timezones green, twice in
a row. Lint clear, headless ok. `appsscript.json` and
`test/fixtures/rollup-golden.json` both byte-identical to `a256bdf`.

**CHECKER — and this one earned its keep.** It found two real bugs, and proved
three of my tests could not fail. Everything below came from it.

**Bug 1: an armed STOP could get stuck armed, forever, covering the row.**
`tapCategory` disarms STOP, and the re-tap-the-lit-block branch returns
*without* rendering — while disarming had already cancelled the timer whose
repaint would have fixed it. Because the armed state takes the whole posture
row, the result was a black bar reading TAP AGAIN TO STOP sitting on top of the
posture toggle and the sit clock, permanently, doing nothing when tapped. The
checker confirmed it in real Chromium at both viewports, with
`document.elementFromPoint` returning `stopBtn` over the posture button's
centre. `disarmStop()` now reports whether it disarmed anything, and the caller
repaints. Test 43l.

**Bug 2: a server answer older than the STOP undid it.** The risk HANDOFF-2.md
predicted for this task, and it was real. `getState` takes no server lock,
`applyOps` does, so the two round trips can finish in either order. A `getState`
computed *before* the STOP and delivered *after* it repopulated `S.open` with
the block the user had just ended, and the next tap then closed it at the wrong
time — losing the end time the user chose. `adoptServerState`'s existing
queue-length guard cannot catch this: by the time the answer lands, the STOP has
applied and the queue is empty. Fixed with a `localGen` counter bumped by every
`enqueue`; a read carries the generation it was issued under and is dropped if
anything was written since. Test 43k.

**Two things that made bug 2 hard to see, both fixed in the harness.**

1. The shim computed a call's answer at *delivery* time, so a slow call was
   merely late, never stale. Real Apps Script computes when the call arrives and
   the answer travels back. `setCallLag(name, ms)` now models that — answer
   computed now, delivered later — which is what makes the race expressible at
   all. The default 5ms path is unchanged.
2. `reboot()` dropped the old instance's tick interval but not its
   `visibilitychange` handler, so every reboot left another client listening.
   `fireVisible()` woke all of them, each holding its own `S` and all rendering
   into one shared DOM. A zombie instance was undoing what the live one had just
   done — and it looked exactly like a product bug. I chased it as one before
   finding the second `getState`. `VIS` is now cleared on reboot, beside the
   line that already did this for timers.

**Three tests that could not fail, all found by the checker, all now proved.**

- 43d's "nothing was queued" read the *calendar*, not the queue. It passed
  against a build the checker mutated to enqueue a spurious op on every arm.
- 43g's "no mark on the closed block" asserted `A()[0].t === 'DW:'`, which is
  equally true of a block that never closed. Closed-ness is now asserted first.
- 43e never checked the queue at all.

Its mutation testing also showed that making `armStop` act on the **first** tap
reddened only 3 of 40 assertions. Single-tap-writes-nothing assertions added to
43b, 43c, 43f and 43g, so the arm/confirm half is now pinned as hard as the
close half.

**Both new regression tests were then proved non-vacuous the same way:**
reverting the repaint fix turns 4 assertions red; reverting the stale-read guard
turns 2 red. Restored, 616 / 0 both times.

Also from the checker, and taken: the armed `aria-label` never changed, so a
screen reader announced "end the day" in both states and the whole arm/confirm
distinction was inaudible — it now tracks the visible text. `#stopBtn` joined
the `:focus-visible` rule with the row's other two controls. And STOP stays
dimmed while armed over an already-ended day, so arming with nothing to end no
longer looks like it is about to do something.

**Q7 parked:** a STOP whose closes never reach the server still becomes a
phantom block plus `UNLOGGED` the next morning. Judged honest — the user is told
in a persistent banner and the write is in the drawer — but it reads against
contract 16 as literally worded, so it wants a human decision.
