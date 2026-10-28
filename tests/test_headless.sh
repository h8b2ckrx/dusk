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

# probe_dir SCHEME: a finished probe run for the current code, reused across
# tests while src/, extension/ and tests/headless/ are unchanged.
probe_dir() {
  local key out
  key=$(cd "$REPO" && find src extension tests/headless -type f ! -name 'stylesheet-*.css' \
    -print0 | sort -z | xargs -0 sha1sum | sha1sum | cut -c1-16)
  out="${TMPDIR:-/tmp}/dusk-probe-$key-$1"
  if [ "$(cat "$out/done" 2> /dev/null)" != ok ]; then
    "$REPO/tools/headless-probe.sh" "$out" "$1" > /dev/null 2>&1 \
      || fail "headless probe failed ($1): $(cat "$out/error.txt" 2> /dev/null)"
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
  local selectors=()
  mapfile -t selectors < <(grep -hvE '^(# |~)|^$' "$REPO"/tests/headless/chunk-*.selectors)
  "$REPO/tests/headless/cascade.py" unmatched "$out/snapshots.json" "${selectors[@]}" \
    || fail "selectors not found on screen"
}
