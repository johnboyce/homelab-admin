# Consolidation Roadmap: geek-infra → homelab-admin

## Objective

Make `homelab-admin` the **single source of truth** for all infrastructure configuration on the `geek` host. Gradually deprecate `geek-infra` once all services are verified under Ansible control.

---

## Status: Phase 5 Consolidation Complete

### Services Consolidated ✅

| Service | Status | Source | Path | Managed By |
|---------|--------|--------|------|------------|
| **PostgreSQL** | Consolidated | geek-infra → homelab-admin | `/home/johnb/homelab-admin/platform/postgres/` | Ansible (docker_compose_v2) |
| **Authentik** | Consolidated | geek-infra → homelab-admin | `/home/johnb/homelab-admin/platform/authentik/` | Ansible (docker_compose_v2) |
| **nginx** | Already in repo | homelab-admin | `/home/johnb/homelab-admin/platform/ingress/nginx/` | Ansible (synchronize + handlers) |
| **Redis** | TBD | Optional (removed in Authentik 2025.8+) | N/A | Manual |
| **CasaOS** | Native Service | Native Ubuntu system service | N/A | Manual (systemctl) |

---

## Consolidation Timeline

### ✅ Phase 5 (In Progress)

**Completed tasks:**
1. ✅ Copied postgres/docker-compose.yml from `/home/johnb/geek-infra/postgres/` to `/home/johnb/homelab-admin/platform/postgres/`
2. ✅ Copied authentik/docker-compose.yml from `/home/johnb/geek-infra/authentik/` to `/home/johnb/homelab-admin/platform/authentik/`
3. ✅ Copied authentik/.env from geek-infra to homelab-admin/platform/authentik/
4. ✅ Updated ansible/roles/postgres/tasks/main.yml to reference homelab-admin paths
5. ✅ Updated ansible/roles/authentik/tasks/main.yml to reference homelab-admin paths
6. ✅ Tested consolidated setup with `make ansible-dry-run ARGS='--tags postgres,authentik'` (passing)

**Next steps:**
- [ ] Apply Phase 5 with `make ansible-apply` (requires user approval)
- [ ] Verify services remain healthy after switch
- [ ] Update status playbook to confirm Ansible-managed state

---

## Migration Path

### Immediate (This session)

1. **Switch service control to homelab-admin paths** ✅
   - Ansible roles now reference `/home/johnb/homelab-admin/platform/postgres/` and `/authentik/`
   - docker_compose_v2 module manages services from consolidated location

2. **Next: Full-stack testing** (pending user approval)
   ```bash
   make ansible-dry-run              # Full system check (all phases 1-5)
   make ansible-apply                # Apply if all checks pass
   ```

### Transition (Future Sessions)

3. **Monitor dual setup** (geek-infra still exists, but dormant)
   - Services now run from homelab-admin
   - geek-infra/ remains as backup snapshot
   - Document procedure to rollback to geek-infra if needed

4. **Verify CasaOS integration**
   - CasaOS is native system service (`systemctl status casaos`)
   - Not managed by Ansible (design decision: native services stay native)
   - Document in architecture docs

5. **Sunset geek-infra** (after 2-3 weeks of stable operation)
   - Archive: `tar czf geek-infra-backup-$(date +%Y%m%d).tar.gz /home/johnb/geek-infra/`
   - Document any manual step-by-step procedures
   - Remove if all services remain stable under Ansible

---

## Architecture Decision: Why This Matters

### Before (Scattered)
- Services run from multiple locations
- Repo ≠ runtime state
- No disaster recovery path
- Port management across 3 files (firewall, nginx, docker-compose)

### After (Consolidated)
- **Single repo source of truth:** homelab-admin
- **Idempotent automation:** Ansible manages all services
- **Disaster recovery ready:** Clone repo, run playbooks, services restore
- **Port registry:** ansible/group_vars/all.yml referenced by all components

---

## Key Files Modified This Session

| File | Change |
|------|--------|
| `platform/postgres/docker-compose.yml` | Copied from geek-infra (source of truth) |
| `platform/authentik/docker-compose.yml` | Copied from geek-infra, updated paths |
| `platform/authentik/.env` | Copied from geek-infra (secrets, gitignored) |
| `ansible/roles/postgres/tasks/main.yml` | Updated paths: geek-infra → homelab-admin |
| `ansible/roles/authentik/tasks/main.yml` | Updated paths: geek-infra → homelab-admin |

---

## Verification Checklist

Before fully sunsetting geek-infra:

- [ ] Full system idempotency test: `make ansible-dry-run` shows no diffs on 2nd run
- [ ] postgres: `docker exec geek-postgres psql -U postgres -d postgres -c "SELECT version();"` works
- [ ] authentik: `curl -I http://192.168.1.187:9000` returns 200
- [ ] authentik worker: `docker logs authentik-worker` shows no errors
- [ ] nginx: `docker logs geek-nginx` shows clean reload
- [ ] services survive host reboot: Infrastructure persists with correct state
- [ ] Configuration changes work: Edit nginx conf → `make ansible-nginx` syncs correctly

---

## Rollback Procedure (if needed)

If consolidation causes issues:

```bash
# Option 1: Revert to geek-infra (quick, temporary)
docker-compose -f /home/johnb/geek-infra/postgres/docker-compose.yml down
docker-compose -f /home/johnb/geek-infra/postgres/docker-compose.yml up -d

# Option 2: Git revert (permanent fix)
git revert <commit-hash>
make ansible-apply
```

---

## Future Enhancements

### Phase 6: Disaster Recovery Playbook

Bare-metal recovery playbook to restore from scratch:
1. Provision geek host (OS, users, sudo, SSH keys)
2. Clone homelab-admin repo
3. Run `make ansible-install && make ansible-apply`
4. Verify all services running
5. Restore secrets (.env files) from secure backup

### Phase 7: CasaOS Integration (Optional)

Document native service management pattern:
- CasaOS runs via systemctl, not Docker
- Can be monitored/restarted via Ansible with systemd module
- Separate playbook if/when management is needed

### Phase 8: Multi-Environment Expansion

Template support for multiple homelabs:
- `ansible/inventory/hosts.ini` can list multiple hosts
- `ansible/group_vars/geek.yml` for host-specific overrides
- Single playbook applies to all homelabs

---

## Maintenance Notes

### When adding new services:

1. Create service directory: `platform/service-name/`
2. Add docker-compose.yml to repo
3. Create Ansible role: `ansible/roles/service-name/`
4. Add port to `ansible/inventory/group_vars/all.yml`
5. Update firewall rules in ansible/roles/firewall/tasks/main.yml
6. Add to site.yml playbook

### When updating service versions:

1. Edit `platform/service-name/docker-compose.yml`
2. Test: `make ansible-dry-run ARGS='--tags service-name'`
3. Apply: `make ansible-apply ARGS='--tags service-name'`
4. Verify: Check service logs and connectivity

---

## References

- **CLAUDE.md** — Project principles and workflows
- **ADMIN.md** — Operational rules and constraints
- **ansible/STATUS.md** — Ansible phase progress
- **ansible/ansible.cfg** — Ansible configuration
- **ansible/inventory/group_vars/all.yml** — Port registry (single source of truth)
