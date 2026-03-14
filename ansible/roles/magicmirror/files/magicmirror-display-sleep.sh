#!/bin/bash
# Ends the MagicMirror morning window.
# Kills Chromium and the keep-awake mouse wiggler, then lets GNOME's
# default idle/DPMS power management put the display to sleep naturally.

set -euo pipefail

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [sleep] $*"; }

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

# Ensure screen lock is disabled so the wake script can dismiss the
# screensaver without requiring a password.
gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true

# Kill the keep-awake mouse wiggler
log "Stopping keep-awake wiggler"
pkill -f magicmirror-keep-awake.sh || true

# Kill Chromium kiosk
log "Killing Chromium kiosk..."
pkill -f chromium-browser || true

# Ensure X11 screensaver and DPMS timeouts are set (the wake script's
# xset -dpms / xset s off must be undone for the display to sleep).
export DISPLAY=:0
export XAUTHORITY=/home/johnb/.Xauthority
log "Restoring X11 screensaver and DPMS timeouts"
xset s 300 300
xset +dpms
xset dpms 300 300 300

log "Display sleep complete — monitor will power off in ~5min"
