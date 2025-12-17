#!/usr/bin/env bash
set -euo pipefail

# Deploy nginx config from repo -> host (/etc/nginx-docker) for the geek-nginx container.
# - Desired state lives in repo at: platform/ingress/nginx/etc-nginx-docker
# - Host runtime lives at: /etc/nginx-docker
# - TLS private keys MUST NEVER enter git; certs are managed on host only.
#
# Usage:
#   ./scripts/nginx_deploy_to_host.sh
#
# Optional env:
#   NGINX_CONTAINER=geek-nginx
#   SOURCE_DIR=<override repo source>
#   DEST_DIR=/etc/nginx-docker

NGINX_CONTAINER="${NGINX_CONTAINER:-geek-nginx}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${SOURCE_DIR:-$REPO_ROOT/platform/ingress/nginx/etc-nginx-docker}"
DEST="${DEST_DIR:-/etc/nginx-docker}"

say() { printf "%s\n" "$*"; }
die() { say "❌ $*"; exit 1; }

say "== Deploying nginx config: repo → host =="
say "   Source: $SOURCE"
say "   Dest:   $DEST"
say "   Nginx :  $NGINX_CONTAINER"
say ""

[[ -d "$SOURCE" ]] || die "Source directory not found: $SOURCE"

# Safety: refuse if repo contains private keys
if find "$SOURCE" -type f \( -name "*.key" -o -name "*.pem" -o -iname "*priv*" \) -print -quit | grep -q .; then
  die "Refusing to deploy: private key material detected under repo source ($SOURCE). Remove it from repo."
fi

# Ensure dest exists
sudo mkdir -p "$DEST"

say "== Syncing files (excluding certs/) =="
sudo rsync -av --delete \
  --exclude 'certs/' \
  "$SOURCE/" \
  "$DEST/"

# Ensure certs dir exists but do not overwrite its contents
sudo mkdir -p "$DEST/certs"

say ""
say "== Setting ownership and permissions (excluding certs contents) =="

# Base dir
sudo chown root:root "$DEST"
sudo chmod 755 "$DEST"

# Lock down certs directory itself; do NOT chmod/chown cert files broadly here
sudo chown root:root "$DEST/certs"
sudo chmod 700 "$DEST/certs"
# If key files exist, keep them strict
sudo find "$DEST/certs" -type f \( -name "*.key" -o -name "*.pem" \) -exec chmod 600 {} \; 2>/dev/null || true

# Apply root ownership + sane perms to everything except certs subtree
shopt -s nullglob dotglob
for p in "$DEST"/*; do
  [[ "$p" == "$DEST/certs" ]] && continue
  sudo chown -R root:root "$p"
done
shopt -u nullglob dotglob

sudo find "$DEST" -path "$DEST/certs" -prune -o -type d -exec chmod 755 {} \;
sudo find "$DEST" -path "$DEST/certs" -prune -o -type f -exec chmod 644 {} \;

say ""
say "== Testing nginx configuration inside container =="
if docker exec "$NGINX_CONTAINER" nginx -t; then
  say ""
  say "✅ Configuration test passed"
  say ""
  read -p "Reload nginx now? [y/N] " -n 1 -r
  echo
  if [[ "${REPLY:-}" =~ ^[Yy]$ ]]; then
    docker exec "$NGINX_CONTAINER" nginx -s reload
    say "✅ Nginx reloaded successfully"
  else
    say "⚠️  Skipped reload. Run: docker exec $NGINX_CONTAINER nginx -s reload"
  fi
else
  say ""
  die "Configuration test failed. Nginx NOT reloaded."
fi
