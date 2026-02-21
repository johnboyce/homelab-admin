#!/usr/bin/env bash
# setup_firewall.sh — Configure UFW firewall rules for geek host
#
# IMPORTANT: This script must run ON the geek host (not from macbook)
#
# Usage (from geek host):
#   bash setup_firewall.sh
#   or
#   make setup-firewall  (if Make target exists)
#
# This script configures UFW with:
# - SSH and web services (public)
# - Admin services (LAN only)
# - Specific ports for internal services
# - Security rules (block dangerous ports)

set -u
say() { printf "%s\n" "$*"; }
die() { say "❌ $*"; exit 1; }
check() { say "✓ $1"; }

HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")

say "╔════════════════════════════════════════════════════════════════╗"
say "║             UFW Firewall Configuration for geek               ║"
say "╚════════════════════════════════════════════════════════════════╝"
say ""

# Safety check: only run on geek host
if [[ "$HOSTNAME" != "geek" ]]; then
  die "This script must run ON the geek host, not from a remote machine. Current host: $HOSTNAME"
fi

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
  die "This script must be run with sudo"
fi

say "Host: $HOSTNAME"
say "User: $(whoami)"
say ""

# Check if UFW is installed
if ! command -v ufw &> /dev/null; then
  say "UFW not found. Installing..."
  apt-get update && apt-get install -y ufw || die "Failed to install UFW"
  check "UFW installed"
fi

# Enable UFW if not already enabled
if ufw status | grep -q "inactive"; then
  say ""
  say "⚠️  UFW is currently INACTIVE. Enabling now..."
  read -p "Enable UFW? [y/N] " -n 1 -r
  echo
  if [[ ! "${REPLY:-}" =~ ^[Yy]$ ]]; then
    die "Cancelled. UFW remains inactive."
  fi
  ufw --force enable || die "Failed to enable UFW"
  check "UFW enabled"
fi

say ""
say "═══════════════════════════════════════════════════════════════"
say "Applying firewall rules..."
say "═══════════════════════════════════════════════════════════════"
say ""

# Remote access (WAN) — allow
say "Remote Access (WAN):"
ufw allow 22/tcp comment "SSH" > /dev/null 2>&1 && check "SSH (22/tcp)"
ufw allow "Nginx Full" > /dev/null 2>&1 && check "Nginx Full (80/443)"

# Block dangerous ports
say ""
say "Security Rules (block dangerous):"
ufw deny 3389/tcp comment "Block RDP brute-force" > /dev/null 2>&1 && check "Block RDP (3389)"
ufw deny 5901/tcp comment "Block VNC from WAN" > /dev/null 2>&1 && check "Block VNC WAN (5901)"

# LAN-only services (192.168.1.0/24)
say ""
say "LAN-Only Services (192.168.1.0/24):"
ufw allow from 192.168.1.0/24 to any port 8081 proto tcp comment "Ollama API" > /dev/null 2>&1 && check "Ollama (8081)"
ufw allow from 192.168.1.0/24 to any port 53 proto tcp comment "Pi-hole DNS" > /dev/null 2>&1 && check "Pi-hole TCP (53)"
ufw allow from 192.168.1.0/24 to any port 53 proto udp comment "Pi-hole DNS" > /dev/null 2>&1 && check "Pi-hole UDP (53)"
ufw allow from 192.168.1.0/24 to any port 9090 proto tcp comment "Cockpit LAN only" > /dev/null 2>&1 && check "Cockpit (9090)"
ufw allow from 192.168.1.0/24 to any port 5901 proto tcp comment "VNC LAN only" > /dev/null 2>&1 && check "VNC LAN (5901)"
ufw allow from 192.168.1.0/24 to any port 8888 proto tcp comment "CasaOS LAN access" > /dev/null 2>&1 && check "CasaOS (8888)"

# Broader private network ranges (backup)
say ""
say "Backup Private Ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16):"
ufw allow from 192.168.0.0/16 to any port 8888 proto tcp comment "CasaOS private network" > /dev/null 2>&1 && check "CasaOS (192.168.0.0/16)"
ufw allow from 10.0.0.0/8 to any port 8888 proto tcp comment "CasaOS private network" > /dev/null 2>&1 && check "CasaOS (10.0.0.0/8)"
ufw allow from 172.16.0.0/12 to any port 8888 proto tcp comment "CasaOS private network" > /dev/null 2>&1 && check "CasaOS (172.16.0.0/12)"

# Public services (anywhere)
say ""
say "Public Services (anywhere):"
ufw allow 7777 comment "Custom service" > /dev/null 2>&1 && check "Port 7777"
ufw allow 11434 comment "Ollama inference" > /dev/null 2>&1 && check "Port 11434"

say ""
say "═══════════════════════════════════════════════════════════════"
say "Firewall rules applied. Current status:"
say "═══════════════════════════════════════════════════════════════"
say ""
ufw status numbered
say ""
say "✅ Firewall configuration complete!"
say ""
say "To view rules: sudo ufw status numbered"
say "To delete a rule: sudo ufw delete [number]"
say "To reload firewall: sudo ufw reload"
