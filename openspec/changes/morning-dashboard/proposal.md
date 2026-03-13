## Why

A dedicated morning information display on the geek microPC would provide an at-a-glance briefing each morning without any interaction — current weather for both Wayne PA (19342) and Letterkenny, Donegal Ireland, a multi-day forecast, live stock prices (LMT, CMCSA, AAPL, NVDA), and rotating news headlines from world and local Philadelphia-area sources. The display should wake at 07:00, show the dashboard, and sleep at 09:00 autonomously. MagicMirror² is the established self-hosted solution for this use case, runs well in Docker, and integrates cleanly with the existing geek-infra stack.

## What Changes

**New files:**
- `platform/magicmirror/docker-compose.yml` — MagicMirror² container on `geek-infra` network
- `platform/magicmirror/.env.example` — documents required `OPENWEATHERMAP_API_KEY` secret
- `platform/ingress/nginx/etc-nginx-docker/conf.d/35_magicmirror.geek.conf` — nginx reverse proxy with WebSocket support
- `ansible/roles/magicmirror/tasks/main.yml` — Docker service deployment + host kiosk + display scheduling
- `ansible/roles/magicmirror/templates/config.js.j2` — Jinja2-templated MagicMirror² config with all modules
- `ansible/roles/magicmirror/files/magicmirror-wake.service` — systemd user unit to power on display
- `ansible/roles/magicmirror/files/magicmirror-wake.timer` — fires at 07:00 daily
- `ansible/roles/magicmirror/files/magicmirror-sleep.service` — systemd user unit to power off display
- `ansible/roles/magicmirror/files/magicmirror-sleep.timer` — fires at 09:00 daily
- `ansible/roles/magicmirror/files/magicmirror-kiosk.desktop` — XDG autostart entry for Chromium kiosk

**Modified files:**
- `platform/pihole/etc-pihole/hosts/05-geek-local.list` — add `magicmirror.geek`
- `ansible/inventory/group_vars/all.yml` — add `magicmirror.port: 8080` to port registry
- `ansible/playbooks/site.yml` — add `magicmirror` role with `[magicmirror, lifecycle]` tags
- `Makefile` — add `magicmirror-test` target for immediate test without waiting for schedule
- `HOMELAB_SPEC.yml` — add magicmirror service entry and version matrix row

## Capabilities

### New Capabilities

- `morning-dashboard`: Requirements for the MagicMirror² service, kiosk mode configuration, display scheduling, and immediate test hook.

### Modified Capabilities

- `service-inventory`: Add magicmirror to the service registry with pinned version and `strategy: pinned` version policy.

## Impact

- **New Docker container** (`geek-magicmirror`) on `geek-infra` — no impact on existing services
- **New nginx vhost** (`magicmirror.geek`) — no changes to existing vhosts; requires nginx reload
- **New DNS entry** — Pi-hole reload required after hosts list update
- **Host display config changes on geek** — XDG autostart and systemd user timers affect the `johnb` user session only; no system-level impact on other services
- **Ubuntu 24.04 X11 requirement** — `xset dpms` requires an X11 session. If geek is running a Wayland session, GDM3 must be configured to use X11 (one-line change to `/etc/gdm3/custom.conf`)
- **One new secret required** — `OPENWEATHERMAP_API_KEY` must be added to `/etc/homelab/secrets/magicmirror.env` on geek before first deploy; free-tier OWM account sufficient
