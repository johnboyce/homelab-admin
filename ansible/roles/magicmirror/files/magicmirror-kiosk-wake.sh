#!/bin/bash
# Starts the MagicMirror kiosk service and switches VT if no user is active.
# Called by magicmirror-kiosk-wake.timer daily.
# Runs as root (system-level service).

set -euo pipefail

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [kiosk-wake] $*"; }

# Start the kiosk X server (idempotent — systemd won't double-start)
log "Starting magicmirror-kiosk.service"
systemctl start magicmirror-kiosk.service

# Only switch VT to kiosk if no user has an active graphical session.
# GDM's own session (user=gdm) doesn't count as an active user session.
if loginctl list-sessions --no-legend | grep -v gdm | grep -q "seat0"; then
    log "Active user session detected on seat0 — not switching VT (kiosk running on VT8)"
else
    log "No active user session — switching to VT8"
    chvt 8
fi

log "Wake complete"
