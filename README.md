# Homelab Admin

Infrastructure-as-code for a personal homelab running on host `geek`. This repository contains Docker Compose configurations, nginx reverse proxy settings, and operational runbooks for managing a self-hosted platform with identity management, data services, and web applications.

## 🎯 Purpose

This repository serves as the **source of truth** for homelab infrastructure on the `geek` host. It manages:

- **Identity & Authentication**: Authentik SSO for unified authentication across services
- **Reverse Proxy & TLS**: nginx-based ingress with HTTPS termination
- **Data Services**: Shared PostgreSQL and Redis instances
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
    │  - Redis:6379        │
    └──────────────────────┘

All services communicate over the geek-infra Docker network
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
    └── sync_nginx_from_host.sh # Sync live nginx config to repo
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

3. **Start data services first** (PostgreSQL and Redis):
   ```bash
   cd platform/postgres
   docker-compose up -d
   
   cd ../redis
   docker-compose up -d
   ```

4. **Start Authentik** (requires PostgreSQL and Redis):
   ```bash
   cd ../authentik
   # Set required environment variable
   export AUTHENTIK_OUTPOST_TOKEN="your-token-here"
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
# Test configuration
make nginx-test

# Reload nginx (after config changes)
make nginx-reload

# Sync live config to repo
./scripts/sync_nginx_from_host.sh

# View differences between repo and live config
make diff-nginx
```

### Authentik Identity Provider

- **Containers**: 
  - `authentik-server` (UI/API on port 9000)
  - `authentik-worker` (background tasks)
  - `authentik-outpost` (forward auth proxy)
- **Image**: `ghcr.io/goauthentik/server:latest`
- **Dependencies**: PostgreSQL, Redis
- **Features**:
  - Single Sign-On (SSO) for all services
  - Forward authentication for nginx-protected apps
  - LDAP/SAML/OAuth support

**Configuration**:
- Requires `AUTHENTIK_OUTPOST_TOKEN` environment variable
- PostgreSQL database: `authentik`
- Accessible at `http://auth.geek` (internal) and `https://auth.johnnyblabs.com` (public)

### PostgreSQL Database

- **Container**: `geek-postgres`
- **Image**: `postgres:16`
- **Data**: Persisted in `./pgdata/` (gitignored)
- **Default Credentials**: See `docker-compose.yml` (change in production!)
- **Network**: Only accessible within `geek-infra` network (no external ports)

**Databases**:
- `postgres` (default)
- `authentik` (for Authentik)

### Redis Cache

- **Container**: `geek-redis`
- **Image**: `redis:7`
- **Data**: Persisted in `./data/` with AOF (Append-Only File)
- **Network**: Only accessible within `geek-infra` network

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

The live nginx configuration at `/etc/nginx-docker` is treated as the **live state**. This repo mirrors it for version control:

1. Make changes to `/etc/nginx-docker` on the host
2. Test with `make nginx-test`
3. Apply with `make nginx-reload`
4. Sync to repo with `./scripts/sync_nginx_from_host.sh`
5. Commit and push changes

The sync script automatically excludes private keys.

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
3. If valid, reload nginx:
   ```bash
   make nginx-reload
   ```
4. Sync the changes to the repository:
   ```bash
   ./scripts/sync_nginx_from_host.sh
   ```
5. Commit and push to version control

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

# Redis
docker exec geek-redis redis-cli BGSAVE
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

```bash
make nginx-test      # Test nginx configuration syntax
make nginx-reload    # Test and reload nginx (graceful)
make backup-nginx    # Sync live config to backup directory
make diff-nginx      # Show differences between backup and live config
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
