# dusk — design

Theme name: **dusk** (owner's choice).
Status: built (branch `dusk-v1`, Tasks 1–12 done and approved, 2026-10-29). §4
lists every owner decision, including the ones made while building.
Date: 2026-10-28. Owner: the user (Ubuntu user `ubuntu`, home `/home/ubuntu`).

## 1. Intent

A small, personal theme layer for Ubuntu 26.04 that lets the owner control
**corner radius everywhere**, restore the **old Shell modal dialog look**, and
later tweak **colors** — while everything else stays stock Ubuntu (Yaru).

It is an override layer, not a theme. Stock Yaru stays the base for the Shell,
for libadwaita apps and for GTK3 apps. We only add rules for the things we
change, through official hooks, so system updates keep working and the whole
thing can be removed cleanly.

Success looks like:
- Changing one token in `src/_tokens.scss` and re-running `install.sh` changes
  that radius (or color) consistently across Shell and apps.
- Shell modal dialogs look like Ubuntu 24.04's (details in §6).
- With all tokens at their defaults, the desktop looks like stock Ubuntu except
  for the dialogs and the proposed radius scale.
- `uninstall.sh` returns the system to exactly how it was.

## 2. Goals, non-goals, anti-goals

**Goals**
- Corner radius for **every rounded element** in the Shell, in libadwaita
  apps and in GTK3 apps (owner's decision, v1). "Rounded" means the element
  has a non-zero radius in stock Yaru on this machine. That includes the core
  list (windows, buttons, entries, popovers, menus, cards, dialogs,
  notifications, quick settings, OSDs, top bar items and their dropdown
  menus) and everything else that's rounded, for example:
  - Apps: tabs, sidebar row highlights, tooltips, toasts, banners, view
    switchers, progress and level bars, scrollbars, dropdowns, spin buttons.
  - Shell: Alt+Tab switcher, workspace switcher, app grid icons and folders,
    overview search results, screenshot UI, calendar days, message list
    items, and Shell's own buttons (notification actions, "Clear", calendar
    buttons).
  - Elements with radius 0 in stock stay square. Elements that are circles
    in stock stay circles.
  - Excluded, because they're out of scope (§2 non-goals): lock screen, GDM,
    high contrast, Looking Glass. (Ubuntu Dock was excluded too, until the
    owner brought its corners in, decision 17.)
  - Ubuntu Dock's right-click menus share Shell's menu styling, and St CSS
    can't exclude them, so they follow the menu token. That's accepted.
- Controls (buttons, switches, checkboxes, radios, sliders, entries): **radius
  only** for now. Size, flat style and colors stay stock. Each control type
  gets its own radius token.
- Shell modal dialogs: Ubuntu 24.04 (GNOME 46) Yaru style (§6).
- Colors: the structure for color overrides exists from day one, but every
  color token starts **unset** (= stock Yaru). The owner sets only the ones
  that bother them, later.
- Dark mode first. The structure has a slot for light, left empty for now.

**Non-goals (stay stock / out of scope)**
- Accent color: never set by us. It always follows the picker in Settings.
- Top bar background and colors: never set. Blur my Shell stays fully on and
  owns the top bar's look.
- Lock screen (unlock dialog) and GDM login screen.
- Ubuntu Dock's look other than corners (decision 17).
- High-contrast mode.
- Qt apps, icons, cursors, fonts, wallpapers.
- Patching Shell JavaScript or layouts. **Three approved exceptions** (owner,
  2026-10-28 and 2026-10-29), all of the form "make Shell honour a CSS value
  it sets in code instead": (1) §6, the dialog button row follows the CSS
  `spacing`; (2) the overview's workspace wallpaper follows
  `.workspace-background`'s CSS `border-radius` (Shell hard-codes 30px in
  `workspace.js`); (3) the main app grid's icons follow `-dusk-app-icon-size`
  (§4.20). Nothing else.
- Window corners for apps that aren't libadwaita/GTK3 CSD, and the bottom
  corners of GTK3 windows: the owner uses the "Rounded Window Corners Reborn"
  extension, and the README points to it. We don't reimplement it.

**Anti-goals (failure even if it technically works)**
- Copying or forking any theme file (no full `gnome-shell.css`, no User
  Themes extension, no copy of Yaru).
- Hardcoded radius or color values in rule files. Every value comes from
  `src/_tokens.scss`.
- Guessed selectors. Every selector is checked on this machine first (Looking
  Glass for Shell, GTK Inspector for apps).
- Fighting other extensions (especially Blur my Shell on the top bar).
- An install or uninstall that leaves stray files or settings behind.

## 3. The system it runs on (checked 2026-10-28, read-only)

- Ubuntu 26.04.1 LTS, GNOME Shell 50.1, Wayland, session mode `ubuntu`.
- Shell theme: Yaru (`/usr/share/gnome-shell/theme/Yaru*`), set by the
  `ubuntu` session mode.
- GTK 4.22.4, libadwaita 1.9.1, GTK 3.24.52.
- GTK theme `Yaru-sage-dark`, `color-scheme` = `prefer-dark`, accent picker
  set to slate.
- **Ubuntu's libadwaita is patched with Yaru built in**: it carries one
  stylesheet per Yaru accent (`default-dark-yaru-sage.css` and so on). So
  "stock" libadwaita apps here already look Yaru.
- `~/.config/gtk-4.0/` and `~/.config/gtk-3.0/` hold only `settings.ini`
  (plus `bookmarks`). There's no `gtk.css` yet.
- `sassc` 3.6.1 is installed; dart-sass (`sass`) isn't.
- Flatpak is **not installed**. Snaps: only system snaps, no desktop apps.
- adw-gtk3 isn't installed and isn't in Ubuntu's repos (not used: see §4).
- Enabled user extensions: Blur my Shell, Tiling Shell, Caffeine, Tasks in
  Panel, Vitals, plus Ubuntu's defaults (Ubuntu Dock, AppIndicators, …).
  User Themes and Just Perfection are installed but disabled.
- Rounded Window Corners Reborn is not installed.

## 4. Decisions made by the owner

1. Base everywhere is stock Yaru. adw-gtk3 is dropped.
2. Accent follows the Settings picker.
3. Blur my Shell stays fully on, including the top bar. No top bar background
   or colors from us. We only control the **radius** of top bar items: panel
   buttons, status area, clock, their hover/active highlights, and their
   dropdown menus.
4. Dark only first; keep the structure ready for light.
5. Controls: radius only, one token per control type.
6. Dialogs: Ubuntu 24.04 (GNOME 46) Yaru style. Default button uses accent
   **text**, no accent background. Dialog radius comes from tokens.
7. Lock screen and GDM: stock.
8. Ubuntu Dock: untouched.
9. Radius: the builder proposes a scale (§7) and the owner tweaks it.
10. Colors: start from Yaru, change only what bothers the owner.
11. Repo at `~/dusk`, with git. This design doc lives in `docs/`.
12. The theme is named **dusk**.
13. GTK3 window corners: keep Yaru's top-only rounding, with the value from
    our window radius token. Bottom corners come from Rounded Window Corners
    Reborn, which the owner installs. No bottom-corner CSS from us.
14. Scope: every rounded element follows the scale in v1, not just the core
    list (§2).
15. Dialog button gap (decided after the Task 3 probe): allow one small JS
    exception in `extension.js` so the dialogs can match 24.04 exactly (§6).
16. Overview workspace corners (decided in Task 7): allow a second small JS
    exception so the workspace wallpaper follows `$radius-workspace`. Shell
    clips it at `BACKGROUND_CORNER_RADIUS_PIXELS = 30` in `workspace.js`; that
    is the only corner Shell sets in code (all Shell JS searched).
17. Ubuntu Dock's corners (owner, during Task 8): the dock background and the
    icon hover highlight follow the theme (`$radius-dock`, `$radius-dock-item`),
    replacing decision 8 ("Ubuntu Dock: untouched") for corners only. Its
    other styling stays stock. In the Ubuntu session the dock's own
    stylesheet is empty and relies on Yaru's dock rules, which dusk mirrors in
    Yaru's order, with values from tokens.
18. No pills (owner, during Task 8): every element that was a pill uses a
    scale step instead, in Shell and apps. Only truly round things stay round:
    avatars, dots, badges, round icon backgrounds, switch and slider knobs,
    handles, radio buttons. **Exception (owner, Task 12): switch tracks are
    back to their original pill shape**, in Shell and apps alike.
19. Window buttons round (owner, after Task 12): close, minimize and maximize
    are circles in every app, `$radius-titlebutton: $r-circle`. Electron apps
    that hide the system title bar (Claude) draw their own round buttons in
    Chromium code, which no theme can reach, so everything else matches them.
    GTK3 keeps Yaru's own 24px circles (a radial gradient; a radius on Yaru's
    30px button box would draw a bigger one). GTK4 and libadwaita get 50% on
    the button's 24px icon box, which is also what draws the title bars of
    X11 apps (Mutter's frames helper, plain GTK4). Any other token value
    squares them again: GTK3 then swaps the gradient for a flat tint.
21. Lock screen (owner, 2026-10-29), replacing decision 7 for the lock
    screen only: `metadata.json` adds `session-modes: ["user",
    "unlock-dialog"]`, so dusk's stylesheet styles the unlock dialog, and
    Yaru's lock-screen rules are mirrored with tokens. The login screen
    (GDM) stays stock: it never loads dusk.
23. Dialogs back to 26.04's layout (owner, 2026-10-29), replacing decisions 6 and 15: every
    Shell dialog (Log Out / Power Off / Restart, password prompts, the rest) keeps Yaru 26.04's
    own layout, with separate buttons and Shell's 12px gaps. dusk's 24.04 dialog styling (flush
    buttons, 1px dividers, outline, its own button colors, the default button in accent text) and
    the button-gap JS exception are removed. Dialogs keep dusk's corners (`$radius-dialog`, and
    `$radius-dialog-button` on the md step) and stay in the color work (decision 22, chunk 3).
22. Shell pop-up colors like Ubuntu 24.04 (owner, 2026-10-29), in dark and light: every floating
    Shell surface takes 24.04 Yaru's exact colors, except what Blur my Shell styles. Replaces
    decision 10 ("colors from Yaru") for those surfaces. Design:
    [2026-10-29-dusk-shell-colors-design.md](2026-10-29-dusk-shell-colors-design.md).
20. App grid icon size (owner, 2026-10-29): a third small JS exception.
    Shell 50 picks the app grid's icon size in code from 96/64/48/32px,
    starting at 64px, and its icons ignore CSS `icon-size`. dusk sets the
    main grid's own `fixed-icon-size` property from `$app-grid-icon-size`
    (96px), read from `-dusk-app-icon-size` on `.icon-grid`. The grid then
    fits fewer icons per page. Search results match it (owner, same day):
    app results are app grid icons, which `extension.js` sizes the same way
    as search adds them to its grid; other results (system actions) read
    CSS `icon-size`. Folder grids and the dock keep Shell's sizes;
    `disable()` gives Shell its own size back, also to results on screen at
    the time. It watches the grid rather than patching the method that makes
    the results: Ubuntu Dock patches that method too, and whenever Do Not
    Disturb changes it takes its patch off and back on, removing ours (found
    live, 2026-10-29).
24. The notification indicator next to the top bar clock (owner,
    2026-10-29). Shell shows a bell there for unseen notifications. Blur my
    Shell's Contrasted top bar gives it a pill of its own with 14px corners
    and 8px padding inside 3px borders, which left its 16px icon 10px of the
    32px top bar. dusk gives it the clock's corners (`$radius-topbar-item`)
    and `$topbar-indicator-padding` (5px) above and below the icon: the
    whole icon shows, in a pill as tall as the clock's. Without that top bar
    style the bell has no pill and looks as stock.
25. Blur my Shell's search entry and folder name entry (owner,
    2026-10-30). dusk's general entry colors, and the stock rules it keeps
    for the overview's search entry and an app folder's name entry, came out
    as strong as Blur my Shell's own rules for them; dusk's stylesheet loads
    later, so the search entry turned solid grey with a focus ring while
    typing, and the folder name entry solid. dusk now re-asserts Blur my
    Shell's own look there (`$blur-my-shell-entry-*`, copied from its
    stylesheet), under its own style classes, so it applies only while that
    style is on; with it off, the kept stock rules apply (the search entry
    stays readable in light mode). A Blur my Shell update that changes those
    colors fails `test_blur_my_shell_entries_keep_its_look`.
    (Retired by decision 26: dusk's theme copies nothing of Blur my Shell.)
26. dusk's own Shell theme (owner, 2026-10-30), replacing the extension
    stylesheet: dusk's theme is built from a copy of Yaru 26.04's Sass source
    and loaded in Shell's base slot, in Yaru's place, so nothing overrides
    anything and Yaru's updates can't reach it. Decisions 22 to 25 are now
    made in that source. dusk also draws the top bar itself: see-through, a
    pill behind each button, black in dark mode and the light pop-ups' colors
    in light mode, the same on hover, none on the lock screen, so Blur my
    Shell isn't needed. The theme loader is a third JS exception. Design:
    [2026-10-30-dusk-shell-theme-design.md](2026-10-30-dusk-shell-theme-design.md).

## 5. Architecture

> **Shell row superseded by decision 26 (2026-10-30):** dusk's Shell theme now sits in Shell's base
> slot, in Yaru's place, and the extension's stylesheets described in this section are gone.

Three layers. Each one overrides stock styling through its official hook.

| Layer | Hook | Loaded on top of | Our output |
|---|---|---|---|
| GTK4 / libadwaita | `~/.config/gtk-4.0/gtk.css` (user priority) | libadwaita's built-in Yaru styles | `build/gtk4.css` |
| GTK3 | `~/.config/gtk-3.0/gtk.css` | the active Yaru GTK3 variant (whatever accent is picked) | `build/gtk3.css` |
| GNOME Shell | a tiny extension's stylesheet, auto-loaded by Shell | Yaru Shell theme | `extension/stylesheet-dark.css`, `extension/stylesheet-light.css` |

How these layers behave on this system (checked):
- **GTK**: the user `gtk.css` is loaded at a higher priority than the theme.
  As far as I know, GTK picks the higher-priority provider before it compares
  selector specificity, so our selectors can stay simple. The builder confirms
  this on the first GTK4 rule.
- **libadwaita variables available here**: all the color variables
  (`--window-bg-color`, `--view-bg-color`, `--popover-bg-color`,
  `--card-bg-color`, `--headerbar-bg-color`, `--sidebar-bg-color`,
  `--dialog-bg-color`, …) and **`--window-radius`** (15px stock). Every other
  radius is hardcoded in the stylesheet, so radius needs per-widget rules.
  `@media (prefers-color-scheme: dark)` is supported (libadwaita uses it
  itself).
- **Shell extension stylesheets**: Shell 50 looks in the extension folder, in
  this order: `ubuntu-dark.css`, `stylesheet-dark.css`, `ubuntu.css`,
  `stylesheet.css` (or the `-light` names in light mode). It loads the first
  one it finds, and reloads automatically when you switch light/dark. It
  unloads the stylesheet when the extension is disabled and reloads it when
  re-enabled.
- **Shell CSS** has no custom variables and no media queries. It does have a
  built-in `-st-accent-color` / `-st-accent-fg-color` (which follow the
  picker), color functions (`st-mix`, `st-lighten`, `st-transparentize`), and
  `:first-child` / `:last-child`.
- ~~Our Shell stylesheet loads after Yaru, so it wins at equal
  specificity.~~ **Corrected in Task 5, from live measurements:** St ranks an
  extension stylesheet above the theme outright. Our rules beat Yaru's
  whatever their specificity, even `!important` ones. So a general rule of
  ours also erases Yaru's more specific special cases (e.g. square items
  inside a submenu); those are re-asserted. `tests/test_headless.sh` checks
  the live Shell against a model of this cascade, and
  `test_shell_keeps_yaru_special_cases` checks the special cases statically.

**Light vs dark:** radius and the dialog layout don't depend on the mode. Only
colors do. So each layer splits into "common rules" (always on) and "color
rules" (per mode):
- GTK4: common rules at top level, dark colors inside
  `@media (prefers-color-scheme: dark)`, and a light block left empty.
- Shell: both `stylesheet-dark.css` and `stylesheet-light.css` contain the
  common rules plus their own mode's colors. Light colors are empty for now,
  so light mode still gets radius and dialogs.
- GTK3: GTK3 CSS can't detect the mode. Radius works in both modes. GTK3
  color overrides would apply in both modes, so **GTK3 color tokens stay
  unused until we design a light/dark answer for GTK3.** That's a known later
  decision, not part of this build.

## 6. Shell modal dialogs

> **Superseded by decision 23 (2026-10-29):** dialogs are back to Yaru 26.04's own layout; the
> 24.04 layout below, and the JS exception it needed, are history.

**Target look (Ubuntu 24.04 / GNOME 46 Yaru):** buttons sit flush against the
bottom edge of the dialog and split its full width equally. A 1px divider runs
above the button row and between buttons. Only the dialog's outer bottom
corners are rounded, using the dialog radius token. No floating pill buttons.
The default button uses accent-colored text (`-st-accent-color`) and no accent
background. Hover/pressed backgrounds and the divider color follow the 24.04
Yaru values, converted into tokens.

**Reference for exact values:** the Yaru shell theme source in the
`ubuntu/yaru` GitHub repository at its Ubuntu 24.04 release, modal dialog
section. Read it as reference only, never copied wholesale.

**Applies to:** every Shell modal dialog. They all use the same base
(`dialog.js`): log out / restart / power off, polkit authentication prompts,
the extension install prompt, and dialogs from other extensions. Not the lock
screen.

**How GNOME 50 builds a dialog (from `/org/gnome/shell/ui/dialog.js`):**
- `.modal-dialog`: a vertical box. In Yaru dark: padding 24px, spacing 18px,
  radius 18px. Its two direct children are siblings:
  - `.modal-dialog-content-box` (Yaru: padding-top 12px, spacing 18px)
  - `.modal-dialog-button-box` (Yaru: padding-top 6px). It's an `St.Widget`
    with a `Clutter.BoxLayout`, `homogeneous: true` and **`spacing: 12`
    set in code**.
- Buttons are `.modal-dialog-button`, and the default one has the `:default`
  pseudo-class. In Yaru: radius 12px, padding 12px, light translucent
  background.
- The GNOME 46 class `modal-dialog-linked-button` no longer exists. The 24.04
  rules must be re-expressed on `.modal-dialog-button`.

**Plan of attack:** move the dialog's padding off `.modal-dialog` and onto
the content box. Zero the dialog spacing and the button box padding. Give the
button box a top divider. Make the buttons square and transparent, with
dividers between them. Use `:first-child` / `:last-child` (and the
only-child case) to round the outer bottom corners.

**Known risk, checked first:** the 12px gap between buttons is set in JS, not
CSS. The first thing the builder tests is whether `spacing: 0` in our CSS
overrides it. If it doesn't, the fallback is a negative horizontal margin on
the buttons. If neither works, stop and come back to the owner. No JS
patching without the owner's say-so.

**Result (Task 3, 2026-10-28):** CSS `spacing: 0` has no effect: the owner
saw the gap remain in a `pkexec` prompt. The fallback is impossible too,
because Clutter actor margins can't be negative (minimum 0, per the
Clutter-18 type data). The owner chose a small JS exception over a CSS-only
approximation. `extension.js` uses Shell's `InjectionManager` to wrap
`Dialog.prototype._createDialog`. After the original runs, it makes the
button row's layout honour the stylesheet's `spacing` on
`.modal-dialog-button-box`, but only when a stylesheet sets one. `disable()`
restores the original method. The value itself stays a token. If a future
Shell renames the method, the wrapper is skipped: the stylesheet still
applies, but the buttons keep Shell's 12px gaps.

**What 24.04 actually does (from the Yaru source):** the dividers are 1px
gaps between buttons tinted with the foreground color, not drawn lines. With
the JS exception, the gap is simply `spacing: 1px` on the button row.

## 7. Tokens (`src/_tokens.scss`)

The single source of truth. Rule files never contain literal radius or color
values.

### 7.1 Radius scale (proposed; the owner tweaks)

A base scale in 3px steps, following libadwaita's own rhythm (6 / 9 / 12 / 15
/ 18). That way nested corners line up: an item's radius ≈ its container's
radius minus the padding between them.

`xs 6px · sm 9px · md 12px · lg 15px · xl 18px · pill 999px · circle 50%`

**Changed by the owner (2026-10-28, after chunk A): squarer corners, twice**, to
`xs 2px · sm 3px · md 4px · lg 5px · xl 6px · xxl 8px`. **Then a little rounder (2026-10-29):**
now `xs 3px · sm 4px · md 6px · lg 7px · xl 9px · xxl 12px · pill · circle`. Element tokens still
point at the same steps; only the step values changed, so the px numbers in the tables below and
in the inventories are from the first proposal.

Each element gets its own token pointing at a scale step, so the owner can
change one element without touching the scale. "Now" values come from Yaru's
stylesheets on this machine. Shell values are the **effective** ones: Yaru
overrides some of its own values later in the file (e.g. menus 20 → 16.8).
They get a final check in Looking Glass.

The proposal snaps each element to the nearest step, and keeps pills as pills
unless noted. ⚠ marks a proposal that's a visibly bigger change than a few
pixels, or that changes the shape. The owner decides those while reading.

| Element token | Now: apps (libadwaita) / GTK3 / Shell | Proposed |
|---|---|---|
| checkbox | 6 / 3 / 6–7 | xs (6) |
| radio | circle / circle / circle | circle |
| button (apps) | 9 / 6 / — | sm (9) |
| Shell buttons (notification actions, "Clear", calendar…) | — / — / mixed: pills and 8 | pills stay pills, 8 → sm (9); final grouping in the step 3 inventory |
| entry | 9 / 6 / 8 | sm (9) |
| search entry (Shell) | — / — / pill | pill (stock) |
| switch | pill / 14 / pill | pill |
| slider trough + knob | pill / pill / pill | pill |
| menu item (in menus/popovers) | 9 / — / 12 | sm (9) |
| top bar item highlight | — / — / pill | pill (stock; token lets owner change) |
| card, boxed list, calendar event / world clocks / weather buttons | 12 / — / 8–12 | md (12) |
| popover / menu (incl. top bar dropdowns) | 15 / 15 (menus 8) / 16.8 | lg (15) |
| notification | — / — / 16 (banner), 18 (in the message list) | lg (15) |
| OSD (volume, brightness…) | — / — / pill | pill (stock) |
| quick settings panel | — / — / 36 | xl (18) ⚠ halves it |
| quick toggle | — / — / 16.8 (plain); the ones with a menu arrow may still be pills (to confirm in Looking Glass) | lg (15) for both ⚠ if they are pills now, they lose that shape |
| window | 15 / 15 (top corners) / — | lg (15); GTK3 stays top corners only |
| dialog (Shell modal + app dialogs) | ? / ? / 18 | xl (18) |

**This table is the core set, not the full list.** Every rounded element is
in scope (§2), so each layer's build step (§10) **starts with an inventory**:
- List every selector with a non-zero radius in that layer's stock
  stylesheet, minus the exclusions.
- Group them into element tokens. Where an element clearly belongs to a core
  token, reuse it (e.g. dropdowns → button, spin buttons → entry, context
  menus → popover). Only add a new token where nothing fits.
- Show the owner a table like the one above for that layer: element, Now,
  Proposed, ⚠. Proposals use the same snap rule.

The owner approves that table before any rules for the layer get written.
New tokens join `_tokens.scss` with their layer.

### 7.2 Colors

- **Shell pop-ups (decision 22):** Yaru 24.04's colors, in dark and light, for every floating
  surface, set where dusk's theme defines them (decision 26). Design and details:
  [2026-10-29-dusk-shell-colors-design.md](2026-10-29-dusk-shell-colors-design.md).
- **Apps:** tokens map one-to-one onto libadwaita's color variables. Every one is unset (an unset
  token emits no rule, so the stock Yaru color shows).
- The accent has no token (a non-goal). The top bar's pills do (decision 26).

### 7.3 Spacing

None, except the padding of the bell next to the top bar clock (decision 24). The 24.04 dialog
spacing went with decision 23.

## 8. Repo layout

```
~/dusk/
  src/_tokens.scss     # single source of truth: radius scale, element radii, colors, spacing
  src/gtk4.scss        # libadwaita overrides
  src/gtk3.scss        # Yaru GTK3 overrides
  src/shell-theme/     # dusk's Shell theme: a copy of Yaru's source with dusk's edits (decision 26)
  extension/           # metadata.json, extension.js (three approved exceptions, §4.15–16, §4.20), compiled stylesheet-dark.css / stylesheet-light.css
  build/               # compiled gtk4.css / gtk3.css (gitignored)
  docs/                # this design doc
  install.sh
  uninstall.sh
  README.md            # what each file does, how to find selectors, how to update after a GNOME release
```

Differences from the owner's original sketch: the extension ships
`stylesheet-dark.css` + `stylesheet-light.css` instead of one
`stylesheet.css` (§5). GTK3 builds on Yaru, not adw-gtk3. A `build/` folder
holds the compiled GTK files.

Compiled CSS (in `build/` and `extension/`) is gitignored. Source lives only in
`src/`.

Extension: UUID `dusk@local`, `shell-version: ["50"]`, default session
modes (normal session only, so the lock screen stays stock). The `@local`
suffix matches the owner's other personal extension (`nothing-icon-size@local`)
and avoids looking like an official Ubuntu extension (builder's call).

## 9. install.sh / uninstall.sh

**install.sh** (idempotent: running it twice is the same as once):
1. Check `sassc` is present. If not, stop and say so.
2. Compile `src/` into `build/gtk4.css`, `build/gtk3.css`,
   `extension/stylesheet-dark.css` and `extension/stylesheet-light.css`.
3. For each target (`~/.config/gtk-4.0/gtk.css`, `~/.config/gtk-3.0/gtk.css`,
   `~/.local/share/gnome-shell/extensions/dusk@local`):
   - Already our symlink → leave it.
   - A real file or another link → move it to a timestamped backup next to
     it, then create our symlink.
   - Missing → create our symlink.
4. Enable the extension.
5. Only if `flatpak` is installed: apply
   `flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro`.
   Flatpak apps can't follow symlinks into `~/dusk`, so in that case the GTK
   targets must be copies, or `~/dusk/build` must be exposed too. The
   builder picks one when it comes up. Flatpak isn't installed today.
6. Record what it did in a small state file, so uninstall reverts exactly
   that.

**uninstall.sh:** disable the extension. Remove only the symlinks that point
into `~/dusk`. Restore the newest backups. Undo the Flatpak override only
if install added it. Delete the state file. Leave nothing else changed.

**Gotchas the README must cover:**
- On Wayland, Shell only notices a newly added extension after logging out
  and back in once. After that first time, a Shell change is: run
  `install.sh`, then disable and re-enable the extension (that reloads the
  stylesheet).
- GTK apps read `gtk.css` at startup. Restart the app to see changes, or use
  GTK Inspector's live CSS editor while experimenting.

## 10. Build order and gates

Each step ends with: exactly which files changed, how to test, and how to
revert. The owner approves before the next step starts.

1. **Skeleton:** git repo, the folder layout, `_tokens.scss` with the
   proposed values, empty layer files, the empty extension, `install.sh`,
   `uninstall.sh`, a README stub. Show the structure before any styles.
2. **Shell dialogs** (§6), starting with the button-gap check.
3. **Rest of Shell:** inventory first (§7.1), owner approves the Shell
   table, then the rules: top bar items and their menus, popups and menu
   items, notifications, quick settings, calendar, OSDs, and every other
   rounded Shell element. Color hooks, all unset. Expected to be the biggest
   step, so it may be split into smaller approved chunks (e.g. top bar and
   menus → notifications and calendar → overview, switchers and the rest).
4. **GTK4 / libadwaita:** inventory first, owner approves the table, then
   the radius rules and color hooks (unset).
5. **GTK3:** inventory first, owner approves the table, then the radius
   rules. Colors deferred (§5).

Steps 3–5 were not ordered by the owner beyond "Shell dialogs, then GTK4,
then GTK3". Putting the rest of Shell right after dialogs is the builder's
call.

## 11. How each layer gets tested

- **Selectors:** Looking Glass (Alt+F2 → `lg` → picker) for Shell. GTK
  Inspector (`GTK_DEBUG=interactive <app>`) for apps. Every selector in a
  rule file is checked this way, and the comment above the rule says what it
  targets.
- **Shell dialogs:** open each kind and cancel it: the log out and power off
  dialogs, a polkit prompt (e.g. `pkexec true`), and an extension install
  prompt. If a nested Shell (`gnome-shell --devkit`) is available on this
  machine, prefer it for early experiments. The builder checks whether it is.
- **GTK4 / GTK3:** a few installed apps of each kind, before and after, in
  dark mode.
- **Revert check:** run `uninstall.sh` and confirm all three targets are back
  to their pre-install state.

## 12. Left to the builder

- Exact SCSS mechanics: how "unset token = no rule" works, and how one
  `shell.scss` produces both dark and light stylesheets (e.g. thin entry
  files that set a mode variable).
- The state file format, and the backup file naming.
- Which apps to test with.
- Exact 24.04 values for divider color, button padding and hover/pressed
  backgrounds, read from the Yaru 24.04 source.
- README wording.

## 13. Notes from the recon

- Yaru's compiled Shell CSS contains a few literal `$yaru_popup_radius`
  strings, i.e. an unexpanded SCSS variable. Shell will ignore those values.
  This may matter when we override radius on quick settings or buttons: what
  you see now may not be what the CSS seems to say. Confirm in Looking Glass.
- Ubuntu's libadwaita chooses its Yaru stylesheet from the GTK theme name
  (`Yaru-sage-dark` → `yaru-sage`). Our `gtk.css` applies on top of whichever
  one is active.

## 14. Calls the builder made (owner: check these)

None of these were decided by the owner. Each can be changed.

1. The radius scale (6 / 9 / 12 / 15 / 18 / pill / circle) and the snap
   rule: nearest step, pills stay pills, circles stay circles, square stays
   square.
2. The ⚠ proposals in §7.1: quick settings panel 36 → 18, and quick toggles
   → 15.
3. Unset color tokens emit no rule (stock shows). The new dialog divider and
   dialog button hover/pressed colors start at Ubuntu 24.04's values.
4. GTK3 color overrides are deferred until there's a light/dark answer for
   GTK3.
5. The Shell extension ships `stylesheet-dark.css` + `stylesheet-light.css`
   rather than one `stylesheet.css`. Both carry the radius and dialog rules.
6. Extension UUID `dusk@local`.
7. Build with `sassc` (already installed). Compiled output in `build/` and
   `extension/`, gitignored.
8. install.sh: timestamped backups, a state file for exact uninstall, and
   the Flatpak step only if Flatpak is installed.
9. Build order: rest of Shell right after dialogs, then GTK4, then GTK3.
   Each layer starts with an inventory table for the owner to approve.
