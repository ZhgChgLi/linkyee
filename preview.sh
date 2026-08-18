#!/usr/bin/env bash
# preview.sh — build linkyee with a chosen theme and serve locally
#
# Usage:
#   ./preview.sh                  # build with the theme currently set in config.yml
#   ./preview.sh <theme-name>     # temporarily switch to <theme-name>, build, serve;
#                                 # restores config.yml on Ctrl-C
#
# Requires: bundler + ruby (for the build), and python3 (or ruby) for the static server.

set -euo pipefail

THEME="${1:-}"
PORT="${PORT:-8080}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$ROOT/config.yml"
BACKUP="$ROOT/config.yml.preview-backup"

if [ ! -f "$CONFIG" ]; then
  echo "Error: $CONFIG not found." >&2
  exit 1
fi

restore_config() {
  if [ -f "$BACKUP" ]; then
    mv "$BACKUP" "$CONFIG"
    echo
    echo "Restored config.yml."
  fi
}

cleanup() {
  trap - INT TERM EXIT
  for pid in "${WATCH_PID:-}" "${SERVER_PID:-}"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  restore_config
}
trap cleanup INT TERM EXIT

if [ -n "$THEME" ]; then
  if [ ! -d "$ROOT/themes/$THEME" ]; then
    echo "Error: themes/$THEME does not exist." >&2
    echo "Available themes:" >&2
    ls -1 "$ROOT/themes/" | sed 's/^/  - /' >&2
    exit 1
  fi
  cp "$CONFIG" "$BACKUP"
  # Replace the first 'theme:' line. Works for both 'theme: x' and 'theme:x'.
  if command -v gsed >/dev/null 2>&1; then
    gsed -i -E "0,/^theme:.*/s//theme: $THEME/" "$CONFIG"
  else
    # macOS BSD sed has no -i in-place GNU style; use a portable two-step.
    awk -v t="$THEME" 'BEGIN{done=0} /^theme:/ && !done {print "theme: " t; done=1; next} {print}' "$CONFIG" > "$CONFIG.tmp"
    mv "$CONFIG.tmp" "$CONFIG"
  fi
  echo "Switched theme to: $THEME"
fi

build_site() {
  ( cd "$ROOT" && bundle exec ruby ./scaffold.rb )
}

echo "Building site..."
build_site

WATCH_PATHS=(themes plugins assets config.yml scaffold.rb)
[ -d "$ROOT/locales" ] && WATCH_PATHS+=(locales)

start_watcher() {
  if command -v fswatch >/dev/null 2>&1; then
    (
      cd "$ROOT"
      # -o emits one line per batch of events; -l 0.3s coalesces bursts.
      fswatch -o -l 0.3 "${WATCH_PATHS[@]}" 2>/dev/null | while read -r _; do
        echo
        echo "[watch] change detected, rebuilding..."
        if build_site; then
          echo "[watch] rebuilt — refresh the browser."
        else
          echo "[watch] build failed. fix the error above and save again." >&2
        fi
      done
    ) &
    WATCH_PID=$!
    echo "Watching for changes (fswatch): ${WATCH_PATHS[*]}"
  else
    (
      # Watcher must not inherit `set -e` from the parent — find may
      # legitimately return non-zero on macOS and we don't want that to
      # silently kill the loop.
      set +e
      cd "$ROOT"
      REF="$(mktemp)"
      touch "$REF"
      trap 'rm -f "$REF"' EXIT
      while true; do
        sleep 1
        # `find -newer REF` is O(changed files) — way faster than mtime-hash.
        CHANGED="$(find "${WATCH_PATHS[@]}" -type f -newer "$REF" 2>/dev/null | head -1)"
        if [ -n "$CHANGED" ]; then
          echo
          echo "[watch] change detected, rebuilding..."
          touch "$REF"
          if build_site; then
            echo "[watch] rebuilt — refresh the browser."
          else
            echo "[watch] build failed. fix the error above and save again." >&2
          fi
        fi
      done
    ) &
    WATCH_PID=$!
    echo "Watching for changes (polling, install fswatch for instant reload): ${WATCH_PATHS[*]}"
  fi
}

start_watcher

echo
echo "Preview: http://localhost:$PORT"
echo "Press Ctrl-C to stop preview."
echo

cd "$ROOT/_output"
# Serve with no-cache headers so a browser refresh always picks up the
# rebuilt CSS/JS/HTML (otherwise auto-rebuild looks broken: file changes
# but the browser keeps serving the cached response).
if command -v python3 >/dev/null 2>&1; then
  python3 -c '
import http.server, socketserver, sys
class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()
    def log_message(self, *a, **kw): pass
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", int(sys.argv[1])), NoCacheHandler) as s:
    s.serve_forever()
' "$PORT" >/dev/null 2>&1 &
elif command -v ruby >/dev/null 2>&1; then
  ruby -e '
require "webrick"
port = ARGV[0].to_i
s = WEBrick::HTTPServer.new(Port: port, DocumentRoot: ".",
  AccessLog: [], Logger: WEBrick::Log.new(File::NULL))
s.config[:HTTPVersion] = WEBrick::HTTPVersion.new("1.1")
s.mount_proc "/" do |req, res|
  WEBrick::HTTPServlet::FileHandler.new(s, ".").service(req, res)
  res["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
  res["Pragma"] = "no-cache"
  res["Expires"] = "0"
end
trap("INT") { s.shutdown }
s.start
' "$PORT" >/dev/null 2>&1 &
else
  echo "Error: need python3 or ruby to serve." >&2
  exit 1
fi
SERVER_PID=$!
wait "$SERVER_PID"
