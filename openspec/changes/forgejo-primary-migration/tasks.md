## 1. Migrate Forgejo to Primary Remote

- [x] 1.1 Delete mirror repo on Forgejo via API (`DELETE /api/v1/repos/johnb/homelab-admin`)
- [x] 1.2 Re-create as regular repo via API (`POST /api/v1/user/repos`)
- [x] 1.3 Push all commits from local to Forgejo (`git push forgejo main --force`)
- [x] 1.4 Configure push mirror to GitHub (`POST /api/v1/repos/johnb/homelab-admin/push_mirrors`)

## 2. Configure Branch Protection

- [x] 2.1 Create branch protection rule on Forgejo (`enable_push: false`, `required_approvals: 0`)
- [x] 2.2 Create branch protection on GitHub (`allow_force_pushes: false`, `allow_deletions: false`)
- [x] 2.3 Update local tracking: `git branch --set-upstream-to=forgejo/main main`

## 3. Documentation

- [x] 3.1 Create `openspec/specs/git-workflow/spec.md` documenting the new workflow
- [x] 3.2 Create change record (this file)
