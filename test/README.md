# tests

Three layers, because they are blind to different things. `deploy.sh` runs all
three before it pushes anything.

The third layer, `test/smoke.js`, is checks that need a real engine. They run
two ways and both are needed: `node test/headless.js` runs them in a headless
browser on your machine, and you paste the same file into the console on your
phone. The headless run is the one a machine can do; the phone is the only place
some of these bugs have ever appeared.

## `node test/tests.js`

492 assertions against the real `Code.gs` and the real script out of
`Index.html`, run in node behind a shim for `CalendarApp`, `SpreadsheetApp`,
`PropertiesService`, `ScriptApp`, `HtmlService`, `LockService` and a small DOM.
A virtual clock lets a test wait ninety minutes in a millisecond.

Run it under a few zones — every day boundary in the app is timezone-dependent:

```bash
for z in America/New_York Europe/London Australia/Sydney UTC; do
  TZ=$z node test/tests.js | tail -1
done
```

Those four are the contracted zones, and section 39d compares both rollup grids
against a golden captured per zone in `test/fixtures/rollup-golden.json`. In a
fifth zone there is no golden to compare against, so 39d reports as **skipped**
with the zone named and the run continues — 482 passed, 1 skipped. A skip is never
counted in `passed`: a run that could not reach a section has to look different
from one that ran everything. If the fixture itself is missing or unreadable the
suite says so and stops, rather than throwing partway through.

The shim deliberately mirrors two things the real parser does, both of which hid
a real bug before it did: an id that the markup never declares resolves to
`null`, and interactive content written into a `<button>` is dropped.

## `node test/lint.js`

Static checks over the source. Every rule exists because a bug of exactly that
shape shipped, and none of them is reachable by running the code: they are
properties of the file.

| Rule | The bug it prevents |
|---|---|
| every id the script asks for is declared | a handler left on a deleted element — a blank screen, twice |
| every id the stylesheet targets exists | dead rules that read as if they still work |
| every `var(--x)` is defined | an undefined custom property computes to the initial value, not a fallback |
| `100dvh` comes after `100vh` | the later declaration wins; reversed, the app is taller than the screen |
| no interactive content inside a `<button>` | the parser drops it, so `querySelector` finds nothing and the builder throws |
| marks are ASCII | `parseTitle_` matches `+ = -` literally; a dash lookalike silently stops parsing |
| no writable handle to PLAN | PLAN is read-only and must stay that way structurally |
| the source files pull nothing in | Apps Script has no module loader; an import or CDN URL is a blank screen, not a build error |
| the browser is a dev dependency, pinned exactly | nothing here is deployed, and a floating version makes "the pinned browser still launches" meaningless |
| both meta tag lists parse non-empty | a parser that quietly matched nothing would make the two rules below pass while comparing nothing |
| neither list declares a tag twice | a duplicate name hides a difference behind whichever copy is read last |
| `doGet` and `test/headless.js` inject the same meta tags | the headless run would render a document the phone never loads, and pass while doing it |
| every meta tag name is one Apps Script permits | `addMetaTag` throws at request time for any other name — a crash you only see on the deployed URL |
| no file in the repo contains a NUL byte | git calls the file binary, so `git diff` shows nothing and the file stops being reviewable |
| every `.md` in the repo agrees with the manifest about scope counts | `README.md`'s manifest row disagreed with `appsscript.json` for long enough that a build contract quoted the wrong number as fact, and then two more docs quoted it from there |

## `node test/headless.js`

Runs `test/smoke.js` inside a real browser engine, at a phone viewport and a
desktop viewport, and reports pass/fail counts for each.

It also drives the drawer of set-aside writes at real coordinates — open it, then
double-tap DISCARD at one fixed point and check that exactly one entry left and it
was the one aimed at. That check is here rather than in the suite above because the
suite's DOM shim has no layout, so it cannot express a control moving into the place
a finger has already committed to. That is precisely how a single-tap DISCARD used to
destroy a second write the reader had never looked at, while a test named "discarding
the same row twice is a no-op" passed.

A second drawer phase counts rather than watches: it taps one fixed point 2, 3, 4 and
6 times and checks that 1, 1, 2 and 3 entries left, and — the part that actually
matters — that **every** tap which destroyed an entry found a button already reading
`TAP AGAIN TO DISCARD` under the finger. Rows *do* slide up when one is removed; what
makes that safe is arm/confirm, not a frozen layout, and this is the check that pins
it (contract assertion 24, amendment A4). Revert `armDead` to discard on the first tap
and it fails naming the tap number and what the button said at the time.

```bash
npm install          # once; installs the pinned headless browser
node test/headless.js
```

It renders what `doGet` actually serves, not `Index.html` off the disk — that
file still has the `bootstrap` placeholder in it and the client script throws
without real config. Apps Script wraps the fragment in its own document and
injects the meta tags, so the runner rebuilds that wrapper. A document assembled
any other way is not the one the phone loads.

The meta tag list is written out twice on purpose: once in `doGet`, once in
`test/headless.js`. Deriving one from the other would make the comparison
self-fulfilling — whatever `doGet` sent would be whatever the harness injected,
agreeing by construction while nothing was pinned. The drift rule in
`test/lint.js` is the only thing holding the two copies together, and it names
the tag and says which side is missing it.

If the browser is not installed, the run exits non-zero and names the install
command, and `deploy.sh` stops. A skipped run is never reported as a pass.

**This does not replace the phone paste.** Of the three bug classes below, only
the CSS cascade one is reliably visible here. In a headless engine `dvh` and
`vh` are equal, and every check in `smoke.js` is relative — with no viewport
meta at all the page lays out at 980px and all of them still pass. The phone is
where those bugs showed up and it is still where you find them.

## `test/smoke.js`

Paste it into the browser console with the app open. It returns
`{ pass, fail, failed, skipped }`. A skipped check is one the current state
could not reach; it is never counted as a pass.

This layer exists because the suite above is structurally blind to three classes,
each of which shipped a bug:

| Class | What got through |
|---|---|
| CSS cascade | both posture figures visible at once; a black ring on a black page |
| Viewport | `100vh` overriding `100dvh` — the app was taller than the screen |
| HTML parsing | `<input>` inside `<button>`, silently dropped |

None of those is reachable without a real engine, a real cascade and a real
viewport. Every check in the file corresponds to a bug that actually shipped, so
a failure names the regression rather than a symptom.

Run it on the phone, not just the laptop. Two of those three only showed up on
the phone, and `node test/headless.js` does not change that — it runs these same
checks on your machine, where those two are not visible.

One warning from writing it: `ok()` judges arrays by length and booleans by
themselves, and shouts at anything else. It did not, at first — it did `!!cond`,
and an empty array is truthy, so two checks passed vacuously no matter what they
found. An assertion that cannot fail is worse than no assertion, because it is
counted.
