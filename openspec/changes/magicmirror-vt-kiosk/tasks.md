## 1. New kiosk scripts

- [x] 1.1 Create `magicmirror-kiosk-x11.sh` — xinit wrapper that starts X server on `:1 vt8` and exec's Chromium in fullscreen kiosk mode pointing at `http://magicmirror.geek` (no window manager, no screensaver)
- [x] 1.2 Create `magicmirror-kiosk-wake.sh` — checks for active GNOME sessions on seat0 via `loginctl`, runs `chvt 8` only if no user session is active
- [x] 1.3 Create `magicmirror-kiosk-sleep.sh` — stops the kiosk service via `systemctl stop`, then sets DPMS to power off the monitor

## 2. New system-level systemd units

- [x] 2.1 Create `magicmirror-kiosk.service` — system-level service that runs `magicmirror-kiosk-x11.sh` as `User=johnb`, `Type=simple`, with `ExecStartPre=+/usr/bin/chvt 8` (smart switch via wake script)
- [x] 2.2 Create `magicmirror-kiosk-wake.timer` — system-level timer firing at `07:00` daily, starts `magicmirror-kiosk-wake.service`
- [x] 2.3 Create `magicmirror-kiosk-wake.service` — system-level oneshot that runs the wake script (session check + start kiosk)
- [x] 2.4 Create `magicmirror-kiosk-sleep.timer` — system-level timer firing at `08:00` daily (confirm schedule with user), starts `magicmirror-kiosk-sleep.service`
- [x] 2.5 Create `magicmirror-kiosk-sleep.service` — system-level oneshot that runs the sleep script (stop kiosk + DPMS off)
- [x] 2.6 Create system-level `magicmirror-snapshot-cache.service` — same functionality as current user-level unit, runs as `User=johnb`
- [x] 2.7 Create system-level `magicmirror-snapshot-cache.timer` — same schedule (every 30s), system-level

## 3. Ansible role — cleanup legacy artifacts

- [x] 3.1 Add tasks to stop and disable old user-level timers (`magicmirror-wake.timer`, `magicmirror-sleep.timer`, `magicmirror-snapshot-cache.timer`) before removing files
- [x] 3.2 Add tasks to remove old user-level systemd unit files from `/home/johnb/.config/systemd/user/` (all 6 files)
- [x] 3.3 Add task to remove `magicmirror-keep-awake.sh` from `/home/johnb/.local/bin/`
- [x] 3.4 Add task to remove legacy autostart entries (`magicmirror-kiosk.desktop`, `display-noblank.desktop`) from `/home/johnb/.config/autostart/`
- [x] 3.5 Remove the `magicmirror-keep-awake.sh` source file from `ansible/roles/magicmirror/files/`
- [x] 3.6 Remove the old user-level `.service` and `.timer` source files from `ansible/roles/magicmirror/files/` (wake, sleep, snapshot-cache)
- [x] 3.7 Remove old `magicmirror-kiosk.sh`, `magicmirror-display-wake.sh`, `magicmirror-display-sleep.sh` source files from `ansible/roles/magicmirror/files/`

## 4. Ansible role — GDM configuration

- [x] 4.1 Replace the GDM auto-login `blockinfile` task with a task that removes the auto-login block (uses `blockinfile` with `state: absent` or removes the marker block)
- [x] 4.2 Replace the Wayland disable `lineinfile` task with a task that comments out or removes `WaylandEnable=false` (restores default)
- [x] 4.3 Update the `Restart GDM` handler — keep it, but only notify when GDM config actually changes

## 5. Ansible role — deploy new units and scripts

- [x] 5.1 Add task to ensure `xinit` package is installed (`xorg` or `xinit` package via apt)
- [x] 5.2 Add task to deploy new kiosk scripts to `/home/johnb/.local/bin/` (kiosk-x11, kiosk-wake, kiosk-sleep)
- [x] 5.3 Add task to deploy system-level systemd units to `/etc/systemd/system/` (kiosk service, wake service+timer, sleep service+timer, snapshot-cache service+timer)
- [x] 5.4 Add handler to run `systemctl daemon-reload` when system units change
- [x] 5.5 Add tasks to enable and start the system-level timers (wake, sleep, snapshot-cache)
- [x] 5.6 Remove the `loginctl enable-linger` task (no longer needed — system timers don't require lingering)

## 6. Ansible role — update tasks/main.yml structure

- [x] 6.1 Rewrite `tasks/main.yml` to reflect new task ordering: secrets → docker → modules → packages → GDM cleanup → legacy removal → deploy scripts → deploy units → enable timers
- [x] 6.2 Update role header comment to remove "Requires: X11 session (GDM3 Wayland disabled by this role)"
- [x] 6.3 Update `handlers/main.yml` — add system-level daemon-reload handler, keep docker restart and GDM restart handlers

## 7. Verification

- [x] 7.1 Run `make ansible-dry-run` and review the diff for correctness
- [x] 7.2 Apply with `make ansible-apply ARGS="--tags magicmirror"` on geek
- [ ] 7.3 Reboot geek — verify GDM login screen appears (not auto-logged-in desktop)
- [x] 7.4 Verify system timers are active: `systemctl list-timers 'magicmirror-*'`
- [x] 7.5 Manually trigger kiosk: `sudo systemctl start magicmirror-kiosk-wake.service` — verify MagicMirror displays on monitor
- [x] 7.6 Manually trigger sleep: `sudo systemctl start magicmirror-kiosk-sleep.service` — verify monitor powers off
- [ ] 7.7 Log in via GDM to GNOME, start kiosk manually, verify monitor stays on GNOME session (no VT switch)
- [ ] 7.8 Run Ansible role a second time — verify zero changed tasks (idempotency)
