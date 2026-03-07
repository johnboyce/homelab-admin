# Infrastructure Standards Specification

## Overview

This specification defines the standards and patterns for all infrastructure services in the homelab-admin project running on the `geek` host.

## Purpose

- Ensure consistency across all service deployments
- Document best practices for Docker Compose configurations
- Define Ansible automation patterns
- Establish security and networking standards
- Guide version management and updates
- Enable automated validation and compliance checking

## Scope

Applies to all services in the `platform/` directory and their corresponding Ansible roles.

## Core Principles

### 1. Source of Truth
- Git repository is the authoritative source for all configuration
- Host system reflects runtime state deployed from git
- Changes flow: `local edit → git → ansible → host`

### 2. Security First
- No secrets in git (use `.env.example` only)
- All secrets stored in `/etc/homelab/secrets/` on host
- Private keys never committed
- Firewall default deny, explicit allow
- TLS for all public domains

### 3. Idempotency
- All operations safe to run multiple times
- Ansible roles use `state: present` (not recreated/restarted)
- Configuration changes don't cause unnecessary service restarts

### 4. Reversibility
- All changes must be testable and rollback-able
- Use Ansible dry-run (`--check`) before applying
- Document rollback procedures

## Docker Compose Standards

### Required Fields

Every `docker-compose.yml` MUST include:

```yaml
services:
  <service-name>:
    image: <registry>/<image>:<version>  # Version pinning preferred
    container_name: <name>                # Required, lowercase-hyphenated
    restart: unless-stopped               # Required
    networks:
      - geek-infra                        # Required, external network
    # ... service-specific configuration
    
networks:
  geek-infra:
    external: true                        # Required
```

### Service Configuration

#### Container Naming
- Pattern: `<service-name>` or `geek-<service-name>`
- Must be lowercase, hyphenated
- Must be unique across entire stack
- Examples: `authentik-server`, `geek-nginx`, `bookstack`

#### Restart Policy
- Use: `unless-stopped` (preferred)
- Alternative: `always` (if service must survive docker daemon restart)
- Never: `no` or omit (services should auto-restart)

#### Network Configuration
- All services MUST use `geek-infra` external network
- Network is created by `docker_infra` Ansible role
- Services communicate via container names as DNS
- No additional networks unless isolation required

#### Volume Mounts
- Host paths MUST use pattern: `/srv/homelab/<service-name>/`
- Configuration files: `/etc/homelab/` or service-specific under `/srv/`
- Read-only mounts: Append `:ro` (e.g., nginx configs)
- Document backup requirements in comments or spec

#### Port Exposure
- Prefer: No host ports (docker-network only access via nginx)
- If required: Document in port registry (`group_vars/all.yml`)
- Public services: Only 80/443 exposed (via nginx)
- LAN services: Restricted by UFW firewall rules
- Format: `"<host-port>:<container-port>[/protocol]"`

#### Environment Variables
- Secrets MUST use `env_file: /etc/homelab/secrets/<service>.env`
- Non-secret config can be inline in `environment:` section
- Always provide `.env.example` in service directory
- Never hardcode passwords, tokens, or keys

#### Version Pinning

**Critical Services** (MUST pin):
- nginx → Pin to major version (e.g., `1.29.4`)
- postgres → Pin to major version (e.g., `16`)
- authentik → Pin to exact version (e.g., `2025.10.4`)

**Standard Services** (SHOULD pin):
- All application services (bookstack, forgejo, vaultwarden)
- Pin to semantic version or major version
- Example: `linuxserver/bookstack:25.12.7`

**Acceptable :latest** (with monitoring):
- Non-critical utilities
- Services with good backwards compatibility
- Must document update strategy in comments

### Health Checks

Add health checks where possible:

```yaml
services:
  app:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Ansible Role Standards

### Directory Structure

```
ansible/roles/<service-name>/
├── tasks/
│   └── main.yml          # Required
├── handlers/
│   └── main.yml          # Optional, for reload/restart
├── templates/            # Optional
├── files/                # Optional
└── defaults/
    └── main.yml          # Optional, for role variables
```

### Task Requirements

Every role's `tasks/main.yml` MUST include:

1. **Secrets Validation**
```yaml
- name: Check <service> secrets file exists
  stat:
    path: /etc/homelab/secrets/<service>.env
  become: yes
  register: <service>_secrets
  tags: [<service>, lifecycle]

- name: Fail if secrets file is missing
  fail:
    msg: |
      /etc/homelab/secrets/<service>.env not found.
      Required variables: VAR1, VAR2, VAR3
  when: not <service>_secrets.stat.exists
  tags: [<service>, lifecycle]
```

2. **Service Deployment**
```yaml
- name: Ensure <service> stack is running
  community.docker.docker_compose_v2:
    project_src: /home/johnb/homelab-admin/platform/<service>
    state: present           # Not 'restarted' - idempotent
    pull: policy            # Pull if newer version available
  become: yes
  tags: [<service>, lifecycle]
```

3. **Health Check** (recommended)
```yaml
- name: Flush handlers before health check
  meta: flush_handlers
  tags: [<service>, lifecycle]

# For HTTP services accessible via nginx
- name: Health check <service>
  uri:
    url: "http://localhost/healthz"
    headers:
      Host: "<service>.geek"
    status_code: 200
  ignore_errors: yes
  tags: [<service>, lifecycle]

# For container-only services
- name: Health check <service> container
  community.docker.docker_container_info:
    name: <service>
  register: <service>_info
  ignore_errors: yes
  tags: [<service>, lifecycle]
```

### Tags

Standard tags for all roles:

- `<service-name>` — Service-specific tag for selective execution
- `lifecycle` — Start/stop/deploy operations
- `config` — Configuration changes only
- `bootstrap` — Initial setup tasks
- `always` — Pre-tasks that run every time

Usage:
```bash
# Deploy single service
make ansible-apply ARGS='--tags authentik'

# Update configuration only
make ansible-apply ARGS='--tags config'

# Bootstrap new service
make ansible-apply ARGS='--tags bootstrap,postgres'
```

### Handlers

When services need reload (not restart):

```yaml
# handlers/main.yml
---
- name: Test nginx configuration
  command: docker exec geek-nginx nginx -t
  become: yes
  ignore_errors: yes

- name: Reload nginx
  command: docker exec geek-nginx nginx -s reload
  become: yes
  when: nginx_running | default(true)
```

### Idempotency Requirements

- Second run of role MUST show `changed=0` (if no actual changes)
- Use `state: present` not `state: restarted`
- Check before creating (use `stat` or `command` with `creates`)
- Use `changed_when: false` for read-only tasks

## nginx Configuration Standards

### File Organization

```
platform/ingress/nginx/etc-nginx-docker/
├── nginx.conf                  # Main configuration
├── conf.d/                     # All virtual hosts (active configs)
│   ├── 00_*.conf              # Base/default configs
│   ├── 10_*.conf              # Primary services
│   ├── 20_*.conf              # Secondary services
│   └── 30_*.conf              # Network services
├── snippets/                   # Reusable config fragments
└── certs/                      # TLS certificates (not in git)
    └── .keep                   # Placeholder only
```

### Naming Convention

- Pattern: `NN_<fqdn>.conf`
- Numeric prefix determines load order
- FQDN in filename for clarity
- Examples:
  - `10_auth.johnnyblabs.com.conf`
  - `21_bookstack.geek.conf`

### Server Block Patterns

#### Internal Domain (HTTP)
```nginx
server {
  listen 80;
  server_name <service>.geek;
  
  location / {
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto http;
    proxy_pass http://<container-name>:<port>;
  }
}
```

#### Public Domain (HTTPS)
```nginx
# HTTP → HTTPS redirect
server {
  listen 80;
  server_name <service>.johnnyblabs.com;
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl;
  http2 on;
  server_name <service>.johnnyblabs.com;
  
  ssl_certificate     /etc/nginx/certs/johnnyblabs.crt;
  ssl_certificate_key /etc/nginx/certs/johnnyblabs.key;
  
  location / {
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_pass http://<container-name>:<port>;
  }
}
```

#### WebSocket Support
Add for real-time services (Authentik, etc.):
```nginx
location /ws/ {
  proxy_pass http://<backend>;
  proxy_http_version 1.1;
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $connection_upgrade;
  # ... other headers
}
```

### Required Proxy Headers

All proxied locations MUST include:
- `proxy_set_header Host $host;`
- `proxy_set_header X-Real-IP $remote_addr;`
- `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`
- `proxy_set_header X-Forwarded-Proto (http|https);`

## Security Standards

### Secret Management

1. **Never commit secrets to git**
   - No `.env` files (only `.env.example`)
   - No `.key`, `.pem`, `.crt` files
   - No hardcoded passwords in any file

2. **Host storage**
   - Location: `/etc/homelab/secrets/<service>.env`
   - Permissions: `644` (readable by docker)
   - Owner: `root:root`

3. **Documentation**
   - Every service with secrets MUST have `.env.example`
   - Document all required variables
   - Include generation commands for secrets

### TLS Certificates

- Managed by: `acme.sh` with Cloudflare DNS-01 challenge
- Location: `/etc/nginx-docker/certs/`
- Permissions: 
  - Private keys (`.key`): `600`
  - Certificates (`.crt`, `.pem`): `644`
- Renewal: Automatic via cron (annual for Let's Encrypt)
- Never commit to git (only `.keep` placeholder)

### Firewall Rules

- Tool: UFW (Uncomplicated Firewall)
- Default: Deny incoming, allow outgoing
- Public ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- LAN-only ports: 53 (DNS), 222 (Forgejo SSH), 9090 (Cockpit), etc.
- Managed by: `ansible/roles/firewall/tasks/main.yml`
- Port registry: `ansible/inventory/group_vars/all.yml`

## Version Management

### Version Strategy Matrix

| Service Type | Strategy | Example | Update Schedule |
|-------------|----------|---------|-----------------|
| Critical Infrastructure | Pinned exact | `postgres:16.2.1` | Security only |
| Core Services | Major pinned | `nginx:1.29.4` | Quarterly |
| Applications | Version pinned | `bookstack:25.12.7` | Quarterly |
| Utilities | Latest (monitored) | `pihole:latest` | Monthly review |

### Update Process

1. Check upstream release notes
2. Update `docker-compose.yml` with new version
3. Update `HOMELAB_SPEC.yml` version matrix
4. Test with dry-run: `make ansible-dry-run`
5. Apply: `make ansible-apply`
6. Verify: `make homelab-status-verbose`
7. Monitor logs for issues
8. Commit changes with descriptive message

### Version Tracking

- Current versions tracked in: `HOMELAB_SPEC.yml` (legacy OpenAPI format)
- Check versions: `./scripts/check_versions.sh`
- Update schedule in spec
- Last checked date tracked

## Port Registry

### Single Source of Truth

File: `ansible/inventory/group_vars/all.yml`

```yaml
services:
  <service>:
    port: <number>          # Primary service port
    <protocol>_port: <num>  # Additional ports if needed
```

### Usage

- Referenced by Ansible firewall role
- Used in nginx upstream configurations
- Documented in service docker-compose.yml
- Prevents port conflicts

### Port Allocation

- 80, 443: nginx (public HTTP/HTTPS)
- 53: Pi-hole DNS
- 222: Forgejo SSH
- 5432: PostgreSQL (docker-network only)
- 9000: Authentik server (docker-network only)
- 9090: Cockpit (LAN only)
- 11434: Ollama (LAN only)

## Network Architecture

### Docker Network
- Name: `geek-infra`
- Type: External bridge network
- Created by: `docker_infra` Ansible role
- All services connect to this network

### Access Scopes

1. **Public** - Internet accessible via nginx HTTPS
   - Ports: 80, 443 only
   - Domains: `*.johnnyblabs.com`
   - TLS required

2. **LAN** - Local network only
   - Restricted by UFW to `192.168.1.0/24`
   - Domains: `*.geek`
   - HTTP acceptable

3. **Docker-network** - Container-to-container only
   - No host port exposure
   - DNS via container names
   - Most secure option (preferred)

4. **Localhost** - Host loopback only
   - Bound to `127.0.0.1`
   - SSH tunnel for remote access
   - Example: Pi-hole admin

### Domain Strategy

- Internal: `<service>.geek` → HTTP, LAN access
- Public: `<service>.johnnyblabs.com` → HTTPS, Internet access
- nginx handles routing for both domains
- DNS: Pi-hole for `.geek`, Cloudflare for `.johnnyblabs.com`

## Service Dependencies

### Dependency Order

1. **Infrastructure Layer**
   - `docker_infra` → Creates network
   - `nginx` → Reverse proxy
   - `postgres` → Shared database
   - `firewall` → Security rules

2. **Identity Layer**
   - `authentik` → SSO provider (depends on postgres)

3. **Application Layer**
   - `bookstack` → Wiki (depends on authentik for auth)
   - `forgejo` → Git (depends on postgres)
   - `woodpecker` → CI/CD (depends on forgejo)
   - `vaultwarden` → Password manager
   - `plane` → Project management (depends on postgres)

4. **Network Layer**
   - `pihole` → DNS/ad-blocking
   - `cloudflare_ddns` → Dynamic DNS updates
   - `landing` → Landing page

### Dependency Declaration

In Ansible `site.yml`, roles run in dependency order:
```yaml
roles:
  - role: firewall
  - role: nginx
  - role: docker_infra
  - role: postgres
  - role: authentik
  # ... applications depend on above
```

In Docker Compose, use `depends_on`:
```yaml
services:
  app:
    depends_on:
      - database
```

## Documentation Requirements

### Repository Level

Required files:
- `README.md` — Architecture, quick start, workflows
- `ADMIN.md` — Principles, non-negotiables
- `CHECKLIST.md` — Progress tracking
- `docs/ANSIBLE_DEPLOYMENT.md` — Deployment guide
- `docs/FIREWALL.md` — Firewall rules
- `docs/TLS_CERTIFICATES.md` — Certificate management

### Service Level

For each service in `platform/<service>/`:
- `docker-compose.yml` — Required
- `.env.example` — Required if using secrets
- `README.md` — Optional, for complex services
- Inline comments — Document non-obvious configuration

### Ansible Role Level

- Role purpose in comment at top of `tasks/main.yml`
- Document required secrets with helpful error messages
- Comment complex tasks
- Reference documentation in failure messages

## Backup Strategy

### Services Requiring Backup

- **postgres** → Database dumps via `pg_dump`
- **authentik** → Media, templates, database
- **bookstack** → Config, MariaDB data
- **forgejo** → Git repositories
- **vaultwarden** → Password vault data
- **pihole** → Configuration and blocklists

### Backup Standards

- Script location: `scripts/backup_*.sh`
- Backup destination: `/srv/homelab/backups/`
- Retention: 30 days (databases), 4 weeks (volumes)
- Testing: Restore test quarterly
- Documentation: `BACKUP.md`

### What NOT to Backup

- Logs
- Cache data
- Temporary files
- Recreatable data (pulled from upstream)

## Validation and Compliance

### Automated Checks

Scripts in `scripts/`:
- `validate_homelab.sh` — Full compliance validation
- `check_versions.sh` — Version currency check
- `generate_env_examples.sh` — Create missing examples

### Validation Categories

1. **Security** — No secrets in git, proper permissions
2. **Standards** — Docker Compose patterns followed
3. **Coverage** — All services have Ansible roles
4. **Documentation** — Required docs exist
5. **Versions** — Version strategy followed
6. **Consistency** — Naming, paths, patterns aligned

### Running Validation

```bash
# Full validation
./scripts/validate_homelab.sh

# Version check
./scripts/check_versions.sh

# Before deployment
make ansible-dry-run

# After deployment
make homelab-status-verbose
```

## Testing Procedures

### Pre-Deployment

1. **Syntax validation**
   ```bash
   # Ansible
   make ansible-dry-run
   
   # nginx
   make nginx-test
   
   # Docker Compose
   docker compose -f platform/<service>/docker-compose.yml config
   ```

2. **Compliance check**
   ```bash
   ./scripts/validate_homelab.sh
   ```

### Post-Deployment

1. **Service status**
   ```bash
   make homelab-status-verbose
   ```

2. **Health checks**
   ```bash
   # Individual service
   curl -H "Host: <service>.geek" http://geek/
   
   # All services
   make homelab-health
   ```

3. **Log review**
   ```bash
   make homelab-logs
   ```

## Change Management

### Workflow

1. Make changes locally in repository
2. Commit to git with descriptive message
3. Push to GitHub
4. Run Ansible dry-run to preview changes
5. Apply changes via Ansible
6. Verify deployment
7. Monitor for issues

### Rollback

If deployment fails:
```bash
# Git revert
git revert <commit-hash>
git push

# Or restore from backup
./scripts/restore_backup.sh <service> <backup-date>

# Emergency: manual intervention on host
ssh johnb@geek
cd ~/homelab-admin/platform/<service>
docker compose down
docker compose up -d
```

## Maintenance Schedule

### Daily
- Monitor service health (automated or manual check)

### Weekly
- Review logs for errors
- Check disk space on host

### Monthly
- Check for service updates (security patches)
- Review firewall logs
- Test backups

### Quarterly
- Update service versions (non-critical)
- Full backup restore test
- Review and update documentation
- Audit access controls

### Annually
- TLS certificate renewal (automated)
- Security audit
- Disaster recovery drill
- Review and cleanup deprecated services

## Non-Negotiable Rules

From `ADMIN.md`:

1. **This repo is source of truth** — Git = desired state, host = runtime state
2. **Secrets never enter git** — No passwords, tokens, keys, or certificates
3. **Changes must be reversible** — Every change deployable, testable, rollback-able
4. **Clarity beats cleverness** — If unsure, ask; don't guess infrastructure

## References

- Main documentation: `README.md`
- Admin principles: `ADMIN.md`
- Deployment guide: `docs/ANSIBLE_DEPLOYMENT.md`
- Firewall rules: `docs/FIREWALL.md`
- TLS management: `docs/TLS_CERTIFICATES.md`
- Port registry: `ansible/inventory/group_vars/all.yml`

## Compliance

All services and configurations MUST comply with this specification. Use validation scripts to verify compliance before deployment.

