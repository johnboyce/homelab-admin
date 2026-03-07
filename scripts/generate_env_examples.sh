#!/usr/bin/env bash
# generate_env_examples.sh — Generate .env.example files for services
# Scans docker-compose.yml files and creates .env.example documentation
# Usage: ./scripts/generate_env_examples.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=false

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  echo -e "${YELLOW}DRY RUN MODE - No files will be created${NC}"
  echo ""
fi

echo -e "${BLUE}Scanning for services that need .env.example files...${NC}"
echo ""

# Find all docker-compose.yml files
compose_files=$(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f | sort)

for compose_file in $compose_files; do
  service_dir=$(dirname "$compose_file")
  service_name=$(basename "$service_dir")

  # Check if this service uses env_file
  if ! grep -q "env_file:" "$compose_file"; then
    continue
  fi

  example_file="$service_dir/.env.example"

  # Check if .env.example already exists
  if [ -f "$example_file" ]; then
    echo -e "${GREEN}✓${NC} $service_name — .env.example exists"
    continue
  fi

  echo -e "${YELLOW}→${NC} $service_name — Creating .env.example"

  # Extract environment variables from docker-compose.yml
  env_vars=$(grep -E "^\s+[A-Z_]+:" "$compose_file" | sed 's/:.*//' | sed 's/^ *//' | sort -u || true)

  # Extract variables referenced in environment section
  referenced_vars=$(grep -E '\$\{[A-Z_]+\}' "$compose_file" | grep -oE '\$\{[A-Z_]+\}' | sed 's/[${}]//g' | sort -u || true)

  # Combine and deduplicate
  all_vars=$(echo -e "$env_vars\n$referenced_vars" | sort -u | grep -v '^$' || true)

  # Generate content
  content="# $service_name environment variables
# Copy this file to /etc/homelab/secrets/$service_name.env on the geek host
# and fill in with actual values

# Path on host: /etc/homelab/secrets/$service_name.env
# Permissions: 644 (readable by docker user)
# Never commit actual values to git

"

  if [ -n "$all_vars" ]; then
    while IFS= read -r var; do
      if [ -n "$var" ]; then
        # Add helpful comments for common variables
        case "$var" in
          *PASSWORD*|*SECRET*|*KEY*)
            content+="# Generate with: openssl rand -base64 32
"
            ;;
          *TOKEN*)
            content+="# API or authentication token
"
            ;;
          *HOST*|*URL*)
            content+="# Service endpoint or URL
"
            ;;
        esac
        content+="$var=changeme
"
      fi
    done <<< "$all_vars"
  else
    content+="# No environment variables detected in docker-compose.yml
# This file serves as documentation that secrets are managed externally
"
  fi

  content+="
# Security Notes:
# - Rotate secrets regularly
# - Use strong random values (not 'changeme')
# - Keep backups of this file in secure location (not in git)
# - Document required variables in service README if complex
"

  if [ "$DRY_RUN" = true ]; then
    echo "  Would create: $example_file"
    echo "  Variables found: $(echo "$all_vars" | wc -l | xargs)"
  else
    echo "$content" > "$example_file"
    echo -e "  ${GREEN}Created:${NC} $example_file"
  fi
done

echo ""
echo -e "${BLUE}Summary:${NC}"
total=$(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f -exec grep -l "env_file:" {} \; | wc -l)
existing=$(find "$REPO_ROOT/platform" -name ".env.example" -type f | wc -l)
echo "  Services with secrets: $total"
echo "  .env.example files:    $existing"
echo ""

if [ "$DRY_RUN" = false ]; then
  echo -e "${GREEN}✓ .env.example generation complete${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review generated .env.example files"
  echo "  2. Add detailed comments for complex variables"
  echo "  3. Commit to git: git add platform/*/.env.example && git commit -m 'Add .env.example files'"
fi

