# build/gtk4.css against docs/inventory-gtk4.tsv (design decision: mirror
# every libadwaita radius rule, in libadwaita's order, values from tokens).

# Every inventory row is in build/gtk4.css with its token's value, and the
# rows keep libadwaita's order (tests/headless/mirror_check.py).
test_gtk4_mirrors_inventory() {
  (cd "$REPO" && ./build.sh > /dev/null)
  python3 - "$REPO" "${SASSC:-sassc}" <<'EOF'
import sys
repo, sassc = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{repo}/tests/headless")
from mirror_check import problems
found = problems(repo, sassc, f"{repo}/docs/inventory-gtk4.tsv", f"{repo}/build/gtk4.css", window_var=True)
print("\n".join(found[:20]) + (f"\n… {len(found)} problems" if len(found) > 20 else ""))
sys.exit(1 if found else 0)
EOF
}

# gtk_probe_dir: a finished tools/headless-gtk.sh run for the current code,
# reused while src/, docs/inventory-gtk4.tsv, tests/headless/ and the
# installed system (stock_key) are unchanged.
gtk_probe_dir() {
  local key out
  key=$({ cd "$REPO" && find src docs/inventory-gtk4.tsv tests/headless tools/headless-gtk.sh -type f \
    -print0 | sort -z | xargs -0 sha1sum; stock_key; } | sha1sum | cut -c1-16)
  out="${TMPDIR:-/tmp}/dusk-gtk-$key-dark"
  if [ ! -s "$out/gtk4.json" ] || [ ! -s "$out/gtk4-plain.json" ]; then
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
    # A pill token (999px) is drawn capped at half the widget's height.
    if all(c >= 100 for c in corners):
        return round_(name)
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

# Window buttons (close, minimize, maximize) follow $radius-titlebutton, in
# libadwaita apps and in plain GTK4, which draws X11 apps' title bars (Mutter's
# frames helper). Both draw the round tint on the button's icon. Round: a
# circle (the shape drawn is square, its corners at least half its size).
test_headless_gtk4_window_buttons_follow_token() {
  local out; out=$(gtk_probe_dir)
  python3 - "$REPO" "${SASSC:-sassc}" "$out" <<'EOF'
import json, sys
repo, sassc, out = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, f"{repo}/tests/headless")
from tokens import token_values
token = token_values(repo, sassc, ["titlebutton"])["titlebutton"]
bad = []
for name in ("gtk4.json", "gtk4-plain.json"):
    got = json.load(open(f"{out}/{name}")).get("titlebutton-image", {})
    shape = got.get("shape")
    if not shape:
        bad.append(f"{name}: close button icon not measured ({got})")
        continue
    r, (w, h) = shape["radii"], shape["bounds"]
    if token.endswith("%"):
        if abs(w - h) > 0.5 or min(r) < w / 2 - 0.5:
            bad.append(f"{name}: close button icon drawn {w}x{h} with corners {r}, want a circle")
    elif any(abs(c - float(token.rstrip("px"))) > 0.5 for c in r):
        bad.append(f"{name}: close button icon drawn {r}, want {token}")
print("\n".join(bad))
sys.exit(1 if bad else 0)
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

# The inventory still matches the installed libadwaita (your accent's Yaru
# stylesheet, found with gresource list; the radii are the same for every
# accent and in light and dark).
test_gtk4_inventory_matches_installed_libadwaita() {
  local lib=/usr/lib/x86_64-linux-gnu/libadwaita-1.so.0 accent res css
  accent=$(gtk_theme)
  accent=${accent%-dark}
  accent=${accent#Yaru}
  accent=${accent#-}
  res=$(gresource list "$lib" | grep -xF "/org/gnome/Adwaita/styles/default-dark-yaru-${accent:-default}.css") \
    || fail "no libadwaita Yaru stylesheet for $(gtk_theme) in $lib"
  css=$(mktemp)
  gresource extract "$lib" "$res" > "$css"
  assert_inventory_current "$REPO/docs/inventory-gtk4.tsv" "$css" --exclude adaptive-preview
}
