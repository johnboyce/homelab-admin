## ADDED Requirements

### Requirement: Standalone X kiosk on dedicated VT

The system SHALL run a standalone X server on display `:1` and VT8 with Chromium in fullscreen kiosk mode pointing at `http://magicmirror.geek`. The X server SHALL have no window manager, screensaver, or DPMS configured. The kiosk SHALL be managed by a system-level systemd service (`magicmirror-kiosk.service`).

#### Scenario: Kiosk service starts successfully
- **WHEN** `magicmirror-kiosk.service` is started (by timer or manually)
- **THEN** an X server starts on display `:1`, VT8, running Chromium in fullscreen kiosk mode displaying `http://magicmirror.geek`

#### Scenario: Kiosk service stops cleanly
- **WHEN** `magicmirror-kiosk.service` is stopped (by timer or manually)
- **THEN** Chromium and the X server on display `:1` are terminated, and VT8 is released

#### Scenario: Kiosk runs without window manager
- **WHEN** the kiosk X server is running
- **THEN** no window manager, desktop environment, screensaver, or idle timer is active on display `:1`

### Requirement: Scheduled wake and sleep via system timers

The system SHALL use system-level systemd timers to start and stop the kiosk service on a daily schedule. The wake timer SHALL fire at 07:00 and the sleep timer SHALL fire at the configured end time daily.

#### Scenario: Morning wake activates kiosk
- **WHEN** the wake timer fires at 07:00
- **THEN** `magicmirror-kiosk.service` is started and the physical monitor displays the MagicMirror dashboard

#### Scenario: Sleep timer deactivates kiosk
- **WHEN** the sleep timer fires
- **THEN** `magicmirror-kiosk.service` is stopped and the physical monitor enters DPMS standby (powers off)

#### Scenario: Timers survive reboot
- **WHEN** the geek server is rebooted
- **THEN** the wake and sleep timers are active and will fire at their next scheduled times without manual intervention

### Requirement: Smart VT switching preserves active desktop sessions

The kiosk wake process SHALL check for active GNOME sessions on `seat0` before switching the monitor to VT8. If the user has an active graphical session, the kiosk SHALL start on VT8 but the monitor SHALL remain on the user's current VT.

#### Scenario: No active user session — monitor switches to kiosk
- **WHEN** the wake timer fires and no user (other than `gdm`) has an active graphical session on `seat0`
- **THEN** the monitor switches to VT8 showing the MagicMirror dashboard

#### Scenario: User is in active GNOME session — monitor stays on user's VT
- **WHEN** the wake timer fires and `johnb` has an active graphical session on `seat0`
- **THEN** the kiosk starts on VT8 but the monitor remains on the user's current VT

#### Scenario: User can manually switch to kiosk VT
- **WHEN** the kiosk is running on VT8 and the user presses Ctrl+Alt+F8
- **THEN** the monitor switches to VT8 showing the MagicMirror dashboard

### Requirement: No GDM auto-login after reboot

After reboot, GDM SHALL display its login screen. The system SHALL NOT auto-login any user. The user SHALL be able to log in manually to a GNOME session at any time.

#### Scenario: Server reboots to login screen
- **WHEN** geek is rebooted
- **THEN** the physical monitor shows the GDM login screen, not a logged-in desktop

#### Scenario: Manual GNOME login works normally
- **WHEN** the user selects `johnb` at the GDM login screen and enters credentials
- **THEN** a normal GNOME desktop session starts on VT2

### Requirement: GDM Wayland setting restored to default

The system SHALL NOT force `WaylandEnable=false` in GDM configuration. GDM SHALL use its default session type.

#### Scenario: GDM config has no Wayland override
- **WHEN** the Ansible role is applied
- **THEN** `/etc/gdm3/custom.conf` does not contain `WaylandEnable=false` set by this role

### Requirement: Legacy kiosk artifacts removed

The Ansible role SHALL remove all user-level systemd units, autostart entries, and the mouse wiggler script that were part of the previous kiosk implementation.

#### Scenario: User-level systemd units cleaned up
- **WHEN** the Ansible role is applied
- **THEN** `magicmirror-wake.service`, `magicmirror-wake.timer`, `magicmirror-sleep.service`, `magicmirror-sleep.timer`, `magicmirror-snapshot-cache.service`, and `magicmirror-snapshot-cache.timer` do not exist in `/home/johnb/.config/systemd/user/`

#### Scenario: Legacy autostart entries removed
- **WHEN** the Ansible role is applied
- **THEN** `magicmirror-kiosk.desktop` and `display-noblank.desktop` do not exist in `/home/johnb/.config/autostart/`

#### Scenario: Mouse wiggler removed
- **WHEN** the Ansible role is applied
- **THEN** `magicmirror-keep-awake.sh` does not exist in `/home/johnb/.local/bin/`

### Requirement: Camera snapshot cache preserved as system service

The snapshot cache functionality SHALL be preserved and moved to a system-level systemd timer/service, running as `johnb`. Functionality (polling go2rtc every 30 seconds) SHALL be unchanged.

#### Scenario: Snapshot cache runs after migration
- **WHEN** the Ansible role is applied and the system is running
- **THEN** `magicmirror-snapshot-cache.timer` is active as a system-level timer, polling go2rtc every 30 seconds

### Requirement: Ansible deployment is idempotent

Running `make ansible-apply ARGS="--tags magicmirror"` multiple times SHALL produce the same result. No errors or unnecessary restarts SHALL occur on subsequent runs.

#### Scenario: Second Ansible run reports no changes
- **WHEN** the Ansible role is applied twice in succession with no manual changes
- **THEN** the second run reports zero changed tasks (all tasks return "ok")
