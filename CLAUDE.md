# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

**homelab-admin** is a personal homelab infrastructure repository for host `geek`. It manages Docker-based services (Authentik SSO, nginx reverse proxy, PostgreSQL, Redis) with version-controlled nginx configurations. The repository serves as the **source of truth** for desired infrastructure state.

## Core Principles (Non-Negotiable)

1. **Repository is source of truth** — Git represents desired state, the host represents runtime state
2. **Secrets never enter Git** — No passwords, tokens, private keys, or real certificates. Use `.env.example` files only
3. **Changes are reversible** — Every change must be deployable, testable, and rollback-able
4. **Clarity over cleverness** — Ask focused questions rather than guessing infrastructure decisions

## Essential Commands

### nginx Configuration

```bash
# Test nginx syntax without reloading
make nginx-test

# Test and gracefully reload nginx
make nginx-reload

# Deploy repo config to host (normal workflow: repo → host)
make nginx-deploy

# Import live config from host (emergency/bootstrap only: host → repo)
make nginx-import
```

### Authentik

```bash
# Deploy authentik upgrades to geek host
make deploy-authentik

# Inspect Authentik API (requires .env.local with API credentials)
make authentik-inspect

# Dump Authentik config snapshots (sanitized)
make authentik-config-dump

# Bootstrap BookStack OIDC integration (if required)
make bookstack-oidc-bootstrap
```

### Verification (mandatory for ingress/TLS/identity changes)

```bash
docker exec geek-nginx nginx -t
curl -Ik https://auth.johnnyblabs.com
curl -Ik https://auth.johnnyblabs.com/outpost.goauthentik.io/ping
curl -Ik https://bookstack.johnnyblabs.com
```

## Architecture Overview

### Service Stack

```
nginx (geek-nginx) — reverse proxy, TLS termination, forward auth
  ├── Authentik (identity SSO)
  ├── BookStack (wiki/docs)
  └── Other services
      └── PostgreSQL (shared data layer)
          └── Redis (optional cache, deprecated for Authentik 2025.8+)
```

- **Network**: All services run on external Docker network `geek-infra`
- **Ingress**: nginx only, no direct service port exposure
- **Domains**:
  - Internal: `*.geek` (HTTP, LAN only)
  - Public: `*.johnnyblabs.com` (HTTPS, TLS-terminated)

### nginx Configuration Model

**Key rule**: `platform/ingress/nginx/etc-nginx-docker/` is the **authoritative nginx config**.

**Current structure**: Uses `conf.d/` with numbered files (00_geek.conf, 10_auth.johnnyblabs.com.conf, etc.)
- Rationale: Explicit control over load order, clear separation of concerns
- See `platform/ingress/nginx/README.md` for detailed configuration inventory

- **Live nginx config** runs from: `/etc/nginx-docker` (on host)
- **Canonical source** in repo: `platform/ingress/nginx/etc-nginx-docker/conf.d/`
- **Sync direction** (normal): `repo → host` via `make nginx-deploy`
- **TLS certs/keys**: Live on host only (`/etc/nginx-docker/certs/`), repo contains only `.keep` placeholder
- **Legacy reference**: `sites-available/` kept for historical reference but not actively deployed

### Repository Structure

```
platform/
  ingress/nginx/
    etc-nginx-docker/        # Authoritative nginx config (mirrored from host)
      sites-available/       # Virtual host configs
      sites-enabled/         # Symlinks (managed on host, not in repo)
      certs/                 # Only .keep file; actual certs/keys on host
  authentik/                 # Authentik SSO (server, worker, outpost)
  postgres/                  # Shared PostgreSQL
  redis/                     # Shared Redis (optional)

scripts/
  nginx_import_from_host.sh  # Emergency: host → repo
  nginx_deploy_to_host.sh    # Normal: repo → host
  authentik_*.sh             # Identity-related utilities

docs/
  README.md                  # Comprehensive setup and troubleshooting
  ADMIN.md                   # Strict operational rules
  AUTHENTIK_*.md             # Identity-specific guides
  CHECKLIST.md               # Verification checklists
```

## Key Workflows

### Adding a New Service

1. Create `platform/service-name/docker-compose.yml` with `geek-infra` network
2. Add nginx vhost config in `platform/ingress/nginx/etc-nginx-docker/sites-available/`
3. Test: `make nginx-test`
4. Deploy: `make nginx-deploy`
5. Update documentation

### Adding Forward Authentication to a Service

Use `platform/ingress/nginx/etc-nginx-docker/sites-available/bookstack.geek.conf` as template:

1. Create `/_ak/auth` internal location proxying to `http://outpost-proxy:9000/outpost.goauthentik.io/auth/nginx`
2. Create `@ak_start` error handler redirecting to Authentik login
3. Add `auth_request /_ak/auth;` and `error_page 401 = @ak_start;` to protected location blocks
4. Note: OIDC callback paths (`/oidc/callback`, `/oidc/logout`) must bypass forward-auth
5. Configure provider/application in Authentik UI
6. Test end-to-end flow

### Updating nginx Configuration

1. Edit config in repo: `platform/ingress/nginx/etc-nginx-docker/`
2. Test: `make nginx-test` (tests syntax in running container)
3. Deploy: `make nginx-deploy` (tests, syncs, reloads)
4. Commit with verification commands in message

### Debugging Services

```bash
# Container logs
docker logs -f geek-nginx
docker logs -f authentik-server
docker logs -f authentik-worker
docker logs -f geek-postgres

# Database connectivity
docker exec -it geek-postgres psql -U authentik -d authentik

# Outpost connectivity from nginx
docker exec -it geek-nginx curl -I http://authentik-outpost:9000/outpost.goauthentik.io/ping
```

## Important Details

### Authentik Version

- **Current**: 2025.10.3
- **Major change (2025.8+)**: Redis dependency removed. Authentik now uses PostgreSQL for caching, tasks, WebSockets, and session store.
- **PostgreSQL impact**: ~50% more connections compared to Redis versions
- **Config**: All `AUTHENTIK_REDIS__*` environment variables removed

### File Ownership & Permissions

When deploying to host, enforce:
- Ownership: `root:root`
- Directories: `755`
- Files: `644`
- Private keys: `600`

(Handled automatically by deployment scripts)

### TLS Certificates

- **Public certificates** (`.crt`): Safe to commit (they're public)
- **Private keys** (`.key`, `.pem`): NEVER commit, keep on host only
- **Location on host**: `/etc/nginx-docker/certs/`
- **Check expiration**: `openssl x509 -in /etc/nginx-docker/certs/johnnyblabs.crt -noout -enddate`

## Common Patterns & Conventions

### nginx Snippets

- Reusable nginx configuration located in `platform/ingress/nginx/etc-nginx-docker/geek/snippets/`
- Forward-auth pattern always uses `outpost-proxy:9000` (not `authentik-server`)

### Docker Networking

- All services must connect to external network `geek-infra`
- Create network if it doesn't exist: `docker network create geek-infra`
- Services don't expose ports to host; nginx handles all ingress

### Environment Configuration

- Service `.env` files use placeholders: `.env.example` in repo
- Actual secrets only on host machine
- Authentik uses `AUTHENTIK_POSTGRESQL__HOST` (double underscore) for nested config
- Outpost token: `AUTHENTIK_OUTPOST_TOKEN` in `.env`, mapped to `AUTHENTIK_TOKEN` in container

### Verification Workflow

Before committing changes to ingress/identity/TLS:

1. Run `make nginx-test` (syntax validation)
2. Run verification `curl` commands
3. Document both tests and expected HTTP status codes in commit message
4. Include rollback procedure if applicable

## Gotchas & Anti-Patterns

- ❌ Do not manually edit `/etc/nginx-docker/` on host unless doing emergency hotfix (use `make nginx-import` afterward)
- ❌ Do not commit private keys, real `.env` files, or database data directories
- ❌ Do not create symlinks in `sites-enabled/` via repo; manage them on host
- ❌ Do not expose service ports directly; all ingress goes through nginx
- ❌ Do not use Redis-specific Authentik config after 2025.8+ (it's removed)
- ✅ Always test nginx config before deployment
- ✅ Always verify forward-auth patterns match bookstack template
- ✅ Always use HTTP 302 (not 301) for auth redirects
- ✅ Always set `X-Forwarded-Proto` to match the actual scheme (http vs https)

## When Uncertain

1. Check `ADMIN.md` for strict operational rules
2. Check `README.md` for architecture and troubleshooting
3. Review similar config files in `platform/ingress/nginx/etc-nginx-docker/sites-available/`
4. Ask one focused question rather than guessing
5. Test before committing

## Useful References

- **nginx docs**: https://nginx.org/en/docs/
- **Authentik docs**: https://goauthentik.io/docs/
- **Docker Compose**: https://docs.docker.com/compose/
- **Forward auth pattern**: See `bookstack.geek.conf` and `bookstack.johnnyblabs.com` vhosts
