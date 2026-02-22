#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🏥 Homelab Health Check"
echo "======================="
echo ""

# Function to check command status
check() {
    local name="$1"
    local cmd="$2"

    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        return 1
    fi
}

# Track failures
FAILURES=0

echo "📦 Container Status:"
echo "---"

# Check if all containers are running
CONTAINERS=("geek-nginx" "authentik-server" "authentik-worker" "authentik-outpost" "geek-postgres" "bookstack" "bookstack-db" "geek-redis" "geek-pihole" "geek-cloudflare-ddns")

for container in "${CONTAINERS[@]}"; do
    if check "$container" "ssh johnb@geek \"docker ps --filter 'name=$container' --filter 'status=running' --quiet | grep -q .\""; then
        :
    else
        FAILURES=$((FAILURES + 1))
    fi
done

echo ""
echo "🗄️  Database Connectivity:"
echo "---"

# Test Authentik → PostgreSQL
if check "Authentik can reach PostgreSQL" "ssh johnb@geek \"docker exec authentik-server psql -U authentik -h geek-postgres -c 'SELECT version()' 2>/dev/null | grep -q PostgreSQL\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

# Test BookStack → MariaDB
if check "BookStack can reach MariaDB" "ssh johnb@geek \"docker exec bookstack-db mysql -u bigbear -pa3e8949f-484c-4877-afdb-391f892f9bb6 -h bookstack-db -e 'SELECT VERSION()' 2>/dev/null | grep -q '10.11'\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

# Test PostgreSQL database integrity
if check "PostgreSQL authentik database exists" "ssh johnb@geek \"docker exec geek-postgres psql -U authentik -c 'SELECT datname FROM pg_database WHERE datname=\\\"authentik\\\"' 2>/dev/null | grep -q authentik\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "🌐 Service Endpoints:"
echo "---"

# Test Authentik API
if check "Authentik API responding" "curl -s https://auth.johnnyblabs.com/api/v3/root/config/ 2>/dev/null | grep -q 'capabilities'"; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

# Test BookStack via forward-auth
if check "BookStack accessible (nginx forward-auth)" "curl -s -I https://bookstack.johnnyblabs.com 2>/dev/null | grep -q -E '^HTTP.*30[0-2]'"; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

# Test Authentik forward-auth callback
if check "Authentik outpost responding" "ssh johnb@geek \"docker exec geek-nginx curl -s -I http://authentik-outpost:9000/outpost.goauthentik.io/ping 2>/dev/null | grep -q -E '^HTTP.*200'\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "💾 Volume Mounts:"
echo "---"

# Check volume directories exist on geek
if check "/srv/homelab/postgres/pgdata exists" "ssh johnb@geek \"sudo test -d /srv/homelab/postgres/pgdata\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

if check "/srv/homelab/authentik exists" "ssh johnb@geek \"sudo test -d /srv/homelab/authentik\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

if check "/srv/homelab/bookstack exists" "ssh johnb@geek \"sudo test -d /srv/homelab/bookstack\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

if check "/srv/homelab/redis/data exists" "ssh johnb@geek \"sudo test -d /srv/homelab/redis/data\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "🔐 Secrets:"
echo "---"

# Check secrets files exist
SECRETS=("pihole" "authentik" "bookstack" "postgres" "cloudflare-ddns")

for secret in "${SECRETS[@]}"; do
    if check "/etc/homelab/secrets/$secret.env exists" "ssh johnb@geek \"sudo test -f /etc/homelab/secrets/$secret.env\""; then
        :
    else
        FAILURES=$((FAILURES + 1))
    fi
done

echo ""
echo "🔗 Network Connectivity:"
echo "---"

# Test service-to-service DNS resolution
if check "nginx can resolve authentik-server" "ssh johnb@geek \"docker exec geek-nginx getent hosts authentik-server | grep -q .\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

if check "nginx can resolve bookstack" "ssh johnb@geek \"docker exec geek-nginx getent hosts bookstack | grep -q .\""; then
    :
else
    FAILURES=$((FAILURES + 1))
fi

echo ""
echo "📊 Summary:"
echo "---"

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILURES check(s) failed${NC}"
    exit 1
fi
