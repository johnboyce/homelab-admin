# Authentik Environment Configuration Guide

## Overview

This guide explains the correct environment variable configuration for Authentik when using a separate/centralized PostgreSQL instance, based on the official Authentik documentation.

## Environment Variable Naming in Authentik

According to the [official Authentik documentation](https://docs.goauthentik.io/docs/installation/docker-compose), Authentik uses **double underscores** in its environment variable names:

- `AUTHENTIK_SECRET_KEY`: Encryption key for Authentik
- `AUTHENTIK_POSTGRESQL__HOST`: PostgreSQL server hostname/IP
- `AUTHENTIK_POSTGRESQL__PORT`: PostgreSQL port (defaults to 5432)
- `AUTHENTIK_POSTGRESQL__USER`: PostgreSQL username for Authentik
- `AUTHENTIK_POSTGRESQL__PASSWORD`: PostgreSQL password for Authentik user
- `AUTHENTIK_POSTGRESQL__NAME`: Database name for Authentik

### Important Note on Password Fallback

From the official documentation:
> If `AUTHENTIK_POSTGRESQL__PASSWORD` is not set, it defaults to the value of the `POSTGRES_PASSWORD` environment variable. This fallback is specific to the default Docker Compose setup.

This explains the warning you may have seen:
```json
{"env_var":"POSTGRES_PASSWORD","event":"Environment variable not found, using fallback","fallback":"","found":false,"level":"warning","timestamp":"2025-12-17T00:50:43Z"}
```

When `AUTHENTIK_POSTGRESQL__PASSWORD` is not properly set, Authentik tries to fall back to `POSTGRES_PASSWORD`, which also wasn't available, resulting in the warning.

## Configuration Approach

### Using `env_file` for Direct Variable Loading

The cleanest approach for a custom PostgreSQL setup is to use `env_file` to load environment variables directly:

**`.env` file:**
```bash
# Authentik secrets (DO NOT COMMIT .env)
AUTHENTIK_SECRET_KEY=your-long-random-string
AUTHENTIK_POSTGRESQL__PASSWORD=your-authentik-db-password
AUTHENTIK_OUTPOST_TOKEN=your-outpost-token
```

**`docker-compose.yml`:**
```yaml
services:
  server:
    env_file:
      - .env
    environment:
      # PostgreSQL connection settings (customized for separate postgres)
      AUTHENTIK_POSTGRESQL__HOST: geek-postgres
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      # AUTHENTIK_SECRET_KEY and AUTHENTIK_POSTGRESQL__PASSWORD 
      # are loaded from .env file via env_file directive
```

### Why This Works

1. **`env_file: - .env`**: Docker Compose loads all variables from `.env` file and makes them available inside the container
2. **`environment` section**: Only specifies connection-specific settings (host, user, database name) that are different from defaults
3. **No variable substitution needed**: Variables in `.env` match exactly what Authentik expects

## Setup for Centralized PostgreSQL

Since you're using a separate PostgreSQL container (`geek-postgres`), you need to:

### 1. Create the Authentik Database and User

Connect to your PostgreSQL container and create the database and user:

```bash
# Connect to PostgreSQL as superuser
docker exec -it geek-postgres psql -U postgres

# Inside psql:
CREATE DATABASE authentik;
CREATE USER authentik WITH PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;

# PostgreSQL 15+ requires additional grants
\c authentik
GRANT ALL ON SCHEMA public TO authentik;

# Exit psql
\q
```

### 2. Test PostgreSQL Connection

Before starting Authentik, verify the connection works:

```bash
# Test connection from outside the container (if port 5432 is exposed)
docker exec -it geek-postgres psql -U authentik -d authentik -c "SELECT version();"

# Test from within the docker network (better test)
docker run --rm --network geek-infra postgres:16 \
  psql -h geek-postgres -U authentik -d authentik -c "SELECT version();"
```

You'll be prompted for the password. If the connection succeeds, you'll see the PostgreSQL version.

### 3. Configure Authentik .env File

Create `.env` from the example and set your actual values:

```bash
cd platform/authentik
cp .env.example .env
nano .env  # or vim, code, etc.
```

Set these values in `.env`:
```bash
AUTHENTIK_SECRET_KEY=<generate-with-openssl-rand-60>
AUTHENTIK_POSTGRESQL__PASSWORD=<password-you-set-for-authentik-user>
AUTHENTIK_OUTPOST_TOKEN=<generate-with-openssl-rand-60>
```

Generate secure values:
```bash
# Generate secret key
openssl rand -base64 60 | tr -d '\n'

# Generate outpost token
openssl rand -base64 60 | tr -d '\n'
```

### 4. Deploy Authentik

```bash
cd /path/to/homelab-admin
make deploy-authentik
```

Or manually:
```bash
cd platform/authentik
docker compose pull
docker compose up -d
```

### 5. Verify No Warnings

Check the logs to confirm no environment variable warnings:

```bash
docker logs authentik-server 2>&1 | grep -i "environment variable not found"
docker logs authentik-worker 2>&1 | grep -i "environment variable not found"
```

If configured correctly, these commands should return no output.

## New Install vs Upgrade

### If This Is a New Install

Follow the steps above to:
1. Create the PostgreSQL database and user
2. Configure `.env` with proper credentials
3. Deploy Authentik

### If This Is an Upgrade from Previous Version

If you already have Authentik running with data:

1. **Backup first**:
   ```bash
   docker exec geek-postgres pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql
   ```

2. **Update configuration** (already done in this PR):
   - `.env.example` has correct variable names
   - `docker-compose.yml` uses `env_file` properly

3. **Update your actual `.env` file** to match the new format:
   ```bash
   # Make sure it has double underscores:
   AUTHENTIK_POSTGRESQL__PASSWORD=your-existing-password
   ```

4. **Restart Authentik**:
   ```bash
   cd platform/authentik
   docker compose down
   docker compose up -d
   ```

## Troubleshooting

### Connection Refused

If Authentik can't connect to PostgreSQL:

```bash
# Verify PostgreSQL is running
docker ps | grep geek-postgres

# Check if authentik user exists
docker exec -it geek-postgres psql -U postgres -c "\du"

# Check if authentik database exists
docker exec -it geek-postgres psql -U postgres -c "\l" | grep authentik
```

### Permission Errors

If you see permission errors in Authentik logs:

```bash
# Grant all permissions
docker exec -it geek-postgres psql -U postgres -d authentik \
  -c "GRANT ALL ON SCHEMA public TO authentik;"
```

### Password Authentication Failed

Double-check:
1. The password in `.env` matches the one set for the authentik PostgreSQL user
2. The variable name is `AUTHENTIK_POSTGRESQL__PASSWORD` (double underscores)
3. The `.env` file is in the correct location (`platform/authentik/.env`)

## Summary

The key points:
1. Use `AUTHENTIK_POSTGRESQL__PASSWORD` (double underscores) in `.env` file
2. Use `env_file: - .env` in docker-compose.yml to load variables directly
3. Set connection details (host, user, database) in `environment` section for customization
4. Create the PostgreSQL database and user separately before deploying Authentik
5. Test the PostgreSQL connection before deploying Authentik

This configuration follows Authentik's official documentation and works correctly with a centralized PostgreSQL instance.
