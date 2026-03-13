#!/bin/bash
# Turns off the display for the MagicMirror sleep window.
# 1. Kills Chromium kiosk (it inhibits DPMS in fullscreen mode)
# 2. Disables the display output via xrandr (more authoritative than DPMS)

export DISPLAY=:0
export XAUTHORITY=/home/johnb/.Xauthority

# Kill Chromium kiosk — it inhibits DPMS when in fullscreen/kiosk mode
pkill -f chromium-browser || true
sleep 2

# Turn off the connected display via xrandr (GPU-level, cannot be overridden)
OUTPUT=$(xrandr | grep ' connected' | head -1 | cut -d' ' -f1)
if [ -n "$OUTPUT" ]; then
    xrandr --output "$OUTPUT" --off
fi
