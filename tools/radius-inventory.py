#!/usr/bin/env python3
"""List the effective corner radius of every selector in a stylesheet.

Usage: radius-inventory.py FILE.css [--include-zero] [--include-media]
                                    [--exclude REGEX] [--source-order]

Prints one tab-separated line per selector and radius property:
    value<TAB>property<TAB>selector
Selector lists are split, and only the last value per selector and property
counts (as in the cascade). Covers border-radius and its four longhands.
Values that aren't lengths, 0 or percentages show as INVALID:<raw>.
Sorted by the largest length in the value (em counted as 16px, percentages
after all lengths, INVALID last), then by selector.

--include-zero   also list radius 0 (square corners)
--include-media  also list rules inside @media blocks (skipped by default:
                 in libadwaita they are high-contrast rules)
--exclude REGEX  drop selectors matching REGEX
--source-order   keep the order of each selector's last declaration (the
                 order the cascade uses for ties) instead of sorting
"""
import argparse
import re
import sys

PROPS = {
    "border-radius",
    "border-top-left-radius",
    "border-top-right-radius",
    "border-bottom-right-radius",
    "border-bottom-left-radius",
}
PART = re.compile(r"^(\d*\.?\d+)(px|em|%)?$")


def split_top_level(text, sep):
    """Split on `sep` outside parentheses."""
    parts, depth, cur = [], 0, ""
    for ch in text:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == sep and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return [p.strip() for p in parts if p.strip()]


def rules(css, include_media):
    """Yield (selector_list, declarations_text) for every plain rule."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    stack, buf = [], ""
    for ch in css:
        if ch == "{":
            stack.append(buf.strip())
            buf = ""
        elif ch == "}":
            prelude = stack.pop() if stack else ""
            in_media = any(p.startswith("@") for p in stack)
            if not prelude.startswith("@") and (include_media or not in_media):
                yield prelude, buf
            buf = ""
        elif ch == ";" and (not stack or stack[-1].startswith("@")):
            buf = ""  # a statement such as @define-color or @import
        else:
            buf += ch


def classify(value):
    """Return (is_zero, sort_key, shown_value)."""
    value = value.replace("!important", "").strip()
    key, zero = 0.0, True
    for part in value.split():
        m = PART.match(part)
        if not m:
            return False, float("inf"), f"INVALID:{value}"
        number, unit = float(m.group(1)), m.group(2)
        if number:
            zero = False
        if unit == "%":
            key = max(key, 1e6 + number)
        else:
            key = max(key, number * (16 if unit == "em" else 1))
    return zero, key, value


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("file")
    ap.add_argument("--include-zero", action="store_true")
    ap.add_argument("--include-media", action="store_true")
    ap.add_argument("--exclude")
    ap.add_argument("--source-order", action="store_true")
    ap.add_argument("-h", "--help", action="store_true")
    args = ap.parse_args()
    if args.help:
        print(__doc__.strip())
        return 0

    effective = {}
    with open(args.file) as f:
        for selectors, body in rules(f.read(), args.include_media):
            for decl in split_top_level(body, ";"):
                prop, _, value = decl.partition(":")
                prop = prop.strip()
                if prop in PROPS:
                    for sel in split_top_level(selectors, ","):
                        sel = " ".join(sel.split())
                        effective.pop((sel, prop), None)  # keep cascade order
                        effective[(sel, prop)] = value.strip()

    exclude = re.compile(args.exclude) if args.exclude else None
    rows = []
    for (sel, prop), value in effective.items():
        if exclude and exclude.search(sel):
            continue
        zero, key, shown = classify(value)
        if zero and not args.include_zero:
            continue
        rows.append((key, sel, shown, prop))
    for key, sel, shown, prop in (rows if args.source_order else sorted(rows)):
        print(f"{shown}\t{prop}\t{sel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
