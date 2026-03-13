#!/bin/bash
# Wakes the display and relaunches the MagicMirror kiosk browser.
# Called by magicmirror-wake.timer at 07:00 daily.

set -euo pipefail

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [wake] $*"; }

export DISPLAY=:0
export XAUTHORITY=/home/johnb/.Xauthority

# Re-enable display output
log "Re-enabling display output"
xrandr --auto

# Disable DPMS and screensaver so the display stays on during the morning window
log "Disabling DPMS and screensaver"
xset -dpms
xset s off

# Relaunch Chromium kiosk (killed by sleep script)
log "Launching kiosk browser"
/home/johnb/.local/bin/magicmirror-kiosk.sh

log "Display wake complete"
