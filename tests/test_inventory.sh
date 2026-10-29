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

# --keep REGEX: out-of-scope stock rules the static check can't tie to an
# in-scope one (a class on an element a type rule styles, like the
# overview's .search-entry under StEntry) are kept too.
test_color_inventory_keep_regex() {
  local dir; dir=$(mktemp -d)
  printf 'StEntry { background-color: #e5e5e5; }\n.search-entry { background-color: #3b3b3b; }\n.other { color: red; }\n' > "$dir/new.css"
  : > "$dir/old.css"
  local out; out=$("$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^StEntry' --keep '^\.search-entry')
  assert_eq "$(cut -f1,5 <<< "$out" | tr '\t' ' ')" "StEntry derived
.search-entry keep"
}

# Kept rules are protected too: a kept rule that would itself override a
# more specific stock rule keeps that one as well. --no-keep drops rules
# dusk never meets (the login screen).
test_color_inventory_keep_closure_and_no_keep() {
  local dir; dir=$(mktemp -d)
  printf '.c { color: #111111; }\n.x .c { color: #222222; }\n.x .y .c { color: #333333; }\n.login-dialog .c { color: #444444; }\n' > "$dir/new.css"
  : > "$dir/old.css"
  local out; out=$("$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^\.c$' --keep '^\.x \.c$' --no-keep '^\.login-dialog')
  assert_eq "$(cut -f1,5 <<< "$out" | tr '\t' ' ')" ".c derived
.x .c keep
.x .y .c keep"
}

# The winning declaration counts, not the last: an earlier !important value
# beats a later plain one (Yaru's inactive menu items: transparent !important,
# then a grey that never shows).
test_color_inventory_important_wins() {
  local dir; dir=$(mktemp -d)
  printf '.m:insensitive { background-color: transparent !important; }\n.m:insensitive { color: #111111; background-color: #424247; }\n' > "$dir/new.css"
  printf '.m:insensitive { background-color: transparent !important; }\n.m:insensitive { background-color: #343434; }\n' > "$dir/old.css"
  assert_eq "$("$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^\.m' | grep -P '\tbackground-color\t' | cut -f3-5)" \
    $'transparent !important\ttransparent !important\tsame'
}

# --add REGEX: older rules the stock file dropped, for elements it still has
# (24.04's notification banners), are listed after the stock rules with their
# older value (added); the 26.04 value is "-".
test_color_inventory_adds_old_rules() {
  local dir; dir=$(mktemp -d)
  printf '.m { background-color: #36363a; }\n.m.banner { min-height: 64px; }\n' > "$dir/new.css"
  printf '.m { background-color: #2f2f2f; }\n.m.banner { background-color: #1d1d1d; }\n.m.banner:hover { background-color: #222222; }\n.gone { color: red; }\n' > "$dir/old.css"
  local out; out=$("$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^\.m' --add '^\.m\.banner')
  assert_eq "$out" $'.m\tbackground-color\t#36363a\t#2f2f2f\tsame\n.m.banner\tbackground-color\t-\t#1d1d1d\tadded\n.m.banner:hover\tbackground-color\t-\t#222222\tadded'
}

# --images FILE: where the older theme drew a color in a picture (24.04's
# SVG switches), the stock rule takes the color from the table (image).
test_color_inventory_images() {
  local dir; dir=$(mktemp -d)
  printf '.sw { background: rgba(255, 255, 255, 0.15); }\n.sw .knob { background: #d7d7d8; }\n' > "$dir/new.css"
  printf '.sw { background-image: url("off.svg"); }\n' > "$dir/old.css"
  printf '.sw\tbackground\t#575757\n.sw .knob\tbackground\t#f8f7f7\n' > "$dir/images.tsv"
  local out; out=$("$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^\.sw' --images "$dir/images.tsv")
  assert_eq "$out" $'.sw\tbackground\trgba(255, 255, 255, 0.15)\t#575757\timage\n.sw .knob\tbackground\t#d7d7d8\t#f8f7f7\timage'
}

# The 24.04 column carries the !important the mirror emits: 24.04's own where
# the value is 24.04's (same), 26.04's where it isn't (unset, image).
test_color_inventory_importance_follows_value() {
  local dir; dir=$(mktemp -d)
  printf '.m:hover { background-color: #424247 !important; }\n.m:insensitive { background-color: #2a2a2a !important; }\n.sw { background: #555555 !important; }\n' > "$dir/new.css"
  printf '.m:hover { background-color: #464646; }\n.m:insensitive { color: red; }\n.sw { background-image: url("x.svg"); }\n' > "$dir/old.css"
  printf '.sw\tbackground\t#575757\n' > "$dir/images.tsv"
  local out; out=$("$REPO/tools/color-inventory.py" "$dir/new.css" "$dir/old.css" --scope '^\.(m|sw)' --images "$dir/images.tsv" | cut -f1,4,5)
  assert_eq "$out" $'.m:hover\t#464646\tsame\n.m:insensitive\ttransparent !important\tunset\n.sw\t#575757 !important\timage'
}

# The installed Yaru 26.04 Shell stylesheet for MODE, extracted to a file.
stock_shell_css() {
  local css; css=$(mktemp --suffix=.css)
  local name=gnome-shell.css
  [ "$1" = dark ] && name=gnome-shell-dark.css
  gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource \
    "/org/gnome/shell/theme/Yaru/$name" > "$css"
  echo "$css"
}

# Every row with a 24.04 value of its own (same, unset, added), on the element
# its selector names, and menu items also as Shell shows them under the
# pointer and pressed (also selected and focused): Yaru 26.04 plus dusk give
# it the background and border Yaru 24.04's own cascade gives it (final
# review: 26.04's !important menu hover made 24.04's pressed colors dead).
test_color_inventory_rows_follow_2404_cascade() {
  local mode out
  for mode in dark light; do
    out=$("$REPO/tests/headless/colors.py" follows-rows "$(stock_shell_css "$mode")" \
      "$REPO/docs/reference/yaru-24.04-gnome-shell-$mode.css" "$REPO/docs/inventory-shell-colors.tsv" "$mode") \
      || fail "$mode: colors that aren't 24.04's:
$(head -12 <<< "$out")"
  done
}

# "unset" (24.04 drew nothing) only where 24.04 drew no picture either: its
# switches and check boxes were SVG pictures, so a track that's transparent
# for lack of a color rule is wrong (final review: off switches lost their
# track).
test_color_inventory_unset_only_where_2404_drew_nothing() {
  local mode out
  for mode in dark light; do
    out=$(python3 - "$REPO/docs/inventory-shell-colors.tsv" "$REPO/docs/reference/yaru-24.04-gnome-shell-$mode.css" "$mode" <<'EOF'
import re, sys
tsv, ref, mode = sys.argv[1:]
css = re.sub(r"/\*.*?\*/", "", open(ref).read(), flags=re.S)
pictures = {" ".join(sel.split()) for m in re.finditer(r"([^{}]+)\{([^{}]*)\}", css)
            if re.search(r"background-image:\s*url", m.group(2)) for sel in m.group(1).split(",")}
for line in open(tsv):
    if line.strip() and not line.startswith("# "):
        m, sel, prop, _, _, source, _, _ = line.rstrip("\n").split("\t")
        if m in ("both", mode) and source == "unset" and prop.startswith("background") and sel in pictures:
            print(f"{sel} {prop}")
EOF
)
    [ -z "$out" ] || fail "$mode: unset where 24.04 drew a picture: $out"
  done
}

# Rows new in 26.04 (derived) and accent rows hold no 26.04-only color: each
# color in their 24.04 value is one Yaru 24.04 uses (at any alpha), or one the
# palettes give (final review: focused entries flashed 26.04's lighter grey).
test_color_inventory_no_2604_colors_left() {
  local mode out
  for mode in dark light; do
    out=$(python3 - "$REPO/docs/inventory-shell-colors.tsv" "$REPO/docs/reference/yaru-24.04-gnome-shell-$mode.css" \
      "$REPO/docs/inventory-shell-colors-palette-$mode.tsv" "$mode" <<'EOF'
import re, sys
sys.path.insert(0, sys.argv[0].rsplit("/", 1)[0] if "/" in sys.argv[0] else ".")
tsv, ref, palette, mode = sys.argv[1:]
COLOR = re.compile(r"#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)")
def rgb(c):
    c = c.lower().replace(" ", "")
    if c.startswith("#"):
        h = c[1:] if len(c) > 4 else "".join(ch * 2 for ch in c[1:])
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return tuple(int(float(x)) for x in c[c.index("(") + 1:-1].split(",")[:3])
allowed = {rgb(c) for c in COLOR.findall(open(ref).read())}
for line in open(palette):
    if line.strip() and not line.startswith("# "):
        allowed |= {rgb(c) for c in COLOR.findall(line.rstrip("\n").split("\t")[1] + ")")}
left = set()
for line in open(tsv):
    if line.strip() and not line.startswith("# "):
        m, sel, prop, _, old, source, _, _ = line.rstrip("\n").split("\t")
        if m in ("both", mode) and source in ("derived", "accent"):
            left |= {f"{c} ({sel} {prop})" for c in COLOR.findall(old) if rgb(c) not in allowed}
print("\n".join(sorted(left)))
EOF
)
    [ -z "$out" ] || fail "$mode: 26.04 colors left:
$(head -12 <<< "$out")"
  done
}

# The lock screen keeps its own look (decision 21): dusk changes no color of
# its notifications, also where a class rule of ours meets the lock screen's
# type rules (final review: the media player's buttons turned dark in light
# mode). Its notification widgets, as Shell 50 builds them, in their states.
test_color_inventory_lock_screen_notifications_stay_stock() {
  local mode out
  for mode in dark light; do
    out=$(python3 - "$REPO/tests/headless" "$(stock_shell_css "$mode")" "$REPO/docs/inventory-shell-colors.tsv" "$mode" <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import colors
yaru = colors.parse_color_rules(open(sys.argv[2]).read(), origin=0)
ours, _ = colors.tsv_rules(sys.argv[3], sys.argv[4], [1, 2, 3])
lock = ".unlock-dialog #unlockDialogNotifications .unlock-dialog-notifications-container"
message = "StButton.message.media-message"
widgets = [
    f"{lock} {message}",
    f"{lock} StButton.message.message-notification-group",
    f"{lock} {message} StBoxLayout.message-header StButton.message-expand-button",
    f"{lock} {message} StBoxLayout.message-header StButton.message-close-button",
    f"{lock} {message} StBoxLayout.message-box StBoxLayout StButton.message-media-control",
    f"{lock} StBoxLayout.unlock-dialog-notification-source StButton",
]
names = ["background", "text", "border", "shadow"]
for widget in widgets:
    for state in ((), ("hover",), ("hover", "active"), ("focus",), ("insensitive",)):
        records = colors.element(widget, state)
        stock, with_ours = colors.predict(records, yaru)[-1], colors.predict(records, yaru + ours)[-1]
        # Background and text: the lock screen's messages draw no border
        # (border: none), whose color the model can't tell from a drawn one.
        for slot in (0, 1):
            if stock[slot] != with_ours[slot]:
                print(f"{widget.split()[-1]}{''.join(':' + p for p in state)} {names[slot]}: stock {stock[slot]}, with dusk {with_ours[slot]}")
EOF
)
    [ -z "$out" ] || fail "$mode: lock screen colors changed:
$(head -12 <<< "$out")"
  done
}
