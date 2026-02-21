#!/usr/bin/env bash
# homelab_status.sh — Quick status check for geek homelab
# Usage: ./scripts/homelab_status.sh [verbose]
#        make homelab-status
#        make homelab-status-verbose

set -u  # Exit on undefined variables
# Don't use -e or -o pipefail; we need to handle errors gracefully

VERBOSE="${1:-}"
GEEK_HOST="johnb@geek"

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

# Quick checks (no verbose needed)
print_header "HOMELAB STATUS — $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if Docker is available locally
if ! docker ps &>/dev/null; then
  echo -e "${YELLOW}Note: Docker not available locally. Checking remote host (geek) instead.${NC}"
  echo ""
else
  # 1. Docker Network
  echo -e "${BLUE}Network (Local)${NC}"
  if docker network ls 2>/dev/null | grep -q geek-infra; then
    status_line "Docker network (geek-infra)" "$(check_mark)"
  else
    status_line "Docker network (geek-infra)" "$(cross_mark)"
  fi
  echo ""

  # 2. Container Status
  echo -e "${BLUE}Services (Local)${NC}"
  RUNNING=$(docker ps 2>/dev/null --filter "label!=skip" | grep -E "(postgres|nginx|authentik|redis)" | wc -l)
  if [ "$RUNNING" -gt 0 ]; then
    status_line "Running containers" "$(check_mark)" "$RUNNING containers"
  else
    status_line "Running containers" "$(warning_mark)" "none (likely remote only)"
  fi

  # Check each critical service
  for svc in geek-postgres geek-nginx authentik-server authentik-outpost; do
    if docker ps 2>/dev/null | grep -q "$svc"; then
      status_line "  $svc" "$(check_mark)" "running"
    fi
  done
  echo ""

  # 3. nginx Configuration
  echo -e "${BLUE}nginx (Local)${NC}"
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
    status_line "nginx syntax" "$(warning_mark)" "nginx not running locally"
  fi
  echo ""

  # 4. PostgreSQL
  echo -e "${BLUE}Database (Local)${NC}"
  if docker ps 2>/dev/null | grep -q geek-postgres; then
    PG_READY=$(docker exec geek-postgres pg_isready -U postgres 2>/dev/null | grep "accepting" || echo "no")
    if [ "$PG_READY" != "no" ]; then
      status_line "PostgreSQL ready" "$(check_mark)"
    else
      status_line "PostgreSQL ready" "$(warning_mark)"
    fi
  else
    status_line "PostgreSQL ready" "$(warning_mark)" "postgres not running locally"
  fi
  echo ""

  # 5. Authentik Status
  echo -e "${BLUE}Authentik (Local)${NC}"
  if docker ps 2>/dev/null | grep -q authentik-server; then
    AUTH_HEALTH=$(docker exec authentik-server curl -s http://localhost:9000/health/live/ -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
    if [ "$AUTH_HEALTH" = "204" ] || [ "$AUTH_HEALTH" = "200" ]; then
      status_line "Authentik API" "$(check_mark)" "HTTP $AUTH_HEALTH"
    else
      status_line "Authentik API" "$(warning_mark)" "HTTP $AUTH_HEALTH"
    fi
  else
    status_line "Authentik API" "$(warning_mark)" "authentik not running locally"
  fi
  echo ""
fi

# 6. Remote Host Status (via SSH)
echo -e "${BLUE}Remote Host (geek)${NC}"
if ssh "$GEEK_HOST" "docker ps &>/dev/null" 2>/dev/null; then
  status_line "SSH connection" "$(check_mark)"

  # Count remote containers
  REMOTE_COUNT=$(ssh "$GEEK_HOST" "docker ps --format 'table {{.Names}}' 2>/dev/null" | grep -E "(postgres|nginx|authentik|redis)" | wc -l)
  status_line "Remote containers running" "$(check_mark)" "$REMOTE_COUNT containers"

  # Check /etc/nginx-docker
  if ssh "$GEEK_HOST" "[ -d /etc/nginx-docker ]" 2>/dev/null; then
    status_line "/etc/nginx-docker on host" "$(check_mark)"
  else
    status_line "/etc/nginx-docker on host" "$(cross_mark)"
  fi
else
  status_line "SSH connection" "$(cross_mark)"
fi
echo ""

# 7. Connectivity Tests
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
