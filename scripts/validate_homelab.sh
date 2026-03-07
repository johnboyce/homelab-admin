#!/usr/bin/env bash
# validate_homelab.sh — Infrastructure compliance validation
# Checks homelab configuration against HOMELAB_SPEC.yml standards
# Usage: ./scripts/validate_homelab.sh [--category <category>] [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_JSON=false
CATEGORY_FILTER=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    --category)
      CATEGORY_FILTER="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--category <category>] [--json]"
      exit 1
      ;;
  esac
done

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
INFO_COUNT=0

log_result() {
  local status="$1"
  local check_name="$2"
  local message="$3"
  local remediation="${4:-}"

  case "$status" in
    PASS)
      ((PASS_COUNT++))
      if [ "$OUTPUT_JSON" = false ]; then
        echo -e "${GREEN}✓${NC} $check_name"
        [ -n "$message" ] && echo -e "  ${message}"
      fi
      ;;
    FAIL)
      ((FAIL_COUNT++))
      if [ "$OUTPUT_JSON" = false ]; then
        echo -e "${RED}✗${NC} $check_name"
        echo -e "  ${RED}${message}${NC}"
        [ -n "$remediation" ] && echo -e "  ${YELLOW}→ ${remediation}${NC}"
      fi
      ;;
    WARN)
      ((WARN_COUNT++))
      if [ "$OUTPUT_JSON" = false ]; then
        echo -e "${YELLOW}⚠${NC} $check_name"
        echo -e "  ${message}"
        [ -n "$remediation" ] && echo -e "  ${YELLOW}→ ${remediation}${NC}"
      fi
      ;;
    INFO)
      ((INFO_COUNT++))
      if [ "$OUTPUT_JSON" = false ]; then
        echo -e "${BLUE}ℹ${NC} $check_name"
        echo -e "  ${message}"
      fi
      ;;
  esac
}

print_header() {
  if [ "$OUTPUT_JSON" = false ]; then
    echo ""
    echo -e "${BOLD}${BLUE}═══ $1 ═══${NC}"
    echo ""
  fi
}

# Check 1: No secrets in git
check_no_secrets_in_git() {
  print_header "Security: Secret Management"

  local found_secrets=false

  # Check for .env files (except .env.example)
  if git -C "$REPO_ROOT" ls-files | grep -E '\.env$' | grep -v example >/dev/null 2>&1; then
    log_result FAIL "No .env files in git" \
      "Found .env files committed to repository" \
      "Remove them: git rm --cached <file> && git commit"
    found_secrets=true
  else
    log_result PASS "No .env files in git" "No secret .env files found"
  fi

  # Check for private keys
  if git -C "$REPO_ROOT" ls-files | grep -E '\.(key|pem|p12|pfx)$' >/dev/null 2>&1; then
    log_result FAIL "No private keys in git" \
      "Found private key files in repository" \
      "Remove them and add to .gitignore"
    found_secrets=true
  else
    log_result PASS "No private keys in git" "No private key files found"
  fi

  # Check for hardcoded passwords (basic check)
  if git -C "$REPO_ROOT" grep -i "password.*=" platform/ 2>/dev/null | grep -v ".example" | grep -v "# " >/dev/null; then
    log_result WARN "No hardcoded passwords" \
      "Possible hardcoded passwords found (manual review needed)" \
      "Review matches and ensure using env_file instead"
  else
    log_result PASS "No hardcoded passwords" "No obvious hardcoded passwords"
  fi
}

# Check 2: Docker Compose standards
check_docker_compose_standards() {
  print_header "Docker Compose Standards"

  local compose_files
  mapfile -t compose_files < <(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f)

  for compose_file in "${compose_files[@]}"; do
    local service_dir
    service_dir=$(basename "$(dirname "$compose_file")")

    # Check for required fields
    if ! grep -q "container_name:" "$compose_file"; then
      log_result FAIL "container_name in $service_dir" \
        "Missing container_name field" \
        "Add container_name to all services"
    else
      log_result PASS "container_name in $service_dir"
    fi

    if ! grep -q "restart:" "$compose_file"; then
      log_result WARN "restart policy in $service_dir" \
        "Missing restart policy" \
        "Add 'restart: unless-stopped' to services"
    else
      log_result PASS "restart policy in $service_dir"
    fi

    if ! grep -q "networks:" "$compose_file"; then
      log_result FAIL "networks in $service_dir" \
        "Missing networks configuration" \
        "Add geek-infra network"
    else
      # Check if geek-infra is used
      if ! grep -q "geek-infra" "$compose_file"; then
        log_result FAIL "geek-infra network in $service_dir" \
          "Not using geek-infra network" \
          "Change to use geek-infra external network"
      else
        log_result PASS "geek-infra network in $service_dir"
      fi
    fi
  done
}

# Check 3: Ansible role coverage
check_ansible_coverage() {
  print_header "Ansible Role Coverage"

  local services
  mapfile -t services < <(find "$REPO_ROOT/platform" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)

  for service in "${services[@]}"; do
    # Skip ingress directory (nginx role manages it)
    if [ "$service" = "ingress" ]; then
      continue
    fi

    # Check if ansible role exists
    local role_path="$REPO_ROOT/ansible/roles/$service"
    if [ ! -d "$role_path" ]; then
      log_result FAIL "Ansible role for $service" \
        "No ansible role found" \
        "Create ansible/roles/$service/tasks/main.yml"
    else
      log_result PASS "Ansible role for $service"

      # Check for tasks/main.yml
      if [ ! -f "$role_path/tasks/main.yml" ]; then
        log_result FAIL "Tasks for $service role" \
          "Missing tasks/main.yml" \
          "Create $role_path/tasks/main.yml"
      else
        log_result PASS "Tasks for $service role"
      fi
    fi
  done

  # Check that all roles are in site.yml
  local site_yml="$REPO_ROOT/ansible/playbooks/site.yml"
  for service in "${services[@]}"; do
    if [ "$service" = "ingress" ]; then
      continue
    fi

    if ! grep -q "role: $service" "$site_yml" 2>/dev/null; then
      log_result WARN "Role $service in site.yml" \
        "Role not included in main playbook" \
        "Add to ansible/playbooks/site.yml"
    else
      log_result PASS "Role $service in site.yml"
    fi
  done
}

# Check 4: Version pinning
check_version_pinning() {
  print_header "Version Management"

  local compose_files
  mapfile -t compose_files < <(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f)

  for compose_file in "${compose_files[@]}"; do
    local service_dir
    service_dir=$(basename "$(dirname "$compose_file")")

    # Extract image tags
    local images
    mapfile -t images < <(grep "image:" "$compose_file" | sed 's/.*image: *//' | sed 's/#.*//')

    for image in "${images[@]}"; do
      if [[ "$image" == *":latest" ]]; then
        log_result WARN "Version pinning: $service_dir" \
          "Using :latest tag for $(echo "$image" | cut -d: -f1)" \
          "Consider pinning to specific version for reproducibility"
      else
        log_result PASS "Version pinning: $service_dir ($image)"
      fi
    done
  done
}

# Check 5: Documentation completeness
check_documentation() {
  print_header "Documentation Coverage"

  # Check for core documentation files
  local required_docs=(
    "README.md"
    "ADMIN.md"
    "docs/ANSIBLE_DEPLOYMENT.md"
    "docs/FIREWALL.md"
    "docs/TLS_CERTIFICATES.md"
  )

  for doc in "${required_docs[@]}"; do
    if [ -f "$REPO_ROOT/$doc" ]; then
      log_result PASS "Required doc: $doc"
    else
      log_result FAIL "Required doc: $doc" \
        "Missing required documentation" \
        "Create $doc with relevant information"
    fi
  done

  # Check for .env.example files
  local compose_files
  mapfile -t compose_files < <(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f)

  for compose_file in "${compose_files[@]}"; do
    local service_dir
    service_dir=$(dirname "$compose_file")
    local service_name
    service_name=$(basename "$service_dir")

    # Check if service uses env_file
    if grep -q "env_file:" "$compose_file"; then
      local example_file="$service_dir/.env.example"
      if [ -f "$example_file" ]; then
        log_result PASS ".env.example for $service_name"
      else
        log_result WARN ".env.example for $service_name" \
          "Missing .env.example file" \
          "Create $service_dir/.env.example documenting required variables"
      fi
    fi
  done
}

# Check 6: Firewall rules alignment
check_firewall_rules() {
  print_header "Firewall Configuration"

  local firewall_role="$REPO_ROOT/ansible/roles/firewall/tasks/main.yml"

  if [ ! -f "$firewall_role" ]; then
    log_result FAIL "Firewall role exists" \
      "Firewall role not found" \
      "Create ansible/roles/firewall/tasks/main.yml"
    return
  fi

  log_result PASS "Firewall role exists"

  # Check that exposed ports have firewall consideration
  local compose_files
  mapfile -t compose_files < <(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f)

  for compose_file in "${compose_files[@]}"; do
    local service_name
    service_name=$(basename "$(dirname "$compose_file")")

    # Extract port mappings
    local ports
    mapfile -t ports < <(grep -E '^\s+- "?[0-9]+:' "$compose_file" 2>/dev/null | sed 's/.*"\?\([0-9]\+\):.*/\1/' || true)

    for port in "${ports[@]}"; do
      if [ -n "$port" ]; then
        # Check if port 80/443 (handled by Nginx Full)
        if [ "$port" = "80" ] || [ "$port" = "443" ]; then
          log_result PASS "Firewall rule for port $port ($service_name)" "Covered by Nginx Full"
        # Check if port 22 (SSH)
        elif [ "$port" = "22" ]; then
          log_result PASS "Firewall rule for port $port" "Standard SSH"
        else
          # Should be documented in firewall role or docs
          log_result INFO "Port $port exposed by $service_name" \
            "Verify firewall rule in ansible/roles/firewall/ or docs/FIREWALL.md"
        fi
      fi
    done
  done
}

# Check 7: Backup coverage
check_backup_coverage() {
  print_header "Backup Strategy"

  local backup_doc="$REPO_ROOT/BACKUP.md"
  if [ ! -f "$backup_doc" ]; then
    log_result WARN "Backup documentation" \
      "BACKUP.md not found" \
      "Create documentation for backup strategy"
  else
    log_result PASS "Backup documentation exists"
  fi

  # Check for backup scripts
  local backup_scripts
  mapfile -t backup_scripts < <(find "$REPO_ROOT/scripts" -name "*backup*.sh" -type f)

  if [ ${#backup_scripts[@]} -eq 0 ]; then
    log_result WARN "Backup scripts" \
      "No backup scripts found" \
      "Create automated backup scripts in scripts/"
  else
    log_result PASS "Backup scripts" "Found ${#backup_scripts[@]} backup script(s)"
  fi

  # Services that need backup
  local backup_critical=(
    "postgres"
    "authentik"
    "bookstack"
    "forgejo"
    "vaultwarden"
  )

  for service in "${backup_critical[@]}"; do
    local volume_path="/srv/homelab/$service"
    log_result INFO "Backup needed: $service" \
      "Data at $volume_path should be backed up regularly"
  done
}

# Check 8: nginx configuration
check_nginx_config() {
  print_header "nginx Configuration"

  local nginx_dir="$REPO_ROOT/platform/ingress/nginx/etc-nginx-docker"

  # Check main config exists
  if [ -f "$nginx_dir/nginx.conf" ]; then
    log_result PASS "nginx.conf exists"
  else
    log_result FAIL "nginx.conf exists" \
      "Main nginx configuration missing" \
      "Restore from backup or host"
  fi

  # Check conf.d directory
  if [ -d "$nginx_dir/conf.d" ]; then
    log_result PASS "conf.d directory exists"

    # Check for proper naming convention
    local conf_files
    mapfile -t conf_files < <(find "$nginx_dir/conf.d" -name "*.conf" -type f)

    for conf_file in "${conf_files[@]}"; do
      local filename
      filename=$(basename "$conf_file")

      if [[ "$filename" =~ ^[0-9]{2}_[a-z0-9.-]+\.conf$ ]]; then
        log_result PASS "Naming: $filename"
      else
        log_result WARN "Naming: $filename" \
          "Does not follow NN_name.conf pattern" \
          "Rename to follow numeric prefix convention"
      fi
    done
  else
    log_result FAIL "conf.d directory exists" \
      "nginx conf.d directory missing"
  fi

  # Check certs directory (should exist but be empty in repo)
  if [ -d "$nginx_dir/certs" ]; then
    local cert_count
    cert_count=$(find "$nginx_dir/certs" -type f ! -name ".keep" | wc -l)

    if [ "$cert_count" -gt 0 ]; then
      log_result FAIL "Certificates not in git" \
        "Found $cert_count certificate files in repo" \
        "Remove them (should only be on host, not in git)"
    else
      log_result PASS "Certificates not in git"
    fi
  fi
}

# Check 9: Port registry alignment
check_port_registry() {
  print_header "Port Registry Alignment"

  local port_registry="$REPO_ROOT/ansible/inventory/group_vars/all.yml"

  if [ ! -f "$port_registry" ]; then
    log_result FAIL "Port registry exists" \
      "group_vars/all.yml not found" \
      "Create port registry at ansible/inventory/group_vars/all.yml"
    return
  fi

  log_result PASS "Port registry exists"

  # Check that it has services section
  if grep -q "^services:" "$port_registry"; then
    log_result PASS "Port registry has services section"
  else
    log_result FAIL "Port registry structure" \
      "Missing services section" \
      "Add services section to group_vars/all.yml"
  fi
}

# Check 10: Version currency
check_version_currency() {
  print_header "Version Currency Check"

  log_result INFO "Version checking" \
    "This requires manual upstream checks or API integration"

  # Check when versions were last verified
  local spec_file="$REPO_ROOT/HOMELAB_SPEC.yml"
  if [ -f "$spec_file" ]; then
    log_result PASS "Spec file exists" "HOMELAB_SPEC.yml found"

    # Extract last_updated date from version matrix
    if grep -q "last_updated:" "$spec_file"; then
      local last_check
      last_check=$(grep "last_updated:" "$spec_file" | head -1 | sed 's/.*: *"\(.*\)"/\1/')
      log_result INFO "Last version check" "Version matrix last updated: $last_check"

      # Check if it's recent (within 90 days)
      if command -v date >/dev/null 2>&1; then
        local today
        today=$(date +%Y-%m-%d)
        # Simple date comparison (assumes ISO format)
        if [[ "$last_check" < "$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d)" ]]; then
          log_result WARN "Version check recency" \
            "Last version check was >90 days ago" \
            "Run version audit and update HOMELAB_SPEC.yml"
        else
          log_result PASS "Version check recency" "Versions checked within 90 days"
        fi
      fi
    fi
  else
    log_result WARN "Spec file exists" \
      "HOMELAB_SPEC.yml not found" \
      "Version tracking not available"
  fi
}

# Check 11: Consistency patterns
check_consistency() {
  print_header "Consistency Patterns"

  # Check volume path consistency (/srv/homelab/{service}/)
  local compose_files
  mapfile -t compose_files < <(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f)

  for compose_file in "${compose_files[@]}"; do
    local service_name
    service_name=$(basename "$(dirname "$compose_file")")

    # Extract volume mounts
    if grep -q "volumes:" "$compose_file"; then
      local volumes
      mapfile -t volumes < <(grep -E '^\s+- /' "$compose_file" | grep -v "env_file" | sed 's/.*- *//' | cut -d: -f1 || true)

      for volume in "${volumes[@]}"; do
        if [ -n "$volume" ]; then
          if [[ "$volume" =~ ^/srv/homelab/ ]]; then
            log_result PASS "Volume path: $service_name" "$volume"
          elif [[ "$volume" =~ ^/etc/ ]]; then
            # /etc/ paths are acceptable (configs, secrets)
            log_result PASS "Volume path: $service_name" "$volume"
          elif [[ "$volume" =~ ^/var/run/ ]]; then
            # /var/run/ acceptable for docker.sock
            log_result PASS "Volume path: $service_name" "$volume"
          else
            log_result WARN "Volume path: $service_name" \
              "Non-standard path: $volume" \
              "Consider using /srv/homelab/$service_name/"
          fi
        fi
      done
    fi
  done
}

# Check 12: Secret file requirements
check_secret_files() {
  print_header "Secret Files (.env.example)"

  local compose_files
  mapfile -t compose_files < <(find "$REPO_ROOT/platform" -name "docker-compose.yml" -type f)

  for compose_file in "${compose_files[@]}"; do
    local service_dir
    service_dir=$(dirname "$compose_file")
    local service_name
    service_name=$(basename "$service_dir")

    # Check if service uses env_file
    if grep -q "env_file:" "$compose_file"; then
      local example_file="$service_dir/.env.example"
      if [ -f "$example_file" ]; then
        log_result PASS ".env.example: $service_name" "Documentation exists"
      else
        log_result WARN ".env.example: $service_name" \
          "Service uses secrets but no .env.example" \
          "Create $service_dir/.env.example documenting required variables"
      fi
    fi
  done
}

# Check 13: Best practices
check_best_practices() {
  print_header "Best Practices"

  # Check for README files
  if [ -f "$REPO_ROOT/README.md" ]; then
    log_result PASS "Root README.md exists"
  else
    log_result FAIL "Root README.md exists" \
      "No README.md at root" \
      "Create README.md documenting the project"
  fi

  # Check for .gitignore
  if [ -f "$REPO_ROOT/.gitignore" ]; then
    log_result PASS ".gitignore exists"

    # Check for important patterns
    if grep -q "\.env$" "$REPO_ROOT/.gitignore" && \
       grep -q "\.key$" "$REPO_ROOT/.gitignore"; then
      log_result PASS ".gitignore covers secrets"
    else
      log_result WARN ".gitignore patterns" \
        "May not cover all secret patterns" \
        "Ensure .env, .key, *.pem are ignored"
    fi
  else
    log_result FAIL ".gitignore exists" \
      "No .gitignore file" \
      "Create .gitignore to prevent committing secrets"
  fi

  # Check Makefile exists
  if [ -f "$REPO_ROOT/Makefile" ]; then
    log_result PASS "Makefile exists" "Task automation available"
  else
    log_result WARN "Makefile exists" \
      "No Makefile for task shortcuts"
  fi
}

# Main execution
main() {
  if [ "$OUTPUT_JSON" = false ]; then
    echo -e "${BOLD}${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║       Homelab Infrastructure Validation Report                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Repository: $REPO_ROOT"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
  fi

  # Run all checks
  check_no_secrets_in_git
  check_docker_compose_standards
  check_ansible_coverage
  check_version_pinning
  check_documentation
  check_firewall_rules
  check_port_registry
  check_version_currency
  check_consistency
  check_secret_files
  check_best_practices

  # Summary
  if [ "$OUTPUT_JSON" = false ]; then
    echo ""
    echo -e "${BOLD}${BLUE}═══ Summary ═══${NC}"
    echo ""
    echo -e "${GREEN}Passed:${NC}   $PASS_COUNT"
    echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "${RED}Failed:${NC}   $FAIL_COUNT"
    echo -e "${BLUE}Info:${NC}     $INFO_COUNT"
    echo ""

    if [ $FAIL_COUNT -eq 0 ]; then
      echo -e "${GREEN}${BOLD}✓ Infrastructure validation passed!${NC}"
      exit 0
    else
      echo -e "${RED}${BOLD}✗ Infrastructure validation found $FAIL_COUNT critical issues${NC}"
      exit 1
    fi
  fi
}

main "$@"

