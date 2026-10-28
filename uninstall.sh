#!/usr/bin/env bash
# Undoes exactly what install.sh recorded: disables the extension, removes our
# symlinks, restores backups and the Flatpak overrides file, and removes the
# directories install.sh created (if they're empty).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID=dusk@local
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dusk"
STATE="$STATE_DIR/install.state"

if [ ! -f "$STATE" ]; then
  echo "dusk is not installed."
  exit 0
fi

gnome-extensions disable "$UUID" 2> /dev/null || true

# Read the records, then drop the state file so its directory can go too.
mapfile -t records < "$STATE"
rm -f "$STATE"
rmdir "$STATE_DIR" 2> /dev/null || true

# 1. Our symlinks, only if they still point into this repo.
for r in "${records[@]}"; do
  IFS=$'\t' read -r kind a _ <<< "$r"
  if [ "$kind" = link ] && [ -L "$a" ] && [[ "$(readlink "$a")" == "$REPO"/* ]]; then
    rm "$a"
    echo "Removed $a"
  fi
done

# 2. Backups, newest first: restore one per target, list any older ones.
declare -A restored=()
leftovers=()
for ((i = ${#records[@]} - 1; i >= 0; i--)); do
  IFS=$'\t' read -r kind a b <<< "${records[i]}"
  case "$kind" in
    backup)
      [ -e "$b" ] || [ -L "$b" ] || continue
      if [ -z "${restored[$a]:-}" ] && [ ! -e "$a" ] && [ ! -L "$a" ]; then
        mv "$b" "$a"
        restored[$a]=1
        echo "Restored $a"
      else
        leftovers+=("$b")
      fi
      ;;
    flatpak)
      overrides="${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/overrides/global"
      if [ "$a" = NONE ]; then
        rm -f "$overrides"
      else
        mv "$a" "$overrides"
      fi
      echo "Restored Flatpak overrides"
      ;;
  esac
done

# 3. Directories we created, deepest first, only if empty.
for ((i = ${#records[@]} - 1; i >= 0; i--)); do
  IFS=$'\t' read -r kind a _ <<< "${records[i]}"
  if [ "$kind" = dir ]; then
    rmdir "$a" 2> /dev/null || true
  fi
done

if [ ${#leftovers[@]} -gt 0 ]; then
  echo "Older backups left in place:"
  printf '  %s\n' "${leftovers[@]}"
fi
echo "dusk uninstalled. Log out and back in (or restart apps) to see stock Ubuntu."
