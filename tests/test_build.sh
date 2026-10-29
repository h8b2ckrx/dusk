# build.sh outputs, and the spec's non-goals checked on the compiled CSS.

SHELL_CSS=(extension/stylesheet-dark.css extension/stylesheet-light.css)
GTK_CSS=(build/gtk4.css build/gtk3.css)

build() {
  (cd "$REPO" && ./build.sh > /dev/null)
}

test_build_writes_four_files() {
  build
  for f in "${GTK_CSS[@]}" "${SHELL_CSS[@]}"; do
    [ -f "$REPO/$f" ] || fail "missing $f"
  done
}

test_gtk_outputs_parse() {
  build
  "$REPO/tools/check_gtk_css.py" 4 "$REPO/build/gtk4.css"
  "$REPO/tools/check_gtk_css.py" 3 "$REPO/build/gtk3.css"
}

# Accent always follows the Settings picker (spec §2).
test_no_accent_override() {
  build
  for f in "${GTK_CSS[@]}"; do
    ! grep -qE -- '--accent-(bg-|fg-)?color\s*:|@define-color\s+accent' "$REPO/$f" \
      || fail "$f overrides the accent color"
  done
}

# Blur my Shell owns the top bar's look; we only set radius there (spec §4).
test_no_topbar_background() {
  build
  for f in "${SHELL_CSS[@]}"; do
    python3 - "$REPO/$f" <<'EOF' || fail "$f sets a top bar background"
import sys
css = open(sys.argv[1]).read()
for block in css.split("}"):
    selector, _, body = block.partition("{")
    if "#panel" in selector and "background" in body:
        print(selector.strip())
        sys.exit(1)
EOF
  done
}

# The login screen (GDM) stays stock (spec §2): it never loads dusk, so
# rules for it would be dead weight. The lock screen does follow dusk
# (decision 21); its prompt shares the .login-dialog-button buttons.
test_no_login_screen_selectors() {
  build
  for f in "${SHELL_CSS[@]}"; do
    ! grep -qE '#panel\.login-screen|\.login-dialog[ ,{]|login-dialog-user-list|login-dialog-not-listed|web-login-dialog|\.qr-code' "$REPO/$f" \
      || fail "$f styles the login screen"
  done
}

test_missing_sassc_fails() {
  local out; out=$(mktemp)
  if (cd "$REPO" && SASSC=dusk-no-sassc ./build.sh) > "$out" 2>&1; then
    fail "build.sh succeeded without sassc"
  fi
  assert_contains "$out" "sassc"
}

test_check_gtk_css_rejects_bad_css() {
  local bad; bad=$(mktemp --suffix=.css)
  echo 'button { border-radius: banana; }' > "$bad"
  local v rc
  for v in 3 4; do
    rc=0
    "$REPO/tools/check_gtk_css.py" "$v" "$bad" 2> /dev/null || rc=$?
    assert_eq "$rc" 1 "GTK $v check exit code for invalid CSS"
  done
}

# Dialogs keep Yaru 26.04's own layout (decision 23): dusk sets only their
# corners (and, by chunk, their colors), never padding, spacing, margins,
# fonts or outlines.
test_dialogs_set_only_corners_and_colors() {
  build
  python3 - "$REPO" <<'PY' || fail "dusk changes the dialogs' layout"
import importlib.util, re, sys
repo = sys.argv[1]
sys.path.insert(0, f"{repo}/tests/headless")
import colors
bad = []
for mode in ("dark", "light"):
    css = re.sub(r"/\*.*?\*/", "", open(f"{repo}/extension/stylesheet-{mode}.css").read(), flags=re.S)
    for m in re.finditer(r"([^{}]+)\{([^}]*)\}", css):
        if ".modal-dialog" not in m.group(1):
            continue
        for decl in m.group(2).split(";"):
            prop = decl.partition(":")[0].strip()
            if prop and not (prop.endswith("radius") or prop in colors.PROPS):
                bad.append(f"{mode}: {' '.join(m.group(1).split())[:60]}: {decl.strip()}")
print("\n".join(bad[:10]))
sys.exit(1 if bad else 0)
PY
}

# every_selector_has_radius_rule LIST: each selector in LIST (see
# tests/headless/chunk-*.selectors) has a border-radius rule of its own in
# the compiled dark and light Shell stylesheets.
every_selector_has_radius_rule() {
  build
  python3 - "$REPO/extension" "$1" <<'PY' || fail "missing rules for $(basename "$1")"
import sys
wanted = [l.strip().lstrip("~") for l in open(sys.argv[2]) if l.strip() and not l.startswith("# ")]
ok = True
for style in ("dark", "light"):
    css = open(f"{sys.argv[1]}/stylesheet-{style}.css").read()
    have = set()
    for block in css.split("}"):
        sel, _, body = block.partition("{")
        if "border-radius" in body or "-radius:" in body:
            have.update(" ".join(s.split()) for s in sel.split(","))
    for s in wanted:
        if s not in have:
            print(f"{style}: no radius rule for {s}")
            ok = False
sys.exit(0 if ok else 1)
PY
}

test_shell_chunk_a_rules_present() {
  every_selector_has_radius_rule "$REPO/tests/headless/chunk-a.selectors"
}

# Our stylesheet beats Yaru's outright, so for every Yaru radius rule that is a
# more specific case of one of ours (e.g. square items inside a submenu), we
# re-assert it. Lock and login screen rules are skipped (dusk is off there), and
# so is Looking Glass (out of scope).
test_shell_keeps_yaru_special_cases() {
  build
  local yaru; yaru=$(mktemp --suffix=.css)
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    /org/gnome/shell/theme/Yaru/gnome-shell-dark.css > "$yaru"
  "$REPO/tests/headless/cascade.py" shadowed "$yaru" "$REPO/extension/stylesheet-dark.css" \
    'unlock-screen|login-screen|unlock-dialog|login-dialog|screen-shield|lg-dialog|LookingGlass' \
    || fail "our rules would erase Yaru special cases"
}

test_shell_chunk_b_rules_present() {
  every_selector_has_radius_rule "$REPO/tests/headless/chunk-b.selectors"
}

test_shell_chunk_c_rules_present() {
  every_selector_has_radius_rule "$REPO/tests/headless/chunk-c.selectors"
}

test_shell_dock_rules_present() {
  every_selector_has_radius_rule "$REPO/tests/headless/dock.selectors"
}

# Shell pop-up colors (decision 22): src/_shell-colors.scss (rules) and
# src/_shell-color-values.scss (their 24.04 values) are generated from
# docs/inventory-shell-colors.tsv by tools/mirror-colors.py.

test_shell_colors_generated_up_to_date() {
  diff <("$REPO/tools/mirror-colors.py" "$REPO/docs/inventory-shell-colors.tsv" rules) "$REPO/src/_shell-colors.scss" > /dev/null \
    || fail "src/_shell-colors.scss is stale: run tools/mirror-colors.py docs/inventory-shell-colors.tsv rules > src/_shell-colors.scss"
  diff <("$REPO/tools/mirror-colors.py" "$REPO/docs/inventory-shell-colors.tsv" values) "$REPO/src/_shell-color-values.scss" > /dev/null \
    || fail "src/_shell-color-values.scss is stale: run tools/mirror-colors.py docs/inventory-shell-colors.tsv values > src/_shell-color-values.scss"
}

# shell_colors_on DIR: a copy of src/ in DIR with every color chunk switched
# on, compiled to DIR/dark.css and DIR/light.css.
shell_colors_on() {
  cp -r "$REPO/src" "$1/src"
  sed -i -E 's/^\$shell-color-chunks: \(1: (true|false), 2: (true|false), 3: (true|false)\);/$shell-color-chunks: (1: true, 2: true, 3: true);/' "$1/src/_tokens.scss"
  grep -q '^\$shell-color-chunks: (1: true, 2: true, 3: true);' "$1/src/_tokens.scss" || fail "no \$shell-color-chunks switches"
  "${SASSC:-sassc}" --style expanded -I "$1/src" "$1/src/shell-dark.scss" > "$1/dark.css"
  "${SASSC:-sassc}" --style expanded -I "$1/src" "$1/src/shell-light.scss" > "$1/light.css"
}

# With every chunk on, each inventory row is in its mode's stylesheet with
# its 24.04 value (and 26.04's !important), in the inventory's order.
test_shell_colors_mirror_inventory() {
  local tmp; tmp=$(mktemp -d)
  shell_colors_on "$tmp"
  python3 - "$REPO" "$tmp" <<'PY'
import importlib.util, re, sys
repo, tmp = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("ci", f"{repo}/tools/color-inventory.py")
ci = importlib.util.module_from_spec(spec); spec.loader.exec_module(ci)
rows = [l.rstrip("\n").split("\t") for l in open(f"{repo}/docs/inventory-shell-colors.tsv")
        if l.strip() and not l.startswith("# ")]
bad = []
for mode in ("dark", "light"):
    built = list(ci.declarations(open(f"{tmp}/{mode}.css").read()).items())
    where = {key: i for i, (key, _) in enumerate(built)}
    last = -1
    for m, sel, prop, new, old, *_ in rows:
        if m not in ("both", mode):
            continue
        want = " ".join(old.replace("!important", "").split())
        if "!important" in new:
            want += " !important"
        i = where.get((sel, prop))
        if i is None:
            bad.append(f"{mode}: {sel} {prop} missing")
        elif built[i][1] != want:
            bad.append(f"{mode}: {sel} {prop} is '{built[i][1]}', want '{want}'")
        elif i < last:
            bad.append(f"{mode}: {sel} {prop} out of order")
        else:
            last = i
print("\n".join(bad[:20]) + (f"\n… {len(bad)} problems" if len(bad) > 20 else ""))
sys.exit(1 if bad else 0)
PY
}

# Outside the scope (the top bar, dock, lock and login screens, Blur my
# Shell's surfaces, the keyboard), every color dusk sets, with every chunk
# on, is the installed Yaru 26.04 value: only re-asserted, never changed.
test_no_color_rules_outside_scope() {
  local tmp; tmp=$(mktemp -d)
  shell_colors_on "$tmp"
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource /org/gnome/shell/theme/Yaru/gnome-shell-dark.css > "$tmp/stock-dark.css"
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource /org/gnome/shell/theme/Yaru/gnome-shell.css > "$tmp/stock-light.css"
  python3 - "$REPO" "$tmp" <<'PY'
import importlib.util, re, sys
repo, tmp = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("ci", f"{repo}/tools/color-inventory.py")
ci = importlib.util.module_from_spec(spec); spec.loader.exec_module(ci)
outside = re.compile(r"#panel|#dash|\.search-section-content|\.app-folder-dialog|\.unlock-dialog|\.login-dialog|\.keyboard")
bad = []
for mode in ("dark", "light"):
    stock = ci.declarations(open(f"{tmp}/stock-{mode}.css").read())
    norm = lambda v: " ".join(v.replace("!important", "").split()).lower()
    for (sel, prop), value in ci.declarations(open(f"{tmp}/{mode}.css").read()).items():
        if outside.search(sel) and norm(value) != norm(stock.get((sel, prop), "")):
            bad.append(f"{mode}: {sel} {prop}: {value} (stock: {stock.get((sel, prop))})")
print("\n".join(bad[:20]))
sys.exit(1 if bad else 0)
PY
}
