#!/usr/bin/env bash
# Compiles Yaru 24.04's GNOME Shell stylesheets (dark and light, default
# accent) from the ubuntu/yaru source at the Ubuntu 24.04 release tag, the way
# Yaru's own build (gnome-shell/src/meson.build) does: every `url(` in the
# Sass sources goes through `yaru_url_handler(`, and gnome-shell.scss.in is
# filled in per variant. It only reads the clone and runs nothing from it.
# dusk keeps the output in docs/reference/ (decision 22).
#
# Usage: tools/yaru-2404-shell.sh OUTDIR
# Writes OUTDIR/gnome-shell-dark.css and OUTDIR/gnome-shell-light.css.
set -euo pipefail

TAG=24.04.3-0ubuntu1
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
SASSC="${SASSC:-sassc}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git clone -q --depth 1 --branch "$TAG" --filter=blob:none --sparse \
  https://github.com/ubuntu/yaru "$WORK/yaru" 2> /dev/null
git -C "$WORK/yaru" sparse-checkout set gnome-shell/src common
SRC="$WORK/yaru/gnome-shell/src"
BUILD="$WORK/build"

# The Sass sources, with `url(` rewritten as Yaru's build does.
(cd "$SRC" && find . -name '*.scss') | while read -r f; do
  mkdir -p "$BUILD/$(dirname "$f")"
  sed "s,[[:space:]]*url[[:space:]]*(, yaru_url_handler(,g;" "$SRC/$f" > "$BUILD/$f"
done

# Yaru's build passes the colorable asset names as a list.
assets=$(cd "$SRC/colorable-assets" && ls -- *.svg | sed "s/.*/'&'/" | paste -sd, -)

for variant in dark light; do
  dark=false
  [ "$variant" = dark ] && dark=true
  sed -e "s/@DarkVariant@/$dark/" -e "s/@YaruVariant@/$variant/" \
    -e "s/@UseGResource@/true/" -e "s/@HighContrast@/false/" \
    -e "s/@Colors@/colors/" -e "s/@ColorableAssets@/[$assets]/" \
    "$SRC/gnome-shell.scss.in" > "$BUILD/gnome-shell-$variant.scss"
  "$SASSC" --style expanded -I "$BUILD" -I "$WORK/yaru/common" "$BUILD/gnome-shell-$variant.scss" \
    "$OUT/gnome-shell-$variant.css" 2> "$WORK/sassc-$variant.log" \
    || { cat "$WORK/sassc-$variant.log" >&2; exit 1; }
done
