#!/usr/bin/env bash
# Reloads dusk's Shell stylesheet (disable + enable the extension), then prints
# any Shell log lines about it since, and checks Shell reports the extension
# ACTIVE. Prints "clean" and exits 0 if all is well, exits 1 otherwise.
set -euo pipefail

UUID=dusk@local
since=$(date '+%Y-%m-%d %H:%M:%S')

# The extension's state as Shell reports it (ACTIVE, INACTIVE, ...).
state() {
  gnome-extensions info "$UUID" | sed -n 's/^ *State: //p'
}

# wait_for STATE: give Shell up to 5 seconds to get there.
wait_for() {
  local _
  for _ in $(seq 1 20); do
    [ "$(state)" = "$1" ] && return 0
    sleep 0.25
  done
  return 1
}

# Shell ignores an enable that lands while it is still disabling, leaving the
# extension "Enabled: Yes" but INACTIVE (seen live), and a plain enable can't
# fix that. So wait for each state change, and try once more if needed.
for _ in 1 2; do
  gnome-extensions disable "$UUID"
  wait_for INACTIVE || true
  gnome-extensions enable "$UUID"
  wait_for ACTIVE && break
done
sleep 1

lines=$(journalctl --user -b _COMM=gnome-shell --since "$since" -o cat \
  | grep -iE 'dusk|stylesheet|css' || true)

if [ -n "$lines" ]; then
  echo "$lines"
  exit 1
fi

current=$(state)
if [ "$current" != ACTIVE ]; then
  echo "$UUID is not active (State: ${current:-unknown}); its stylesheet is not loaded." >&2
  echo "If it was just installed, log out and back in once." >&2
  exit 1
fi
echo clean
