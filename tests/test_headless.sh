# Real GNOME Shell, headless and isolated from the desktop
# (tools/headless-probe.sh). Slow: about 15 seconds per style.

# check_flush OUTDIR: in every sample dialog, and in Shell's own Log Out and
# Power Off dialog (created before extensions load), the buttons touch the
# dialog's left, right and bottom edges, with exactly a 1px gap between
# neighbours ($dialog-divider-width).
check_flush() {
  python3 - "$1/result.json" <<'EOF'
import json, sys
results = json.load(open(sys.argv[1]))
for key in ("workspace", "workspace-disabled"):
    results.pop(key)  # checked by test_headless_workspace_corners_follow_stylesheet
for key in ("app-grid", "app-grid-disabled"):
    results.pop(key, None)  # checked by test_headless_app_grid_icons_follow_stylesheet
results.pop("lock", None)  # checked by test_headless_lock_screen_follows_tokens
for key in ("search", "search-disabled", "search-on-screen-disabled"):
    results.pop(key, None)  # checked by test_headless_search_icons_follow_stylesheet
assert set(results) == {"1", "2", "3", "logout", "poweroff", "logout-disabled"}, results.keys()
# With dusk disabled, Shell's own 12px gap is back (extension.js disable()).
assert results.pop("logout-disabled")["spacing"] == 12, "disable() did not restore the gap"
for n, r in results.items():
    d, b = r["dialog"], r["buttons"]
    assert len(b) == int(n) if n.isdigit() else len(b) >= 2, (n, len(b))
    gaps = [b[i + 1]["x"] - (b[i]["x"] + b[i]["w"]) for i in range(len(b) - 1)]
    assert all(abs(g - 1) < 0.01 for g in gaps), (n, "gaps", gaps)
    assert abs(b[0]["x"] - d["x"]) < 0.01, (n, "left edge")
    assert abs((b[-1]["x"] + b[-1]["w"]) - (d["x"] + d["w"])) < 0.01, (n, "right edge")
    for btn in b:
        assert abs((btn["y"] + btn["h"]) - (d["y"] + d["h"])) < 0.01, (n, "bottom edge")
EOF
}

# probe_dir SCHEME [dock]: a finished probe run for the current code, reused
# across tests while src/, extension/, tests/headless/, the probe tool and the
# installed system (stock_key) are unchanged.
# "dock" also loads Ubuntu Dock, laid out like the owner's (bottom, not
# extended, shrink).
probe_dir() {
  local key out variant="${2:-}"
  key=$({ cd "$REPO" && find src extension tests/headless tools/headless-probe.sh -type f \
    ! -name 'stylesheet-*.css' -print0 | sort -z | xargs -0 sha1sum; stock_key; } \
    | sha1sum | cut -c1-16)
  out="${TMPDIR:-/tmp}/dusk-probe-$key-$1${variant:+-$variant}"
  if [ "$(cat "$out/done" 2> /dev/null)" != ok ]; then
    local extra="" settings=""
    if [ "$variant" = dock ]; then
      extra=ubuntu-dock@ubuntu.com
      settings="org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM"
      settings+=";org.gnome.shell.extensions.dash-to-dock extend-height false"
      settings+=";org.gnome.shell.extensions.dash-to-dock custom-theme-shrink true"
    fi
    DUSK_EXTRA_EXTENSIONS="$extra" DUSK_GSETTINGS="$settings" \
      "$REPO/tools/headless-probe.sh" "$out" "$1" > /dev/null 2>&1 \
      || fail "headless probe failed ($1 $variant): $(cat "$out/error.txt" 2> /dev/null)"
  fi
  echo "$out"
}

test_headless_dark_dialog_buttons_flush() {
  check_flush "$(probe_dir dark)"
}

test_headless_light_dialog_buttons_flush() {
  check_flush "$(probe_dir light)"
}

# The stylesheet Shell loads for Yaru (dark), extracted for the cascade check.
yaru_dark_css() {
  local css; css=$(mktemp --suffix=.css)
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    /org/gnome/shell/theme/Yaru/gnome-shell-dark.css > "$css"
  echo "$css"
}

# The light one (Shell loads it in light mode).
yaru_light_css() {
  local css; css=$(mktemp --suffix=.css)
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    /org/gnome/shell/theme/Yaru/gnome-shell.css > "$css"
  echo "$css"
}

# In every probed UI state, each widget's computed radius is what Yaru plus
# our stylesheet predict (so our rules take effect where they should), and
# every chunk selector expected on screen matches a real element.
test_headless_shell_radii_match_stylesheets() {
  local out; out=$(probe_dir dark)
  local yaru; yaru=$(yaru_dark_css)
  "$REPO/tests/headless/cascade.py" check "$out/snapshots.json" "$yaru" \
    "$REPO/extension/stylesheet-dark.css" || fail "computed radii differ from the stylesheets"
  # Our stylesheet beats Yaru's outright, so a general rule of ours must not
  # erase one of Yaru's more specific special cases: re-assert those instead.
  "$REPO/tests/headless/cascade.py" clobbered "$out/snapshots.json" "$yaru" \
    "$REPO/extension/stylesheet-dark.css" || fail "our rules override Yaru special cases"
  # An element with several classes keeps the meaning stock gave it, unless
  # the drift was reviewed (listed here with the reason).
  "$REPO/tests/headless/cascade.py" drift "$out/snapshots.json" "$yaru" \
    "$REPO/extension/stylesheet-dark.css" \
    '.popup-menu-content=>.quick-settings' \
    || fail "elements changed which rule decides their radius"
  # Allowed above: the quick settings panel is also a menu; it has its own
  # approved token (docs/inventory-shell.md, chunk A).
  local selectors=()
  mapfile -t selectors < <(grep -hvE '^(# |~)|^$' "$REPO"/tests/headless/chunk-*.selectors)
  "$REPO/tests/headless/cascade.py" unmatched "$out/snapshots.json" "${selectors[@]}" \
    || fail "selectors not found on screen"
}

# The overview's workspace wallpaper is clipped at a radius Shell sets in code
# (30px); extension.js makes it follow .workspace-background's radius from our
# stylesheet, and gives Shell's back on disable. Measured on the real clip.
test_headless_workspace_corners_follow_stylesheet() {
  local out; out=$(probe_dir dark)
  python3 - "$out/result.json" "$REPO/extension/stylesheet-dark.css" <<'EOF' || fail "workspace corners don't follow the stylesheet"
import json, re, sys
results = json.load(open(sys.argv[1]))
css = open(sys.argv[2]).read()
ours = float(re.search(r"\.workspace-background \{[^}]*border-radius: (\d+)px", css).group(1))
on, off = results["workspace"], results["workspace-disabled"]
assert on and off, ("no workspace backgrounds measured", on, off)
for w in on:
    assert w["state"] > 0.99, ("overview not fully open", w)
    assert abs(w["css"] - ours) < 0.5, ("stylesheet radius not applied", w, ours)
    assert abs(w["clip"] - ours) < 0.5, ("wallpaper clip is not ours", w, ours)
for w in off:
    assert abs(w["clip"] - 30 * w["state"]) < 0.5, ("Shell's 30px not restored", w)
EOF
}

# Ubuntu Dock's corners follow the theme (design decision 17). With the dock
# laid out like the owner's, Shell's computed radii match Yaru plus our
# stylesheet (in the Ubuntu session the dock's own stylesheet is empty), the
# dock selectors expected on screen are there, and the background and the
# icon highlight carry our dock tokens.
test_headless_dock_follows_tokens() {
  local out; out=$(probe_dir dark dock)
  local yaru; yaru=$(yaru_dark_css)
  "$REPO/tests/headless/cascade.py" check "$out/snapshots.json" "$yaru" \
    "$REPO/extension/stylesheet-dark.css" || fail "dock radii differ from the stylesheets"
  local selectors=()
  mapfile -t selectors < <(grep -hvE '^(# |~)|^$' "$REPO/tests/headless/dock.selectors")
  "$REPO/tests/headless/cascade.py" unmatched "$out/snapshots.json" "${selectors[@]}" \
    || fail "dock selectors not found on screen"
  python3 - "$out/snapshots.json" "$REPO/extension/stylesheet-dark.css" <<'EOF' || fail "dock tokens not applied"
import json, re, sys
css = open(sys.argv[2]).read()
def px(selector):
    return int(re.search(re.escape(selector) + r"[^{]*\{[^}]*?border-radius: (\d+)px", css).group(1))
dock = px("#dashtodockContainer.bottom.shrink #dash .dash-background")
item = px("#dashtodockContainer.bottom .dash-item-container .overview-tile .overview-icon")
recs = json.load(open(sys.argv[1]))["desktop"]
def under_dock(i):
    while i >= 0:
        if recs[i]["id"] == "dashtodockContainer":
            return True
        i = recs[i]["parent"]
    return False
bg = [r for i, r in enumerate(recs) if "dash-background" in r["classes"] and under_dock(i)]
icons = [r for i, r in enumerate(recs) if "overview-icon" in r["classes"] and under_dock(i)]
assert bg and icons, ("dock not on screen", len(bg), len(icons))
assert all(r["radii"] == [dock] * 4 for r in bg), ([r["radii"] for r in bg], dock)
assert all(r["radii"] == [item] * 4 for r in icons), ({tuple(r["radii"]) for r in icons}, item)
EOF
}

# Shell picks the app grid's icon size in code (64px on this screen);
# extension.js makes the main grid use the stylesheet's -dusk-app-icon-size
# (decision 20), on the real headless Shell. Disabling dusk gives Shell its
# own size back.
test_headless_app_grid_icons_follow_stylesheet() {
  local out; out=$(probe_dir dark)
  python3 - "$out/result.json" "$REPO/extension/stylesheet-dark.css" <<'EOF'
import json, re, sys
results = json.load(open(sys.argv[1]))
css = open(sys.argv[2]).read()
m = re.search(r"-dusk-app-icon-size: (\d+)px", css)
bad = []
if not m:
    bad.append("no -dusk-app-icon-size in the stylesheet")
want = int(m.group(1)) if m else None
on, off = results.get("app-grid"), results.get("app-grid-disabled")
if not on or not off:
    bad.append(f"app grid not measured: {on}, {off}")
else:
    if on["layout"] != want or on["first"] != want:
        bad.append(f"with dusk: grid {on['layout']}px, first icon {on['first']}px, want {want}px")
    if off["layout"] == want or off["layout"] > 64:
        bad.append(f"after disabling dusk: grid {off['layout']}px, want Shell's own (64px or less)")
print("\n".join(bad))
sys.exit(1 if bad else 0)
EOF
}

# The lock screen follows dusk (decision 21): dusk stays on in Shell's
# lock-screen session mode, and the unlock dialog, its password prompt and
# the locked top bar get Yaru plus our stylesheet. The probe shows them
# without locking for real (see tests/headless/dusk-probe@local).
test_headless_lock_screen_follows_tokens() {
  local out; out=$(probe_dir dark)
  python3 - "$out/result.json" <<'EOF' || fail "dusk is not on while the screen is locked"
import json, sys
lock = json.load(open(sys.argv[1])).get("lock")
assert lock and lock["duskActive"], lock
EOF
  local selectors=()
  mapfile -t selectors < <(grep -hvE '^(# |~)|^$' "$REPO/tests/headless/lock.selectors")
  "$REPO/tests/headless/cascade.py" unmatched "$out/snapshots.json" "${selectors[@]}" \
    || fail "lock screen selectors not found on screen"
}

# Search results' icons match the app grid's (decision 20): app results are
# app grid icons, which Shell sizes in code, and extension.js gives them the
# stylesheet's -dusk-app-icon-size; other results (system actions) read CSS
# icon-size. Disabling dusk gives app results Shell's own size back, also
# those on screen at the time.
test_headless_search_icons_follow_stylesheet() {
  local out; out=$(probe_dir dark)
  python3 - "$out/result.json" "$REPO/extension/stylesheet-dark.css" <<'EOF'
import json, re, sys
results = json.load(open(sys.argv[1]))
want = int(re.search(r"-dusk-app-icon-size: (\d+)px", open(sys.argv[2]).read()).group(1))
on, off = results.get("search"), results.get("search-disabled")
bad = []
if not on or not on["apps"] or not on["others"]:
    bad.append(f"search results not measured: {on}")
else:
    if any(s != want for s in on["apps"]):
        bad.append(f"app results drawn at {on['apps']}, want {want}px")
    if any(s != want for s in on["others"]):
        bad.append(f"other results drawn at {on['others']}, want {want}px")
if not off or not off["apps"] or any(s == want or s > 64 for s in off["apps"]):
    bad.append(f"after disabling dusk, app results at {off and off['apps']}, want Shell's own (64px or less)")
kept = results.get("search-on-screen-disabled")
if not kept or not kept["apps"] or any(s == want or s > 64 for s in kept["apps"]):
    bad.append(f"results on screen while dusk was disabled kept {kept and kept['apps']}, want Shell's own")
print("\n".join(bad))
sys.exit(1 if bad else 0)
EOF
}

# In every probed UI state, in dark and light, each widget's computed colors
# (background, text, border, shadow) are what Yaru plus our stylesheet
# predict, and no general color rule of ours erases a more specific Yaru one
# (decision 22; tests/headless/colors.py).
test_headless_shell_colors_match_stylesheets() {
  local mode out yaru
  for mode in dark light; do
    out=$(probe_dir "$mode")
    yaru=$("yaru_${mode}_css")
    "$REPO/tests/headless/colors.py" check "$out/snapshots.json" "$yaru" \
      "$REPO/extension/stylesheet-$mode.css" || fail "$mode: computed colors differ from the stylesheets"
    "$REPO/tests/headless/colors.py" clobbered "$out/snapshots.json" "$yaru" \
      "$REPO/extension/stylesheet-$mode.css" || fail "$mode: our color rules override Yaru special cases"
  done
}
