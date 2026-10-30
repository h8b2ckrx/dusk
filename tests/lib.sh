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

# probe_dir SCHEME [dock]: a finished probe run for the current code, reused
# across tests while src/, extension/, tests/headless/, the probe tool and the
# installed system (stock_key) are unchanged.
# "dock" also loads Ubuntu Dock, laid out like the owner's (bottom, not
# extended, shrink); "accent" picks the blue accent instead of slate;
# "default" also loads Ubuntu Dock and sets color-scheme to `default`, which is
# what Quick Settings' Dark Style toggle writes for light mode.
probe_dir() {
  local key out variant="${2:-}"
  key=$({ cd "$REPO" && find src extension tests/headless tools/headless-probe.sh -type f \
    -print0 | sort -z | xargs -0 sha1sum; stock_key; } \
    | sha1sum | cut -c1-16)
  out="${TMPDIR:-/tmp}/dusk-probe-$key-$1${variant:+-$variant}"
  if [ "$(cat "$out/done" 2> /dev/null)" != ok ]; then
    local extra="" settings=""
    if [ "$variant" = accent ]; then
      settings="org.gnome.desktop.interface accent-color blue"
    fi
    if [ "$variant" = default ]; then
      extra=ubuntu-dock@ubuntu.com
      settings="org.gnome.desktop.interface color-scheme default"
    fi
    if [ "$variant" = dock ]; then
      extra=ubuntu-dock@ubuntu.com
      settings="org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM"
      settings+=";org.gnome.shell.extensions.dash-to-dock extend-height false"
      settings+=";org.gnome.shell.extensions.dash-to-dock custom-theme-shrink true"
    fi
    DUSK_EXTRA_EXTENSIONS="$extra" DUSK_GSETTINGS="$settings" \
      "$REPO/tools/headless-probe.sh" "$out" "$1" > /dev/null 2>&1 \
      || fail "headless probe failed ($1 $variant): $(cat "$out/error.txt" 2> /dev/null)"
  fi
  echo "$out"
}

# The stylesheet Shell loads for Yaru (dark), extracted for the cascade check.
yaru_dark_css() {
  local css; css=$(mktemp --suffix=.css)
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    /org/gnome/shell/theme/Yaru/gnome-shell-dark.css > "$css"
  echo "$css"
}

# The light one (Shell loads it in light mode).
yaru_light_css() {
  local css; css=$(mktemp --suffix=.css)
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    /org/gnome/shell/theme/Yaru/gnome-shell.css > "$css"
  echo "$css"
}

# theme_css MODE: dusk's Shell theme for MODE (built), the only stylesheet in
# the base slot of Shell's theme while dusk runs (design 2026-10-30).
theme_css() {
  (cd "$REPO" && ./build.sh > /dev/null)
  echo "$REPO/extension/theme/dusk-$1.css"
}

# dusk_errors LOG: the lines of a Shell log that come from dusk's own files: an
# exception's stack frames, or a warning about its theme.
dusk_errors() {
  grep -n "extensions/dusk@local/" "$1" || true
}

# empty_css: an empty stylesheet, for checks that take a second one on top.
empty_css() {
  local css; css=$(mktemp --suffix=.css)
  echo "$css"
}

