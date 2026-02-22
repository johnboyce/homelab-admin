.PHONY: preflight nginx-test nginx-reload nginx-import nginx-deploy deploy-authentik deploy-bookstack bookstack-oidc-bootstrap authentik-config-dump authentik-inspect homelab-status homelab-status-verbose homelab-logs homelab-health homelab-backup homelab-backup-list homelab-backup-restore setup-firewall ansible-install ansible-status ansible-dry-run ansible-apply ansible-firewall ansible-nginx

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

deploy-bookstack:
	@echo "== Deploying BookStack to geek host =="
	@ssh johnb@geek 'cd ~/homelab-admin/platform/bookstack && docker compose pull && docker compose up -d'
	@echo "== Reloading nginx to flush upstream DNS cache =="
	@ssh johnb@geek 'docker exec geek-nginx nginx -s reload'
	@echo "== BookStack deployed =="

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

homelab-backup:
	@bash scripts/backup_postgresql.sh backup

homelab-backup-list:
	@bash scripts/backup_postgresql.sh list

homelab-backup-restore:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ Please specify backup file with FILE="; \
		echo ""; \
		echo "Example: make homelab-backup-restore FILE=backups/authentik_backup_20260221_130000.sql"; \
		echo ""; \
		echo "Available backups:"; \
		bash scripts/backup_postgresql.sh list; \
	else \
		bash scripts/backup_postgresql.sh restore $(FILE); \
	fi

setup-firewall:
	@echo "== Setting up UFW firewall rules on geek host =="
	@echo ""
	@echo "⚠️  This script must run ON the geek host, not from macbook."
	@echo ""
	@echo "Run this instead:"
	@echo "  ssh johnb@geek 'bash ~/homelab-admin/scripts/setup_firewall.sh'"
	@echo ""
	@echo "Or if the repo is cloned on geek:"
	@echo "  ssh johnb@geek 'sudo bash ~/path/to/homelab-admin/scripts/setup_firewall.sh'"

ansible-install:
	@echo "== Installing Ansible collections =="
	cd ansible && ansible-galaxy collection install -r requirements.yml

ansible-status:
	@echo "== Homelab Status (read-only, no changes) =="
	@echo ""
	cd ansible && ansible-playbook playbooks/status.yml

ansible-dry-run:
	@echo "== Ansible Dry-Run (--check --diff) =="
	@echo "This shows what WOULD be changed without making any changes."
	@echo ""
	@echo "Tip: Pass ARGS to filter by tags, e.g.:"
	@echo "  make ansible-dry-run ARGS='--tags firewall'"
	@echo ""
	cd ansible && ansible-playbook playbooks/site.yml --check --diff $(ARGS)

ansible-apply:
	@echo "== Applying Ansible Infrastructure Changes =="
	@echo ""
	@echo "Tip: Pass ARGS to filter by tags, e.g.:"
	@echo "  make ansible-apply ARGS='--tags postgres,authentik'"
	@echo ""
	cd ansible && ansible-playbook playbooks/site.yml $(ARGS)

ansible-firewall:
	@echo "== Managing firewall rules with Ansible =="
	@echo ""
	@echo "Tip: Add ARGS for dry-run: make ansible-firewall ARGS='--check --diff'"
	@echo ""
	cd ansible && ansible-playbook playbooks/firewall.yml $(ARGS)

ansible-nginx:
	@echo "== Syncing nginx configuration with Ansible =="
	@echo ""
	@echo "Tip: Add ARGS for dry-run: make ansible-nginx ARGS='--check --diff'"
	@echo ""
	cd ansible && ansible-playbook playbooks/nginx.yml $(ARGS)
