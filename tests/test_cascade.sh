# tests/headless/cascade.py: predicting the corner radii Shell computes from
# Yaru's stylesheet plus ours, on small made-up element trees.

# predict YARU_CSS DUSK_CSS: prints "id: tl tr br bl" for each record of the
# fixed tree below (root .a > mid .b > leaf .c, plus an StIcon under mid, and
# .d under a plain Clutter actor under root).
predict() {
  python3 - "$REPO/tests/headless" "$1" "$2" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import cascade
records = [
    {"parent": -1, "id": "root", "classes": ["a"], "pseudo": [], "types": ["StBin", "StWidget"]},
    {"parent": 0, "id": "mid", "classes": ["b"], "pseudo": [], "types": ["StBin", "StWidget"]},
    {"parent": 1, "id": "leaf", "classes": ["c"], "pseudo": ["hover"], "types": ["StBin", "StWidget"]},
    {"parent": 1, "id": "icon", "classes": [], "pseudo": [], "types": ["StIcon", "StWidget"]},
    {"parent": 0, "id": "clutter", "classes": [], "pseudo": [], "types": ["ClutterActor"]},
    {"parent": 4, "id": "under", "classes": ["d"], "pseudo": [], "types": ["StWidget"]},
]
rules = cascade.parse_rules(sys.argv[2], origin=0) + cascade.parse_rules(sys.argv[3], origin=1)
for rec, corners in zip(records, cascade.predict(records, rules)):
    print(f"{rec['id']}: " + " ".join("-" if v is None else v for v in corners))
EOF
}

line_for() { grep "^$1:" <<< "$2"; }

test_cascade_descendant_and_child() {
  local out
  out=$(predict '.a .c { border-radius: 1px; } .a > .c { border-radius: 2px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 1px 1px 1px 1px"
  out=$(predict '.b > .c { border-radius: 3px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 3px 3px 3px 3px"
}

test_cascade_specificity_beats_order() {
  local out
  out=$(predict '.a .c { border-radius: 5px; } .c { border-radius: 9px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 5px 5px 5px 5px"
}

# Within one stylesheet, equal specificity: the later rule wins.
# St gives a rule the specificity of the last selector in its list that
# matches the element (st-theme.c add_matched_properties overwrites it per
# match), not the highest: `.a .c, .c` counts as `.c` for an element both
# match, so a later `.c` rule wins (seen in Yaru's folder tiles).
test_cascade_group_takes_last_matching_selector() {
  local out
  out=$(predict '.a .c, .c { border-radius: 5px; } .c { border-radius: 9px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 9px 9px 9px 9px"
  out=$(predict '.c, .a .c { border-radius: 5px; } .c { border-radius: 9px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 5px 5px 5px 5px"
}

test_cascade_later_rule_wins() {
  local out
  out=$(predict '.c { border-radius: 8px; } .c { border-radius: 7px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 7px 7px 7px 7px"
}

# St ranks an extension stylesheet above the theme outright: ours wins even
# against a more specific or !important Yaru rule (seen live: our
# .popup-menu-item beat Yaru's .popup-sub-menu .popup-menu-item, and our
# .popup-menu-item:checked beat Yaru's !important one).
test_cascade_our_stylesheet_beats_yaru() {
  local out
  out=$(predict '.c { border-radius: 8px; }' '.c { border-radius: 9px; }')
  assert_eq "$(line_for leaf "$out")" "leaf: 9px 9px 9px 9px"
  out=$(predict '.a .c { border-radius: 8px; }' '.c { border-radius: 9px; }')
  assert_eq "$(line_for leaf "$out")" "leaf: 9px 9px 9px 9px" "more specific Yaru rule"
  out=$(predict '.c { border-radius: 4px !important; }' '.c { border-radius: 9px; }')
  assert_eq "$(line_for leaf "$out")" "leaf: 9px 9px 9px 9px" "!important Yaru rule"
}

test_cascade_shorthand_and_longhands() {
  local out
  out=$(predict '.c { border-radius: 4px; } .c { border-top-left-radius: 0; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 0 4px 4px 4px"
  out=$(predict '.c { border-radius: 1px 2px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 1px 2px 1px 2px"
  out=$(predict '.c { border-radius: 1px 2px 3px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 1px 2px 3px 2px"
}

# :ltr always applies (left-to-right desktop), :rtl never; other pseudo-classes
# must be present on the element; type selectors match the GType chain.
test_cascade_pseudo_classes_and_types() {
  local out
  out=$(predict '.c:ltr { border-radius: 3px; } .c:rtl { border-radius: 6px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 3px 3px 3px 3px"
  out=$(predict '.c:hover { border-radius: 2px; } .c:active { border-radius: 5px; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 2px 2px 2px 2px"
  out=$(predict 'StIcon { border-radius: 2px; } #root .b { border-radius: 1px; }' '')
  assert_eq "$(line_for icon "$out")" "icon: 2px 2px 2px 2px"
  assert_eq "$(line_for mid "$out")" "mid: 1px 1px 1px 1px"
  assert_eq "$(line_for root "$out")" "root: - - - -"
}

# Within one stylesheet, !important beats specificity.
test_cascade_important_wins_within_a_stylesheet() {
  local out
  out=$(predict '' '.c { border-radius: 4px !important; } .a .b .c { border-radius: 9px; }')
  assert_eq "$(line_for leaf "$out")" "leaf: 4px 4px 4px 4px"
}

# St looks past non-St actors to the nearest St ancestor (seen live: the
# Activities workspace dots sit under a plain Clutter actor).
test_cascade_skips_non_st_ancestors() {
  local out
  out=$(predict '.a .d { border-radius: 2px; }' '')
  assert_eq "$(line_for under "$out")" "under: 2px 2px 2px 2px"
}

# tests/headless/colors.py: the same cascade for colors (decision 22).

# color_eval VALUE: what colors.evaluate gives, as "r g b a" (or "None").
color_eval() {
  python3 - "$REPO/tests/headless" "$1" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import colors
v = colors.evaluate(sys.argv[2])
print("None" if v is None else " ".join(map(str, v)))
PY
}

# sass_color EXPR: what sassc computes for a Sass color expression, as "r g b a".
sass_color() {
  local css; css=$(printf '.t { c: %s; }' "$1" | "${SASSC:-sassc}" -s)
  color_eval "$(sed -n 's/.*c: \(.*\);.*/\1/p' <<< "$css")"
}

# St's color functions behave like Sass's; the headless check calibrates
# them against what St itself computes (test_headless_shell_colors_match_stylesheets).
test_colors_evaluate_st_functions() {
  assert_eq "$(color_eval 'st-lighten(#36363a, 7%)')" "$(sass_color 'lighten(#36363a, 7%)')" "st-lighten"
  assert_eq "$(color_eval 'st-darken(#36363a, 7%)')" "$(sass_color 'darken(#36363a, 7%)')" "st-darken"
  assert_eq "$(color_eval 'st-mix(white, #36363a, 9%)')" "$(sass_color 'mix(white, #36363a, 9%)')" "st-mix"
  assert_eq "$(color_eval 'st-transparentize(#f2f2f2, 0.9)')" "$(sass_color 'transparentize(#f2f2f2, 0.9)')" "st-transparentize"
  assert_eq "$(color_eval 'st-lighten(st-mix(white, #36363a, 9%), 4%)')" \
    "$(sass_color 'lighten(mix(white, #36363a, 9%), 4%)')" "nested"
  assert_eq "$(color_eval 'rgba(29, 29, 29, 0.975)')" "29 29 29 249" "rgba"
  assert_eq "$(color_eval '#FAFAFA')" "250 250 250 255" "hex"
  assert_eq "$(color_eval 'st-mix(-st-accent-color, #1d1d1d, 5%)')" "None" "accent"
}

# color_predict YARU_CSS DUSK_CSS: "id: bg | fg | border | shadow" for the
# tree used by `predict` above.
color_predict() {
  python3 - "$REPO/tests/headless" "$1" "$2" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import colors
records = [
    {"parent": -1, "id": "root", "classes": ["a"], "pseudo": [], "types": ["StBin", "StWidget"]},
    {"parent": 0, "id": "mid", "classes": ["b"], "pseudo": [], "types": ["StBin", "StWidget"]},
    {"parent": 1, "id": "leaf", "classes": ["c"], "pseudo": ["hover"], "types": ["StBin", "StWidget"]},
]
rules = colors.parse_color_rules(sys.argv[2], origin=0) + colors.parse_color_rules(sys.argv[3], origin=1)
for rec, slots in zip(records, colors.predict(records, rules)):
    print(f"{rec['id']}: " + " | ".join("-" if v is None else " ".join(map(str, v)) for v in slots))
PY
}

# Text color is inherited from the nearest St parent; the others aren't.
test_colors_foreground_inherits() {
  local out; out=$(color_predict '.a { color: #111111; background-color: #222222; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: - | 17 17 17 255 | - | -"
  out=$(color_predict '.a { color: #111111; } .c { color: white; }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: - | 255 255 255 255 | - | -"
}

# Shorthands: background, border and box-shadow set their color slot.
test_colors_shorthands() {
  local out; out=$(color_predict '.c { background: #010203; border: 1px solid #040506; box-shadow: inset 0 0 0 1px rgba(7, 8, 9, 0.5); }' '')
  assert_eq "$(line_for leaf "$out")" "leaf: 1 2 3 255 | - | 4 5 6 255 | 7 8 9 128"
}

# WCAG contrast ratio between two opaque colors.
test_colors_contrast_ratio() {
  local out
  out=$(python3 - "$REPO/tests/headless" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import colors
print(round(colors.contrast((255, 255, 255, 255), (0, 0, 0, 255)), 1),
      round(colors.contrast((247, 247, 247, 255), (29, 29, 29, 255)), 1),
      colors.over((247, 247, 247, 128), (29, 29, 29, 255)))
PY
)
  assert_eq "$out" "21.0 15.7 (138, 138, 138, 255)"
}
