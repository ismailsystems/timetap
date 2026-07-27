# Progress — round 2, the honest record round

handoff: factory/HANDOFF-2.md · branch: `factory/honest-record`
started: _not yet — created 2026-07-27 at handoff time_

Round 1's progress record is `factory/progress.md` and is **read-only**.

## Status

In progress. **5 of 16 tasks complete. Stage A is finished.** Stage B, task B1 next.

Suite: **636 passed / 0 failed** (baseline was 492), green in all four
contracted timezones. Lint all clear. Headless ok, 19 checks per viewport.

## Tasks

| Task | Stage | Status | Attempts | Notes |
|---|---|---|---|---|
| A1 | A | **done** | 1 | vacuity check done. Checker found a contract-17 defect, fixed. Criterion 6 parked as Q1 — self-contradictory |
| A2 | A | **done** | 1 | vacuity check done, separation held. Checker found 2 defects, both fixed |
| A3 | A | **done** | 1 | checker found 2 real bugs (stuck armed STOP, stale-read race) + 3 weak tests, all fixed |
| A4 | A | **done** | 1 | checker found 4 mutations my phase missed; all now caught |
| A5 | A | **done** | 1 | criteria all met; checker's 16-scenario x 6-zone differential moved nothing. Q9/Q10 parked |
| B1 | B | pending | 0 | |
| B2 | B | pending | 0 | golden fixture changes here |
| B3 | B | pending | 0 | golden fixture changes here |
| B4 | B | pending | 0 | |
| B5 | B | pending | 0 | vacuity check required |
| C1 | C | pending | 0 | the sweep is the load-bearing criterion |
| C2 | C | pending | 0 | |
| C3 | C | pending | 0 | |
| D1 | D | pending | 0 | golden fixture changes here, second and last time |
| D2 | D | pending | 0 | |
| D3 | D | pending | 0 | |

## Baseline, measured 2026-07-27 before any work

```
node test/tests.js      492 passed, 0 failed
node test/lint.js       all clear — 17 rules, 38 files scanned
node test/headless.js   ok — 19 checks per viewport, drawer + tap-count green
```

`main` level with `origin/main` at `a256bdf`. `appsscript.json` byte-identical
to that commit and must stay so.

## Vacuity checks (mandatory — record what was reverted and what went red)

| Check | Task | Status |
|---|---|---|
| Revert regex to `[+=\-]`, parse criteria go red | A1 | **done — 6 red, 521/6.** Reverted `MARKS` to `'+=-'`, which reverts the regex by construction. Details in `log-2.md` |
| Revert `?` to `=`, mark criteria go red **while boundary criteria stay green** | A2 | **done — 8 mark red, every boundary green.** Independently reproduced by the checker |
| Delete the PLAN sentence from each doc **one at a time**, lint names that file | B5 | not run |

## Orientation

`HANDOFF-2.md`'s Orientation section asks for the Q&A to be appended to that
file. Its Guardrails say never to edit that file, under a heading reading "never
violate". The guardrail wins; orientation is recorded here, which the operating
loop already names as the loop's memory across restarts. Conflict flagged for
the reviewer.

**Questions to the human: none.** 112 criteria are specified against exact line
numbers, and the document's own instruction for genuine mid-run ambiguity is to
park it here rather than ask.

**Two naming choices made rather than parked** — both cheap to change at review,
neither worth stalling the run over:

- D1's "a key named for what it is" does not name the key. Using `UNPARSED`.
- D2's partial-week marker does not name the column. Will be decided at D2 and
  recorded here.

**Pre-flight finding, before task A1.** The baseline recorded above as green was
not. `node test/lint.js` failed on `factory/log-2.md:22` — the handoff's own
pre-flight entry quotes the stale scope claim carried over from the first round,
so the scope-count rule caught its own paperwork. Resolved by adding
`factory/log-2.md` to
`SCOPE_QUOTE_EXEMPT` on the rationale `factory/log.md` already carries. Full
reasoning and the cost of that choice are in `factory/log-2.md`. Baseline is
green as of that fix, and it is the real starting line: 492 / 0, lint all clear,
headless ok at 19 checks per viewport.

## Parked questions

### Q1 (A1) — criterion 6 contradicts itself, and only one half is satisfiable

A1's sixth criterion: *"Given the title `DW: memo ??`, when parsed, then the mark
is a single `?` and the text is `memo ?` — the regex anchors to one trailing
character, exactly as it already does for `=`."*

Its two halves disagree. Measured against the pre-round code at `a256bdf`:

```
"DW: memo =="  ->  {key:'DW', text:'memo ==', mark:null}
"DW: C++"      ->  {key:'DW', text:'C++',     mark:null}
```

`=` does **not** already behave the way the criterion's stated outcome
describes: a doubled mark is text, because the regex requires start-of-string or
whitespace before the mark. Making the literal outcome true means deleting that
guard, which would:

- change `=` behaviour, against **contract 7** (untouched behaviour unchanged);
- make `DW: C++` parse as text `DW: C+`, mark `+`;
- break **contract 18** — `buildTitle_` would rebuild `DW: memo ??` as
  `DW: memo ? ?`, so a title carrying `?` would stop round-tripping
  byte-identical.

**Taken:** the justification clause is implemented — `?` behaves exactly as the
three existing marks do, whatever that behaviour is — and `test/tests.js` 41d
asserts that equivalence directly rather than restating the literal outcome.
**The literal outcome is NOT met and has not been deleted.** The criterion needs
a human ruling; the engineering here is not close, but the guardrail says park
rather than reinterpret, so it is parked.

### Q2 (A1) — the same hole exists for `+`, `=` and `-`, and predates this round

Fixing Q3 below closes the `?` case only. A note ending in `+`, `=` or `-` has
always been read back as that mark, and always silently eaten from the note:

```
"DW: great +"  ->  {key:'DW', text:'great', mark:'+'}
```

Not touched, because contract 17 names `?` specifically and contract 7 says
leave existing behaviour alone. **Should the same protection be extended to the
other three marks?** It would stop a user's stray `+` from silently marking a
block as having gone well — which is the same class of dishonesty this round
exists to remove — but it is a behaviour change outside any task in this round.
Human's call.

### Q4 (A2) — contract 17 and A1's criterion 4 cannot both be fully true

Contract 17: *"No action a user can take produces `?`. Only `staleGuard_` writes
it."* A1's criterion 4: *"Given an op carrying `mark: '?'`, when `applyOps` runs,
then it is applied and its id appears in `applied` — not in `dropped`."*

`validOp_` is the trust boundary for ops that came out of `localStorage`, and
the file says so. Criterion 4 requires it to accept `?`, so an op carrying one
is applied and a title gets a `?` that `staleGuard_` did not write. Before this
round `validOp_` rejected it.

**Not fixed, deliberately.** Rejecting `?` in `validOp_` would satisfy contract
17's second sentence and directly violate an explicit acceptance criterion,
which the guardrails forbid. Worth noting the route is narrow: it needs
hand-editing `localStorage`, not any action the UI offers, so contract 17's
first sentence still holds. `staleGuard_` writes its `?` through `ev.setTitle`
directly and never through an op, so nothing in this round actually needs
criterion 4. **Human ruling wanted:** keep criterion 4, or tighten `validOp_`.

### Q5 (A2) — a title hand-edited in Google Calendar can still read as a guess

A1 closed the write side: a note typed into the app can no longer land a `?` in
the mark slot. The read side is unclosable by design. A user who types
`DW: is this right ?` straight into Google Calendar gets it parsed as mark `?`:

```
"DW: a ?"  ->  {key:'DW', text:'a', mark:'?'}
```

One consequence worth stating outright, found at A5: such a block also stops
counting toward the waking span, so a user who hand-edits a title to end in
` ?` silently loses those hours from `waking h` while keeping them in their
category column. Narrowly reachable — `MARK_TAIL_RE_` needs whitespace before
the `?`, so `DW: ship it?` is safe and only `DW: ship it ?` is not.

`parseTitle_` cannot tell a `?` the app wrote from one a user typed, because the
handoff's design puts both in the same single trailing character. Making parse
ignore `?` would break A2 outright — `getState` has to read back what
`staleGuard_` writes.

**Not fixable inside this design.** It is a consequence of encoding the guess as
a trailing mark, which contracts 13 and 18 mandate. Flagged so the reviewer sees
it as a known limit rather than an oversight.

### Q9 (A5) — a row can now contradict itself, and a guessed block's start is a fact

A5 stops `UNLOGGED` and `?` blocks from extending the waking span. Both keep
their own hours, as criterion 3 requires. The consequence, found by the checker:

```
                                                    A5            pre-round
DW 09-16 closed "=", DW 16-24 phantom "?", SIT 09-17
  waking h                                          7             15
  DW                                               15             15
  sitting %                                      1.14           0.53

a day whose only block is the overnight phantom
  waking h                                          0             2
  DW                                                2             2
```

The sheet now reports 15 hours of deep work inside a 7-hour waking day, and an
evening-start day reads `waking h` 0 while its category column reads 2.

**The root of it:** a `?` block's **start** is a fact the user reported — they
tapped the category at 22:00 — and only its **end** was guessed. The guard
discards both ends.

**The fix that suggests itself, and why it was not taken.** Letting a `?`
block's start extend `first` while its end does not extend `last` removes the
contradiction *and still satisfies A5's criteria 2 and 5* — I checked. But
**contract 22** says a `?` block's hours "do not extend the waking span", with
no qualification, and under that fix a `?` block that is the day's earliest
event extends the span backwards. Taking it means overriding a contract
assertion, which the guardrails reserve for the human.

Behaviour is pinned by test 44h rather than left accidental. **If this is ruled
the other way, 44h is the test to change.**

Worth noting `sitting %` above 100% was already reachable before this round —
SIT 06:00-20:00 against DW 09:00-17:00 gives 1.75 in both trees — so this is a
widening of an existing oddity, not a new class of one. A5's own risk note
anticipates the comparability problem and parks it; this is the same family.

### Q10 (A5) — a user-added category can take the key `UNLOGGED`

`keyFor_` has no reserved-key check, so a category the user names "Unlogged",
"un-logged" or "UNLOGGED time" all derive the key `UNLOGGED`:

```
keyFor_("Unlogged", [])      = UNLOGGED
"unlogged: real work"  ->  {key:'UNLOGGED', text:'real work', mark:null}
that user's real 06:00-18:00 block  ->  waking h = 0, UNLOGGED = 12
```

Their genuinely logged time then stops counting toward the waking span, and
`rollupKeys_` also pushes `UNLOGGED` unconditionally so the key gets a duplicate
column. Both halves predate this round; A5 is what makes the first one bite.

**Not fixed.** Reserving a key is a product decision — reject the name, rename
the key, or silently suffix it — and contract 7 puts category add and remove
among the things this round leaves alone. Contrived to reach, and named here so
it is a known hole rather than a surprise.

### Q8 (A4) — the mark strip's own controls are 42px tall

Measured during A4 and printed by the headless phase on every run:

```
strip controls:  stripHead 112x17, mark + 74x42, mark = 74x42, mark - 74x42
```

The three mark buttons and the strip head are interactive, live inside
`#postureRow`, and are under the 44x44 floor the rest of that row is now held
to. They are **not** asserted, because the first criterion limits the check to
the resting posture row and the strip is hidden then — so failing on them would
be inventing a criterion rather than meeting one.

Pre-existing from round 1, and reaching 44px means finding 2px inside a fixed
72px row that also holds a 17px head. **Should the strip be brought up to the
same floor?** Human's call; it is a visual change to round 1's work, not this
round's. Printed on every headless run so it cannot be quietly forgotten.

### Q7 (A3) — a STOP whose closes never reach the server still becomes a phantom

If the server rejects every call, STOP's two closes retry, are set aside after
`MAX_OP_TRIES`, and the block stays `#open` on the calendar. The next morning
`staleGuard_` bounds it and writes `UNLOGGED` — exactly the phantom this round
removes — even though the user did close the day.

```
STOP at 19:00, server rejecting -> set aside
next morning: "DW: ?" 09:00-14:00 | "UNLOGGED -" 14:00-08:00
banner: "1 write was set aside after repeated failures"
```

**Judged honest and left alone.** The user is told, in a banner that persists,
and the set-aside drawer holds the write. The alternative — the client
pretending the day ended when the calendar says otherwise — is the dishonesty
this round exists to remove. Flagged because it reads against contract 16 as
literally worded, and that deserves a human decision rather than a silent pass.

### Q6 (A2) — contract 18 has one literal counterexample, and it predates the round

Contract 18: *"Given **any** title carrying `?`, when it is parsed and rebuilt,
then it round-trips byte-identical."* One form does not:

```
"UNLOGGED ?"  ->  "UNLOGGED: ?"
```

`parseTitle_` special-cases a bare `UNLOGGED` with no colon; `buildTitle_`
always writes one. Pre-existing and identical for every mark at `a256bdf`
(`"UNLOGGED -"` → `"UNLOGGED: -"`), so not a regression. Every other `?` form
round-trips, including `"DW: ?"`, `"DW: why? ?"` and `"DW: a ? ?"`. Left alone
as out of scope; contract 18's wording is what is wrong, not the code.

## Contract additions

_Every bug found during the run gets a criterion written here first, then the
fix._

### Q3 / addition 1 (found at A1, by the checker) — a user's note could write `?`

**Contract 17 was violated by A1 as first written.** `?` became a mark on the
read side, but nothing stopped user note text from ending in one. Reproduced
through the real UI — tap `DW`, type a note, tap `MTG` twice, block under
`MIN_MARK_MINUTES`:

```
note typed : "is this right ?"
title      : "DW: is this right ?"
parses as  : {key:'DW', text:'is this right', mark:'?'}
```

A block the user annotated became indistinguishable from one the app guessed —
and the user's `?` silently vanished from the note. It would have poisoned A2
and all of Stage B, where a `?` block is excluded from the waking span
(contract 22).

**New criteria, added here before the fix:**

- [tier 1] Given a note ending in ` ?` on a block that closes with no mark, when
  the title is parsed, then the mark is null. No user action produces `?`.
- [tier 1] Given a note ending in ` ?` on a block that closes with a mark, then
  the note keeps its `?` and the mark is the one the app applied. The trailing
  slot is occupied, so the note is unambiguous and must not be touched.
- [tier 1] Given any note, then build → parse → rebuild stays byte-identical.
- [tier 1, error] Given a note of only `?` characters, then nothing throws and
  the title parses to mark null.

**Fixed in A1.** `buildTitle_` strips a trailing mark-position `?` from user
text only when no mark follows it. Deliberately narrow: when a mark does follow,
the note's `?` is preserved intact, which is strictly better than the pre-round
behaviour it replaces.

### Addition 2 (found at A2, by the checker) — a category could be configured to guess

Categories added at runtime come out of the `EXTRA_CATEGORIES` script property,
which nothing validates. A category carrying `autoMark: '?'` made `markFor`
return `?` on an ordinary tapped close — no `staleGuard_` involved. That breaks
contract 17 *and* A1's own criterion 7, which says `markFor` never produces `?`.
Before this round `validOp_` rejected the resulting op, so the widening removed
the backstop that had been making the documentation true.

- [tier 1] Given a category configured with `autoMark: '?'`, when a block of it
  is closed by an ordinary tap, then the title does not carry `?`, and the
  normal duration rule applies instead.

**Fixed in A2**, in `markFor` — the one place the criterion names. Test 42g.

### Addition 3 (found at A2, by the checker) — bounding overwrites a mark that is no longer true

`staleGuard_` used to preserve a mark already present on an open block; making
`?` unconditional overwrites it. Only reachable by hand-editing a title in
Google Calendar, since the app never marks an open block. The new behaviour is
right — the app really did guess the end time — but it was a silent change with
no criterion and no test, which the standing rule forbids.

- [tier 1] Given an open block hand-titled `DW: memo =` that the app then has to
  bound, then its mark becomes `?` and its text survives unchanged.

**Recorded here, then pinned by test 42h.**


## Parked tasks

_None. Three parked tasks trips the circuit breaker and ends the run._
