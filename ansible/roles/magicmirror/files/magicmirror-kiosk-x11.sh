#!/bin/bash
# Starts a standalone X server on :1 vt8 with Chromium in fullscreen kiosk mode.
# No window manager, no screensaver, no DPMS — just X + Chromium.
# Managed by magicmirror-kiosk.service (system-level).

set -euo pipefail

MAGICMIRROR_URL="http://magicmirror.geek"

# Clean up stale X lock files from previous crashes
rm -f /tmp/.X1-lock

# Ensure XAUTHORITY is set for the systemd service context
export XAUTHORITY="${HOME}/.Xauthority"

# xinit runs the given client script on a new X server.
# -- separates client args from server args.
# :1  = display number (GDM uses :0)
# vt8 = virtual terminal 8 (GDM on vt1, GNOME sessions on vt2+)
exec xinit /bin/bash -c "
    # Disable DPMS and screensaver on this X server
    xset s off
    xset -dpms

    # Get actual screen resolution for window sizing
    SCREEN_RES=\$(xrandr | grep -oP '\d+x\d+' | head -1)
    SCREEN_W=\${SCREEN_RES%x*}
    SCREEN_H=\${SCREEN_RES#*x}

    # Launch Chromium fullscreen kiosk — this is the only X client
    # --window-size and --window-position required since there is no window manager
    exec chromium-browser \\
        --no-first-run \\
        --noerrdialogs \\
        --disable-infobars \\
        --disable-session-crashed-bubble \\
        --disable-restore-session-state \\
        --check-for-update-interval=31536000 \\
        --start-fullscreen \\
        --kiosk \\
        --window-position=0,0 \\
        --window-size=\${SCREEN_W},\${SCREEN_H} \\
        '$MAGICMIRROR_URL'
" -- :1 vt8 -nocursor
