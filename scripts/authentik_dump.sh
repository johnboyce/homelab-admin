#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null || { echo "❌ jq required"; exit 1; }
command -v curl >/dev/null || { echo "❌ curl required"; exit 1; }

AUTHENTIK_BASE_URL="${AUTHENTIK_BASE_URL:-https://auth.johnnyblabs.com}"
API_BASE="${AUTHENTIK_BASE_URL%/}/api/v3"
TOKEN="${AUTHENTIK_API_TOKEN:-}"

if [[ -z "${TOKEN}" ]]; then
  echo "❌ AUTHENTIK_API_TOKEN is not set."
  exit 1
fi

AUTH_HEADER="Authorization: Bearer ${TOKEN}"

ts="$(date -u +"%Y%m%dT%H%M%SZ")"
out_dir="inventory/authentik/${ts}"
latest_dir="inventory/authentik/latest"

mkdir -p "${out_dir}"
mkdir -p "${latest_dir}"

sanitize() {
  # Remove or mask secret-ish fields defensively
  jq 'walk(
        if type=="object" then
          (del(.client_secret, .token, .key, .private_key, .secret)
           | (if has("client_secret") then .client_secret="***" else . end))
        else . end
      )'
}

dump() {
  local path="$1"
  local file="$2"
  echo "== GET ${API_BASE}${path} -> ${file}"
  curl -fsS -H "${AUTH_HEADER}" -H "Accept: application/json" \
    "${API_BASE}${path}" \
  | sanitize > "${out_dir}/${file}"
  ln -sf "../${ts}/${file}" "${latest_dir}/${file}"
}

echo "== Authentik config dump =="
echo "Base: ${AUTHENTIK_BASE_URL}"
echo "Out : ${out_dir}"
echo

dump "/root/config/" "root_config.json"
dump "/core/applications/" "applications.json"
dump "/providers/oauth2/" "providers_oauth2.json"
dump "/providers/proxy/" "providers_proxy.json"
dump "/outposts/instances/" "outposts.json"

echo
echo "✅ Wrote:"
ls -1 "${out_dir}"
echo
echo "✅ Latest symlinks updated under: ${latest_dir}"
