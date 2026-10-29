# Shared helpers for tests/test_*.sh. Sourced by tests/run.sh.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "  $*" >&2
  return 1
}

assert_eq() {
  [ "$1" = "$2" ] || fail "expected '$2', got '$1'${3:+ ($3)}"
}

# assert_contains FILE TEXT: FILE contains TEXT literally.
assert_contains() {
  grep -qF -- "$2" "$1" || fail "$1 does not contain: $2"
}

# assert_not_contains FILE TEXT: FILE does not contain TEXT literally.
assert_not_contains() {
  ! grep -qF -- "$2" "$1" || fail "$1 contains: $2"
}

# assert_symlink_to LINK TARGET: LINK is a symlink whose target is TARGET.
assert_symlink_to() {
  [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] || fail "$1 is not a symlink to $2"
}

# assert_missing PATH: nothing exists at PATH (not even a dangling symlink).
assert_missing() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1 exists"
}

# gtk_theme: the GTK theme in use, e.g. Yaru-sage-dark.
gtk_theme() {
  gsettings get org.gnome.desktop.interface gtk-theme | tr -d "'"
}

# stock_key: a short hash of what the headless results depend on outside the
# repo: the installed Shell, GTK, libadwaita and Yaru, and the theme in use.
# Probe caches include it, so an update makes them run again.
stock_key() {
  { gtk_theme
    stat -L -c '%n %s %Y' /usr/bin/gnome-shell /usr/lib/gnome-shell/libshell-*.so \
      /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
      /usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com/metadata.json \
      /usr/lib/x86_64-linux-gnu/libadwaita-1.so.0 /usr/lib/x86_64-linux-gnu/libgtk-4.so.1 \
      /usr/lib/x86_64-linux-gnu/libgtk-3.so.0 "/usr/share/themes/$(gtk_theme)"/gtk-*/gtk.gresource \
      2> /dev/null
  } | sha1sum | cut -c1-16
}

# assert_inventory_current TSV CSS [inventory options]: TSV still lists
# exactly CSS's radius rules, in order (selector, property, value). After an
# update to the stock stylesheet it may not: dusk would then keep forcing old
# values on rules that changed.
assert_inventory_current() {
  local tsv="$1" css="$2" d
  shift 2
  d=$(diff <(grep -v '^# ' "$tsv" | grep . | cut -f1-3) \
    <("$REPO/tools/radius-inventory.py" "$css" --include-zero --source-order "$@" \
      | awk -F'\t' '{ sub(/^INVALID:/, "", $1); print $3 "\t" $2 "\t" $1 }')) \
    || fail "$(basename "$tsv") no longer matches the installed stylesheet (< inventory, > installed):
$(echo "$d" | head -20)
See README, 'Updating after a GNOME, Yaru or libadwaita update'."
}
