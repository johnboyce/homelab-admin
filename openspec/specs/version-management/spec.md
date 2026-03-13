## Purpose

Defines how Docker image versions are managed across the homelab stack: pinning requirements, the version registry, the upgrade workflow, and what's permitted at pin time.

## Requirements

### Requirement: Stateful services SHALL use pinned image versions
Every service that stores data or holds security-sensitive state SHALL specify an explicit version tag in its `docker-compose.yml`. The `:latest` tag MUST NOT be used for stateful or security-sensitive services.

#### Scenario: Stateful service has explicit version tag
- **WHEN** a docker-compose.yml is reviewed for a stateful service
- **THEN** the `image:` field SHALL contain a specific version (e.g., `1.35.4`, `2026.02.0`)
- **THEN** the `image:` field SHALL NOT contain `:latest`

#### Scenario: New service added to the stack
- **WHEN** a new service docker-compose.yml is created
- **THEN** the image tag SHALL be pinned before the PR is merged
- **THEN** the version SHALL be documented in `openspec/specs/service-inventory/spec.md`

### Requirement: Stateless utilities using latest SHALL document justification
Stateless, idempotent services with no persistent data MAY use `:latest` only if a justification is documented in the service inventory spec. Undocumented use of `:latest` SHALL be treated as a compliance failure.

#### Scenario: Stateless utility using latest
- **WHEN** a stateless service uses `:latest`
- **THEN** the `openspec/specs/service-inventory/spec.md` entry SHALL document the justification
- **THEN** the service SHALL be reviewed quarterly

### Requirement: Current versions SHALL be tracked in service-inventory spec
The service inventory spec SHALL record the current pinned version for every service. This is the single source of truth for deployed versions.

#### Scenario: Version updated
- **WHEN** a service image tag is changed in docker-compose.yml
- **THEN** `openspec/specs/service-inventory/spec.md` SHALL be updated in the same commit
- **THEN** `HOMELAB_SPEC.yml` version matrix SHALL be updated in the same commit

### Requirement: Version upgrades SHALL go through the openspec change workflow
Intentional version upgrades for pinned services SHALL be proposed as an openspec change. The change SHALL document: current version, target version, upstream release notes reviewed, and rollback procedure.

#### Scenario: Service upgrade is proposed
- **WHEN** a service version upgrade is planned
- **THEN** an openspec change SHALL be created via `/opsx:propose`
- **THEN** the design.md SHALL include the version audit table (running vs latest stable)
- **THEN** the tasks.md SHALL include a rollback task

### Requirement: Pin-time upgrades SHALL be limited to minor or patch versions
When eliminating a `:latest` tag, upgrading to a newer minor or patch version at the same time is acceptable. Major version upgrades SHALL NOT be bundled into a pin-only change.

#### Scenario: Safe upgrade at pin time
- **WHEN** a service using `:latest` is behind by a minor or patch version
- **THEN** the service MAY be upgraded to latest stable in the same change
- **THEN** the design.md SHALL record the running version, target version, and rationale

#### Scenario: Major upgrade deferred from pin-only change
- **WHEN** a service using `:latest` is behind by a major version
- **THEN** the service SHALL be pinned to its currently-running version only
- **THEN** a separate openspec change SHALL be proposed for the major version upgrade

### Requirement: Pinned versions SHALL match the running container after deployment
After deployment, the image tag in docker-compose.yml SHALL match the version label of the running container.

#### Scenario: Post-deployment verification
- **WHEN** a service is deployed with a pinned version tag
- **THEN** `docker inspect <container> | jq '.[0].Config.Image'` SHALL return the expected tag
