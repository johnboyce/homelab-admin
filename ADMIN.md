# ADMIN.md — Homelab Admin Repository

This repository defines the **desired state** of my homelab platform running on host `geek`.

It is intentionally opinionated.

---

## Core Principles (Non-Negotiable)

1. **This repo is the source of truth**
    - Git represents *desired state*
    - The host represents *runtime state*

2. **Secrets never enter Git**
    - No real passwords, tokens, private keys, or live certs
    - `.env.example` files only
    - Cert folders may exist, but contain placeholders only

3. **Changes must be reversible**
    - Every change must be deployable, testable, and rollback-able

4. **Clarity beats cleverness**
    - If unsure, ask one focused question
    - Do not guess or invent infrastructure

---

## Repository Layout (Intentional)

```
platform/
  ingress/nginx/
    etc-nginx-docker/        # Canonical nginx config (repo-managed)
  identity/authentik/
    docker-compose.yml
    custom-templates/
    media/
  data/
    postgres/
    redis/

apps/
  bookstack/
  casaos/
  cockpit/

scripts/
  nginx_import_from_host.sh   # bootstrap / emergency capture
  nginx_deploy_to_host.sh     # normal workflow (repo → host)

docs/
  runbooks/
  troubleshooting/
```

### Key rule
> `platform/ingress/nginx/etc-nginx-docker` is the **authoritative nginx config**.

---

## Nginx & Ingress Model

- **Live nginx config** runs from:
  ```
  /etc/nginx-docker
  ```

- **Canonical nginx config** lives in this repo at:
  ```
  platform/ingress/nginx/etc-nginx-docker
  ```

- **TLS certs and private keys**
    - Live only on host under `/etc/nginx-docker/certs`
    - Repo contains `certs/.keep` only
    - Never commit `.key`, `.pem`, `.crt`, `.p12`, `.pfx`

---

## Sync Direction (IMPORTANT)

### Default (normal work)
```
repo → host
```

- Edit files in the repo
- Deploy using:
  ```
  make nginx-deploy
  ```
- Validate and reload nginx

### Exception (emergency only)
```
host → repo
```

- Used only if an urgent hotfix was made directly on the server
- Captured via:
  ```
  make nginx-import
  ```
- Must be followed by review + commit

> Host → repo is **not** the normal workflow.

---

## Scripts (Single Responsibility)

- `scripts/nginx_import_from_host.sh`
    - One-time bootstrap or emergency drift capture
    - Excludes all cert material

- `scripts/nginx_deploy_to_host.sh`
    - Deploys repo config to `/etc/nginx-docker`
    - Normalizes ownership and permissions
    - Runs `nginx -t` and reloads container

Makefile targets must call scripts — **no duplicate rsync logic**.

---

## File Ownership & Permissions

When deploying repo → host:

- Ownership: `root:root`
- Directories: `755`
- Files: `644`
- Private keys (host only): `600`

Deployment scripts must explicitly enforce this.

---

## Authentik & Identity

- Authentik runs via Docker Compose
- Uses shared Postgres
- External access via nginx + Authentik Outpost
- Public base URL:
  ```
  https://auth.johnnyblabs.com
  ```

Any change to identity or ingress **must** include:
- Updated docs
- Verification commands
- Expected HTTP status codes

---

## Verification Requirements (Mandatory)

Every change affecting ingress, TLS, or identity must document and pass:

```bash
docker exec geek-nginx nginx -t
curl -Ik https://auth.johnnyblabs.com
curl -Ik https://auth.johnnyblabs.com/outpost.goauthentik.io/ping
curl -Ik https://bookstack.johnnyblabs.com
```

---

## If Uncertain

- Ask **one focused question**
- Do not invent infrastructure
- Do not commit “just in case” files
- Prefer explicit failure over silent success

---

## For Automation / Copilot Agents

- Never commit secrets or cert material
- Treat repo as desired state
- Default to repo → host workflows
- Use existing scripts; do not duplicate logic
- Favor explicit, readable changes over abstraction
