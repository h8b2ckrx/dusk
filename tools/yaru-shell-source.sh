#!/usr/bin/env bash
# Copies Yaru 26.04's GNOME Shell theme source into DEST, for dusk's own Shell
# theme (design 2026-10-30, §5): from ubuntu/yaru at the release the
# installed yaru-theme-gnome-shell comes from, Yaru's own Sass and images
# (gnome-shell/src), the GNOME Shell upstream Sass and images it bundles
# (gnome-shell/upstream/theme, to DEST/upstream), the Sass helpers its
# template imports (common, to DEST/common), and Yaru's licences. It only
# reads the clone and runs nothing from it.
#
# Usage: tools/yaru-shell-source.sh DEST
set -euo pipefail

TAG=26.04.5.1ubuntu
DEST="$(mkdir -p "$1" && cd "$1" && pwd)"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
if ! git clone -q --depth 1 --branch "$TAG" --filter=blob:none --sparse \
    https://github.com/ubuntu/yaru "$WORK/yaru" 2> "$WORK/clone.log"; then
  echo "yaru-shell-source.sh: couldn't fetch ubuntu/yaru at $TAG:" >&2
  cat "$WORK/clone.log" >&2
  exit 1
fi
git -C "$WORK/yaru" sparse-checkout set gnome-shell common
src="$WORK/yaru/gnome-shell/src"
upstream="$WORK/yaru/gnome-shell/upstream/theme"

find "$DEST" -mindepth 1 -delete
mkdir -p "$DEST/upstream" "$DEST/common"
cp "$src/gnome-shell.scss.in" "$src"/*.svg "$src/pad-osd.css" "$DEST/"
cp -r "$src/gnome-shell-sass" "$DEST/"
cp -r "$upstream/gnome-shell-sass" "$upstream"/*.svg "$DEST/upstream/"
cp "$WORK/yaru/common/sass-utils.scss" "$WORK/yaru/common/oklab.scss" "$DEST/common/"
cp "$WORK/yaru"/COPYING* "$WORK/yaru/LICENSE_CCBYSA" "$DEST/"
echo "$TAG" > "$DEST/TAG"
