#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[update_playbook] Error on line ${LINENO}" >&2' ERR

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[update_playbook] Required command '$cmd' not found" >&2
    exit 1
  fi
}

join_url() {
  local base="${1%/}"
  local path="${2#/}"
  printf '%s/%s' "$base" "$path"
}

require_cmd http
require_cmd jq

: "${SOC_USER:?Environment variable SOC_USER must be set}"
: "${SOC_PASS:?Environment variable SOC_PASS must be set}"
: "${NG_SOC_API_BASE:?Environment variable NG_SOC_API_BASE must be set}"
: "${NG_SOAR_API_BASE:?Environment variable NG_SOAR_API_BASE must be set}"
: "${PLAYBOOK_LIBRARY_API_BASE:?Environment variable PLAYBOOK_LIBRARY_API_BASE must be set}"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 playbook_identifier path/to/playbook.json" >&2
  exit 2
fi

PLAYBOOK_ID="$1"
PLAYBOOK_PATH="$2"

if [[ ! -f "$PLAYBOOK_PATH" ]]; then
  echo "[update_playbook] Playbook file '$PLAYBOOK_PATH' not found" >&2
  exit 2
fi

AUTH_ENDPOINT=$(join_url "$NG_SOC_API_BASE" "auth")
REPOSITORY_ENDPOINT=$(join_url "$NG_SOC_API_BASE" "cacao/repository/$PLAYBOOK_ID")
SOAR_UPDATE_ENDPOINT=$(join_url "$NG_SOAR_API_BASE" "playbooks/$PLAYBOOK_ID")
LIBRARY_REGISTER_ENDPOINT=$(join_url "$PLAYBOOK_LIBRARY_API_BASE" "library/register")

get_token() {
  http --check-status --print=b POST "$AUTH_ENDPOINT" \
    username="$SOC_USER" password="$SOC_PASS" \
    | jq -r '.token'
}

TOKEN=$(get_token)
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "[update_playbook] Failed to obtain authentication token" >&2
  exit 1
fi

VERSION=$(jq -r '.version' "$PLAYBOOK_PATH")
if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "[update_playbook] Missing 'version' field in playbook" >&2
  exit 2
fi

http --check-status PUT "$REPOSITORY_ENDPOINT" \
  "Authorization: Bearer $TOKEN" \
  < "$PLAYBOOK_PATH"

http --check-status PUT "$SOAR_UPDATE_ENDPOINT" \
  "Authorization: Bearer $TOKEN" \
  < "$PLAYBOOK_PATH"

http --check-status POST "$LIBRARY_REGISTER_ENDPOINT" \
  "Authorization: Bearer $TOKEN" \
  playbook_id="$PLAYBOOK_ID" \
  version="$VERSION"
