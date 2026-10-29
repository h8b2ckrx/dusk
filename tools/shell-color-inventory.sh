#!/usr/bin/env bash
# Prints docs/inventory-shell-colors.tsv (design decision 22): every color rule
# of the installed Yaru 26.04 Shell stylesheets for the floating surfaces in
# scope, dark and light, with Yaru 24.04's value (docs/reference/), from
# tools/color-inventory.py and tools/color-inventory-table.py.
#
# Usage: tools/shell-color-inventory.sh > docs/inventory-shell-colors.tsv
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The floating surfaces (design §4), by their selectors' first compound, plus
# the general controls drawn on them.
SCOPE='^(\.(popup-|quick-|message|notification-banner|notification-button|calendar|events-|world-clocks|weather|datemenu|modal-dialog|prompt-dialog|end-session|run-dialog|audio-device|polkit|dialog-list|osd-|pad-osd|resize-popup|workspace-switcher|ws-switcher|switcher-|cycler|dash-label|window-caption|screenshot-ui-(panel|tooltip|type-button|capture-button|close-button|shot-cast|show-pointer)|candidate-|background-app|keyboard-brightness|device-subtitle|shell-link|button|flat|default|icon-button|check-box|toggle-switch|slider)|StEntry|StScrollBar)'
# Out of scope (design §3): the lock and login screens, the top bar, the
# dock, Looking Glass, what Blur my Shell styles, the on-screen keyboard, and
# the dialog buttons dusk already styles like 24.04 (design §6).
EXCLUDE='unlock-dialog|login-dialog|#panel|#dash|#LookingGlass|lg-dialog|app-folder|search-section|keyboard-key|word-suggestions|emoji-|modal-dialog-button'

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
  /org/gnome/shell/theme/Yaru/gnome-shell-dark.css > "$WORK/stock-dark.css"
gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
  /org/gnome/shell/theme/Yaru/gnome-shell.css > "$WORK/stock-light.css"

for mode in dark light; do
  "$REPO/tools/color-inventory.py" "$WORK/stock-$mode.css" \
    "$REPO/docs/reference/yaru-24.04-gnome-shell-$mode.css" \
    --scope "$SCOPE" --exclude "$EXCLUDE" \
    --palette "$REPO/docs/inventory-shell-colors-palette-$mode.tsv" \
    --renames "$REPO/docs/inventory-shell-colors-renames.tsv" > "$WORK/$mode.tsv"
done

"$REPO/tools/color-inventory-table.py" "$WORK/dark.tsv" "$WORK/light.tsv" \
  "Shell pop-up colors (design decision 22), made with tools/shell-color-inventory.sh: don't edit by hand." \
  "26.04: the installed Yaru Shell stylesheets. 24.04: docs/reference/. Scope, exclusions: the script." \
  "Palettes: docs/inventory-shell-colors-palette-{dark,light}.tsv. Renames: docs/inventory-shell-colors-renames.tsv."
