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

**Set the timezone** in `appsscript.json`. This is the setting most likely to be
silently wrong, because the shipped default is a real place and nothing
complains if it is not yours: day boundaries, the rollup window and the trigger
hour all come from it, so an hour out puts everything logged late at night on
the wrong day. `setupRollup` prints the zone it is using. Change it to your own
[IANA zone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
(`Europe/London`, `America/Los_Angeles`, `Asia/Tokyo`, …). Every day boundary,
the rollup window and the hour the nightly trigger fires all read from this one
value via `Session.getScriptTimeZone()`.

**Save** (⌘S / Ctrl-S).

The Advanced Calendar Service is **not** required. Every write goes through
`CalendarApp`, and nothing belongs under `dependencies`. The manifest asks for
three scopes and no more:

| Scope | For |
|---|---|
| `.../auth/calendar` | reading PLAN, writing ACTUAL and SITTING |
| `.../auth/spreadsheets` | the nightly rollup (section 9) |
| `.../auth/script.scriptapp` | installing the nightly trigger |

---

## 4. Give the app your calendar IDs

Two places work. The app reads a **script property** first and falls back to the
**CONFIG literal**, and either way the ID is trimmed, so a trailing space
pasted along with it does no harm.

### Option A — script properties (do this if you use clasp)

**Project Settings → Script properties → Edit script properties → Add script
property.** Three rows, named exactly:

| Property | Value |
|---|---|
| `CAL_PLAN` | `c_...@group.calendar.google.com` |
| `CAL_ACTUAL` | `c_...@group.calendar.google.com` |
| `CAL_SITTING` | `c_...@group.calendar.google.com` |

Save. `Code.gs` stays byte-identical to the repo.

That is the whole point of this option: the calendar IDs are the only part of
`Code.gs` that is yours rather than the project's. Leave them in the file and
every `git pull` that touches `Code.gs` collides with the one line you care
about, and you get to choose between committing your personal calendar IDs to
a public repo or resolving the same conflict forever. Script properties live in
the Apps Script project only — never in git, never pushed, never pulled.

### Option B — paste them into CONFIG

Simpler if you are only ever going to use the editor. Top of `Code.gs`:

```js
var CAL_PLAN    = 'c_...@group.calendar.google.com';
var CAL_ACTUAL  = 'c_...@group.calendar.google.com';
var CAL_SITTING = 'c_...@group.calendar.google.com';
```

Values set in script properties override these, so it is safe to leave stale
literals here — but confusing, so do not.

While you are there, the rest of the CONFIG block is the whole settings
surface of the app. There is no settings screen and there will never be one.

- `CATEGORIES` — add or remove entries and the button grid, the rollup columns
  and the mark rules all follow. Nothing else needs editing. Keys become the
  `"KEY:"` title prefix, so keep them short and uppercase.
  You can also add one from the grid itself: the `+` box names a category and
  the app stores it in a script property called `EXTRA_CATEGORIES`, appended to
  this array rather than merged into it. Delete that property to get back to
  exactly what is written here. Categories cannot be renamed from either place,
  because a key change would split every past event away from every future one
  in the rollup.
- `MAX_CATEGORIES` (10) — the ceiling on both together. The `+` box disappears
  once you reach it.
  **Order matters ergonomically:** the grid fills from the bottom row upward,
  so the first entries land nearest your thumb and the last entries sit in the
  top corners. Put what you tap most at the top of the array.
  The button shows the `label`, verbatim and full size, so write it the way you
  want to read it. The `key` never appears on the grid — it is the record's
  vocabulary: the `"KEY:"` prefix on every ACTUAL event and the column headers
  in the rollup sheet. Long labels wrap to two lines and still fit.
- `autoMark` — `'+'`, `'='`, `'-'` or `null`. Non-null means that category
  never shows the mark strip; the mark is applied silently. `null` means the
  strip may appear.
- `MIN_MARK_MINUTES` (15) — shorter blocks get no mark and no strip.
- `MISTAP_SECONDS` (90) — a tap this soon after the last one is a correction:
  it retitles the open block rather than starting a new one, keeping the
  original start time.
- `CONFIRM_WITHIN_SECONDS` (60) — a tap this soon after the last one arms the
  button instead of acting, and waits for a second tap on the same button.
  Nothing is written or queued until that second tap.
- `CONFIRM_TIMEOUT_MS` (4000) — how long an armed button waits before
  forgetting. Ignoring it is always the safe outcome.
- `STALE_OPEN_HOURS` (5) — how far a forgotten open block may run before the
  app bounds it and writes `UNLOGGED -` for the rest.
- `MARK_TIMEOUT_MS` (6000) — how long the strip waits before applying `=`.
- `BODY_KEY` (`'BODY'`) — the one category whose tap closes an open SIT block
  and drops the posture button back to `NOT SITTING`. Set it to `''` to remove even
  that coupling.
- `SHEET_ID`, `DAILY_TAB`, `WEEKLY_TAB`, `ROLLUP_DAYS`, `ROLLUP_HOUR` — the
  nightly rollup. See section 9.

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
calendar, spreadsheet and triggers.

If you are updating an existing deployment and the scopes have changed, Google
will ask you to authorize again. Run any function from the editor once and
approve the new list, or the trigger will fail silently overnight.

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

**Use Chrome. Not Safari.** This is the opposite of the usual iOS advice and it
is worth the two minutes it takes to read why.

1. Open the web app URL in **Chrome for iOS**.
2. Share sheet → **Add to Home Screen** → name it `timetap` → **Add**.

You get a fullscreen icon with no browser chrome, same as Safari would give.

### Why not Safari

Safari fails with `Sorry, unable to open the file at this time`, which sounds
like a broken deployment and is not one. Apps Script serves your page inside a
sandboxed iframe from `googleusercontent.com` after bouncing through Google's
auth domains — a genuinely cross-site flow — and Safari's **Prevent Cross-Site
Tracking**, on by default, breaks it.

The misleading part: `script.google.com/home` loads fine in Safari, because
that is a first-party page. A working Google session there proves nothing about
whether `/exec` will load. Do not spend an hour chasing the account, as this
setup did.

Turning off Prevent Cross-Site Tracking and Block All Cookies in
**Settings → Apps → Safari** may fix it. Chrome just works, is already signed
into your Google account, and does not require weakening Safari's defaults for
every other site you visit.

**Brave cannot do this at all** — third-party browsers on iOS gained Add to
Home Screen in 2023 and Brave has not implemented it. Chrome has.

### Getting the URL onto the phone

Do not retype it. It is ~114 characters, and one stray space or line break from
a wrapped copy makes the address bar treat it as a search query and hand it to
Google — which looks like the app failing when nothing has been requested yet.

Send it as something tappable: Handoff from the Mac, Messages to yourself, a
note synced over iCloud, or a QR code generated locally.

### After it is installed

The app tolerates being killed. State lives on the calendar, not in the page,
so the icon can be cold-launched at any time and it will find the open block.

If the launched app shows a Google sign-in loop, open the URL in the browser
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

1. Open the app. Every box is dimmed — that is what nothing running looks like.
2. Tap `ADM`. Its box brightens, takes a white ring that breathes, and shows a
   clock in its top left corner. An event `ADM:` appears on ACTUAL, one minute
   long, with `#open` in its description.
3. Tap `DW` within a minute. Nothing is written: the `DW` box arms itself and
   says `TAP AGAIN`. Tap it again and there is still exactly one event on the
   calendar, now titled `DW:`, with the original start time. That is the
   confirmation gate and the mis-tap rule, in that order.
4. Type into the note inside the lit box. The event's title picks it up.
5. Wait a couple of minutes and tap the lit box itself. SPLIT opens on the
   block that is running.
6. Tap `NOT SITTING` so it reads `SITTING`. A `SIT` event appears on the
   SITTING calendar and the button shows how long. Tap `BODY`. The SIT block
   closes at that instant, the button falls back to `NOT SITTING`, and nothing
   else moves.
7. In the editor, run `dailyRollup` once by hand and open your spreadsheet.
   The `daily` and `weekly` tabs should be full of numbers.

Nothing appears in the posture row unless a write is waiting or has failed. If
a red pill shows up there, the message above it names the cause; the two common
ones are an empty `CAL_ACTUAL` and a calendar ID pasted with a trailing space.

Then paste `test/smoke.js` into the browser console, on the phone. It returns
`{ pass, fail, failed }` and checks the things a screenshot would tell you and
the test suite cannot.

---

## 9. The rollup spreadsheet

There is no week screen in the app. The numbers go to a Google Sheet on a daily
trigger, and you read them where you actually think — which was never a phone.

**Create a spreadsheet.** A **new, empty** one — not a workbook you already use.
`daily` and `weekly` are cleared and rewritten every night, so a tab of yours
that happens to share either name is gone by morning. `setupRollup` lists any
other tabs it finds so you know when you have pointed it at a shared workbook.

Copy its URL — the whole thing, out of the address bar. You do not need to
extract the id; the app will take it out.

**Tell the app about it.** Project Settings → Script properties → add
`SHEET_ID` and paste the URL. (The `SHEET_ID` literal in CONFIG works too, but
`clasp push` overwrites it and a script property it cannot touch.)

**Run `setupRollup` once.** Pick it from the function dropdown in the editor and
press Run, then read the **Execution log** panel underneath. It does everything
else in one go:

- checks the spreadsheet opens
- installs the nightly trigger
- fills both tabs immediately, so you are not waiting until 3am to find out
- reports how many events it found on each of the three calendars

That last part is the one to read. If `ACTUAL` comes back 0 and you have been
logging, `CAL_ACTUAL` is pointing at the wrong calendar — worth knowing now
rather than on Sunday.

The first run will ask you to authorize again: the rollup added the
`spreadsheets` and `script.scriptapp` scopes. Approve them, or the trigger fails
silently overnight.

Safe to run again whenever. It clears its own trigger before installing one, so
it cannot leave you with two.

### What lands in the sheet

Two tabs, both rebuilt from the calendars on every run.

`daily` — one row per day, ninety days back:

| date | day | DW | MTG | … | plan DW | … | switches | waking h | sitting h | sitting % | longest sit min | sits over 90 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

`weekly` — the same numbers grouped Monday to Sunday, with the planned-versus-
actual ratio the weekly ritual compares:

| week of | plan DW | DW | DW ratio | … | switches | waking h | sitting h | sitting % | longest sit min | sits over 90 |
|---|---|---|---|---|---|---|---|---|---|---|

Everything is a real number, not a padded string, so Sheets will sum, pivot and
chart it without being asked twice. A ratio against zero planned hours is blank
rather than an error, and so is a sitting percentage on a day with no waking
span.

### Two things to know

**These tabs are generated output.** Every run clears them and writes them
again. Anything you type into them is gone by morning. Put your own work in
another tab and point formulas at `daily!A:Z` — that survives.

**Rebuilding is the point.** Because each run recomputes the whole window
rather than appending yesterday, a calendar you correct on Thursday shows up
correctly for Tuesday, and adding a category does not leave the old columns
misaligned. Today's row is partial until the day ends and gets corrected on the
next run.

The app itself still does not participate in the review. It emits raw numbers
into a grid and stops there. No charts, no highlighting, no comparison to last
week — the spreadsheet will happily do all of that if *you* ask it to.

---

## 10. Push from the repo instead of pasting (optional)

Copying three files into the editor by hand gets old fast, and it is how the
two copies drift. `clasp` is Google's own CLI for this — it pushes the working
tree straight into the script project.

```bash
npm install -g @google/clasp
```

**Turn the API on once** at
[script.google.com/home/usersettings](https://script.google.com/home/usersettings)
— set *Google Apps Script API* to **On**. Pushes fail with a `User has not
enabled the Apps Script API` error until you do.

**Log in.** This opens a browser for Google's consent screen, so run it
yourself:

```bash
clasp login
```

**Point the repo at your script.** The ID is in **Project Settings → IDs →
Script ID** (also the long string in the editor URL):

```bash
cd ~/Desktop/timetap && printf '{"scriptId":"YOUR_SCRIPT_ID","rootDir":"."}' > .clasp.json
```

`.clasp.json` is gitignored — it is specific to your machine and your script.
`.claspignore` is committed, and it excludes everything except the three files
that belong to Apps Script. Without it `clasp` would push `site/index.html`
alongside `Index.html` and the docs site would land in your web app.

**Then, after any edit:**

```bash
./deploy.sh
```

That is the whole loop: pull, list deployments, push, redeploy. It matters that
it does all four — a `clasp push` alone updates the code but the web app URL
keeps serving the pinned version, so the phone sees nothing until a new one is
cut.

The script resolves the deployment itself by ignoring `@HEAD` and taking the
single numbered deployment. If you have more than one, name it:

```bash
./deploy.sh AKfycb...
```

or `export TIMETAP_DEPLOYMENT_ID=AKfycb...`. `--no-pull` skips step one.

It will refuse to run if no numbered deployment exists yet, rather than
creating one: `clasp deploy` with no ID mints a **new URL**, which would leave
the icon on your home screen pointing at the old one. Create the first
deployment from the editor, as in section 5.

The pull uses `--rebase --autostash`, so uncommitted local edits survive it.
Prefer script properties for your calendar IDs (section 4) and there is nothing
to survive — `Code.gs` never diverges from the repo in the first place.

`clasp pull` goes the other way, if you ever edit in the browser and want the
change back in git. Push and pull both overwrite wholesale, so pick one
direction as the source of truth — the repo — and stay there.

> **The one way to lose your calendar IDs.** `clasp push` replaces the editor's
> `Code.gs` with your local one, entirely. If the IDs are pasted into the
> editor's copy and your local copy still has the empty strings from the repo,
> the first push silently blanks them and the app starts throwing
> `CAL_ACTUAL is not set`.
>
> Script properties (section 4) are immune: they are project data, not a file,
> so nothing `clasp` does can touch them. That is the real reason to prefer
> Option A once you are syncing.

A GitHub Action can run `clasp push` on every commit to main, but it needs your
`~/.clasprc.json` OAuth token in a repo secret. For a personal app deployed to
an audience of one, that is a Google refresh token sitting in GitHub for very
little gain. Local `clasp push` is the better trade.

---

## 11. What lives where

| | |
|---|---|
| Source of truth for the open block | the calendar, via `#open` in the description |
| Source of truth for everything else | the calendar |
| localStorage | an unsent-write queue and a UI mirror, both disposable |
| Settings | the CONFIG block in `Code.gs` |
| The numbers | a Google Sheet, rebuilt nightly from the calendars |
| Conclusions about your week | you, on Sunday, by hand |

Clearing Safari's storage loses nothing but unsent writes. Deleting the app
and reinstalling it recovers full state from the calendar on first open.
