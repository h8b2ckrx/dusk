#!/usr/bin/env bash
# Reads the corner radii GTK3 computes for sample widgets (tests/headless/
# gtk3_probe.py), with our gtk3.css and your GTK theme, but with its own
# config folder: your ~/.config/gtk-3.0/gtk.css isn't involved. No window is
# shown (GTK3 styles widgets without displaying them).
#
# Usage: tools/probe-gtk3.sh OUTDIR [stock]
#   stock: without our gtk.css, to see Yaru's own values.
# Writes OUTDIR/gtk3.json.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
STOCK="${2:-}"
THEME=$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")

"$REPO/build.sh" > /dev/null

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/gtk-3.0"
[ "$STOCK" = stock ] || ln -s "$REPO/build/gtk3.css" "$ROOT/gtk-3.0/gtk.css"
rm -f "$OUT/gtk3.json"

XDG_CONFIG_HOME="$ROOT" GTK_THEME="$THEME" timeout 30 \
  python3 "$REPO/tests/headless/gtk3_probe.py" "$OUT" > "$OUT/probe.log" 2>&1 || true

[ -s "$OUT/gtk3.json" ]
