#!/usr/bin/env python3
"""Golden records of dusk's Shell look, and checks against them (design
2026-10-30, §6: dusk's own theme has to reproduce today's look).

A record maps a key to a look: {"colors": [bg, fg, border, shadow],
"radii": [tl, tr, br, bl]}. A color is [r, g, b, a] (0-255), the winning raw
value (whitespace-normalized) when it can't be evaluated (the accent), or
null; a radius is in px, or null.

Static records predict, with the cascade model, every selector of a
stylesheet on its own element (colors.element) in the state the selector
names, and menu items also as Shell shows them under the pointer and
pressed (colors.MENU_ITEM_STATES); the key is the selector plus those extra
states, and the record keeps "selector" and "states" to rebuild it. Probe
records keep what Shell computed for every probed widget; the key is
"<state>|<cascade.describe()>|<n>", n numbering widgets with the same
description in a state.

Usage:
  golden.py record-static BASE.css OVERLAY.css OUT.json
  golden.py record-probe SNAPSHOTS.json OUT.json
  golden.py check-static THEME.css GOLDEN.json EXCEPTIONS.tsv [--overlay OVERLAY.css] [--only REGEX] [--slots LIST]
  golden.py check-probe SNAPSHOTS.json GOLDEN.json EXCEPTIONS.tsv [--only REGEX] [--slots LIST]
The checks print one line per key and slot that differs from the record
(colors by more than 2 per channel, radii by more than half a pixel) and
isn't covered by an exception, and exit 1 if any. EXCEPTIONS.tsv: key regex,
slot (bg, fg, border, shadow, radius or *), task, reason.
"""
import argparse
import json
import re
import sys

import cascade
import colors

SLOTS = ["bg", "fg", "border", "shadow"]


def _rules(css_path, origin):
    css = open(css_path).read()
    return colors.parse_color_rules(css, origin), cascade.parse_rules(css, origin)


def _norm(raw):
    return " ".join(raw.split()) if raw else None


def _predicted_look(records, color_rules, radius_rules, i):
    evaluated = colors.predict(records, color_rules)[i]
    winners = cascade.winners(records, color_rules)[i]
    look = []
    for slot in range(4):
        value = evaluated[slot]
        if value is None and winners[slot] is not None:
            look.append(_norm(winners[slot].corners[slot]))
        else:
            look.append(list(value) if value is not None else None)
    radii = [cascade.px(r) if r is not None else None for r in cascade.predict(records, radius_rules)[i]]
    return {"colors": look, "radii": radii}


def _selectors(css_path):
    color_rules, radius_rules = _rules(css_path, 1)
    seen = []
    for rule in color_rules + radius_rules:
        if rule.selector not in seen:
            seen.append(rule.selector)
    return seen


def _states(selector):
    """The extra states a selector's element is recorded in."""
    records = colors.element(selector)
    subject = records[-1]
    states = [()]
    if "popup-menu-item" in subject["classes"] and "insensitive" not in subject["pseudo"]:
        states += colors.MENU_ITEM_STATES
    return [tuple(p for p in extra if p not in subject["pseudo"]) for extra in states]


def _key(selector, extra):
    return selector + "".join(f":{p}" for p in extra)


def record_static(base_css, overlay_css):
    base_c, base_r = _rules(base_css, 0)
    over_c, over_r = _rules(overlay_css, 1) if overlay_css else ([], [])
    out = {}
    for selector in _selectors(overlay_css):
        if colors.element(selector) is None:
            continue
        for extra in _states(selector):
            records = colors.element(selector, extra)
            look = _predicted_look(records, base_c + over_c, base_r + over_r, len(records) - 1)
            out[_key(selector, extra)] = {"selector": selector, "states": list(extra), **look}
    return out


def record_probe(snapshots):
    out = {}
    for state, records in snapshots.items():
        seen = {}
        for i, record in enumerate(records):
            if record.get("colors") is None and record.get("radii") is None:
                continue
            description = cascade.describe(records, i)
            n = seen[description] = seen.get(description, -1) + 1
            out[f"{state}|{description}|{n}"] = {"colors": record.get("colors"), "radii": record.get("radii")}
    return out


def load_exceptions(path):
    rows = []
    for line in open(path):
        if line.strip() and not line.startswith("#"):
            key, slot, task, reason = line.rstrip("\n").split("\t")[:4]
            rows.append((re.compile(key), slot, task, reason))
    return rows


def _excepted(key, slot, exceptions):
    return any(pattern.search(key) and (s == "*" or s == slot) for pattern, s, _, _ in exceptions)


def _differs(a, b, tolerance):
    if a is None or b is None or isinstance(a, str) or isinstance(b, str):
        return a != b
    return any(abs(x - y) > tolerance for x, y in zip(a, b))


def _compare(key, want, got, exceptions, slots):
    lines = []
    for slot, name in enumerate(SLOTS):
        if name in slots and not _excepted(key, name, exceptions):
            a, b = (want["colors"] or [None] * 4)[slot], (got["colors"] or [None] * 4)[slot]
            if _differs(a, b, 2):
                lines.append(f"{key} {name}: recorded {a}, now {b}")
    if "radius" in slots and not _excepted(key, "radius", exceptions):
        a, b = want["radii"] or [None] * 4, got["radii"] or [None] * 4
        if any(abs(x - y) > 0.5 if not (x is None or y is None) else x != y for x, y in zip(a, b)):
            lines.append(f"{key} radius: recorded {a}, now {b}")
    return lines


def check_static(theme_css, golden, exceptions, only=None, slots=None, overlay_css=None):
    slots = slots or SLOTS + ["radius"]
    theme_c, theme_r = _rules(theme_css, 0)
    over_c, over_r = _rules(overlay_css, 1) if overlay_css else ([], [])
    lines = []
    for key, want in golden.items():
        if only and not re.search(only, key):
            continue
        records = colors.element(want["selector"], tuple(want["states"]))
        got = _predicted_look(records, theme_c + over_c, theme_r + over_r, len(records) - 1)
        lines += _compare(key, want, got, exceptions, slots)
    return lines


def check_probe(snapshots, golden, exceptions, only=None, slots=None):
    slots = slots or SLOTS + ["radius"]
    now = record_probe(snapshots)
    lines = []
    for key, want in golden.items():
        if only and not re.search(only, key):
            continue
        if key not in now:
            if not _excepted(key, "*", exceptions):
                lines.append(f"{key}: no longer on screen")
            continue
        lines += _compare(key, want, now[key], exceptions, slots)
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["record-static", "record-probe", "check-static", "check-probe"])
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--overlay")
    ap.add_argument("--only")
    ap.add_argument("--slots")
    args = ap.parse_args()
    slots = args.slots.split(",") if args.slots else None
    if args.command == "record-static":
        base, overlay, out = args.paths
        json.dump(record_static(base, overlay), open(out, "w"), indent=0, sort_keys=True)
        return 0
    if args.command == "record-probe":
        snapshots, out = args.paths
        json.dump(record_probe(json.load(open(snapshots))), open(out, "w"), indent=0, sort_keys=True)
        return 0
    source, golden_path, exceptions_path = args.paths
    golden, exceptions = json.load(open(golden_path)), load_exceptions(exceptions_path)
    if args.command == "check-static":
        lines = check_static(source, golden, exceptions, args.only, slots, args.overlay)
    else:
        lines = check_probe(json.load(open(source)), golden, exceptions, args.only, slots)
    print("\n".join(lines[:60]) + (f"\n… {len(lines)} differences" if len(lines) > 60 else ""))
    return 1 if lines else 0


if __name__ == "__main__":
    sys.exit(main())
