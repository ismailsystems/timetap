# timetap iOS (Path 2)

SwiftUI capture client. The brain stays in `Code.gs`. The phone posts the same
ops the web client already uses, over HTTPS with a shared secret.

This is a pure port of the capture surface. Rollup, PLAN editing, and category
retirement stay on Apps Script / Sheets / Calendar — same as the web app.

## 1. Script property

In the Apps Script project: **Project Settings → Script properties** → add:

| Property    | Value                                       |
|-------------|---------------------------------------------|
| `API_TOKEN` | long random string (32+ chars). Keep private. |

```bash
openssl rand -hex 24
```

## 2. Second deployment (API)

Keep your existing **MYSELF** web deployment for the HTML shell.

Create another deployment of the same project:

1. **Deploy → Manage deployments → Add deployment**
2. Type: **Web app**
3. Execute as: **Me**
4. Who has access: **Anyone** (including anonymous)
5. Deploy. Copy the `/exec` URL.

That URL is what the iOS app posts to. Anyone who has the URL still needs
`API_TOKEN`. Anonymous `doGet` does not serve the capture HTML.

Redeploy (**New version**) after pulling API changes, on **both** deployments
if you want the HTML shell and the API on the same code revision.

## 3. Build the app

```bash
cd ios
xcodegen generate
open TimeTap.xcodeproj
```

Select your Development Team under Signing, Run on a phone or simulator.

On first launch, paste:

- **Web app /exec URL** — the Anyone deployment URL
- **API_TOKEN** — the script property value

Use **Test connection** in Settings before you leave the sheet.

## 4. Wire contract

`POST` JSON body:

```json
{ "token": "…", "action": "config" }
{ "token": "…", "action": "getState" }
{ "token": "…", "action": "applyOps", "ops": [ /* same shapes as Index.html */ ] }
{ "token": "…", "action": "addCategory", "label": "Deep reading" }
```

Success: `{ "ok": true, "result": … }`  
Failure: `{ "ok": false, "error": "…" }`

## 5. Ported surface (parity with Index.html)

- Categories + Add category (server `addCategory`, max from config)
- NOW panel (since clock, note, tap to split)
- Day rail (UNLOGGED gaps, open outline, proportional heights)
- Split sheet (remainder cut + whole-block recategorize)
- Sitting toggle + sit-edit sheet (set start / delete)
- STOP + undo ribbon
- Mark strip (`+ = -`)
- Dead-letter drawer with arm-to-discard
- Offline queue, redirect-safe POST, corrective getState after undo
- Unreadable open-block banner
- Settings (URL, token in Keychain, tz, connection probe)

## 6. Deliberately not on the phone

Same as the web client — not missing, just not capture:

- Nightly rollup / Sheets UI (`dailyRollup`, `rollupStatus`)
- PLAN calendar editing (hand-written on Sunday)
- `removeCategory` (editor-only on purpose; no delete beside a log control)

## 7. Smoke check without the phone

```bash
TOKEN='…'
URL='https://script.google.com/macros/s/…/exec'

curl -sL -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -d "{\"token\":\"$TOKEN\",\"action\":\"config\"}"
```

`-L` matters: Apps Script redirects once. `curl` re-POSTs; browsers often do
not. The iOS client re-issues POST on redirect for the same reason.
