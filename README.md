# timetap

A personal time-logging web app. Google Apps Script, four files that import
nothing and need no build step.

The repo has dev-only test tooling with one dependency (a headless browser, used
by `test/headless.js`). None of it is deployed: what goes up is the four files
below, exactly as they are.

**Automate capture. Never automate judgment.**

Logging costs one tap. The app never interprets, scores, advises, summarises,
reminds or nudges. Every conclusion is drawn by the human, later, elsewhere.

You maintain a **PLAN** calendar by hand (intent, written Sunday). The app
writes an **ACTUAL** calendar (record, written continuously) and a **SITTING**
calendar (posture overlay). Comparing them is a weekly manual ritual the app
does not participate in beyond emitting raw numbers.

## Files

| File | What it is |
|---|---|
| [`appsscript.json`](appsscript.json) | Manifest. Three OAuth scopes, all load-bearing. Set your timezone here. |
| [`Code.gs`](Code.gs) | Server. CONFIG block, calendar reads/writes, week aggregation. |
| [`Index.html`](Index.html) | Client. All HTML/CSS/JS inlined. No CDN, no build step. |
| [`SETUP.md`](SETUP.md) | Deployment steps and the required Google Calendar settings. |

Start with [SETUP.md](SETUP.md).

## How it works

The calendar is the source of truth, not localStorage. Tapping a category
immediately creates an event with `start = now`, `end = now + 1 minute`, and
`#open` in the description. The next tap patches the end to that instant,
applies the mark, and strips `#open`. This survives a dead battery and a
reinstall — on load the open block is found by querying the calendar, not by
trusting the browser.

The UI updates on tap and the write happens in the background. When the write
fails, the operation is queued in localStorage, ordered and idempotent, and
retried on the next interaction and on load.

### The mark

The mark belongs to the block that just **closed**, captured at the transition
— the one moment you both know how it went and are already holding the phone.
A closed block shows the `+ = -` strip only if its category has no `autoMark`
and it ran at least `MIN_MARK_MINUTES`. Ignoring the strip costs zero taps: it
dismisses itself and `=` stands. You should see it two to four times a day.

### Posture

Posture is an overlay, not a seventh category. Categories are a partition —
exactly one true at a time. You sit *while* doing deep work, meetings, meals.

One button below the grid, reading **SITTING** or **NOT SITTING**. Only sitting
is written down — not sitting is the absence of a SIT block rather than a row of
its own, so the button needs nothing remembered to know what it says. Only
sitting carries a duration, because only sitting has a start to count from, and
that duration is also the way in to correcting it.

The only coupling in the entire app: tapping `BODY` closes an open SIT block
and drops the button to not sitting. That is definitional, not inference. No
accelerometer, no screen time, no heuristics, ever.

### The numbers

There is no week screen. A daily trigger rebuilds two tabs of a Google Sheet
from the calendars — `daily`, one row per day for ninety days, and `weekly`,
the same numbers grouped Monday to Sunday with the planned-versus-actual ratio.
Both are rebuilt rather than appended, so the job is idempotent and a
retroactive calendar edit corrects itself.

The app emits the grid and stops. No charts, no highlighting, no commentary.

## Non-goals

No notifications. No automatic detection of anything. No streaks, scores or
badges. No AI summaries or insights. No charts. No settings screen. No
onboarding. No writes to PLAN, ever.
