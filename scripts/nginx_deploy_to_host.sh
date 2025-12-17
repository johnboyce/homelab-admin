#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_ROOT/platform/ingress/nginx/etc-nginx-docker"
DEST="/etc/nginx-docker"

echo "== Deploying nginx config: repo → host =="
echo "   Source: $SOURCE"
echo "   Dest:   $DEST"
echo ""

# Verify source directory exists
if [ ! -d "$SOURCE" ]; then
  echo "❌ Error: Source directory not found: $SOURCE"
  exit 1
fi

# Deploy config (excluding certs directory entirely - host manages those)
sudo rsync -av --delete \
  --exclude 'certs/' \
  "$SOURCE/" \
  "$DEST/"

# Ensure certs directory exists on host (but don't touch contents)
sudo mkdir -p "$DEST/certs"

# Set correct ownership and permissions
echo ""
echo "== Setting ownership and permissions =="
sudo chown -R root:root "$DEST"
sudo find "$DEST" -type d -exec chmod 755 {} \;
sudo find "$DEST" -type f -exec chmod 644 {} \;

# Preserve stricter permissions on private keys if they exist (ignore if no cert files present)
if [ -d "$DEST/certs" ]; then
  sudo find "$DEST/certs" -type f \( -name "*.key" -o -name "*.pem" \) -exec chmod 600 {} \; 2>/dev/null || true
fi

echo ""
echo "== Testing nginx configuration =="
if docker exec geek-nginx nginx -t; then
  echo ""
  echo "✅ Configuration test passed"
  echo ""
  read -p "Reload nginx? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker exec geek-nginx nginx -s reload
    echo "✅ Nginx reloaded successfully"
  else
    echo "⚠️  Skipped reload. Run 'docker exec geek-nginx nginx -s reload' manually when ready."
  fi
else
  echo ""
  echo "❌ Configuration test failed. Nginx NOT reloaded."
  echo "   Fix errors and run this script again."
  exit 1
fi
