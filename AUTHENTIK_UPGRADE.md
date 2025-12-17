# Authentik Upgrade Guide: Redis-based to 2025.10.3

This guide covers upgrading Authentik from older versions (pre-2025.8) that required Redis to version 2025.10.3, which no longer requires Redis.

> **Note for zsh users**: All commands in this guide work with zsh, bash, or any POSIX-compatible shell. The `make deploy-authentik` command explicitly uses bash internally, so it works regardless of your default shell.

## Important Changes in Authentik 2025.8+

- **Redis Dependency Removed**: Authentik now uses PostgreSQL for all caching, task queuing, WebSocket connections, and the embedded outpost session store
- **Increased PostgreSQL Load**: Expect approximately 50% more PostgreSQL connections compared to Redis-based versions
- **Configuration Changes**: All Redis-related environment variables have been removed from the configuration

## Pre-Upgrade Checklist

Before starting the upgrade, ensure you complete these steps:

### 1. Backup Your Data

**Critical**: Always backup before upgrading!

```bash
# Backup Authentik database
docker exec geek-postgres pg_dump -U authentik authentik > authentik-backup-$(date +%Y%m%d).sql

# Verify the backup
ls -lh authentik-backup-*.sql

# Optional: Backup Redis data (if you want to keep it for other services)
docker exec geek-redis redis-cli BGSAVE
```

### 2. Document Current State

```bash
# Check currently running Authentik version
docker ps | grep authentik

# Check current Authentik containers
cd platform/authentik
docker-compose ps

# Save current environment settings
cp .env .env.backup
```

### 3. Verify Prerequisites

```bash
# Ensure PostgreSQL is running and healthy
docker ps | grep geek-postgres
docker exec geek-postgres psql -U authentik -d authentik -c "SELECT version();"

# Check available disk space (PostgreSQL will handle more data)
df -h
```

## Upgrade Steps

### Step 1: Stop Current Authentik Services

```bash
cd platform/authentik
docker-compose down
```

This stops the Authentik server, worker, and outpost containers but preserves all data in PostgreSQL.

### Step 2: Update Configuration (Already Done)

The `docker-compose.yml` in this repository has already been updated to:
- Use Authentik version 2025.10.3
- Remove all Redis-related configuration
- Use only PostgreSQL for all storage needs

No manual configuration changes are needed.

### Step 3: Deploy the Upgrade

Use the provided Makefile target:

```bash
cd /path/to/homelab-admin
make deploy-authentik
```

This will:
1. Prompt you to confirm the upgrade
2. Pull the new Authentik 2025.10.3 images
3. Start the updated containers
4. Display the status of all services
5. Show verification commands

**Alternative manual deployment**:
```bash
cd platform/authentik
docker-compose pull
docker-compose up -d
```

### Step 4: Verify the Upgrade

#### Check Container Status

```bash
cd platform/authentik
docker-compose ps
```

Expected output:
```
NAME                 IMAGE                                    STATUS
authentik-outpost    ghcr.io/goauthentik/proxy:2025.10.3     Up
authentik-server     ghcr.io/goauthentik/server:2025.10.3    Up
authentik-worker     ghcr.io/goauthentik/server:2025.10.3    Up
```

#### Check Logs for Errors

```bash
# Server logs
docker logs authentik-server | tail -50

# Worker logs
docker logs authentik-worker | tail -50

# Outpost logs
docker logs authentik-outpost | tail -50
```

Look for any ERROR messages. Some INFO/WARNING messages during migration are normal.

#### Test Web Access

```bash
# Test internal access
curl -Ik http://auth.geek

# Test public access (if configured)
curl -Ik https://auth.johnnyblabs.com
```

Both should return `HTTP/1.1 200 OK` or `HTTP/2 200`.

#### Verify Login

1. Open your browser and navigate to `https://auth.geek` or `https://auth.johnnyblabs.com`
2. Log in with your admin credentials
3. Verify that the dashboard loads correctly
4. Check that your applications and providers are still configured

#### Monitor PostgreSQL Connections

```bash
# Check PostgreSQL connection count
docker exec geek-postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname='authentik';"
```

Note the connection count - it will be higher than before due to Redis removal.

## Post-Upgrade: Handling Redis

Now that Authentik no longer needs Redis, you have options:

### Option 1: Keep Redis Running (if other services need it)

If you have other services that use Redis, leave it running:

```bash
# Redis stays up - no action needed
docker ps | grep geek-redis
```

### Option 2: Stop Redis (if only Authentik was using it)

If Authentik was the only service using Redis:

```bash
# Stop Redis
cd platform/redis
docker-compose down

# This stops the container but preserves the data volume
```

### Option 3: Remove Redis Completely

If you're certain you won't need Redis:

```bash
# Stop and remove Redis container and volumes
cd platform/redis
docker-compose down -v

# Optional: Remove the data directory
# WARNING: This deletes all Redis data permanently!
# rm -rf data/
```

## Troubleshooting

### Authentik Won't Start

Check the logs:
```bash
docker logs authentik-server
docker logs authentik-worker
```

Common issues:
- **Database connection errors**: Verify PostgreSQL is running and credentials in `.env` are correct
- **Migration errors**: Check that the database user has proper permissions

### Database Permission Issues

```bash
# Grant permissions to authentik user
docker exec -it geek-postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;"
```

### Performance Issues

If you notice performance degradation:

1. **Check PostgreSQL resources**:
   ```bash
   docker stats geek-postgres
   ```

2. **Review PostgreSQL logs**:
   ```bash
   docker logs geek-postgres | tail -100
   ```

3. **Consider increasing PostgreSQL memory** (edit `platform/postgres/docker-compose.yml`):
   ```yaml
   command: postgres -c shared_buffers=256MB -c max_connections=200
   ```

### Services Still Using Old Version

```bash
# Force recreation of containers with new images
cd platform/authentik
docker-compose down
docker-compose pull
docker-compose up -d --force-recreate
```

## Rollback Procedure

If you encounter critical issues and need to rollback:

### Step 1: Stop New Version

```bash
cd platform/authentik
docker-compose down
```

### Step 2: Restore Database Backup

```bash
# Drop and recreate the database
docker exec -it geek-postgres psql -U postgres -c "DROP DATABASE authentik;"
docker exec -it geek-postgres psql -U postgres -c "CREATE DATABASE authentik OWNER authentik;"

# Restore from backup
cat authentik-backup-YYYYMMDD.sql | docker exec -i geek-postgres psql -U authentik -d authentik
```

### Step 3: Revert docker-compose.yml

Edit `platform/authentik/docker-compose.yml` and change the image version back to your previous version, then:

```bash
docker-compose up -d
```

## Expected Behavior After Upgrade

### Normal Operations

- Authentik UI should be fully functional
- All configured applications and providers should work
- Forward authentication should work as before
- SSO logins should complete successfully

### Changed Metrics

- **More PostgreSQL connections**: This is expected and normal
- **Slightly higher PostgreSQL CPU/memory**: PostgreSQL is doing work that Redis previously handled
- **No Redis connections**: Authentik no longer uses Redis at all

### Migration Status

Authentik will automatically run database migrations on first startup with the new version. This is normal and may take a minute or two.

## Summary

The upgrade from Redis-based Authentik to 2025.10.3 is straightforward:

1. ✅ Backup your database
2. ✅ Stop old Authentik containers
3. ✅ Deploy new version with `make deploy-authentik`
4. ✅ Verify services are running
5. ✅ Optionally stop/remove Redis if no longer needed

The new version consolidates all storage in PostgreSQL, simplifying your infrastructure while maintaining all Authentik functionality.

## Additional Resources

- [Authentik 2025.8 Release Notes](https://goauthentik.io/docs/releases/2025.8) - Redis removal announcement
- [Authentik 2025.10 Release Notes](https://goauthentik.io/docs/releases/2025.10) - Latest features
- [Authentik Documentation](https://goauthentik.io/docs/) - Official docs
