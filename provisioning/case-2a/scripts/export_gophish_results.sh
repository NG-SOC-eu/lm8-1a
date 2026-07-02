#!/usr/bin/env bash
# Export GoPhish campaign results for PUC2-Sub Case 2a.
# Usage: ./export_gophish_results.sh <campaign_id> [output_file]
#
# The script queries the GoPhish REST API and writes a JSON report suitable
# for ingestion into the Reporting Workspace (Grafana / PostgreSQL).
#
# Prerequisites: curl, jq
# Run from the instructor console or the phishing-simulator host.

set -euo pipefail

GOPHISH_HOST="${GOPHISH_HOST:-http://phishing-simulator.internal:3333}"
GOPHISH_API_KEY="${GOPHISH_API_KEY:-}"
CAMPAIGN_ID="${1:-}"
OUTPUT_FILE="${2:-campaign_${CAMPAIGN_ID}_results_$(date +%Y%m%d_%H%M%S).json}"

usage() {
  echo "Usage: $0 <campaign_id> [output_file]"
  echo ""
  echo "Environment variables:"
  echo "  GOPHISH_HOST     GoPhish base URL (default: http://phishing-simulator.internal:3333)"
  echo "  GOPHISH_API_KEY  GoPhish API key (required)"
  exit 1
}

if [[ -z "${CAMPAIGN_ID}" ]]; then
  echo "ERROR: campaign_id is required." >&2
  usage
fi

if [[ -z "${GOPHISH_API_KEY}" ]]; then
  echo "ERROR: GOPHISH_API_KEY environment variable must be set." >&2
  echo "  Retrieve the API key from the GoPhish admin panel under Account Settings." >&2
  echo "  export GOPHISH_API_KEY=<your-api-key>" >&2
  exit 1
fi

for cmd in curl jq; do
  if ! command -v "${cmd}" &>/dev/null; then
    echo "ERROR: '${cmd}' is required but not installed." >&2
    exit 1
  fi
done

AUTH_HEADER="Authorization: ${GOPHISH_API_KEY}"

echo "[*] Fetching campaign summary for campaign ID ${CAMPAIGN_ID}..."
CAMPAIGN=$(curl -sf -H "${AUTH_HEADER}" \
  "${GOPHISH_HOST}/api/campaigns/${CAMPAIGN_ID}/" \
  || { echo "ERROR: Failed to fetch campaign ${CAMPAIGN_ID}." >&2; exit 1; })

echo "[*] Fetching campaign results..."
RESULTS=$(curl -sf -H "${AUTH_HEADER}" \
  "${GOPHISH_HOST}/api/campaigns/${CAMPAIGN_ID}/results" \
  || { echo "ERROR: Failed to fetch results for campaign ${CAMPAIGN_ID}." >&2; exit 1; })

echo "[*] Fetching campaign summary statistics..."
SUMMARY=$(curl -sf -H "${AUTH_HEADER}" \
  "${GOPHISH_HOST}/api/campaigns/${CAMPAIGN_ID}/summary" \
  || { echo "ERROR: Failed to fetch summary for campaign ${CAMPAIGN_ID}." >&2; exit 1; })

# Merge campaign metadata, summary, and per-target results into one JSON report
REPORT=$(jq -n \
  --argjson campaign "${CAMPAIGN}" \
  --argjson results "${RESULTS}" \
  --argjson summary "${SUMMARY}" \
  '{
    exported_at:    (now | todate),
    scenario:       "PUC2-Sub Case 2a - Phishing Attack Training Scenario",
    campaign:       $campaign,
    summary:        $summary,
    target_results: $results
  }')

echo "${REPORT}" > "${OUTPUT_FILE}"
echo "[+] Report saved to: ${OUTPUT_FILE}"

# Print a human-readable summary to stdout
echo ""
echo "=== Campaign Summary ==="
echo "${SUMMARY}" | jq -r '
  "Campaign:         " + (.name // "N/A"),
  "Status:           " + (.status // "N/A"),
  "Total targets:    " + (.stats.total         | tostring),
  "Emails sent:      " + (.stats.sent          | tostring),
  "Emails opened:    " + (.stats.opened        | tostring),
  "Links clicked:    " + (.stats.clicked       | tostring),
  "Data submitted:   " + (.stats.submitted_data| tostring),
  "Emails reported:  " + (.stats.email_reported| tostring)
' 2>/dev/null || echo "${SUMMARY}" | jq .
