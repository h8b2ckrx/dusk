# dusk: Shell pop-up colors like Ubuntu 24.04 (design)

Status: approved by the owner 2026-10-29 (after a builder check). Design decision 22 in
[2026-10-28-dusk-design.md](2026-10-28-dusk-design.md) points here. It builds on that design:
same repo, same hooks, same rules (tokens only, mirror stock rules, owner gates).

## 1. Intent

The owner, looking at the date menu and a notification banner in dark mode: the colors "are too
bright for dark mode", and the notifications "have to be a little darker, like 24.04". Asked
about scope, the owner chose **all of the Shell's pop-ups**, then **exactly 24.04's colors**,
then **light mode back to 24.04's light colors too**, and approved **"everything in the Shell
that floats"** as the boundary.

So: every floating GNOME Shell surface, and everything drawn on it, takes Ubuntu 24.04 Yaru's
exact colors, in dark and in light. Today they use Ubuntu 26.04 Yaru's colors, which are much
lighter in dark mode and slightly blue-tinted.

## 2. What 24.04 and 26.04 use (recon, 2026-10-29)

24.04 values were compiled from the Yaru source at tag `24.04.3-0ubuntu1` (the same source as
the 24.04 dialogs, §6 of the main design), `gnome-shell/src/gnome-shell-sass/`. Its greys all
derive from one near-black, `$jet` `#181818` (dark), and `#FAFAFA` / white (light). 26.04 values
come from the installed theme (`/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource`).

| Surface | 24.04 dark | 26.04 dark | 24.04 light | 26.04 light |
|---|---|---|---|---|
| Menus, quick settings, calendar, dialogs (`$bg_color`) | `#1d1d1d` | `#36363a` | `#FAFAFA` | white |
| Notification banner | `#1d1d1d` | `#54545a` | `#FAFAFA` | white |
| Cards: notifications in the list, events, world clocks, quick-toggle menus (`$card_bg_color`) | `#2f2f2f` | `#47474c` / `#54545a` | white | white |
| OSDs: volume, brightness, Alt+Tab (`$osd_bg_color`) | `rgba(29,29,29,0.975)` | `#2f2f2f` | same as dark | `#2f2f2f` |
| Text on pop-ups (`$fg_color`) | `#F7F7F7` | (builder reads) | `#3D3D3D` | (builder reads) |
| Hover tint (`$hover_bg_color`) | `fg` at 10% | (builder reads) | `fg` at 10% | (builder reads) |

Hover and pressed colors in 26.04 are often computed from the surface color (e.g.
`st-lighten(#36363a, 7%)`), so they must change with the surfaces, or they'd look lighter than
what's around them.

## 3. Goals, non-goals, anti-goals

**Goals**
- In dark and light mode, every floating Shell surface (list in §4) shows 24.04's exact
  colors: its background, the cards on it, its text, hover and pressed states, buttons drawn on
  it, separators, borders and outlines.
- The values live in `src/_tokens.scss`, per mode, and can be changed there.
- Tests on a real headless Shell show the computed colors match, in both modes.

**Non-goals (stay as they are)**
- The top bar (Blur my Shell styles it; decision 3), the dock, the overview and app grid
  backgrounds, the lock screen backdrop, the login screen.
- What Blur my Shell styles in the overview: the search result cards and the app folder pop-up
  (its "style components" and "style dialogs" options, on by default and on here). The owner
  chose to leave them to it, like the top bar: dusk adds no color rules for them.
- Apps (GTK4, libadwaita, GTK3). GTK3 colors stay deferred.
- The accent color: it keeps following the Settings picker wherever 26.04 uses it.
- Corner radii, sizes, spacing: unchanged.
- High contrast mode.

**Anti-goals (a failure even if it "works")**
- Text, icons or focus rings that become hard to read on the darker surfaces.
- A hover, pressed or button color lighter than 24.04's, flashing over the new dark surface.
- Literal colors in rule files (the lint forbids them), or anything outside the hooks dusk
  already uses (no JS for colors).
- Erasing one of Yaru's more specific color rules by accident (our stylesheet beats Yaru
  outright, as with radii).

## 4. Surfaces in scope ("everything that floats")

- Top bar menus, and every popup menu in the Shell (context menus, the dock's right-click
  menus, submenus, separators, switches and sliders in menus).
- Quick settings: the panel, toggles, toggle menus, sliders, system items.
- The date menu: calendar, today button, events, world clocks, weather, the message list,
  its Clear and Do Not Disturb controls.
- Notifications: banners, notifications in the list, groups and stacks, media controls.
- Modal dialogs: polkit, end session, run dialog, and the others built on `.modal-dialog`. The
  24.04 dialog colors dusk already sets (outline, buttons) stay; the dialog background joins them.
- OSDs: volume and brightness, keyboard layout, the pad OSD.
- The Alt+Tab app and window switchers.
- Tooltips (dash labels, window titles in the overview) and the screenshot UI panel.
- Not the lock screen's notifications: 26.04 draws them translucent on the wallpaper, and the
  lock-screen backdrop is a non-goal. They stay 26.04's (builder's call, see §8). Since dusk's
  general notification rules would win over Yaru's lock-screen ones, dusk re-asserts those.

The inventory (§6) confirms each surface's selectors on screen; anything it finds that floats
and isn't listed is added there for the owner to see.

## 5. How it's built

- **Same hooks as now:** the `dusk@local` extension's `stylesheet-dark.css` / `stylesheet-light.css`
  (from `src/shell-dark.scss` / `shell-light.scss`, which set `$mode`). No JS.
- **Tokens:** `$shell-colors` in `src/_tokens.scss` already holds per-mode color tokens (most are
  `null` = stock today). It gets the tokens this needs, per surface and state, with 24.04's
  values for each mode. Rule files read them through `shell-color($key)`; a `null` still emits
  nothing.
- **Rules:** as with radii, our stylesheet beats Yaru's outright, so dusk repeats Yaru 26.04's
  own color rules for these surfaces, with the same selectors, in Yaru's source order, values
  from tokens, and re-asserts Yaru's special cases next to any general rule that would erase them.
- **Mapping rule (builder's call, owner checks it in the inventory):**
  - An element that exists in both releases takes 24.04's value for that element and state.
  - An element new in 26.04, with no 24.04 counterpart (e.g. notification stacks), takes
    26.04's own formula applied to 24.04's palette (e.g. "the card color lightened 4%" with
    24.04's card color).
  - Alpha tints (hover = text color at 10%, etc.) keep 24.04's form, so they work in both modes.
- **Accent (builder's call):** wherever 26.04 uses the accent (`-st-accent-color`: checked
  toggles, switches, the selected day, focus rings, focused backgrounds), 26.04's own accent
  expression stays, so it keeps following the picker and keeps the contrast 26.04 tuned for it
  (in dark mode 26.04 whitens the accent 60% for focus rings). Only a surface color inside such
  an expression (e.g. `st-mix(accent, <surface>, 5%)`) is swapped for 24.04's surface. Where only
  one release uses the accent for a state, 26.04 decides. Accent-derived values need no tokens of
  their own beyond the surfaces they mix with.

## 6. Owner gates

1. **This document.**
2. **A color inventory** (`docs/inventory-shell-colors.md`, plus a machine-readable table if the
   builder generates rules from it): per surface and state, the 26.04 selector(s), 26.04's
   value, 24.04's value, and the token. The owner approves it before any rule is written,
   like the radius inventories.
3. **Chunks**, each installed, then checked by the owner in dark and light before the next:
   1. menus and quick settings;
   2. notifications and the date menu;
   3. dialogs, OSDs, the switchers, tooltips and the screenshot panel.
4. Commit and push after each approved chunk.

## 7. Testing

- **Real computed colors:** the headless probe (`tests/headless/dusk-probe@local`) already
  records every visible actor's radii in many UI states. It also records computed background,
  border and text colors, and the states are snapshotted in **dark and light**. Tests compare
  them with the inventory's expected values.
- **Cascade check for colors:** extend `tests/headless/cascade.py` (or add a sibling) so that
  "Yaru plus dusk predicts what Shell computes" and "no general rule of ours erases a Yaru
  special case" also hold for color properties.
- **Drift:** like the GTK inventories, a test checks the color inventory still matches the
  installed Yaru 26.04 stylesheet, so an update that changes a stock color shows up.
- **No regressions:** every existing test still passes.

## 8. Left to the builder (and calls already made)

Left to the builder: the exact selector list, the inventory's format, whether rules are
generated from a table or hand-written, how the probe reads colors, token names, and how
chunk boundaries fall in the code.

Calls made while writing this (owner: check these):
- The on-screen keyboard is not "floating" (it's docked to the bottom) and stays 26.04.
- Lock-screen notifications stay 26.04's translucent ones (§4).
- Tooltips and the screenshot UI panel count as floating.
- New-in-26.04 elements use 26.04's formulas on 24.04's palette (§5).
- Accent expressions stay 26.04's; only surfaces inside them change (§5).
- Other extensions' own floating UI (e.g. Tiling Shell's snap assistant and layout editor) is
  theirs, like apps: not in scope.
