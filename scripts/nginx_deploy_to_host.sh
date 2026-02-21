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
GEEK_HOST="${GEEK_HOST:-johnb@geek}"

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

# Detect deployment context
CURRENT_HOST=$(hostname -s 2>/dev/null || echo "unknown")
GEEK_SHORT=$(echo "$GEEK_HOST" | cut -d'@' -f2)
IS_LOCAL_GEEK=false
IS_MACOS=false

if [[ "$CURRENT_HOST" == "$GEEK_SHORT" ]]; then
  IS_LOCAL_GEEK=true
  say "== Running on geek host (local deployment) =="
elif [[ "$(uname)" == "Darwin" ]]; then
  IS_MACOS=true
  say "== Running on macOS (remote deployment via SSH) =="
else
  say "== Running on remote Linux host (deploying to geek via SSH) =="
fi

if [[ "$IS_LOCAL_GEEK" == "true" ]]; then
  # Already on geek: use local paths directly
  say "== Deploying locally (already on geek host) =="

  say "== Syncing files (excluding certs/) =="
  sudo mkdir -p "$DEST"
  # Extract tar contents directly into $DEST, stripping the 'etc-nginx-docker' directory level
  sudo tar --exclude='certs' -C "$(dirname "$SOURCE")" -cf - "$(basename "$SOURCE")" | sudo tar -xf - --strip-components=1 -C "$DEST"

  say ""
  say "== Setting ownership and permissions =="
  sudo chown -R root:root "$DEST"
  sudo chmod 755 "$DEST"
  sudo find "$DEST" -type f -exec chmod 644 {} \;
  sudo find "$DEST" -type d -exec chmod 755 {} \;

  # Ensure certs directory exists but don't overwrite its contents
  sudo mkdir -p "$DEST/certs"
  sudo chown root:root "$DEST/certs"
  sudo chmod 700 "$DEST/certs"
  sudo find "$DEST/certs" -type f \( -name "*.key" -o -name "*.pem" \) -exec chmod 600 {} \; 2>/dev/null || true

elif [[ "$IS_MACOS" == "true" ]] || [[ "$IS_LOCAL_GEEK" == "false" && "$(uname)" != "Darwin" ]]; then
  # Remote deployment (macOS or remote Linux): Deploy via SCP+SSH
  TEMP_TAR="/tmp/nginx-config-$$.tar"

  if [[ "$IS_MACOS" == "true" ]]; then
    say "== Deploying from macOS via SCP+SSH =="
  else
    say "== Deploying from remote Linux via SCP+SSH =="
  fi

  say "== Creating deployment archive =="
  tar --exclude='certs' -C "$(dirname "$SOURCE")" -cf "$TEMP_TAR" "$(basename "$SOURCE")" || die "Failed to create tar archive"

  say "== Copying to geek host =="
  scp "$TEMP_TAR" "$GEEK_HOST:/tmp/" > /dev/null 2>&1 || die "Failed to copy archive to geek host"

  say "== Extracting and setting permissions =="
  # Extract tar contents directly into /etc/nginx-docker, stripping the 'etc-nginx-docker' directory level
  ssh -t "$GEEK_HOST" "sudo bash -c 'mkdir -p \"$DEST\" && cd \"$DEST\" && tar -xf /tmp/nginx-config-$$.tar --strip-components=1 && rm -f /tmp/nginx-config-$$.tar && chown -R root:root \"$DEST\" && chmod 755 \"$DEST\" && find \"$DEST\" -type f -exec chmod 644 {} \; && find \"$DEST\" -type d -exec chmod 755 {} \; && mkdir -p \"$DEST/certs\" && chown root:root \"$DEST/certs\" && chmod 700 \"$DEST/certs\"'" || die "Failed to extract and set permissions"

  # Clean up local temp file
  rm -f "$TEMP_TAR"
fi

say ""
say "== Testing nginx configuration inside container =="

if [[ "$IS_MACOS" == "true" ]]; then
  # macOS: test via SSH on remote host
  if ssh "$GEEK_HOST" "docker exec '$NGINX_CONTAINER' nginx -t" 2>&1; then
    say ""
    say "✅ Configuration test passed"
    say ""
    read -p "Reload nginx now? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY:-}" =~ ^[Yy]$ ]]; then
      ssh "$GEEK_HOST" "docker exec '$NGINX_CONTAINER' nginx -s reload" || die "Failed to reload nginx"
      say "✅ Nginx reloaded successfully"
    else
      say "⚠️  Skipped reload. Run: ssh $GEEK_HOST 'docker exec $NGINX_CONTAINER nginx -s reload'"
    fi
  else
    say ""
    die "Configuration test failed. Nginx NOT reloaded."
  fi
else
  # Linux: test locally
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
fi
