# build.sh outputs, and the spec's non-goals checked on the compiled CSS.

SHELL_CSS=(extension/theme/dusk-dark.css extension/theme/dusk-light.css)
GTK_CSS=(build/gtk4.css build/gtk3.css)

build() {
  (cd "$REPO" && ./build.sh > /dev/null)
}

# The two GTK stylesheets and dusk's Shell theme, and no extension stylesheet:
# Shell would load one on top of dusk's theme (design 2026-10-30).
test_build_writes_four_files() {
  build
  for f in "${GTK_CSS[@]}" "${SHELL_CSS[@]}"; do
    [ -f "$REPO/$f" ] || fail "missing $f"
  done
  ! ls "$REPO"/extension/stylesheet*.css > /dev/null 2>&1 || fail "an extension stylesheet is left in extension/"
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

# css_rules FILE: FILE's rules in order, one per line ("selectors { decls }"),
# comments dropped, whitespace normalized, and each url() reduced to its file
# name (the copy resolves images next to the file, Yaru from its resource).
css_rules() {
  python3 - "$1" <<'PY'
import re, sys
css = re.sub(r"/\*.*?\*/", "", open(sys.argv[1]).read(), flags=re.S)
css = re.sub(r'url\(\s*["\']?([^"\')]*?)["\']?\s*\)', lambda m: f'url("{m.group(1).rsplit("/", 1)[-1]}")', css)
for m in re.finditer(r"([^{}]+)\{([^{}]*)\}", css):
    selectors = ", ".join(" ".join(s.split()) for s in m.group(1).split(","))
    decls = "; ".join(" ".join(d.split()) for d in m.group(2).split(";") if d.strip())
    print(f"{selectors} {{ {decls} }}")
PY
}

# stock_shell_theme MODE: the installed Yaru Shell stylesheet for MODE.
stock_shell_theme() {
  local css; css=$(mktemp --suffix=.css)
  local name=gnome-shell.css
  [ "$1" = dark ] && name=gnome-shell-dark.css
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    "/org/gnome/shell/theme/Yaru/$name" > "$css"
  echo "$css"
}

# dusk's Shell theme is built from its copy of Yaru 26.04's source (design
# 2026-10-30, §5). The copy as first committed (Yaru's files, unchanged)
# builds to exactly the installed Yaru's rules, in order: the copy was
# complete and the build matches Ubuntu's. (dusk's edits come after it.)
test_shell_theme_copy_matches_installed_yaru() {
  local mode d first pristine
  first=$(git -C "$REPO" log --diff-filter=A --format=%h -- src/shell-theme/yaru/TAG | tail -1)
  pristine=$(mktemp -d)
  git -C "$REPO" archive "$first" src/shell-theme/yaru | tar -x -C "$pristine"
  for mode in dark light; do
    "$REPO/tools/build-shell-theme.sh" "$pristine/src/shell-theme/yaru" "$mode" "$pristine/$mode.css"
    d=$(diff <(css_rules "$(stock_shell_theme "$mode")") <(css_rules "$pristine/$mode.css")) \
      || fail "$mode: the built copy differs from the installed Yaru (< Yaru, > dusk):
$(head -12 <<< "$d")"
  done
}

# Every image the installed Yaru takes from its theme resource is next to
# dusk's theme files, where they find it.
test_shell_theme_images_present() {
  local mode f missing=""
  build > /dev/null
  for mode in dark light; do
    for f in $(grep -o 'resource:///org/gnome/shell/theme/[^")]*' "$(stock_shell_theme "$mode")" | sed 's|.*/||' | sort -u); do
      [ -f "$REPO/extension/theme/$f" ] || missing+=" $f"
    done
  done
  [ -z "$missing" ] || fail "missing next to the theme:$missing"
}

# Every style class Shell 50's own code uses that the installed Yaru styles
# is styled by dusk's theme too (a widget a later update adds shows here).
test_shell_theme_covers_shell_classes() {
  local lib js out
  build > /dev/null
  lib=$(ls /usr/lib/gnome-shell/libshell-*.so | head -1)
  js=$(mktemp)
  for f in $(gresource list "$lib" | grep '\.js$'); do gresource extract "$lib" "$f"; done > "$js"
  out=$(python3 - "$js" "$(stock_shell_theme dark)" "$REPO/extension/theme/dusk-dark.css" <<'PY'
import re, sys
js = open(sys.argv[1]).read()
classes = set()
for m in re.finditer(r"(?:style_class:\s*|add_style_class_name\(\s*)['\"]([a-z0-9-][a-z0-9 _-]*)['\"]", js):
    classes |= set(m.group(1).split())
def styled(path):
    css = re.sub(r"/\*.*?\*/", "", open(path).read(), flags=re.S)
    return set(re.findall(r"\.([a-zA-Z0-9_-]+)", "".join(m.group(1) for m in re.finditer(r"([^{}]+)\{", css))))
yaru, dusk = styled(sys.argv[2]), styled(sys.argv[3]) if __import__("os").path.exists(sys.argv[3]) else set()
print(" ".join(sorted(c for c in classes if c in yaru and c not in dusk)))
PY
)
  [ -z "$out" ] || fail "classes Yaru styles but dusk's theme doesn't: $out"
}
