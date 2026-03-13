## ADDED Requirements

### Requirement: All stateful services SHALL pin image versions
Every service that stores data or holds state SHALL specify an explicit image version tag in its docker-compose.yml. The `:latest` tag MUST NOT be used for stateful services.

Stateful services include: databases, password managers, wikis, project management tools, git servers, CI servers.

#### Scenario: Stateful service has pinned version
- **WHEN** a docker-compose.yml is reviewed for a stateful service
- **THEN** the `image:` field SHALL contain a specific version tag (e.g., `1.35.4`, `2025.11.1`)
- **THEN** the `image:` field SHALL NOT contain `:latest`

### Requirement: Stateless utilities MAY use latest with justification
Stateless, idempotent services with no persistent data MAY use `:latest` if a justification is documented in the service inventory. Such services SHALL be reviewed quarterly.

#### Scenario: Stateless utility uses latest with documentation
- **WHEN** a stateless service uses `:latest`
- **THEN** the service-inventory.md entry SHALL document the justification
- **THEN** the service SHALL be flagged for quarterly version review

### Requirement: Current pinned versions SHALL be tracked in service-inventory
The `openspec/specs/service-inventory.md` SHALL contain the current pinned version and version policy for every service. This is the single source of truth for what version is deployed.

#### Scenario: Service version is updated
- **WHEN** a service image version is changed in docker-compose.yml
- **THEN** service-inventory.md SHALL be updated in the same commit
- **THEN** HOMELAB_SPEC.yml version matrix SHALL be updated in the same commit

### Requirement: Version upgrades SHALL go through the change workflow
Intentional version upgrades for pinned services SHALL be proposed as an openspec change. The change SHALL include: current version, target version, release notes reviewed, rollback procedure.

#### Scenario: Service upgrade is proposed
- **WHEN** a service version upgrade is needed
- **THEN** an openspec change SHALL be created via `/opsx:propose`
- **THEN** the proposal SHALL reference upstream release notes
- **THEN** the tasks SHALL include a rollback step

### Requirement: Pinned versions SHALL match the running container
After any deployment, the version tag in docker-compose.yml SHALL match the version label reported by the running container (`org.opencontainers.image.version` label or equivalent).

#### Scenario: Deployment verification
- **WHEN** a service is deployed with a pinned version
- **THEN** `docker inspect <container> | jq '.[0].Config.Labels["org.opencontainers.image.version"]'` SHALL return the expected version

### Requirement: Pin-time upgrades SHALL be limited to minor or patch versions
When pinning a service that is behind on minor or patch versions, upgrading to the latest stable at pin time is acceptable. Major version upgrades SHALL NOT be combined with a pin-only change — they require a dedicated openspec change with release notes review.

#### Scenario: Safe upgrade at pin time
- **WHEN** a service using `:latest` is behind by a minor or patch version
- **THEN** the service MAY be upgraded to latest stable as part of the pinning change
- **THEN** the design document SHALL record the running version, the target version, and the rationale

#### Scenario: Major version upgrade blocked from pin-only change
- **WHEN** a service using `:latest` is behind by a major version
- **THEN** the service SHALL be pinned to its currently-running version
- **THEN** a separate openspec change SHALL be proposed for the major version upgrade
