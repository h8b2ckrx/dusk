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

run_probe() {
  local out="$1" scheme="$2"
  "$REPO/tools/headless-probe.sh" "$out" "$scheme" \
    || fail "headless probe failed ($scheme): $(cat "$out/error.txt" 2> /dev/null)"
}

test_headless_dark_dialog_buttons_flush() {
  local out; out=$(mktemp -d)
  run_probe "$out" dark
  check_flush "$out"
}

test_headless_light_dialog_buttons_flush() {
  local out; out=$(mktemp -d)
  run_probe "$out" light
  check_flush "$out"
}
