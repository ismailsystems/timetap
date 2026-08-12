# timetap iOS (Path 2)

SwiftUI capture client. The brain stays in `Code.gs`. The phone posts the same
`getState` / `applyOps` / `config` contract the web client already uses, over
HTTPS with a shared secret.

## 1. Script property

In the Apps Script project: **Project Settings → Script properties** → add:

| Property   | Value                                      |
|------------|--------------------------------------------|
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

Redeploy (**New version**) after pulling `doPost` changes, on **both**
deployments if you want the HTML shell and the API on the same code revision.

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

## 4. Wire contract

`POST` JSON body:

```json
{ "token": "…", "action": "config" }
{ "token": "…", "action": "getState" }
{ "token": "…", "action": "applyOps", "ops": [ /* same shapes as Index.html */ ] }
```

Success: `{ "ok": true, "result": … }`  
Failure: `{ "ok": false, "error": "…" }`

## 5. v1 scope

Shipped in this pass:

- Categories, NOW + note, STOP, sitting toggle
- Undo ribbon, mark strip (`+ = -`)
- Offline queue in `UserDefaults`, flush with redirect-safe POST
- Settings for URL + token (token in Keychain)

Not yet (still on the web app):

- Split sheet, sit-edit sheet, dead-letter drawer UI
- Day rail
- Add-category from the grid

## 6. Smoke check without the phone

```bash
TOKEN='…'
URL='https://script.google.com/macros/s/…/exec'

curl -sL -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -d "{\"token\":\"$TOKEN\",\"action\":\"config\"}"
```

`-L` matters: Apps Script redirects once. `curl` re-POSTs; browsers often do
not. The iOS client re-issues POST on redirect for the same reason.
