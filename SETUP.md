# timetap — setup

Automate capture. Never automate judgment.

Four files. No dependencies, no build, no accounts beyond the Google account
you already have. Twenty minutes end to end.

---

## 1. Create the three calendars

Open [Google Calendar](https://calendar.google.com) on a desktop browser
(the mobile app cannot create calendars or show calendar IDs).

Left sidebar → **Other calendars** → **+** → **Create new calendar**.

Create three, exactly these roles:

| Name      | Role                                                        |
|-----------|-------------------------------------------------------------|
| `PLAN`    | You write it by hand on Sunday. The app **never** touches it. |
| `ACTUAL`  | The app writes it continuously.                             |
| `SITTING` | The app writes it continuously. Posture overlay.            |

Set the timezone on each one to your own. Names do not matter to the code —
only the IDs do — but future you will be reading these in the calendar UI, so
keep them blunt.

---

## 2. Find each calendar ID

**Settings** (gear, top right) → **Settings for my calendars** → click the
**specific calendar** in the left sidebar → **Integrate calendar** →
**Calendar ID**.

It looks like:

```
c_8f31a9c4e2b7d05f1a6e3c9b8d47e21f0a5c6b3d9e8f7a2b1c4d5e6f@group.calendar.google.com
```

Copy all three. Do this per calendar — the ID lives under each calendar's own
settings page, not under the top-level General settings.

---

## 3. Create the Apps Script project

1. Go to [script.google.com](https://script.google.com) → **New project**.
2. Rename it `timetap` (click "Untitled project" at the top).
3. Gear icon (**Project Settings**) → tick
   **Show "appsscript.json" manifest file in editor**.
4. In the editor's file list, you now have `Code.gs` and `appsscript.json`.
   Add one more: **+** next to Files → **HTML** → name it exactly `Index`
   (Apps Script appends `.html` itself — do not type the extension).

Now paste, replacing the entire contents of each file:

| Editor file       | Paste from       |
|-------------------|------------------|
| `appsscript.json` | `appsscript.json`|
| `Code.gs`         | `Code.gs`        |
| `Index.html`      | `Index.html`     |

**Set the timezone** in `appsscript.json`. It ships as
`"timeZone": "America/New_York"` — change it to your own
[IANA zone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
(`Europe/London`, `America/Los_Angeles`, `Asia/Tokyo`, …). Everything the app
does with day boundaries and the week window reads from this one value via
`Session.getScriptTimeZone()`.

**Save** (⌘S / Ctrl-S).

The Advanced Calendar Service is **not** required. Every write goes through
`CalendarApp`, so the manifest needs exactly one scope,
`https://www.googleapis.com/auth/calendar`, and nothing under `dependencies`.

---

## 4. Paste the calendar IDs into CONFIG

Top of `Code.gs`:

```js
var CAL_PLAN    = 'c_...@group.calendar.google.com';
var CAL_ACTUAL  = 'c_...@group.calendar.google.com';
var CAL_SITTING = 'c_...@group.calendar.google.com';
```

While you are there, the rest of the CONFIG block is the whole settings
surface of the app. There is no settings screen and there will never be one.

- `CATEGORIES` — add or remove entries and the button grid, the week report
  and the mark rules all follow. Nothing else needs editing. Keys become the
  `"KEY:"` title prefix, so keep them short and uppercase.
- `autoMark` — `'+'`, `'='`, `'-'` or `null`. Non-null means that category
  never shows the mark strip; the mark is applied silently. `null` means the
  strip may appear.
- `MIN_MARK_MINUTES` (15) — shorter blocks get no mark and no strip.
- `MISTAP_SECONDS` (90) — a tap this soon after the last one is a correction.
- `STALE_OPEN_HOURS` (5) — how far a forgotten open block may run before the
  app bounds it and writes `UNLOGGED -` for the rest.
- `MARK_TIMEOUT_MS` (6000) — how long the strip waits before applying `=`.
- `BODY_KEY` (`'BODY'`) — the one category whose tap closes an open SIT block.
  Set it to `''` to remove even that coupling.

Save.

---

## 5. Deploy

**Deploy** (blue, top right) → **New deployment** → gear next to "Select type"
→ **Web app**.

- Description: anything
- **Execute as: Me**
- **Who has access: Only myself**

→ **Deploy** → **Authorize access** → pick your account → "Google hasn't
verified this app" → **Advanced** → **Go to timetap (unsafe)** → **Allow**.
The warning is expected: it is your own unpublished script asking for your own
calendar.

Copy the **Web app URL** (`https://script.google.com/macros/s/AKfy…/exec`).

Open it in a desktop browser once and tap a category to confirm an event lands
on ACTUAL before you go near the phone.

### Redeploying after an edit

Code edits do **not** go live on the existing URL by themselves.
**Deploy** → **Manage deployments** → pencil icon → **Version: New version**
→ **Deploy**. Same URL, new code. (Creating another *New deployment* instead
gives you a second URL — avoid.)

---

## 6. Add to the iPhone home screen

1. Open the web app URL in **Safari** (not Chrome — only Safari installs home
   screen bookmarks).
2. Share sheet → **Add to Home Screen** → name it `timetap` → **Add**.

The app tolerates being killed. State lives on the calendar, not in the page,
so the icon can be cold-launched at any time and it will find the open block.

If the launched app shows a Google sign-in loop, open the URL in Safari
normally once, complete the sign-in, then use the icon again.

---

## 7. Required Google Calendar settings

These are not optional. The app is silent by design; the calendar is where
noise leaks in.

For **ACTUAL** and **SITTING** — Settings → *the specific calendar*:

- **Event notifications** — remove every default notification. Click the **X**
  next to each row under "Event notifications" and "All-day event
  notifications" until both lists are empty. The app writes 60+ events a week;
  each one would otherwise buzz your wrist.
- **General notifications** — set every dropdown (New events, Changed events,
  Cancelled events, Event responses, Daily agenda) to **None**.
- **Auto-accept invitations** — irrelevant here, leave as is.

For **SITTING** specifically:

- **Hide from the default view.** In the left sidebar, untick the SITTING
  checkbox. It stays written, it stays queryable, it stops covering your day
  in a second layer of blocks. Tick it only during the weekly review.

For **free/busy**, so logging does not make you look booked to anyone:

- On a secondary calendar, availability follows the *event*, not the calendar.
  The reliable fix is at the source: after the first few events land, open one,
  set **Busy → Free**, and confirm. New events created by
  `CalendarApp.createEvent` inherit the calendar's default, so also check
  Calendar settings → *the specific calendar* → **General** and set the default
  visibility/availability if your account exposes it.
- Belt and braces: keep ACTUAL and SITTING **unshared**. An unshared secondary
  calendar never appears in anyone else's free/busy lookup regardless of the
  per-event flag.

For **PLAN**:

- Nothing to configure. The app opens it read-only and never creates, edits or
  deletes anything on it. Notifications there are your business — that is the
  calendar you actually want to look at.

---

## 8. Sanity check

1. Open the app. NOW bar reads `NOW: IDLE`.
2. Tap `ADM`. NOW bar switches to `NOW: ADM`, timer starts, sync dot goes
   amber then dark. An event `ADM:` appears on ACTUAL, one minute long, with
   `#open` in its description.
3. Tap `DW` within 90 seconds. Still exactly one event on the calendar, now
   titled `DW:`, same start time. That is the mis-tap rule.
4. Toggle `SITTING` on. A `SIT` event appears on the SITTING calendar. Tap
   `BODY`. The SIT block closes at that instant and nothing else moves.
5. Tap `W`. The week screen renders numbers. It is monospace and selectable —
   long-press to copy the whole block into whatever you review in.

If the sync dot sits red, the message under it names the cause. The two common
ones are an empty `CAL_ACTUAL` and a calendar ID pasted with a trailing space.

---

## 9. What lives where

| | |
|---|---|
| Source of truth for the open block | the calendar, via `#open` in the description |
| Source of truth for everything else | the calendar |
| localStorage | an unsent-write queue and a UI mirror, both disposable |
| Settings | the CONFIG block in `Code.gs` |
| Conclusions about your week | you, on Sunday, by hand |

Clearing Safari's storage loses nothing but unsent writes. Deleting the app
and reinstalling it recovers full state from the calendar on first open.
