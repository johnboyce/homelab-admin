#!/bin/bash
# Starts the MagicMirror morning window.
# Launches a mouse wiggler to keep the display awake, then starts
# the Chromium kiosk browser. No GNOME settings are modified.
# Called by magicmirror-wake.timer at 07:00 daily.

set -euo pipefail

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [wake] $*"; }

export DISPLAY=:0
export XAUTHORITY=/home/johnb/.Xauthority
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

# Disable X11 screensaver and DPMS so the display stays on
log "Disabling X11 screensaver and DPMS"
xset s off
xset -dpms

# Dismiss GNOME screensaver/lock screen if active
log "Dismissing screensaver"
gdbus call --session \
  --dest org.gnome.ScreenSaver \
  --object-path /org/gnome/ScreenSaver \
  --method org.gnome.ScreenSaver.SetActive false 2>/dev/null || true

# Start the keep-awake mouse wiggler (prevents GNOME idle/DPMS)
log "Starting keep-awake wiggler"
pkill -f magicmirror-keep-awake.sh || true
/home/johnb/.local/bin/magicmirror-keep-awake.sh &

# Launch Chromium kiosk (killed by sleep script)
log "Launching kiosk browser"
/home/johnb/.local/bin/magicmirror-kiosk.sh

log "Display wake complete"
