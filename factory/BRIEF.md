# Brief: timetap — error paths round
date: 2026-07-26

## What we're building

Three changes to an app that already works, all of them on code paths that only
run when something has already gone wrong.

1. **A headless smoke test**, so a machine can check the rendered page instead of
   only a human with a phone and a paste.
2. **A drawer for lost writes**, so a write the app gave up on tells you where to
   go fix it by hand instead of vanishing behind a count.
3. **A rollup that admits it failed**, so stale numbers announce themselves in the
   sheet rather than being trusted for eleven days.

Nothing here changes what the app does in normal use. Tapping a category, closing
a block, marking it, the posture button, the grid — all untouched.

## Who it's for and what they get

One user: the person who built it and logs their time with it. What they walk away
with is the ability to trust three things they currently can't — that a night of
unattended code changes didn't break the screen, that a failed write is findable,
and that the numbers in the sheet are as fresh as they look.

## Done looks like

The morning it works, in concrete behaviour:

- Running `./deploy.sh` runs three test layers, not two. The third one opens a real
  browser engine, renders `Index.html` at a phone viewport and a desktop viewport,
  runs the checks that are already in `test/smoke.js`, and reports pass/fail counts.
  If the browser isn't installed, it says so loudly and **the deploy does not
  proceed**.
- Deliberately changing the meta-tag list in `Code.gs` without changing the harness
  makes a lint check fail by name.
- With writes failing permanently (server rejecting), the app's error banner is
  tappable. Tapping it opens a sheet listing each set-aside write: when it happened,
  which category, what it was trying to do, and why it failed — enough to fix it by
  hand in Google Calendar. Each entry can be discarded once handled.
- Opening the rollup spreadsheet shows a "last rebuilt" line in both the `daily` and
  `weekly` tabs. Breaking the sheet id and running the rollup records the failure
  where it can still be read, and the stamp in the sheet stays old.

## Not in this version

- **No retry button in the drawer.** By the time a write is quarantined it sat at the
  head of the queue while everything behind it went through, so replaying it out of
  order is the app guessing what was meant. Google Calendar is the source of truth and
  the place retroactive edits already happen; the drawer's job is to say where to look.
- **No CI changes.** `.github/workflows/pages.yml` keeps publishing the docs site and
  keeps running no tests. The overnight loop runs locally; local is where checking must
  work.
- **No testing against the deployed URL.** Local render only.
- **The manual phone paste stays exactly as it is.** Headless Chromium on a Mac is not a
  phone, and two of the three bug classes `test/smoke.js` exists for only appeared on
  the phone. `test/README.md`'s instruction to run it on the phone is not superseded.
- **Nothing from the README's non-goals.** No notifications, no detection, no streaks or
  scores, no AI summaries, no charts, no settings screen, no writes to PLAN.
- No change to normal-use behaviour: grid, taps, marks, posture, split, sit-edit.

## Facts (discovered, not asked)

**Stack.** Google Apps Script web app. No build step, no dependencies, no
`package.json`. Four source files at the repo root:

| File | What |
|---|---|
| `Code.gs` (1104 lines) | Server. CONFIG block, calendar reads/writes, week aggregation, rollup. |
| `Index.html` (1063 lines) | Client. All CSS/JS inlined. |
| `appsscript.json` | Manifest, one OAuth scope. |
| `SETUP.md` | Deploy steps. |

**Tests.** Three layers, documented in `test/README.md`:
- `node test/tests.js` — 253 assertions against the real `Code.gs` and the real script
  extracted from `Index.html`, behind shims for `CalendarApp`, `SpreadsheetApp`,
  `PropertiesService`, `ScriptApp`, `HtmlService`, `LockService` and a small DOM.
  Virtual clock. Meant to be run under several `TZ` values.
- `node test/lint.js` — static checks over the source; every rule maps to a bug that shipped.
- `test/smoke.js` — pasted into a browser console with the app open; returns
  `{ pass, fail, failed }`. The only layer that has seen a pixel.

Test command: `node test/tests.js && node test/lint.js`. `deploy.sh` runs both before
pushing via clasp; `--no-test` skips them.

**Relevant code locations.**
- Server-side meta tags injected by `HtmlService` — `Code.gs:176` (`doGet`), three tags
  including viewport, added because Apps Script ignores meta tags written in the HTML file.
- Quarantine of failed writes — `Index.html:497`, dead list in `localStorage` key
  `tt.dead.v1` (`Index.html:358`), capped at 50 entries.
- Dead-count message on boot — `Index.html:964`.
- Error banner element `#err` — `Index.html:307`.
- Existing full-screen overlay sheets `#sheetSplit` / `#sheetSit` (`.view hidden`) —
  `Index.html:311`, `Index.html:332`. The drawer follows this pattern.
- `dailyRollup` — `Code.gs:817`. No try/catch, no record of having run.
- `openSheet_` — `Code.gs:972`. Most likely failure point (bad or revoked sheet id).
- `writeGrid_` — `Code.gs:985`. Rebuilds each tab wholesale, so a stamp row is cheap.
- `say_` — `Code.gs:811`. Logs to the Apps Script execution log, which nobody reads on a Sunday.

**Environment.** node v26.5.0. `.gitignore` already lists `node_modules/`. Existing CI
publishes docs to GitHub Pages only.

**Product law, from README.md.** Automate capture, never automate judgment. The app
never interprets, scores, advises, summarises, reminds or nudges.

## Decisions made

1. Build all three features this round, not one. Acknowledged as the top of what one
   overnight run finishes cleanly (~9-12 tasks); plan is ordered so the two cheap
   features land before the expensive one, so a partial night still delivers.
2. Headless smoke renders **`Index.html` locally**, not the deployed URL — fast, offline,
   runs before every deploy.
3. Because a local render isn't the page Apps Script serves, the harness **replicates the
   three server-side meta tags**, and a **lint rule fails if `Code.gs`'s tag list and the
   harness's ever drift apart**. This is what makes local rendering honest.
4. The headless harness **loads `test/smoke.js` itself into the page** and reads its
   `{ pass, fail, failed }`, rather than reimplementing the checks. One source of truth;
   the phone paste and the machine run cannot disagree.
5. Runs at **two viewports**: phone and desktop.
6. **Local only** — new `package.json`, browser installed locally, third gate in
   `deploy.sh`. No CI job.
7. If the browser isn't installed, the run **skips loudly and `deploy.sh` refuses to
   deploy**. A silent skip counted as a pass is the vacuous-assertion bug `test/README.md`
   already has a scar from.
8. Drawer opens from the existing error banner, as a third overlay sheet matching
   `#sheetSplit` / `#sheetSit`. No settings screen.
9. Drawer is **show + discard**, no retry — see "Not in this version" for why.
10. Rollup outcome is recorded in a **script property** (always writable, survives the
    sheet being unopenable) and **stamped as a "last rebuilt" line into both generated
    tabs**. A stale timestamp above the numbers is the signal; no alert, no notification.

## Open risks

- **The drift lint is the load-bearing check and the easiest to write vacuously.** It is
  the only thing making "render locally" honest rather than a convenient fiction. If it
  is implemented as a shallow string match that passes regardless, the whole first feature
  becomes theatre. Its test must prove it fails: change a meta tag in one place only, and
  the lint must fail by name.
- **All three features live on error paths**, which normal use never reaches, so a wrong
  implementation is invisible. Every acceptance test must force the failure — a server
  that always rejects, a sheet id that cannot open, a deliberately desynchronised tag list
  — never observe the happy path and infer.
- **First `package.json` in the repo.** A repo whose README opens with "no dependencies"
  gains a dev-only dependency. Source files stay dependency-free; the claim needs restating
  accurately rather than quietly becoming false.
- **Three features is the top of one night.** If the loop stalls, expect it on the headless
  smoke test.
