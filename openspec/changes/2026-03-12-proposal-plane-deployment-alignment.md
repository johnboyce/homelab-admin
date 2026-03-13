# Change: Align Plane Deployment with Repo Spec

**ID:** CHG-2026-002
**Date:** 2026-03-12
**Status:** proposed
**Type:** migration
**Services:** plane
**Author:** johnb

## Summary

There is a discrepancy between the Plane deployment documented in the repo and the actual running instance on `geek`. The repo contains a custom `platform/plane/docker-compose.yml` but the live service uses the official Plane community CLI deployment at `/srv/homelab/plane-official/`. These need to be reconciled — either update the spec to match reality, or migrate the live service to match the repo pattern.

## Details

### Current State (Reality on geek)

- **Location:** `/srv/homelab/plane-official/deployments/cli/community/plane-app/`
- **Config:** `plane.env` in that directory (also `/etc/homelab/secrets/plane.env` exists — relationship unclear, needs audit)
- **Deployment:** Plane official community CLI (13 containers, self-contained PostgreSQL/Redis/RabbitMQ/MinIO)
- **Proxy:** `plane-app-proxy-1` container connected to `geek-infra` network
- **Admin:** `admin@plane.geek`
- **Workspace:** `homelab`, Project: `Infrastructure` (INFRA-*)
- **Images:** Using `:latest` — **HIGH RISK**

### Current State (Repo / Spec)

- **Location:** `platform/plane/docker-compose.yml`
- **Pattern:** Custom compose using shared postgres (`geek-postgres`) and shared redis
- **Ansible role:** `ansible/roles/plane/` (exists but may target wrong deployment)
- **Documented in:** `openspec/specs/service-inventory.md` as `platform/plane/docker-compose.yml`

### The Discrepancy

The live service is the **official Plane community deployment** (self-contained, opinionated, uses its own internal postgres/redis/rabbitmq/minio). The repo has a **custom compose** attempting to integrate Plane with the shared infrastructure stack — this is likely an older design that was superseded when the official community deployment was adopted.

## Options

### Option A: Update Spec to Match Reality (Recommended)

Accept the official community deployment as canonical. Update the repo to:
1. Remove/deprecate `platform/plane/docker-compose.yml` (custom compose)
2. Add reference config/docs pointing to `/srv/homelab/plane-official/` on geek
3. Update `openspec/specs/service-inventory.md` to reflect actual deployment
4. Update `HOMELAB_SPEC.yml` service entry
5. Pin Plane images (currently `:latest`)
6. Add Ansible role that manages the official deployment (or documents manual process)

### Option B: Migrate Live to Match Repo Pattern

Migrate Plane to use shared postgres/redis, removing the self-contained deployment. More complex, higher risk, and fights Plane's official deployment design.

**Recommendation: Option A** — Aligning the spec with reality is lower risk and respects Plane's intended deployment model.

## Impact

- No production impact (purely documentation + spec alignment)
- If version pinning is added as part of this: brief Plane restart required
- Ansible role needs updating regardless

## Implementation (Option A)

- [ ] Audit `/srv/homelab/plane-official/` structure on geek (document fully)
- [ ] Clarify relationship between `/etc/homelab/secrets/plane.env` and the deployment's own `plane.env` — are they the same file, a symlink, or duplicate?
- [ ] Determine current Plane version running on geek
- [ ] Update `platform/plane/docker-compose.yml` to note it is deprecated/reference-only, or remove it
- [ ] Update `openspec/specs/service-inventory.md` Plane entry with correct deployment path
- [ ] Update `HOMELAB_SPEC.yml` Plane service entry
- [ ] Pin Plane images to current version in `plane.env`
- [ ] Update Ansible role to manage the official deployment (or document manual-only)

## Verification

```bash
# Check running Plane containers on geek
ssh johnb@geek "docker ps | grep plane"

# Check current Plane version
ssh johnb@geek "docker inspect plane-app-api-1 | jq '.[0].Config.Image'"

# Verify proxy container is connected to geek-infra
ssh johnb@geek "docker network inspect geek-infra | jq '.[0].Containers | keys'"
```

## Rollback

No rollback needed — this is a spec/documentation change only (unless version pinning triggers issues, which would be reverted by restoring `:latest` in `plane.env`).

## Spec Updates Required

- [ ] `openspec/specs/service-inventory.md` — correct Plane deployment path and status
- [ ] `HOMELAB_SPEC.yml` — update Plane service registry entry
- [ ] `platform/plane/docker-compose.yml` — add deprecation notice or remove
- [ ] `platform/plane/.env.example` — verify it matches actual `plane.env` vars

## Notes

- Plane update gotcha: always use `--env-file plane.env` — no `.env` file exists; docker compose defaults `LISTEN_HTTP_PORT=80` which conflicts with nginx
- `/etc/homelab/secrets/plane.env` exists (334 bytes, updated Mar 7) — but it's unclear whether the official deployment reads from here or from the `plane.env` in its own directory. Audit required.
- Note: `/etc/homelab/secrets/` is `drwx------ root root` — SSH checks as `johnb` will falsely report files as missing. Always use `sudo` to inspect secrets.
