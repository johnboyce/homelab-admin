#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/platform/ingress/nginx/etc-nginx-docker"

mkdir -p "$DEST"

sudo rsync -av --delete \
  --exclude 'certs/*.key' \
  --exclude 'certs/*.pem' \
  --exclude 'certs/*priv*' \
  /etc/nginx-docker/ \
  "$DEST/"

mkdir -p "$DEST/certs"
touch "$DEST/certs/.keep"

echo "✅ Synced /etc/nginx-docker -> $DEST (private keys excluded)"
