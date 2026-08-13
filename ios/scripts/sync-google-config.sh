#!/bin/bash
# Writes TimeTap/Config/Google.xcconfig from ios/.secrets/GOOGLE_IOS_CLIENT_ID.
# Placeholder if the secret is missing (live Sign-In then stays parked).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRET="$ROOT/.secrets/GOOGLE_IOS_CLIENT_ID"
OUT="$ROOT/TimeTap/Config/Google.xcconfig"
mkdir -p "$(dirname "$OUT")"
if [[ -f "$SECRET" ]]; then
  ID="$(tr -d '[:space:]' < "$SECRET")"
else
  ID="000000000000-placeholder.apps.googleusercontent.com"
fi
PREFIX="${ID%.apps.googleusercontent.com}"
SCHEME="com.googleusercontent.apps.${PREFIX}"
cat > "$OUT" <<EOF
GOOGLE_IOS_CLIENT_ID = ${ID}
GOOGLE_IOS_URL_SCHEME = ${SCHEME}
EOF
