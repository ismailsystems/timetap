# Progress — timetap error paths round

handoff: factory/HANDOFF.md
branch: factory/error-paths
baseline at launch: 298 assertions green under 4 timezones, `node test/lint.js` clear

Status values: `pending` · `in progress` · `done` · `PARKED`
A task is `done` only after the CHECKER step has independently re-verified it.

| Task | Title | Status | Attempts | Notes |
|---|---|---|---|---|
| A1 | Force a server failure; prove a write is set aside | done | 1 | All 5 criteria pass against **unmodified** `Index.html` — no finding, nothing to park. 21 new assertions (298 → 319), green under all 4 zones, lint clear. Checker: mutation-tested, see log. |
| B1 | A set-aside write identifies its block | done | 1 | All 5 criteria verified. 1-4 in section 35-35d; criterion 5 verified in section 36f once B2 gave it a surface to render on. Found F1 and F2 on the way. |
| B2 | Banner opens a drawer of set-aside writes | done | 1 | 35 assertions (337 → 372, 4 zones, lint clear). Fixes F1 and F2. CHECKER: 7 mutations, all caught — one of them (singular verb) only after I noticed my tests covered the plural case alone. |
| B3 | Discard an entry; banner clears with the last | done | 1 | 19 assertions (372 → 391, 4 zones, lint clear). CHECKER: 3 mutations, all caught — position-based identity, discard reaching into the queue, drawer not closing on the last entry. |
| C1 | A failed rollup records why | done | 1 | 19 assertions (391 → 410, 4 zones, lint clear). Record-then-rethrow into script property `ROLLUP_LAST`. CHECKER: 3 mutations, all caught. |
| C2 | Both tabs carry a last-rebuilt stamp | done | 1 | 30 assertions (410 → 440, 4 zones, lint clear). Golden fixture `test/fixtures/rollup-golden.json` captured from d048ca3, before the stamp existed. CHECKER: 5 mutations, all caught. One existing test amended (see log). |
| C3 | Last outcome readable by hand | done | 1 | 19 assertions (440 → 459, 4 zones, lint clear). `rollupStatus()`, runnable from the editor. CHECKER: 4 mutations, all caught. **Stage C complete.** |
| D1 | A real browser opens Index.html | done | 1 | `test/headless.js` + `test/serve.js`, Playwright pinned 1.62.0 (exact). 3 new lint rules. CHECKER: 4 lint mutations + both missing-browser paths, all exit non-zero. Tier-4 canary: chromium-1234 launches on this machine. |
| D2 | Harness serves the page as Apps Script does | done | 1 | 5 of 6 criteria met and verified. **Criterion 6 is PARKED — see F4**, with evidence and a question; not weakened, not declared met. Found and fixed F3. |
| D3 | Desktop viewport too, reported separately | done | 1 | Both viewports labelled with their dimensions and reported separately. CHECKER: a phone-only CSS break fails phone / passes desktop / exits 1 naming phone; zero checks at one viewport exits 1 even though the other passed. |
| D4 | Drift lint on the meta tags (HIGH RISK) | done | 1 | All 6 criteria verified against fixture copies, plus 2 extra vacuity guards. **META-TEST PERFORMED**: neutering the rule makes exactly criteria 2, 3 and 4 stop detecting — three, as required. See log for the full transcript. |
| D5 | deploy.sh gains a third gate | done | 1 | All 5 criteria exercised with a stub `clasp` prepended to PATH and a dummy `.clasp.json` in a fixture copy — the real `.clasp.json` was never read and no real deployment happened. **Stage D complete.** |
| E1 | Docs describe what now exists | pending | 0 | |

## Parked questions for the human

<!-- Anything the handoff does not answer. Write the question and what you did
     instead (park the task, or proceed on a stated assumption). -->

**D2, criterion 6 (see F4 below).** No check in `smoke.js` is viewport-sensitive, and Blink
re-lays-out when a viewport meta is appended, so "inject the tags after render and watch the
viewport checks fail" cannot be demonstrated. I built the control that proves the injection
point matters by a layout fact instead (390px with the tags, 980px without), and left the
criterion as written unmet rather than redefining it. **Your call: accept the layout-fact
control, or add a genuinely viewport-sensitive check to `smoke.js` (which changes the file
the phone paste uses)?**

## Bugs found while building

<!-- Standing rule: a bug gets a criterion here FIRST, then the fix. -->

### F3 — `smoke.js` counts a check that cannot fail (found during D2)

`test/smoke.js:78` reads `ok('no block running, ring not checked', true, ...)`. It is
literally `true`, so it is a pass no matter what the page does, and it is counted in
`pass`. That is the exact class `test/README.md:63` records — an assertion that cannot
fail is worse than none, because it is counted. It also makes the check count
underivable: 20 call sites, 18 executed, and no way to tell a skipped check from a real
one.

- [tier 3] Given no block is running, then the ring check is reported as **skipped**, not
  as passed, and `pass` counts only checks that could have failed.
- [tier 3] Given the runner, then `pass + fail + skipped` equals the number of `ok(` call
  sites in the file — so a check added to `smoke.js` can never silently go unrun.

### F4 — no check in `smoke.js` is viewport-sensitive, so D2's last criterion cannot be met as written (found during D2)

D2's sixth criterion asks that injecting the meta tags *after* render make the
viewport-dependent checks in `smoke.js` fail. Measured on Playwright 1.62.0 / chromium-1234:

| metas | layout width | smoke result |
|---|---|---|
| before render | 390px (correct) | 18 pass, 0 fail |
| after render | 390px — Blink re-lays-out on a dynamically added viewport meta | 18 pass, 0 fail |
| never injected | 980px (definitively the wrong document) | 18 pass, 0 fail |

Two independent reasons it fails: (1) "after" is indistinguishable from "before", because
Blink re-runs layout when a viewport meta is appended; (2) more seriously, **even with no
meta at all and a 980px layout, every smoke check still passes** — the checks are all
relative (`app` height vs `window.innerHeight`, cells equal width, rows full), and those
hold at any layout width. `smoke.js` opens by saying it exists to catch the viewport bug
class; in a headless engine, where `dvh` and `vh` are equal, it structurally cannot.

The injection point *does* matter — 390 vs 980 proves it. `smoke.js` just cannot see it.

**PARKED for the human.** Question: should the control prove the injection point matters
by a layout fact read from the live DOM (`documentElement.clientWidth` 390 with the metas
vs 980 without), which is what the criterion is *for*? Or should `smoke.js` gain a genuinely
viewport-sensitive check, which changes the file the phone paste uses? I have implemented
the first and left the criterion unsatisfied rather than declaring it met. This is also
direct evidence for the standing claim that the phone paste is not superseded.

### F1 — FIXED in B2 — the boot-time "set aside" banner erases itself (found during B1)

`boot()` calls `showErr(...)` with the set-aside count (`Index.html:964`), then drains and
calls `loadServerState()`, whose success handler calls `hideErr()` (`Index.html:906`). On
any healthy load the message is wiped before it can be read. It survives only when the
state load *also* fails — i.e. the message is visible exactly when it is least useful.
Contract item 9 requires the banner visible whenever a write has been set aside, so this
blocks B2 rather than being cosmetic.

Criteria (must pass before F1 is considered fixed):

- [tier 1] Given at least one set-aside write and a *healthy* server, when the app boots
  and the state load succeeds, then the banner is still visible.
- [tier 1] Given no set-aside writes, when the app boots and a transient error is shown
  and then cleared, then the banner is hidden — `hideErr()` still works for its own cases.
- [tier 1] Given a set-aside write and a later successful flush, then the banner does not
  get erased by that success either.

### F2 — FIXED in B2 — the count reads "1 write were set aside" (found during B1)

`Index.html:964` pluralises the noun but not the verb, so a single entry reads
`1 write were set aside after repeated failures`.

- [tier 1] Given exactly one set-aside write, then the message reads "1 write was set
  aside"; given two, "2 writes were set aside".
