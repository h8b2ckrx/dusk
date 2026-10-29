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
