# Homelab Backup Strategy

This document describes the backup procedures for the homelab's critical data (PostgreSQL Authentik database).

## Overview

**What's being backed up:** PostgreSQL database containing Authentik configuration, users, and authentication data.

**Where:** `./backups/` directory (local macbook, checked into git)

**Backup format:** SQL dump (human-readable, portable, can be restored anywhere)

**Backup size:** ~80-100MB per backup

## Quick Start

### Create a Backup

```bash
make homelab-backup
```

Output:
```
✅ Backup created: ./backups/authentik_backup_20260221_132456.sql (81M)
To restore this backup later, run:
  make homelab-backup-restore FILE=./backups/authentik_backup_20260221_132456.sql
```

### List Backups

```bash
make homelab-backup-list
```

Output:
```
Available Backups

  ./backups/authentik_backup_20260221_132456.sql (81M)
  ./backups/authentik_backup_20260221_130000.sql (81M)
  ./backups/authentik_backup_20260220_120000.sql (81M)

  Oldest: authentik_backup_20260220_120000.sql
  Newest: authentik_backup_20260221_132456.sql
```

### Restore from Backup

```bash
make homelab-backup-restore FILE=./backups/authentik_backup_20260221_132456.sql
```

This will:
1. Ask for confirmation (type `yes`)
2. Restore the database
3. Verify connectivity

## Recommended Backup Schedule

- **Daily:** `make homelab-backup` (automated, once per day)
- **After major changes:** Create backup immediately after configuration changes
- **Retention:** Keep last 30 days of backups locally, archive older ones

## Setting Up Automated Daily Backups

### On macOS (using launchd)

Create `~/Library/LaunchAgents/com.homelab.backup.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.homelab.backup</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>cd ~/working/homelab-admin && make homelab-backup</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>2</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/homelab-backup.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/homelab-backup-error.log</string>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.homelab.backup.plist
launchctl list | grep homelab  # Verify it's loaded
```

### On Linux (using cron)

Add to crontab:
```bash
crontab -e

# Add this line to run backup daily at 2 AM
0 2 * * * cd ~/working/homelab-admin && make homelab-backup >> /tmp/homelab-backup.log 2>&1
```

## Backup Testing (CRITICAL!)

You must test that backups actually restore correctly. This is not optional.

### Test Restore Procedure

**WARNING:** This will overwrite your database. Only do this in a test environment or when you're sure.

1. List available backups:
   ```bash
   make homelab-backup-list
   ```

2. Pick an old backup to test with (not the newest one):
   ```bash
   make homelab-backup-restore FILE=./backups/authentik_backup_20260220_120000.sql
   ```

3. Verify services are still running:
   ```bash
   make homelab-status
   ```

4. Test accessing Authentik:
   ```bash
   curl -I http://auth.geek
   ```

5. If all works, create a fresh backup:
   ```bash
   make homelab-backup
   ```

## Backup Content

Each backup file contains:

```sql
--
-- PostgreSQL database dump
--

-- Dumped from database version 16.x
-- Dumped by pg_dump version 16.x

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- [Database schema, data, and sequences]
-- [Authentik configuration]
-- [User accounts]
-- [Application settings]
-- [Session data]

--
-- PostgreSQL database dump complete
--
```

The backup is portable and can be restored on any PostgreSQL 16+ installation.

## Recovery Scenarios

### Scenario 1: Accidentally Deleted User

If you accidentally delete an Authentik user:

1. Create backup first (safeguard):
   ```bash
   make homelab-backup
   ```

2. Restore from backup before the deletion:
   ```bash
   make homelab-backup-restore FILE=./backups/authentik_backup_BEFORE_DELETE.sql
   ```

3. Verify the user is back

### Scenario 2: Database Corruption

If PostgreSQL becomes corrupted:

1. Check status:
   ```bash
   make homelab-status
   ```

2. View logs for errors:
   ```bash
   make homelab-logs
   ```

3. If unrecoverable, restore:
   ```bash
   make homelab-backup-restore FILE=./backups/authentik_backup_LATEST.sql
   ```

### Scenario 3: Complete Host Failure (geek dies)

1. Recover geek host (restore from VM snapshot, rebuild, etc.)

2. Restore services:
   ```bash
   cd ~/working/homelab-admin
   make nginx-deploy       # Deploy nginx config
   docker-compose -f platform/postgres/docker-compose.yml up -d
   docker-compose -f platform/authentik/docker-compose.yml up -d
   ```

3. Restore database:
   ```bash
   make homelab-backup-restore FILE=./backups/authentik_backup_LATEST.sql
   ```

4. Verify services:
   ```bash
   make homelab-status
   ```

## Troubleshooting

### Backup fails with SSH error

```
❌ Backup failed!
```

Check:
```bash
ssh johnb@geek 'docker ps | grep postgres'
```

### Backup completes but file is too small (<1MB)

The backup might be empty. Check:
```bash
head -20 ./backups/authentik_backup_LATEST.sql
```

Should show SQL header, not be empty.

### Restore fails with permission error

Make sure you're using the correct database user:
```bash
ssh johnb@geek 'docker exec geek-postgres psql -U authentik -l'
```

### Restore succeeds but services don't work

Check logs:
```bash
make homelab-logs
```

The database might be in an inconsistent state. Try restoring an older backup.

## Backup Size Management

Backups are typically 80-100MB each.

Keep last 30 days locally:
```bash
# Find old backups (older than 30 days)
find ./backups -name "*.sql" -mtime +30 -ls

# Archive them somewhere else (S3, external drive, etc.)
# Then delete locally
```

## Advanced: Automated Cloud Backup

For extra safety, consider uploading backups to cloud storage:

```bash
# Add to your backup script or cron:
aws s3 cp ./backups/authentik_backup_*.sql s3://my-bucket/homelab-backups/
# or
rclone sync ./backups/ remote:homelab-backups/
```

## Verification Checklist

- [ ] Created first backup: `make homelab-backup`
- [ ] Listed backups: `make homelab-backup-list`
- [ ] Tested restore: `make homelab-backup-restore FILE=<file>`
- [ ] Verified services work after restore
- [ ] Set up automated backups (launchd/cron)
- [ ] Documented backup location and procedures
- [ ] Planned retention strategy
- [ ] Tested disaster recovery scenario

## Related Commands

```bash
# View backup script
cat scripts/backup_postgresql.sh

# Manual backup (advanced)
ssh johnb@geek 'docker exec geek-postgres pg_dump -U authentik authentik > /tmp/backup.sql'

# Check database size
ssh johnb@geek 'docker exec geek-postgres psql -U authentik authentik -c "SELECT pg_size_pretty(pg_database_size(current_database()));"'

# View database info
ssh johnb@geek 'docker exec geek-postgres psql -U authentik -l'
```

## Summary

✅ **You now have:**
- Automated backup script (`make homelab-backup`)
- Restore capability (`make homelab-backup-restore`)
- Backup listing (`make homelab-backup-list`)
- Documentation for testing and recovery

**Next steps:**
1. Test restore at least once
2. Set up automated daily backups
3. Document where backups are stored
4. Test disaster recovery scenario
