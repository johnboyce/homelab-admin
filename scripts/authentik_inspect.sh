#!/usr/bin/env bash
set -euo pipefail

AUTHENTIK_BASE_URL="${AUTHENTIK_BASE_URL:-https://auth.johnnyblabs.com}"
API_BASE="${AUTHENTIK_BASE_URL%/}/api/v3"
TOKEN="${AUTHENTIK_API_TOKEN:-}"

if [[ -z "${TOKEN}" ]]; then
  echo "❌ AUTHENTIK_API_TOKEN is not set."
  echo "   Usage:"
  echo "   AUTHENTIK_API_TOKEN='...' ./authentik_inspect.sh"
  exit 1
fi

AUTH_HEADER="Authorization: Bearer ${TOKEN}"

api() {
  local path="$1"
  echo
  echo "== GET ${API_BASE}${path} =="
  # show status + a little body if error
  curl -sS -D /tmp/ak_headers.txt \
    -H "${AUTH_HEADER}" \
    -H "Accept: application/json" \
    "${API_BASE}${path}" \
    -o /tmp/ak_body.json || true
  head -n 20 /tmp/ak_headers.txt
  echo
  cat /tmp/ak_body.json | (jq . 2>/dev/null || cat)
}

api "/root/config/"
api "/core/applications/"
api "/providers/proxy/"
api "/outposts/instances/"
api "/providers/oauth2/"
