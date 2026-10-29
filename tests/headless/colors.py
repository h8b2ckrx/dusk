#!/usr/bin/env python3
"""Predict the colors GNOME Shell computes, and compare with reality.

The same cascade as cascade.py (our stylesheet beats Yaru's outright; within
one, !important, then specificity, then source order), for four color slots
instead of four corners: 0 background, 1 text (inherited from the nearest St
parent), 2 border (top), 3 box-shadow. Values are evaluated like St does,
including its st-lighten / st-darken / st-mix / st-transparentize /
st-opacify functions (they behave like their Sass namesakes). A value that
uses the accent (-st-accent-color) depends on the Settings picker and isn't
predicted here.

Records come from tests/headless/dusk-probe@local (snapshots.json): `colors`
is [bg, fg, border, shadow], each [r, g, b, a] (0-255) or null.

Usage:
  colors.py check SNAPSHOTS.json YARU.css DUSK.css
      Print every element whose computed color differs from the prediction
      (more than 2 per channel); exit 1 if any.
  colors.py clobbered SNAPSHOTS.json YARU.css DUSK.css
      Print every element where one of our rules overrides a more specific
      Yaru rule for the same slot; exit 1 if any.
  colors.py shadowed YARU.css DUSK.css [EXCLUDE_REGEX]
      Static version of `clobbered`, for states the probe doesn't show
      (hover, pressed): print every more specific Yaru rule for a slot one of
      our rules sets, on a subset of what ours targets, not re-asserted in
      ours; exit 1 if any.
  colors.py expect SNAPSHOTS.json YARU.css INVENTORY.tsv MODE CHUNKS [ON]
      Print every element whose color a row of CHUNKS (e.g. 1 or 1,2)
      decides, by Yaru plus the inventory's rows of the chunks switched ON
      (default CHUNKS), where Shell's color isn't that row's 24.04 value;
      exit 1 if any, or if none was compared.
  colors.py contrast SNAPSHOTS.json YARU.css INVENTORY.tsv MODE CHUNKS [ON]
      Print every label on such a surface with text contrast below 4.5 and
      below 80% of stock Yaru's for it (disabled ones aside); exit 1 if any, or if
      none was checked.
"""
import colorsys
import json
import re
import sys

import cascade

SLOTS = {"background-color": 0, "color": 1, "border-color": 2, "box-shadow": 3}
PROPS = set(SLOTS) | {"background", "border", "border-top"}
NAMED = {"white": (255, 255, 255, 255), "black": (0, 0, 0, 255), "transparent": (0, 0, 0, 0),
         "whitesmoke": (245, 245, 245, 255)}
COLOR_START = re.compile(r"#[0-9a-fA-F]{3,8}\b|(?:rgba?|st-[a-z]+)\(|-st-accent-color|\b(?:white|black|transparent)\b")


def first_color(value):
    """The first color in a declaration value (e.g. a border or shadow), or None."""
    m = COLOR_START.search(value)
    if not m:
        return None
    start, end = m.start(), m.end()
    if value[end - 1] == "(":
        depth = 1
        while end < len(value) and depth:
            depth += {"(": 1, ")": -1}.get(value[end], 0)
            end += 1
    return value[start:end]


def expand(prop, value):
    """{slot: raw} a color declaration sets."""
    value = value.strip()
    if prop in ("background-color", "color", "border-color"):
        return {SLOTS[prop]: value}
    if prop == "background":
        color = "transparent" if value == "none" else first_color(value)
        return {0: color} if color else {}
    if prop in ("border", "border-top"):
        color = first_color(value)
        return {2: color} if color else {}
    if prop == "box-shadow":
        color = "none" if value == "none" else first_color(value)
        return {3: color} if color else {}
    return {}


def parse_color_rules(css, origin):
    """Color rules in source order, one per selector in each list."""
    return cascade.parse_rules(css, origin, props=PROPS, expand=expand)


def split_args(text):
    """Top-level comma-separated arguments."""
    args, depth, buf = [], 0, ""
    for ch in text:
        if ch == "," and depth == 0:
            args.append(buf.strip())
            buf = ""
            continue
        depth += {"(": 1, ")": -1}.get(ch, 0)
        buf += ch
    args.append(buf.strip())
    return args


def amount(text):
    """'7%' -> 0.07, '0.9' -> 0.9."""
    text = text.strip()
    return float(text[:-1]) / 100 if text.endswith("%") else float(text)


def _rgba(value):
    """(r, g, b, a) with r, g, b in 0-255 floats and a in 0-1, or None."""
    value = value.strip()
    if "-st-accent-color" in value:
        return None
    if value in NAMED:
        r, g, b, a = NAMED[value]
        return (r, g, b, a / 255)
    if value.startswith("#"):
        h = value[1:]
        if len(h) in (3, 4):
            h = "".join(c * 2 for c in h)
        a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
    m = re.match(r"^([a-z-]+)\((.*)\)$", value, re.S)
    if not m:
        return None
    name, args = m.group(1), split_args(m.group(2))
    if name in ("rgb", "rgba"):
        channels = [float(x[:-1]) * 2.55 if x.endswith("%") else float(x) for x in args[:3]]
        return (*channels, amount(args[3]) if len(args) > 3 else 1.0)
    inner = [_rgba(a) for a in args[:2]]
    if any(c is None for c in inner[:1 if name != "st-mix" else 2]):
        return None
    if name in ("st-lighten", "st-darken"):
        r, g, b, a = inner[0]
        h, light, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        light = min(1.0, max(0.0, light + (1 if name == "st-lighten" else -1) * amount(args[1])))
        r, g, b = colorsys.hls_to_rgb(h, light, s)
        return (r * 255, g * 255, b * 255, a)
    if name in ("st-transparentize", "st-opacify"):
        r, g, b, a = inner[0]
        a = a - amount(args[1]) if name == "st-transparentize" else a + amount(args[1])
        return (r, g, b, min(1.0, max(0.0, a)))
    if name == "st-mix":
        # Sass mix(): `p` is the weight of the first color, adjusted for alpha.
        (r1, g1, b1, a1), (r2, g2, b2, a2) = inner
        p = amount(args[2]) if len(args) > 2 else 0.5
        w, d = 2 * p - 1, a1 - a2
        w1 = ((w if w * d == -1 else (w + d) / (1 + w * d)) + 1) / 2
        w2 = 1 - w1
        return (r1 * w1 + r2 * w2, g1 * w1 + g2 * w2, b1 * w1 + b2 * w2, a1 * p + a2 * (1 - p))
    return None


def evaluate(value):
    """(r, g, b, a) as 0-255 ints, or None for 'none', the accent, or anything unknown."""
    color = _rgba(value) if value and value != "none" else None
    if color is None:
        return None
    r, g, b, a = color
    # round(a, 6): 1 - 0.9 is 0.09999…, which would round one alpha step low.
    return (round(r), round(g), round(b), round(round(a, 6) * 255))


def predict(records, rules):
    """Per record, per slot: the evaluated winning value (None if nothing
    sets it, or it uses the accent). Text color inherits from the nearest St
    parent."""
    result = []
    for i, best in enumerate(cascade.winners(records, rules)):
        slots = [evaluate(rule.corners[slot]) if rule else None for slot, rule in enumerate(best)]
        if best[1] is None:
            parent = cascade.st_parent(records, i)
            slots[1] = result[parent][1] if parent >= 0 else None
        result.append(slots)
    return result


def shadowed(yaru, dusk, exclude=None):
    """(our selector, Yaru selector) pairs where ours would erase Yaru's for a slot."""
    ours = {(r.selector, s) for r in dusk for s in r.corners}
    pairs = set()
    for d in dusk:
        for y in yaru:
            shared = set(y.corners) & set(d.corners)
            if not shared or all((y.selector, s) in ours for s in shared):
                continue
            if y.specificity <= d.specificity or (exclude and re.search(exclude, y.selector)):
                continue
            if cascade.narrows(y, d):
                pairs.add((d.selector, y.selector))
    return sorted(pairs)


def over(fg, bg):
    """fg composited over an opaque bg, as an opaque color."""
    a = fg[3] / 255
    return tuple(round(f * a + b * (1 - a)) for f, b in zip(fg[:3], bg[:3])) + (255,)


def contrast(a, b):
    """WCAG contrast ratio between two opaque colors."""
    def lum(c):
        ch = [x / 255 for x in c[:3]]
        ch = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in ch]
        return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]
    hi, lo = sorted((lum(a), lum(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def tsv_rules(tsv, mode, chunks, on=None):
    """The inventory's rows for `mode` as rules (origin 1) with their 24.04
    values, for the chunks switched `on` (default: `chunks`) plus chunk 0 —
    what the mirror emits; and the rules of `chunks` alone."""
    on = set(on or chunks)
    rules, wanted = [], []
    for line in open(tsv):
        if not line.strip() or line.startswith("# "):
            continue
        m, sel, prop, new, old, source, _, chunk = line.rstrip("\n").split("\t")
        if m not in ("both", mode) or int(chunk) not in on | {0}:
            continue
        flag = " !important" if "!important" in new else ""
        value = old.replace("!important", "").strip()
        parsed = parse_color_rules(f"{sel} {{ {prop}: {value}{flag}; }}", origin=1)
        for rule in parsed:
            rule.source = source
        rules += parsed
        if int(chunk) in chunks:
            wanted += parsed
    return rules, wanted


def expect(snapshots, yaru, tsv, mode, chunks, on=None):
    """Elements whose color a row of `chunks` decides, with Shell's computed
    color differing from that row's 24.04 value: (problems, compared)."""
    ours, wanted = tsv_rules(tsv, mode, chunks, on)
    wanted = {id(r) for r in wanted}
    problems, compared = [], 0
    names = ["background", "text", "border", "shadow"]
    for state, records in snapshots.items():
        for i, best in enumerate(cascade.winners(records, yaru + ours)):
            computed = records[i].get("colors")
            if not computed:
                continue
            for slot, rule in enumerate(best):
                if rule is None or id(rule) not in wanted:
                    continue
                want = evaluate(rule.corners[slot])
                got = computed[slot]
                if want is None or (slot == 3 and got is None):
                    continue
                compared += 1
                if got is None or any(abs(x - y) > 2 for x, y in zip(got, want)):
                    problems.append(f"{state}: {cascade.describe(records, i)} {names[slot]}: "
                                    f"Shell {got}, want {list(want)} from '{rule.selector}'")
    return problems, compared


def legibility(snapshots, yaru, tsv, mode, chunks, on=None, minimum=4.5):
    """Labels on a surface whose background a row of `chunks` decides, with
    text contrast below `minimum` and below 80% of what stock Yaru gives the
    same label (some text is dim by design), disabled ones aside. A label
    whose text and background colors both come straight from 24.04 is
    24.04's own pairing, and passes: (problems, checked)."""
    ours, wanted = tsv_rules(tsv, mode, chunks, on)
    wanted = {id(r) for r in wanted}
    problems, checked = [], 0
    for state, records in snapshots.items():
        best = cascade.winners(records, yaru + ours)
        stock = predict(records, yaru)
        for i, record in enumerate(records):
            if "StLabel" not in record["types"] or not record.get("colors"):
                continue
            # St marks every non-reactive widget :insensitive (labels, plain
            # boxes); only an insensitive control means disabled text.
            j, disabled = i, False
            while j >= 0:
                control = any(k in t for t in records[j]["types"] for k in ("Button", "MenuItem", "StEntry"))
                disabled |= control and "insensitive" in records[j]["pseudo"]
                bg = (records[j].get("colors") or [None])[0]
                if bg and bg[3] >= 250:
                    break
                j = records[j]["parent"]
            if j < 0 or disabled or best[j][0] is None or id(best[j][0]) not in wanted:
                continue
            checked += 1
            # Text and background both straight from 24.04: 24.04's own pairing.
            k = i
            while k >= 0 and best[k][1] is None:
                k = cascade.st_parent(records, k)
            text = best[k][1] if k >= 0 else None
            if (getattr(text, "source", None) in ("same", "renamed")
                    and getattr(best[j][0], "source", None) in ("same", "renamed", "unset")):
                continue
            ratio = contrast(over(record["colors"][1], bg), bg)
            before, behind = stock[i][1], stock[j][0]
            floor = minimum
            if before and behind and behind[3] >= 250:
                # 24.04's light text (#3D3D3D) is lighter than 26.04's (#222222),
                # so its dim labels are a little fainter by design; flag only a
                # real drop (e.g. a light hint on a light entry).
                floor = min(minimum, 0.8 * contrast(over(before, behind), behind))
            if ratio < floor:
                problems.append(f"{state}: {cascade.describe(records, i)}: contrast {ratio:.1f}")
    return problems, checked


def check(snapshots, rules):
    problems = []
    names = ["background", "text", "border", "shadow"]
    for state, records in snapshots.items():
        for i, (record, predicted) in enumerate(zip(records, predict(records, rules))):
            computed = record.get("colors")
            if not computed:
                continue
            for slot, want in enumerate(predicted):
                got = computed[slot]
                if want is None or (slot == 3 and got is None):
                    continue
                if got is None or any(abs(x - y) > 2 for x, y in zip(got, want)):
                    problems.append(f"{state}: {cascade.describe(records, i)} {names[slot]}: "
                                    f"Shell {got}, predicted {list(want)}")
                    break
    return problems


def main():
    if len(sys.argv) >= 7 and sys.argv[1] in ("expect", "contrast"):
        snapshots = json.load(open(sys.argv[2]))
        yaru = parse_color_rules(open(sys.argv[3]).read(), origin=0)
        chunks = [int(c) for c in sys.argv[6].split(",")]
        on = [int(c) for c in sys.argv[7].split(",")] if len(sys.argv) > 7 else None
        fn = expect if sys.argv[1] == "expect" else legibility
        problems, n = fn(snapshots, yaru, sys.argv[4], sys.argv[5], chunks, on)
        print("\n".join(sorted(set(problems))[:40]))
        print(f"{n} {'colors compared' if fn is expect else 'labels checked'}, {len(problems)} problems")
        return 1 if problems or not n else 0
    if len(sys.argv) < 4 or sys.argv[1] not in ("check", "clobbered", "shadowed"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    if sys.argv[1] == "shadowed":
        pairs = shadowed(parse_color_rules(open(sys.argv[2]).read(), origin=0),
                         parse_color_rules(open(sys.argv[3]).read(), origin=1),
                         sys.argv[4] if len(sys.argv) > 4 else None)
        print("\n".join(f"our '{d}' would erase Yaru's '{y}'" for d, y in pairs))
        return 1 if pairs else 0
    snapshots = json.load(open(sys.argv[2]))
    yaru = parse_color_rules(open(sys.argv[3]).read(), origin=0)
    dusk = parse_color_rules(open(sys.argv[4]).read(), origin=1)
    if sys.argv[1] == "check":
        problems = check(snapshots, yaru + dusk)
        print("\n".join(problems))
        return 1 if problems else 0
    lines = set()
    for records in snapshots.values():
        stock = cascade.winners(records, yaru)
        ours = cascade.winners(records, yaru + dusk)
        for i in cascade.clobbered(records, yaru, dusk):
            for b, a in zip(stock[i], ours[i]):
                if b and a and a in dusk and a.specificity < b.specificity:
                    lines.add(f"{cascade.describe(records, i)}: our '{a.selector}' overrides Yaru's '{b.selector}'")
    print("\n".join(sorted(lines)))
    return 1 if lines else 0


if __name__ == "__main__":
    sys.exit(main())
