#!/usr/bin/env bash
set -euo pipefail

if [[ "${ALLOW_IMPORT:-}" != "true" ]]; then
  echo "❌ Import is disabled by default (host → repo is emergency only)."
  echo "   Re-run with: ALLOW_IMPORT=true make nginx-import"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/platform/ingress/nginx/etc-nginx-docker"

mkdir -p "$DEST"

DEST_OWNER="$(id -un)"
DEST_GROUP="$(id -gn)"

echo "== Importing nginx config: host → repo (emergency) =="
echo "   Source: /etc/nginx-docker"
echo "   Dest:   $DEST"
echo ""

sudo rsync -av --delete \
  --chown="${DEST_OWNER}:${DEST_GROUP}" \
  --exclude 'certs/*.key' \
  --exclude 'certs/*.pem' \
  --exclude 'certs/*priv*' \
  /etc/nginx-docker/ \
  "$DEST/"

mkdir -p "$DEST/certs"
touch "$DEST/certs/.keep"

# Guardrail: ensure repo tree is owned by current user
bad="$(find "$DEST" -not -user "$DEST_OWNER" -print -quit || true)"
if [[ -n "$bad" ]]; then
  echo "❌ Import produced non-owned file: $bad"
  echo "   Fix with: sudo chown -R ${DEST_OWNER}:${DEST_GROUP} '$DEST'"
  exit 1
fi

echo "✅ Synced /etc/nginx-docker -> $DEST (private keys excluded)"
echo "⚠️  Review diffs and commit intentionally."
