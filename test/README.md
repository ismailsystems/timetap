# tests

Three layers, because they are blind to different things. `deploy.sh` runs the
first two before it pushes anything; the third is a paste into a browser
console, and it is the only one that has ever seen a pixel.

## `node test/tests.js`

253 assertions against the real `Code.gs` and the real script out of
`Index.html`, run in node behind a shim for `CalendarApp`, `SpreadsheetApp`,
`PropertiesService`, `ScriptApp`, `HtmlService`, `LockService` and a small DOM.
A virtual clock lets a test wait ninety minutes in a millisecond.

Run it under a few zones — every day boundary in the app is timezone-dependent:

```bash
for z in America/New_York Europe/London Australia/Sydney UTC; do
  TZ=$z node test/tests.js | tail -1
done
```

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

## `test/smoke.js`

Paste it into the browser console with the app open. It returns
`{ pass, fail, failed }`.

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
the phone.

One warning from writing it: `ok()` judges arrays by length and booleans by
themselves, and shouts at anything else. It did not, at first — it did `!!cond`,
and an empty array is truthy, so two checks passed vacuously no matter what they
found. An assertion that cannot fail is worse than no assertion, because it is
counted.
