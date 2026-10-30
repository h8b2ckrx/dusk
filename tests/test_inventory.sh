# tools/radius-inventory.py on tests/fixtures/radius.css.

inventory() {
  "$REPO/tools/radius-inventory.py" "$REPO/tests/fixtures/radius.css" "$@"
}

test_inventory_lists_effective_nonzero_radii() {
  local out; out=$(mktemp)
  inventory > "$out"
  local expected
  expected=$(printf '%s\n' \
    $'4px\tborder-top-left-radius\t.d' \
    $'12px\tborder-radius\t.a' \
    $'16.8px\tborder-radius\t.q' \
    $'999px\tborder-radius\t.r' \
    $'0 0 6px 6px\tborder-radius\t.f:not(.x, .y)' \
    $'INVALID:$yaru_popup_radius\tborder-radius\t.e')
  assert_eq "$(sort "$out")" "$(echo "$expected" | sort)" "inventory lines"
}

test_inventory_sorts_by_value() {
  local out; out=$(mktemp)
  inventory > "$out"
  assert_eq "$(cut -f1 "$out" | tr '\n' ' ')" "4px 0 0 6px 6px 12px 16.8px 999px INVALID:\$yaru_popup_radius " "value order"
}

test_inventory_include_zero() {
  local out; out=$(mktemp)
  inventory --include-zero > "$out"
  grep -qxF $'0\tborder-radius\t.b' "$out" || fail ".b missing with --include-zero"
  grep -qxF $'0\tborder-radius\t.c' "$out" || fail ".c missing with --include-zero"
}

test_inventory_exclude() {
  local out; out=$(mktemp)
  inventory --exclude '^\.e$' > "$out"
  assert_not_contains "$out" $'\t.e'
}

# High-contrast and other @media-only rules are out of scope unless asked for.
test_inventory_skips_media_blocks() {
  local out; out=$(mktemp)
  inventory > "$out"
  assert_not_contains "$out" ".hc"
  inventory --include-media > "$out"
  assert_contains "$out" $'3px\tborder-radius\t.hc'
}

# --source-order keeps the order of each selector's last (effective)
# declaration, which is what the cascade uses for ties.
test_inventory_source_order() {
  local out; out=$(mktemp)
  inventory --source-order > "$out"
  assert_eq "$(cut -f3 "$out" | tr '\n' ' ')" ".r .a .q .d .e .f:not(.x, .y) " "selector order"
}

# GTK3 focus rings have their own radius (-gtk-outline-radius and its four
# longhands), listed like border radii.
test_inventory_lists_gtk3_focus_ring_radii() {
  local css; css=$(mktemp --suffix=.css)
  printf 'button { -gtk-outline-radius: 6px; outline-offset: -2px; }\n.x { -gtk-outline-top-left-radius: 7px; }\n' > "$css"
  assert_eq "$("$REPO/tools/radius-inventory.py" "$css" --source-order)" \
    $'6px\t-gtk-outline-radius\tbutton\n7px\t-gtk-outline-top-left-radius\t.x' "focus ring rows"
}
