#!/usr/bin/env bash
#
# Pull, push, deploy. One command between an edit and the phone.
#
#   ./deploy.sh                  resolve the deployment automatically
#   ./deploy.sh AKfycb...        target a specific deployment id
#   ./deploy.sh --no-pull        skip the git pull
#   ./deploy.sh --no-test        skip the checks (they are the point; think twice)
#
# Three test layers run before anything ships:
#
#   1. static checks       test/lint.js
#   2. the offline suite   test/tests.js, under three timezones
#   3. the headless render  test/headless.js, in a real browser engine
#
# If the browser is not installed the deploy stops rather than going ahead
# without layer 3. A skipped run is never a pass.
#
# Requires clasp (npm install -g @google/clasp), a clasp login, and a
# .clasp.json pointing at your script. See SETUP.md section 10.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ -t 1 ]; then B=$(tput bold); D=$(tput dim); R=$(tput sgr0); else B=""; D=""; R=""; fi
step() { printf '\n%s==> %s%s\n' "$B" "$1" "$R"; }
die()  { printf '\n%serror:%s %s\n' "$B" "$R" "$1" >&2; exit 1; }

DEPLOY_ID="${TIMETAP_DEPLOYMENT_ID:-}"
DO_PULL=1
DO_TEST=1
for arg in "$@"; do
  case "$arg" in
    --no-pull) DO_PULL=0 ;;
    --no-test) DO_TEST=0 ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    -*)        die "unknown option: $arg" ;;
    *)         DEPLOY_ID="$arg" ;;
  esac
done

command -v clasp >/dev/null 2>&1 || die "clasp is not installed. npm install -g @google/clasp"
[ -f .clasp.json ] || die ".clasp.json not found. See SETUP.md section 10 for how to create it."
if grep -q 'YOUR_SCRIPT_ID' .clasp.json 2>/dev/null; then
  die ".clasp.json still holds the placeholder scriptId.

Replace it with your own: Project Settings -> IDs -> Script ID
  printf '{\"scriptId\":\"REAL_ID\",\"rootDir\":\".\"}' > .clasp.json"
fi

# ── 1. pull ──────────────────────────────────────────────────────────
# --autostash because your calendar IDs live in Code.gs and are probably
# uncommitted, which would otherwise make every pull refuse to run.
if [ "$DO_PULL" -eq 1 ]; then
  step "git pull"
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "${D}not a git repository, skipping${R}"
  elif ! git rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    echo "${D}no upstream for $(git branch --show-current), skipping${R}"
  else
    git pull --rebase --autostash || die "pull failed. Resolve it, then re-run.
If the autostash conflicted, your local edits are safe: git stash list"
  fi
else
  step "git pull ${D}(skipped)${R}"
fi

# ── 1b. checks ───────────────────────────────────────────────────────
# Every regression that reached the phone went out through this script while
# the tests sat green and unrun. They run here now, before anything ships.
if [ "$DO_TEST" -eq 1 ]; then
  step "checks"
  if ! command -v node >/dev/null 2>&1; then
    echo "${D}node not found, skipping${R}"
  else
    if ! OUT=$(node test/lint.js 2>&1); then
      printf '%s\n' "$OUT"
      die "static checks failed. Nothing deployed."
    fi
    printf '%s\n' "$OUT" | tail -1
    for z in America/New_York Europe/London UTC; do
      if ! OUT=$(TZ=$z node test/tests.js 2>&1); then
        printf '%s\n' "$OUT" | tail -25
        die "tests failed under $z. Nothing deployed."
      fi
      printf '  %-18s %s\n' "$z" "$(printf '%s\n' "$OUT" | tail -1)"
    done
    # The third layer, in a real browser engine. A missing browser stops the
    # deploy instead of being waved through: reporting a run that never
    # happened as a pass is how a rendering bug reaches the phone.
    if ! OUT=$(node test/headless.js 2>&1); then
      printf '%s\n' "$OUT"
      die "headless checks failed. Nothing deployed."
    fi
    printf '%s\n' "$OUT" | tail -1
  fi
else
  step "checks ${D}(skipped)${R}"
fi

# ── 2. deployments ───────────────────────────────────────────────────
step "clasp deployments"
if ! DEPLOYMENTS=$(clasp deployments 2>&1); then
  die "clasp deployments failed:

${DEPLOYMENTS}

  Invalid ID       scriptId in .clasp.json is wrong.
                   Project Settings -> IDs -> Script ID
  not logged in    clasp login
  API disabled     https://script.google.com/home/usersettings"
fi
printf '%s\n' "$DEPLOYMENTS"

# @HEAD is the always-latest /dev url. The web app on your home screen is a
# numbered deployment, and that is the only kind worth repointing.
VERSIONED=$(printf '%s\n' "$DEPLOYMENTS" \
  | sed -n 's/^- \([A-Za-z0-9_-][A-Za-z0-9_-]*\) @[0-9][0-9]*.*/\1/p')
COUNT=$(printf '%s' "$VERSIONED" | grep -c . || true)

if [ -n "$DEPLOY_ID" ]; then
  :
elif [ "$COUNT" -eq 1 ]; then
  DEPLOY_ID="$VERSIONED"
elif [ "$COUNT" -eq 0 ]; then
  die "no versioned deployment exists, only @HEAD.

Create one in the editor: Deploy -> New deployment -> Web app,
Execute as: Me, Access: Only myself. Then re-run this.

Deliberately not automated: 'clasp deploy' with no id mints a NEW url,
which would leave your home screen icon pointing at the old one."
else
  die "found $COUNT versioned deployments and cannot choose between them.
Pass one:  ./deploy.sh AKfycb...
Or set it: export TIMETAP_DEPLOYMENT_ID=AKfycb..."
fi

# ── 3. push ──────────────────────────────────────────────────────────
step "clasp push"
if git rev-parse --git-dir >/dev/null 2>&1; then
  DIRTY=$(git status --porcelain -- appsscript.json Code.gs Index.html 2>/dev/null \
    | awk '{print $NF}' | tr '\n' ' ')
  if [ -n "$DIRTY" ]; then echo "${D}uncommitted, going up anyway: ${DIRTY}${R}"; fi
fi
# --force skips the interactive prompt when appsscript.json has changed.
if ! PUSHED=$(clasp push --force 2>&1); then
  die "clasp push failed:

${PUSHED}

  If it mentions the Apps Script API, switch it on:
  https://script.google.com/home/usersettings"
fi
printf '%s\n' "$PUSHED"

# ── 4. deploy ────────────────────────────────────────────────────────
if git rev-parse --git-dir >/dev/null 2>&1; then
  DESC="$(git rev-parse --short HEAD)"
  git diff --quiet HEAD -- appsscript.json Code.gs Index.html 2>/dev/null || DESC="$DESC+dirty"
else
  DESC="$(date +%Y-%m-%d\ %H:%M)"
fi

step "clasp deploy ${D}($DESC)${R}"
if ! DEPLOYED=$(clasp deploy -i "$DEPLOY_ID" -d "$DESC" 2>&1); then
  die "clasp deploy failed:

${DEPLOYED}"
fi
printf '%s\n' "$DEPLOYED"

printf '\n%slive%s  https://script.google.com/macros/s/%s/exec\n' "$B" "$R" "$DEPLOY_ID"
