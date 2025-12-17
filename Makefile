BACKUP_DIR := _backup/etc-nginx-docker
LIVE_DIR := /etc/nginx-docker

.PHONY: nginx-test nginx-reload backup-nginx diff-nginx deploy-authentik

nginx-test:
	docker exec geek-nginx nginx -t

nginx-reload:
	docker exec geek-nginx nginx -t
	docker exec geek-nginx nginx -s reload

backup-nginx:
	@echo "== Sync live nginx config -> $(BACKUP_DIR) (excluding cert private keys) =="
	sudo rsync -av --delete \
	  --exclude 'certs/*.key' \
	  --exclude 'certs/*.pem' \
	  --exclude 'certs/*priv*' \
	  $(LIVE_DIR)/ $(BACKUP_DIR)/

diff-nginx:
	sudo diff -ruN $(BACKUP_DIR) $(LIVE_DIR) || true

deploy-authentik:
	@echo "== Deploying Authentik upgrades to geek =="
	@echo "⚠️  This will pull new images and restart authentik services"
	@echo "⚠️  Upgrading to version 2025.10.3 (Redis no longer required)"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd platform/authentik && \
		docker-compose pull && \
		docker-compose up -d && \
		echo "✅ Authentik deployed. Checking status..." && \
		docker-compose ps && \
		echo "" && \
		echo "📋 View logs with: cd platform/authentik && docker-compose logs -f" && \
		echo "🔍 Verify at: https://auth.geek or https://auth.johnnyblabs.com"; \
	else \
		echo "❌ Deployment cancelled"; \
	fi
