#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-quartz-smoke:test}"
FIXTURE="$(cd "$(dirname "$0")/fixtures/smoke" && pwd)"

run_container() {
  local name="$1"; shift
  docker run -d --name "$name" -p 8080:8080 \
    -v "$FIXTURE:/usr/src/app/content" \
    "$@" "$IMAGE"
}

wait_for_server() {
  local name="$1"
  for i in $(seq 1 60); do
    curl -sfL --max-time 2 http://localhost:8080/ > /dev/null 2>&1 && \
      echo "[$name] server ready after $((i * 2))s" && return 0
    sleep 2
  done
  echo "[$name] server did not start in time"
  docker logs "$name"
  return 1
}

stop_container() {
  docker stop "$1" > /dev/null 2>&1 || true
  docker rm   "$1" > /dev/null 2>&1 || true
}

assert() {
  local desc="$1"; shift
  if "$@"; then
    echo "  PASS: $desc"
  else
    echo "  FAIL: $desc"
    return 1
  fi
}

cleanup() {
  stop_container quartz-smoke
  stop_container quartz-env
  stop_container quartz-ignore
}
trap cleanup EXIT

# ── Main smoke ────────────────────────────────────────────────────────────────
echo "=== Main smoke ==="
run_container quartz-smoke
wait_for_server quartz-smoke

assert "GET /" bash -c 'curl -sfL http://localhost:8080/ > /dev/null'

assert "/notes/ lists alpha and beta (folder-page)" bash -c '
  body=$(curl -sfL http://localhost:8080/notes/)
  echo "$body" | grep -qi "alpha" && echo "$body" | grep -qi "beta"
'

assert "/notes/alpha/ has .related element and link to beta (related plugin)" bash -c '
  body=$(curl -sfL http://localhost:8080/notes/alpha/)
  echo "$body" | grep -q "class=\"related" && echo "$body" | grep -q "/notes/beta"
'

assert "GET /docs/ returns 200 (content-page excludes subfolder index)" bash -c 'curl -sfL http://localhost:8080/docs/ > /dev/null'

assert "sitemap.xml has <loc>, notes/alpha, and guide (content-index + includePDFs)" bash -c '
  body=$(curl -sfL http://localhost:8080/sitemap.xml)
  echo "$body" | grep -q "<loc>" &&
  echo "$body" | grep -q "notes/alpha" &&
  echo "$body" | grep -q "guide"
'

assert "index.xml is a valid RSS feed (content-index)" bash -c '
  curl -sfL http://localhost:8080/index.xml | grep -q "<rss"
'

stop_container quartz-smoke

# ── Env-var overrides ─────────────────────────────────────────────────────────
echo "=== Env-var overrides ==="
run_container quartz-env \
  -e QUARTZ_PAGE_TITLE="Smoke Garden" \
  -e QUARTZ_LOCALE="fr-FR" \
  -e PLUGIN_CREATED_MODIFIED_DATE_PRIORITY="filesystem"
wait_for_server quartz-env

assert "QUARTZ_PAGE_TITLE overrides site title" bash -c '
  curl -sfL http://localhost:8080/ | grep -q "Smoke Garden"
'

assert "QUARTZ_LOCALE sets lang=fr" bash -c '
  curl -sfL http://localhost:8080/ | grep -q "lang=\"fr\""
'

assert "PLUGIN_CREATED_MODIFIED_DATE_PRIORITY — page still renders <time>" bash -c '
  curl -sfL http://localhost:8080/notes/alpha/ | grep -q "<time"
'

stop_container quartz-env

# ── Ignore patterns ───────────────────────────────────────────────────────────
echo "=== Ignore patterns ==="
run_container quartz-ignore -e QUARTZ_IGNORE_PATTERNS="notes,"
wait_for_server quartz-ignore

assert "QUARTZ_IGNORE_PATTERNS=notes, makes /notes/alpha/ return 404" bash -c '
  http_code=$(curl -sfL -o /dev/null -w "%{http_code}" http://localhost:8080/notes/alpha/)
  [ "$http_code" = "404" ]
'

stop_container quartz-ignore

echo ""
echo "All smoke tests passed."
