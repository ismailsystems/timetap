# tests

Two layers, because they are blind to different things.

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
