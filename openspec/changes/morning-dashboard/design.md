## Context

MagicMirror² is a Node.js dashboard framework running on port 8080. The `karsten13/magicmirror` Docker image is the canonical maintained image — it runs the MM² app server inside the container, serves the browser-based UI, and supports Socket.IO for real-time module updates. The kiosk is a Chromium browser on the geek host pointed at `http://magicmirror.geek` (nginx proxy → container).

| Component | Decision | Rationale |
|-----------|----------|-----------|
| Container image | `karsten13/magicmirror` | Most-maintained MM² Docker image; supports volume-mounted config and modules |
| Container port | 8080 | MM² default; internal only (nginx handles all ingress) |
| Config delivery | Ansible Jinja2 template → `config.js` | Keeps API key out of git; idempotent; follows existing role patterns |
| Weather module | MM² built-in `weather` (OpenWeatherMap provider) | No extra module install needed; supports multiple locations; free OWM tier is sufficient |
| Stocks module | `jalibu/MMM-Stocks` (Yahoo Finance) | No API key required; supports ticker list; actively maintained |
| News module | MM² built-in `newsfeed` | RSS-based; no API key; supports multiple simultaneous feeds |
| Kiosk browser | Chromium (`--kiosk` flag) | Available in Ubuntu 24.04 repos; supports `--kiosk` natively; no session restore prompts |
| Display scheduling | `systemd --user` timers | More reliable than cron for display operations in a user session context; survives reboots |
| X11 vs Wayland | X11 session required | `xset dpms force on/off` does not work under Wayland; GDM3 configured to disable Wayland |

## MagicMirror² Module Configuration

**Weather locations:**
- Wayne PA (zip 19342): lat 39.8962, lon -75.5288 — OWM location string `"Wayne,US"`
- Letterkenny, Donegal, Ireland: lat 54.9558, lon -7.7342 — OWM location string `"Letterkenny,IE"`
- Each location gets: current conditions + 5-day forecast (shown as separate module instances)
- Units: imperial for Wayne PA, metric for Letterkenny

**Stocks:** `LMT` (Lockheed Martin), `CMCSA` (Comcast), `AAPL` (Apple), `NVDA` (NVIDIA) — polled every 5 minutes via Yahoo Finance

**News feeds:**
- World: BBC World (`http://feeds.bbci.co.uk/news/world/rss.xml`), Reuters Top News (`https://feeds.reuters.com/reuters/topNews`)
- Local (Philadelphia / 19342 area): Philadelphia Inquirer (`https://www.inquirer.com/arcio/rss/`), 6ABC Action News (`https://6abc.com/feed/`)

**`config.js.j2` (Jinja2 template — deployed to `/srv/homelab/magicmirror/config/config.js`):**

```javascript
let config = {
    address: "0.0.0.0",
    port: 8080,
    basePath: "/",
    ipWhitelist: [],
    useHttps: false,
    language: "en",
    locale: "en-US",
    logLevel: ["INFO", "LOG", "WARN", "ERROR"],
    timeFormat: 12,
    units: "imperial",
    modules: [
        {
            module: "alert",
        },
        {
            module: "clock",
            position: "top_left",
            config: {
                dateFormat: "dddd, MMMM D"
            }
        },
        // Weather: Wayne PA (19342) — current
        {
            module: "weather",
            position: "top_right",
            header: "Wayne, PA",
            config: {
                weatherProvider: "openweathermap",
                type: "current",
                lat: 39.8962,
                lon: -75.5288,
                apiKey: "{{ openweathermap_api_key }}"
            }
        },
        // Weather: Wayne PA (19342) — 5-day forecast
        {
            module: "weather",
            position: "top_right",
            header: "Wayne, PA — Forecast",
            config: {
                weatherProvider: "openweathermap",
                type: "forecast",
                lat: 39.8962,
                lon: -75.5288,
                apiKey: "{{ openweathermap_api_key }}"
            }
        },
        // Weather: Letterkenny, Donegal — current
        {
            module: "weather",
            position: "top_left",
            header: "Letterkenny, Ireland",
            config: {
                weatherProvider: "openweathermap",
                type: "current",
                units: "metric",
                lat: 54.9558,
                lon: -7.7342,
                apiKey: "{{ openweathermap_api_key }}"
            }
        },
        // Weather: Letterkenny, Donegal — 3-day forecast
        {
            module: "weather",
            position: "top_left",
            header: "Letterkenny — Forecast",
            config: {
                weatherProvider: "openweathermap",
                type: "forecast",
                units: "metric",
                maxNumberOfDays: 3,
                lat: 54.9558,
                lon: -7.7342,
                apiKey: "{{ openweathermap_api_key }}"
            }
        },
        // Stocks: LMT, CMCSA, AAPL, NVDA (Yahoo Finance — no API key)
        {
            module: "MMM-Stocks",
            position: "bottom_bar",
            config: {
                stocks: "LMT,CMCSA,AAPL,NVDA",
                updateInterval: 300000,
                showChange: true,
                showChangePercent: true
            }
        },
        // World News
        {
            module: "newsfeed",
            position: "bottom_left",
            header: "World News",
            config: {
                feeds: [
                    { title: "BBC World", url: "http://feeds.bbci.co.uk/news/world/rss.xml" },
                    { title: "Reuters",   url: "https://feeds.reuters.com/reuters/topNews" }
                ],
                showSourceTitle: true,
                showPublishDate: true,
                reloadInterval: 300000
            }
        },
        // Local News (Philadelphia area — 19342)
        {
            module: "newsfeed",
            position: "bottom_right",
            header: "Local News",
            config: {
                feeds: [
                    { title: "Philly Inquirer", url: "https://www.inquirer.com/arcio/rss/" },
                    { title: "6ABC Philly",     url: "https://6abc.com/feed/" }
                ],
                showSourceTitle: true,
                showPublishDate: true,
                reloadInterval: 300000
            }
        }
    ]
};

if (typeof module !== "undefined") { module.exports = config; }
```

## Ansible Role Structure

```
ansible/roles/magicmirror/
├── tasks/
│   └── main.yml          # Docker service + kiosk + display scheduling
├── templates/
│   └── config.js.j2      # MagicMirror² config with Jinja2 for API key
├── files/
│   ├── magicmirror-kiosk.desktop     # XDG autostart — Chromium kiosk
│   ├── magicmirror-wake.service      # systemd user unit — xset dpms force on
│   ├── magicmirror-wake.timer        # fires at 07:00 daily
│   ├── magicmirror-sleep.service     # systemd user unit — xset dpms force off
│   └── magicmirror-sleep.timer       # fires at 09:00 daily
└── handlers/
    └── main.yml          # Reload systemd user daemon, restart container
```

**`tasks/main.yml` key sections:**

```yaml
# 1. Read secrets
- name: Read magicmirror secrets
  include_vars:
    file: /etc/homelab/secrets/magicmirror.env
    name: magicmirror_secrets
  become: yes

# 2. Ensure data directories
- name: Ensure MagicMirror directories exist
  file:
    path: "{{ item }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  become: yes
  loop:
    - /srv/homelab/magicmirror/config
    - /srv/homelab/magicmirror/modules

# 3. Deploy config from template
- name: Deploy MagicMirror config.js
  template:
    src: config.js.j2
    dest: /srv/homelab/magicmirror/config/config.js
    owner: root
    group: root
    mode: '0644'
  become: yes
  vars:
    openweathermap_api_key: "{{ magicmirror_secrets.OPENWEATHERMAP_API_KEY }}"
  notify: Restart MagicMirror

# 4. Install custom modules (MMM-Stocks)
- name: Install MMM-Stocks module
  community.docker.docker_container_exec:
    container: geek-magicmirror
    command: >
      npm install --prefix /home/node/MagicMirror/modules/MMM-Stocks
      https://github.com/jalibu/MMM-Stocks/tarball/master
  become: yes
  ignore_errors: yes  # container may not be running on first apply

# 5. Deploy Docker stack
- name: Ensure MagicMirror container is running
  community.docker.docker_compose_v2:
    project_src: /home/johnb/homelab-admin/platform/magicmirror
    state: present
    pull: policy
  become: yes

# 6. Configure X11 session (disable Wayland in GDM3)
- name: Disable Wayland in GDM3 (required for xset dpms)
  lineinfile:
    path: /etc/gdm3/custom.conf
    regexp: '^#?WaylandEnable='
    line: 'WaylandEnable=false'
    insertafter: '\[daemon\]'
  become: yes

# 7. Deploy kiosk autostart
- name: Deploy kiosk autostart desktop file
  copy:
    src: magicmirror-kiosk.desktop
    dest: /home/johnb/.config/autostart/magicmirror-kiosk.desktop
    owner: johnb
    group: johnb
    mode: '0644'
  become: yes

# 8. Deploy systemd user timers
- name: Deploy display wake/sleep systemd units
  copy:
    src: "{{ item }}"
    dest: /home/johnb/.config/systemd/user/{{ item }}
    owner: johnb
    group: johnb
    mode: '0644'
  become: yes
  loop:
    - magicmirror-wake.service
    - magicmirror-wake.timer
    - magicmirror-sleep.service
    - magicmirror-sleep.timer
  notify: Reload user systemd

# 9. Enable and start timers
- name: Enable display scheduling timers
  systemd:
    name: "{{ item }}"
    enabled: yes
    state: started
    scope: user
  become: yes
  become_user: johnb
  loop:
    - magicmirror-wake.timer
    - magicmirror-sleep.timer
```

**`magicmirror-kiosk.desktop`:**
```ini
[Desktop Entry]
Type=Application
Name=MagicMirror Kiosk
Exec=chromium-browser --kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble --no-first-run http://magicmirror.geek
X-GNOME-Autostart-enabled=true
Hidden=false
```

**`magicmirror-wake.service`:**
```ini
[Unit]
Description=Wake display for MagicMirror

[Service]
Type=oneshot
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/johnb/.Xauthority
ExecStart=/usr/bin/xset dpms force on
ExecStartPost=/usr/bin/xrandr --auto
```

**`magicmirror-wake.timer`:**
```ini
[Unit]
Description=Wake display at 7am for MagicMirror

[Timer]
OnCalendar=*-*-* 07:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

**`magicmirror-sleep.service`:**
```ini
[Unit]
Description=Sleep display after MagicMirror window

[Service]
Type=oneshot
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/johnb/.Xauthority
ExecStart=/usr/bin/xset dpms force off
```

**`magicmirror-sleep.timer`:**
```ini
[Unit]
Description=Sleep display at 9am after MagicMirror window

[Timer]
OnCalendar=*-*-* 09:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

**nginx vhost (`35_magicmirror.geek.conf`):**
```nginx
server {
    listen 80;
    server_name magicmirror.geek;

    location / {
        proxy_pass http://geek-magicmirror:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support — MagicMirror uses Socket.IO for real-time module updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
```

**`make magicmirror-test` target:**
```makefile
magicmirror-test: ## Force-wake display and open MagicMirror kiosk immediately (no schedule wait)
	@echo "== Waking display and launching MagicMirror kiosk on geek =="
	ssh -o IdentityFile=~/.ssh/id_ed25519 johnb@geek \
		"DISPLAY=:0 XAUTHORITY=/home/johnb/.Xauthority xset dpms force on; \
		 DISPLAY=:0 XAUTHORITY=/home/johnb/.Xauthority \
		   chromium-browser --kiosk --noerrdialogs --disable-infobars http://magicmirror.geek &"
	@open http://magicmirror.geek || true
```

## Secrets Required

| Secret file | Variable | Description |
|-------------|----------|-------------|
| `/etc/homelab/secrets/magicmirror.env` | `OPENWEATHERMAP_API_KEY` | Free-tier OWM key; register at openweathermap.org → API keys |

## Goals / Non-Goals

**Goals:**
- Deploy MagicMirror² as a Docker service reachable at `http://magicmirror.geek`
- Display weather, stocks, and news as specified
- Auto-wake at 07:00, auto-sleep at 09:00 via systemd timers
- Chromium kiosk starts automatically when `johnb` session starts
- `make magicmirror-test` forces immediate display + kiosk for testing
- Ansible role is idempotent and tagged `magicmirror`

**Non-Goals:**
- Public (`.johnnyblabs.com`) domain — internal LAN access only
- Authentik SSO protection — dashboard is read-only and LAN-only
- Mobile/responsive layout — single fixed display output
- MagicMirror module updates (handled by separate version change)

## Risks / Trade-offs

**[Risk] Wayland session breaks `xset dpms`** → Mitigation: Ansible disables Wayland in `/etc/gdm3/custom.conf`. One-time session change; affects `johnb` login session only. If GDM3 is not the display manager, task must be adjusted.

**[Risk] OWM free tier rate limits** → Mitigation: Built-in `weather` module polls per-location; free tier allows 60 calls/min, 1M/month. 2 locations × polling every ~10 min = well within limits.

**[Risk] `MMM-Stocks` / Yahoo Finance rate limits** → Mitigation: 5-minute poll interval avoids aggressive fetching. If Yahoo Finance blocks, fall back to Alpha Vantage module with API key.

**[Risk] `chromium-browser` not installed on geek** → Mitigation: Ansible role checks and installs `chromium-browser` package if absent.

**[Risk] `johnb` session not active when timers fire** → Mitigation: `Persistent=true` on timers ensures they fire on next login if missed; kiosk autostart handles the browser.

## Open Questions

1. Does the geek microPC have GDM3 as the display manager, or a different one (lightdm, etc.)? The Wayland-disable step targets `/etc/gdm3/custom.conf` — adjust if different.
2. Is `johnb` configured for autologin, or does geek require a manual login each boot? (Autologin config is separate from this change but needed for fully unattended kiosk.)
3. Which display output is the dashboard monitor on? `xrandr --auto` in the wake service handles most cases but may need a specific `--output` flag if geek has multiple displays.
