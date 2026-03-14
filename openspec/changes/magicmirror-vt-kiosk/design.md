## Context

The geek server runs a MagicMirror morning dashboard (07:00–08:00) on its physical monitor. The current implementation auto-logs `johnb` into a full GNOME desktop via GDM, then uses user-level systemd timers to launch/kill Chromium in kiosk mode and manage DPMS. This causes the server to boot into a visible desktop — undesirable for a machine that primarily runs Docker infrastructure services. The user also needs regular GNOME desktop access (1-2x/week) and occasional gaming, so GDM and GNOME must remain installed and accessible.

**Current flow:**
```
Boot → GDM auto-login → GNOME desktop (visible!) → user timers → wake/sleep scripts → Chromium + mouse wiggler
```

**Target flow:**
```
Boot → GDM login screen (idle) → system timer at 07:00 → xinit on VT8 → Chromium kiosk (monitor switches to VT8)
                                 → system timer at 08:00 → kill X on VT8 → DPMS off (monitor sleeps)
User login (on demand) → GDM → GNOME on VT2 (unaffected by kiosk lifecycle)
```

## Goals / Non-Goals

**Goals:**
- After reboot, geek shows GDM login screen — never an auto-logged-in desktop
- MagicMirror displays on schedule without any user session
- Desktop/gaming sessions are completely uninterrupted by kiosk lifecycle
- Idempotent Ansible deployment — safe to run repeatedly
- Clean removal of all legacy artifacts (user timers, mouse wiggler, autostart files, GDM hacks)

**Non-Goals:**
- Changing the MagicMirror Docker service, config, or modules (unchanged)
- Changing the snapshot cache functionality (preserved, moved to system-level)
- Supporting multiple monitors or display outputs
- Remote/VNC access to the kiosk display
- Changing the wake/sleep schedule (stays 07:00/08:00, configurable via timer)

## Decisions

### 1. Standalone X server via `xinit` on VT8

**Decision:** The kiosk runs its own X server on display `:1` and VT8, started by `xinit`.

**Why:** A standalone X server is the simplest way to get Chromium on a display without a desktop environment. No window manager, no screensaver, no idle detection — just X + Chromium. The X server owns VT8 exclusively, so it doesn't conflict with GDM (VT1) or GNOME sessions (VT2+).

**Alternatives considered:**
- *cage (Wayland kiosk compositor)*: Purpose-built for kiosks but requires installing a new package, rewriting all display management for Wayland, and is less battle-tested on Ubuntu server. Overkill for a single-app display.
- *Custom GDM session (`.desktop` file)*: Still requires auto-login, which is the problem we're solving. Even a minimal session means GDM logs a user in automatically.
- *Framebuffer browser (no X)*: Very limited browser options, no hardware acceleration.

### 2. System-level systemd units (not user-level)

**Decision:** All kiosk services and timers run as system-level units under `/etc/systemd/system/`, executing as `johnb` via the `User=` directive.

**Why:** User-level timers require either an active login session or `loginctl enable-linger`. The current setup relies on both auto-login AND lingering. System-level timers fire regardless of login state — they're managed by PID 1 and start at boot. This is the correct level for infrastructure that should run without human interaction.

**Alternatives considered:**
- *Keep user-level timers + lingering*: Would still work without auto-login (lingering keeps user services alive), but conceptually wrong — this is infrastructure, not a user preference. Also fragile if lingering gets disabled.

### 3. Smart VT switching with active-session detection

**Decision:** The wake script checks for an active GNOME session on `seat0` before switching VTs. If the user is logged in and using the desktop, the kiosk starts on VT8 but the monitor stays on the user's VT.

**Why:** The user logs into GNOME 1-2x/week. The kiosk should never yank the monitor away from an active session. The user can manually switch to VT8 (`Ctrl+Alt+F8`) to see MagicMirror if they want.

**Implementation:**
```bash
# Only switch VT if no graphical user session is active
if ! loginctl list-sessions --no-legend | grep -v gdm | grep -q "seat0.*tty[2-7]"; then
    chvt 8
fi
```

### 4. No mouse wiggler needed

**Decision:** Remove `magicmirror-keep-awake.sh` entirely.

**Why:** The standalone X server has no screensaver, no idle timer, and no DPMS configured. There's nothing to fight against. GNOME's idle management only applies to GNOME sessions, not to our bare X server. The display stays on because nothing turns it off — the sleep timer handles shutdown explicitly.

### 5. Kiosk script simplified — no wmctrl

**Decision:** Use Chromium's `--start-fullscreen` flag directly. Remove the `wmctrl` hack.

**Why:** The current kiosk script uses `wmctrl` to force fullscreen because GNOME's window management sometimes overrides `--kiosk`. With no window manager at all, Chromium is the only client — `--start-fullscreen` works reliably and `--kiosk` disables UI chrome. No `sleep 8 && wmctrl` race condition.

### 6. Snapshot cache moves to system-level timer

**Decision:** `magicmirror-snapshot-cache.service` and timer move from user-level to system-level, running as `johnb` via `User=johnb`.

**Why:** Consistency with the rest of the kiosk infrastructure. The snapshot cache runs `curl` to poll go2rtc — it doesn't need an X session or any desktop integration.

### 7. GDM cleanup — remove auto-login and Wayland hack

**Decision:** Remove the `blockinfile` auto-login block and the `WaylandEnable=false` line from `/etc/gdm3/custom.conf`.

**Why:** The kiosk no longer uses GDM's X session. GDM can run Wayland or X11 for the login screen — it doesn't matter. The user's GNOME session type is their choice. The auto-login block is the root cause of the reported problem.

## Risks / Trade-offs

**[Risk] X server on VT8 may not start if GPU is busy** → The standalone X server needs GPU access. If GDM or a GNOME session is using the GPU, a second X server should still work (multi-seat X is well-supported on modern GPUs), but if it fails, the timer will log errors to the journal. Mitigation: test on geek before merging; fallback is the user manually starting MagicMirror.

**[Risk] `chvt` requires root** → VT switching requires `CAP_SYS_TTY_CONFIG` or root. Since systemd system services run as root by default (with `User=` for the exec), the pre-start VT switch can run as root while Chromium runs as `johnb`. Mitigation: use a `ExecStartPre=+/usr/bin/chvt 8` (the `+` prefix runs as root even when `User=` is set).

**[Risk] Two X servers consume more GPU memory** → Minimal impact. The kiosk X server runs a single Chromium tab. GPU memory usage is negligible compared to gaming. The kiosk X server is killed by the sleep timer, so it's only alive during the dashboard window.

**[Trade-off] Display `:1` vs `:0`** → GDM uses `:0`. Our kiosk uses `:1`. Scripts must set `DISPLAY=:1` explicitly. This is a permanent divergence from the old approach where everything shared `:0`.

**[Trade-off] No Wayland for kiosk** → We chose X11 via `xinit` because it's simpler and more predictable for this use case. If Ubuntu drops X11 support in a future release, we'd need to switch to `cage` or similar. This is a distant concern for a homelab.

## Migration Plan

1. **Dry run:** `make ansible-dry-run` to preview changes
2. **Apply:** `make ansible-apply ARGS="--tags magicmirror"` — this will:
   - Remove auto-login from GDM config
   - Remove Wayland disable line from GDM config
   - Deploy new system-level units
   - Remove old user-level units
   - Deploy new scripts, remove legacy scripts
   - Restart GDM (takes user back to login screen)
   - Enable and start system timers
3. **Verify:** Reboot geek, confirm GDM login screen appears (not desktop)
4. **Verify:** Wait for wake timer (or trigger manually: `sudo systemctl start magicmirror-kiosk.service`) — confirm MagicMirror displays
5. **Rollback:** `git checkout HEAD~1 -- ansible/roles/magicmirror/ && make ansible-apply ARGS="--tags magicmirror"` restores prior behavior

## Open Questions

1. **Wake/sleep schedule** — Currently 07:00–08:00. The sleep timer says 08:00 but the proposal mentioned 09:00. Need to confirm the desired window with the user before implementation.
