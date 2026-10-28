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

# clobbered YARU DUSK: ids of records where one of our rules overrides a more
# specific Yaru rule (a deliberate special case we'd erase).
clobbered() {
  python3 - "$REPO/tests/headless" "$1" "$2" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import cascade
records = [
    {"parent": -1, "id": "root", "classes": ["a"], "pseudo": [], "types": ["StWidget"]},
    {"parent": 0, "id": "leaf", "classes": ["c"], "pseudo": [], "types": ["StWidget"]},
    {"parent": -1, "id": "other", "classes": ["c"], "pseudo": [], "types": ["StWidget"]},
]
yaru = cascade.parse_rules(sys.argv[2], origin=0)
dusk = cascade.parse_rules(sys.argv[3], origin=1)
print(" ".join(records[i]["id"] for i in cascade.clobbered(records, yaru, dusk)))
PY
}

test_cascade_detects_clobbered_special_cases() {
  local yaru='.c { border-radius: 8px; } .a .c { border-radius: 0; }'
  assert_eq "$(clobbered "$yaru" '.c { border-radius: 9px; }')" "leaf"
  assert_eq "$(clobbered "$yaru" '.c { border-radius: 9px; } .a .c { border-radius: 0; }')" ""
}

# St looks past non-St actors to the nearest St ancestor (seen live: the
# Activities workspace dots sit under a plain Clutter actor).
test_cascade_skips_non_st_ancestors() {
  local out
  out=$(predict '.a .d { border-radius: 2px; }' '')
  assert_eq "$(line_for under "$out")" "under: 2px 2px 2px 2px"
}

# drifted YARU DUSK: ids of records whose radius now comes from a different
# rule of ours than the one mirroring stock's winner, with a different value.
drifted() {
  python3 - "$REPO/tests/headless" "$1" "$2" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import cascade
records = [
    {"parent": -1, "id": "both", "classes": ["menu", "date"], "pseudo": [], "types": ["StWidget"]},
    {"parent": -1, "id": "menu", "classes": ["menu"], "pseudo": [], "types": ["StWidget"]},
]
yaru = cascade.parse_rules(sys.argv[2], origin=0)
dusk = cascade.parse_rules(sys.argv[3], origin=1)
print(" ".join(records[i]["id"] for i, _, _ in cascade.drifts(records, yaru, dusk)))
PY
}

# In stock the later .menu rule wins on the two-class element; if ours lets
# .date win with another value, that's drift. Same value, or matching order: none.
test_cascade_detects_drift() {
  local yaru='.date { border-radius: 8px; } .menu { border-radius: 16px; }'
  assert_eq "$(drifted "$yaru" '.menu { border-radius: 5px; } .date { border-radius: 3px; }')" "both"
  assert_eq "$(drifted "$yaru" '.menu { border-radius: 5px; } .date { border-radius: 5px; }')" ""
  assert_eq "$(drifted "$yaru" '.date { border-radius: 3px; } .menu { border-radius: 5px; }')" ""
}
