## 0. Prerequisites (Before First Apply)

- [ ] 0.1 Register free account at openweathermap.org and generate an API key
- [ ] 0.2 Create secrets file on geek: `sudo bash -c 'echo "OPENWEATHERMAP_API_KEY=<your-key>" > /etc/homelab/secrets/magicmirror.env && chmod 600 /etc/homelab/secrets/magicmirror.env'`
- [ ] 0.3 Verify geek has Chromium installed: `ssh johnb@geek "which chromium-browser || which chromium"` — if missing, Ansible role installs it
- [ ] 0.4 Verify geek X11/display: `ssh johnb@geek "echo $DISPLAY"` — should return `:0` or similar (if blank, X session not active; log in at the physical display first)

## 1. Docker Service

- [ ] 1.1 Create `platform/magicmirror/docker-compose.yml` with `geek-magicmirror` container on `geek-infra` network, port 8080 internal only, volumes for config and modules
- [ ] 1.2 Create `platform/magicmirror/.env.example` documenting `OPENWEATHERMAP_API_KEY`
- [ ] 1.3 Add `magicmirror.port: 8080` to `ansible/inventory/group_vars/all.yml` port registry

## 2. Ansible Role — Docker Service

- [ ] 2.1 Create `ansible/roles/magicmirror/tasks/main.yml` with secrets check, directory creation, config template deployment, docker_compose_v2 task
- [ ] 2.2 Create `ansible/roles/magicmirror/templates/config.js.j2` with full module configuration (weather ×4, MMM-Stocks, newsfeed ×2)
- [ ] 2.3 Create `ansible/roles/magicmirror/handlers/main.yml` with restart handler
- [ ] 2.4 Add `magicmirror` role to `ansible/playbooks/site.yml` with tags `[magicmirror, lifecycle]`

## 3. Ansible Role — Kiosk & Display Scheduling

- [ ] 3.1 Create `ansible/roles/magicmirror/files/magicmirror-kiosk.desktop` (XDG autostart for Chromium `--kiosk`)
- [ ] 3.2 Create `ansible/roles/magicmirror/files/magicmirror-wake.service` (`xset dpms force on` + `xrandr --auto`)
- [ ] 3.3 Create `ansible/roles/magicmirror/files/magicmirror-wake.timer` (OnCalendar=`*-*-* 07:00:00`, Persistent=true)
- [ ] 3.4 Create `ansible/roles/magicmirror/files/magicmirror-sleep.service` (`xset dpms force off`)
- [ ] 3.5 Create `ansible/roles/magicmirror/files/magicmirror-sleep.timer` (OnCalendar=`*-*-* 09:00:00`, Persistent=true)
- [ ] 3.6 Add tasks to `main.yml`: install chromium-browser if absent, disable GDM3 Wayland, deploy kiosk desktop file, deploy and enable systemd user timers

## 4. Nginx & DNS

- [ ] 4.1 Create `platform/ingress/nginx/etc-nginx-docker/conf.d/35_magicmirror.geek.conf` (proxy_pass to `geek-magicmirror:8080`, WebSocket upgrade headers, proxy_read_timeout 86400)
- [ ] 4.2 Add `192.168.1.187 magicmirror.geek` to `platform/pihole/etc-pihole/hosts/05-geek-local.list`
- [ ] 4.3 Test nginx config: `make nginx-test`
- [ ] 4.4 Deploy nginx config: `make nginx-deploy`
- [ ] 4.5 Verify DNS resolves: `dig @192.168.1.187 magicmirror.geek +short` → `192.168.1.187`

## 5. Makefile Test Hook

- [ ] 5.1 Add `magicmirror-test` target to `Makefile` that SSHes to geek, force-wakes display, and launches Chromium `--kiosk http://magicmirror.geek` immediately
- [ ] 5.2 Verify target syntax locally: `make -n magicmirror-test`

## 6. Deploy Service

- [ ] 6.1 Dry-run first: `make ansible-dry-run ARGS="--tags magicmirror"`
- [ ] 6.2 Apply: `make ansible-apply ARGS="--tags magicmirror"`
- [ ] 6.3 Verify container running: `ssh johnb@geek "sudo docker inspect geek-magicmirror | jq '.[0].State.Status'"`
- [ ] 6.4 Verify config deployed: `ssh johnb@geek "sudo cat /srv/homelab/magicmirror/config/config.js | grep -c openweathermap"` → should return `> 0`

## 7. Immediate Test (Hook)

- [ ] 7.1 Run `make magicmirror-test` — display should wake and Chromium should open at `http://magicmirror.geek`
- [ ] 7.2 Verify MagicMirror UI loads (weather, stocks, news modules visible)
- [ ] 7.3 Verify WebSocket connection (modules update in real time — clock ticks, no stale data)
- [ ] 7.4 Verify Wayne PA weather shows (current + forecast)
- [ ] 7.5 Verify Letterkenny weather shows (current + forecast)
- [ ] 7.6 Verify stock tickers show LMT, CMCSA, AAPL, NVDA
- [ ] 7.7 Verify news headlines rotating (world + local)

## 8. Scheduled Wake/Sleep Verification

- [ ] 8.1 Verify systemd timers are active: `ssh johnb@geek "systemctl --user list-timers | grep magicmirror"`
- [ ] 8.2 Test wake timer manually: `ssh johnb@geek "systemctl --user start magicmirror-wake.service"` → display powers on
- [ ] 8.3 Test sleep timer manually: `ssh johnb@geek "systemctl --user start magicmirror-sleep.service"` → display powers off
- [ ] 8.4 Verify kiosk autostart desktop file deployed: `ssh johnb@geek "ls ~/.config/autostart/magicmirror-kiosk.desktop"`

## 9. Spec Documentation

- [ ] 9.1 Update `openspec/specs/service-inventory/spec.md` — add magicmirror row to version registry table with version and `strategy: pinned`
- [ ] 9.2 Update `HOMELAB_SPEC.yml` — add magicmirror service entry with version policy, ports, domains, health_check
