#!/usr/bin/env bash
set -euo pipefail

# Creates Authentik OAuth2/OIDC provider + application for BookStack via Authentik API.
#
# Usage:
#   AUTHENTIK_BASE_URL="https://auth.johnnyblabs.com" \
#   AUTHENTIK_API_TOKEN="..." \
#   BOOKSTACK_FQDN="bookstack.johnnyblabs.com" \
#   ./scripts/bookstack_oidc_bootstrap.sh
#
# Optional:
#   BOOKSTACK_APP_SLUG="bookstack"
#   BOOKSTACK_PROVIDER_NAME="bookstack-oidc"
#   TEMPLATE_PROVIDER_NAME="nginx-forwardauth"  # existing provider to copy flows from

AUTHENTIK_BASE_URL="${AUTHENTIK_BASE_URL:-https://auth.johnnyblabs.com}"
API_BASE="${AUTHENTIK_BASE_URL%/}/api/v3"
TOKEN="${AUTHENTIK_API_TOKEN:-}"

BOOKSTACK_FQDN="${BOOKSTACK_FQDN:-bookstack.johnnyblabs.com}"
BOOKSTACK_APP_SLUG="${BOOKSTACK_APP_SLUG:-bookstack}"
BOOKSTACK_PROVIDER_NAME="${BOOKSTACK_PROVIDER_NAME:-bookstack-oidc}"
BOOKSTACK_APP_NAME="${BOOKSTACK_APP_NAME:-BookStack}"

TEMPLATE_PROVIDER_NAME="${TEMPLATE_PROVIDER_NAME:-nginx-forwardauth}"

if [[ -z "${TOKEN}" ]]; then
  echo "❌ AUTHENTIK_API_TOKEN is not set."
  exit 1
fi

if [[ -z "${BOOKSTACK_FQDN}" ]]; then
  echo "❌ BOOKSTACK_FQDN is not set (e.g. bookstack.johnnyblabs.com)."
  exit 1
fi

auth_header() { printf "Authorization: Bearer %s" "${TOKEN}"; }

api_get() {
  local path="$1"
  curl -fsS -H "$(auth_header)" -H "Accept: application/json" "${API_BASE}${path}"
}

api_post() {
  local path="$1"
  curl -fsS -X POST -H "$(auth_header)" -H "Content-Type: application/json" "${API_BASE}${path}" -d @-
}

redact() {
  local s="${1:-}"
  if [[ "${#s}" -le 10 ]]; then
    echo "<redacted>"
  else
    echo "${s:0:6}…${s: -4}"
  fi
}

echo "== Authentik BookStack OIDC bootstrap =="
echo "Base URL      : ${AUTHENTIK_BASE_URL}"
echo "API Base      : ${API_BASE}"
echo "BookStack FQDN: ${BOOKSTACK_FQDN}"
echo "App slug      : ${BOOKSTACK_APP_SLUG}"
echo "Provider name : ${BOOKSTACK_PROVIDER_NAME}"
echo "Template prov : ${TEMPLATE_PROVIDER_NAME}"
echo

echo "== 1) Sanity check API token =="
api_get "/root/config/" | jq -r '.capabilities[]' >/dev/null
echo "✅ API token works"
echo

echo "== 2) Find template OAuth2 provider to copy required flows from =="
template_json="$(api_get "/providers/oauth2/" | jq -c --arg n "${TEMPLATE_PROVIDER_NAME}" '.results[] | select(.name==$n)')"
if [[ -z "${template_json}" ]]; then
  echo "❌ Could not find OAuth2 provider named '${TEMPLATE_PROVIDER_NAME}'."
  echo "   Available providers:"
  api_get "/providers/oauth2/" | jq -r '.results[] | "- " + .name'
  exit 1
fi

AUTHZ_FLOW="$(echo "${template_json}" | jq -r '.authorization_flow')"
INVALID_FLOW="$(echo "${template_json}" | jq -r '.invalidation_flow')"
AUTHN_FLOW="$(echo "${template_json}" | jq -r '.authentication_flow // empty')"
PROPERTY_MAPPINGS="$(echo "${template_json}" | jq -c '.property_mappings')"

echo "✅ Template provider found."
echo "   authorization_flow : ${AUTHZ_FLOW}"
echo "   invalidation_flow  : ${INVALID_FLOW}"
if [[ -n "${AUTHN_FLOW}" ]]; then
  echo "   authentication_flow: ${AUTHN_FLOW}"
else
  echo "   authentication_flow: <not set on template>"
fi
echo "   property_mappings  : ${PROPERTY_MAPPINGS}"
echo

echo "== 3) Check if BookStack OAuth2 provider already exists =="
existing_provider="$(api_get "/providers/oauth2/" | jq -c --arg n "${BOOKSTACK_PROVIDER_NAME}" '.results[] | select(.name==$n)')"
if [[ -n "${existing_provider}" ]]; then
  PROVIDER_PK="$(echo "${existing_provider}" | jq -r '.pk')"
  CLIENT_ID="$(echo "${existing_provider}" | jq -r '.client_id')"
  CLIENT_SECRET="$(echo "${existing_provider}" | jq -r '.client_secret')"
  echo "✅ Provider already exists: pk=${PROVIDER_PK}, client_id=${CLIENT_ID}"
else
  echo "== 4) Create BookStack OAuth2/OIDC provider =="
  redirect_uri="https://${BOOKSTACK_FQDN}/oidc/callback"

  # Build JSON payload conditionally including authentication_flow if present on template.
  if [[ -n "${AUTHN_FLOW}" ]]; then
    provider_payload="$(jq -n \
      --arg name "${BOOKSTACK_PROVIDER_NAME}" \
      --arg client_type "confidential" \
      --arg authz "${AUTHZ_FLOW}" \
      --arg inval "${INVALID_FLOW}" \
      --arg authn "${AUTHN_FLOW}" \
      --arg redirect "${redirect_uri}" \
      --argjson mappings "${PROPERTY_MAPPINGS}" \
      '{
        name: $name,
        client_type: $client_type,
        authorization_flow: $authz,
        invalidation_flow: $inval,
        authentication_flow: $authn,
        redirect_uris: [{matching_mode:"strict", url:$redirect}],
        property_mappings: $mappings,
        include_claims_in_id_token: true,
        issuer_mode: "per_provider",
        sub_mode: "hashed_user_id"
      }')"
  else
    provider_payload="$(jq -n \
      --arg name "${BOOKSTACK_PROVIDER_NAME}" \
      --arg client_type "confidential" \
      --arg authz "${AUTHZ_FLOW}" \
      --arg inval "${INVALID_FLOW}" \
      --arg redirect "${redirect_uri}" \
      --argjson mappings "${PROPERTY_MAPPINGS}" \
      '{
        name: $name,
        client_type: $client_type,
        authorization_flow: $authz,
        invalidation_flow: $inval,
        redirect_uris: [{matching_mode:"strict", url:$redirect}],
        property_mappings: $mappings,
        include_claims_in_id_token: true,
        issuer_mode: "per_provider",
        sub_mode: "hashed_user_id"
      }')"
  fi

  created_provider="$(printf '%s' "${provider_payload}" | api_post "/providers/oauth2/" )"
  PROVIDER_PK="$(echo "${created_provider}" | jq -r '.pk')"
  CLIENT_ID="$(echo "${created_provider}" | jq -r '.client_id')"
  CLIENT_SECRET="$(echo "${created_provider}" | jq -r '.client_secret')"
  echo "✅ Created provider pk=${PROVIDER_PK}"
fi
echo

echo "== 5) Check if BookStack application already exists =="
existing_app="$(api_get "/core/applications/" | jq -c --arg slug "${BOOKSTACK_APP_SLUG}" '.results[] | select(.slug==$slug)')"
if [[ -n "${existing_app}" ]]; then
  APP_PK="$(echo "${existing_app}" | jq -r '.pk')"
  APP_NAME="$(echo "${existing_app}" | jq -r '.name')"
  echo "✅ Application already exists: pk=${APP_PK}, name=${APP_NAME}, slug=${BOOKSTACK_APP_SLUG}"
else
  echo "== 6) Create BookStack application bound to provider =="
  app_payload="$(jq -n \
    --arg name "${BOOKSTACK_APP_NAME}" \
    --arg slug "${BOOKSTACK_APP_SLUG}" \
    --argjson provider "${PROVIDER_PK}" \
    '{
      name: $name,
      slug: $slug,
      provider: $provider,
      open_in_new_tab: false
    }')"

  created_app="$(printf '%s' "${app_payload}" | api_post "/core/applications/" )"
  APP_PK="$(echo "${created_app}" | jq -r '.pk')"
  echo "✅ Created application pk=${APP_PK}, slug=${BOOKSTACK_APP_SLUG}"
fi
echo

# Issuer/discovery URL: with issuer_mode=per_provider, authentik issues per-provider OIDC metadata.
# The most practical output is the discovery URL under the application slug path.
DISCOVERY_URL="${AUTHENTIK_BASE_URL%/}/application/o/${BOOKSTACK_APP_SLUG}/.well-known/openid-configuration"

echo "== Summary =="
echo "BookStack redirect URI : https://${BOOKSTACK_FQDN}/oidc/callback"
echo "Authentik application  : name=${BOOKSTACK_APP_NAME}, slug=${BOOKSTACK_APP_SLUG}, pk=${APP_PK}"
echo "Authentik provider     : name=${BOOKSTACK_PROVIDER_NAME}, pk=${PROVIDER_PK}"
echo "OIDC discovery URL     : ${DISCOVERY_URL}"
echo "OIDC client_id         : ${CLIENT_ID}"
echo "OIDC client_secret     : $(redact "${CLIENT_SECRET}")"
echo
echo "Next (BookStack .env):"
echo "  AUTH_METHOD=oidc"
echo "  AUTH_AUTO_INITIATE=true"
echo "  OIDC_ISSUER=${AUTHENTIK_BASE_URL%/}/application/o/${BOOKSTACK_APP_SLUG}/"
echo "  OIDC_ISSUER_DISCOVER=true"
echo "  OIDC_CLIENT_ID=${CLIENT_ID}"
echo "  OIDC_CLIENT_SECRET=<use the real secret (store securely)>"
