#!/bin/bash
# Polls go2rtc for camera snapshots and caches the last successful frame.
# When cameras are sleeping (no RTSP stream), the cached image persists
# so MagicMirror can show the most recent capture instead of "camera sleeping".
# Run by magicmirror-snapshot-cache.timer every 30 seconds.

CACHE_DIR="/srv/homelab/magicmirror/modules/MMM-CameraSnapshots/cache"
CAMERAS="backyard breezeway garage"
GO2RTC="http://go2rtc.geek/api/frame.jpeg"

mkdir -p "$CACHE_DIR"

for cam in $CAMERAS; do
    tmp="$CACHE_DIR/${cam}.tmp.jpg"
    out="$CACHE_DIR/${cam}.jpg"
    ts="$CACHE_DIR/${cam}.ts"

    if curl -sf --max-time 5 "${GO2RTC}?src=${cam}" -o "$tmp" 2>/dev/null; then
        mv "$tmp" "$out"
        date +%s > "$ts"
    fi
    rm -f "$tmp"
done
