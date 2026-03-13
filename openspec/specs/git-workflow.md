# Git Workflow Specification

## Overview

This document defines the git workflow for the `homelab-admin` repository. All infrastructure changes follow this workflow to maintain auditability, reversibility, and quality gates.

## Repository Architecture

```
Forgejo (primary)  ──push mirror──►  GitHub (mirror)
     │                                     │
  PRs/CI here                        read-only backup
     │
  Woodpecker CI
```

- **Primary:** `forgejo` remote — `http://forgejo.geek/johnb/homelab-admin`
- **Mirror:** `origin` remote — `https://github.com/johnboyce/homelab-admin`
- **Sync:** Forgejo push mirror syncs to GitHub on every commit + every 8 hours
- **Local tracking:** `main` tracks `forgejo/main`

## Branch Protection

### Forgejo (enforced)
- Direct pushes to `main` are **blocked**
- All changes must go through a PR
- When Woodpecker CI is configured: status checks must pass before merge

### GitHub (enforced)
- Force pushes to `main` are **blocked**
- Branch deletion is **blocked**
- No PR requirement (push mirror needs direct push access)

## Branch Naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/<short-description>` | `feat/add-vaultwarden` |
| Fix | `fix/<short-description>` | `fix/nginx-proxy-headers` |
| Docs | `docs/<short-description>` | `docs/update-firewall-guide` |
| Chore | `chore/<short-description>` | `chore/pin-woodpecker-version` |
| OpenSpec | `spec/<short-description>` | `spec/git-workflow` |

Rules:
- Lowercase, hyphenated
- Short and descriptive (3–5 words max after prefix)
- No ticket numbers (not needed for solo homelab)

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short summary>

[optional body]

[optional footer]
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### Types

| Type | Use for |
|------|---------|
| `feat` | New service, new feature |
| `fix` | Bug fix, misconfiguration correction |
| `chore` | Version bumps, dependency updates |
| `docs` | Documentation only |
| `spec` | OpenSpec additions or updates |
| `refactor` | Restructuring without behaviour change |
| `ci` | Woodpecker pipeline changes |

### Examples

```
feat: add vaultwarden password manager service

fix: set correct X-Forwarded-Proto header in bookstack proxy

chore: pin woodpecker to v3.1.0

spec: add git workflow specification

ci: add ansible lint check to woodpecker pipeline
```

## PR Workflow

### Standard Flow

```
1. Create feature branch
   git checkout -b feat/my-change

2. Make changes (follow conventions in CLAUDE.md)

3. Test locally
   make nginx-test         # if nginx changes
   make ansible-dry-run    # if ansible changes

4. Push to Forgejo
   git push forgejo feat/my-change

5. Open PR at http://forgejo.geek/johnb/homelab-admin
   - Title: mirrors commit message format
   - Description: what changed, why, how to verify, rollback procedure

6. Review & merge on Forgejo
   - Forgejo auto-mirrors to GitHub within seconds
```

### PR Description Template

```markdown
## What
Brief description of the change.

## Why
Reason for the change (links to issue or context).

## How to verify
- [ ] Step 1
- [ ] Step 2

## Rollback
How to revert if needed.
```

### Hotfix Flow (emergency)

For urgent fixes that can't wait for a full PR review:

```
1. Make fix directly on host (document what you did)
2. Capture state back to repo
   make nginx-import     # for nginx changes
3. Commit with hotfix: prefix
   git commit -m "fix: emergency hotfix - <description>"
4. Push to Forgejo (you must still merge via PR — create PR immediately)
5. Open and self-merge PR with justification in description
```

## Woodpecker CI (planned)

Once `.woodpecker.yml` is added to the repo, the pipeline will:

- Validate nginx config syntax
- Lint Ansible playbooks (`ansible-lint`)
- Check for secrets accidentally committed
- Validate `.env.example` files are present for all services
- Run `./scripts/validate_homelab.sh` in check mode

Branch protection will be updated to require CI pass before merge.

See `openspec/specs/ci-pipeline.md` (to be created) for pipeline spec.

## OpenSpec Change Tracking

All service changes — not just code — should be accompanied by an openspec change record in `openspec/changes/`. See `openspec/changes/README.md` for format.

The convention is:
- Proposals use branch `spec/<description>` and a change record in `proposed` status
- Completed changes archive to `openspec/changes/archive/`
- The `openspec/specs/service-inventory.md` and `HOMELAB_SPEC.yml` are updated to reflect completed changes

## Compliance

Changes touching the following areas require corresponding openspec updates:

| Area changed | Spec to update |
|-------------|---------------|
| New service added | `service-inventory.md`, `HOMELAB_SPEC.yml` |
| Port added/changed | `ansible/inventory/group_vars/all.yml` + `compliance-validation.md` |
| Security pattern changed | `infrastructure-standards.md` |
| New Ansible role | `service-inventory.md` |
| Version pinned/updated | `service-inventory.md` version table |
| nginx pattern changed | `infrastructure-standards.md` |
