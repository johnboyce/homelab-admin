## Purpose

Defines the security posture for the homelab: secrets management, TLS handling, firewall policy, and Authentik SSO protection requirements.

## Requirements

### Requirement: Secrets SHALL never be committed to git
No passwords, tokens, API keys, private keys, or real certificate private keys SHALL appear in the git repository at any time. The repository SHALL contain only `.env.example` files with placeholder values.

#### Scenario: Secret accidentally staged
- **WHEN** a file containing a real secret is staged for commit
- **THEN** the `.gitignore` SHALL prevent it from being committed
- **THEN** the developer SHALL be warned before the commit proceeds

#### Scenario: env.example contains only placeholders
- **WHEN** a `.env.example` file is reviewed
- **THEN** all secret values SHALL be placeholder strings (e.g., `your-secret-here`, `changeme`)

### Requirement: Secrets SHALL be stored at /etc/homelab/secrets/ on the host
All runtime secrets SHALL reside in `/etc/homelab/secrets/<service>.env` on the `geek` host. This directory SHALL be owned by root with mode `700`.

#### Scenario: Secrets directory permissions
- **WHEN** `/etc/homelab/secrets/` is inspected on geek
- **THEN** the directory SHALL have permissions `drwx------ root root`
- **THEN** individual `.env` files SHALL be readable only by root (mode `600` or `644`)

### Requirement: TLS private keys SHALL never be committed to git
SSL/TLS private key files (`.key`, `.pem` containing private keys) SHALL reside only on the host at `/etc/nginx-docker/certs/`. The repository SHALL contain only a `.keep` placeholder in the certs directory.

#### Scenario: Certs directory in repo
- **WHEN** `platform/ingress/nginx/etc-nginx-docker/certs/` is reviewed in git
- **THEN** the directory SHALL contain only `.keep` files
- **THEN** no `.key` or `.pem` files SHALL be present

### Requirement: UFW SHALL default-deny all incoming traffic
The host firewall SHALL use a default-deny-incoming policy with explicit allow rules for each required port. Docker-managed iptables rules supplement UFW for container traffic.

#### Scenario: Default firewall policy
- **WHEN** `sudo ufw status` is run on geek
- **THEN** the default incoming policy SHALL be `deny`
- **THEN** the default outgoing policy SHALL be `allow`

### Requirement: All firewall port rules SHALL reference the Ansible port registry
UFW rules managed by Ansible SHALL reference port variables from `ansible/inventory/group_vars/all.yml`. No hardcoded port numbers SHALL appear in Ansible firewall tasks.

#### Scenario: Firewall rule references registry variable
- **WHEN** an Ansible firewall task is reviewed
- **THEN** the port value SHALL be a variable reference (e.g., `{{ services.nginx.http_port }}`)
- **THEN** the variable SHALL be defined in `ansible/inventory/group_vars/all.yml`

### Requirement: Services SHALL authenticate via Authentik SSO where appropriate
Web-facing services that support OIDC or forward authentication SHALL be protected by Authentik. Direct authentication bypass routes (e.g., OIDC callbacks) SHALL be explicitly whitelisted.

#### Scenario: Protected service nginx config
- **WHEN** an nginx vhost for a protected service is reviewed
- **THEN** it SHALL include `auth_request /_ak/auth;`
- **THEN** it SHALL include `error_page 401 = @ak_start;`
- **THEN** OIDC callback paths SHALL have `auth_request off;`
