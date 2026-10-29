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

# tools/color-inventory.py: in-scope color rules of a stock stylesheet with
# their value in an older one (decision 22).

# color_inventory: runs the tool on two small made-up stylesheets and a palette.
color_inventory() {
  local dir; dir=$(mktemp -d)
  cat > "$dir/new.css" <<'CSS'
.menu { background-color: #36363a; }
.other { color: red; }
.menu:hover { background-color: st-lighten(#36363a, 7%); }
.menu .new { border: 1px solid #47474c; }
.menu .acc { background-color: st-mix(-st-accent-color, #36363a, 5%); }
.menu { color: #ffffff; }
.menu .fg { color: -st-accent-fg-color; }
.menu > .handle { background-color: #727275; color: white; }
.menu .old-name { background-color: #36363a; }
.c { background-color: #36363a; }
.away .c { background-color: #123456; }
.menu .sub { background-color: #56565c; box-shadow: 0 1px 2px #000000; }
CSS
  cat > "$dir/old.css" <<'CSS'
.menu { background-color: #1d1d1d; color: #F7F7F7; }
.menu:hover { background-color: #222222; }
.menu .acc { background-color: #E95420; }
.menu StButton#handle { background-color: #5e5e5e; }
.c { background-color: #2f2f2f; }
.menu .sub { border-radius: 9px; }
CSS
  printf '#36363a\t#1d1d1d\n#47474c\t#2f2f2f\nwhite\t#F7F7F7\n' > "$dir/palette.tsv"
  printf '^\\.menu > \\.handle$\t.menu StButton#handle\n' > "$dir/renames.tsv"
  "$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^(\.menu|\.c$)' --exclude '^\.away' \
    --palette "$dir/palette.tsv" --renames "$dir/renames.tsv"
}

# In-scope selectors only, in the stock file's order (each selector's last
# declaration), with the older value where the older file has the rule.
test_color_inventory_lists_scope() {
  local out; out=$(color_inventory)
  assert_eq "$(cut -f1,2 <<< "$out" | head -5 | tr '\t' ' ')" ".menu background-color
.menu:hover background-color
.menu .new border
.menu .acc background-color
.menu color" "rows"
  assert_eq "$(sed -n 1p <<< "$out")" $'.menu\tbackground-color\t#36363a\t#1d1d1d\tsame'
  assert_eq "$(sed -n 5p <<< "$out")" $'.menu\tcolor\t#ffffff\t#F7F7F7\tsame'
}

# No older rule: the stock expression with the palette's colors swapped
# (derived). An accent expression stays the stock one, palette-swapped,
# even where the older file baked an accent in.
test_color_inventory_derives() {
  local out; out=$(color_inventory)
  assert_eq "$(sed -n 3p <<< "$out")" $'.menu .new\tborder\t1px solid #47474c\t1px solid #2f2f2f\tderived'
  assert_eq "$(sed -n 4p <<< "$out")" $'.menu .acc\tbackground-color\tst-mix(-st-accent-color, #36363a, 5%)\tst-mix(-st-accent-color, #1d1d1d, 5%)\taccent'
}

# The accent's text color counts as accent; a renamed element takes the older
# value under its old selector (renamed); a named color in a derived value is
# palette-swapped too.
test_color_inventory_renames_and_accent_fg() {
  local out; out=$(color_inventory)
  assert_eq "$(grep -P '^\.menu \.fg\t' <<< "$out" | cut -f5)" "accent"
  assert_eq "$(grep -P '^\.menu > \.handle\tbackground-color' <<< "$out")" $'.menu > .handle\tbackground-color\t#727275\t#5e5e5e\trenamed'
  assert_eq "$(grep -P '^\.menu > \.handle\tcolor' <<< "$out" | cut -f4,5)" $'#F7F7F7\tderived'
}

# An excluded stock rule that one of the in-scope rules would erase (more
# specific, same color slot) is listed too, keeping its stock value (keep).
test_color_inventory_keeps_erased_exclusions() {
  local out; out=$(color_inventory)
  assert_eq "$(grep -P '^\.away \.c\t' <<< "$out")" $'.away .c\tbackground-color\t#123456\t#123456\tkeep'
}

# The older file has the element but never set this color: it drew none
# (transparent background or border, no shadow) (unset).
test_color_inventory_unset_in_old() {
  local out; out=$(color_inventory)
  assert_eq "$(grep -P '^\.menu \.sub\tbackground-color' <<< "$out" | cut -f4,5)" $'transparent\tunset'
  assert_eq "$(grep -P '^\.menu \.sub\tbox-shadow' <<< "$out" | cut -f4,5)" $'none\tunset'
}

# Palette swaps happen in one pass: a color swapped to another palette color
# isn't swapped again.
test_color_inventory_swaps_once() {
  local dir; dir=$(mktemp -d)
  echo '.m .n { color: st-mix(#f2f2f2, #ededed, 5%); }' > "$dir/new.css"
  : > "$dir/old.css"
  printf '#f2f2f2\t#ededed\n#ededed\t#e8e8e8\n' > "$dir/palette.tsv"
  assert_eq "$("$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^\.m' --palette "$dir/palette.tsv" | cut -f4)" \
    "st-mix(#ededed, #e8e8e8, 5%)"
}

# tools/color-inventory-table.py: the dark and light inventories as one table
# (mode, selector, property, 26.04 value, 24.04 value, source, token, chunk).
test_color_inventory_table_merges_modes() {
  local dir; dir=$(mktemp -d)
  printf '.popup-menu-item:hover\tbackground-color\t#36363a\t#1d1d1d\tsame\n.message\tcolor\twhite\t#F7F7F7\tsame\n.away .c\tcolor\tred\tred\tkeep\n' > "$dir/dark.tsv"
  printf '.popup-menu-item:hover\tbackground-color\twhite\t#FAFAFA\tsame\n.message\tcolor\twhite\t#F7F7F7\tsame\n.osd-window\tcolor\tblack\t#3D3D3D\tderived\n' > "$dir/light.tsv"
  local out; out=$("$REPO/tools/color-inventory-table.py" "$dir/dark.tsv" "$dir/light.tsv" | grep -v '^# ')
  assert_eq "$out" "dark	.popup-menu-item:hover	background-color	#36363a	#1d1d1d	same	popup-menu-item-hover-background-color	1
light	.popup-menu-item:hover	background-color	white	#FAFAFA	same	popup-menu-item-hover-background-color	1
both	.message	color	white	#F7F7F7	same	message-color	2
light	.osd-window	color	black	#3D3D3D	derived	osd-window-color	3
dark	.away .c	color	red	red	keep	away-c-color	0"
}

# The color inventory still matches the installed Yaru 26.04 stylesheets: the
# same rows, selectors, properties and 26.04 values (an update shows here).
test_color_inventory_matches_installed_yaru() {
  local d
  d=$(diff <("$REPO/tools/shell-color-inventory.sh" | grep -v '^# ' | cut -f1-4) \
    <(grep -v '^# ' "$REPO/docs/inventory-shell-colors.tsv" | cut -f1-4)) \
    || fail "docs/inventory-shell-colors.tsv no longer matches the installed Yaru (< installed, > inventory):
$(echo "$d" | head -20)
Re-run tools/shell-color-inventory.sh and review the changed rows."
}

# docs/inventory-shell-colors.md is what tools/color-inventory-doc.py makes
# from the table (it never drifts from the rows).
test_color_inventory_doc_up_to_date() {
  diff <("$REPO/tools/color-inventory-doc.py" "$REPO/docs/inventory-shell-colors.tsv") "$REPO/docs/inventory-shell-colors.md" > /dev/null \
    || fail "docs/inventory-shell-colors.md is stale: run tools/color-inventory-doc.py docs/inventory-shell-colors.tsv > docs/inventory-shell-colors.md"
}
