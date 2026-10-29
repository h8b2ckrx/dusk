# Real GNOME Shell, headless and isolated from the desktop
# (tools/headless-probe.sh). Slow: about 15 seconds per style.

# check_flush OUTDIR: in every sample dialog, and in Shell's own Log Out and
# Power Off dialog (created before extensions load), the buttons touch the
# dialog's left, right and bottom edges, with exactly a 1px gap between
# neighbours ($dialog-divider-width).
# check_stock_dialogs PROBE_DIR: dialogs keep Yaru 26.04's own layout
# (decision 23): Shell's 12px gaps between separate buttons, which don't
# reach the dialog's edges, with dusk's corner tokens on the dialog and its
# buttons. With dusk disabled, the gap is still Shell's.
check_stock_dialogs() {
  python3 - "$REPO" "${SASSC:-sassc}" "$1/result.json" <<'EOF'
import json, sys
repo, sassc = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{repo}/tests/headless")
from tokens import token_values
t = {k: float(v.rstrip("px")) for k, v in token_values(repo, sassc, ["dialog", "dialog-button"]).items()}
results = json.load(open(sys.argv[3]))
for key in ("workspace", "workspace-disabled", "app-grid", "app-grid-disabled", "lock",
            "search", "search-disabled", "search-on-screen-disabled", "search-reenabled", "search-after-dnd"):
    results.pop(key, None)  # checked by their own tests
assert set(results) == {"1", "2", "3", "logout", "poweroff", "logout-disabled"}, results.keys()
assert results.pop("logout-disabled")["spacing"] == 12, "Shell's gap changed with dusk disabled"
for n, r in results.items():
    d, b = r["dialog"], r["buttons"]
    assert len(b) == int(n) if n.isdigit() else len(b) >= 2, (n, len(b))
    assert r["spacing"] == 12, (n, "spacing", r["spacing"])
    gaps = [b[i + 1]["x"] - (b[i]["x"] + b[i]["w"]) for i in range(len(b) - 1)]
    assert all(abs(g - 12) < 0.01 for g in gaps), (n, "gaps", gaps)
    assert b[0]["x"] > d["x"] + 1 and b[-1]["x"] + b[-1]["w"] < d["x"] + d["w"] - 1, (n, "buttons reach the edges")
    assert all(btn["y"] + btn["h"] < d["y"] + d["h"] - 1 for btn in b), (n, "buttons reach the bottom")
    assert abs(d["radius"] - t["dialog"]) < 0.5, (n, "dialog radius", d["radius"], t["dialog"])
    assert all(abs(btn["radius"] - t["dialog-button"]) < 0.5 for btn in b), (n, "button radius", [x["radius"] for x in b])
EOF
}

# probe_dir SCHEME [dock]: a finished probe run for the current code, reused
# across tests while src/, extension/, tests/headless/, the probe tool and the
# installed system (stock_key) are unchanged.
# "dock" also loads Ubuntu Dock, laid out like the owner's (bottom, not
# extended, shrink); "accent" picks the blue accent instead of slate.
probe_dir() {
  local key out variant="${2:-}"
  key=$({ cd "$REPO" && find src extension tests/headless tools/headless-probe.sh -type f \
    ! -name 'stylesheet-*.css' -print0 | sort -z | xargs -0 sha1sum; stock_key; } \
    | sha1sum | cut -c1-16)
  out="${TMPDIR:-/tmp}/dusk-probe-$key-$1${variant:+-$variant}"
  if [ "$(cat "$out/done" 2> /dev/null)" != ok ]; then
    local extra="" settings=""
    if [ "$variant" = accent ]; then
      settings="org.gnome.desktop.interface accent-color blue"
    fi
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

test_headless_dark_dialogs_stock_layout() {
  check_stock_dialogs "$(probe_dir dark)" || fail "dark dialogs aren't 26.04's layout"
}

test_headless_light_dialogs_stock_layout() {
  check_stock_dialogs "$(probe_dir light)" || fail "light dialogs aren't 26.04's layout"
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
# those on screen at the time; enabling it again resizes the results Shell
# kept.
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
again = results.get("search-reenabled")
if not again or not again["apps"] or any(s != want for s in again["apps"]):
    bad.append(f"after enabling dusk again, app results at {again and again['apps']}, want {want}px")
print("\n".join(bad))
sys.exit(1 if bad else 0)
EOF
}

# Search's app results keep the app grid's size alongside Ubuntu Dock, which
# takes its own search patch off and puts it back whenever Do Not Disturb
# changes (seen live: back at 64px after a Do Not Disturb toggle).
test_headless_search_icons_survive_ubuntu_dock() {
  local out; out=$(probe_dir dark dock)
  python3 - "$out/result.json" "$REPO/extension/stylesheet-dark.css" <<'EOF'
import json, re, sys
results = json.load(open(sys.argv[1]))
want = int(re.search(r"-dusk-app-icon-size: (\d+)px", open(sys.argv[2]).read()).group(1))
bad = []
for key in ("search", "search-after-dnd"):
    got = results.get(key)
    if not got or not got["apps"] or any(s != want for s in got["apps"]):
        bad.append(f"{key}: app results at {got and got['apps']}, want {want}px")
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

# check_chunk_colors CHUNKS SELECTOR...: in dark and light, every element whose
# color a row of CHUNKS decides shows that row's 24.04 value (decision 22),
# its labels stay legible (contrast 4.5), and the SELECTORS are on screen.
check_chunk_colors() {
  local chunks="$1" mode out yaru on
  shift
  # The chunks switched on in src/_tokens.scss (what the stylesheet has).
  on=$(sed -n 's/^\$shell-color-chunks: (\(.*\));/\1/p' "$REPO/src/_tokens.scss" \
    | tr ',' '\n' | sed -n 's/ *\([0-9]\): true/\1/p' | paste -sd, -)
  for mode in dark light; do
    out=$(probe_dir "$mode")
    yaru=$("yaru_${mode}_css")
    "$REPO/tests/headless/colors.py" expect "$out/snapshots.json" "$yaru" \
      "$REPO/docs/inventory-shell-colors.tsv" "$mode" "$chunks" "$on" || fail "$mode: chunk $chunks colors aren't 24.04's"
    "$REPO/tests/headless/colors.py" contrast "$out/snapshots.json" "$yaru" \
      "$REPO/docs/inventory-shell-colors.tsv" "$mode" "$chunks" "$on" || fail "$mode: chunk $chunks text isn't legible"
    "$REPO/tests/headless/cascade.py" unmatched "$out/snapshots.json" "$@" || fail "$mode: chunk $chunks surfaces not on screen"
  done
}

# Chunk 1: menus and quick settings, and the controls drawn on them.
test_headless_popup_colors_follow_2404() {
  check_chunk_colors 1 .popup-menu-content .popup-menu-item .quick-settings .quick-toggle-menu .button
}

# The accent still follows the Settings picker: a checked quick toggle with
# the blue accent isn't the color it has with the default (slate) one.
test_headless_colors_follow_accent() {
  python3 - "$(probe_dir dark)/snapshots.json" "$(probe_dir dark accent)/snapshots.json" <<'EOF' || fail "the accent doesn't follow the picker"
import json, sys
def checked(path):
    for rec in json.load(open(path))["quick-settings"]:
        if "quick-toggle" in rec["classes"] and "checked" in rec["pseudo"] and rec.get("colors"):
            return rec["colors"][0]
slate, blue = checked(sys.argv[1]), checked(sys.argv[2])
assert slate and blue, ("no checked quick toggle", slate, blue)
assert slate != blue, ("same color with both accents", slate)
EOF
}

# Chunk 2: notifications and the date menu.
test_headless_notification_colors_follow_2404() {
  check_chunk_colors 2 .message .calendar .events-button .datemenu-today-button
}

# Chunk 3: dialogs, OSDs, switchers, tooltips and the screenshot panel. The
# switchers and tooltips need windows and dash hovers the headless session
# doesn't have; the mirror and shadowing tests cover their rules.
test_headless_dialog_osd_colors_follow_2404() {
  check_chunk_colors 3 .modal-dialog .modal-dialog-button .osd-window .screenshot-ui-panel
}

# A menu's separator and its items you can't click draw no background of
# their own, in dark and light (24.04 and 26.04 both: transparent !important).
test_headless_inactive_menu_items_have_no_background() {
  local mode
  for mode in dark light; do
    python3 - "$(probe_dir "$mode")/snapshots.json" <<'PY' || fail "$mode: inactive menu items have a background"
import json, sys
recs = json.load(open(sys.argv[1]))["panel-menu"]
found = [r for r in recs if r.get("colors") and (
    "popup-separator-menu-item" in r["classes"]
    or ("popup-menu-item" in r["classes"] and "insensitive" in r["pseudo"]))]
assert len(found) >= 2, ("separator and inactive item not on screen", len(found))
bad = [(r["classes"], r["colors"][0]) for r in found if r["colors"][0][3] != 0]
assert not bad, bad
PY
  done
}
