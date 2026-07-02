#!/usr/bin/env bats

setup() {
  export BATS_TMPDIR="$BATS_TEST_TMPDIR"
  mkdir -p "$BATS_TMPDIR/bin"
  PATH="$BATS_TMPDIR/bin:$PATH"
  export PATH

  cat <<'EOS' > "$BATS_TMPDIR/bin/http"
#!/usr/bin/env bash
set -euo pipefail
log_file="${MOCK_HTTP_LOG:-}"
if [[ -n "$log_file" ]]; then
  printf '%s\n' "$*" >> "$log_file"
fi
method=""
url=""
i=1
while [[ $i -le $# ]]; do
  arg="${!i}"
  case "$arg" in
    GET|POST|PUT|DELETE|PATCH)
      method="$arg"
      ((i++))
      url="${!i}"
      ;;
  esac
  ((i++))
done
if [[ -z "$url" ]]; then
  echo "mock http: URL not provided" >&2
  exit 2
fi
if [[ -n "${MOCK_HTTP_FAIL:-}" && "$url" == *"${MOCK_HTTP_FAIL}"* ]]; then
  echo "mock http: forced failure for $url" >&2
  exit 1
fi
if [[ "$url" == *"/auth" ]]; then
  echo '{"token":"mock-token"}'
elif [[ "$method" == "GET" ]]; then
  if [[ -n "${MOCK_HTTP_GET_PAYLOAD:-}" ]]; then
    printf '%s' "$MOCK_HTTP_GET_PAYLOAD"
  else
    echo '{"id":"mock","content":"example"}'
  fi
else
  echo '{"status":"ok"}'
fi
EOS
  chmod +x "$BATS_TMPDIR/bin/http"

  cat <<'EOS' > "$BATS_TMPDIR/bin/jq"
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" != "-r" ]]; then
  echo "mock jq supports only -r" >&2
  exit 1
fi
case "$2" in
  '.token')
    python - "$@" <<'PY'
import json,sys
print(json.load(sys.stdin)['token'])
PY
    ;;
  '.version')
    shift 2
    python - "$@" <<'PY'
import json,sys
from pathlib import Path
path = Path(sys.argv[1])
print(json.loads(path.read_text())['version'])
PY
    ;;
  *)
    echo "mock jq unsupported query" >&2
    exit 1
    ;;
esac
EOS
  chmod +x "$BATS_TMPDIR/bin/jq"

  export SOC_USER="test-user"
  export SOC_PASS="test-pass"
  export NG_SOC_API_BASE="https://ng-soc.example/api"
  export NG_SOAR_API_BASE="https://ng-soar.example/api"
  export CICMS_API_BASE="https://cicms.example/api"
  export PLAYBOOK_LIBRARY_API_BASE="https://library.example/api"
  export CTISS_API_BASE="https://ctiss.example/api"
  export MOCK_HTTP_LOG="$BATS_TMPDIR/http.log"
  : > "$MOCK_HTTP_LOG"
}

teardown() {
  rm -f "$MOCK_HTTP_LOG"
}

@test "create_playbook succeeds with valid inputs" {
  run "$BATS_TEST_DIRNAME/../create_playbook.sh" "$BATS_TEST_DIRNAME/../examples/playbook-create.json"
  [ "$status" -eq 0 ]
  run grep -c 'cacao/repository' "$MOCK_HTTP_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -c 'playbooks/import' "$MOCK_HTTP_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -c 'incidents/register-playbook' "$MOCK_HTTP_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "create_playbook fails when repository call fails" {
  export MOCK_HTTP_FAIL='cacao/repository'
  run "$BATS_TEST_DIRNAME/../create_playbook.sh" "$BATS_TEST_DIRNAME/../examples/playbook-create.json"
  [ "$status" -ne 0 ]
}

@test "update_playbook propagates version and handles errors" {
  run "$BATS_TEST_DIRNAME/../update_playbook.sh" playbook--example-create "$BATS_TEST_DIRNAME/../examples/playbook-update.json"
  [ "$status" -eq 0 ]
  run grep -c 'library/register' "$MOCK_HTTP_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  export MOCK_HTTP_FAIL='playbooks/'
  run "$BATS_TEST_DIRNAME/../update_playbook.sh" playbook--example-create "$BATS_TEST_DIRNAME/../examples/playbook-update.json"
  [ "$status" -ne 0 ]
}

@test "share_playbook posts payload to CTI-SS" {
  export MOCK_HTTP_GET_PAYLOAD='{"id":"mock","version":"1.1.0"}'
  run "$BATS_TEST_DIRNAME/../share_playbook.sh" playbook--example-create canal-general
  [ "$status" -eq 0 ]
  run grep -c 'cacao/share' "$MOCK_HTTP_LOG"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  export MOCK_HTTP_FAIL='cacao/share'
  run "$BATS_TEST_DIRNAME/../share_playbook.sh" playbook--example-create canal-general
  [ "$status" -ne 0 ]
}
