#!/bin/bash
# Wakes the display and relaunches the MagicMirror kiosk browser.
# Called by magicmirror-wake.timer at 07:00 daily.

export DISPLAY=:0
export XAUTHORITY=/home/johnb/.Xauthority

# Re-enable display output
xrandr --auto

# Disable DPMS and screensaver so the display stays on
xset -dpms
xset s off

# Relaunch Chromium kiosk (killed by sleep script)
/home/johnb/.local/bin/magicmirror-kiosk.sh
