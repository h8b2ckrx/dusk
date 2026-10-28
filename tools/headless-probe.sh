#!/usr/bin/env bash
# Starts a throwaway headless GNOME Shell, isolated from your desktop (its own
# settings, session bus and data folders; only dusk@local and the test-only
# tests/headless/dusk-probe@local enabled). The probe opens sample modal
# dialogs, measures them and screenshots them, then the Shell is stopped.
#
# Usage: tools/headless-probe.sh OUTDIR [dark|light]
# Writes OUTDIR/result.json, OUTDIR/dialog-{1,2,3}.png and OUTDIR/shell.log.
# Exits 0 if the probe finished, 1 otherwise (see OUTDIR/error.txt).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
SCHEME="${2:-dark}"

"$REPO/build.sh" > /dev/null

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
export XDG_CONFIG_HOME="$ROOT/config" XDG_DATA_HOME="$ROOT/data"
export XDG_CACHE_HOME="$ROOT/cache" XDG_STATE_HOME="$ROOT/state"
mkdir -p "$XDG_DATA_HOME/gnome-shell/extensions"
ln -s "$REPO/extension" "$XDG_DATA_HOME/gnome-shell/extensions/dusk@local"
ln -s "$REPO/tests/headless/dusk-probe@local" "$XDG_DATA_HOME/gnome-shell/extensions/dusk-probe@local"
rm -f "$OUT/done" "$OUT/error.txt"

export DUSK_PROBE_OUT="$OUT" DUSK_SCHEME="$SCHEME"
dbus-run-session -- bash -c '
  gsettings set org.gnome.shell enabled-extensions "[\"dusk@local\", \"dusk-probe@local\"]"
  # The ubuntu session mode would also load these; they are not under test.
  gsettings set org.gnome.shell disabled-extensions "[\"ubuntu-dock@ubuntu.com\", \"ubuntu-appindicators@ubuntu.com\", \"ding@rastersoft.com\", \"tiling-assistant@ubuntu.com\", \"snapd-prompting@canonical.com\", \"snapd-search-provider@canonical.com\", \"web-search-provider@ubuntu.com\"]"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-$DUSK_SCHEME"
  gsettings set org.gnome.desktop.interface accent-color slate
  gnome-shell --headless --virtual-monitor 1280x800 --mode=ubuntu --no-x11 \
    > "$DUSK_PROBE_OUT/shell.log" 2>&1 &
  pid=$!
  for _ in $(seq 1 60); do
    [ -f "$DUSK_PROBE_OUT/done" ] && break
    sleep 0.5
  done
  kill "$pid" 2> /dev/null
  wait "$pid" 2> /dev/null
' > /dev/null 2>&1 || true

[ "$(cat "$OUT/done" 2> /dev/null)" = ok ]
