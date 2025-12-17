.PHONY: nginx-test nginx-reload nginx-import nginx-deploy deploy-authentik bookstack-oidc-bootstrap authentic-config-dump

nginx-test:
	docker exec geek-nginx nginx -t

nginx-reload:
	docker exec geek-nginx nginx -t
	docker exec geek-nginx nginx -s reload

nginx-import:
	@echo "== Importing nginx config from host (emergency/bootstrap only) =="
	@bash scripts/nginx_import_from_host.sh

nginx-deploy:
	@echo "== Deploying nginx config to host (normal workflow) =="
	@bash scripts/nginx_deploy_to_host.sh

deploy-authentik:
	@echo "== Deploying Authentik upgrades to geek =="
	@echo "⚠️  This will pull new images and restart authentik services"
	@echo "⚠️  Upgrading to version 2025.10.3 (Redis no longer required)"
	@bash -c 'read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd platform/authentik && \
		docker compose pull && \
		docker compose up -d && \
		echo "✅ Authentik deployed. Checking status..." && \
		docker compose ps && \
		echo "" && \
		echo "📋 View logs with: cd platform/authentik && docker compose logs -f" && \
		echo "🔍 Verify at: https://auth.geek or https://auth.johnnyblabs.com"; \
	else \
		echo "❌ Deployment cancelled"; \
	fi'

authentic-config-dump:
	@echo "== Show Authentik configs from Authetic API  =="
	@set -a; [ -f .env.local ] && . ./.env.local; set +a; \
	@./scripts/authentik_inspect.sh

bookstack-oidc-bootstrap:
	@echo "== Deploying Bookstack config if required =="
	@set -a; [ -f .env.local ] && . ./.env.local; set +a; \
	@./scripts/bookstack_oidc_bootstrap.sh
