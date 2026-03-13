## Purpose

Defines the required conventions for all homelab services: Docker Compose structure, container naming, networking, secrets handling, volume paths, nginx ingress, and Ansible role standards.

## Requirements

### Requirement: All services SHALL connect to the geek-infra Docker network
Every service in the homelab stack SHALL declare the `geek-infra` external Docker network in its `docker-compose.yml`. No service SHALL create its own isolated network as primary communication layer.

#### Scenario: Service network configuration
- **WHEN** a docker-compose.yml is reviewed
- **THEN** the service SHALL list `geek-infra` under `networks:`
- **THEN** the networks section SHALL declare `geek-infra` as `external: true`

### Requirement: All services SHALL use the unless-stopped restart policy
Every container in the homelab stack SHALL specify `restart: unless-stopped`. No other restart policy is permitted.

#### Scenario: Restart policy check
- **WHEN** a docker-compose.yml is reviewed
- **THEN** every service SHALL have `restart: unless-stopped`

### Requirement: Container names SHALL be lowercase and hyphenated
Container names SHALL follow the pattern `<scope>-<service>` or `<service>` in lowercase with hyphens. No underscores, uppercase, or spaces.

#### Scenario: Container naming
- **WHEN** a container_name is set in docker-compose.yml
- **THEN** the name SHALL match `^[a-z][a-z0-9-]+$`

### Requirement: Secrets SHALL be loaded via env_file from /etc/homelab/secrets/
Service secrets SHALL be injected using `env_file: /etc/homelab/secrets/<service>.env`. Secret values SHALL NOT appear in docker-compose.yml, environment blocks, or the git repository.

#### Scenario: Service secrets configuration
- **WHEN** a service requires secrets
- **THEN** docker-compose.yml SHALL reference `env_file: /etc/homelab/secrets/<service>.env`
- **THEN** the repo SHALL contain only a `.env.example` file with placeholder values

### Requirement: Persistent data SHALL be stored under /srv/homelab/<service>/
All persistent container volumes SHALL mount host paths under `/srv/homelab/<service>/`. Temporary or runtime data MAY use named volumes.

#### Scenario: Volume path convention
- **WHEN** a service mounts a persistent volume
- **THEN** the host path SHALL begin with `/srv/homelab/<service>/`

### Requirement: nginx SHALL be the sole ingress point
No service SHALL expose ports directly to the public internet. All HTTP/HTTPS traffic SHALL be routed through the `geek-nginx` reverse proxy. Services expose ports only to the Docker network or localhost.

#### Scenario: Service port exposure
- **WHEN** a service needs to be accessible via a browser
- **THEN** an nginx vhost SHALL be created in `platform/ingress/nginx/etc-nginx-docker/conf.d/`
- **THEN** the service SHALL NOT bind to `0.0.0.0:<port>` unless it is nginx itself or a LAN-only service with UFW protection

### Requirement: nginx conf.d files SHALL use numbered prefixes for load order
nginx virtual host configurations SHALL be named `NN_<fqdn>.conf` where `NN` is a two-digit number controlling load order.

#### Scenario: nginx config file naming
- **WHEN** a new nginx vhost config is created
- **THEN** the filename SHALL match `^[0-9]{2}_[a-z0-9._-]+\.conf$`
- **THEN** the file SHALL be placed in `platform/ingress/nginx/etc-nginx-docker/conf.d/`

### Requirement: Ansible roles SHALL be idempotent and validate secrets before deploying
Every Ansible role SHALL check that its secrets file exists before attempting deployment. Running the role multiple times SHALL produce the same result.

#### Scenario: Role run with missing secrets
- **WHEN** an Ansible role runs and the secrets file is absent
- **THEN** the role SHALL fail with a descriptive error message before attempting any deployment

#### Scenario: Idempotent role execution
- **WHEN** an Ansible role runs with no changes required
- **THEN** all tasks SHALL report `ok` with `changed=0`

### Requirement: All ports SHALL be registered in the Ansible group_vars port registry
Every port used by any service SHALL be declared in `ansible/inventory/group_vars/all.yml`. This is the single source of truth for port assignments across firewall rules, nginx configs, and docker-compose files.

#### Scenario: New service port registration
- **WHEN** a new service exposes a port
- **THEN** the port SHALL be added to `ansible/inventory/group_vars/all.yml` before deployment
- **THEN** the UFW firewall rule SHALL reference the registry variable, not a hardcoded number
