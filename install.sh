#!/usr/bin/env bash
# Installs dusk: builds the CSS, then symlinks it into GTK's user config and
# Shell's extension folder. Safe to run again. Everything it changes is
# recorded in a state file so uninstall.sh can undo exactly that.
#
# Overridable for tests: SASSC (see build.sh), FLATPAK.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID=dusk@local
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dusk"
STATE="$STATE_DIR/install.state"
FLATPAK="${FLATPAK:-flatpak}"

# Build first: if sassc is missing or a stylesheet doesn't compile, stop
# before touching anything.
"$REPO/build.sh" > /dev/null

# record FIELD...: append one tab-separated record, unless it's already there.
record() {
  local line
  line=$(printf '%s\t' "$@")
  line="${line%$'\t'}"
  grep -qxF -- "$line" "$STATE" || printf '%s\n' "$line" >> "$STATE"
}

# missing_dirs DIR: DIR and its missing ancestors, outermost first.
missing_dirs() {
  local d="$1"
  while [ ! -d "$d" ]; do
    echo "$d"
    d=$(dirname "$d")
  done | tac
}

# ensure_dir DIR: create DIR, recording every directory we had to create.
ensure_dir() {
  local d
  while IFS= read -r d; do
    mkdir "$d"
    record dir "$d"
  done < <(missing_dirs "$1")
}

# backup_path TARGET: a free timestamped backup name next to TARGET.
backup_path() {
  local b
  b="$1.dusk-backup-$(date +%Y%m%d-%H%M%S)"
  while [ -e "$b" ] || [ -L "$b" ]; do b="$b-1"; done
  echo "$b"
}

# link TARGET SOURCE: make TARGET a symlink to SOURCE, backing up whatever
# was there.
link() {
  local target="$1" src="$2" backup
  ensure_dir "$(dirname "$target")"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
    record link "$target"
    return
  fi
  if [ -L "$target" ] && grep -qxF -- "$(printf 'link\t%s' "$target")" "$STATE"; then
    # Our own link from an earlier install, e.g. before the repo moved.
    rm "$target"
  elif [ -e "$target" ] || [ -L "$target" ]; then
    backup=$(backup_path "$target")
    mv "$target" "$backup"
    record backup "$target" "$backup"
  fi
  ln -s "$src" "$target"
  record link "$target"
}

# The state file comes first, so it can record the directories made for it.
state_dirs=$(missing_dirs "$STATE_DIR")
mkdir -p "$STATE_DIR"
touch "$STATE"
while IFS= read -r d; do
  [ -n "$d" ] && record dir "$d"
done <<< "$state_dirs"

link "$CONFIG/gtk-4.0/gtk.css" "$REPO/build/gtk4.css"
link "$CONFIG/gtk-3.0/gtk.css" "$REPO/build/gtk3.css"
link "$DATA/gnome-shell/extensions/$UUID" "$REPO/extension"

# Flatpak apps can read our gtk.css only if the config folders and the
# symlinks' real target (build/) are exposed to them.
if command -v "$FLATPAK" > /dev/null; then
  overrides="$DATA/flatpak/overrides/global"
  if ! grep -q '^flatpak' "$STATE"; then
    ensure_dir "$(dirname "$overrides")"
    if [ -e "$overrides" ]; then
      backup=$(backup_path "$overrides")
      cp -p "$overrides" "$backup"
      record flatpak "$backup"
    else
      record flatpak NONE
    fi
  fi
  "$FLATPAK" override --user \
    --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem="$REPO/build:ro"
fi

echo "Linked:"
echo "  $CONFIG/gtk-4.0/gtk.css -> $REPO/build/gtk4.css"
echo "  $CONFIG/gtk-3.0/gtk.css -> $REPO/build/gtk3.css"
echo "  $DATA/gnome-shell/extensions/$UUID -> $REPO/extension"

# On Wayland, Shell only discovers a new extension at login. Within the
# session it was installed in (or after an uninstall), it already knows it.
if gnome-extensions enable "$UUID" 2> /dev/null \
  && gnome-extensions info "$UUID" 2> /dev/null | grep -q 'State: ACTIVE'; then
  echo "Extension $UUID enabled. Restart apps to pick up GTK changes;"
  echo "run tools/shell-reload.sh to reload the Shell stylesheet."
else
  echo "Shell hasn't loaded $UUID yet."
  echo "Log out and back in once, then run ./install.sh again."
fi
