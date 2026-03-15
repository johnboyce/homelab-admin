#!/bin/bash
# Starts the MagicMirror kiosk if the system boots during the wake window.
# Called by magicmirror-kiosk-boot.service at boot (after graphical.target).
# The persistent wake/sleep timers handle regular daily scheduling, but if
# the system reboots mid-window, the timers consider today's wake "done".

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [kiosk-boot] $*"; }

CURRENT_HOUR=$(date +%H)
WAKE_HOUR=07
SLEEP_HOUR=08

if [ "$CURRENT_HOUR" -ge "$WAKE_HOUR" ] && [ "$CURRENT_HOUR" -lt "$SLEEP_HOUR" ]; then
    log "Boot during wake window ($WAKE_HOUR:00–$SLEEP_HOUR:00) — starting kiosk"
    /home/johnb/.local/bin/magicmirror-kiosk-wake.sh
else
    log "Boot outside wake window (current hour: $CURRENT_HOUR) — kiosk not started"
fi
