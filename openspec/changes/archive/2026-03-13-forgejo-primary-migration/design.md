## Context

Prior state: `origin` (GitHub) was the active push target. `forgejo` was a read-only pull mirror, 25 commits behind, with Woodpecker CI receiving no webhooks.

New state: Forgejo is primary. GitHub is a push mirror destination. All development flows through Forgejo → GitHub automatically.

## Goals / Non-Goals

**Goals:**
- Forgejo as primary remote with branch protection
- GitHub as automated push mirror (backup + public visibility)
- Woodpecker CI receives webhooks on every push

**Non-Goals:**
- Migrating CI pipelines (no `.woodpecker.yml` exists yet)
- Changing any service deployments

## Decisions

**Decision: Delete and recreate Forgejo repo rather than un-mirror via API**

Forgejo's API does not support converting a mirror repo to a regular repo via PATCH. Deleting and recreating is the only API-supported path.

**Decision: Use `sync_on_commit: true` for the push mirror**

Ensures GitHub is updated immediately on every push, not just on the 8h interval. GitHub remains a near-real-time mirror.

**Decision: 0 required approvals on Forgejo branch protection**

Solo repo. PRs enforce workflow discipline (no direct main pushes) without blocking self-merge.

## Risks / Trade-offs

**[Risk] Forgejo outage breaks push workflow** → Mitigation: GitHub remote (`origin`) remains configured locally. If Forgejo is unavailable, temporarily push to `origin` and update tracking.

**[Risk] GitHub token for push mirror expires** → Mitigation: Token is from `gh auth token` (OAuth). If rotated, update at `http://forgejo.geek/johnb/homelab-admin/settings`.

## Migration Plan

1. DELETE repo on Forgejo via API
2. POST new regular repo on Forgejo via API
3. Force push all commits: `git push forgejo main --force`
4. POST push mirror config pointing to GitHub with token
5. POST branch protection rule on Forgejo (`enable_push: false`)
6. PUT branch protection on GitHub (`allow_force_pushes: false`, `allow_deletions: false`)
7. Update local tracking: `git branch --set-upstream-to=forgejo/main main`

**Status: Completed 2026-03-12**

## Open Questions

None — fully implemented.
