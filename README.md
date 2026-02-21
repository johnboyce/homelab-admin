# Homelab Admin

Infrastructure-as-code for a personal homelab running on host `geek`. This repository contains Docker Compose configurations, nginx reverse proxy settings, and operational runbooks for managing a self-hosted platform with identity management, data services, and web applications.

## 🎯 Purpose

This repository serves as the **source of truth** for homelab infrastructure on the `geek` host. It manages:

- **Identity & Authentication**: Authentik SSO for unified authentication across services
- **Reverse Proxy & TLS**: nginx-based ingress with HTTPS termination
- **Data Services**: Shared PostgreSQL instance (Redis optional for other services)
- **Configuration Management**: Version-controlled configs with safe secret handling

The setup supports both internal `.geek` domains for LAN access and public `johnnyblabs.com` domains with TLS for internet-facing services.

## 🏗️ Architecture

### Service Stack

```
┌─────────────────────────────────────────────────────────┐
│                     nginx (geek-nginx)                  │
│          Reverse Proxy + TLS Termination                │
│   Ports: 80 (HTTP), 443 (HTTPS)                         │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌──────▼──────┐  ┌─────────▼─────────┐
│   Authentik    │  │  BookStack  │  │  Other Services   │
│   (Identity)   │  │    (Docs)   │  │                   │
│                │  │             │  │                   │
│ - Server:9000  │  │             │  │                   │
│ - Worker       │  │             │  │                   │
│ - Outpost      │  │             │  │                   │
└────────────────┘  └─────────────┘  └───────────────────┘
        │                   │
        └───────┬───────────┘
                │
    ┌───────────▼──────────┐
    │  Shared Services     │
    │                      │
    │  - PostgreSQL:5432   │
    │  - Redis:6379 *      │
    └──────────────────────┘

All services communicate over the geek-infra Docker network

* Redis is optional - no longer required by authentik 2025.8+
  May be used by other services in the future
```

### Network Design

- **Docker Network**: All services run on the `geek-infra` external network
- **Internal Domains**: `*.geek` (e.g., `auth.geek`, `bookstack.geek`) for LAN access via HTTP
- **Public Domains**: `*.johnnyblabs.com` with HTTPS/TLS for internet access
- **No Direct Port Exposure**: Most services only accessible through nginx reverse proxy (more secure)

## 📁 Repository Structure

```
.
├── ADMIN.md                    # Internal documentation and non-negotiables
├── Makefile                    # nginx testing and sync utilities
├── platform/
│   ├── authentik/              # Authentik SSO setup
│   │   ├── docker-compose.yml  # Server, worker, and outpost containers
│   │   └── authentik_inspect.sh # API inspection script
│   ├── ingress/
│   │   └── nginx/
│   │       └── etc-nginx-docker/  # Mirror of /etc/nginx-docker from host
│   │           ├── nginx.conf
│   │           ├── sites-available/
│   │           │   ├── auth.geek.conf
│   │           │   ├── bookstack.geek.conf
│   │           │   └── ...
│   │           └── geek/
│   │               └── snippets/  # Reusable nginx config snippets
│   ├── nginx/                  # nginx reverse proxy setup
│   │   └── docker-compose.yml
│   ├── postgres/               # Shared PostgreSQL database
│   │   └── docker-compose.yml
│   └── redis/                  # Shared Redis cache
│       └── docker-compose.yml
└── scripts/
    ├── nginx_import_from_host.sh # Emergency: import live config to repo
    └── nginx_deploy_to_host.sh   # Normal: deploy repo config to host
```

### Key Directories

- **`platform/`**: All service Docker Compose configurations organized by function
- **`platform/ingress/nginx/etc-nginx-docker/`**: Version-controlled mirror of live nginx configuration
- **`scripts/`**: Automation and maintenance utilities

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Root/sudo access on the host machine
- External Docker network created: `docker network create geek-infra`

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/johnboyce/homelab-admin.git
   cd homelab-admin
   ```

2. **Create the Docker network** (if not already created):
   ```bash
   docker network create geek-infra
   ```

3. **Start data services first** (PostgreSQL):
   ```bash
   cd platform/postgres
   docker-compose up -d
   ```
   
   **Note**: Redis is optional. Authentik 2025.8+ no longer requires Redis. If you have other services that need Redis, you can start it:
   ```bash
   cd ../redis
   docker-compose up -d
   ```

4. **Start Authentik** (requires PostgreSQL):
   ```bash
   cd ../authentik
   # Copy and configure environment variables
   cp .env.example .env
   # Edit .env and set:
   #   AUTHENTIK_SECRET_KEY (long random string)
   #   AUTHENTIK_POSTGRESQL__PASSWORD (authentik database password - note double underscores)
   #   AUTHENTIK_OUTPOST_TOKEN (outpost authentication token)
   docker-compose up -d
   ```

5. **Configure nginx**:
   - Ensure `/etc/nginx-docker/` exists on the host
   - Copy configs from `platform/ingress/nginx/etc-nginx-docker/` to `/etc/nginx-docker/`
   - Add TLS certificates to `/etc/nginx-docker/certs/` (private keys are NOT in this repo)

6. **Start nginx**:
   ```bash
   cd ../nginx
   docker-compose up -d
   ```

7. **Test nginx configuration**:
   ```bash
   make nginx-test
   ```

8. **Verify services**:
   ```bash
   # Check Authentik is accessible
   curl -Ik http://auth.geek
   curl -Ik https://auth.johnnyblabs.com
   
   # Check BookStack (if configured)
   curl -Ik https://bookstack.johnnyblabs.com
   ```

## 📚 Documentation & Operational Guides

This repository includes comprehensive documentation for setup, maintenance, and troubleshooting:

| Document | Purpose |
|----------|---------|
| **[CLAUDE.md](CLAUDE.md)** | AI assistant guidance (architecture, workflows, conventions) |
| **[ADMIN.md](ADMIN.md)** | Operational rules and non-negotiables |
| **[docs/FIREWALL.md](docs/FIREWALL.md)** | UFW firewall rules, security policies, LAN vs WAN access |
| **[docs/BACKUP.md](docs/BACKUP.md)** | PostgreSQL backup automation, recovery procedures, disaster recovery |
| **[platform/ingress/nginx/README.md](platform/ingress/nginx/README.md)** | nginx configuration inventory, vhost structure, TLS management |

### Make Targets for Operations

Quick access to common tasks:

```bash
# Nginx Management
make nginx-test                  # Test nginx syntax without reload
make nginx-reload                # Test and gracefully reload nginx
make nginx-deploy                # Deploy repo config to geek host
make nginx-import                # Import live config from host (emergency)

# Service Monitoring
make homelab-status              # Quick status check (container state, services)
make homelab-status-verbose      # Status + connectivity tests to all services
make homelab-health              # Full health checks including Docker info
make homelab-logs                # Show recent logs from all services

# Data Protection
make homelab-backup              # Create PostgreSQL backup
make homelab-backup-list         # List available backups
make homelab-backup-restore FILE=<backup> # Restore from backup

# Infrastructure Setup
make setup-firewall              # Configure UFW firewall rules (runs on geek host)
```

## 🔧 Service Details

### nginx Reverse Proxy

- **Container**: `geek-nginx`
- **Image**: `nginx:1.25`
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Config Location**: `/etc/nginx-docker` (mounted read-only)
- **Features**:
  - TLS termination with custom certificates
  - HTTP to HTTPS redirects
  - Dual domain support (internal `.geek` and public `.johnnyblabs.com`)
  - Forward authentication integration with Authentik

**Common Commands**:
```bash
# Test nginx configuration
make nginx-test

# Reload nginx (after config changes)
make nginx-reload

# Deploy repo config to host (normal workflow)
make nginx-deploy

# Import live config from host (emergency only)
make nginx-import
```

### Authentik Identity Provider

- **Containers**: 
  - `authentik-server` (UI/API on port 9000)
  - `authentik-worker` (background tasks)
  - `authentik-outpost` (forward auth proxy)
- **Image**: `ghcr.io/goauthentik/server:2025.10.3`
- **Dependencies**: PostgreSQL only (Redis removed in 2025.8+)
- **Features**:
  - Single Sign-On (SSO) for all services
  - Forward authentication for nginx-protected apps
  - LDAP/SAML/OAuth support

**Configuration**:
- See `platform/authentik/.env.example` for required environment variables
- Required variables:
  - `AUTHENTIK_SECRET_KEY`: Long random string for encryption
  - `AUTHENTIK_POSTGRESQL__PASSWORD`: Password for authentik database user (note double underscores)
  - `AUTHENTIK_OUTPOST_TOKEN`: Token for outpost authentication
- PostgreSQL database: `authentik`
- Accessible at `http://auth.geek` (internal) and `https://auth.johnnyblabs.com` (public)

**Version Notes**:
- **2025.8+**: Redis dependency removed. Authentik now uses PostgreSQL for all caching, tasks, WebSocket connections, and the embedded outpost session store.
- **Current Version**: 2025.10.3
- **Migration Impact**: Expect ~50% more PostgreSQL connections compared to Redis-based versions.
- **Configuration**: All Redis-related settings (`AUTHENTIK_REDIS__HOST`, etc.) have been removed.

### PostgreSQL Database

- **Container**: `geek-postgres`
- **Image**: `postgres:16`
- **Data**: Persisted in `./pgdata/` (gitignored)
- **Default Credentials**: See `docker-compose.yml` (change in production!)
- **Network**: Only accessible within `geek-infra` network (no external ports)

**Databases**:
- `postgres` (default)
- `authentik` (for Authentik)

### Redis Cache (Optional)

- **Container**: `geek-redis`
- **Image**: `redis:7`
- **Data**: Persisted in `./data/` with AOF (Append-Only File)
- **Network**: Only accessible within `geek-infra` network
- **Status**: No longer required by authentik 2025.8+. Available for other services that may need caching/queuing.

## 🔒 Security Practices

### Secret Management

**CRITICAL**: This repository follows strict security practices:

- ❌ **NEVER** commit secrets, tokens, private keys, or real passwords
- ✅ Use `.env.example` files with placeholders
- ✅ Actual secrets are managed outside of version control
- ✅ TLS certificate private keys (`.key`, `.pem`) are excluded via `.gitignore`

### What's NOT in Git

Per `.gitignore`:
- `*.env` files (except `.env.example`)
- `*.key`, `*.pem` (TLS private keys)
- `**/pgdata/`, `**/data/` (service data directories)
- `**/secrets/`, `**/*private*`, `**/*secret*`

### TLS Certificates

- **Public certificates** (`.crt`): Safe to commit (they're public anyway)
- **Private keys** (`.key`): NEVER commit, keep only on the host
- **Location**: `/etc/nginx-docker/certs/` on host

### Configuration Sync

This repository contains the **desired state** for nginx configuration. The normal workflow is **repo → host**:

1. Edit configuration files in `platform/ingress/nginx/etc-nginx-docker/`
2. Commit changes to version control
3. Deploy to host with `make nginx-deploy`
4. The deploy script will test configuration and prompt for reload

**Exception**: Emergency hotfixes made directly on the host should be captured with `make nginx-import` and then committed to the repo. This is not the normal workflow.

All scripts automatically exclude certificate private keys from syncing.

## 🔄 Common Workflows

### Adding a New Service

1. Create a new directory under `platform/`
2. Add a `docker-compose.yml` with the service definition
3. Ensure the service uses the `geek-infra` network
4. Add nginx reverse proxy configuration in `platform/ingress/nginx/etc-nginx-docker/sites-available/`
5. Enable the site by creating a symlink in `sites-enabled/` (on the host)
6. Test nginx config: `make nginx-test`
7. Reload nginx: `make nginx-reload`
8. Update documentation

### Updating nginx Configuration

1. Edit config in `/etc/nginx-docker/` on the host
2. Test the configuration:
   ```bash
   make nginx-test
   ```
3. Commit the changes to version control
4. Deploy to the host:
   ```bash
   make nginx-deploy
   ```
   This will test the configuration and prompt for reload

### Adding Forward Authentication to a Service

1. See `platform/ingress/nginx/etc-nginx-docker/sites-available/bookstack.geek.conf` as a template
2. Add the `/_ak/auth` internal location for the auth subrequest
3. Add the `@ak_start` error handler for redirecting to Authentik
4. Add `auth_request /_ak/auth;` and `error_page 401 = @ak_start;` to protected locations
5. Configure the application in Authentik UI as a new Provider/Application
6. Test end-to-end authentication flow

### Backing Up Data

Data directories are gitignored but should be backed up regularly:

```bash
# PostgreSQL
docker exec geek-postgres pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql

# Redis (if using)
docker exec geek-redis redis-cli BGSAVE
```

### Upgrading Authentik

**Important**: Authentik 2025.8+ removed the Redis dependency. 

**For detailed upgrade instructions**, see [AUTHENTIK_UPGRADE.md](AUTHENTIK_UPGRADE.md) for a comprehensive step-by-step guide including:
- Pre-upgrade checklist and backups
- Detailed upgrade steps
- Post-upgrade Redis cleanup options
- Troubleshooting and rollback procedures

**Quick upgrade** (if you've already upgraded before):

1. **Backup your data first**:
   ```bash
   docker exec geek-postgres pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql
   ```

2. **Deploy the upgrade**:
   ```bash
   make deploy-authentik
   ```
   
   This will:
   - Pull the new authentik images (2025.10.3)
   - Restart authentik services
   - Display status and verification URLs

3. **Verify the upgrade**:
   ```bash
   # Check container status
   docker ps | grep authentik
   
   # Check logs for errors
   docker logs authentik-server
   docker logs authentik-worker
   
   # Test web access
   curl -Ik https://auth.geek
   curl -Ik https://auth.johnnyblabs.com
   ```

4. **Post-upgrade notes**:
   - Authentik now uses ~50% more PostgreSQL connections (migrated from Redis)
   - All Redis-related environment variables have been removed
   - If no other services use Redis, it can be stopped to free resources (see [AUTHENTIK_UPGRADE.md](AUTHENTIK_UPGRADE.md))

**Rollback**: If issues occur, restore from backup:
```bash
# Stop authentik
cd platform/authentik && docker-compose down

# Restore database
cat authentik-backup-YYYYMMDD.sql | docker exec -i geek-postgres psql -U authentik -d authentik

# Revert to previous version in docker-compose.yml and restart
```

## 🛠️ Troubleshooting

### nginx Won't Start

```bash
# Check configuration syntax
make nginx-test

# View nginx error logs
docker logs geek-nginx

# Check if ports 80/443 are already in use
sudo netstat -tulpn | grep -E ':(80|443)'
```

### Authentik Database Connection Issues

```bash
# Verify PostgreSQL is running
docker ps | grep postgres

# Check Authentik logs
docker logs authentik-server
docker logs authentik-worker

# Test database connectivity
docker exec -it geek-postgres psql -U authentik -d authentik
```

### Forward Auth Not Working

```bash
# Check Authentik outpost is running
docker ps | grep authentik-outpost
docker logs authentik-outpost

# Verify the outpost token is set
echo $AUTHENTIK_OUTPOST_TOKEN

# Check nginx can reach the outpost
docker exec -it geek-nginx curl -I http://authentik-outpost:9000/outpost.goauthentik.io/ping
```

### SSL/TLS Certificate Issues

```bash
# Verify certificate files exist
ls -la /etc/nginx-docker/certs/

# Check certificate expiration
openssl x509 -in /etc/nginx-docker/certs/johnnyblabs.crt -noout -enddate

# Validate certificate and key match
openssl x509 -noout -modulus -in /etc/nginx-docker/certs/johnnyblabs.crt | openssl md5
openssl rsa -noout -modulus -in /etc/nginx-docker/certs/johnnyblabs.key | openssl md5
```

### Checking Service Logs

```bash
# All services at once
docker-compose logs -f

# Specific service
docker logs -f geek-nginx
docker logs -f authentik-server
docker logs -f geek-postgres
docker logs -f geek-redis
```

## 📋 Makefile Targets

> **Shell Compatibility**: All Makefile targets work with any shell (zsh, bash, fish, etc.). Commands that require bash-specific features explicitly invoke bash internally.

```bash
make nginx-test        # Test nginx configuration syntax
make nginx-reload      # Test and reload nginx (graceful)
make nginx-deploy      # Deploy repo config to host (normal workflow)
make nginx-import      # Import live config from host (emergency only)
make deploy-authentik  # Deploy authentik upgrades to geek host
```

## 🔗 Related Documentation

- **ADMIN.md**: Internal documentation with strict operational rules and non-negotiables
- **Authentik Documentation**: https://goauthentik.io/docs/
- **nginx Documentation**: https://nginx.org/en/docs/

## 📝 Notes

- **Host**: `geek` - the physical/VM host running all services
- **Domain Strategy**: 
  - Internal LAN: `*.geek` (HTTP only, faster for internal use)
  - Public Internet: `*.johnnyblabs.com` (HTTPS with TLS)
- **Philosophy**: Incremental, reversible changes. Always verify before committing.
- **Test Commands**: Every change should include verification commands (see ADMIN.md)

## 🤝 Contributing

This is a personal homelab repository. Changes should be:
- **Minimal**: Only change what's necessary
- **Incremental**: Make small, testable changes
- **Reversible**: Always have a rollback plan
- **Documented**: Update docs when changing DNS/TLS/ingress
- **Verified**: Include test/verification commands with every change

## 📜 License

This is personal infrastructure configuration. Use at your own risk. No warranty provided.
