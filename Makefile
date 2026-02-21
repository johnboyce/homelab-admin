.PHONY: preflight nginx-test nginx-reload nginx-import nginx-deploy deploy-authentik bookstack-oidc-bootstrap authentik-config-dump authentik-inspect homelab-status homelab-status-verbose homelab-logs homelab-health

preflight:
	@bad=$$(find platform -not -user $$(id -un) -print -quit 2>/dev/null || true); \
	if [ -n "$$bad" ]; then \
	  echo "❌ Repo contains non-owned file under platform/: $$bad"; \
	  echo "   Fix with: sudo chown -R $$(id -un):$$(id -gn) platform"; \
	  exit 1; \
	fi

nginx-test: preflight
	docker exec geek-nginx nginx -t

nginx-reload: preflight
	docker exec geek-nginx nginx -t
	docker exec geek-nginx nginx -s reload

nginx-import:
	@echo "== Importing nginx config from host (emergency/bootstrap only) =="
	@bash scripts/nginx_import_from_host.sh

nginx-deploy: preflight
	@echo "== Deploying nginx config to host (normal workflow) =="
	@bash scripts/nginx_deploy_to_host.sh

authentik-inspect:
	@set -a; [ -f .env.local ] && . ./.env.local; set +a; \
	./scripts/authentik_inspect.sh

authentik-config-dump:
	@echo "== Dumping Authentik config snapshots (sanitized) =="
	@set -a; [ -f .env.local ] && . ./.env.local; set +a; \
	./scripts/authentik_dump.sh

bookstack-oidc-bootstrap:
	@echo "== Bootstrapping Authentik BookStack OIDC (if required) =="
	@set -a; [ -f .env.local ] && . ./.env.local; set +a; \
	./scripts/bookstack_oidc_bootstrap.sh

homelab-status:
	@bash scripts/homelab_status.sh

homelab-status-verbose:
	@bash scripts/homelab_status.sh verbose

homelab-logs:
	@echo "== Recent Service Logs (last 20 lines per service) =="
	@echo ""
	@if docker ps &>/dev/null; then \
		echo "nginx:"; \
		docker logs --tail=20 geek-nginx 2>/dev/null || echo "(nginx not running)"; \
		echo ""; \
		echo "postgres:"; \
		docker logs --tail=20 geek-postgres 2>/dev/null || echo "(postgres not running)"; \
		echo ""; \
		echo "authentik-server:"; \
		docker logs --tail=20 authentik-server 2>/dev/null || echo "(authentik-server not running)"; \
	else \
		echo "Docker not available locally. To see remote logs:"; \
		echo "  ssh johnb@geek 'docker logs --tail=20 geek-nginx'"; \
	fi

homelab-health:
	@echo "== Running Full Health Checks =="
	@echo ""
	@bash scripts/homelab_status.sh verbose
	@echo ""
	@if docker ps &>/dev/null; then \
		echo "== Docker System Info =="; \
		docker system df 2>/dev/null || echo "(docker info not available)"; \
	fi
