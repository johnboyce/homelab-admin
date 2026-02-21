# Ansible Migration Status

This file tracks progress of migrating from shell scripts to Ansible-based infrastructure as code.

## Progress Overview

| Component | Status | Since | Notes |
|-----------|--------|-------|-------|
| **Infrastructure** | | | |
| Ansible foundation | ✓ Done | 2026-02-21 | Playbooks, roles, vars structure in place |
| Port registry | ✓ Done | 2026-02-21 | `group_vars/all.yml` - single source of truth |
| **Firewall** | | | |
| UFW automation | ✓ Done | Previous session | `scripts/setup_firewall.sh` |
| Ansible firewall role | ✓ Done | 2026-02-21 | `roles/firewall/tasks/main.yml` idempotent |
| Firewall dry-run test | ⧗ Pending | | `make ansible-dry-run` |
| **nginx** | | | |
| nginx deployment script | ✓ Done | Previous session | `scripts/nginx_deploy_to_host.sh` |
| Ansible nginx role | ✓ Done | 2026-02-21 | `roles/nginx/tasks/main.yml` with sync + reload |
| nginx config sync test | ⧗ Pending | | `make ansible-nginx --check` |
| **Docker Services** | | | |
| docker_infra network | ✓ Done (stub) | 2026-02-21 | `roles/docker_infra/tasks/main.yml` |
| PostgreSQL | ✓ Done (stub) | 2026-02-21 | `roles/postgres/tasks/main.yml` - Phase 5 |
| Authentik | ✓ Done (stub) | 2026-02-21 | `roles/authentik/tasks/main.yml` - Phase 5 |
| **Documentation** | | | |
| Ansible section in CLAUDE.md | ⧗ Pending | | Update agent guidance |
| homelab_status.sh Ansible info | ⧗ Pending | | Add managed components display |

## What Was Done Before This Session

- ✓ nginx deployment script (`scripts/nginx_deploy_to_host.sh`)
  - OS-aware (macOS/Linux/geek host)
  - Handles tar+SSH deployment
  - Tests and reloads nginx in container

- ✓ Firewall automation (`scripts/setup_firewall.sh`)
  - UFW rules for all services
  - LAN-only segmentation
  - Safety checks

- ✓ PostgreSQL backup system (`scripts/backup_postgresql.sh`)
  - Backup/restore/list operations
  - Disaster recovery procedures

- ✓ Service status dashboard (`scripts/homelab_status.sh`)
  - Shows running containers
  - Service accessibility (LAN vs Internet)
  - Health checks

- ✓ Comprehensive documentation
  - FIREWALL.md - firewall rules and management
  - BACKUP.md - backup procedures
  - README.md with Make targets and documentation index

## What This Session (Ansible Migration) Added

- ✓ Ansible 13.3.0 installed (via Homebrew)
- ✓ Collections installed (community.general, community.docker)
- ✓ Ansible directory structure (`ansible/` directory)
- ✓ ansible.cfg - connection configuration
- ✓ inventory/hosts.ini - geek host definition
- ✓ requirements.yml - collection dependencies
- ✓ group_vars/all.yml - **Port Registry** (single source of truth for all ports)
- ✓ Playbooks:
  - site.yml - full convergence
  - status.yml - read-only facts gathering
  - firewall.yml - firewall only
  - nginx.yml - nginx config only
  - docker.yml - docker services
- ✓ Roles (Phase-based):
  - firewall role - idempotent UFW rules from port registry
  - nginx role - config sync with handlers
  - docker_infra role - network management
  - postgres role - stub for Phase 5
  - authentik role - stub for Phase 5
- ✓ Makefile targets:
  - ansible-install
  - ansible-status (working ✓)
  - ansible-dry-run
  - ansible-firewall
  - ansible-nginx

## Phased Implementation Plan

### Phase 1: Foundation ✓ COMPLETE
- [x] Ansible installation and configuration
- [x] Directory structure
- [x] Port registry in group_vars
- [x] Connectivity test with status.yml

### Phase 2: Firewall (Ready for Testing)
- [x] Firewall role with UFW tasks
- [ ] Dry-run test: `make ansible-dry-run --tags firewall`
- [ ] Compare output against current `ufw status numbered`
- [ ] Apply: `make ansible-firewall`

### Phase 3: nginx Config (Ready for Testing)
- [x] nginx role with config sync
- [x] Handlers for test+reload
- [ ] Dry-run test: `make ansible-dry-run --tags nginx`
- [ ] Apply: `make ansible-nginx`
- [ ] Verify with: `make nginx-test`

### Phase 4: Docker Infrastructure (Ready)
- [x] docker_infra role for geek-infra network
- [ ] Test: `make ansible-dry-run --tags docker`

### Phase 5: Service Management (Stubs Ready)
- [x] postgres role (stub - uncomment when ready)
- [x] authentik role (stub - uncomment when ready)
- [ ] To activate: uncomment docker_compose_v2 tasks
- [ ] Test with --check mode first

## Key Design Decisions

1. **Port Registry** (`group_vars/all.yml`)
   - All ports defined in one place
   - Referenced by firewall rules, nginx configs, docker-compose templates
   - Eliminates port management hell

2. **Coexistence Not Replacement**
   - Roles use `state: present` not `state: restarted`
   - Dry-run (`--check --diff`) validates before applying
   - Can run alongside existing shell scripts

3. **Tag-Based Execution**
   - `bootstrap` - initial setup (enable UFW, create network)
   - `config` - configuration updates (rules, files)
   - `lifecycle` - service start/stop (phase 5+)

4. **Idempotency**
   - Run twice → no changes on second run
   - Verified with `--check` before apply
   - UFW module handles rule deduplication

## Testing Checklist

Before marking a phase complete:

- [ ] Run `make ansible-dry-run --tags [phase]` and review output
- [ ] Run `make ansible-[phase]` to apply
- [ ] Verify services still running (if applicable)
- [ ] Run `make ansible-status` to confirm facts updated
- [ ] Run playbook twice → second run shows `changed=0`

## Migration Completion Criteria

- All 5 phases tested and applied
- `make homelab-status` shows Ansible-managed components
- Disaster recovery playbook exists and tested
- All shell scripts either replaced or deprecated in comments
- Documentation updated in CLAUDE.md
- No manual configuration on geek host outside Ansible

## Next Steps

1. Test Phase 2 firewall:
   ```bash
   make ansible-dry-run --tags firewall
   # Review output, compare to: ssh johnb@geek sudo ufw status numbered
   make ansible-firewall
   ```

2. Test Phase 3 nginx:
   ```bash
   make ansible-dry-run --tags nginx --diff
   make ansible-nginx
   make nginx-test  # Fallback shell script still works
   ```

3. Create final progress report and disaster recovery playbook
