# build/gtk4.css against docs/inventory-gtk4.tsv (design decision: mirror
# every libadwaita radius rule, in libadwaita's order, values from tokens).

# check_mirror: every inventory row is in build/gtk4.css with its token's
# value, and the rows keep libadwaita's order.
test_gtk4_mirrors_inventory() {
  (cd "$REPO" && ./build.sh > /dev/null)
  python3 - "$REPO" "${SASSC:-sassc}" <<'EOF'
import re, subprocess, sys
repo, sassc = sys.argv[1], sys.argv[2]
rows = [l.rstrip("\n").split("\t") for l in open(f"{repo}/docs/inventory-gtk4.tsv")
        if l.strip() and not l.startswith("# ")]

# Token values, from the tokens file itself.
sys.path.insert(0, f"{repo}/tests/headless")
from tokens import token_values
value = token_values(repo, sassc, sorted({r[3] for r in rows if r[3] != "0"} | {"window"}))

LENGTH = re.compile(r"(?<![\w.-])(\d*\.?\d+)(px|%|em)?(?![\w.-])")
def expected(libadwaita, token):
    return LENGTH.sub(lambda m: "0" if float(m.group(1)) == 0 else value[token], libadwaita)

css = open(f"{repo}/build/gtk4.css").read()
position = {}
for k, block in enumerate(css.split("}")):
    sel, _, body = block.rpartition("{")
    for decl in body.split(";"):
        prop, _, val = decl.partition(":")
        for s in sel.split(","):
            position[(" ".join(s.split()), prop.strip())] = (k, " ".join(val.split()))

problems, last = [], -1
for sel, prop, libadwaita, token in rows:
    got = position.get((sel, prop))
    want = expected(libadwaita, token)
    if got is None:
        problems.append(f"missing: {sel} {{ {prop} }}")
        continue
    k, val = got
    if val != want:
        problems.append(f"{sel} {{ {prop}: {val} }}, want {want}")
    if k < last:
        problems.append(f"out of libadwaita's order: {sel} {{ {prop} }}")
    last = max(last, k)

root = re.search(r":root\s*\{[^}]*--window-radius:\s*([^;]+);", css)
if not root or root.group(1).strip() != value["window"]:
    problems.append(f"--window-radius is not the window token ({value['window']})")

print("\n".join(problems[:20]) + (f"\n… {len(problems)} problems" if len(problems) > 20 else ""))
sys.exit(1 if problems else 0)
EOF
}

# gtk_probe_dir: a finished tools/headless-gtk.sh run for the current code,
# reused while src/, docs/inventory-gtk4.tsv and tests/headless/ are unchanged.
gtk_probe_dir() {
  local key out
  key=$(cd "$REPO" && find src docs/inventory-gtk4.tsv tests/headless tools/headless-gtk.sh -type f \
    -print0 | sort -z | xargs -0 sha1sum | sha1sum | cut -c1-16)
  out="${TMPDIR:-/tmp}/dusk-gtk-$key-dark"
  if [ ! -s "$out/gtk4.json" ]; then
    "$REPO/tools/headless-gtk.sh" "$out" dark > /dev/null 2>&1 \
      || fail "GTK probe failed: $(tail -3 "$out/probe.log" 2> /dev/null)"
  fi
  echo "$out"
}

# Real libadwaita widgets, drawn by GTK with our gtk.css in an isolated
# session: the corners GTK draws carry our tokens. Linked groups keep their
# square inner corners, and knobs, radios and avatars stay round.
test_headless_gtk4_widgets_follow_tokens() {
  local out; out=$(gtk_probe_dir)
  python3 - "$REPO" "${SASSC:-sassc}" "$out/gtk4.json" <<'EOF'
import json, sys
repo, sassc = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{repo}/tests/headless")
from tokens import token_values
names = ["button", "icon-button", "pill-button", "entry", "switch", "checkbox", "bar",
         "toggle-group", "card", "popover", "window", "slider"]
t = {k: float(v.rstrip("px")) for k, v in token_values(repo, sassc, names).items()}
got = json.load(open(sys.argv[3]))
problems = []
def radii(name):
    r = got.get(name, {}).get("radii")
    if r is None:
        problems.append(f"{name}: not measured ({got.get(name)})")
    return r
def want(name, corners):
    r = radii(name)
    if r is not None and any(abs(a - b) > 0.5 for a, b in zip(r, corners)):
        problems.append(f"{name}: drawn {r}, want {corners}")
def round_(name):
    r = radii(name)
    w, h = got[name]["size"] if r is not None else (0, 0)
    if r is not None and min(r) < min(w, h) / 2 - 0.5:
        problems.append(f"{name}: drawn {r}, want round (size {w}x{h})")
b = t["button"]
want("button", [b] * 4)
want("linked-first", [b, 0, 0, b])
want("linked-middle", [0] * 4)
want("linked-last", [0, b, b, 0])
want("button-circular", [t["icon-button"]] * 4)
want("button-pill", [t["pill-button"]] * 4)
want("entry", [t["entry"]] * 4)
want("spinbutton", [t["entry"]] * 4)
want("switch", [t["switch"]] * 4)
want("check", [t["checkbox"]] * 4)
want("progressbar-trough", [min(t["bar"], got["progressbar-trough"]["size"][1] / 2)] * 4)
want("toggle-group", [t["toggle-group"]] * 4)
toggle = radii("toggle")
if toggle is not None and not all(0 <= c <= t["toggle-group"] for c in toggle):
    problems.append(f"toggle: drawn {toggle}, want between 0 and the group's {t['toggle-group']}")
want("boxed-list", [t["card"]] * 4)
want("boxed-list-first-row", [t["card"], t["card"], 0, 0])
want("card", [t["card"]] * 4)
want("popover-contents", [t["popover"]] * 4)
want("window", [t["window"]] * 4)
trough = radii("scale-trough")
if trough is not None and any(c > t["slider"] + 0.5 for c in trough):
    problems.append(f"scale-trough: drawn {trough}, want at most {t['slider']}")
for name in ("switch-knob", "scale-knob", "radio", "avatar"):
    round_(name)
print("\n".join(problems))
sys.exit(1 if problems else 0)
EOF
}

# The committed partial is exactly what the generator makes from the inventory
# (never hand-edited, never stale).
test_gtk4_generated_rules_up_to_date() {
  diff <("$REPO/tools/mirror-radius.py" "$REPO/docs/inventory-gtk4.tsv") "$REPO/src/_gtk4-radius.scss" > /dev/null \
    || fail "src/_gtk4-radius.scss is stale: run tools/mirror-radius.py docs/inventory-gtk4.tsv > src/_gtk4-radius.scss"
}

# Inventory comments start with "# "; a selector can start with "#" (an id).
test_mirror_keeps_id_selectors() {
  local out; out=$(mktemp)
  "$REPO/tools/mirror-radius.py" "$REPO/tests/fixtures/mirror_ids.tsv" > "$out"
  assert_contains "$out" "#an-id .thing {"
  assert_not_contains "$out" "a comment line"
}
