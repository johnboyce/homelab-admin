## Why

The repo documents Plane at `platform/plane/docker-compose.yml` using a custom compose with shared postgres/redis. The actual running deployment is the official Plane community CLI at `/srv/homelab/plane-official/` — a self-contained stack with its own internal postgres, redis, rabbitmq, and minio. This discrepancy means the repo does not accurately reflect reality, and the Ansible role may be targeting the wrong deployment.

## What Changes

- `platform/plane/docker-compose.yml` — marked as deprecated or removed (custom compose that doesn't match live deployment)
- `openspec/specs/service-inventory/spec.md` — updated to reflect actual deployment location and method
- `HOMELAB_SPEC.yml` — updated Plane service registry entry
- `platform/plane/.env.example` — verified/updated to match actual `plane.env` variables
- Ansible role for Plane — updated to manage the official deployment or documented as manual-only
- Plane images pinned (currently using `:latest`)

## Capabilities

### New Capabilities

*(none)*

### Modified Capabilities

- `service-inventory`: Plane deployment path and method corrected from custom compose to official CLI deployment.

## Impact

- No production impact — Plane continues running from `/srv/homelab/plane-official/`
- Brief Plane restart required if image pinning is applied
- Ansible role behaviour changes (targets correct deployment)
- `/etc/homelab/secrets/plane.env` relationship to official deployment's `plane.env` needs audit
