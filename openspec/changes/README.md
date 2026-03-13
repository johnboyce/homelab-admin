# OpenSpec Change Records

This directory tracks infrastructure changes — both proposals and completed work.

## Directory Structure

```
openspec/changes/
  README.md                          # This file
  YYYY-MM-DD-<slug>.md               # Active/completed change records
  archive/
    YYYY-MM-DD-<slug>.md             # Archived (older completed) changes
```

## When to Create a Change Record

Create a change record for:
- Any service addition or removal
- Version upgrades for pinned services
- Architectural changes (networking, ingress, auth)
- Deployment method changes
- Security posture changes
- Changes that affect multiple services or have rollback risk

Trivial changes (typo fixes, comment updates, blank line cleanup) do not need a record.

## File Naming

```
YYYY-MM-DD-<type>-<service>-<short-description>.md
```

Examples:
- `2026-03-12-completed-forgejo-primary-migration.md`
- `2026-03-15-proposal-woodpecker-ci-pipeline.md`
- `2026-04-01-completed-vaultwarden-version-pin.md`

## Change Record Format

```markdown
# Change: <Title>

**ID:** CHG-YYYY-NNN
**Date:** YYYY-MM-DD
**Status:** proposed | in-progress | completed | cancelled
**Type:** migration | upgrade | new-service | removal | config | security
**Services:** service1, service2
**Author:** johnb

## Summary
One paragraph describing what changed and why.

## Details
Detailed description of the change.

## Impact
- Which services are affected
- Any downtime expected
- Dependencies that need updating

## Implementation
Steps taken (or to be taken).

## Verification
How to confirm the change is working correctly.

## Rollback
How to revert if something goes wrong.

## Spec Updates Required
- [ ] `openspec/specs/service-inventory.md` — update service entry
- [ ] `HOMELAB_SPEC.yml` — update service registry
- [ ] Other docs...

## Notes
Any additional context, gotchas, or lessons learned.
```

## Lifecycle

```
proposed → in-progress → completed → (archive after 90 days)
                       ↓
                   cancelled
```

- **proposed:** Change is planned, not yet started
- **in-progress:** Actively being implemented
- **completed:** Fully implemented and verified
- **cancelled:** Decided not to proceed (keep record for context)
- **archive:** Completed records moved to `archive/` after ~90 days to keep the root clean

## Change ID Sequence

Assign IDs sequentially per year: CHG-2026-001, CHG-2026-002, etc.
Track the last used ID at the bottom of this file.

---

**Last used ID:** CHG-2026-002
