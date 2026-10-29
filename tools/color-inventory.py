#!/usr/bin/env python3
"""List the in-scope color rules of a stock Shell stylesheet, with the value
an older stylesheet gives the same rule (design decision 22).

Usage: color-inventory.py STOCK.css OLD.css --scope REGEX [--exclude REGEX]
                          [--palette PALETTE.tsv] [--renames RENAMES.tsv]
                          [--include-media]

Prints one tab-separated line per selector and color property, in STOCK's
order (each selector's last declaration counts, as in the cascade):
    selector<TAB>property<TAB>stock value<TAB>old value<TAB>source
Color properties: background-color, background, color, border-color, border,
border-top, box-shadow. Selector lists are split.

source:
  same     OLD has the same selector and property (or background and
           background-color for each other): its value.
  renamed  The element has another selector in OLD (RENAMES): OLD's value
           under that selector.
  derived  OLD has no such rule: the stock value with each color from
           PALETTE's first column replaced by its second.
  accent   The stock value uses the accent (-st-accent-color or
           -st-accent-fg-color): kept, palette-swapped, so it follows the
           Settings picker (OLD's accent was baked in).
  unset    OLD has the selector but never sets this color, so it drew none:
           transparent (background, border) or none (box-shadow). Text
           colors fall back to derived (they inherit).
  keep     An out-of-scope stock rule that one of the in-scope rules would
           erase (more specific, same color slot): its stock value, so a
           mirror can re-assert it.

--scope REGEX    keep selectors matching REGEX
--exclude REGEX  drop selectors matching REGEX
--palette FILE   two tab-separated columns: stock color, old color (a hex
                 color, a color name, or any literal text such as
                 "rgba(255, 255, 255,")
--renames FILE   two tab-separated columns: a regex for the stock selector,
                 its replacement in OLD (re.sub)
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "headless"))
import colors  # noqa: E402

TWINS = {"background": "background-color", "background-color": "background"}


def declarations(css, include_media=False):
    """{(selector, property): value}, in source order of each pair's last declaration."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    found, stack, buf = {}, [], ""
    for ch in css:
        if ch == "{":
            stack.append(buf.strip())
            buf = ""
        elif ch == "}":
            prelude = stack.pop() if stack else ""
            in_media = any(p.startswith("@") for p in stack)
            if not prelude.startswith("@") and (include_media or not in_media):
                for decl in buf.split(";"):
                    prop, _, value = decl.partition(":")
                    prop = prop.strip()
                    if prop not in colors.PROPS:
                        continue
                    for selector in prelude.split(","):
                        key = (" ".join(selector.split()), prop)
                        found.pop(key, None)  # keep cascade order
                        found[key] = " ".join(value.split())
            buf = ""
        elif ch == ";" and not stack:
            buf = ""
        else:
            buf += ch
    return found


def all_selectors(css):
    """Every selector of every plain rule, whatever it sets."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    return {" ".join(sel.split()) for m in re.finditer(r"([^{}]+)\{[^{}]*\}", css)
            for sel in m.group(1).split(",") if not sel.strip().startswith("@")}


def swap(value, palette):
    """value with each palette color (case-insensitive) replaced, in one pass."""
    if not palette:
        return value
    patterns = []
    for old in palette:
        if old.startswith("#"):
            patterns.append(re.escape(old) + r"(?![0-9a-fA-F])")
        elif old[0].isalpha():
            patterns.append(r"(?<![\w-])" + re.escape(old) + r"(?![\w-])")
        else:
            patterns.append(re.escape(old))
    lower = {k.lower(): v for k, v in palette.items()}
    return re.sub("|".join(f"(?:{p})" for p in patterns),
                  lambda m: lower[m.group(0).lower()], value, flags=re.I)


def table(path):
    """Two-column TSV as a dict (comment lines start with '# ')."""
    pairs = {}
    if path:
        for line in open(path):
            if line.strip() and not line.startswith("# "):
                a, b = line.rstrip("\n").split("\t")[:2]
                pairs[a] = b
    return pairs


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("stock")
    ap.add_argument("old")
    ap.add_argument("--scope", required=True)
    ap.add_argument("--exclude")
    ap.add_argument("--palette")
    ap.add_argument("--renames")
    ap.add_argument("--include-media", action="store_true")
    ap.add_argument("-h", "--help", action="store_true")
    args = ap.parse_args()
    if args.help:
        print(__doc__.strip())
        return 0

    palette, renames = table(args.palette), table(args.renames)
    stock = declarations(open(args.stock).read(), args.include_media)
    old = declarations(open(args.old).read(), args.include_media)
    scope = re.compile(args.scope)
    exclude = re.compile(args.exclude) if args.exclude else None
    in_scope = {key for key in stock
                if scope.search(key[0]) and not (exclude and exclude.search(key[0]))}

    # Out-of-scope rules one of ours would erase.
    ours = colors.parse_color_rules("".join(f"{sel} {{ {prop}: {stock[(sel, prop)]}; }}\n"
                                            for sel, prop in in_scope), origin=1)
    theirs = colors.parse_color_rules("".join(f"{sel} {{ {prop}: {value}; }}\n"
                                              for (sel, prop), value in stock.items()
                                              if (sel, prop) not in in_scope), origin=0)
    keep = {y for _, y in colors.shadowed(theirs, ours)}

    old_selectors = all_selectors(open(args.old).read())
    initial = {"background-color": "transparent", "background": "transparent",
               "border-color": "transparent", "border": "transparent", "border-top": "transparent",
               "box-shadow": "none"}

    def lookup(selector, prop):
        return old.get((selector, prop), old.get((selector, TWINS.get(prop, prop))))

    for (selector, prop), value in stock.items():
        if (selector, prop) not in in_scope:
            if selector in keep:
                print(f"{selector}\t{prop}\t{value}\t{value}\tkeep")
            continue
        renamed = selector
        for pattern, replacement in renames.items():
            renamed = re.sub(pattern, replacement, renamed)
        if "-st-accent" in value:
            then, source = swap(value, palette), "accent"
        elif lookup(selector, prop) is not None:
            then, source = lookup(selector, prop), "same"
        elif renamed != selector and lookup(renamed, prop) is not None:
            then, source = lookup(renamed, prop), "renamed"
        elif prop in initial and (selector in old_selectors or renamed in old_selectors):
            then, source = initial[prop], "unset"
        else:
            then, source = swap(value, palette), "derived"
        print(f"{selector}\t{prop}\t{value}\t{then}\t{source}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
