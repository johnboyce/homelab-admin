BACKUP_DIR := _backup/etc-nginx-docker
LIVE_DIR := /etc/nginx-docker

.PHONY: nginx-test nginx-reload backup-nginx diff-nginx

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
