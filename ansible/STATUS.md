# Ansible Migration Status

This file tracks progress of migrating from shell scripts to Ansible-based infrastructure as code.

## Progress Overview

| Component | Status | Since | Notes |
|-----------|--------|-------|-------|
| **Infrastructure** | | | |
| Ansible foundation | ✓ Done | 2026-02-21 | Playbooks, roles, vars structure in place |
| Port registry | ✓ Done | 2026-02-21 | `group_vars/all.yml` - single source of truth |
| **Firewall** | | | |
| UFW automation | ✓ Done | 2026-02-21 | Ansible `roles/firewall` — idempotent |
| Forgejo SSH rule (222/tcp) | ✓ Done | 2026-02-22 | LAN-only, added to port registry |
| **nginx** | | | |
| Ansible nginx role | ✓ Done | 2026-02-21 | Config sync + reload handler |
| Health check fix | ✓ Done | 2026-02-26 | `Host: geek` header + `/healthz` endpoint; `meta: flush_handlers` before check |
| **Docker Services** | | | |
| docker_infra network | ✓ Done | 2026-02-21 | `roles/docker_infra` — geek-infra network |
| landing | ✓ Done | 2026-02-22 | `roles/landing` |
| PostgreSQL | ✓ Done | 2026-02-21 | `roles/postgres` |
| Authentik | ✓ Done | 2026-02-21 | `roles/authentik` |
| BookStack | ✓ Done | 2026-02-22 | `roles/bookstack` |
| Pi-hole | ✓ Done | 2026-02-22 | `roles/pihole` — dnsmasq conf deployed |
| Cloudflare DDNS | ✓ Done | 2026-02-22 | `roles/cloudflare_ddns` |
| Plane | ✓ Done | 2026-02-22 | `roles/plane` — community deployment |
| Forgejo | ✓ Done | 2026-02-22 | `roles/forgejo` — container state check (no host ports) |
| Woodpecker CI | ✓ Done | 2026-02-22 | `roles/woodpecker` — container state check (no host ports) |
| **Documentation** | | | |
| ANSIBLE_DEPLOYMENT.md | ✓ Done | 2026-02-26 | Roles list, health check patterns, secrets checklist updated |
| STATUS.md | ✓ Done | 2026-02-26 | Reflects actual deployed state |

## All Phases Complete

### Phase 1: Foundation ✓
- [x] Ansible installation and configuration
- [x] Directory structure
- [x] Port registry in `group_vars/all.yml`
- [x] Connectivity test with `status.yml`

### Phase 2: Firewall ✓
- [x] Firewall role with idempotent UFW rules
- [x] LAN-only segmentation for Cockpit, Ollama, VNC, Forgejo SSH, Plane
- [x] WAN block rules for RDP, Cockpit, Plane, VNC

### Phase 3: nginx ✓
- [x] Config sync from repo to host
- [x] Test + reload handler
- [x] Health check fixed: `Host: geek` header + `/healthz`, flush_handlers before check

### Phase 4: Docker Infrastructure ✓
- [x] `geek-infra` Docker network managed by Ansible

### Phase 5: All Services ✓
- [x] PostgreSQL, Authentik, BookStack, Pi-hole, Cloudflare DDNS
- [x] Plane (community deployment, proxy attached to geek-infra)
- [x] Forgejo (Git service, SSH on 222:2222, HTTP via nginx only)
- [x] Woodpecker CI (OAuth via Forgejo, HTTP via nginx only)

## Key Design Decisions

1. **Port Registry** (`group_vars/all.yml`)
   - All ports defined in one place
   - Referenced by firewall rules, nginx configs, docker-compose files
   - Eliminates port management drift

2. **Coexistence Not Replacement**
   - Roles use `state: present` — does not restart running services unnecessarily
   - Dry-run (`--check --diff`) validates before applying
   - Coexists with existing shell scripts (`make nginx-deploy`, etc.)

3. **Tag-Based Execution**
   - Run a single service: `make ansible-apply ARGS='--tags forgejo'`
   - Run multiple: `make ansible-apply ARGS='--tags forgejo,woodpecker'`

4. **Idempotency**
   - Run twice → no changes on second run
   - Verified: `changed=0` on second `make ansible-apply`

5. **Health Check Strategy**
   - Services with nginx `/healthz`: use `uri` with `Host: geek` header + `meta: flush_handlers`
   - Services without host-exposed HTTP ports (Forgejo, Woodpecker): use `community.docker.docker_container_info`
   - Reason: container DNS names are not resolvable from the Ansible host

## Remaining Improvements (Optional)

- [ ] Ansible Vault for secrets (replaces manual `/etc/homelab/secrets/` management)
- [ ] `changed_when: false` on read-only tasks to suppress noise
- [ ] Disaster recovery playbook
- [ ] Alert on health check failure (currently `ignore_errors: yes`)
