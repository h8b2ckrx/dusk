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

# While today's override layer exists: Yaru plus it still give the recorded
# look for every selector.
test_golden_static_matches_today() {
  local mode
  for mode in dark light; do
    "$REPO/tests/headless/golden.py" check-static "$("yaru_${mode}_css")" "$REPO/tests/golden/static-$mode.json" \
      "$REPO/tests/golden/exceptions.tsv" --overlay "$REPO/extension/stylesheet-$mode.css" \
      || fail "$mode: the static look differs from the record"
  done
}

# Every recorded probe variant still measures as recorded.
test_golden_probe_matches_today() {
  local v out
  for v in $GOLDEN_VARIANTS; do
    out=$(probe_dir "${v%%:*}" $([ "$v" != "${v#*:}" ] && echo "${v#*:}"))
    "$REPO/tests/headless/golden.py" check-probe "$out/snapshots.json" "$(golden_probe_file "$v")" \
      "$REPO/tests/golden/exceptions.tsv" || fail "$v: the probed look differs from the record"
  done
}

# A changed record is reported, naming the selector and the slot.
test_golden_check_reports_a_change() {
  local dir out rc=0
  dir=$(mktemp -d)
  python3 - "$REPO/tests/golden/static-dark.json" "$dir/changed.json" <<'EOF'
import json, sys
golden = json.load(open(sys.argv[1]))
golden[".popup-menu-content"]["colors"][0] = [1, 2, 3, 255]
json.dump(golden, open(sys.argv[2], "w"))
EOF
  out=$("$REPO/tests/headless/golden.py" check-static "$(yaru_dark_css)" "$dir/changed.json" \
    "$REPO/tests/golden/exceptions.tsv" --overlay "$REPO/extension/stylesheet-dark.css") || rc=$?
  assert_eq "$rc" 1 "exit code"
  [[ "$out" == *".popup-menu-content bg"* ]] || fail "the key and slot aren't named: $out"
}
