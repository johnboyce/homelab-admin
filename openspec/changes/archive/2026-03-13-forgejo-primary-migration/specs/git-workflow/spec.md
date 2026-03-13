## ADDED Requirements

### Requirement: Forgejo is the primary git remote
All development work SHALL target the Forgejo remote (`forgejo`). GitHub (`origin`) is a push mirror only, receiving commits automatically from Forgejo on every push and every 8 hours.

#### Scenario: Developer pushes a branch
- **WHEN** a developer pushes a feature branch
- **THEN** the branch SHALL be pushed to `forgejo` remote
- **THEN** Forgejo SHALL mirror the branch to GitHub automatically

### Requirement: Direct pushes to main SHALL be blocked
The `main` branch on Forgejo SHALL have branch protection enabled. Direct pushes MUST be rejected. All changes MUST go through a pull request.

#### Scenario: Direct push attempt blocked
- **WHEN** a developer attempts `git push forgejo main`
- **THEN** Forgejo SHALL reject the push with a branch protection error

### Requirement: Forgejo push mirror SHALL sync to GitHub automatically
A push mirror SHALL be configured in Forgejo to forward all commits to GitHub (`origin`). The mirror SHALL sync on every commit and at a maximum interval of 8 hours.

#### Scenario: Push mirror sync on commit
- **WHEN** a commit is merged to `main` on Forgejo
- **THEN** Forgejo push mirror SHALL forward the commit to GitHub within seconds
