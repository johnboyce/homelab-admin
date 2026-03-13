## Purpose

Defines the completeness requirements for service management: every service must have a compose file, an Ansible role, a secrets example, and a pinned version tracked in this spec.

## Requirements

### Requirement: Every deployed service SHALL have a docker-compose.yml in platform/
Each service managed by this repository SHALL have a corresponding `platform/<service>/docker-compose.yml`. Services using third-party deployment tools (e.g., Plane official CLI) SHALL be documented with a reference compose file noting the actual deployment location.

#### Scenario: Service has compose file
- **WHEN** a service is deployed to geek
- **THEN** `platform/<service>/docker-compose.yml` SHALL exist in the repository
- **THEN** the compose file SHALL be the authoritative definition of that service's configuration

### Requirement: Every deployed service SHALL have an Ansible role
Each service SHALL have a corresponding Ansible role at `ansible/roles/<service>/`. The role SHALL be included in `ansible/playbooks/site.yml`.

#### Scenario: Service has Ansible role
- **WHEN** a service is deployed
- **THEN** `ansible/roles/<service>/tasks/main.yml` SHALL exist
- **THEN** the role SHALL appear in `ansible/playbooks/site.yml`

### Requirement: Every service SHALL have a .env.example file
Each service with secrets SHALL have a `.env.example` file at `platform/<service>/.env.example` documenting all required environment variables with placeholder values.

#### Scenario: env.example completeness
- **WHEN** a `.env.example` is reviewed
- **THEN** all variables referenced in the service's docker-compose.yml `environment:` or `env_file:` blocks SHALL have corresponding entries

### Requirement: Service versions SHALL be pinned and documented
The current deployed version of each service SHALL be documented. Services using `:latest` SHALL be flagged for remediation.

#### Scenario: Service version documented
- **WHEN** this spec is current
- **THEN** every service entry SHALL include the current pinned version tag

### Requirement: Current service versions SHALL be tracked in this registry
The following versions are pinned and deployed as of 2026-03-12. This table MUST be updated whenever a service version changes:

| Service | Image | Pinned Version | Version Policy |
|---------|-------|---------------|---------------|
| nginx | `nginx` | `1.29.4` | major-pinned |
| postgres | `postgres` | `16` | major-pinned |
| authentik server | `ghcr.io/goauthentik/server` | `2025.10.4` | pinned |
| authentik worker | `ghcr.io/goauthentik/server` | `2025.10.4` | pinned |
| bookstack | `lscr.io/linuxserver/bookstack` | `25.12.7` | pinned |
| forgejo | `codeberg.org/forgejo/forgejo` | `14` | major-rolling |
| forgejo-runner | `code.forgejo.org/forgejo/runner` | `12` | major-rolling |
| woodpecker-server | `woodpeckerci/woodpecker-server` | `2.8.3` | pinned (v3 upgrade pending) |
| woodpecker-agent | `woodpeckerci/woodpecker-agent` | `2.8.3` | pinned (v3 upgrade pending) |
| vaultwarden | `vaultwarden/server` | `1.35.4` | pinned |
| pihole | `pihole/pihole` | `2026.02.0` | pinned |
| ollama | `ollama/ollama` | `0.17.7` | pinned |
| cloudflare-ddns | `favonia/cloudflare-ddns` | `1.15.1` | pinned |
| plane | official CLI deployment | `latest` ⚠️ | unmanaged (see CHG-2026-002) |

#### Scenario: All stateful services are pinned
- **WHEN** all docker-compose.yml files are reviewed
- **THEN** every stateful service SHALL have an explicit version tag
- **THEN** no stateful service SHALL use `:latest`
