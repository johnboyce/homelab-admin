#!/usr/bin/env bash
# backup_postgresql.sh — Backup Authentik PostgreSQL database
# Backs up the PostgreSQL database to a timestamped file
#
# Usage:
#   ./scripts/backup_postgresql.sh              # Creates backup
#   ./scripts/backup_postgresql.sh restore FILE # Restores from backup
#   make homelab-backup                         # Via Makefile
#   make homelab-backup-restore FILE=backup.sql # Restore via Makefile

set -u

GEEK_HOST="johnb@geek"
BACKUP_DIR="./backups"
DB_USER="authentik"
DB_NAME="authentik"
CONTAINER_NAME="geek-postgres"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
  echo -e "${BLUE}$1${NC}"
}

print_ok() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# ============================================================================
# BACKUP OPERATION
# ============================================================================

backup_database() {
  print_header "PostgreSQL Backup — Authentik Database"
  echo ""

  # Create backup directory if it doesn't exist
  mkdir -p "$BACKUP_DIR"

  # Generate timestamped filename
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  BACKUP_FILE="$BACKUP_DIR/authentik_backup_${TIMESTAMP}.sql"

  print_header "Creating backup..."
  echo "  Database: $DB_NAME"
  echo "  User: $DB_USER"
  echo "  Host: $GEEK_HOST"
  echo "  File: $BACKUP_FILE"
  echo ""

  # Perform backup via SSH
  if ssh "$GEEK_HOST" "docker exec $CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME 2>/dev/null" > "$BACKUP_FILE" 2>/dev/null; then
    FILE_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
    print_ok "Backup created: $BACKUP_FILE ($FILE_SIZE)"

    # Show last few lines of backup to verify it's valid
    echo ""
    echo "Backup verification (last 5 lines):"
    tail -5 "$BACKUP_FILE"

    echo ""
    print_ok "Backup complete!"
    echo ""
    echo "To restore this backup later, run:"
    echo "  make homelab-backup-restore FILE=$BACKUP_FILE"

  else
    print_error "Backup failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check SSH connection: ssh $GEEK_HOST 'hostname'"
    echo "  2. Check container: ssh $GEEK_HOST 'docker ps | grep $CONTAINER_NAME'"
    echo "  3. Check database user: ssh $GEEK_HOST 'docker exec $CONTAINER_NAME psql -U $DB_USER -l'"
    exit 1
  fi
}

# ============================================================================
# RESTORE OPERATION
# ============================================================================

restore_database() {
  local BACKUP_FILE="$1"

  if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Backup file not found: $BACKUP_FILE"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/*.sql 2>/dev/null || echo "  (no backups found)"
    exit 1
  fi

  print_header "PostgreSQL Restore — Authentik Database"
  echo ""
  echo "⚠️  WARNING: This will overwrite the current database!"
  echo ""
  echo "  Backup file: $BACKUP_FILE"
  echo "  Database: $DB_NAME"
  echo "  Container: $CONTAINER_NAME"
  echo ""

  # Ask for confirmation
  read -p "Are you sure you want to restore? (type 'yes' to confirm): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
  fi

  print_header "Restoring from backup..."

  # Restore via SSH
  if ssh "$GEEK_HOST" "docker exec -i $CONTAINER_NAME psql -U $DB_USER $DB_NAME 2>/dev/null" < "$BACKUP_FILE" > /dev/null 2>&1; then
    print_ok "Database restored from: $BACKUP_FILE"
    echo ""
    echo "Verification:"
    echo "  Run 'make homelab-status' to check if Authentik is responding"
    echo "  Check logs: make homelab-logs"

  else
    print_error "Restore failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check backup file integrity: head -20 $BACKUP_FILE"
    echo "  2. Check database: ssh $GEEK_HOST 'docker exec $CONTAINER_NAME psql -U $DB_USER -l'"
    echo "  3. Check container logs: make homelab-logs"
    exit 1
  fi
}

# ============================================================================
# LIST BACKUPS
# ============================================================================

list_backups() {
  print_header "Available Backups"
  echo ""

  if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    ls -lh "$BACKUP_DIR"/*.sql 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    OLDEST=$(ls -1tr "$BACKUP_DIR"/*.sql 2>/dev/null | head -1)
    NEWEST=$(ls -1tr "$BACKUP_DIR"/*.sql 2>/dev/null | tail -1)
    echo "  Oldest: $(basename "$OLDEST" 2>/dev/null)"
    echo "  Newest: $(basename "$NEWEST" 2>/dev/null)"
  else
    echo "  (no backups found in $BACKUP_DIR)"
  fi
}

# ============================================================================
# MAIN
# ============================================================================

case "${1:-backup}" in
  backup)
    backup_database
    ;;
  restore)
    if [ -z "${2:-}" ]; then
      print_error "Please specify backup file to restore"
      echo ""
      echo "Usage: $0 restore <backup-file>"
      echo ""
      list_backups
      exit 1
    fi
    restore_database "$2"
    ;;
  list)
    list_backups
    ;;
  *)
    print_error "Unknown command: $1"
    echo ""
    echo "Usage:"
    echo "  $0 backup              # Create backup"
    echo "  $0 restore <file>      # Restore from backup"
    echo "  $0 list                # List available backups"
    exit 1
    ;;
esac
