## Why

After the MagicMirror kiosk was implemented, rebooting geek auto-logs `johnb` into a full GNOME desktop — wrong for a server that's also used for Docker services. The current approach (GDM auto-login → GNOME session → user-level timers → Chromium kiosk) conflates display management with the user's desktop session. The user needs regular desktop access (1-2x/week) and occasional gaming, so GDM and GNOME must stay — but the kiosk should be decoupled from the user session entirely.

## What Changes

- **Remove GDM auto-login** — after reboot, GDM shows its login screen instead of auto-logging into a desktop
- **Remove Wayland disable hack** — no longer needed since the kiosk runs its own X server, not the GDM/GNOME one
- **Replace user-level systemd services/timers with system-level ones** — kiosk lifecycle managed by root, not tied to `johnb`'s session
- **New kiosk architecture**: system-level service starts a standalone X server + Chromium on a dedicated VT (VT8), completely independent of GDM/GNOME
- **Remove mouse wiggler** (`magicmirror-keep-awake.sh`) — the kiosk X server has no screensaver, idle manager, or DPMS to fight against
- **Smart VT switching** — wake timer only switches the monitor to VT8 if the user isn't in an active GNOME session; user can always manually switch VTs
- **Preserve snapshot cache** — camera snapshot timer moves to system-level but functionality is unchanged
- **Remove legacy autostart artifacts** (`magicmirror-kiosk.desktop`, `display-noblank.desktop`)
- **Cleanup of user-level systemd units** — old timer/service files removed from `~/.config/systemd/user/`

## Capabilities

### New Capabilities
- `vt-kiosk-display`: System-level X kiosk on a dedicated VT — starts/stops a standalone X server with Chromium, independent of GDM and user sessions

### Modified Capabilities

_(none — no existing specs are changing at the requirement level)_

## Impact

- **Ansible role**: `ansible/roles/magicmirror/` — tasks, handlers, and files significantly reworked
- **GDM config**: `/etc/gdm3/custom.conf` — auto-login block removed; Wayland disable line removed
- **systemd**: user-level units in `~/.config/systemd/user/` replaced with system-level units in `/etc/systemd/system/`
- **Scripts**: wake/sleep/kiosk scripts rewritten for standalone X; keep-awake script deleted
- **Dependencies**: `xinit` (from `xorg` package) required on geek; `xdotool` and `wmctrl` no longer needed for kiosk (may still be installed for other use)
- **Rollback**: re-run the Ansible role at a prior commit to restore auto-login + user-level timers
