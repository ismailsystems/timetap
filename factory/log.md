# Log — timetap error paths round

One line per event, newest at the bottom. Format:
`## [YYYY-MM-DD HH:MM] <task id> | <what happened>`

## [2026-07-26 19:20] setup | Handoff compiled. Branch factory/error-paths created off main. Baseline verified green: 298 assertions under America/New_York, Europe/London, Australia/Sydney and UTC; `node test/lint.js` all clear. 13 tasks pending.

## [2026-07-27 00:00] orientation | Read HANDOFF.md in full. Baseline re-verified independently: `node test/tests.js` 298 passed / 0 failed, `node test/lint.js` all clear. Six questions asked; human answered "yes to all". Answers recorded in the HANDOFF Orientation Q&A block — Playwright pinned exact as the dev-only browser, npm install approved, deploy.sh only ever run with a stub clasp prepended to PATH, B1 captures category at quarantine time (wire payload unchanged), C2 gets a committed golden fixture, drawer wording is the agent's to choose within the no-judgment law. No build work started.

## [2026-07-27 00:40] A1 | DONE. `test/harness.js` gains `setServerReject(msg)`, which wraps the real `applyOp_` so it throws — the rejection then travels the real `applyOps` bookkeeping and comes back through the *success* handler as a non-empty `errors` array, the one path that counts against an op's try count. `reset()` clears it. 21 assertions added to `test/tests.js` as sections 34/34b/34c/34d. 298 → 319, green under America/New_York, Europe/London, Australia/Sydney, UTC; `node test/lint.js` clear. **All five criteria pass against unmodified `Index.html` — no finding, nothing parked.**

## [2026-07-27 00:40] A1 | CHECKER. Mutation-tested in a throwaway copy under scratchpad (never in the repo). Neutering the reject switch fails 12 assertions; a cap that keeps the oldest 50 instead of the newest fails the ordering assertion. **The first pass of this found a real flaw in my own test:** moving the give-up threshold from 5 to 6 still passed 319/319, because the second pump waited for *any* dead entry instead of stopping at the fifth attempt — the vacuous-assertion class `test/README.md:63` records. Fixed by pumping to exactly 5 attempts and asserting there. Now off-by-one in either direction fails: threshold 6 → 4 failures, threshold 4 → 3 failures. Control copy 319/319.
