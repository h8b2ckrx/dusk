# Golden records of dusk's Shell look (design 2026-10-30, §6): the colors and
# corners today's dusk gives every selector of its stylesheet (static) and
# every probed widget (probe), which dusk's own theme has to reproduce
# (tests/headless/golden.py; tests/golden/).

# The recorded probe variants: MODE or MODE:VARIANT (probe_dir's names).
GOLDEN_VARIANTS="dark light dark:dock dark:blur dark:accent"

# golden_probe_file MODE[:VARIANT]: its record, e.g. probe-dark-dock.json.
golden_probe_file() {
  echo "$REPO/tests/golden/probe-${1/:/-}.json"
}

# golden_exceptions MODE[:VARIANT]: the exceptions file for that record: the
# Blur my Shell run also lists its own top bar, which sits on top of any theme.
golden_exceptions() {
  local file; file=$(mktemp)
  cat "$REPO/tests/golden/exceptions.tsv" > "$file"
  [ "$1" != dark:blur ] || cat "$REPO/tests/golden/exceptions-blur.tsv" >> "$file"
  echo "$file"
}

# dusk's theme alone gives the recorded look for every selector, apart from
# the changes tests/golden/exceptions.tsv lists (each with its own test).
test_golden_static_matches_theme() {
  local mode
  for mode in dark light; do
    "$REPO/tests/headless/golden.py" check-static "$(theme_css "$mode")" "$REPO/tests/golden/static-$mode.json" \
      "$REPO/tests/golden/exceptions.tsv" || fail "$mode: the static look differs from the record"
  done
}

# Every recorded probe variant measures as recorded, apart from the listed
# changes.
test_golden_probe_matches_theme() {
  local v out
  for v in $GOLDEN_VARIANTS; do
    out=$(probe_dir "${v%%:*}" $([ "$v" != "${v#*:}" ] && echo "${v#*:}"))
    "$REPO/tests/headless/golden.py" check-probe "$out/snapshots.json" "$(golden_probe_file "$v")" \
      "$(golden_exceptions "$v")" || fail "$v: the probed look differs from the record"
  done
}

# Corners: dusk's theme alone gives every recorded corner, predicted for
# every selector and measured on every probed widget (Task 4).
test_golden_radii_match_theme() {
  local mode v out
  for mode in dark light; do
    "$REPO/tests/headless/golden.py" check-static "$(theme_css "$mode")" "$REPO/tests/golden/static-$mode.json" \
      "$REPO/tests/golden/exceptions.tsv" --slots radius || fail "$mode: corners differ from the record"
  done
  for v in $GOLDEN_VARIANTS; do
    out=$(probe_dir "${v%%:*}" $([ "$v" != "${v#*:}" ] && echo "${v#*:}"))
    "$REPO/tests/headless/golden.py" check-probe "$out/snapshots.json" "$(golden_probe_file "$v")" \
      "$(golden_exceptions "$v")" --slots radius || fail "$v: measured corners differ from the record"
  done
}

# A changed record is reported, naming the selector and the slot: a record
# of dusk's theme checks clean against it, and with one menu background
# changed reports exactly that.
test_golden_check_reports_a_change() {
  local dir out rc=0
  dir=$(mktemp -d)
  "$REPO/tests/headless/golden.py" record-static "$(empty_css)" "$(theme_css dark)" "$dir/theme.json"
  "$REPO/tests/headless/golden.py" check-static "$(theme_css dark)" "$dir/theme.json" \
    "$REPO/tests/golden/exceptions.tsv" || fail "a record of the theme doesn't check clean against it"
  python3 - "$dir/theme.json" "$dir/changed.json" <<'EOF'
import json, sys
golden = json.load(open(sys.argv[1]))
golden[".popup-menu-content"]["colors"][0] = [1, 2, 3, 255]
json.dump(golden, open(sys.argv[2], "w"))
EOF
  out=$("$REPO/tests/headless/golden.py" check-static "$(theme_css dark)" "$dir/changed.json" \
    "$REPO/tests/golden/exceptions.tsv") || rc=$?
  assert_eq "$rc" 1 "exit code"
  assert_eq "$out" ".popup-menu-content bg: recorded [1, 2, 3, 255], now [54, 54, 58, 255]" "report"
}
