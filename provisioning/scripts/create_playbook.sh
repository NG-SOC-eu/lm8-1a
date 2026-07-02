#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[create_playbook] Error on line ${LINENO}" >&2' ERR

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[create_playbook] Required command '$cmd' not found" >&2
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
: "${CICMS_API_BASE:?Environment variable CICMS_API_BASE must be set}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/playbook.json" >&2
  exit 2
fi

PLAYBOOK_PATH="$1"
if [[ ! -f "$PLAYBOOK_PATH" ]]; then
  echo "[create_playbook] Playbook file '$PLAYBOOK_PATH' not found" >&2
  exit 2
fi

AUTH_ENDPOINT=$(join_url "$NG_SOC_API_BASE" "auth")
REPOSITORY_ENDPOINT=$(join_url "$NG_SOC_API_BASE" "cacao/repository")
SOAR_IMPORT_ENDPOINT=$(join_url "$NG_SOAR_API_BASE" "playbooks/import")
CICMS_REGISTER_ENDPOINT=$(join_url "$CICMS_API_BASE" "incidents/register-playbook")

get_token() {
  http --check-status --print=b POST "$AUTH_ENDPOINT" \
    username="$SOC_USER" password="$SOC_PASS" \
    | jq -r '.token'
}

TOKEN=$(get_token)
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "[create_playbook] Failed to obtain authentication token" >&2
  exit 1
fi

http --check-status POST "$REPOSITORY_ENDPOINT" \
  "Authorization: Bearer $TOKEN" \
  < "$PLAYBOOK_PATH"

http --check-status POST "$SOAR_IMPORT_ENDPOINT" \
  "Authorization: Bearer $TOKEN" \
  < "$PLAYBOOK_PATH"

http --check-status POST "$CICMS_REGISTER_ENDPOINT" \
  "Authorization: Bearer $TOKEN" \
  playbook_path="$PLAYBOOK_PATH"
