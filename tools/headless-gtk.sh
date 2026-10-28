#!/usr/bin/env bash
# Runs tests/headless/gtk4_probe.py in a throwaway session isolated from your
# desktop (its own settings, session bus and data folders), with a headless
# GNOME Shell as the display. The probe builds sample libadwaita widgets and
# records the corner radii GTK draws for them.
#
# Usage: tools/headless-gtk.sh OUTDIR [dark|light] [stock]
#   stock: without our gtk.css, to see libadwaita's own values.
# Uses your current GTK theme name (it picks libadwaita's Yaru accent).
# Writes OUTDIR/gtk4.json, OUTDIR/gtk4.png and OUTDIR/shell.log.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
SCHEME="${2:-dark}"
STOCK="${3:-}"
THEME=$(gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'")

"$REPO/build.sh" > /dev/null

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
export XDG_CONFIG_HOME="$ROOT/config" XDG_DATA_HOME="$ROOT/data"
export XDG_CACHE_HOME="$ROOT/cache" XDG_STATE_HOME="$ROOT/state"
mkdir -p "$XDG_CONFIG_HOME/gtk-4.0"
[ "$STOCK" = stock ] || ln -s "$REPO/build/gtk4.css" "$XDG_CONFIG_HOME/gtk-4.0/gtk.css"
rm -f "$OUT/gtk4.json"

export DUSK_OUT="$OUT" DUSK_SCHEME="$SCHEME" DUSK_THEME="$THEME" DUSK_REPO="$REPO"
export DUSK_DISPLAY="dusk-gtk-$$"
dbus-run-session -- bash -c '
  gsettings set org.gnome.shell disable-user-extensions true
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$DUSK_SCHEME"
  gsettings set org.gnome.desktop.interface gtk-theme "$DUSK_THEME"
  gnome-shell --headless --virtual-monitor 1280x800 --mode=ubuntu --no-x11 \
    --wayland-display "$DUSK_DISPLAY" > "$DUSK_OUT/shell.log" 2>&1 &
  pid=$!
  for _ in $(seq 1 60); do
    [ -S "$XDG_RUNTIME_DIR/$DUSK_DISPLAY" ] && break
    sleep 0.5
  done
  sleep 2
  WAYLAND_DISPLAY="$DUSK_DISPLAY" GDK_BACKEND=wayland timeout 60 \
    python3 "$DUSK_REPO/tests/headless/gtk4_probe.py" "$DUSK_OUT" \
    > "$DUSK_OUT/probe.log" 2>&1 || true
  kill "$pid" 2> /dev/null
  wait "$pid" 2> /dev/null
' > /dev/null 2>&1 || true

[ -s "$OUT/gtk4.json" ]
