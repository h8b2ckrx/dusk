# build/gtk3.css against docs/inventory-gtk3.tsv: every Yaru GTK3 radius rule
# mirrored in Yaru's order, values from tokens (design §5; decision 13 for
# windows).

test_gtk3_mirrors_inventory() {
  (cd "$REPO" && ./build.sh > /dev/null)
  python3 - "$REPO" "${SASSC:-sassc}" <<'PY'
import sys
repo, sassc = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{repo}/tests/headless")
from mirror_check import problems
found = problems(repo, sassc, f"{repo}/docs/inventory-gtk3.tsv", f"{repo}/build/gtk3.css")
print("\n".join(found[:20]) + (f"\n… {len(found)} problems" if len(found) > 20 else ""))
sys.exit(1 if found else 0)
PY
}

# The committed partial is exactly what the generator makes from the inventory.
test_gtk3_generated_rules_up_to_date() {
  diff <("$REPO/tools/mirror-radius.py" "$REPO/docs/inventory-gtk3.tsv") "$REPO/src/_gtk3-radius.scss" > /dev/null \
    || fail "src/_gtk3-radius.scss is stale: run tools/mirror-radius.py docs/inventory-gtk3.tsv > src/_gtk3-radius.scss"
}

# Decision 13: GTK3 window frames round their top corners only.
test_gtk3_window_frame_top_only() {
  (cd "$REPO" && ./build.sh > /dev/null)
  python3 - "$REPO/build/gtk3.css" <<'PY'
import re, sys
css = open(sys.argv[1]).read()
m = re.search(r"(?m)^decoration[^{]*\{[^}]*border-radius:\s*([^;]+);", css)
assert m, "no decoration rule"
parts = m.group(1).split()
assert len(parts) == 4 and parts[2] == "0" and parts[3] == "0" and parts[0] != "0", parts
PY
}

# Real GTK3 widgets, styled (never shown) with our gtk3.css and your GTK
# theme in their own config folder (tools/probe-gtk3.sh): the radius GTK3
# computes carries our tokens, linked groups keep their square joins, knobs
# stay round, and window frames follow decision 13.
test_gtk3_widgets_follow_tokens() {
  local out; out=$(mktemp -d)
  "$REPO/tools/probe-gtk3.sh" "$out" || fail "GTK3 probe failed: $(tail -3 "$out/probe.log")"
  python3 - "$REPO" "${SASSC:-sassc}" "$out/gtk3.json" <<'PY'
import json, sys
repo, sassc = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{repo}/tests/headless")
from tokens import token_values
names = ["icon-button", "button", "entry", "switch", "round", "checkbox", "slider", "bar",
         "popover", "app-tooltip", "window", "dialog"]
t = {k: float(v.rstrip("px")) for k, v in token_values(repo, sassc, names).items()}
got = json.load(open(sys.argv[3]))
want = {
    "button": t["button"], "linked-first": t["button"],
    "linked-middle": 0, "linked-last": 0, "entry": t["entry"], "spinbutton": t["entry"],
    "switch": t["switch"], "switch-knob": t["round"], "check": t["checkbox"],
    "scale-trough": t["slider"], "progress-trough": t["bar"], "popover": t["popover"],
    "menu": t["popover"], "menu-frame": t["popover"], "tooltip": t["app-tooltip"],
    "window-frame": t["window"], "window-frame-maximized": 0, "dialog-frame": t["dialog"],
}
bad = [f"{k}: GTK3 computes {got.get(k)}, want {v:g}" for k, v in want.items()
       if got.get(k) is None or abs(got[k] - v) > 0.5]
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
}

# Title bar buttons (close, minimize, maximize) follow $radius-titlebutton,
# as GTK3 draws them (tests/headless/gtk3_probe.py reads the pixels). Round:
# Yaru's own circles, 24px like GTK4's (a radius on Yaru's 30px button box
# would draw a bigger one). Otherwise dusk swaps Yaru's round gradient for a
# flat tint (0.1, as in Yaru; none in unfocused windows) with that radius.
test_gtk3_title_buttons_follow_token() {
  local out; out=$(mktemp -d)
  "$REPO/tools/probe-gtk3.sh" "$out" || fail "GTK3 probe failed: $(tail -3 "$out/probe.log")"
  python3 - "$REPO" "${SASSC:-sassc}" "$out/gtk3.json" <<'PY'
import json, sys
repo, sassc = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{repo}/tests/headless")
from tokens import token_values
token = token_values(repo, sassc, ["titlebutton"])["titlebutton"]
got = json.load(open(sys.argv[3]))
shape = got["titlebutton-shape"]
bad = []
if token.endswith("%"):
    if not (shape["width"] > 0 and abs(shape["width"] - shape["height"]) <= 1 and not shape["corner"]):
        bad.append(f"close button drawn {shape}, want a circle (token {token})")
else:
    if got["titlebutton-image"]:
        bad.append("focused close button still has Yaru's round gradient")
    if abs(got["titlebutton-alpha"] - 0.1) > 0.01:
        bad.append(f"focused close button tint alpha {got['titlebutton-alpha']}, want 0.1")
    if got["titlebutton-backdrop-image"] or got["titlebutton-backdrop-alpha"] > 0.01:
        bad.append(f"unfocused close button has a background: {got['titlebutton-backdrop-image']}, "
                   f"{got['titlebutton-backdrop-alpha']}")
    if abs(got["titlebutton"] - float(token.rstrip("px"))) > 0.5:
        bad.append(f"close button radius {got['titlebutton']}, want {token}")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
}

# Both ways of the token, built from a copy of src/: round keeps Yaru's own
# circles (dusk adds no tint), anything else adds the flat tints.
test_gtk3_titlebutton_token_switches_tint() {
  local tmp; tmp=$(mktemp -d)
  cp -r "$REPO/src" "$tmp/src"
  build_with() {
    sed -i "s/^\$radius-titlebutton: [^;]*;/\$radius-titlebutton: $1;/" "$tmp/src/_tokens.scss"
    grep -q "^\$radius-titlebutton: $1;" "$tmp/src/_tokens.scss" || fail "no \$radius-titlebutton token"
    "${SASSC:-sassc}" -I "$tmp/src" "$tmp/src/gtk3.scss" > "$tmp/$2.css"
  }
  build_with '$r-circle' round
  assert_not_contains "$tmp/round.css" "alpha(currentColor, 0.1)"
  build_with '$r-sm' square
  assert_contains "$tmp/square.css" "alpha(currentColor, 0.1)"
}
