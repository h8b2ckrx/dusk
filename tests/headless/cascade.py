#!/usr/bin/env python3
"""Predict the corner radii GNOME Shell computes, and compare with reality.

Models St's cascade for border-radius only. St ranks an extension stylesheet
above the theme outright, so any rule of ours beats any Yaru rule, even a
more specific or !important one (seen live). Within one stylesheet: !important,
then specificity, then source order. Selectors use the subset
Yaru uses for radii: element types (matched against the GType chain), #id,
.class, :pseudo-class (:ltr always applies, :rtl never), descendant and child
combinators. Ancestors are St widgets only: St skips plain Clutter actors
and uses the nearest St widget above (seen live: the Activities workspace
dots sit under a plain Clutter actor and still match `#panel …` rules).

Records come from tests/headless/dusk-probe@local (snapshots.json): one per
mapped actor, with parent index, id, classes, pseudo, types and the radii
Shell computed.

Usage:
  cascade.py check SNAPSHOTS.json YARU.css DUSK.css
      Print every element whose computed radius differs from the prediction;
      exit 1 if any.
  cascade.py unmatched SNAPSHOTS.json SELECTOR...
      Print the selectors that match no element in any snapshot; exit 1 if any.
"""
import itertools
import json
import re
import sys

PROPS = {
    "border-radius": None,
    "border-top-left-radius": 0,
    "border-top-right-radius": 1,
    "border-bottom-right-radius": 2,
    "border-bottom-left-radius": 3,
}
COMPOUND = re.compile(r"^([A-Za-z][\w-]*)?((?:[#.:][\w-]+)*)$")
SIMPLE = re.compile(r"([#.:])([\w-]+)")


# A fresh id per parsed declaration (Rule.group).
_GROUPS = itertools.count()


class Rule:
    def __init__(self, selector, compounds, specificity, key, corners, group=None):
        self.selector = selector
        self.compounds = compounds    # [(combinator to the left, compound)]
        self.specificity = specificity
        self.key = key                # sort key: later/bigger wins
        self.corners = corners        # {corner index: raw value}
        self.group = group            # the declaration this selector shares with its list


def parse_selector(selector):
    """'.a > .b:hover' -> ([(None, a), ('>', b)], specificity) or None."""
    tokens = selector.replace(">", " > ").split()
    compounds, combinator = [], None
    ids = classes = types = 0
    for token in tokens:
        if token == ">":
            combinator = ">"
            continue
        m = COMPOUND.match(token)
        if not m:
            return None
        compound = {"type": m.group(1), "ids": [], "classes": [], "pseudo": []}
        if compound["type"]:
            types += 1
        for kind, name in SIMPLE.findall(m.group(2)):
            if kind == "#":
                compound["ids"].append(name)
                ids += 1
            elif kind == ".":
                compound["classes"].append(name)
                classes += 1
            else:
                compound["pseudo"].append(name)
                classes += 1
        compounds.append((combinator if compounds else None, compound))
        combinator = " "
    return compounds, (ids, classes, types)


def expand(prop, value):
    """Corner values a declaration sets: {corner: raw}."""
    if PROPS[prop] is not None:
        return {PROPS[prop]: value}
    parts = value.split("/")[0].split()
    if len(parts) == 1:
        parts *= 4
    elif len(parts) == 2:
        parts = [parts[0], parts[1], parts[0], parts[1]]
    elif len(parts) == 3:
        parts = [parts[0], parts[1], parts[2], parts[1]]
    return dict(enumerate(parts[:4]))


def parse_rules(css, origin, props=PROPS, expand=None):
    """Radius rules in source order, one per selector in each list. Other
    properties with `props` and `expand(prop, value) -> {slot: raw}`
    (tests/headless/colors.py uses this for colors)."""
    expand = expand or globals()["expand"]
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    rules, order = [], 0
    stack, buf = [], ""
    for ch in css:
        if ch == "{":
            stack.append(buf.strip())
            buf = ""
        elif ch == "}":
            prelude = stack.pop() if stack else ""
            if not prelude.startswith("@") and not any(p.startswith("@") for p in stack):
                for decl in buf.split(";"):
                    prop, _, value = decl.partition(":")
                    prop = prop.strip()
                    if prop not in props:
                        continue
                    important = "!important" in value
                    value = value.replace("!important", "").strip()
                    order += 1
                    group = next(_GROUPS)
                    for selector in prelude.split(","):
                        selector = " ".join(selector.split())
                        parsed = parse_selector(selector)
                        if parsed is None:
                            continue
                        compounds, specificity = parsed
                        key = (origin, important, specificity, order)
                        slots = expand(prop, value)
                        if slots:
                            rules.append(Rule(selector, compounds, specificity, key, slots, group))
            buf = ""
        elif ch == ";" and not stack:
            buf = ""
        else:
            buf += ch
    return rules


def st_parent(records, i):
    """Index of the nearest St widget above record i, or -1."""
    p = records[i]["parent"]
    while p >= 0 and "StWidget" not in records[p]["types"]:
        p = records[p]["parent"]
    return p


def compound_matches(record, compound):
    if compound["type"] and compound["type"] not in record["types"]:
        return False
    if any(i != record["id"] for i in compound["ids"]):
        return False
    if any(c not in record["classes"] for c in compound["classes"]):
        return False
    for p in compound["pseudo"]:
        if p == "ltr":
            continue
        if p == "rtl" or p not in record["pseudo"]:
            return False
    return True


def matches(records, i, compounds, k=None):
    k = len(compounds) - 1 if k is None else k
    combinator, compound = compounds[k]
    if not compound_matches(records[i], compound):
        return False
    if k == 0:
        return True
    p = st_parent(records, i)
    if compounds[k][0] == ">":
        return p >= 0 and matches(records, p, compounds, k - 1)
    while p >= 0:
        if matches(records, p, compounds, k - 1):
            return True
        p = st_parent(records, p)
    return False


def winners(records, rules):
    """Per record, per corner: the winning Rule (or None). As in St, a rule
    counts with the specificity of the last selector in its list that matches
    the element, not the highest (st-theme.c add_matched_properties sets the
    statement's specificity at every matching selector)."""
    result = []
    for i, record in enumerate(records):
        best, best_key = [None] * 4, [None] * 4
        if "StWidget" in record["types"]:
            matched = [rule for rule in rules if matches(records, i, rule.compounds)]
            last = {rule.group: rule.specificity for rule in matched}
            for rule in matched:
                origin, important, _, order = rule.key
                key = (origin, important, last[rule.group], order)
                for corner in rule.corners:
                    if best[corner] is None or key >= best_key[corner]:
                        best[corner], best_key[corner] = rule, key
        result.append(best)
    return result


def predict(records, rules):
    """Per record, per corner: the winning raw value (or None)."""
    return [[r.corners[c] if r else None for c, r in enumerate(best)]
            for best in winners(records, rules)]


def px(value):
    """Pixels for '12px' / '0', None for em, % or anything else."""
    if value is None:
        return 0.0
    m = re.match(r"^(\d*\.?\d+)(px)?$", value)
    return float(m.group(1)) if m else None


def describe(records, i):
    chain = []
    while i >= 0 and len(chain) < 4:
        r = records[i]
        chain.append((r["types"][0] if r["types"] else "?")
                     + (f"#{r['id']}" if r["id"] else "")
                     + "".join(f".{c}" for c in r["classes"]))
        i = r["parent"]
    return " < ".join(chain)


def check(snapshots, rules):
    problems = []
    for state, records in snapshots.items():
        for i, (record, best) in enumerate(zip(records, winners(records, rules))):
            if record["radii"] is None:
                continue
            for corner, rule in enumerate(best):
                expected = px(rule.corners[corner] if rule else None)
                if expected is None:
                    continue
                actual = record["radii"][corner]
                if abs(actual - expected) > 0.5:
                    problems.append(f"{state}: {describe(records, i)} corner {corner}: "
                                    f"Shell {actual}, predicted {expected:g} from "
                                    f"'{rule.selector if rule else '(nothing)'}'")
                    break
    return problems


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("check", "unmatched"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    snapshots = json.load(open(sys.argv[2]))
    if sys.argv[1] == "check":
        rules = (parse_rules(open(sys.argv[3]).read(), origin=0)
                 + parse_rules(open(sys.argv[4]).read(), origin=1))
        problems = check(snapshots, rules)
        print("\n".join(problems))
        return 1 if problems else 0
    unmatched = []
    for selector in sys.argv[3:]:
        compounds, _ = parse_selector(selector)
        if not any(matches(records, i, compounds)
                   for records in snapshots.values() for i in range(len(records))):
            unmatched.append(selector)
    print("\n".join(unmatched))
    return 1 if unmatched else 0


if __name__ == "__main__":
    sys.exit(main())
