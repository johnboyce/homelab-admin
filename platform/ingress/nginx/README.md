# nginx Configuration

This directory contains the authoritative nginx configuration for the homelab's reverse proxy and TLS termination.

## Current Structure

**Active:** `etc-nginx-docker/conf.d/*.conf` (numbered configuration files)
- These files are deployed to the host and actively used
- Named with prefixes (00_, 05_, 10_, 11_, 20_, 21_, 31_, etc.) to control load order
- Each file is a self-contained virtual host or upstream definition

**Legacy (Reference):** `etc-nginx-docker/sites-available/` (standard nginx layout)
- Kept for historical reference and as patterns for future reconfigurations
- Not currently deployed to the host
- Useful for understanding previous configuration approaches

## Configuration Files

### Current (conf.d/)

| File | Purpose |
|------|---------|
| `00_geek.conf` | Upstream definitions for internal services |
| `05_geek.conf` | Additional global/shared configuration |
| `10_auth.johnnyblabs.com.conf` | Public HTTPS Authentik (identity provider) |
| `11_auth.geek.conf` | Internal HTTP Authentik (LAN only) |
| `20_bookstack.johnnyblabs.com.conf` | Public HTTPS BookStack with forward-auth |
| `21_bookstack.geek.conf` | Internal HTTP BookStack with forward-auth |
| `31_pihole.geek.conf` | Internal HTTP Pi-hole (DNS/adblocking) |

### Snippets (Reusable Components)

Located in `geek/snippets/` and `snippets/`:

| File | Purpose |
|------|---------|
| `authentik_forwardauth.conf` | Authentik forward-auth patterns |
| `proxy_common.conf` | Common proxy settings (headers, buffering) |
| `proxy_websocket.conf` | WebSocket-specific proxy configuration |
| `lan_only.conf` | LAN-only access restrictions |
| `websocket_map.conf` | WebSocket status code mappings |

## Deployment

### Current State

The host is running configurations from `conf.d/` that were synced from this repository.

**Last sync:** [Check git history for most recent import]

### To Update Configuration

1. **Edit config** in repo: `platform/ingress/nginx/etc-nginx-docker/conf.d/`
2. **Test syntax** locally: `make nginx-test`
3. **Deploy to host**: `make nginx-deploy`
4. **Reload nginx** (done automatically by deploy)
5. **Verify** with curl tests (see CLAUDE.md)

### To Import from Host (Emergency)

If you've made manual changes on the host that need to be captured:

```bash
ALLOW_IMPORT=true make nginx-import
```

⚠️ **Important:** Import is emergency-only. Normal workflow is repo → host.

## Standard nginx Files

| File | Auto-Generated | Purpose |
|------|---|----------|
| `nginx.conf` | Yes (nginx standard) | Main nginx config |
| `fastcgi.conf`, `fastcgi_params` | Yes | FastCGI protocol |
| `scgi_params`, `uwsgi_params` | Yes | SCGI/uWSGI protocols |
| `mime.types` | Yes | MIME type mappings |
| `html/index.html` | Yes | Fallback page |

These are typically part of the base nginx installation and should not be edited locally.

## TLS Certificates

- **Location on host:** `/etc/nginx-docker/certs/`
- **In repo:** Only `.keep` placeholder (certificates are not version-controlled)
- **Private keys:** Never committed to git

To check certificate expiry:

```bash
ssh johnb@geek "openssl x509 -in /etc/nginx-docker/certs/johnnyblabs.crt -noout -enddate"
```

## Architecture

All services are reverse-proxied through nginx:

```
Internet/LAN
    ↓
nginx (TLS termination, routing, auth)
    ↓
Authentik (SSO) → PostgreSQL
BookStack (Wiki) → PostgreSQL
Pi-hole (DNS)
... other services
```

Forward authentication flow (for protected services):

```
Client Request
    ↓
nginx checks auth via /_ak/auth
    ↓
authentik-outpost:9000/outpost.goauthentik.io/auth/nginx
    ↓
→ If authenticated: serve content
→ If not: redirect to https://auth.johnnyblabs.com/outpost.goauthentik.io/start
```

## Quick Debugging

```bash
# Test syntax without reload
make nginx-test

# View logs
docker logs -f geek-nginx

# Test specific service from nginx
docker exec -it geek-nginx curl -I http://authentik-server:9000

# Test outpost connectivity
docker exec -it geek-nginx curl -I http://authentik-outpost:9000/outpost.goauthentik.io/ping
```

## References

- nginx documentation: https://nginx.org/en/docs/
- Authentik forward-auth: https://goauthentik.io/docs/providers/proxy/
- This configuration follows forward-auth pattern from `bookstack.geek.conf`
