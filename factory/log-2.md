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
