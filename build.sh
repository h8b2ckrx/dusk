#!/usr/bin/env bash
# Compiles src/ into the CSS files dusk installs:
#   build/gtk4.css, build/gtk3.css,
#   extension/theme/dusk-dark.css, extension/theme/dusk-light.css (dusk's
#   Shell theme, with the images it uses)
# Set SASSC to use a different sassc binary.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

SASSC="${SASSC:-sassc}"
if ! command -v "$SASSC" > /dev/null; then
  echo "build.sh: '$SASSC' not found. Install it with: sudo apt install sassc" >&2
  exit 1
fi

# compile SRC OUT: write OUT only if SRC compiles, so a failed build never
# leaves a half-written stylesheet behind. The temporary file sits next to OUT
# (a hidden name, which install.sh never links), so the final rename is
# atomic: an app starting mid-build reads the old file or the new one.
compile() {
  local tmp
  tmp=$(mktemp "$(dirname "$2")/.$(basename "$2").XXXXXX")
  if ! "$SASSC" --style expanded -I src "$1" > "$tmp"; then
    rm -f "$tmp"
    echo "build.sh: failed to compile $1" >&2
    exit 1
  fi
  mv "$tmp" "$2"
  chmod 644 "$2"
  echo "$2"
}

# compile_shell_theme MODE: dusk's Shell theme (design 2026-10-30) from the
# Yaru copy in src/shell-theme/yaru, to extension/theme/dusk-MODE.css
# (tools/build-shell-theme.sh).
compile_shell_theme() {
  tools/build-shell-theme.sh src/shell-theme/yaru "$1" "extension/theme/dusk-$1.css"
  echo "extension/theme/dusk-$1.css"
}

mkdir -p build extension extension/theme
compile src/gtk4.scss build/gtk4.css
compile src/gtk3.scss build/gtk3.css
# Shell would load an extension stylesheet left from an older build on top
# of dusk's theme.
rm -f extension/stylesheet-dark.css extension/stylesheet-light.css
compile_shell_theme dark
compile_shell_theme light
# The images the theme uses, next to it.
cp src/shell-theme/yaru/{calendar-today,calendar-today-light,gnome-shell-start,workspace-placeholder}.svg extension/theme/
