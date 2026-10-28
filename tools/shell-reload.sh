#!/usr/bin/env bash
# Reloads dusk's Shell stylesheet (disable + enable the extension), then prints
# any Shell log lines about it since. Prints "clean" and exits 0 if there are
# none, exits 1 otherwise.
set -euo pipefail

UUID=dusk@local
since=$(date '+%Y-%m-%d %H:%M:%S')

gnome-extensions disable "$UUID"
gnome-extensions enable "$UUID"
sleep 1

lines=$(journalctl --user -b _COMM=gnome-shell --since "$since" -o cat \
  | grep -iE 'dusk|stylesheet|css' || true)

if [ -n "$lines" ]; then
  echo "$lines"
  exit 1
fi
echo clean
