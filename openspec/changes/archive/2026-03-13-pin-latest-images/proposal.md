## Why

Six services in the homelab stack use `:latest` image tags, creating uncontrolled upgrade risk — a Docker pull could silently introduce breaking changes or regressions with no record of what changed. Vaultwarden (password manager) and Plane (project management) are particularly high risk. Pinning versions gives explicit control over when upgrades happen and makes rollback straightforward.

## What Changes

- `platform/vaultwarden/docker-compose.yml` — pin `vaultwarden/server` to a specific version
- `platform/woodpecker/docker-compose.yml` — pin `woodpecker-server` and `woodpecker-agent` to a specific version
- `platform/pihole/docker-compose.yml` — pin `pihole/pihole` to a specific version
- `platform/ollama/docker-compose.yml` — pin `ollama/ollama` to a specific version
- `platform/cloudflare-ddns/docker-compose.yml` — pin `oznu/cloudflare-ddns` (or equivalent) to a specific version
- `openspec/specs/service-inventory.md` — update version policy column for all affected services
- `HOMELAB_SPEC.yml` — update version matrix for all affected services

Note: Plane image pinning is deferred — Plane uses the official community CLI deployment and version management is handled differently (tracked in CHG-2026-002).

## Capabilities

### New Capabilities

- `version-management`: Standards and current pinned versions for all homelab service images. Covers which services are pinned, at what version, and the policy for updating them.

### Modified Capabilities

- `infrastructure-standards`: Version pinning requirement strengthened — all services except stateless utilities must pin to a specific version (not `:latest`).

## Impact

- **Vaultwarden**: Requires identifying current running version before pinning; brief restart to apply
- **Woodpecker**: Server + agent must be pinned to the same version; restart required
- **Pi-hole**: DNS service — restart causes brief DNS outage (~5s); LAN clients reconnect automatically
- **Ollama**: AI inference service — no critical dependency; safest to pin
- **Cloudflare DDNS**: Stateless utility; minimal risk
- **No nginx or auth impact** — all services remain on `geek-infra` network, no proxy changes needed
