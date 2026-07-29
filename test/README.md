# tests

Three layers, because they are blind to different things. `deploy.sh` runs all
three before it pushes anything.

The third layer, `test/smoke.js`, is checks that need a real engine. They run
two ways and both are needed: `node test/headless.js` runs them in a headless
browser on your machine, and you paste the same file into the console on your
phone. The headless run is the one a machine can do; the phone is the only place
some of these bugs have ever appeared.

## `node test/tests.js`

1162 assertions against the real `Code.gs` and the real script out of
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
with the zone named and the run continues — 1160 passed, 2 skipped, because section 46
compares against the same golden. A skip is never
counted in `passed`: a run that could not reach a section has to look different
from one that ran everything. If the fixture itself is missing or unreadable the
suite says so and stops, rather than throwing partway through.

The shim deliberately mirrors two things the real parser does, both of which hid
a real bug before it did: an id that the markup never declares resolves to
`null`, and interactive content written into a `<button>` is dropped.

It borrows two things from the markup rather than inventing them. Initial
classes, so no test can read a hidden element as visible — that is where the
undo ribbon read as up on every cold load. And nothing else: `role`,
`aria-modal`, `tabindex` and the rest are declared in the markup and are
`smoke.js`'s business, because only a real parser can say whether they reached
the document.

Document-level handlers are kept **by type**. It used to keep
`visibilitychange` and drop the rest on the floor, so the `Escape` handler that
closes a sheet would have been discarded silently while every assertion about
that key passed. `H.fireDoc(type, ev)` delivers one and returns how many
handlers heard it, so a test can refuse to pass when the answer is none.

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
| no interactive content inside a `<button>` in the markup | the parser drops it, so `querySelector` finds nothing and the builder throws |
| nor in a template a script assigns to a `<button>` | the same drop, one step later, where the markup rule cannot see it |
| marks are ASCII | `parseTitle_` matches `+ = -` literally; a dash lookalike silently stops parsing |
| no writable handle to PLAN | PLAN is read-only and must stay that way structurally |
| the source files pull nothing in | Apps Script has no module loader; an import or CDN URL is a blank screen, not a build error |
| the headless browser is a dev dependency | nothing in `test/` is deployed, and a runtime dependency would be |
| the browser version is pinned exactly | a floating version makes "the pinned browser still launches" meaningless |
| both meta tag lists parse non-empty | a parser that quietly matched nothing would make the two rules below pass while comparing nothing |
| neither list declares a tag twice | a duplicate name hides a difference behind whichever copy is read last |
| `doGet` and `test/headless.js` inject the same meta tags | the headless run would render a document the phone never loads, and pass while doing it |
| every meta tag name is one Apps Script permits | `addMetaTag` throws at request time for any other name — a crash you only see on the deployed URL |
| no file in the repo contains a NUL byte | git calls the file binary, so `git diff` shows nothing and the file stops being reviewable |
| the docs describe the controls and marks a user will meet | a control nobody documented is one the user meets for the first time on their own phone. It reads the STOP label and the undo ribbon's own copy out of `Index.html`, so renaming either without touching `README.md` is what fails, and it refuses to run if it could not find them to compare |
| the docs say how a PLAN event has to be titled, and show a real key | a plan written any other way counts toward nothing and the sheet cannot say why. The example key is checked against `CATEGORIES`, so the docs cannot drift into showing a key the app does not have |
| every constant `SETUP.md` quotes has that value in `Code.gs` | C1 changed `MISTAP_SECONDS` from 90 to 20 and left the setup guide saying 90. Every documented constant is checked, and documenting one that `Code.gs` does not declare fails too |
| every `.md` in the repo agrees with the manifest about scope counts | `README.md`'s manifest row disagreed with `appsscript.json` for long enough that a build contract quoted the wrong number as fact, and then two more docs quoted it from there |
| `GUIDE.md` Part 2 does not present the shelf double-tap as live | Part 2 kept describing the round-1 drawer bug in the present tense after Part 3 had the shipped fix; five markers were not a repair. The rule fails if Part 2 again says the bug "is broken", that "the build isn't finished", or that a double-tap destroys a second entry |

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

A further phase measures the posture row in the worst case it ever has to survive:
pending writes **and** an open SIT **and** a running block, so all four of `#sync`,
`#postureBtn`, `#sitEdit` and `#stopBtn` are in one fixed 72px row at once. It runs at
390px and at 980px, and checks hit boxes against 44x44, pairwise overlap, horizontal
overflow, whether STOP is hittable at its own centre, whether the posture label is
legible, and that an armed STOP differs from a resting one in **both** text and
styling. Geometry is measured twice — resting and armed — because the armed label is
the one that might not fit. It then ends a 40-minute block with STOP for real, so the
mark strip comes up over the row, and checks that dismissing the strip gives STOP back.

Four notes on why it is shaped the way it is, each of them a mutation that survived an
earlier version of the check:

- The server stub accepts calls and never answers. A stub that succeeded would drain
  the queue and hide `#sync`, which is the easy case rather than the worst one.
- The styling comparison excludes width and height. A longer armed label makes an
  auto-width button wider by itself, so measuring the box would just re-detect the
  text change and report it as styling.
- The label is judged on the axis it can actually fail on. `scrollWidth >
  clientWidth` can never fire for `#postureLabel`, which is `display:block` with
  `white-space:normal` and therefore wraps rather than overflowing. What is measured
  instead: whether any word occupies more than one line box (a word cut in half),
  whether the label outgrows the control holding it, and whether an ancestor clips it.
- The click has a short timeout and reports failure as a finding. Something covering
  the row otherwise surfaces as a 30-second Playwright stack trace with no criterion
  name in it.

It also measures the strip's own controls and prints them. They are not asserted: the
strip is hidden in the resting worst case, so they fall outside the criterion. They are
currently 42px tall, which is under the 44px floor the rest of the row is held to.

A phase for the SPLIT sheet, which now does two different things — reassign the
remainder, or recategorise the whole block — and asks in the sheet which one it will
do. It seeds a three-hour-old block, re-taps the lit cell to open SPLIT for real, and
checks that both options are on screen at once (an option you have to scroll to find
is an option that does not exist), that each is at least 44x44 and hittable at its own
centre, that they do not overlap, that the sheet is not already scrolled, and that the
chosen one differs from the other on **two** channels rather than a hue shift alone.
Then it chooses the other option and checks that the chosen state, the label naming
what the next tap will do, and `aria-pressed` all move with it — `aria-pressed` is
read only *after* the choice moves, because the static markup happens to be right
before it does, so a first-read check would pass a build that never updated it. It
runs at 390px and at 980px: the desktop viewport is the shorter of the two, so a sheet
that needs scrolling shows up there first.

A second drawer phase counts rather than watches: it taps one fixed point 2, 3, 4 and
6 times and checks that 1, 1, 2 and 3 entries left, and — the part that actually
matters — that **every** tap which destroyed an entry found a button already reading
`TAP AGAIN TO DISCARD` under the finger. Rows *do* slide up when one is removed; what
makes that safe is arm/confirm, not a frozen layout, and this is the check that pins
it (contract assertion 24, amendment A4). Revert `armDead` to discard on the first tap
and it fails naming the tap number and what the button said at the time.

Three phases came out of the Day Rail rounds, and each of them measures something
the suite above is structurally blind to because it has no layout.

**The reach of the guardrails**, at 6, 7, 8 and 10 categories — 10 is
`MAX_CATEGORIES`, and the Add row invites the user all the way there. It checks
that the undo ribbon's hit box is fully on screen and at least 44px tall, that
`elementFromPoint` at its centre returns the ribbon and not whatever is behind it,
that each of the three mark buttons is 44×44 and hits itself, that the strip's
label fits the width it is given, and that a tap a few pixels below the ribbon
reaches no control at all. At seven categories a tap where the ribbon appeared
used to toggle sitting and write a block; at ten the ribbon was off the screen
entirely.

**The rail's box**, at 6, 20 and 40 blocks. 6 is an ordinary day, 20 is where the
old constant first overflowed, 40 is the criterion. It checks that the last
segment and `NOW ▲` are on screen, that `NOW ▲` is still inside the *column* it
labels rather than merely inside the window — `#railSegs` grows past its flex
allocation, and that comparison fails one length of day earlier than the viewport
one does — that the page scrolls in neither axis, and that the category column is
still visible.

Its fixture pins the page clock with `page.clock.setFixedTime` before anything
loads. It lays the day backwards from now, and `railBlocks` correctly drops
whatever ended before local midnight, so a real clock made the phase impossible to
assemble before about 10:15 in the morning: the run was red for the first ten
hours of every day and green for the rest, with `deploy.sh` refusing to deploy in
the mornings. Pinning it keeps the premise real — a forty-block day is ten hours
long — and makes the numbers identical at every hour, so a failure reproduces
whenever it is convenient to look at it. The guard that catches a fixture which
did not assemble counts `blocks + 1`, because the day is `blocks` closed segments
plus the open one; it counted `blocks`, so a rail one segment short passed and was
then measured as though it were the day it names.

**Sheet modality**, at both viewports. The sheets are opaque and full-screen, and
for two rounds that was all they were. This walks 24 Tabs with SPLIT open and
checks every one of them lands inside the sheet, that `#app` carries the `inert`
attribute while a sheet is up and loses it when the last one closes, that focus
starts on DONE rather than on the slider, that `Escape` closes the sheet, and that
focus returns to the control that opened it. Before it, the ten controls *behind*
SPLIT came first in the tab order — the tenth Tab was STOP — and tabbing to a
category row switched the block while the sheet went on naming the old one. `inert`
is one attribute doing a great deal of work, and this is the check that says the
engine honours it rather than the code asking politely.

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

This layer exists because the suite above is structurally blind to four classes,
each of which shipped a bug:

| Class | What got through |
|---|---|
| CSS cascade | both posture figures visible at once; a black ring on a black page |
| Viewport | `100vh` overriding `100dvh` — the app was taller than the screen |
| HTML parsing | `<input>` inside `<button>`, silently dropped |
| Declared ARIA | `role`, `aria-modal`, `aria-live` and `tabindex` live in the markup, and the suite's shim borrows only `class` from it — so nothing else could say whether they reached the document |

None of those is reachable without a real engine, a real cascade and a real
viewport. Every check in the file corresponds to a bug that actually shipped, so
a failure names the regression rather than a symptom.

There are 30 checks. Two of them skip on a cold load — the lit ring's colour and
inset, which need a running block — so a clean run reads `28 passed, 0 failed`.
`node test/headless.js` counts `pass + fail + skipped` against the number of
`ok(` calls in the file, so a check that quietly stopped running is caught rather
than absorbed into the total.

Eight of the thirty came out of the Day Rail rounds. Four are the clocks and the
guardrail: `font-variant-numeric` computed as `tabular-nums` on **every** element
carrying `.tnum` — the class was applied correctly throughout and did almost
nothing, because each rule then set the `font:` shorthand, which resets it — plus
the undo ribbon's `role` and `tabindex`, its announcer being a live region that is
present and unhidden at rest, and the rail carrying a role and a label so
"hatched means unlogged" is not left to colour. Four more are the sheets:
`role="dialog"`, `aria-modal="true"`, a name on each, and `#app` not being `inert`
while nothing is over it. The sheets are found by querying `.view` rather than by
a list written out here, so a fourth sheet is checked by existing.

Run it on the phone, not just the laptop. Two of those three only showed up on
the phone, and `node test/headless.js` does not change that — it runs these same
checks on your machine, where those two are not visible.

One warning from writing it: `ok()` judges arrays by length and booleans by
themselves, and shouts at anything else. It did not, at first — it did `!!cond`,
and an empty array is truthy, so two checks passed vacuously no matter what they
found. An assertion that cannot fail is worse than no assertion, because it is
counted.
