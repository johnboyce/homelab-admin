# Firewall Configuration (UFW)

This document describes the firewall configuration for the geek host using UFW (Uncomplicated Firewall).

## Overview

UFW provides a simple interface to manage iptables rules on Ubuntu. The geek host uses UFW to:
- Allow SSH and web services from anywhere (with rate limiting)
- Restrict admin services (Cockpit, VNC) to LAN only
- Allow specific services only from trusted networks
- Block dangerous ports (RDP brute-force mitigation)

## Current Rules

### Remote Access (WAN)
- **SSH (22/tcp)** — ALLOW from anywhere (standard access)
- **HTTP (80/tcp)** — ALLOW via Nginx Full (web services)
- **HTTPS (443/tcp)** — ALLOW via Nginx Full (TLS termination)

### Local Network Only (LAN: 192.168.1.0/24)
- **Port 8081/tcp** — Ollama API (LAN only)
- **Port 53/tcp + 53/udp** — Pi-hole DNS (LAN only)
- **Port 9090/tcp** — Cockpit (system admin UI, LAN only)
- **Port 5901/tcp** — VNC (remote desktop, LAN only)
- **Port 8888/tcp** — CasaOS (host dashboard, LAN only)

### Other Services
- **Port 7777** — ALLOW (custom service, accessible from anywhere)
- **Port 11434** — ALLOW (Ollama inference, accessible from anywhere)

### Blocked Ports
- **Port 3389/tcp** — RDP protocol (denied for security)
- **Port 5901/tcp** — VNC from WAN (denied, allow LAN only)

## Management

### View Current Rules
```bash
sudo ufw status numbered
```

### Add a New Rule (LAN-only service)
```bash
# Allow port 8888 from LAN subnet
sudo ufw allow from 192.168.1.0/24 to any port 8888 proto tcp comment "Service name"

# Allow port 8888 from broader private ranges (backup)
sudo ufw allow from 192.168.0.0/16 to any port 8888 proto tcp comment "Service name"
```

### Add a New Rule (Public service)
```bash
sudo ufw allow 9999/tcp comment "Public service"
```

### Delete a Rule
```bash
sudo ufw status numbered  # Find rule number
sudo ufw delete 42        # Delete rule #42
```

### Enable/Disable Firewall
```bash
sudo ufw enable   # Enable firewall
sudo ufw disable  # Disable firewall (not recommended)
```

## Automation

See `scripts/setup_firewall.sh` for automated UFW configuration.

## Security Principles

1. **Principle of Least Privilege**: Allow only what's needed
2. **Default Deny**: Reject by default, allow explicitly
3. **LAN vs WAN**: Admin services restricted to 192.168.1.0/24
4. **Comment Rules**: Every rule has a comment explaining its purpose
5. **Numbered Rules**: Use numbered output for easier management

## Testing

After adding rules, verify they're working:

```bash
# From macbook (WAN)
curl -I https://auth.johnnyblabs.com    # Should work (nginx)
curl -I http://192.168.1.187:9090       # Should timeout (blocked)

# From geek host (LAN)
curl -I http://192.168.1.187:8081       # Should work (Ollama LAN)
```

## References

- UFW documentation: https://wiki.ubuntu.com/UncomplicatedFirewall
- iptables basics: https://wiki.ubuntu.com/IptablesHowTo
- IPv4 private ranges (RFC 1918): 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
