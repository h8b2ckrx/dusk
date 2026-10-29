#!/usr/bin/env bash
# Undoes exactly what install.sh recorded: disables the extension and takes
# it out of Shell's extension lists, removes our symlinks, restores backups
# and the Flatpak overrides file, and removes the directories install.sh
# created (if they're empty).
#
# It never deletes the user's files: a link goes only if it still points at
# one of dusk's files, and the Flatpak overrides file is restored only if it's
# unchanged since install. A step that fails doesn't stop the others; the
# state file is then kept, so running it again finishes the job.
set -uo pipefail

UUID=dusk@local
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dusk"
STATE="$STATE_DIR/install.state"
OVERRIDES="${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/overrides/global"

if [ ! -f "$STATE" ]; then
  echo "dusk is not installed."
  exit 0
fi

failed=0
# step_failed WHAT: report a step that didn't work; the others still run.
step_failed() {
  echo "Couldn't $1." >&2
  failed=1
}

# ours LINK: LINK points at one of dusk's files, here or in an earlier repo
# location (the same test as install.sh's).
ours() {
  case "$(readlink "$1")" in
    */build/gtk4.css | */build/gtk3.css | */extension | */extension/*) return 0 ;;
  esac
  return 1
}

# drop_from_list KEY: take dusk out of one of Shell's extension lists. Shell
# puts it in disabled-extensions when it's disabled, and an uninstall without
# a running session leaves it in enabled-extensions.
drop_from_list() {
  local now new
  now=$(gsettings get org.gnome.shell "$1") || return 1
  new=$(python3 -c '
import ast, sys
now, uuid = sys.argv[1].strip(), sys.argv[2]
items = ast.literal_eval(now.removeprefix("@as").strip())
print(repr([i for i in items if i != uuid]) if uuid in items else now)
' "$now" "$UUID") || return 1
  [ "$new" = "$now" ] || gsettings set org.gnome.shell "$1" "$new"
}

gnome-extensions disable "$UUID" 2> /dev/null || true
for key in enabled-extensions disabled-extensions; do
  drop_from_list "$key" || step_failed "take $UUID out of org.gnome.shell $key"
done

mapfile -t records < "$STATE"

# 1. Our symlinks.
for r in "${records[@]}"; do
  IFS=$'\t' read -r kind a _ <<< "$r"
  if [ "$kind" = link ] && [ -L "$a" ] && ours "$a"; then
    if rm "$a"; then echo "Removed $a"; else step_failed "remove $a"; fi
  fi
done

# 2. Backups, newest first: restore one per target, list any older ones.
#    The Flatpak overrides file only if it's still exactly what install left.
flatpak_hash=""
for r in "${records[@]}"; do
  IFS=$'\t' read -r kind a _ <<< "$r"
  [ "$kind" = flatpak-hash ] && flatpak_hash="$a"
done
declare -A restored=()
leftovers=()
for ((i = ${#records[@]} - 1; i >= 0; i--)); do
  IFS=$'\t' read -r kind a b <<< "${records[i]}"
  case "$kind" in
    backup)
      [ -e "$b" ] || [ -L "$b" ] || continue
      if [ -z "${restored[$a]:-}" ] && [ ! -e "$a" ] && [ ! -L "$a" ]; then
        if mv "$b" "$a"; then
          restored[$a]=1
          echo "Restored $a"
        else
          step_failed "restore $a from $b"
        fi
      else
        leftovers+=("$b")
      fi
      ;;
    flatpak)
      [ -e "$OVERRIDES" ] || continue
      now=$(sha256sum < "$OVERRIDES" | cut -d' ' -f1)
      if [ -n "$flatpak_hash" ] && [ "$now" = "$flatpak_hash" ] \
        && { [ "$a" = NONE ] || [ -e "$a" ]; }; then
        if [ "$a" = NONE ]; then
          rm "$OVERRIDES" || step_failed "remove $OVERRIDES"
        else
          mv "$a" "$OVERRIDES" || step_failed "restore $OVERRIDES from $a"
        fi
        echo "Restored Flatpak overrides"
      else
        echo "Flatpak overrides left as they are ($OVERRIDES changed since install, or its"
        echo "backup is missing). dusk's entries in its filesystems= line are:"
        echo "  xdg-config/gtk-4.0:ro;xdg-config/gtk-3.0:ro;<the dusk repo>/build:ro"
        [ "$a" != NONE ] && [ -e "$a" ] && echo "Your file from before dusk: $a"
      fi
      ;;
  esac
done

if [ ${#leftovers[@]} -gt 0 ]; then
  echo "Older backups left in place:"
  printf '  %s\n' "${leftovers[@]}"
fi

if [ "$failed" = 1 ]; then
  echo "dusk is only partly uninstalled. Fix the above and run ./uninstall.sh again." >&2
  exit 1
fi

# 3. The state file, then the directories we created, deepest first, only if
#    empty (the state file's own directory among them).
rm -f "$STATE"
for ((i = ${#records[@]} - 1; i >= 0; i--)); do
  IFS=$'\t' read -r kind a _ <<< "${records[i]}"
  if [ "$kind" = dir ]; then
    rmdir "$a" 2> /dev/null || true
  fi
done
rmdir "$STATE_DIR" 2> /dev/null || true

echo "dusk uninstalled. Log out and back in (or restart apps) to see stock Ubuntu."
