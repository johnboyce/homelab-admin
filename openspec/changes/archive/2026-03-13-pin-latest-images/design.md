## Context

Six services currently use `:latest` image tags. Versions were audited on 2026-03-12 by checking both running container labels (`docker inspect`) and Docker Hub latest stable tags. The strategy: pin each service to its currently-running version unless a safe minor/patch upgrade is available, in which case upgrade at pin time. Woodpecker's v2→v3 major jump is deferred to a separate change.

| Service | Image | Running | Latest Stable | Action |
|---------|-------|---------|--------------|--------|
| vaultwarden | `vaultwarden/server` | `1.35.4` | `1.35.4` | Pin as-is |
| woodpecker server | `woodpeckerci/woodpecker-server` | `2.8.3` | `v3.13.0` | Pin to `2.8.3` (major jump deferred) |
| woodpecker agent | `woodpeckerci/woodpecker-agent` | `2.8.3` | `v3.13.0` | Pin to `2.8.3` (major jump deferred) |
| pihole | `pihole/pihole` | `2025.11.1` | `2026.02.0` | Upgrade to `2026.02.0` |
| ollama | `ollama/ollama` | `0.16.3` | `0.17.7` | Upgrade to `0.17.7` |
| cloudflare-ddns | `favonia/cloudflare-ddns` | `1.15.1` | `1.15.1` | Pin as-is |

## Goals / Non-Goals

**Goals:**
- Eliminate all `:latest` tags across the stack
- Upgrade pihole and ollama to latest stable while pinning
- Pin vaultwarden, woodpecker, cloudflare-ddns to currently-running versions
- Update service-inventory.md and HOMELAB_SPEC.yml to reflect pinned policy
- Establish the pattern: all future upgrades go through an openspec change

**Non-Goals:**
- Woodpecker v2→v3 upgrade (major version, breaking changes, separate change required)
- Plane version pinning (deferred to CHG-2026-002)
- Changing deployment method or configuration for any service

## Decisions

**Decision: Upgrade pihole and ollama to latest stable at pin time**

Both are only one minor/patch release behind with no breaking changes. Pinning to an older version would require a follow-up change immediately. Low risk: Pi-hole is DNS-only, Ollama is stateless inference.

**Decision: Defer Woodpecker v3 upgrade**

v2.8.3 → v3.13.0 is a major version jump. The Woodpecker v3 series introduced breaking changes to the agent configuration and pipeline syntax. This requires its own change with release notes review and pipeline migration testing.

**Decision: Update docker-compose.yml files only (not Ansible roles)**

Version tags live in `docker-compose.yml`. Ansible roles reference the compose files — no role changes needed. Each role will pull the new tag on next deploy.

**Decision: Woodpecker server and agent must share the same version**

Woodpecker server and agent communicate via gRPC; version mismatch causes agent disconnection. Both pinned to `2.8.3` together.

## Risks / Trade-offs

**[Risk] Pihole 2026.02.0 introduces regressions** → Mitigation: Pi-hole uses date-based releases with a conservative release cycle. Brief DNS outage (~5s) on restart; LAN clients reconnect automatically. Rollback: revert tag and redeploy.

**[Risk] Ollama 0.17.7 changes model API behaviour** → Mitigation: Ollama is used for local inference only; no production dependencies. Rollback: revert tag and redeploy, models are stored in a persistent volume and are unaffected.

**[Risk] Woodpecker agent loses in-flight CI jobs on restart** → Mitigation: Restart server first, then agent. No CI jobs expected at time of change.

## Migration Plan

For each service:
1. Update `image:` tag in `docker-compose.yml`
2. Deploy via Ansible: `make ansible-apply ARGS="--tags <service>"`
3. Verify service healthy (see tasks.md for exact commands)

Rollback per service: revert `image:` tag in `docker-compose.yml` and redeploy. Pihole and ollama rollback restores the previous image from Docker Hub cache.

## Open Questions

None — all versions confirmed, upgrade decisions made.
