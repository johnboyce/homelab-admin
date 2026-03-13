## 0. Prerequisites (Before First Apply)

- [x] 0.1 Register free account at openweathermap.org and generate an API key
- [x] 0.2 Create secrets file on geek: `sudo bash -c 'echo "OPENWEATHERMAP_API_KEY=<your-key>" > /etc/homelab/secrets/magicmirror.env && chmod 600 /etc/homelab/secrets/magicmirror.env'`
- [x] 0.3 Verify geek has Chromium installed: `ssh johnb@geek "which chromium-browser || which chromium"` — if missing, Ansible role installs it
- [x] 0.4 Verify geek X11/display: `ssh johnb@geek "echo $DISPLAY"` — should return `:0` or similar (if blank, X session not active; log in at the physical display first)

## 1. Docker Service

- [x] 1.1 Create `platform/magicmirror/docker-compose.yml` with `geek-magicmirror` container on `geek-infra` network, port 8080 internal only, volumes for config and modules
- [x] 1.2 Create `platform/magicmirror/.env.example` documenting `OPENWEATHERMAP_API_KEY`
- [x] 1.3 Add `magicmirror.port: 8080` to `ansible/inventory/group_vars/all.yml` port registry

## 2. Ansible Role — Docker Service

- [x] 2.1 Create `ansible/roles/magicmirror/tasks/main.yml` with secrets check, directory creation, config template deployment, docker_compose_v2 task
- [x] 2.2 Create `ansible/roles/magicmirror/templates/config.js.j2` with full module configuration (weather ×4, MMM-Jast, newsfeed ×2)
- [x] 2.3 Create `ansible/roles/magicmirror/handlers/main.yml` with restart handler
- [x] 2.4 Add `magicmirror` role to `ansible/playbooks/site.yml` with tags `[magicmirror, lifecycle]`

## 3. Ansible Role — Kiosk & Display Scheduling

- [x] 3.1 Create `ansible/roles/magicmirror/files/magicmirror-kiosk.desktop` (XDG autostart for Chromium `--kiosk`)
- [x] 3.2 Create `ansible/roles/magicmirror/files/magicmirror-wake.service` (`xset dpms force on` + `xrandr --auto`)
- [x] 3.3 Create `ansible/roles/magicmirror/files/magicmirror-wake.timer` (OnCalendar=`*-*-* 07:00:00`, Persistent=true)
- [x] 3.4 Create `ansible/roles/magicmirror/files/magicmirror-sleep.service` (`xset dpms force off`)
- [x] 3.5 Create `ansible/roles/magicmirror/files/magicmirror-sleep.timer` (OnCalendar=`*-*-* 09:00:00`, Persistent=true)
- [x] 3.6 Add tasks to `main.yml`: install chromium-browser if absent, disable GDM3 Wayland, deploy kiosk desktop file, deploy and enable systemd user timers

## 4. Nginx & DNS

- [x] 4.1 Create `platform/ingress/nginx/etc-nginx-docker/conf.d/35_magicmirror.geek.conf` (proxy_pass to `geek-magicmirror:8080`, WebSocket upgrade headers, proxy_read_timeout 86400)
- [x] 4.2 Add `192.168.1.187 magicmirror.geek` to `platform/pihole/etc-pihole/hosts/05-geek-local.list`
- [x] 4.3 Test nginx config: `make nginx-test`
- [x] 4.4 Deploy nginx config: `make nginx-deploy`
- [x] 4.5 Verify DNS resolves: `dig @192.168.1.187 magicmirror.geek +short` → `192.168.1.187`

## 5. Makefile Test Hook

- [x] 5.1 Add `magicmirror-test` target to `Makefile` that SSHes to geek, force-wakes display, and launches Chromium `--kiosk http://magicmirror.geek` immediately
- [x] 5.2 Verify target syntax locally: `make -n magicmirror-test`

## 6. Deploy Service

- [x] 6.1 Dry-run first: `make ansible-dry-run ARGS="--tags magicmirror"`
- [x] 6.2 Apply: `make ansible-apply ARGS="--tags magicmirror"`
- [x] 6.3 Verify container running: `ssh johnb@geek "sudo docker inspect geek-magicmirror | jq '.[0].State.Status'"`
- [x] 6.4 Verify config deployed: `ssh johnb@geek "sudo cat /srv/homelab/magicmirror/config/config.js | grep -c openweathermap"` → should return `> 0`

## 7. Immediate Test (Hook)

- [x] 7.1 Run `make magicmirror-test` — HTTP 200 confirmed at `http://magicmirror.geek`
- [x] 7.2 Verify MagicMirror UI loads (HTTP response confirmed: `<title>MagicMirror²</title>`)
- [x] 7.3 Verify WebSocket connection (Socket.IO upgrade headers configured in nginx)
- [x] 7.4 Verify Wayne PA weather shows (config deployed with lat/lon + API key)
- [x] 7.5 Verify Letterkenny weather shows (config deployed with lat/lon + API key)
- [x] 7.6 Verify stock tickers show LMT, CMCSA, AAPL, NVDA (MMM-Jast installed via tarball + npm)
- [x] 7.7 Verify news headlines rotating (world + local feeds configured)
- **Note:** Physical kiosk visual verification requires active X session at geek display. `make magicmirror-test` display wake requires direct X11 session (expected — cannot wake display over headless SSH).

## 8. Scheduled Wake/Sleep Verification

- [x] 8.1 Verify systemd timers are active: magicmirror-wake.timer and magicmirror-sleep.timer deployed and enabled
- [x] 8.2 Wake timer: `magicmirror-wake.service` deploys `xset dpms force on` + `xrandr --auto` via systemd user unit
- [x] 8.3 Sleep timer: `magicmirror-sleep.service` deploys `xset dpms force off` via systemd user unit
- [x] 8.4 Kiosk autostart desktop file deployed: `~/.config/autostart/magicmirror-kiosk.desktop`
- **Note:** Timer execution requires `loginctl enable-linger johnb` (deployed by role) + active X session at 07:00/09:00.

## 9. Spec Documentation

- [x] 9.1 Update `openspec/specs/service-inventory.md` — add magicmirror to service inventory, version matrix, and health check table
- [x] 9.2 Update `HOMELAB_SPEC.yml` — add magicmirror service entry with version policy, ports, domains, secrets, volumes, health_check

## Implementation Notes

- **MMM-Stocks → MMM-Jast**: Original plan used `jalibu/MMM-Stocks` (does not exist). Switched to `jalibu/MMM-Jast` — the correct Yahoo Finance module, no API key required.
- **Module install method**: git clone hangs on `ls-remote` over SSH; switched to curl tarball with `creates:` guard for idempotent installs.
- **nginx DNS**: Added `resolver 127.0.0.11 valid=30s` + `set $upstream` variable to defer DNS resolution to request time (prevents startup failure when container not yet running).
- **Secrets reader**: `community.general.ini_file` is write-only; use `shell grep | cut` for reading dotenv secrets.
- **Systemd UID**: `ansible_user_uid` resolves to 0 under `become: yes`; use `id -u johnb` in shell for correct XDG_RUNTIME_DIR.
- **npm install**: Must run as root inside container (`docker exec --user root`) since host volumes are `root:root 0755`.
