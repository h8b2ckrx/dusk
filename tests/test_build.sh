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
# its 24.04 value and that value's !important (24.04's own where the value is
# 24.04's, so a 26.04 !important can't make 24.04's state rules dead; 26.04's
# for derived, accent, unset and kept rows), in the inventory's order.
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
        if "!important" in old:
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
# Rules under Blur my Shell's style classes re-assert its look instead
# (decision 25; test_blur_my_shell_entries_keep_its_look checks them).
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
        if re.search(r"\.(overview-components|appfolder-dialogs)-", sel):
            continue
        if outside.search(sel) and norm(value) != norm(stock.get((sel, prop), "")):
            bad.append(f"{mode}: {sel} {prop}: {value} (stock: {stock.get((sel, prop))})")
print("\n".join(bad[:20]))
sys.exit(1 if bad else 0)
PY
}

# Static, for states the probe doesn't show (hover, pressed, and the lock
# screen's notifications): with every chunk on, no color rule of ours would
# erase a more specific Yaru one for the same slot. Only the login screen,
# which never loads dusk, is left out.
test_shell_colors_shadow_nothing() {
  local tmp; tmp=$(mktemp -d)
  shell_colors_on "$tmp"
  local mode
  for mode in dark light; do
    gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
      "/org/gnome/shell/theme/Yaru/gnome-shell$([ "$mode" = dark ] && echo -dark).css" > "$tmp/stock.css"
    "$REPO/tests/headless/colors.py" shadowed "$tmp/stock.css" "$tmp/$mode.css" \
      '#panel\.login-screen|\.login-dialog[ ,{]|\.login-dialog$|login-dialog-user-list|login-dialog-not-listed|web-login-dialog|\.qr-code' \
      > "$tmp/shadowed-$mode.txt" || fail "$mode: $(wc -l < "$tmp/shadowed-$mode.txt") rules erased, e.g. $(head -3 "$tmp/shadowed-$mode.txt")"
  done
}

# Blur my Shell's own look wins on the overview's search entry and an app
# folder's name entry (owner, decision 25): with each of its styles on, in
# dark and light and in every state dusk's rules style, the colors are what
# Yaru plus Blur my Shell alone give. Its stylesheet loads before ours, so
# ours come later in the cascade. A Blur my Shell update that changes its
# colors fails here too.
test_blur_my_shell_entries_keep_its_look() {
  local blur mode
  for blur in "$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx" \
      /usr/share/gnome-shell/extensions/blur-my-shell@aunetx; do
    [ -f "$blur/stylesheet.css" ] && break
  done
  [ -f "$blur/stylesheet.css" ] || { fail "Blur my Shell isn't installed"; return; }
  build > /dev/null
  for mode in dark light; do
    local name=gnome-shell.css stock; stock=$(mktemp --suffix=.css)
    [ "$mode" = dark ] && name=gnome-shell-dark.css
    gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
      "/org/gnome/shell/theme/Yaru/$name" > "$stock"
    python3 - "$REPO/tests/headless" "$stock" "$blur/stylesheet.css" "$REPO/extension/stylesheet-$mode.css" <<'EOF' \
      || fail "$mode: Blur my Shell's entries changed by dusk"
import sys
sys.path.insert(0, sys.argv[1])
import colors
yaru = colors.parse_color_rules(open(sys.argv[2]).read(), origin=0)
blur = colors.parse_color_rules(open(sys.argv[3]).read(), origin=1)
dusk = colors.parse_color_rules(open(sys.argv[4]).read(), origin=1)
for rule in dusk:  # loaded after Blur my Shell's
    origin, important, specificity, order = rule.key
    rule.key = (origin, important, specificity, order + 10 ** 6)
names = ["background", "text", "border", "shadow"]
bad = []
for style in ("transparent", "light", "dark"):
    entries = [f"#uiGroup.overview-components-{style} StBoxLayout StEntry.search-entry",
               f"StBoxLayout.app-folder-dialog.appfolder-dialogs-{style} StBoxLayout.folder-name-container StEntry.folder-name-entry"]
    for entry in entries:
        for state in ((), ("hover",), ("focus",), ("hover", "focus"), ("insensitive",)):
            records = colors.element(entry, state)
            want = colors.predict(records, yaru + blur)[-1]
            got = colors.predict(records, yaru + blur + dusk)[-1]
            for slot in range(4):
                if want[slot] != got[slot]:
                    bad.append(f"{style} {entry.split()[-1]}{''.join(':' + p for p in state)} {names[slot]}: "
                               f"Blur my Shell's {want[slot]}, with dusk {got[slot]}")
print("\n".join(bad[:12]))
sys.exit(1 if bad else 0)
EOF
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
# 2026-10-30, §5). Built unchanged, the copy gives exactly the installed
# Yaru's rules, in order: the copy is complete and the build matches Ubuntu's.
test_shell_theme_copy_matches_installed_yaru() {
  local mode d
  build > /dev/null
  for mode in dark light; do
    d=$(diff <(css_rules "$(stock_shell_theme "$mode")") <(css_rules "$REPO/extension/theme/dusk-$mode.css")) \
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
