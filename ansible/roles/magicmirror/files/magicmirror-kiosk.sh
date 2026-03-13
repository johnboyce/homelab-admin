#!/bin/bash
# MagicMirror kiosk launcher — forces fullscreen via wmctrl after Chromium starts
# Required because snap Chromium's --kiosk doesn't always trigger GNOME fullscreen

chromium-browser \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-restore-session-state \
  --no-first-run \
  --check-for-update-interval=31536000 \
  http://magicmirror.geek &

# Wait for Chromium window to appear, then force fullscreen
sleep 8
wmctrl -r 'MagicMirror' -b add,fullscreen
