#!/bin/bash
# Turns off the display for the MagicMirror sleep window.
# 1. Kills Chromium kiosk (it inhibits DPMS in fullscreen mode)
# 2. Disables the display output via xrandr
# 3. Enables DPMS with short timeouts as safety net (GNOME can re-enable xrandr outputs)

set -euo pipefail

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [sleep] $*"; }

export DISPLAY=:0
export XAUTHORITY=/home/johnb/.Xauthority

# Kill Chromium kiosk — it inhibits DPMS when in fullscreen/kiosk mode
log "Killing Chromium kiosk..."
pkill -f chromium-browser || true
sleep 2

# Turn off the connected display via xrandr
OUTPUT=$(xrandr | grep ' connected' | head -1 | cut -d' ' -f1)
if [ -n "$OUTPUT" ]; then
    log "Turning off display output: $OUTPUT"
    xrandr --output "$OUTPUT" --off
else
    log "WARNING: No connected output found"
fi

# Enable DPMS with short timeouts as safety net.
# GNOME/Mutter can re-enable xrandr outputs automatically, but DPMS will
# blank the display again within seconds even if that happens.
log "Enabling DPMS safety net (10s standby/suspend/off)"
xset +dpms
xset dpms 10 10 10
xset dpms force off

log "Display sleep complete"
