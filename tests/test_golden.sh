# Golden records of dusk's Shell look (design 2026-10-30, §6): the colors and
# corners today's dusk gives every selector of its stylesheet (static) and
# every probed widget (probe), which dusk's own theme has to reproduce
# (tests/headless/golden.py; tests/golden/).

# The recorded probe variants: MODE or MODE:VARIANT (probe_dir's names).
GOLDEN_VARIANTS="dark light dark:dock dark:accent"

# golden_probe_file MODE[:VARIANT]: its record, e.g. probe-dark-dock.json.
golden_probe_file() {
  echo "$REPO/tests/golden/probe-${1/:/-}.json"
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
      "$REPO/tests/golden/exceptions.tsv" || fail "$v: the probed look differs from the record"
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
      "$REPO/tests/golden/exceptions.tsv" --slots radius || fail "$v: measured corners differ from the record"
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
  assert_eq "$out" ".popup-menu-content bg: recorded [1, 2, 3, 255], now [29, 29, 29, 255]" "report"
}

# A color written two ways is the same color: a raw value with the accent in
# it compares by what it gives under real accents, and a real change still
# shows.
test_golden_check_compares_raw_values_by_color() {
  assert_eq "$(python3 - "$REPO/tests/headless" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import golden
print(golden._differs("st-mix(-st-accent-color, st-mix(#3D3D3D, white, 10%), 5%)",
                      "st-mix(-st-accent-color, #ececec, 5%)", 2),
      golden._differs("st-mix(-st-accent-color, #000000, 5%)",
                      "st-mix(-st-accent-color, #ffffff, 5%)", 2))
PY
)" "False True"
}

# look MODE SELECTOR: the colors dusk's theme gives SELECTOR's element, as JSON.
look() {
  "$REPO/tests/headless/golden.py" look "$(theme_css "$1")" "$2"
}

# The accent is always the system's: dusk's theme holds none of 24.04's baked
# oranges, and the elements that held them read the accent.
test_theme_accent_not_baked() {
  local mode selector
  for mode in dark light; do
    ! grep -qiE '#e64c17|#c04013|#d34615|#ef8661|#e95420' "$(theme_css "$mode")" || fail "$mode: a baked orange"
    for selector in .button.default:hover \
      '.audio-device-selection-dialog .audio-selection-box .audio-selection-device:active'; do
      case "$(look "$mode" "$selector")" in
        *-st-accent-color*) ;;
        *) fail "$mode: $selector doesn't read the accent" ;;
      esac
    done
  done
}

# The overview's scroll bars are the overview's own, as in stock Yaru.
test_theme_overview_scrollbars_are_stock() {
  local mode state stock
  for mode in dark light; do
    stock=$(yaru_${mode}_css)
    for state in '' :hover :active; do
      assert_eq "$("$REPO/tests/headless/golden.py" look "$(theme_css "$mode")" ".apps-scroll-view StScrollBar > .vhandle$state")" \
        "$("$REPO/tests/headless/golden.py" look "$stock" ".apps-scroll-view StScrollBar > .vhandle$state")" "$mode$state"
      assert_eq "$("$REPO/tests/headless/golden.py" look "$(theme_css "$mode")" ".search-display StScrollBar > .vhandle$state")" \
        "$("$REPO/tests/headless/golden.py" look "$stock" ".search-display StScrollBar > .vhandle$state")" "$mode$state"
    done
  done
}

# Check boxes draw what 24.04's pictures showed: checkbox-off's fill and border
# (bg-color, border-color in Yaru's common/yaru-colors-defs.scss), checkbox's
# accent, and checkbox-focused's darker accent with a lighter border. 24.04 had
# no picture for the pointer, so hovering changes nothing.
test_theme_check_boxes_from_2404_pictures() {
  assert_eq "$(look dark '.check-box StIcon')" '[[29, 29, 29, 255], [0, 0, 0, 0], [70, 70, 70, 255], null]' "dark off"
  assert_eq "$(look light '.check-box StIcon')" '[[250, 250, 250, 255], [0, 0, 0, 0], [199, 199, 199, 255], null]' "light off"
  assert_eq "$(look dark '.check-box:hover StIcon')" "$(look dark '.check-box StIcon')" "dark hover"
  assert_eq "$(look light '.check-box:hover StIcon')" "$(look light '.check-box StIcon')" "light hover"
  assert_eq "$(look dark '.check-box:checked StIcon')" '["-st-accent-color", "-st-accent-fg-color", [0, 0, 0, 0], null]' "checked"
  assert_eq "$(look dark '.check-box:checked:hover StIcon')" "$(look dark '.check-box:checked StIcon')" "checked hover"
  assert_eq "$(look dark '.check-box:focus:checked StIcon')" \
    '["st-darken(-st-accent-color, 7%)", "-st-accent-fg-color", "st-lighten(-st-accent-color, 17%)", null]' "dark focused"
  assert_eq "$(look light '.check-box:focus:checked StIcon')" \
    '["st-darken(-st-accent-color, 3%)", "-st-accent-fg-color", "st-lighten(-st-accent-color, 17%)", null]' "light focused"
}

# The slider's bars take 24.04's values from docs/reference/, the accent aside.
test_theme_slider_bars_from_2404() {
  local mode
  for mode in dark light; do
    python3 - "$(theme_css "$mode")" "$REPO/docs/reference/yaru-24.04-gnome-shell-$mode.css" <<'EOF' || fail "$mode"
import re, sys
def block(path):
    body = re.search(r"(?:^|\})\s*(?:/\*[^*]*\*/\s*)*\.slider \{([^}]*)\}", open(path).read()).group(1)
    return dict(l.strip().rstrip(";").split(": ", 1) for l in body.splitlines() if ": " in l)
ours, theirs = block(sys.argv[1]), block(sys.argv[2])
wrong = []
for prop in ("-barlevel-background-color", "-barlevel-active-border-color", "-barlevel-overdrive-color", "-barlevel-border-color"):
    if ours.get(prop) != theirs.get(prop):
        wrong.append(f"{prop}: {ours.get(prop)} vs {theirs.get(prop)}")
if ours.get("-barlevel-active-background-color") != "-st-accent-color":
    wrong.append("the active bar isn't the accent")
print("\n".join(wrong))
sys.exit(1 if wrong else 0)
EOF
  done
}

# Elements 26.04 renamed take 24.04's values under their 24.04 names.
test_theme_renamed_elements_from_2404() {
  local mode
  for mode in dark light; do
    python3 - "$REPO/tests/headless" "$(theme_css "$mode")" "$REPO/docs/reference/yaru-24.04-gnome-shell-$mode.css" <<'EOF' || fail "$mode"
import sys
sys.path.insert(0, sys.argv[1])
import colors, golden
theme, reference = sys.argv[2:4]
def look(css, selector):
    records = colors.element(selector)
    rules, radii = golden._rules(css, 0)
    return golden._predicted_look(records, rules, radii, len(records) - 1)["colors"]
PAIRS = [(f".modal-dialog .modal-dialog-button-box .modal-dialog-button{state}", f".modal-dialog .modal-dialog-linked-button{state}")
         for state in ("", ":hover", ":active", ":checked", ":checked:hover", ":checked:active", ":insensitive")]
PAIRS += [(".datemenu-today-button:insensitive .day-label", ".datemenu-today-button:insensitive .day-label"),
          (".datemenu-today-button:insensitive .date-label", ".datemenu-today-button:insensitive .date-label")]
wrong = []
for ours, theirs in PAIRS:
    a, b = look(theme, ours), look(reference, theirs)
    for slot in (0, 1):
        if golden._differs(a[slot], b[slot], 2):
            wrong.append(f"{ours} {golden.SLOTS[slot]}: {a[slot]} vs {b[slot]}")
print("\n".join(wrong))
sys.exit(1 if wrong else 0)
EOF
  done
}

# The surface groups of decision 22; a key belongs to the first that matches its
# first compound, and to the menus if none does.
GOLDEN_NOTIFICATIONS='^\.(message|notification|calendar|events-|world-clocks|weather|datemenu|shell-link)'
GOLDEN_DIALOGS='^\.(modal-dialog|prompt-dialog|end-session|run-dialog|audio-device|polkit|dialog-list|osd-|pad-osd|resize-popup|workspace-switcher|ws-switcher|switcher-|cycler|dash-label|window-caption|screenshot-ui-|candidate-)'

# check_golden_colors REGEX: dusk's theme gives every key REGEX picks its
# recorded colors, dark and light, apart from the listed changes.
check_golden_colors() {
  local mode
  for mode in dark light; do
    "$REPO/tests/headless/golden.py" check-static "$(theme_css "$mode")" "$REPO/tests/golden/static-$mode.json" \
      "$REPO/tests/golden/exceptions.tsv" --only "$1" --slots bg,fg,border,shadow || fail "$mode: colors differ from the record"
  done
}

test_golden_colors_match_theme_menus() {
  check_golden_colors "^(?!${GOLDEN_NOTIFICATIONS#^})(?!${GOLDEN_DIALOGS#^})"
}

test_golden_colors_match_theme_notifications() {
  check_golden_colors "$GOLDEN_NOTIFICATIONS"
}

test_golden_colors_match_theme_dialogs() {
  check_golden_colors "$GOLDEN_DIALOGS"
}
