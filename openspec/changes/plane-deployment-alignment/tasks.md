## 1. Audit Plane Deployment on Geek

- [ ] 1.1 Document full structure of `/srv/homelab/plane-official/` on geek
- [ ] 1.2 Determine current Plane version running (`docker inspect plane-app-api-1 | jq '.[0].Config.Image'`)
- [ ] 1.3 Clarify relationship between `/etc/homelab/secrets/plane.env` and `/srv/homelab/plane-official/.../plane.env` — same file, symlink, or duplicate?

## 2. Update Repo to Match Reality

- [ ] 2.1 Add deprecation notice to `platform/plane/docker-compose.yml` or remove it
- [ ] 2.2 Update `platform/plane/.env.example` to match actual `plane.env` variables
- [ ] 2.3 Update `openspec/specs/service-inventory/spec.md` Plane entry with correct deployment path and method
- [ ] 2.4 Update `HOMELAB_SPEC.yml` Plane service registry entry

## 3. Pin Plane Images

- [ ] 3.1 Identify current Plane image versions from running containers
- [ ] 3.2 Pin images in the official deployment's `plane.env` or compose override
- [ ] 3.3 Restart Plane to apply pinned versions and verify

## 4. Update Ansible Role

- [ ] 4.1 Review `ansible/roles/plane/tasks/main.yml` — determine if it targets the correct deployment
- [ ] 4.2 Update role to manage the official CLI deployment, or document that Plane is manually managed
- [ ] 4.3 Run `make ansible-dry-run --tags plane` to verify role is idempotent
