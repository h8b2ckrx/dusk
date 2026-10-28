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

# Lock screen and GDM stay stock (spec §2).
test_no_lock_or_login_selectors() {
  build
  for f in "${SHELL_CSS[@]}"; do
    ! grep -qE 'unlock-dialog|login-dialog|screen-shield' "$REPO/$f" \
      || fail "$f styles the lock or login screen"
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

# The dialog layout applies in light style too, so its button colors must
# exist there (design §5, plan Task 3).
test_light_dialog_has_button_colors() {
  build
  python3 - "$REPO/extension/stylesheet-light.css" <<'PY' || fail "light stylesheet has no dialog button background"
import sys
css = open(sys.argv[1]).read()
for block in css.split("}"):
    selector, _, body = block.partition("{")
    if ".modal-dialog-button" in selector and "background-color" in body:
        sys.exit(0)
sys.exit(1)
PY
}

# Ubuntu 24.04 dialog details (design §6; Yaru 24.04.3 %bubble_button and
# button($style: bubble)), checked on the compiled stylesheets.
test_dialog_matches_2404() {
  build
  python3 - "$REPO/extension" <<'PY' || fail "dialog rules differ from Ubuntu 24.04"
import re, sys
B = ".modal-dialog .modal-dialog-button-box .modal-dialog-button"
# style: (foreground as rgb, as hex, disabled text alpha)
expect = {
    "dark": ("247, 247, 247", "#F7F7F7", "0.5"),
    "light": ("61, 61, 61", "#3D3D3D", "0.4"),
}
ok = True
for style, (fg, fg_hex, dim) in expect.items():
    css = open(f"{sys.argv[1]}/stylesheet-{style}.css").read()
    rules = {}
    for block in css.split("}"):
        sel, _, body = block.partition("{")
        for s in sel.split(","):
            rules.setdefault(" ".join(s.split()), "")
            rules[" ".join(s.split())] += body
    def has(selector, decl):
        global ok
        body = " " + " ".join(rules.get(selector, "").split())
        if decl not in body:
            print(f"{style}: {selector} lacks '{decl}'")
            ok = False
    has(".modal-dialog", f"box-shadow: inset 0 0 0 1px rgba({fg}, 0.15)")
    has(B, "font-weight: normal")
    has(B, f" color: {fg_hex}")
    has(B + ":insensitive", f" color: rgba({fg}, {dim})")
    has(B + ":insensitive", f"background-color: rgba({fg}, 0.17)")
    has(B + ":active:hover", f"background-color: rgba({fg}, 0.19)")
    # Button corners sit 1px inside the dialog's outline: dialog radius - 1.
    dialog = re.search(r"(\d+)px", rules.get(".modal-dialog", "").split("border-radius:")[1]).group(1)
    corner = f"{int(dialog) - 1}px"
    has(B + ":first-child:ltr", f"border-radius: 0 0 0 {corner}")
    has(B + ":last-child:ltr", f"border-radius: 0 0 {corner} 0")
sys.exit(0 if ok else 1)
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
# re-assert it. Lock and login screen rules are skipped: dusk is off there.
test_shell_keeps_yaru_special_cases() {
  build
  local yaru; yaru=$(mktemp --suffix=.css)
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    /org/gnome/shell/theme/Yaru/gnome-shell-dark.css > "$yaru"
  "$REPO/tests/headless/cascade.py" shadowed "$yaru" "$REPO/extension/stylesheet-dark.css" \
    'unlock-screen|login-screen|unlock-dialog|login-dialog|screen-shield' \
    || fail "our rules would erase Yaru special cases"
}
