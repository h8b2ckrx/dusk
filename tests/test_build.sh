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
