#!/usr/bin/env bash
set -euo pipefail
emma_repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$emma_repo_dir"
emma_test_container="emma-garden-integration-$$"
emma_temp_dir="$(mktemp -d /tmp/emma-cloud-tests.XXXXXX)"
emma_http_pid=''
docker run -d --name "$emma_test_container" -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine >/dev/null
cleanup() {
  if [[ -n "$emma_http_pid" ]]; then kill "$emma_http_pid" 2>/dev/null || true; fi
  docker rm -f "$emma_test_container" >/dev/null 2>&1 || true
  rm -rf "$emma_temp_dir"
}
trap cleanup EXIT
emma_pg_ready=0
for ((i=0;i<30;i++)); do
  if docker exec "$emma_test_container" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then emma_pg_ready=1; break; fi
  sleep 1
done
[[ "$emma_pg_ready" == 1 ]] || { echo 'PostgreSQL failed to start'; exit 1; }
docker exec -i "$emma_test_container" psql -U postgres -v ON_ERROR_STOP=1 -q < tests/bootstrap.sql
docker exec -i "$emma_test_container" psql -U postgres -v ON_ERROR_STOP=1 -q < supabase/setup.sql
docker exec -i "$emma_test_container" psql -U postgres -v ON_ERROR_STOP=1 -q < tests/backend.sql
python3 - "$emma_temp_dir/port" <<'PY' >"$emma_temp_dir/http.log" 2>&1 &
import http.server, pathlib, sys
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),http.server.SimpleHTTPRequestHandler)
pathlib.Path(sys.argv[1]).write_text(str(server.server_port))
server.serve_forever()
PY
emma_http_pid=$!
for ((i=0;i<30;i++)); do [[ -s "$emma_temp_dir/port" ]] && break; sleep .1; done
emma_test_port="$(cat "$emma_temp_dir/port")"
EMMA_TEST_CONTAINER="$emma_test_container" EMMA_TEST_BASE_URL="http://127.0.0.1:$emma_test_port/" node tests/cloud-browser.cjs
