# ADMIN.md – Homelab Admin Repo

This repo is the source-of-truth for my homelab platform on host `geek`.

## Non-negotiables
- NEVER commit secrets, tokens, private keys, or real passwords.
- Use `.env.example` files and placeholders only.
- Treat `/etc/nginx-docker` as live state; this repo contains a mirror.

## Repo structure
- `platform/ingress/nginx/` – nginx reverse proxy, TLS, vhosts (mirrors /etc/nginx-docker)
- `platform/identity/authentik/` – authentik server/worker/outpost + templates/media
- `platform/data-services/` – shared postgres/redis compose
- `docs/` – runbooks, troubleshooting, inventory

## Workflow expectations
- Changes must be incremental and reversible.
- Any change to DNS/TLS/ingress must update docs.
- Provide verification commands with every change:
  - `docker exec geek-nginx nginx -t`
  - `curl -Ik https://auth.johnnyblabs.com`
  - `curl -Ik https://bookstack.johnnyblabs.com`

## Syncing live config
- Live nginx config lives at `/etc/nginx-docker`
- This repo mirrors it under `platform/ingress/nginx/etc-nginx-docker`
- Cert private keys do NOT belong in git. Use placeholders.

## If uncertain
Ask one focused question; do not guess.
