# Brief: timetap — Path 3 (SwiftUI writes Calendar itself)
date: 2026-08-12
round: 3
supersedes nothing. Round 1's record is `factory/ROUND-1.md`. Round 2 is
`factory/BRIEF.md` / `PLAN.md`. Path 2 (HTTPS into Apps Script) is
`factory/BRIEF-2.md` / `PLAN-2.md`.

## What we're building

The same TimeTap capture client that Path 2 already ships on the phone, but
the phone talks to **Google Calendar API** itself after **Google Sign-In**.
Apps Script no longer sits between a tap and an ACTUAL event.

Nightly rollup, Sheets, and `setupRollup` stay on Apps Script. They already
read Calendar; they do not care who wrote the events.

## Who it's for and what they get

One user. They open the iPhone app, sign in with Google once, pick PLAN /
ACTUAL / SITTING from a calendar list, tap a category, and see the same
ACTUAL event Path 2 would have written. No `API_TOKEN`. No Anyone deploy.
The HTML web app can stay on Apps Script for rollup viewing if they want it.

## Done looks like

The morning it works, on the same iPhone 16 Pro Max:

1. First launch: Google Sign-In. Then a picker lists the user's calendars.
   Names `PLAN` / `ACTUAL` / `SITTING` are pre-selected when those names
   exist. Confirm writes the three calendar IDs to the device.
2. Tap `DW`. An ACTUAL event appears on the ACTUAL calendar with the same
   title grammar, colour, description refs, and start-now / open-ended
   shape Path 2 would write. No Apps Script `doPost` ran.
3. Split, sit, STOP, undo, marks, notes, day-rail, dead-letter, add
   category all still work. Events on Calendar match Path 2's writer.
4. Settings can change the three calendar IDs. Sign-out clears the Google
   session; calendar IDs stay until the user picks again.
5. The nightly rollup still runs on Apps Script and still sees the events.
6. `ios/.secrets/API_TOKEN` is unused. Path 2's HTTPS client is gone from
   the phone.

## Not in this version

- Rollup / Sheets / PLAN editing on the phone
- `removeCategory`
- Widgets, Watch, App Store
- Keeping Path 2 `doPost` as a fallback
- Cross-phone lock / last-write-wins is accepted
- Pushing device extras back into Apps Script `CATEGORIES` (HTML will not
  show a new button until GAS extras are updated by hand)
- Apple EventKit / native Calendar entitlement
- Rewriting rollup to Swift

## Facts (discovered, not asked)

- Path 2 ships on `main` at `1f84fce`. Capture UI is `ios/TimeTap/`. Server
  op machine is `Code.gs` (`applyOps`, `staleGuard_`, `undoSwitch`,
  `insertActual_`, refs in description).
- Path 2 HTTPS: `TimetapAPI.swift` + `API_TOKEN` + Anyone deploy. That
  path goes away on the phone.
- Calendar IDs today live in Apps Script script properties (`PLAN_CAL_ID`,
  `ACTUAL_CAL_ID`, `SITTING_CAL_ID`). Path 3 stores its own copies on the
  device after the picker. They should be the same calendars.
- `CATEGORIES` in `Code.gs` is the seed list. Copy into Swift. Seed extra
  `POOP` (already on ACTUAL). `addCategory` on device only.
- Title grammar, colour map, `TT1`/`TT2` refs, `staleGuard_`, `undoSwitch`
  60s window, STOP, sit, split, marks, notes, night `?` bound: all must
  match `Code.gs` or rollup lies.
- Apps Script `LockService` does not exist on the phone. One phone is the
  writer.
- Google Calendar insert/patch from iOS needs a Google Cloud **iOS** OAuth
  client ID and a URL scheme on the Xcode target. Calendar scope:
  `https://www.googleapis.com/auth/calendar`.
- Tests today: `node test/run.js` (GAS). Path 3 adds Swift tests for the
  op machine. Device proof is Calendar itself, not curl against `/exec`.
- Branch: `path-3-ios`. Do not rewrite `BRIEF.md` / `PLAN.md`.

## Decisions made

- Google Calendar API + Google Sign-In on the phone. Not EventKit.
- Done = signed-in tap writes the same ACTUAL event Path 2 would. No token.
- Out: rollup on phone, removeCategory, widgets, Watch, App Store, GAS
  fallback, cross-phone lock, pushing extras back to GAS.
- In: full Path 2 capture parity. Device extras stay on the device.
- Calendar IDs: list + pick on first sign-in; pre-select PLAN/ACTUAL/SITTING
  by name; Settings can change.

## Open risks

- **Highest:** porting `applyOps` / `staleGuard_` / `undoSwitch` / refs
  without `LockService`. A wrong patch orphans an open block or double-opens.
- Google Cloud iOS OAuth client + URL scheme. Sign-in fails until that is
  set. Needs a Google Cloud project the user owns (likely the same one as
  the Apps Script GCP project, or a new iOS client on it).
- Calendar list permission: the OAuth consent screen must include Calendar
  scope. First sign-in may show a Google warning if the app is in testing.
- Colour IDs on Calendar API vs Apps Script `CalendarApp` colour enums —
  must map to the same event colours Path 2 writes.
- Optimistic UI vs Calendar lag: Path 2 already has an op queue + dead
  letter. Reuse that shape against Calendar HTTP, not against GAS.
- HTML web app and iPhone can both write if the user opens both. Last write
  wins. Document it; do not build a lock.
