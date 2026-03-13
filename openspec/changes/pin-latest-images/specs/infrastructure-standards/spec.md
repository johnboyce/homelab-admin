## MODIFIED Requirements

### Requirement: Image version pinning policy
All services in the homelab stack SHALL use explicit image version tags. The `:latest` tag MUST NOT be used for any service that holds state or is security-sensitive. Stateless utility services MAY use `:latest` only when explicitly justified in the service inventory.

Previously: "Version pinning preferred" (advisory)
Now: "Version pinning required for stateful and security-sensitive services" (normative)

#### Scenario: Stateful service version tag
- **WHEN** a docker-compose.yml is reviewed for a stateful service (databases, auth, password manager, git, CI, wiki, project management)
- **THEN** the `image:` field SHALL specify an explicit version (e.g., `vaultwarden/server:1.35.4`)
- **THEN** the `image:` field SHALL NOT contain `:latest`

#### Scenario: New service is added to the stack
- **WHEN** a new service is added via docker-compose.yml
- **THEN** the image tag SHALL be pinned to a specific version before the PR is merged
- **THEN** the version SHALL be documented in service-inventory.md
