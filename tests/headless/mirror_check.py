"""Check a compiled stylesheet against a radius inventory (.tsv).

problems(repo, sassc, tsv, css, window_var=False) -> list of strings:
every inventory row is in the compiled CSS with its token's value (zeros stay
0, calc()/var() keep their shape), the rows keep the inventory's order, and
optionally `:root { --window-radius }` is the window token.
"""
import re

from tokens import token_values

LENGTH = re.compile(r"(?<![\w.-])(\d*\.?\d+)(px|%|em)?(?![\w.-])")


def rows(tsv):
    # Comments start with "# "; a selector may itself start with "#" (an id).
    return [l.rstrip("\n").split("\t") for l in open(tsv)
            if l.strip() and not l.startswith("# ")]


def problems(repo, sassc, tsv, css, window_var=False):
    inventory = rows(tsv)
    value = token_values(repo, sassc, sorted({r[3] for r in inventory if r[3] != "0"} | {"window"}))

    def expected(stock, token):
        return LENGTH.sub(lambda m: "0" if float(m.group(1)) == 0 else value[token], stock)

    text = open(css).read()
    position = {}
    for k, block in enumerate(text.split("}")):
        sel, _, body = block.rpartition("{")
        for decl in body.split(";"):
            prop, _, val = decl.partition(":")
            for s in sel.split(","):
                position[(" ".join(s.split()), prop.strip())] = (k, " ".join(val.split()))

    found, last = [], -1
    for sel, prop, stock, token in inventory:
        got = position.get((sel, prop))
        want = " ".join(expected(stock, token).split())
        if got is None:
            found.append(f"missing: {sel} {{ {prop} }}")
            continue
        k, val = got
        if val != want:
            found.append(f"{sel} {{ {prop}: {val} }}, want {want}")
        if k < last:
            found.append(f"out of the inventory's order: {sel} {{ {prop} }}")
        last = max(last, k)

    if window_var:
        root = re.search(r":root\s*\{[^}]*--window-radius:\s*([^;]+);", text)
        if not root or root.group(1).strip() != value["window"]:
            found.append(f"--window-radius is not the window token ({value['window']})")
    return found
