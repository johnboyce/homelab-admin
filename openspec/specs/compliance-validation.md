# Compliance and Validation Specification

## Overview

Defines validation rules, compliance checks, and quality standards for the homelab infrastructure. This spec enables automated validation and identifies areas for improvement.

## Validation Categories

### 1. Security Compliance

#### SEC-01: No Secrets in Git
**Severity:** Critical
**Description:** Repository must not contain actual secrets, keys, or certificates

**Checks:**
- No `.env` files (except `.env.example`)
- No `.key`, `.pem`, `.p12`, `.pfx` files
- No hardcoded passwords in docker-compose.yml or scripts
- `.gitignore` includes secret patterns

**Validation:**
```bash
# Run validation script
./scripts/validate_homelab.sh

# Manual check
git ls-files | grep -E '\.(env|key|pem)$' | grep -v example
```

**Remediation:**
```bash
# Remove from git
git rm --cached <file>
echo "<pattern>" >> .gitignore
git commit -m "Remove secrets from git"
```

---

#### SEC-02: Secrets File Presence
**Severity:** Critical
**Description:** All services with env_file must have secrets on host

**Checks:**
- File exists at `/etc/homelab/secrets/<service>.env`
- Permissions: 644 (readable by docker)
- Owner: root:root
- All required variables present

**Validation:**
- Ansible role checks file existence before deployment
- Fails with helpful error if missing

---

#### SEC-03: TLS Certificate Security
**Severity:** High
**Description:** TLS certificates properly secured

**Checks:**
- Private keys: 600 permissions
- Certificates: 644 permissions
- Owner: root:root
- Not in git repository
- Valid expiration date

**Validation:**
```bash
# Check certificate expiration
ssh johnb@geek "openssl x509 -in /etc/nginx-docker/certs/johnnyblabs.crt -noout -enddate"

# Check permissions
ssh johnb@geek "ls -la /etc/nginx-docker/certs/"
```

---

#### SEC-04: Firewall Configuration
**Severity:** High
**Description:** UFW properly configured with default deny

**Checks:**
- UFW enabled and active
- Default incoming: deny
- Default outgoing: allow
- All exposed ports have explicit rules
- LAN restrictions on admin services

**Validation:**
```bash
ssh johnb@geek "sudo ufw status numbered"
```

---

#### SEC-05: Port Exposure Audit
**Severity:** Medium
**Description:** Minimize port exposure, prefer docker-network

**Checks:**
- Public services: Only 80/443 via nginx
- Admin services: LAN-only or localhost
- Database services: docker-network only (no host exposure)
- Document reason for any host port exposure

**Validation:**
```bash
# Scan all docker-compose files for port mappings
grep -r "ports:" platform/*/docker-compose.yml
```

---

### 2. Configuration Standards

#### CFG-01: Docker Compose Structure
**Severity:** High
**Description:** All docker-compose.yml files follow standard structure

**Required Fields:**
- `services` section
- `container_name` for each service
- `restart` policy (unless-stopped preferred)
- `networks` section with geek-infra
- `image` with version tag

**Validation:**
```bash
# Check structure
for f in platform/*/docker-compose.yml; do
  echo "Checking $f"
  grep -q "container_name:" "$f" || echo "  Missing: container_name"
  grep -q "restart:" "$f" || echo "  Missing: restart policy"
  grep -q "geek-infra" "$f" || echo "  Missing: geek-infra network"
done
```

---

#### CFG-02: Network Configuration
**Severity:** High
**Description:** All services use geek-infra external network

**Checks:**
- Network declared in compose file
- Network marked as external: true
- Service connected to geek-infra

**Validation:**
- Automated in `validate_homelab.sh`

---

#### CFG-03: Volume Path Consistency
**Severity:** Medium
**Description:** Volume paths follow standard pattern

**Standard Path:** `/srv/homelab/<service-name>/`
**Acceptable Exceptions:**
- `/etc/homelab/secrets/` — Secret files
- `/etc/nginx-docker/` — nginx configuration
- `/var/run/docker.sock` — Docker socket for agents

**Validation:**
```bash
# Check volume paths
grep -r "volumes:" platform/*/docker-compose.yml | grep -v "/srv/homelab\|/etc/homelab\|/etc/nginx-docker\|/var/run"
```

---

#### CFG-04: Container Naming
**Severity:** Medium
**Description:** Container names follow convention

**Pattern:** `<service>` or `geek-<service>` or `<service>-<component>`
**Requirements:**
- Lowercase only
- Hyphenated (no underscores)
- Descriptive and unique

**Examples:**
- ✅ `geek-nginx`, `authentik-server`, `bookstack-db`
- ❌ `Nginx`, `authentik_server`, `db`

---

#### CFG-05: Environment Variables
**Severity:** High
**Description:** Proper environment variable management

**Requirements:**
- Secrets via `env_file`
- Non-secret config can be inline
- No hardcoded passwords
- `.env.example` provided

**Validation:**
- Check for `.env.example` files
- Scan for hardcoded secrets

---

### 3. Ansible Standards

#### ANS-01: Role Coverage
**Severity:** High
**Description:** Every platform service has corresponding Ansible role

**Checks:**
- Directory exists: `ansible/roles/<service>/`
- File exists: `ansible/roles/<service>/tasks/main.yml`
- Role included in `site.yml`

**Validation:**
```bash
# List services without roles
for dir in platform/*/; do
  service=$(basename "$dir")
  [ "$service" = "ingress" ] && continue
  [ ! -d "ansible/roles/$service" ] && echo "Missing role: $service"
done
```

---

#### ANS-02: Secret Validation
**Severity:** Critical
**Description:** Roles check for required secrets before deployment

**Required Tasks:**
```yaml
- name: Check <service> secrets file exists
  stat:
    path: /etc/homelab/secrets/<service>.env
  register: secrets_check

- name: Fail if secrets missing
  fail:
    msg: "Secrets file not found. Required: VAR1, VAR2"
  when: not secrets_check.stat.exists
```

---

#### ANS-03: Idempotency
**Severity:** High
**Description:** Roles are idempotent (safe to run multiple times)

**Requirements:**
- Use `state: present` not `restarted`
- Check before create
- Second run shows `changed=0`

**Testing:**
```bash
make ansible-apply
make ansible-apply  # Should show changed=0
```

---

#### ANS-04: Health Checks
**Severity:** Medium
**Description:** Roles verify service health after deployment

**Methods:**
- HTTP services: Use `uri` module with proper headers
- Container-only: Use `docker_container_info` module
- Always: `meta: flush_handlers` before check

---

#### ANS-05: Tag Usage
**Severity:** Medium
**Description:** Roles use consistent tagging

**Required Tags:**
- Service name (e.g., `nginx`, `authentik`)
- `lifecycle` — Deployment operations
- `config` — Configuration changes
- `bootstrap` — Initial setup

**Usage Enables:**
```bash
# Deploy specific service
make ansible-apply ARGS='--tags bookstack'

# Update only configs
make ansible-apply ARGS='--tags config'
```

---

### 4. Version Management

#### VER-01: Critical Service Pinning
**Severity:** Critical
**Description:** Infrastructure services must use pinned versions

**Critical Services:**
- nginx → Pin to major or exact (e.g., `1.29.4`)
- postgres → Pin to major (e.g., `16`)
- authentik → Pin to exact (e.g., `2025.10.4`)

**Current Violations:**
- None (all critical services pinned) ✅

---

#### VER-02: Security Service Pinning
**Severity:** High
**Description:** Security-related services should pin versions

**Security Services:**
- vaultwarden ❌ Currently using `:latest`
- authentik ✅ Pinned

**Remediation:**
```yaml
# Change from:
image: vaultwarden/server:latest

# To:
image: vaultwarden/server:1.32.0  # Check latest stable
```

---

#### VER-03: Version Tracking
**Severity:** Medium
**Description:** Track when versions were last checked

**Requirements:**
- Document current version in spec
- Record last check date
- Set update schedule
- Note upstream source for updates

**Location:** `HOMELAB_SPEC.yml` or service spec

---

#### VER-04: Update Documentation
**Severity:** Medium
**Description:** Document breaking changes and update procedures

**Requirements:**
- Read upstream release notes before updating
- Note breaking changes in spec
- Test in dry-run before applying
- Document any manual steps required

---

### 5. Documentation Standards

#### DOC-01: Core Documentation
**Severity:** High
**Description:** Required documentation files present

**Required Files:**
- ✅ `README.md` — Project overview
- ✅ `ADMIN.md` — Principles
- ✅ `CHECKLIST.md` — Progress
- ✅ `docs/ANSIBLE_DEPLOYMENT.md`
- ✅ `docs/FIREWALL.md`
- ✅ `docs/TLS_CERTIFICATES.md`

---

#### DOC-02: Service Documentation
**Severity:** Medium
**Description:** Services have adequate documentation

**Requirements:**
- `.env.example` if using secrets
- Complex services have README.md
- Inline comments for non-obvious config
- Recovery procedures documented

**Current Status:**
- ⚠️  Several services missing `.env.example`
- ✅ Major services have dedicated docs

**Action:** Run `./scripts/generate_env_examples.sh`

---

#### DOC-03: Code Comments
**Severity:** Low
**Description:** Configuration files have helpful comments

**Guidelines:**
- Explain why, not what
- Document non-obvious choices
- Reference related documentation
- Include examples in comments

---

### 6. Backup and Recovery

#### BCK-01: Backup Requirements
**Severity:** High
**Description:** Critical data has backup strategy

**Services Requiring Backup:**
- postgres (databases)
- authentik (media, templates, database)
- bookstack (config, MariaDB)
- forgejo (git repositories)
- vaultwarden (vault data)
- pihole (configuration)

**Validation:**
- Backup scripts exist
- Backups scheduled (cron or systemd timer)
- Retention policy documented

---

#### BCK-02: Backup Testing
**Severity:** High
**Description:** Backups are tested regularly

**Requirements:**
- Test restore quarterly
- Document restore procedure
- Verify backup integrity
- Store backups off-site (optional)

**Current Status:**
- ⚠️  Scripts exist but testing schedule not defined

---

#### BCK-03: Configuration Backup
**Severity:** Medium
**Description:** Configuration in git serves as backup

**Covered:**
- ✅ nginx configurations
- ✅ Ansible playbooks
- ✅ Docker Compose files
- ✅ Scripts and documentation

**Not Covered:**
- Secrets (by design)
- Runtime data
- TLS certificates (regenerable)

---

## Validation Automation

### Available Scripts

1. **`scripts/validate_homelab.sh`**
   - Full compliance validation
   - Checks security, standards, documentation
   - Exit code 0 = pass, 1 = failures found

2. **`scripts/check_versions.sh`**
   - Scans all docker-compose.yml files
   - Reports current versions
   - Identifies :latest usage
   - Provides update guidance

3. **`scripts/generate_env_examples.sh`**
   - Scans for services with secrets
   - Generates .env.example files
   - Documents required variables

### Integration Points

#### Pre-Commit Validation
```bash
# Add to .git/hooks/pre-commit
./scripts/validate_homelab.sh || exit 1
```

#### Pre-Deployment Validation
```bash
# Already in Makefile
make ansible-dry-run  # Tests without applying
```

#### CI/CD Pipeline (Future)
```yaml
# GitHub Actions workflow
- name: Validate Infrastructure
  run: |
    ./scripts/validate_homelab.sh
    ./scripts/check_versions.sh
```

---

## Compliance Scoring

### Current Score: 78/100

**Breakdown:**
- Security: 18/20 (missing: some .env.example files)
- Configuration: 19/20 (minor: some non-standard volume paths)
- Ansible: 18/20 (missing: some health checks need improvement)
- Versions: 12/20 (major issue: 4 services using :latest)
- Documentation: 16/20 (missing: .env.example, some service docs)
- Backup: 15/20 (exists but testing schedule undefined)

**Target Score:** 90/100

**Improvement Plan:**
1. Fix version pinning → +6 points
2. Generate .env.example files → +2 points
3. Document backup testing → +2 points
4. Improve health checks → +2 points

---

## Action Items

### High Priority (Complete This Week)

- [ ] **VER-02:** Pin vaultwarden to specific version
- [ ] **DOC-02:** Generate all missing .env.example files
  ```bash
  ./scripts/generate_env_examples.sh
  git add platform/*/.env.example
  git commit -m "Add .env.example files for all services"
  ```
- [ ] **VER-03:** Check and update version tracking in specs
- [ ] **ANS-02:** Verify all roles check for secrets

### Medium Priority (Complete This Month)

- [ ] **VER-02:** Pin pihole, woodpecker, plane versions
- [ ] **VER-03:** Update PostgreSQL to latest 16.x patch
- [ ] **BCK-02:** Document backup testing schedule
- [ ] **DOC-02:** Create service-specific troubleshooting guides
- [ ] **ANS-04:** Improve health checks for container-only services

### Low Priority (Complete This Quarter)

- [ ] **Monitoring:** Set up automated health monitoring
- [ ] **CI/CD:** Create GitHub Actions workflow for validation
- [ ] **Backup:** Implement off-site backup storage
- [ ] **Documentation:** Add service-specific README files
- [ ] **Testing:** Create test environment for update validation

---

## Validation Workflow

### Manual Validation (Run Before Commits)

```bash
# 1. Run compliance check
./scripts/validate_homelab.sh

# 2. Check versions
./scripts/check_versions.sh

# 3. Test Ansible changes
make ansible-dry-run

# 4. If all pass, commit
git add -A
git commit -m "Description of changes"
git push
```

### Automated Validation (Future)

```yaml
# .github/workflows/validate.yml
name: Infrastructure Validation
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run validation
        run: ./scripts/validate_homelab.sh
      - name: Check versions
        run: ./scripts/check_versions.sh
      - name: Validate Ansible syntax
        run: |
          pip install ansible
          ansible-playbook ansible/playbooks/site.yml --syntax-check
```

---

## Exception Handling

### Acceptable Exceptions

1. **:latest for non-critical utilities**
   - cloudflare-ddns (DDNS updater)
   - Acceptable if: Service is stateless, no security impact, good update history

2. **Non-standard volume paths**
   - `/var/run/docker.sock` (Docker API access)
   - `/etc/nginx-docker/` (nginx configuration)
   - Must document reason

3. **Localhost port binding**
   - Pi-hole admin: `127.0.0.1:8081`
   - Access via SSH tunnel
   - More secure than LAN exposure

### Exception Documentation

When making exceptions:
1. Document in service docker-compose.yml comments
2. Add to this compliance spec
3. Include reasoning
4. Set review date

---

## Continuous Improvement

### Regular Reviews

**Weekly:**
- Run validation scripts
- Check service health
- Review logs for errors

**Monthly:**
- Check for version updates
- Review compliance score
- Update documentation

**Quarterly:**
- Full infrastructure audit
- Update pinned versions
- Test backup restoration
- Review and archive old changes

### Metrics to Track

- Compliance score (target: 90/100)
- Services using :latest (target: ≤2)
- Services without .env.example (target: 0)
- Days since last version check (target: ≤30)
- Backup test success rate (target: 100%)

---

## Remediation Priorities

### Critical (Fix Immediately)
- Secrets in git
- Missing secrets files blocking deployment
- Firewall misconfiguration
- Certificate expiration

### High (Fix This Week)
- Security services using :latest
- Missing Ansible roles
- Broken health checks

### Medium (Fix This Month)
- Non-critical :latest usage
- Missing documentation
- Non-standard patterns

### Low (Fix This Quarter)
- Documentation improvements
- Monitoring enhancements
- Nice-to-have automations

---

## Tools and Scripts

### Validation
- `scripts/validate_homelab.sh` — Full compliance check
- `scripts/check_versions.sh` — Version audit
- `make ansible-dry-run` — Ansible validation

### Generation
- `scripts/generate_env_examples.sh` — Create missing .env.example

### Deployment
- `make ansible-apply` — Deploy infrastructure
- `make ansible-apply ARGS='--tags <service>'` — Deploy specific service

### Monitoring
- `make homelab-status` — Quick status check
- `make homelab-status-verbose` — Detailed status
- `make homelab-health` — Health check with system info
- `make homelab-logs` — Recent logs

---

## References

- Infrastructure Standards: `openspec/specs/infrastructure-standards.md`
- Service Inventory: `openspec/specs/service-inventory.md`
- Validation Script: `scripts/validate_homelab.sh`
- Main Documentation: `README.md`, `ADMIN.md`

