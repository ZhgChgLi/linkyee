#!/usr/bin/env bash
# screenshot-themes.sh — capture light + dark previews for every built-in theme.
#
# For each theme directory under ./themes/, this script:
#   1. Switches `theme:` in config.yml
#   2. Builds the site (bundle exec ruby ./scaffold.rb)
#   3. Captures preview-light.png + preview-dark.png via Playwright Chromium
#      at a phone-portrait viewport (420×900, --full-page)
#   4. Saves both PNGs into themes/<name>/
#   5. Restores config.yml at the end (or on Ctrl-C)
#
# Every theme gets both preview-light.png and preview-dark.png. Themes that
# read as "dark-first" by identity (e.g. terminal-retro) still ship a light
# variant — Playwright captures both color schemes regardless.
#
# Requirements: bundler + ruby (for the build) and `npx playwright` v1+
# (already available locally; install via `npm i -g playwright` if missing).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/config.yml"
BACKUP="$ROOT/config.yml.shot-backup"
VIEWPORT="420,900"

if [ ! -f "$CONFIG" ]; then
  echo "Error: $CONFIG not found." >&2
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx not found — install Node.js first (Playwright is distributed via npm)." >&2
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
  restore_config
}
trap cleanup INT TERM EXIT

cp "$CONFIG" "$BACKUP"

set_theme() {
  local theme="$1"
  if command -v gsed >/dev/null 2>&1; then
    gsed -i -E "0,/^theme:.*/s//theme: $theme/" "$CONFIG"
  else
    awk -v t="$theme" 'BEGIN{done=0} /^theme:/ && !done {print "theme: " t; done=1; next} {print}' \
      "$CONFIG" > "$CONFIG.tmp"
    mv "$CONFIG.tmp" "$CONFIG"
  fi
}

build_site() {
  ( cd "$ROOT" && bundle exec ruby ./scaffold.rb >/dev/null )
}

shoot() {
  local scheme="$1" out="$2"
  local page="$ROOT/_output/index.html"
  local default_locale
  default_locale="$(sed -n 's/.*data-default-locale="\([^"]*\)".*/\1/p' "$page" | head -n 1)"
  if [ -n "$default_locale" ] && [ -f "$ROOT/_output/$default_locale/index.html" ]; then
    page="$ROOT/_output/$default_locale/index.html"
  fi
  local url="file://$page"
  npx --yes playwright screenshot \
    --browser=chromium \
    --color-scheme="$scheme" \
    --viewport-size="$VIEWPORT" \
    --full-page \
    --wait-for-timeout=600 \
    "$url" "$out" 2>&1 | grep -vE "^(Saved as|Page loaded)" || true
}

themes=()
for d in "$ROOT"/themes/*/; do
  themes+=("$(basename "$d")")
done

echo "Capturing screenshots for ${#themes[@]} themes (viewport ${VIEWPORT}, full-page)..."
echo

for theme in "${themes[@]}"; do
  echo "▶ $theme"
  set_theme "$theme"
  build_site

  out_dir="$ROOT/themes/$theme"

  shoot light "$out_dir/preview-light.png"
  shoot dark  "$out_dir/preview-dark.png"
  echo "  preview-light.png ($(stat -f%z "$out_dir/preview-light.png" 2>/dev/null || stat -c%s "$out_dir/preview-light.png") bytes)"
  echo "  preview-dark.png  ($(stat -f%z "$out_dir/preview-dark.png" 2>/dev/null || stat -c%s "$out_dir/preview-dark.png") bytes)"
done

echo
echo "Done. ${#themes[@]} themes processed."
