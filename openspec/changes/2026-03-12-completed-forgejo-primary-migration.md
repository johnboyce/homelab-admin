# Change: Forgejo Promoted to Primary Git Remote

**ID:** CHG-2026-001
**Date:** 2026-03-12
**Status:** completed
**Type:** migration
**Services:** forgejo, woodpecker
**Author:** johnb

## Summary

Converted the Forgejo instance from a read-only pull mirror (syncing from GitHub) to the primary git remote for `homelab-admin`. GitHub is now a push mirror destination. Branch protection enforced on both remotes. This aligns with the homelab-first philosophy — Forgejo and Woodpecker CI should be the primary development workflow tools.

## Details

Prior state:
- `origin` (GitHub) was the active push target, tracking `main`
- `forgejo` remote was a read-only pull mirror from GitHub, 25 commits behind
- No branch protection on either remote
- Woodpecker CI was not receiving commit hooks (Forgejo was stale)

New state:
- `forgejo` is the primary remote; local `main` tracks `forgejo/main`
- `origin` (GitHub) is a push mirror — Forgejo syncs automatically on every commit + every 8h
- Branch protection on Forgejo: direct pushes to `main` blocked, PRs required
- Branch protection on GitHub: force pushes and deletions blocked (no PR requirement — push mirror needs direct access)

## Implementation

1. Deleted the mirror repo on Forgejo via API (`DELETE /api/v1/repos/johnb/homelab-admin`)
2. Re-created as a regular (non-mirror) repo via API (`POST /api/v1/user/repos`)
3. Pushed all commits from local to Forgejo (`git push forgejo main --force`)
4. Configured Forgejo push mirror to GitHub via API (`POST /api/v1/repos/johnb/homelab-admin/push_mirrors`)
   - `sync_on_commit: true`, interval: `8h`
5. Created branch protection rule on Forgejo (`POST /api/v1/repos/johnb/homelab-admin/branch_protections`)
   - `enable_push: false`, `required_approvals: 0`
6. Created branch protection on GitHub via `gh api`
   - `allow_force_pushes: false`, `allow_deletions: false`
7. Updated local tracking: `git branch --set-upstream-to=forgejo/main main`

## Verification

```bash
# Confirm local tracking
git branch -vv
# Expected: * main ... [forgejo/main]

# Confirm Forgejo has latest commits
git log forgejo/main --oneline -3

# Confirm GitHub mirror receives pushes
# Make a test commit, push to forgejo, check github.com/johnboyce/homelab-admin
```

## Rollback

If Forgejo becomes unavailable, push directly to GitHub and update tracking:

```bash
git branch --set-upstream-to=origin/main main
git push origin main
```

To restore GitHub as primary permanently:
1. Set `git remote set-url origin git@github.com:johnboyce/homelab-admin.git` (already configured)
2. Update tracking to `origin/main`
3. Disable branch protection on GitHub that was added if needed via `gh api`

## Spec Updates Required

- [x] `openspec/specs/git-workflow.md` — created (documents new workflow)
- [ ] `openspec/specs/service-inventory.md` — update Forgejo entry to note primary git remote role
- [ ] `HOMELAB_SPEC.yml` — update Forgejo service entry

## Notes

- Woodpecker CI will now receive webhook events from Forgejo on push (was not working before due to stale mirror)
- Branch protection requires 0 approvals — solo repo, PRs enforce workflow discipline without blocking self-merge
- Adding `status_check_contexts` to Forgejo branch protection should be done once `.woodpecker.yml` is added
- GitHub token used for push mirror: `gho_*` (OAuth token from `gh auth token`) — if rotated, update Forgejo push mirror settings at `http://forgejo.geek/johnb/homelab-admin/settings`
