#!/usr/bin/env bash
# Compiles src/ into the four CSS files dusk installs:
#   build/gtk4.css, build/gtk3.css,
#   extension/stylesheet-dark.css, extension/stylesheet-light.css
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

mkdir -p build extension
compile src/gtk4.scss build/gtk4.css
compile src/gtk3.scss build/gtk3.css
compile src/shell-dark.scss extension/stylesheet-dark.css
compile src/shell-light.scss extension/stylesheet-light.css
