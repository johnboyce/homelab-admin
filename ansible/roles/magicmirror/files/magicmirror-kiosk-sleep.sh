#!/bin/bash
# Stops the MagicMirror kiosk service and powers off the monitor via DPMS.
# Called by magicmirror-kiosk-sleep.timer daily.
# Runs as root (system-level service).

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [kiosk-sleep] $*"; }

# Stop the kiosk X server
log "Stopping magicmirror-kiosk.service"
systemctl stop magicmirror-kiosk.service || true

# Switch back to GDM's VT so the monitor shows the login screen (not a dead VT)
log "Switching to VT1 (GDM)"
chvt 1 || log "Warning: chvt 1 failed (non-fatal)"

# Force DPMS off on GDM's display to power down the monitor.
# GDM may run Wayland (no Xauthority) or X11 — try both approaches.
GDM_XAUTH=$(find /run/user/ -path "*/gdm/Xauthority" 2>/dev/null | head -1) || true
if [ -n "$GDM_XAUTH" ]; then
    log "Powering off monitor via DPMS (X11)"
    DISPLAY=:0 XAUTHORITY="$GDM_XAUTH" xset dpms force off 2>/dev/null || true
else
    # GDM is likely on Wayland — use vbetool or setterm as fallback
    log "GDM on Wayland — using setterm to blank console"
    setterm --blank force --term /dev/tty1 2>/dev/null || true
fi

log "Sleep complete"
