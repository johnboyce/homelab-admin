# Environment Variable Fix - Authentik Configuration

## Issue Summary

The Authentik configuration had an environment variable naming inconsistency that caused warnings in the logs about missing environment variables.

## Problem Details

### Original Issue
The user reported seeing this warning in the Authentik logs:
```json
{"env_var":"POSTGRES_PASSWORD","event":"Environment variable not found, using fallback","fallback":"","found":false,"level":"warning","timestamp":"2025-12-17T00:50:43Z"}
```

### Root Cause
The `.env.example` file contained an incorrectly named environment variable:
- **Incorrect**: `AUTHENTIK_POSTGRESQL__PASSWORD` (double underscore between POSTGRESQL and PASSWORD)
- **Correct**: `AUTHENTIK_POSTGRESQL_PASSWORD` (single underscore)

This mismatch prevented Docker Compose from properly substituting the database password, which caused Authentik to look for alternative environment variable names (like `POSTGRES_PASSWORD`), hence the warning.

## Understanding Authentik's Environment Variable Naming

Authentik uses a specific naming convention for its environment variables:

1. **Variables in `.env` file**: Use single underscores (e.g., `AUTHENTIK_POSTGRESQL_PASSWORD`)
2. **Variables inside the container**: Use double underscores (e.g., `AUTHENTIK_POSTGRESQL__PASSWORD`)

The `docker-compose.yml` file correctly handles this mapping:

```yaml
env_file:
  - .env
environment:
  AUTHENTIK_POSTGRESQL__PASSWORD: ${AUTHENTIK_POSTGRESQL_PASSWORD:-}
```

This configuration:
- Loads all variables from `.env` file via `env_file`
- Reads `AUTHENTIK_POSTGRESQL_PASSWORD` from the `.env` file (single underscore)
- Maps it to `AUTHENTIK_POSTGRESQL__PASSWORD` inside the container (double underscore)

## Changes Made

### 1. Fixed `.env.example` Variable Name
**File**: `platform/authentik/.env.example`

**Before**:
```bash
AUTHENTIK_POSTGRESQL__PASSWORD=replace-me-authentik-db
```

**After**:
```bash
AUTHENTIK_POSTGRESQL_PASSWORD=replace-me-authentik-db
```

### 2. Verified Existing Correct Configurations

The following were already correctly configured by the user:

✅ **Makefile**: Updated to use `docker compose` (space) instead of `docker-compose` (hyphen)
```makefile
docker compose pull
docker compose up -d
docker compose ps
```

✅ **docker-compose.yml**: Added `env_file: - .env` to all three Authentik services (server, worker, outpost-proxy)

## Verification

After creating a `.env` file from the corrected `.env.example`:

1. Copy the example file:
   ```bash
   cd platform/authentik
   cp .env.example .env
   ```

2. Edit `.env` and set actual values:
   ```bash
   AUTHENTIK_SECRET_KEY=<your-long-random-string>
   AUTHENTIK_POSTGRESQL_PASSWORD=<your-authentik-db-password>
   AUTHENTIK_OUTPOST_TOKEN=<your-outpost-token>
   ```

3. Deploy Authentik:
   ```bash
   cd /path/to/homelab-admin
   make deploy-authentik
   ```

4. Verify no warnings in logs:
   ```bash
   docker logs authentik-server | grep -i "environment variable not found"
   docker logs authentik-worker | grep -i "environment variable not found"
   ```

## Related Documentation

The following files correctly reference the environment variable with single underscore:
- `README.md`: Documents `AUTHENTIK_POSTGRESQL_PASSWORD` as the required variable
- `CHECKLIST.md`: Lists `AUTHENTIK_POSTGRESQL_PASSWORD` in the environment variable checklist

## Summary

The fix ensures that:
1. Environment variables are correctly named in `.env.example`
2. Docker Compose can properly substitute variables from the `.env` file
3. Authentik receives the correct database credentials
4. No warnings appear in logs about missing environment variables

The issue was purely a naming inconsistency in the example file that would have caused problems when users created their actual `.env` files from the example.
