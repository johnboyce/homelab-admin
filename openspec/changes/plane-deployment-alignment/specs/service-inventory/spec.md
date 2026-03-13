## MODIFIED Requirements

### Requirement: Current service versions SHALL be tracked in this registry
The following versions are pinned and deployed as of 2026-03-12. This table MUST be updated whenever a service version changes:

| Service | Image | Pinned Version | Version Policy | Notes |
|---------|-------|---------------|---------------|-------|
| plane | official CLI deployment | `latest` ⚠️ | unmanaged | Official community CLI at `/srv/homelab/plane-official/`. Pinning tracked in this change. |

The Plane service SHALL be documented as using the official community CLI deployment at `/srv/homelab/plane-official/deployments/cli/community/plane-app/`, NOT the custom compose at `platform/plane/docker-compose.yml`.

#### Scenario: Plane deployment path is documented correctly
- **WHEN** the service-inventory spec is reviewed
- **THEN** the Plane entry SHALL reference `/srv/homelab/plane-official/` as the deployment location
- **THEN** `platform/plane/docker-compose.yml` SHALL be marked as deprecated or reference-only

### Requirement: Every deployed service SHALL have a docker-compose.yml in platform/
Each service managed by this repository SHALL have a corresponding `platform/<service>/docker-compose.yml`. Services using third-party deployment tools (e.g., Plane official CLI) SHALL be documented with a reference compose file noting the actual deployment location.

#### Scenario: Plane service compose file
- **WHEN** `platform/plane/docker-compose.yml` is reviewed
- **THEN** the file SHALL contain a deprecation notice stating the actual deployment is at `/srv/homelab/plane-official/`
- **THEN** the file SHALL NOT be used for active deployment
