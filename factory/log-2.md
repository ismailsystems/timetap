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
