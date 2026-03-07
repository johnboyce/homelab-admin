# Improvement Roadmap Specification

## Overview

Prioritized roadmap for improving homelab infrastructure based on compliance validation, best practices, and operational needs.

## Improvement Categories

- **Version Management** — Update and pin service versions
- **Documentation** — Complete missing documentation
- **Security** — Enhance security posture
- **Automation** — Improve deployment and monitoring automation
- **Reliability** — Add health checks and error handling
- **Operations** — Streamline day-to-day management

---

## Phase 1: Critical Fixes (Complete This Week)

### Priority: CRITICAL

#### IMP-001: Pin Vaultwarden Version
**Category:** Version Management, Security
**Severity:** Critical
**Effort:** 15 minutes

**Problem:**
- Vaultwarden using `:latest` tag
- Security-critical service (password manager)
- Breaking changes could occur without notice

**Solution:**
1. Check latest stable release: https://github.com/dani-garcia/vaultwarden/releases
2. Update `platform/vaultwarden/docker-compose.yml`
3. Update spec with version and check date
4. Test and deploy

**Commands:**
```bash
# Check latest release
curl -s https://api.github.com/repos/dani-garcia/vaultwarden/releases/latest | grep tag_name

# Update docker-compose.yml
# Change: image: vaultwarden/server:latest
# To:     image: vaultwarden/server:1.32.0  # Use actual latest

# Deploy
make ansible-apply ARGS='--tags vaultwarden'

# Verify
curl -I -H "Host: vaultwarden.geek" http://geek/
```

**Validation:**
- Service starts successfully
- Web UI accessible
- Can log in with existing account
- Data persisted

---

#### IMP-002: Generate All .env.example Files
**Category:** Documentation, Security
**Severity:** High
**Effort:** 30 minutes

**Problem:**
- Several services missing `.env.example` documentation
- Developers/operators don't know what secrets are required
- Difficult to set up services on new hosts

**Services Missing .env.example:**
- postgres
- bookstack  
- forgejo
- woodpecker
- plane
- pihole
- cloudflare-ddns
- vaultwarden

**Solution:**
```bash
# Generate automatically
./scripts/generate_env_examples.sh --dry-run  # Preview
./scripts/generate_env_examples.sh            # Create files

# Review and enhance
# Add helpful comments specific to each service

# Commit
git add platform/*/.env.example
git commit -m "Add .env.example files for all services"
git push
```

**Validation:**
- All services with `env_file:` have `.env.example`
- Files document all required variables
- Include helpful generation commands

---

#### IMP-003: Run Full Validation Check
**Category:** Compliance
**Severity:** High
**Effort:** 10 minutes

**Purpose:**
- Establish baseline compliance
- Identify all issues
- Prioritize remediation

**Commands:**
```bash
# Make script executable
chmod +x scripts/validate_homelab.sh

# Run validation
./scripts/validate_homelab.sh

# Review output and create issues for failures
```

**Validation:**
- Script runs successfully
- All checks reported
- Failure count documented

---

## Phase 2: Version Management (Complete This Month)

### Priority: HIGH

#### IMP-004: Pin Woodpecker Version
**Category:** Version Management
**Severity:** Medium
**Effort:** 20 minutes

**Problem:**
- Using `:latest` tag
- CI/CD service, breaking changes possible
- Should pin to major or specific version

**Solution:**
```yaml
# Check latest: https://github.com/woodpecker-ci/woodpecker/releases
# Update to:
image: woodpeckerci/woodpecker-server:v3.0.0  # Or latest stable
image: woodpeckerci/woodpecker-agent:v3.0.0
```

**Testing:**
- Verify CI builds still work
- Check Forgejo OAuth integration
- Review release notes for breaking changes

---

#### IMP-005: Pin Plane Version
**Category:** Version Management
**Severity:** Medium
**Effort:** 30 minutes

**Problem:**
- Using `:latest` for both backend and frontend
- Community deployment, high risk of breaking changes
- Need version alignment between components

**Solution:**
```yaml
# Check latest: https://github.com/makeplane/plane/releases
# Update to same version for both:
image: makeplane/plane-backend:v0.25.0
image: makeplane/plane-frontend:v0.25.0
```

**Testing:**
- Verify application loads
- Check database migrations
- Test API functionality

---

#### IMP-006: Pin Pi-hole Version
**Category:** Version Management
**Severity:** Low
**Effort:** 15 minutes

**Problem:**
- Using `:latest` tag
- Network service, should be more predictable

**Solution:**
```yaml
# Check latest: https://github.com/pi-hole/docker-pi-hole/releases
# Update to:
image: pihole/pihole:2024.07.0  # Or latest stable
```

**Testing:**
- DNS resolution still works
- Admin interface accessible
- Custom dnsmasq configs preserved

---

#### IMP-007: Update PostgreSQL Patch Version
**Category:** Version Management
**Severity:** Medium
**Effort:** 30 minutes

**Problem:**
- Using `postgres:16` (major only)
- May be missing security patches
- Should specify patch level

**Solution:**
```yaml
# Check latest 16.x: https://www.postgresql.org/
# Update to:
image: postgres:16.2  # Or latest 16.x patch
```

**Testing:**
- All databases start correctly
- Authentik, Forgejo, Plane connect successfully
- Run backup and verify

⚠️ **CAUTION:** Test thoroughly, database version downgrades not supported

---

#### IMP-008: Create Version Tracking System
**Category:** Automation
**Severity:** Medium
**Effort:** 2 hours

**Problem:**
- Version checks are manual
- Easy to forget to check for updates
- No alerting for outdated versions

**Solution:**
1. Enhance `check_versions.sh` to query upstream APIs
2. Add to cron or GitHub Actions
3. Send notification if updates available
4. Document in spec

**APIs to Use:**
- Docker Hub API for public images
- GitHub API for releases
- RSS feeds for some projects

---

## Phase 3: Documentation (Complete This Month)

### Priority: MEDIUM

#### IMP-009: Document Database Setup
**Category:** Documentation
**Severity:** Medium
**Effort:** 1 hour

**Missing:**
- How to create postgres databases
- User permission setup
- Connection string format
- Migration procedures

**Create:**
- `docs/POSTGRESQL_MANAGEMENT.md`

**Content:**
```markdown
# PostgreSQL Database Management

## Creating New Database
## Setting Up Users
## Backup and Restore
## Troubleshooting
```

---

#### IMP-010: Document Forgejo SSH Access
**Category:** Documentation
**Severity:** Medium
**Effort:** 30 minutes

**Missing:**
- SSH key setup for git operations
- Port 222 usage explained
- Clone URL format
- Troubleshooting connection issues

**Update:**
- Add section to `README.md` or create `docs/FORGEJO_SETUP.md`

---

#### IMP-011: Complete Backup Documentation
**Category:** Documentation, Reliability
**Severity:** High
**Effort:** 1 hour

**Current State:**
- `BACKUP.md` exists but incomplete
- Scripts exist but not fully documented
- Restore procedures missing
- Testing schedule undefined

**Tasks:**
1. Update `BACKUP.md` with:
   - Complete backup procedures for each service
   - Restore procedures with examples
   - Testing schedule (quarterly)
   - Retention policies
2. Document in service inventory spec
3. Add to maintenance schedule

---

## Phase 4: Automation (Complete This Quarter)

### Priority: MEDIUM

#### IMP-012: Automated Version Checking
**Category:** Automation
**Severity:** Medium
**Effort:** 3 hours

**Solution:**
- GitHub Actions workflow
- Runs weekly
- Checks upstream for new versions
- Creates issue if updates available
- Updates spec automatically

**Implementation:**
```yaml
# .github/workflows/version-check.yml
name: Version Check
on:
  schedule:
    - cron: '0 10 * * 1'  # Weekly on Monday
  workflow_dispatch:
jobs:
  check-versions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check versions
        run: ./scripts/check_versions.sh --update-spec
      - name: Create PR if updates available
        # ... implementation
```

---

#### IMP-013: Certificate Expiration Monitoring
**Category:** Automation, Security
**Severity:** Medium
**Effort:** 2 hours

**Problem:**
- TLS certificate expiration not monitored
- Could lead to service outage if renewal fails
- Manual check required

**Solution:**
1. Script to check cert expiration
2. Alert if < 30 days remaining
3. Verify acme.sh cron is working
4. Add to health check

**Implementation:**
```bash
# scripts/check_cert_expiration.sh
cert=/etc/nginx-docker/certs/johnnyblabs.crt
expiry=$(openssl x509 -in $cert -noout -enddate | cut -d= -f2)
days_until=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))

if [ $days_until -lt 30 ]; then
  echo "WARNING: Certificate expires in $days_until days"
  # Send alert
fi
```

---

#### IMP-014: Centralized Health Monitoring
**Category:** Automation, Reliability
**Severity:** Medium
**Effort:** 4 hours

**Problem:**
- Health checks are manual or per-deployment
- No alerting on service failures
- Can't track uptime/availability

**Solution:**
1. Deploy monitoring service (Uptime Kuma, Netdata, or simple script)
2. Monitor all service endpoints
3. Alert on failures (email, webhook)
4. Track metrics over time

**Options:**
- Lightweight: Cron + curl script with email alerts
- Full-featured: Uptime Kuma or Grafana + Prometheus
- Balance: Simple monitoring with Healthchecks.io

---

#### IMP-015: Pre-Commit Validation Hook
**Category:** Automation, Quality
**Severity:** Low
**Effort:** 1 hour

**Purpose:**
- Catch issues before commit
- Prevent secrets from entering git
- Validate YAML syntax

**Implementation:**
```bash
# .git/hooks/pre-commit
#!/bin/bash
set -e

echo "Running pre-commit validation..."

# Check for secrets
if git diff --cached --name-only | grep -E '\.(env|key|pem)$' | grep -v example; then
  echo "ERROR: Attempting to commit secret file"
  exit 1
fi

# Run validation
./scripts/validate_homelab.sh

# Check Ansible syntax
ansible-playbook ansible/playbooks/site.yml --syntax-check

echo "Validation passed"
```

---

## Phase 5: Reliability (Ongoing)

### Priority: MEDIUM

#### IMP-016: Improve Health Checks
**Category:** Reliability
**Severity:** Medium
**Effort:** 2 hours

**Current State:**
- Some services only check container status
- No application-level health validation
- Health checks use `ignore_errors: yes` (failures silent)

**Improvements:**
1. Add proper health check endpoints where possible
2. Fail deployment if critical service unhealthy
3. Retry logic for transient failures
4. Document health check requirements in spec

---

#### IMP-017: Add Resource Limits
**Category:** Reliability
**Severity:** Medium
**Effort:** 2 hours

**Problem:**
- No CPU or memory limits defined
- Services could consume all resources
- No protection against resource exhaustion

**Solution:**
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
```

**Implementation:**
1. Profile each service's resource usage
2. Set appropriate limits
3. Test under load
4. Document in service specs

---

#### IMP-018: Disaster Recovery Playbook
**Category:** Reliability, Documentation
**Severity:** High
**Effort:** 4 hours

**Create:** `docs/DISASTER_RECOVERY.md`

**Content:**
1. Bare-metal recovery from scratch
2. Restore from backups
3. Emergency procedures
4. Contact information
5. Service priority order
6. Validation checklist

**Test Annually:**
- Full recovery drill
- Verify all procedures work
- Update documentation

---

## Phase 6: Advanced Features (Future)

### Priority: LOW

#### IMP-019: Development Environment
**Category:** Quality
**Effort:** 4 hours

**Purpose:**
- Test changes before production
- Isolate development from production
- Safe experimentation

**Implementation:**
- Docker Compose overrides
- Separate network or VM
- Test data seeding
- Documentation

---

#### IMP-020: CI/CD Pipeline
**Category:** Automation
**Effort:** 8 hours

**Features:**
- Automated validation on push
- Ansible syntax checking
- Docker Compose validation
- Security scanning
- Documentation linting
- Auto-generate change reports

---

#### IMP-021: Centralized Logging
**Category:** Operations
**Effort:** 6 hours

**Options:**
- Loki + Grafana
- ELK stack (Elasticsearch, Logstash, Kibana)
- Simple: Promtail + Loki

**Benefits:**
- Aggregate logs from all services
- Search across services
- Retention and archival
- Alerting on error patterns

---

## Quick Wins (Can Complete Today)

### QW-01: Make Scripts Executable
```bash
chmod +x scripts/*.sh
git add scripts/
git commit -m "Make scripts executable"
```

### QW-02: Add Makefile Targets
```makefile
validate:
	@./scripts/validate_homelab.sh

check-versions:
	@./scripts/check_versions.sh

generate-env-examples:
	@./scripts/generate_env_examples.sh --dry-run
	@echo ""
	@read -p "Create files? (y/N): " confirm; \
	if [ "$$confirm" = "y" ]; then \
		./scripts/generate_env_examples.sh; \
	fi
```

### QW-03: Update .gitignore
```gitignore
# Ensure all secret patterns covered
*.env
!*.env.example
*.key
*.pem
*.p12
*.pfx
*.crt
!certs/.keep
```

### QW-04: Run Validation
```bash
./scripts/validate_homelab.sh
# Review and prioritize failures
```

---

## Implementation Plan

### Week 1 (March 4-10, 2026)
- [x] Create OpenSpec framework
- [x] Create infrastructure standards spec
- [x] Create service inventory spec
- [x] Create compliance validation spec
- [ ] Make scripts executable
- [ ] Run initial validation
- [ ] Generate .env.example files
- [ ] Pin vaultwarden version

### Week 2 (March 11-17, 2026)
- [ ] Pin woodpecker, plane, pihole versions
- [ ] Update PostgreSQL to latest 16.x
- [ ] Create missing service documentation
- [ ] Update HOMELAB_SPEC.yml version matrix
- [ ] Add Makefile targets for new scripts

### Week 3 (March 18-24, 2026)
- [ ] Complete backup documentation
- [ ] Test backup restore procedure
- [ ] Document database setup procedures
- [ ] Improve health checks in Ansible roles

### Week 4 (March 25-31, 2026)
- [ ] Set up certificate expiration monitoring
- [ ] Create disaster recovery playbook
- [ ] Implement pre-commit hooks
- [ ] Review and update all specs

---

## Tracking Progress

### Compliance Score Goal
- **Current:** 78/100
- **Target (Week 1):** 85/100
- **Target (Month 1):** 90/100
- **Target (Quarter 1):** 95/100

### Key Metrics

| Metric | Current | Target | Deadline |
|--------|---------|--------|----------|
| Services using :latest | 4 | 1 | Week 2 |
| Missing .env.example | 8 | 0 | Week 1 |
| Documentation coverage | 80% | 95% | Month 1 |
| Backup test success | Unknown | 100% | Week 3 |
| Automated checks | 40% | 80% | Month 2 |

---

## Success Criteria

### Phase 1 Success
- ✅ All critical services pinned to versions
- ✅ All services have .env.example
- ✅ Validation script runs without critical failures
- ✅ Compliance score > 85

### Phase 2 Success
- ✅ No services using :latest (except acceptable utilities)
- ✅ All services on latest stable versions
- ✅ Version tracking automated
- ✅ Compliance score > 90

### Phase 3 Success
- ✅ Complete documentation for all services
- ✅ Backup procedures tested and validated
- ✅ Disaster recovery playbook verified
- ✅ Compliance score > 90

### Phase 4+ Success
- ✅ Automated monitoring and alerting
- ✅ CI/CD pipeline operational
- ✅ Certificate monitoring automated
- ✅ Compliance score > 95

---

## Maintenance Schedule

### Daily
- Monitor service health (manual or automated)
- Review critical alerts

### Weekly
- Run validation script
- Check service logs
- Review recent changes

### Monthly
- Check for version updates
- Update service specs
- Run compliance validation
- Security review

### Quarterly
- Update non-critical versions
- Test backup restoration
- Review and update documentation
- Infrastructure audit
- Disaster recovery drill

### Annually
- Major version upgrades
- Security audit
- Access control review
- Archive old data

---

## Risk Management

### High Risk Changes
- PostgreSQL major version upgrade
- Authentik major version upgrade
- nginx major version upgrade
- Firewall rule changes
- Network configuration changes

**Mitigation:**
- Always dry-run first
- Maintain rollback procedure
- Test in isolated environment if possible
- Schedule during maintenance window
- Monitor closely after deployment

### Low Risk Changes
- Documentation updates
- Script improvements
- Minor version bumps (patch level)
- Adding new services (doesn't affect existing)

---

## OpenSpec Integration

### Using OpenSpec for Changes

```bash
# Propose a new improvement
openspec change propose "Pin vaultwarden to specific version"

# View active changes
openspec list

# View change details
openspec show <change-name>

# Archive completed change
openspec archive <change-name>
```

### Spec-Driven Development

1. **Problem identified** → Documented in compliance spec
2. **Improvement proposed** → Create OpenSpec change
3. **Tasks defined** → Break down implementation steps
4. **Implementation** → Execute tasks with validation
5. **Verification** → Run compliance checks
6. **Archive** → Update specs with new state

---

## Next Steps

### Immediate Actions (Today)

1. Make validation scripts executable
2. Run initial validation
3. Review and prioritize failures
4. Start Phase 1 critical fixes

### Commands to Run

```bash
# Make scripts executable
chmod +x scripts/validate_homelab.sh scripts/check_versions.sh scripts/generate_env_examples.sh

# Run validation
./scripts/validate_homelab.sh > validation-report.txt

# Check versions
./scripts/check_versions.sh > version-report.txt

# Generate .env.example files
./scripts/generate_env_examples.sh

# Review reports
cat validation-report.txt
cat version-report.txt

# Commit improvements
git add -A
git commit -m "Add OpenSpec framework and validation tools"
git push
```

---

## Long-Term Vision

### Goals
- **100% Infrastructure as Code** — Everything defined in git
- **Zero-Touch Deployment** — Fully automated via Ansible
- **Self-Healing** — Automated recovery from failures
- **Proactive Monitoring** — Issues detected before impact
- **Comprehensive Documentation** — All procedures documented
- **Disaster-Ready** — Can rebuild from scratch in < 1 hour

### Success Indicators
- Deployment without manual intervention
- No surprises during updates
- Clear audit trail for all changes
- Confident disaster recovery
- New team members can understand system quickly
- Compliance score maintained > 95

---

## References

- Infrastructure Standards: `openspec/specs/infrastructure-standards.md`
- Service Inventory: `openspec/specs/service-inventory.md`
- Compliance Rules: `openspec/specs/compliance-validation.md`
- Main Documentation: `README.md`, `ADMIN.md`
- Validation Tools: `scripts/validate_homelab.sh`

