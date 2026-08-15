# timetap iOS (Path 3)

The iPhone signs in with Google Sign-In, not an API_TOKEN. It writes Google
Calendar itself. Capture stays at Path 2 parity. Rollup stays on Apps Script.

If the HTML app and the iPhone both write, last-write-wins. There is no lock.

## 1. Mint an iOS OAuth client

Use GCP project `timetap-505402` only. Enable the Calendar API.

1. Google Cloud Console → APIs & Services → Credentials → Create credentials
   → OAuth client ID → **iOS**.
2. Name `timetap`. Bundle ID `app.timetap.ios`.
3. Copy the client ID (`….apps.googleusercontent.com`).
4. Write it to `ios/.secrets/GOOGLE_IOS_CLIENT_ID` (gitignored).

The Xcode URL scheme is the reversed client ID:
`com.googleusercontent.apps.{prefix-before-.apps.googleusercontent.com}`.
`ios/scripts/sync-google-config.sh` writes `TimeTap/Config/Google.xcconfig`
from that secret. Info.plist already reads `GIDClientID` and the URL scheme
from that file.

A testing project's consent screen may show a warning. That is accepted.

## 2. Build

```bash
cd ios
./scripts/sync-google-config.sh
xcodegen generate
open TimeTap.xcodeproj
```

Select Development Team `Y3NGT7263T` under Signing. Run on a phone or the
simulator (iPhone 17 Pro Max).

## 3. First launch

1. **Google Sign-In** — scope `https://www.googleapis.com/auth/calendar`.
2. **calendar picker** — PLAN / ACTUAL / SITTING are pre-selected by name
   when those calendars exist (first match on a duplicate name). Confirm
   needs all three. Settings can change them later.
3. Sign-out clears the Google session. Saved calendar IDs stay on the device.

## 4. What the phone does

Tap a category. The phone inserts/patches events on ACTUAL (and SITTING)
through Calendar REST. Titles, colours, `#ref:` / `#open`, stale `?`, and undo
match `Code.gs`. STOP closes the running block only. Sitting has its own
start/stop. Add category stays on the device (cap 16). Groups stay on the
phone. Only child labels are written to Calendar.

The Lock Screen and Dynamic Island show the running block, and sitting as a
second row with its own timer. Enable Live Activities for timetap in Settings
if the Island stays empty.

Device proof is the user's Google Calendar, not curl against `/exec`.

## 5. What stays off the phone

- Nightly rollup / Sheets (`dailyRollup`, `setupRollup`) — rollup stays on Apps Script
- PLAN editing by hand
- `removeCategory` (editor-only)
- Home Screen widgets, App Store

The Watch app is in-scope.
