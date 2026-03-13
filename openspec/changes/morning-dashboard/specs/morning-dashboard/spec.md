## ADDED Requirements

### Requirement: Morning dashboard SHALL be deployed as a Docker service on geek-infra

The MagicMirror² application SHALL run as a Docker container named `geek-magicmirror` connected to the external `geek-infra` Docker network. The container SHALL be managed by the `magicmirror` Ansible role, follow the `unless-stopped` restart policy, and store persistent data under `/srv/homelab/magicmirror/`.

#### Scenario: Container deployment

- **WHEN** `make ansible-apply ARGS="--tags magicmirror"` is run
- **THEN** container `geek-magicmirror` SHALL be in `running` state
- **THEN** the container SHALL be reachable at `http://magicmirror.geek` via the nginx reverse proxy

### Requirement: Dashboard configuration SHALL be managed via Ansible template

The MagicMirror² `config.js` SHALL be generated from a Jinja2 template (`config.js.j2`) by the Ansible `magicmirror` role. The rendered file SHALL be deployed to `/srv/homelab/magicmirror/config/config.js` on the geek host. API keys SHALL be sourced from `/etc/homelab/secrets/magicmirror.env` and SHALL NOT appear in any git-tracked file.

#### Scenario: Config deployment with secret injection

- **WHEN** the `magicmirror` Ansible role is applied
- **THEN** `/srv/homelab/magicmirror/config/config.js` SHALL exist and contain a valid MagicMirror² configuration
- **THEN** the `OPENWEATHERMAP_API_KEY` SHALL be present in the rendered config but SHALL NOT be present in any file tracked by git

### Requirement: Dashboard SHALL display weather for Wayne PA and Letterkenny Ireland

The MagicMirror² configuration SHALL include weather modules showing current conditions and multi-day forecasts for two locations: Wayne PA (zip 19342, lat 39.8962 / lon -75.5288) and Letterkenny, County Donegal, Ireland (lat 54.9558 / lon -7.7342). Wayne PA SHALL use imperial units; Letterkenny SHALL use metric units.

#### Scenario: Weather data visible

- **WHEN** the MagicMirror² UI is loaded in a browser
- **THEN** current temperature and conditions for Wayne, PA SHALL be visible
- **THEN** a multi-day forecast for Wayne, PA SHALL be visible
- **THEN** current temperature and conditions for Letterkenny, Ireland SHALL be visible
- **THEN** a multi-day forecast for Letterkenny, Ireland SHALL be visible

### Requirement: Dashboard SHALL display live stock prices for specified tickers

The MagicMirror² configuration SHALL include a stocks module displaying live prices and change indicators for: LMT (Lockheed Martin), CMCSA (Comcast), AAPL (Apple), NVDA (NVIDIA). The stocks module SHALL use Yahoo Finance as the data source and SHALL NOT require an API key secret. Prices SHALL refresh no more frequently than every 5 minutes.

#### Scenario: Stocks visible and refreshing

- **WHEN** the MagicMirror² UI is loaded
- **THEN** tickers LMT, CMCSA, AAPL, and NVDA SHALL be visible with price and change indicator
- **THEN** prices SHALL be no older than 10 minutes from last successful fetch

### Requirement: Dashboard SHALL display world and local news headlines

The MagicMirror² configuration SHALL include two `newsfeed` module instances: one for world news (BBC World, Reuters) and one for local Philadelphia-area news (Philadelphia Inquirer, 6ABC). Both SHALL use RSS feeds and SHALL NOT require API keys.

#### Scenario: News feeds rotating

- **WHEN** the MagicMirror² UI is observed for 60 seconds
- **THEN** world news headlines SHALL rotate from at least one of the configured world feeds
- **THEN** local news headlines SHALL rotate from at least one of the configured local feeds

### Requirement: Chromium kiosk SHALL start automatically with the johnb user session

The geek host SHALL be configured with an XDG autostart entry (`~/.config/autostart/magicmirror-kiosk.desktop`) that launches `chromium-browser --kiosk http://magicmirror.geek` when the `johnb` user session starts. The browser SHALL suppress error dialogs, info bars, and session crash prompts.

#### Scenario: Kiosk launches on session start

- **WHEN** the `johnb` desktop session starts on geek
- **THEN** Chromium SHALL open in full-screen kiosk mode at `http://magicmirror.geek` within 30 seconds
- **THEN** no browser chrome, address bar, or error dialogs SHALL be visible

### Requirement: Display SHALL wake at 07:00 and sleep at 09:00 via systemd timers

The `johnb` user systemd session SHALL have two timer units enabled: `magicmirror-wake.timer` (fires at 07:00, runs `xset dpms force on`) and `magicmirror-sleep.timer` (fires at 09:00, runs `xset dpms force off`). Both timers SHALL have `Persistent=true` to fire on the next login if the scheduled time was missed. An X11 display session SHALL be required; GDM3 SHALL be configured with `WaylandEnable=false`.

#### Scenario: Scheduled wake

- **WHEN** the system clock reaches 07:00
- **THEN** `magicmirror-wake.timer` SHALL fire
- **THEN** the connected display SHALL power on

#### Scenario: Scheduled sleep

- **WHEN** the system clock reaches 09:00
- **THEN** `magicmirror-sleep.timer` SHALL fire
- **THEN** the connected display SHALL power off

### Requirement: An immediate test hook SHALL be available via make target

A `make magicmirror-test` target SHALL exist in the repository Makefile that: (1) SSHes to geek, (2) force-wakes the display via `xset dpms force on`, and (3) launches Chromium in kiosk mode at `http://magicmirror.geek` — all without waiting for the 07:00 schedule. This target enables immediate end-to-end verification after deployment.

#### Scenario: Test hook execution

- **WHEN** `make magicmirror-test` is run from the Mac
- **THEN** the display on geek SHALL power on within 2 seconds
- **THEN** Chromium SHALL open in kiosk mode at `http://magicmirror.geek` within 5 seconds
- **THEN** the MagicMirror² UI SHALL be visible on the geek display
