## Why

Forgejo was configured as a read-only pull mirror from GitHub, leaving it 25 commits behind and preventing Woodpecker CI from receiving commit webhooks. Promoting Forgejo to primary aligns with the homelab-first philosophy — all CI/CD should run on local infrastructure, with GitHub as a backup mirror.

## What Changes

- Forgejo repo converted from pull-mirror to regular repo (deleted and recreated via API)
- All commits pushed from local to Forgejo (`git push forgejo main --force`)
- Forgejo push mirror configured to sync automatically to GitHub on every commit + every 8h
- Branch protection enabled on Forgejo: direct pushes to `main` blocked, PRs required
- Branch protection enabled on GitHub: force pushes and deletions blocked
- Local `main` branch tracking changed from `origin/main` to `forgejo/main`

## Capabilities

### New Capabilities

- `git-workflow`: Defines Forgejo as primary remote, GitHub as mirror, branch protection rules, and PR-based development workflow.

### Modified Capabilities

*(none — git workflow is a new capability)*

## Impact

- Local pushes must now target `forgejo` remote (not `origin`)
- PRs must be created and merged on Forgejo, not GitHub
- GitHub automatically receives all commits via push mirror
- Woodpecker CI now receives webhooks from Forgejo on every push
