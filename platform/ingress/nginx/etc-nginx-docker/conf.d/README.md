# Nginx Virtual Host Configuration

This directory contains all active nginx virtual host configurations.

## Naming Convention

Files are named with numeric prefixes to control load order:
- `00_*.conf` - Default/base configurations
- `10_*.conf` - Application-specific configurations
- `20_*.conf` - Additional services (if needed)

## Adding New Configurations

1. Create a new `.conf` file in this directory with appropriate numeric prefix
2. Test with: `docker exec geek-nginx nginx -t`
3. Deploy with: `make deploy-edge`
4. Reload with: `docker exec geek-nginx nginx -s reload`

## Migration Note

This homelab previously used both `conf.d/` and `sites-available/sites-enabled` patterns.
It has been standardized to use only `conf.d/` for simplicity and Docker best practices.

The sites-available/sites-enabled directories were not actually functional:
- nginx.conf only included `conf.d/*.conf`
- docker-compose.yml only mounted `conf.d/`
- The symlinks in sites-enabled were never loaded
