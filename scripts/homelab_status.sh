#!/usr/bin/env bash
# homelab_status.sh — Smart status check for geek homelab
# Adapts output based on where it's running (local vs remote access)
# Usage: ./scripts/homelab_status.sh [verbose]
#        make homelab-status
#        make homelab-status-verbose

set -u  # Exit on undefined variables
# Don't use -e or -o pipefail; we need to handle errors gracefully

VERBOSE="${1:-}"
GEEK_HOST="johnb@geek"
CURRENT_HOST=$(hostname -s 2>/dev/null || echo "unknown")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC}  $1"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

check_mark() {
  echo -e "${GREEN}✅${NC}"
}

cross_mark() {
  echo -e "${RED}❌${NC}"
}

warning_mark() {
  echo -e "${YELLOW}⚠️${NC}"
}

status_line() {
  local label="$1"
  local result="$2"
  local details="${3:-}"

  printf "%-40s %s" "$label" "$result"
  if [ -n "$details" ]; then
    echo " ($details)"
  else
    echo ""
  fi
}

# Determine if we're running on the geek host or remotely (macbook, etc.)
IS_LOCAL_GEEK=false
if [ "$CURRENT_HOST" = "geek" ]; then
  IS_LOCAL_GEEK=true
fi

# Header with context
if [ "$IS_LOCAL_GEEK" = true ]; then
  print_header "HOMELAB STATUS (local: geek) — $(date '+%Y-%m-%d %H:%M:%S')"
else
  print_header "HOMELAB STATUS (remote control via SSH) — $(date '+%Y-%m-%d %H:%M:%S')"
fi
echo ""

# ============================================================================
# LOCAL SERVICES (only shown if running on geek host itself)
# ============================================================================
if [ "$IS_LOCAL_GEEK" = true ]; then
  echo -e "${BLUE}Local Services${NC}"

  if ! docker ps &>/dev/null; then
    status_line "Docker daemon" "$(cross_mark)"
    echo ""
  else
    # Docker is available
    status_line "Docker daemon" "$(check_mark)"
    echo ""

    # Network
    echo -e "${BLUE}Network${NC}"
    if docker network ls 2>/dev/null | grep -q geek-infra; then
      status_line "geek-infra network" "$(check_mark)"
    else
      status_line "geek-infra network" "$(cross_mark)"
    fi
    echo ""

    # Services
    echo -e "${BLUE}Containers${NC}"
    RUNNING=$(docker ps 2>/dev/null | grep -E "(postgres|nginx|authentik|redis)" | wc -l)
    status_line "Running critical services" "$(check_mark)" "$RUNNING running"

    for svc in geek-postgres geek-nginx authentik-server authentik-worker authentik-outpost geek-redis; do
      if docker ps 2>/dev/null | grep -q "$svc"; then
        status_line "  • $svc" "$(check_mark)"
      else
        status_line "  • $svc" "$(cross_mark)"
      fi
    done
    echo ""

    # nginx config check
    echo -e "${BLUE}Configuration${NC}"
    if docker ps 2>/dev/null | grep -q geek-nginx; then
      if docker exec geek-nginx nginx -t 2>&1 | grep -q successful; then
        status_line "nginx syntax" "$(check_mark)"
      else
        status_line "nginx syntax" "$(cross_mark)"
        if [ "$VERBOSE" = "verbose" ]; then
          docker exec geek-nginx nginx -t 2>&1 | sed 's/^/  /'
        fi
      fi
    else
      status_line "nginx syntax" "$(warning_mark)" "nginx not running"
    fi
    echo ""

    # Database health
    echo -e "${BLUE}Data Services${NC}"
    if docker ps 2>/dev/null | grep -q geek-postgres; then
      PG_READY=$(docker exec geek-postgres pg_isready -U postgres 2>/dev/null | grep "accepting" || echo "no")
      if [ "$PG_READY" != "no" ]; then
        status_line "PostgreSQL" "$(check_mark)" "ready"
      else
        status_line "PostgreSQL" "$(warning_mark)" "not ready"
      fi
    else
      status_line "PostgreSQL" "$(cross_mark)" "not running"
    fi

    if docker ps 2>/dev/null | grep -q geek-redis; then
      status_line "Redis" "$(check_mark)" "running"
    else
      status_line "Redis" "$(warning_mark)" "not running"
    fi
    echo ""
  fi
else
  # ============================================================================
  # REMOTE HOST STATUS (when running on macbook, etc. - accessing geek via SSH)
  # ============================================================================
  echo -e "${BLUE}Remote Host (geek)${NC}"
  if ! ssh "$GEEK_HOST" "docker ps &>/dev/null" 2>/dev/null; then
    status_line "SSH connection" "$(cross_mark)"
    status_line "Docker daemon" "$(cross_mark)"
    echo ""
    echo "Cannot reach geek host. Check SSH connectivity:"
    echo "  ssh $GEEK_HOST 'hostname'"
  else
    status_line "SSH connection" "$(check_mark)"
    echo ""

    # Get service list from remote
    SERVICES=$(ssh "$GEEK_HOST" "docker ps --format '{{.Names}}' 2>/dev/null" || echo "")

    echo -e "${BLUE}Containers${NC}"
    for svc in geek-postgres geek-nginx authentik-server authentik-worker authentik-outpost geek-redis; do
      if echo "$SERVICES" | grep -q "$svc"; then
        status_line "  • $svc" "$(check_mark)"
      else
        status_line "  • $svc" "$(warning_mark)" "not running"
      fi
    done
    echo ""

    # Remote nginx config check
    echo -e "${BLUE}Configuration${NC}"
    NGINX_TEST=$(ssh "$GEEK_HOST" "docker exec geek-nginx nginx -t 2>&1" || echo "failed")
    if echo "$NGINX_TEST" | grep -q "successful"; then
      status_line "nginx syntax" "$(check_mark)"
    else
      status_line "nginx syntax" "$(cross_mark)"
      if [ "$VERBOSE" = "verbose" ]; then
        echo "$NGINX_TEST" | sed 's/^/  /'
      fi
    fi

    if ssh "$GEEK_HOST" "[ -d /etc/nginx-docker ]" 2>/dev/null; then
      status_line "/etc/nginx-docker" "$(check_mark)"
    else
      status_line "/etc/nginx-docker" "$(cross_mark)"
    fi
    echo ""
  fi
fi

# ============================================================================
# COMMON SECTIONS (shown regardless of local vs remote)
# ============================================================================

# Service Endpoints (HTTP connectivity tests)
echo -e "${BLUE}Service Endpoints${NC}"
if [ "$VERBOSE" = "verbose" ]; then
  # Only run these if verbose (they're slower)
  endpoints=(
    "http://auth.geek|Internal Auth"
    "http://bookstack.geek|Internal BookStack"
    "https://auth.johnnyblabs.com|Public Auth"
    "https://bookstack.johnnyblabs.com|Public BookStack"
  )

  for endpoint in "${endpoints[@]}"; do
    url="${endpoint%%|*}"
    label="${endpoint##*|}"
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -k "$url" 2>/dev/null || echo "000")

    case "$RESPONSE" in
      200|302)
        status_line "$label" "$(check_mark)" "HTTP $RESPONSE"
        ;;
      *)
        status_line "$label" "$(warning_mark)" "HTTP $RESPONSE"
        ;;
    esac
  done
else
  echo "(Run 'make homelab-status-verbose' for connectivity tests)"
fi
echo ""

# 8. Git Status
echo -e "${BLUE}Repository${NC}"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
UNCOMMITTED=$(git status --short 2>/dev/null | wc -l)
AHEAD=$(git rev-list --count @{u}.. 2>/dev/null || echo "0")

status_line "Branch" "$(check_mark)" "$BRANCH"
if [ "$UNCOMMITTED" -eq 0 ]; then
  status_line "Uncommitted changes" "$(check_mark)" "none"
else
  status_line "Uncommitted changes" "$(warning_mark)" "$UNCOMMITTED files"
fi
if [ "$AHEAD" -gt 0 ]; then
  status_line "Unpushed commits" "$(warning_mark)" "$AHEAD commits ahead"
else
  status_line "Unpushed commits" "$(check_mark)"
fi
echo ""

print_header "QUICK ACTIONS"
echo ""
echo "Common commands:"
echo "  make nginx-test              Test nginx configuration"
echo "  make homelab-status-verbose  Show connectivity tests"
echo "  make homelab-logs            Show recent service logs"
echo "  make homelab-health          Run full health checks"
echo ""
echo "For more info: see CLAUDE.md, README.md, or platform/ingress/nginx/README.md"
