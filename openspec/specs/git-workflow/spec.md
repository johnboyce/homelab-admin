## Purpose

Defines the git workflow for the homelab-admin repository: branch naming, commit conventions, PR process, and the Forgejo-primary/GitHub-mirror architecture.

## Requirements

### Requirement: Forgejo is the primary git remote
All development work SHALL target the Forgejo remote (`forgejo`). GitHub (`origin`) is a push mirror only, receiving commits automatically from Forgejo on every push and every 8 hours.

#### Scenario: Developer pushes a branch
- **WHEN** a developer pushes a feature branch
- **THEN** the branch SHALL be pushed to `forgejo` remote
- **THEN** Forgejo SHALL mirror the branch to GitHub automatically

#### Scenario: Local main tracking
- **WHEN** `git branch -vv` is run
- **THEN** `main` SHALL track `forgejo/main`

### Requirement: Direct pushes to main SHALL be blocked
The `main` branch on Forgejo SHALL have branch protection enabled. Direct pushes MUST be rejected. All changes MUST go through a pull request.

#### Scenario: Direct push attempt blocked
- **WHEN** a developer attempts `git push forgejo main`
- **THEN** Forgejo SHALL reject the push with a branch protection error

### Requirement: Branch names SHALL follow the type prefix convention
All feature branches SHALL use a kebab-case prefix matching the type of change.

#### Scenario: Valid branch name
- **WHEN** a new branch is created
- **THEN** the branch name SHALL match the pattern `<type>/<short-description>`
- **THEN** `<type>` SHALL be one of: `feat`, `fix`, `chore`, `docs`, `spec`, `refactor`, `ci`

### Requirement: Commit messages SHALL follow Conventional Commits format
All commits SHALL use the format `<type>: <short summary>` with an optional body.

#### Scenario: Valid commit message
- **WHEN** a commit is created
- **THEN** the subject line SHALL match `^(feat|fix|chore|docs|spec|refactor|ci): .+`
- **THEN** the subject line SHALL be 72 characters or fewer

### Requirement: All changes SHALL go through a pull request on Forgejo
No direct commits to `main` are permitted. Every change, including minor fixes, SHALL be submitted as a PR at `http://forgejo.geek/johnb/homelab-admin`.

#### Scenario: PR created and merged
- **WHEN** a feature branch is ready
- **THEN** a PR SHALL be opened on Forgejo against `main`
- **THEN** the PR SHALL be reviewed and merged via the Forgejo UI

### Requirement: Infrastructure changes SHALL have a corresponding openspec change record
Changes that affect service versions, architecture, security posture, or deployment method SHALL be tracked via an openspec change (`/opsx:propose`).

#### Scenario: Service version change has openspec change
- **WHEN** a service image version is updated in docker-compose.yml
- **THEN** an openspec change SHALL exist in `openspec/changes/` referencing the version change
- **THEN** the PR description SHALL reference the change name
