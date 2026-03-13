# Service Inventory Specification

## Overview

Complete inventory of all services deployed in the homelab infrastructure with their current configuration, dependencies, and compliance status.

## Purpose

- Document all deployed services
- Track versions and update policies
- Identify dependencies between services
- Monitor compliance with infrastructure standards
- Guide maintenance and updates

---

## Infrastructure Services

### nginx (Reverse Proxy)

**Status:** ✅ Production
**Category:** Infrastructure
**Location:** `platform/nginx/docker-compose.yml`
**Ansible Role:** `ansible/roles/nginx/`

**Current Configuration:**
- Image: `nginx:1.29.4` (major-pinned)
- Container: `geek-nginx`
- Ports: 80 (HTTP), 443 (HTTPS) — public
- Network: `geek-infra`
- Config: `/etc/nginx-docker/` (synced from repo)

**Dependencies:** None (foundation service)

**Domains Served:**
- All `*.geek` domains (internal HTTP)
- All `*.johnnyblabs.com` domains (public HTTPS)

**Version Policy:**
- Strategy: Major version pinned
- Update schedule: Quarterly
- Last checked: 2026-03-04
- Upstream: https://hub.docker.com/_/nginx

**Compliance:**
- ✅ Version pinned
- ✅ Ansible managed
- ✅ Documentation complete
- ✅ Health check implemented
- ✅ No secrets required

**Next Actions:**
- Monitor for nginx 1.29.x security updates
- Review for 1.30 when stable

---

### PostgreSQL (Shared Database)

**Status:** ✅ Production
**Category:** Data
**Location:** `platform/postgres/docker-compose.yml`
**Ansible Role:** `ansible/roles/postgres/`

**Current Configuration:**
- Image: `postgres:16` (major-pinned)
- Container: `geek-postgres`
- Port: 5432 (docker-network only)
- Network: `geek-infra`
- Data: `/srv/homelab/postgres/pgdata`

**Dependencies:** None (foundation service)

**Used By:**
- Authentik (database: `authentik`)
- Forgejo (database: `forgejo`)
- Plane (database: `plane`)

**Secrets:**
- File: `/etc/homelab/secrets/postgres.env`
- Required: `POSTGRES_PASSWORD`
- Rotation: Annually or on compromise

**Version Policy:**
- Strategy: Major version pinned
- Current: PostgreSQL 16.x
- Update schedule: Security patches only
- Last checked: 2026-03-04
- Upstream: https://hub.docker.com/_/postgres

**Compliance:**
- ✅ Version pinned (major)
- ✅ Ansible managed
- ⚠️  No .env.example file
- ✅ Backup strategy documented
- ✅ Health check via container status

**Next Actions:**
- Create `.env.example`
- Check for latest 16.x patch version
- Document database initialization for each service

---

### Docker Infrastructure

**Status:** ✅ Production
**Category:** Infrastructure
**Ansible Role:** `ansible/roles/docker_infra/`

**Purpose:**
- Creates `geek-infra` external network
- Ensures Docker is installed and running
- Foundation for all containerized services

**Managed Resources:**
- Network: `geek-infra` (bridge)

**Dependencies:** None (bootstrap service)

**Compliance:**
- ✅ Ansible managed
- ✅ Idempotent
- ✅ No configuration required

---

## Identity Services

### Authentik (SSO/Identity Provider)

**Status:** ✅ Production
**Category:** Identity
**Location:** `platform/authentik/docker-compose.yml`
**Ansible Role:** `ansible/roles/authentik/`

**Current Configuration:**
- Image: `ghcr.io/goauthentik/server:2025.10.4` (pinned)
- Containers: `authentik-server`, `authentik-worker`, `authentik-outpost`
- Ports: 9000, 9443 (docker-network only, proxied via nginx)
- Network: `geek-infra`
- Data: `/srv/homelab/authentik/media`, `/srv/homelab/authentik/custom-templates`

**Dependencies:**
- postgres (database: `authentik`)

**Protects:**
- bookstack.johnnyblabs.com (forward auth)
- Future protected services

**Domains:**
- Internal: `auth.geek` (HTTP)
- Public: `auth.johnnyblabs.com` (HTTPS)

**Secrets:**
- File: `/etc/homelab/secrets/authentik.env`
- Required: `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_POSTGRESQL__PASSWORD`, `AUTHENTIK_TOKEN`
- Rotation: Annually

**Version Policy:**
- Strategy: Pinned exact version
- Current: 2025.10.4
- Update schedule: Manual (test thoroughly)
- Last checked: 2026-03-04
- Last updated: 2026-02-21
- Upstream: https://github.com/goauthentik/authentik/releases
- Breaking changes: Common, read release notes carefully

**Compliance:**
- ✅ Version pinned
- ✅ Ansible managed
- ✅ .env.example exists
- ✅ Backup required and documented
- ✅ Health check implemented
- ✅ Documentation complete (AUTHENTIK_*.md)

**Known Issues:**
- Redis dependency removed in 2025.8+ (already updated)
- Outpost token management needs attention

**Next Actions:**
- Monitor for security patches in 2025.10.x
- Review 2025.11.x when released

---

## Application Services

### BookStack (Documentation Wiki)

**Status:** ✅ Production
**Category:** Applications
**Location:** `platform/bookstack/docker-compose.yml`
**Ansible Role:** `ansible/roles/bookstack/`

**Current Configuration:**
- Image: `linuxserver/bookstack:25.12.7` (pinned)
- Containers: `bookstack`, `bookstack-db` (MariaDB)
- Network: `geek-infra`
- Database: Self-contained MariaDB (not shared postgres)
- Data: `/srv/homelab/bookstack/config`, `/srv/homelab/bookstack/mysql`

**Dependencies:**
- bookstack-db (internal MariaDB)
- authentik (for OIDC auth on public domain)

**Domains:**
- Internal: `bookstack.geek` (HTTP, no auth)
- Public: `bookstack.johnnyblabs.com` (HTTPS, Authentik protected)

**Secrets:**
- File: `/etc/homelab/secrets/bookstack.env`
- Required: `APP_KEY`, `DB_PASSWORD`, `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD`
- OIDC: Additional variables for Authentik integration

**Version Policy:**
- Strategy: Pinned semantic version
- Current: 25.12.7 (LinuxServer.io format: YY.MM.patch)
- Update schedule: Quarterly
- Last checked: 2026-03-04
- Upstream: https://hub.docker.com/r/linuxserver/bookstack

**Compliance:**
- ✅ Version pinned
- ✅ Ansible managed
- ⚠️  No .env.example file
- ✅ Backup required (documented)
- ✅ Health check implemented
- ✅ Documentation exists (BOOKSTACK_INFRASTRUCTURE.md)

**Next Actions:**
- Create `.env.example`
- Check for 25.12.x updates
- Verify OIDC bootstrap script works

---

### Forgejo (Git Service)

**Status:** ✅ Production
**Category:** Applications
**Location:** `platform/forgejo/docker-compose.yml`
**Ansible Role:** `ansible/roles/forgejo/`

**Current Configuration:**
- Image: `codeberg.org/forgejo/forgejo:14` (major-pinned)
- Container: `forgejo`
- Ports: 
  - 222:2222 (SSH, LAN-only)
  - 3000 (HTTP, docker-network only)
- Network: `geek-infra`
- Database: Shared postgres (database: `forgejo`)
- Data: `/srv/homelab/forgejo/data`

**Dependencies:**
- postgres

**Integrated With:**
- woodpecker (CI/CD OAuth)

**Domains:**
- Internal: `forgejo.geek` (HTTP)
- SSH: `geek:222` (LAN-only)

**Secrets:**
- File: `/etc/homelab/secrets/forgejo.env`
- Required: `FORGEJO__database__PASSWD`

**Version Policy:**
- Strategy: Major version rolling tag
- Current: 14 (auto-updates within v14.x)
- Update schedule: Automatic within major
- Last checked: 2026-03-04
- Upstream: https://codeberg.org/forgejo/forgejo/releases

**Compliance:**
- ✅ Version strategy (major rolling)
- ✅ Ansible managed
- ⚠️  No .env.example file
- ✅ Backup required
- ✅ Health check (container status)
- ⚠️  SSH port 222 needs documentation

**Next Actions:**
- Create `.env.example`
- Document SSH key management
- Monitor for Forgejo 15 release

---

### Vaultwarden (Password Manager)

**Status:** ✅ Production
**Category:** Security
**Location:** `platform/vaultwarden/docker-compose.yml`
**Ansible Role:** `ansible/roles/vaultwarden/`

**Current Configuration:**
- Image: `vaultwarden/server:latest` ⚠️
- Container: `vaultwarden`
- Port: 80 (docker-network only)
- Network: `geek-infra`
- Data: `/srv/homelab/vaultwarden/data`

**Dependencies:** None

**Domains:**
- Internal: `vaultwarden.geek` (HTTP)
- Public: `vaultwarden.johnnyblabs.com` (HTTPS)

**Secrets:**
- File: `/etc/homelab/secrets/vaultwarden.env`
- Required: `ADMIN_TOKEN`

**Version Policy:**
- Strategy: Latest ⚠️ **Should be pinned**
- Update schedule: Monthly
- Last checked: 2026-03-04
- Upstream: https://github.com/dani-garcia/vaultwarden/releases

**Compliance:**
- ❌ Using :latest (security-critical service should pin)
- ✅ Ansible managed
- ⚠️  No .env.example file
- ✅ Backup required
- ✅ Health check implemented

**Next Actions:**
- **CRITICAL:** Pin to specific version
- Create `.env.example`
- Check latest stable release
- Test upgrade procedure

---

### Woodpecker (CI/CD)

**Status:** ✅ Production
**Category:** Automation
**Location:** `platform/woodpecker/docker-compose.yml`
**Ansible Role:** `ansible/roles/woodpecker/`

**Current Configuration:**
- Image: `woodpeckerci/woodpecker-server:latest` ⚠️
- Containers: `woodpecker-server`, `woodpecker-agent`
- Ports: 
  - 8000 (HTTP, docker-network)
  - 9000 (gRPC, docker-network)
- Network: `geek-infra`
- Data: `/srv/homelab/woodpecker/agent`

**Dependencies:**
- forgejo (OAuth integration)

**Domains:**
- Internal: `woodpecker.geek` (HTTP)

**Secrets:**
- File: `/etc/homelab/secrets/woodpecker.env`
- Required: `WOODPECKER_AGENT_SECRET`, `WOODPECKER_FORGEJO_CLIENT`, `WOODPECKER_FORGEJO_SECRET`

**Version Policy:**
- Strategy: Latest ⚠️ **Should pin to major**
- Update schedule: Monthly
- Last checked: 2026-03-04
- Upstream: https://github.com/woodpecker-ci/woodpecker/releases

**Compliance:**
- ❌ Using :latest
- ✅ Ansible managed
- ⚠️  No .env.example file
- ⚠️  Backup not required (ephemeral CI data)
- ✅ Health check (container status)

**Next Actions:**
- Pin to major or specific version
- Create `.env.example`
- Document Forgejo OAuth setup

---

### MagicMirror² (Morning Dashboard)

**Status:** ✅ Production
**Category:** Applications
**Location:** `platform/magicmirror/docker-compose.yml`
**Ansible Role:** `ansible/roles/magicmirror/`

**Current Configuration:**
- Image: `karsten13/magicmirror:latest`
- Container: `geek-magicmirror`
- Port: 8080 (docker-network only)
- Network: `geek-infra`
- Config: `/srv/homelab/magicmirror/config` (Ansible-managed, template)
- Modules: `/srv/homelab/magicmirror/modules`

**Dependencies:** None

**Domains:**
- Internal: `magicmirror.geek` (HTTP, LAN only)

**Secrets:**
- File: `/etc/homelab/secrets/magicmirror.env`
- Required: `OPENWEATHERMAP_API_KEY`
- Key source: https://openweathermap.org (free tier)

**Modules:**
- `clock` — 12-hour format with date
- `weather` (×4) — Wayne PA 19342 (imperial, current + 5-day) + Letterkenny Ireland (metric, current + 3-day)
- `MMM-Jast` — Yahoo Finance stocks: LMT, CMCSA, AAPL, NVDA (no API key)
- `newsfeed` (×2) — World (BBC + Reuters) + Local (Philly Inquirer + 6ABC)

**Kiosk & Display:**
- Chromium `--kiosk` launched via XDG autostart (`~/.config/autostart/magicmirror-kiosk.desktop`)
- Display wake: `magicmirror-wake.timer` → 07:00 daily (`xset dpms force on`)
- Display sleep: `magicmirror-sleep.timer` → 09:00 daily (`xset dpms force off`)
- GDM3 Wayland disabled (X11 required for `xset dpms`)
- `loginctl enable-linger johnb` ensures timers survive logout

**Version Policy:**
- Strategy: Latest (acceptable for dashboard)
- Update schedule: Monthly
- Last checked: 2026-03-13
- Upstream: https://hub.docker.com/r/karsten13/magicmirror

**Compliance:**
- ⚠️  Using :latest (non-critical dashboard service)
- ✅ Ansible managed
- ✅ .env.example exists
- ✅ No backup needed (config in git via Ansible template)
- ✅ Health check: HTTP 200 at `http://magicmirror.geek/`

**Next Actions:**
- Physical verification: confirm kiosk autostart at 07:00 with active X session
- Consider pinning to a specific version if stability issues arise

---

### Plane (Project Management)

**Status:** ✅ Production
**Category:** Applications
**Location:** `platform/plane/docker-compose.yml`
**Ansible Role:** `ansible/roles/plane/`

**Current Configuration:**
- Images: `makeplane/plane-backend:latest`, `makeplane/plane-frontend:latest` ⚠️
- Containers: `plane-api`, `plane-frontend`, `plane-redis`
- Network: `geek-infra`
- Database: Shared postgres (database: `plane`)
- Data: `/srv/homelab/plane/data`

**Dependencies:**
- postgres
- plane-redis (internal Redis instance)

**Domains:**
- Internal: `plane.geek` (HTTP)

**Secrets:**
- File: `/etc/homelab/secrets/plane.env`
- Required: `PLANE_SECRET_KEY`, `PLANE_DB_PASSWORD`

**Version Policy:**
- Strategy: Latest ⚠️ **High risk, should pin**
- Update schedule: Monthly
- Last checked: 2026-03-04
- Upstream: https://github.com/makeplane/plane/releases

**Compliance:**
- ❌ Using :latest (community deployment, breaking changes likely)
- ✅ Ansible managed
- ⚠️  No .env.example file
- ✅ Backup required
- ⚠️  Health check needs improvement

**Next Actions:**
- **HIGH PRIORITY:** Pin to specific version
- Create `.env.example`
- Test latest stable release
- Consider if service is actively used

---

## Network Services

### Pi-hole (DNS/Ad Blocking)

**Status:** ✅ Production
**Category:** Network
**Location:** `platform/pihole/docker-compose.yml`
**Ansible Role:** `ansible/roles/pihole/`

**Current Configuration:**
- Image: `pihole/pihole:latest` ⚠️
- Container: `geek-pihole`
- Ports:
  - 53 (DNS, LAN-only)
  - 127.0.0.1:8081:80 (admin UI, localhost only)
- Network: `geek-infra`
- Config: `/srv/homelab/pihole/etc-pihole`, `/srv/homelab/pihole/etc-dnsmasq.d`

**Dependencies:** None

**Domains:**
- Internal: `pihole.geek` (HTTP, proxied from localhost)

**Secrets:**
- File: `/etc/homelab/secrets/pihole.env`
- Required: `WEBPASSWORD`

**Version Policy:**
- Strategy: Latest ⚠️ **Should use version tag**
- Update schedule: Monthly
- Last checked: 2026-03-04
- Upstream: https://github.com/pi-hole/docker-pi-hole/releases

**DNS Configuration:**
- Handles `.geek` domain resolution
- Custom hosts in `etc-dnsmasq.d/05-geek-local.conf`

**Compliance:**
- ❌ Using :latest
- ✅ Ansible managed
- ⚠️  No .env.example file
- ✅ Backup required (configs)
- ✅ Health check implemented

**Next Actions:**
- Pin to version tag (e.g., `2024.07.0`)
- Create `.env.example`
- Document dnsmasq custom configs

---

### Cloudflare DDNS

**Status:** ✅ Production
**Category:** Network
**Location:** `platform/cloudflare-ddns/docker-compose.yml`
**Ansible Role:** `ansible/roles/cloudflare_ddns/`

**Current Configuration:**
- Image: `oznu/cloudflare-ddns:latest` (acceptable)
- Container: `cloudflare-ddns`
- Network: `geek-infra`
- Updates: Every 5 minutes

**Dependencies:** None

**Purpose:**
- Updates Cloudflare DNS with current public IP
- Enables remote access to `*.johnnyblabs.com`

**Secrets:**
- File: `/etc/homelab/secrets/cloudflare-ddns.env`
- Required: `CLOUDFLARE_API_TOKEN`, `ZONE`, `SUBDOMAIN`

**Version Policy:**
- Strategy: Latest (acceptable for utility)
- Update schedule: Quarterly review
- Last checked: 2026-03-04

**Compliance:**
- ✅ Latest acceptable for this service
- ✅ Ansible managed
- ⚠️  No .env.example file
- ✅ No backup needed
- ✅ Health check (container status)

**Next Actions:**
- Create `.env.example`

---

### Landing Page

**Status:** ✅ Production
**Category:** Applications
**Location:** `platform/landing/docker-compose.yml`
**Ansible Role:** `ansible/roles/landing/`

**Current Configuration:**
- Image: `nginx:1.29` (matches main nginx)
- Container: `landing`
- Network: `geek-infra`
- Content: `/srv/homelab/landing/` (static HTML)

**Dependencies:** None

**Domains:**
- Public: `johnnyblabs.com` (HTTPS, root domain)

**Compliance:**
- ✅ Version pinned
- ✅ Ansible managed
- ✅ No secrets needed
- ✅ No backup needed
- ✅ Simple and well-documented

---

## Service Dependency Graph

```
┌─────────────────────────────────────────────────────┐
│ Foundation Layer (No dependencies)                  │
├─────────────────────────────────────────────────────┤
│ • docker_infra (geek-infra network)                │
│ • nginx (reverse proxy)                             │
│ • postgres (shared database)                        │
│ • firewall (UFW rules)                              │
│ • pihole (DNS)                                      │
│ • cloudflare-ddns (public IP updates)              │
│ • landing (static site)                             │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Identity Layer                                      │
├─────────────────────────────────────────────────────┤
│ • authentik (depends on: postgres)                  │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Application Layer                                   │
├─────────────────────────────────────────────────────┤
│ • bookstack (depends on: bookstack-db, authentik)   │
│ • forgejo (depends on: postgres)                    │
│ • magicmirror (independent)                         │
│ • plane (depends on: postgres, plane-redis)         │
│ • vaultwarden (independent)                         │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│ Automation Layer                                    │
├─────────────────────────────────────────────────────┤
│ • woodpecker (depends on: forgejo)                  │
│ • forgejo-runner (depends on: forgejo)              │
└─────────────────────────────────────────────────────┘
```

## Service Health Matrix

| Service | Health Check Method | Endpoint | Status |
|---------|-------------------|----------|--------|
| nginx | HTTP | http://geek/healthz | ✅ |
| postgres | Container status | - | ✅ |
| authentik | HTTP | http://auth.geek/ | ✅ |
| bookstack | HTTP | http://bookstack.geek/ | ✅ |
| forgejo | Container status | - | ✅ |
| woodpecker | Container status | - | ✅ |
| vaultwarden | HTTP | http://vaultwarden.geek/ | ✅ |
| plane | Container status | - | ✅ |
| pihole | Container status | - | ✅ |
| cloudflare-ddns | Container status | - | ✅ |
| magicmirror | HTTP | http://magicmirror.geek/ | ✅ |
| landing | HTTP | https://johnnyblabs.com/ | ✅ |

## Version Summary

| Service | Current | Strategy | Update Priority |
|---------|---------|----------|-----------------|
| nginx | 1.29.4 | major-pinned | ✅ Up to date |
| postgres | 16 | major-pinned | ℹ️  Check for 16.2+ |
| authentik | 2025.10.4 | pinned | ✅ Recently updated |
| bookstack | 25.12.7 | pinned | ✅ Current |
| forgejo | 14 | major-rolling | ✅ Auto-updates |
| vaultwarden | latest | latest ⚠️ | ❌ SHOULD PIN |
| woodpecker | latest | latest ⚠️ | ⚠️  Should pin |
| plane | latest | latest ⚠️ | ⚠️  Should pin |
| pihole | latest | latest ⚠️ | ⚠️  Should pin |
| cloudflare-ddns | latest | latest | ✅ Acceptable |
| magicmirror | latest | latest | ✅ Acceptable (dashboard) |
| landing | 1.29 | matches nginx | ✅ Current |

## Compliance Summary

### Critical Issues (Must Fix)
1. ❌ **Vaultwarden using :latest** — Security-critical service needs version pinning
2. ❌ **Plane using :latest** — Community deployment, breaking changes likely
3. ⚠️  **Missing .env.example files** — Several services lack secret documentation

### Important Improvements
1. ⚠️  **Pin woodpecker and pihole** — Reduce unexpected breaking changes
2. ⚠️  **PostgreSQL patch level** — Check if 16.2+ has security fixes
3. ℹ️  **Health check coverage** — Some services only use container status

### Documentation Gaps
- Several services need `.env.example` files
- SSH key management for Forgejo not documented
- Backup restore procedures incomplete
- Service-specific troubleshooting guides missing

## Maintenance Priorities

### Immediate (This Week)
1. Pin vaultwarden to specific version
2. Generate all missing `.env.example` files
3. Run full validation check

### Short Term (This Month)
1. Pin pihole, woodpecker, plane versions
2. Check all services for latest stable versions
3. Update PostgreSQL to latest 16.x patch
4. Complete backup documentation

### Medium Term (This Quarter)
1. Implement automated version checking
2. Set up certificate expiration monitoring
3. Create disaster recovery playbook
4. Add centralized logging

## Notes

- All services currently operational
- Ansible migration complete (100%)
- Port registry established and documented
- Security posture good (no secrets in git, firewall configured)
- Primary concern: Version management for :latest services

