#!/usr/bin/env bash
# Compiles dusk's Shell theme (design 2026-10-30) from a copy of Yaru's Shell
# source, the way Yaru's own build does it: every Sass file with `url(` going
# through yaru_url_handler( and the upstream default colors swapped for
# Yaru's, the template filled for MODE (images next to the file, not in
# Yaru's resource), with dusk's tokens (src/) on the include path. Writes OUT
# only if it compiles (the same atomic write as build.sh's).
#
# Usage: tools/build-shell-theme.sh YARU_DIR MODE OUT
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
yaru="$1" mode="$2" out="$3"
SASSC="${SASSC:-sassc}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(cd "$yaru" && find gnome-shell-sass upstream -name '*.scss') | while read -r f; do
  mkdir -p "$work/$(dirname "$f")"
  sed "s,[[:space:]]*url[[:space:]]*(, yaru_url_handler(,g" "$yaru/$f" \
    | sed -E "s,[\'](_default-colors([.]scss)?)[\'],'_yaru-default-colors.scss',g" > "$work/$f"
done
sed -e "s/@Variant@/$mode/" -e "s/@YaruVariant@/$mode/" -e "s/@UseGResource@/false/" \
  -e "s/@Contrast@/normal/" -e "s/@Colors@/colors/" "$yaru/gnome-shell.scss.in" > "$work/gnome-shell-$mode.scss"
tmp=$(mktemp "$(dirname "$out")/.$(basename "$out").XXXXXX")
if ! "$SASSC" --style expanded ${SASS_LINE_COMMENTS:+--line-comments} \
    -I "$work" -I "$yaru/common" -I "$work/gnome-shell-sass" -I "$work/upstream" -I "$REPO/src" \
    "$work/gnome-shell-$mode.scss" > "$tmp" 2> "$work/sassc.log"; then
  rm -f "$tmp"
  cat "$work/sassc.log" >&2
  echo "build-shell-theme.sh: failed to compile the Shell theme ($mode)" >&2
  exit 1
fi
mv "$tmp" "$out"
chmod 644 "$out"
