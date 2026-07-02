#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[share_playbook] Error on line ${LINENO}" >&2' ERR

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[share_playbook] Required command '$cmd' not found" >&2
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
: "${CTISS_API_BASE:?Environment variable CTISS_API_BASE must be set}"

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 playbook_identifier ctiss_channel" >&2
  exit 2
fi

PLAYBOOK_ID="$1"
CHANNEL="$2"

AUTH_ENDPOINT=$(join_url "$NG_SOC_API_BASE" "auth")
SOAR_PLAYBOOK_ENDPOINT=$(join_url "$NG_SOAR_API_BASE" "playbooks/$PLAYBOOK_ID")
CTISS_SHARE_ENDPOINT=$(join_url "$CTISS_API_BASE" "cacao/share")

get_token() {
  http --check-status --print=b POST "$AUTH_ENDPOINT" \
    username="$SOC_USER" password="$SOC_PASS" \
    | jq -r '.token'
}

TOKEN=$(get_token)
if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "[share_playbook] Failed to obtain authentication token" >&2
  exit 1
fi

PAYLOAD=$(http --check-status --print=b GET "$SOAR_PLAYBOOK_ENDPOINT" \
  "Authorization: Bearer $TOKEN")

if [[ -z "$PAYLOAD" ]]; then
  echo "[share_playbook] Empty payload returned for playbook '$PLAYBOOK_ID'" >&2
  exit 1
fi

http --check-status POST "$CTISS_SHARE_ENDPOINT" \
  "Authorization: Bearer $TOKEN" \
  channel="$CHANNEL" \
  payload:="$PAYLOAD"
