#!/usr/bin/env bash
# check_versions.sh — Check current vs latest available versions
# Extracts versions from docker-compose.yml files and compares with upstream
# Usage: ./scripts/check_versions.sh [--update-spec]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPDATE_SPEC=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --update-spec)
      UPDATE_SPEC=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--update-spec]"
      exit 1
      ;;
  esac
done

echo -e "${BOLD}${BLUE}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          Homelab Service Version Report                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Function to extract image and version from docker-compose.yml
extract_versions() {
  local compose_file="$1"
  local service_name
  service_name=$(basename "$(dirname "$compose_file")")

  # Extract all image lines
  local images
  mapfile -t images < <(grep "image:" "$compose_file" | sed 's/.*image: *//' | sed 's/#.*//' | xargs)

  for image in "${images[@]}"; do
    if [ -n "$image" ]; then
      local repo version
      repo=$(echo "$image" | cut -d: -f1)
      version=$(echo "$image" | cut -d: -f2-)

      printf "%-25s %-45s %-15s\n" "$service_name" "$repo" "$version"
    fi
  done
}

# Header
printf "%-25s %-45s %-15s\n" "SERVICE" "IMAGE" "VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Scan all docker-compose files
compose_files=$(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f | sort)

for compose_file in $compose_files; do
  extract_versions "$compose_file"
done

echo ""
echo -e "${BOLD}Analysis${NC}"
echo ""

# Count :latest usage
latest_count=$(find "$REPO_ROOT/platform" -name "docker-compose.yml" -exec grep "image:" {} \; | grep -c ":latest" || true)
pinned_count=$(find "$REPO_ROOT/platform" -name "docker-compose.yml" -exec grep "image:" {} \; | grep -v ":latest" | wc -l || true)

echo -e "${BLUE}Version Strategy Distribution:${NC}"
echo "  Pinned versions:    $pinned_count"
echo "  Latest tags:        $latest_count"
echo ""

if [ "$latest_count" -gt 0 ]; then
  echo -e "${YELLOW}⚠ Recommendation:${NC} $latest_count service(s) using :latest tag"
  echo "  Consider pinning versions for critical services:"
  echo ""
  find "$REPO_ROOT/platform" -name "docker-compose.yml" -exec grep -l ":latest" {} \; | while read -r file; do
    service=$(basename "$(dirname "$file")")
    echo "    - $service"
  done
  echo ""
fi

echo -e "${BLUE}Critical Services Check:${NC}"

# Check specific critical services
critical_services=("nginx" "postgres" "authentik")
for service in "${critical_services[@]}"; do
  compose_file="$REPO_ROOT/platform/$service/docker-compose.yml"
  if [ -f "$compose_file" ]; then
    if grep "image:.*:latest" "$compose_file" >/dev/null 2>&1; then
      echo -e "  ${RED}✗${NC} $service using :latest (should be pinned)"
    else
      echo -e "  ${GREEN}✓${NC} $service using pinned version"
    fi
  fi
done

echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo ""
echo "1. Review upstream sources for latest stable versions:"
echo "   - nginx:          https://hub.docker.com/_/nginx"
echo "   - postgres:       https://hub.docker.com/_/postgres"
echo "   - authentik:      https://github.com/goauthentik/authentik/releases"
echo "   - bookstack:      https://www.bookstackapp.com/blog/"
echo "   - forgejo:        https://codeberg.org/forgejo/forgejo/releases"
echo "   - vaultwarden:    https://github.com/dani-garcia/vaultwarden/releases"
echo "   - pihole:         https://github.com/pi-hole/docker-pi-hole/releases"
echo "   - woodpecker:     https://github.com/woodpecker-ci/woodpecker/releases"
echo "   - plane:          https://github.com/makeplane/plane/releases"
echo ""
echo "2. Update docker-compose.yml files with new versions"
echo ""
echo "3. Test deployment:"
echo "   make ansible-dry-run"
echo "   make ansible-apply"
echo ""
echo "4. Update HOMELAB_SPEC.yml version matrix with findings"
echo ""
echo "5. Commit changes:"
echo "   git add -A"
echo "   git commit -m 'Update service versions'"
echo ""

if [ "$UPDATE_SPEC" = true ]; then
  echo -e "${BLUE}Updating HOMELAB_SPEC.yml with current date...${NC}"
  spec_file="$REPO_ROOT/HOMELAB_SPEC.yml"
  if [ -f "$spec_file" ]; then
    today=$(date '+%Y-%m-%d')
    # Update last_updated in version matrix
    if command -v sed >/dev/null 2>&1; then
      sed -i.bak "s/last_updated: \".*\"/last_updated: \"$today\"/" "$spec_file" 2>/dev/null || \
      sed -i '' "s/last_updated: \".*\"/last_updated: \"$today\"/" "$spec_file"
      echo -e "${GREEN}✓${NC} Updated last_updated to $today"
    fi
  fi
fi

