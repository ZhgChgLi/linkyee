#!/usr/bin/env sh
set -eu

interval="${REBUILD_INTERVAL:-86400}"
port="${SERVER_PORT:-8080}"

case "$interval" in
  *[!0-9]*|'') echo "REBUILD_INTERVAL must be a positive number of seconds." >&2; exit 1 ;;
esac

if [ "$interval" -eq 0 ]; then
  echo "REBUILD_INTERVAL must be greater than zero." >&2
  exit 1
fi

build_site() {
  if bundle exec ruby ./scaffold.rb; then
    touch ./_output/.ready
    echo "[builder] Build completed at $(date -u +%Y-%m-%dT%H:%M:%SZ)."
  else
    echo "[builder] Build failed. Serving the previous successful output." >&2
  fi
}

build_site

while true; do
  sleep "$interval"
  build_site
done &

rebuild_pid=$!
trap 'kill "$rebuild_pid" 2>/dev/null || true; exit 0' INT TERM

exec busybox httpd -f -p "$port" -h ./_output
