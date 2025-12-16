#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://auth.geek/api/v3"
TOKEN="$AUTHENTIK_OUTPOST_TOKEN"
AUTH_HEADER="Authorization: Bearer ${TOKEN}"

echo "== Authentik API sanity check =="
curl -s "${BASE_URL}/root/config/" \
  -H "${AUTH_HEADER}" | jq

echo
echo "== Applications =="
curl -s "${BASE_URL}/core/applications/" \
  -H "${AUTH_HEADER}" | jq '.results[] | {id, name, slug}'

echo
echo "== Proxy Providers =="
curl -s "${BASE_URL}/providers/proxy/" \
  -H "${AUTH_HEADER}" | jq '.results[] | {id, name, external_host, internal_host}'

echo
echo "== Outposts =="
curl -s "${BASE_URL}/outposts/instances/" \
  -H "${AUTH_HEADER}" | jq '.results[] | {id, name, type}'
