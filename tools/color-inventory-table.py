#!/usr/bin/env python3
"""Merge the dark and light color inventories (tools/color-inventory.py
output) into docs/inventory-shell-colors.tsv (design decision 22).

Usage: color-inventory-table.py DARK.tsv LIGHT.tsv [HEADER_LINE...]

Prints, after the header lines (as `# ` comments), one row per mode and
selector and property, in the stock stylesheet's order (dark's, with
light-only rows after the row they follow in light):
    mode<TAB>selector<TAB>property<TAB>26.04 value<TAB>24.04 value<TAB>source<TAB>token<TAB>chunk
mode is `both` when both modes have the row with the same values. token
names the row (its selector and property, as a slug; tokens are per row so
both modes share them). chunk: 1 menus and quick settings (and the general
controls they use), 2 notifications and the date menu, 3 dialogs, OSDs,
switchers, tooltips and the screenshot panel, 0 rows kept at their stock
value (always on).
"""
import re
import sys

# First match wins; tested against the selector's first compound.
CHUNKS = [
    (2, r"^\.(message|notification|calendar|events-|world-clocks|weather|datemenu|shell-link)"),
    (3, r"^\.(modal-dialog|prompt-dialog|end-session|run-dialog|audio-device|polkit|dialog-list|osd-|pad-osd|"
        r"resize-popup|workspace-switcher|ws-switcher|switcher-|cycler|dash-label|window-caption|"
        r"screenshot-ui-|candidate-)"),
    (1, r"."),
]


def rows(path):
    out = []
    for line in open(path):
        if line.strip() and not line.startswith("# "):
            out.append(line.rstrip("\n").split("\t"))
    return out


def slug(selector, prop):
    return re.sub(r"[^a-z0-9]+", "-", f"{selector} {prop}".lower()).strip("-")


def chunk(selector, source):
    if source == "keep":
        return 0
    return next(n for n, pattern in CHUNKS if re.search(pattern, selector))


def main():
    dark, light = rows(sys.argv[1]), rows(sys.argv[2])
    light_by_key = {(r[0], r[1]): r for r in light}
    dark_keys = {(r[0], r[1]) for r in dark}
    # Light-only rows go after the row they follow in light.
    after = {}
    previous = None
    for r in light:
        key = (r[0], r[1])
        if key in dark_keys:
            previous = key
        else:
            after.setdefault(previous, []).append(r)

    for line in sys.argv[3:]:
        print(f"# {line}")
    print("# mode\tselector\tproperty\t26.04 value\t24.04 value\tsource\ttoken\tchunk")

    def emit(mode, r):
        print("\t".join([mode, *r[:5], slug(r[0], r[1]), str(chunk(r[0], r[4]))]))

    for r in after.get(None, []):
        emit("light", r)
    for r in dark:
        key = (r[0], r[1])
        other = light_by_key.get(key)
        if other == r:
            emit("both", r)
        else:
            emit("dark", r)
            if other:
                emit("light", other)
        for extra in after.get(key, []):
            emit("light", extra)
    return 0


if __name__ == "__main__":
    sys.exit(main())
