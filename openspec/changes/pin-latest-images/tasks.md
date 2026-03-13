## 1. Pin Vaultwarden (High Priority)

- [ ] 1.1 Update `platform/vaultwarden/docker-compose.yml` image tag from `vaultwarden/server:latest` to `vaultwarden/server:1.35.4`
- [ ] 1.2 Deploy via `make ansible-apply ARGS="--tags vaultwarden"`
- [ ] 1.3 Verify vaultwarden is healthy: `docker inspect vaultwarden | jq '.[0].State.Health.Status'`

## 2. Pin Woodpecker (Server + Agent Together)

- [ ] 2.1 Update `platform/woodpecker/docker-compose.yml` server image from `woodpeckerci/woodpecker-server:latest` to `woodpeckerci/woodpecker-server:2.8.3`
- [ ] 2.2 Update `platform/woodpecker/docker-compose.yml` agent image from `woodpeckerci/woodpecker-agent:latest` to `woodpeckerci/woodpecker-agent:2.8.3`
- [ ] 2.3 Deploy via `make ansible-apply ARGS="--tags woodpecker"`
- [ ] 2.4 Verify woodpecker UI is reachable: `curl -so /dev/null -w "%{http_code}" http://woodpecker.geek`

## 3. Upgrade + Pin Pi-hole (2025.11.1 → 2026.02.0)

- [ ] 3.1 Update `platform/pihole/docker-compose.yml` image tag from `pihole/pihole:latest` to `pihole/pihole:2026.02.0`
- [ ] 3.2 Deploy via `make ansible-apply ARGS="--tags pihole"`
- [ ] 3.3 Verify DNS is resolving: `ssh johnb@geek "dig @127.0.0.1 forgejo.geek +short"`
- [ ] 3.4 Verify Pi-hole admin UI is reachable: `curl -so /dev/null -w "%{http_code}" http://pihole.geek/admin`

## 4. Upgrade + Pin Ollama (0.16.3 → 0.17.7)

- [ ] 4.1 Update `platform/ollama/docker-compose.yml` image tag from `ollama/ollama:latest` to `ollama/ollama:0.17.7`
- [ ] 4.2 Deploy via `make ansible-apply ARGS="--tags ollama"`
- [ ] 4.3 Verify ollama is running: `curl -so /dev/null -w "%{http_code}" http://geek:11434`
- [ ] 4.4 Verify ollama API responds: `curl -s http://geek:11434/api/tags | jq '.models | length'`

## 5. Pin Cloudflare DDNS

- [ ] 5.1 Update `platform/cloudflare-ddns/docker-compose.yml` image tag from `favonia/cloudflare-ddns:latest` to `favonia/cloudflare-ddns:1.15.1`
- [ ] 5.2 Deploy via `make ansible-apply ARGS="--tags cloudflare-ddns"`
- [ ] 5.3 Verify container is running: `ssh johnb@geek "docker ps | grep cloudflare-ddns"`

## 6. Update Spec Documentation

- [ ] 6.1 Update `openspec/specs/service-inventory.md` — set version policy to `pinned` and record current version for all 5 services
- [ ] 6.2 Update `HOMELAB_SPEC.yml` version matrix for vaultwarden, woodpecker, pihole, ollama, cloudflare-ddns
