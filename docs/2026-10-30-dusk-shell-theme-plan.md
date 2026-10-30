# dusk's own Shell theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace dusk's override layer with dusk's own complete Shell theme (a frozen copy of Yaru 26.04's source with dusk's corners, 24.04's colors and the grouped top bar set in place), loaded by dusk's extension in Yaru's place.

**Architecture:** Yaru 26.04's Shell Sass (with the GNOME Shell upstream Sass it bundles) is copied into `src/shell-theme/yaru/` untouched, then edited in place, every edit marked `// dusk:`. `build.sh` compiles it to `extension/theme/dusk-{dark,light}.css` (plus its images). `extension/extension.js` puts that file in the St theme's base slot (`default_stylesheet`), with nothing on top, and puts it back each time Shell rebuilds its own theme. Golden records of today's computed look prove parity.

**Tech Stack:** Sass (sassc), GJS (GNOME Shell 50 extension), St, bash tests (`tests/run.sh`), Python test helpers (`tests/headless/*.py`), the headless probe (`tools/headless-probe.sh`).

**Spec:** [docs/2026-10-30-dusk-shell-theme-design.md](2026-10-30-dusk-shell-theme-design.md) (read it with this plan).

## Global Constraints

- On the Shell side dusk depends only on GNOME Shell 50: Yaru's stylesheet is not loaded while dusk runs; no User Themes extension; no system files, nothing installed as root.
- The Yaru copy: `ubuntu/yaru` tag `26.04.5.1ubuntu`, with Yaru's licence files and attribution.
- Changes are made where a value is defined, never layered on top: dusk adds no override rules and no `!important` of its own. Yaru's own `!important` stays unless it stands in the way of 24.04's look; then it's changed in place.
- Values dusk sets come from tokens in `src/_tokens.scss` (the lint forbids literals in dusk's own rule files). Every dusk edit in the Yaru copy carries a `// dusk:` comment.
- The extension stays `dusk@local`, session modes `user` and `unlock-dialog`; disabling it gives stock Ubuntu back. It keeps the two existing code exceptions (overview wallpaper corners, 96px app icons) and adds the theme loader as the third, marked as such.
- Global fixes only: never a rule for one app or one extension.
- Tests and reviewers never run `install.sh`, `uninstall.sh`, `tools/shell-reload.sh`, `gnome-extensions` or `gsettings set` against the live session; the probe runs in its own isolated Shell.
- Commit messages carry no attribution lines.
- Owner gates: after Task 3 (gate 2: stock look, loader checks), after Task 9 (gate 3: dusk's full look; the owner turns Blur my Shell's top bar style off), and before merging (Task 11).

## Review Focus

- Dark/light switched while a menu is open: the open menu restyles in dusk's colors, and Yaru never comes back (Task 3 test `test_headless_theme_survives_switches`).
- Another extension calls `Main.setThemeStylesheet()` / `Main.loadTheme()` (User Themes installed by mistake): dusk's base comes back, the other stylesheet is dropped (Task 3, same test, a "foreign loadTheme" step).
- Extension stylesheets loaded before or after dusk (Blur my Shell, Ubuntu Dock) survive every theme swap (Task 3 test `test_headless_theme_keeps_extension_stylesheets`).
- dusk disabled and enabled again (`tools/shell-reload.sh`): stock Ubuntu exactly while off, dusk's theme again when on, no duplicate signal handlers (Task 3 test `test_headless_theme_disable_restores_stock`).
- High Contrast switched on: dusk's theme stays (owner-accepted), with no loop and no error in Shell's log (Task 3, `test_headless_theme_survives_switches`, High Contrast step).

---

### Task 1: Tag today's version and record its look

**Files:**
- Create: `tests/headless/golden.py`, `tests/golden/static-{dark,light}.json`, `tests/golden/probe-{dark,light,dark-dock,dark-blur,dark-accent}.json`, `tests/golden/exceptions.tsv`, `tests/test_golden.sh`

**Interfaces:**
- Produces (`tests/headless/golden.py`, CLI and functions):
  - `record_static(base_css: str, overlay_css: str | None) -> dict` — for every selector in `overlay_css` (today: `extension/stylesheet-MODE.css`), its element (`colors.element`) in the state its selector names, and menu items also in `colors.MENU_ITEM_STATES`: `{"<selector>[:<extra states>]": {"colors": [bg, fg, border, shadow], "radii": [tl, tr, br, bl]}}`. A color is `[r, g, b, a]`, or the winning raw value (whitespace-normalized) when it uses the accent; radii in px.
  - `record_probe(snapshots: dict) -> dict` — `{"<state>|<cascade.describe()>|<n>": {"colors": ..., "radii": ...}}`, `n` numbering widgets with the same description in a state.
  - `check_static(theme_css: str, golden: dict, exceptions: list, only: str | None = None, slots: list[str] | None = None, overlay_css: str | None = None) -> list[str]` — predicts with `theme_css` (origin 0) and, only while today's overlay exists, `overlay_css` on top (origin 1); returns one line per differing key and slot (`only`: a regex on keys; `slots`: any of `bg`, `fg`, `border`, `shadow`, `radius`; default all) not covered by an exception.
  - `check_probe(snapshots: dict, golden: dict, exceptions: list, only: str | None = None, slots: list[str] | None = None) -> list[str]`.
  - `load_exceptions(path) -> list` — `tests/golden/exceptions.tsv` columns: key regex, slot (`bg`, `fg`, `border`, `shadow`, `radius` or `*`), task, reason.
  - CLI: `golden.py record-static BASE.css OVERLAY.css OUT.json`, `golden.py record-probe SNAPSHOTS.json OUT.json`, `golden.py check-static THEME.css GOLDEN.json EXCEPTIONS.tsv [--overlay OVERLAY.css] [--only REGEX] [--slots LIST]`, `golden.py check-probe SNAPSHOTS.json GOLDEN.json EXCEPTIONS.tsv [--only REGEX] [--slots LIST]`; exit 1 on any problem line.

- [ ] **Step 1:** Tag the current `main`: `git tag dusk-overlay-final` (local; pushing it waits for the owner).
- [ ] **Step 2: Write the failing tests** in `tests/test_golden.sh`:
  - `test_golden_static_matches_today`: for dark and light, `golden.py check-static <installed Yaru MODE css> tests/golden/static-MODE.json tests/golden/exceptions.tsv --overlay extension/stylesheet-MODE.css` reports nothing. (While today's overlay still exists; Task 3 replaces this test, see there.)
  - `test_golden_probe_matches_today`: for each recorded variant, `golden.py check-probe` on that variant's `probe_dir` snapshots reports nothing.
  - `test_golden_check_reports_a_change`: a copy of a golden with one menu background changed makes `check-static` exit 1 naming that key and `bg`.
- [ ] **Step 3: Run them:** `tests/run.sh test_golden` — FAIL (no `golden.py`, no records).
- [ ] **Step 4: Implement `tests/headless/golden.py`** with the interfaces above, reusing `colors.element`, `colors.predict`, `cascade.predict`, `cascade.describe`, `colors.MENU_ITEM_STATES`.
- [ ] **Step 5: Record** the static goldens (dark, light) and the probe goldens (variants dark, light, dark dock, dark blur, dark accent) from today's build; `exceptions.tsv` starts with its header only.
- [ ] **Step 6: Run:** `tests/run.sh test_golden` — PASS. Full suite `tests/run.sh` — PASS.
- [ ] **Step 7: Commit:** `test: record today's Shell look as golden parity data`.

### Task 2: Copy Yaru 26.04's Shell source and build it unchanged

**Files:**
- Create: `tools/yaru-shell-source.sh`, `src/shell-theme/yaru/` (the copy), `src/shell-theme/README.md`
- Modify: `build.sh`, `.gitignore` (`extension/theme/` is built)
- Test: `tests/test_build.sh`

**Interfaces:**
- Produces: `tools/yaru-shell-source.sh DEST` copies, from tag `26.04.5.1ubuntu`: `gnome-shell/src/{gnome-shell.scss.in,gnome-shell-sass/**,*.svg,pad-osd.css}` to `DEST/`, `gnome-shell/upstream/theme/{gnome-shell-sass/**,*.svg}` to `DEST/upstream/`, `common/sass-utils.scss` (and what it imports) to `DEST/common/`, and the repo's `COPYING*` and `LICENSE_CCBYSA` to `DEST/`.
- Produces: `build.sh` writes `extension/theme/dusk-dark.css`, `extension/theme/dusk-light.css` and the images they reference (`calendar-today.svg`, `calendar-today-light.svg`, `gnome-shell-start.svg`, `workspace-placeholder.svg`) next to them; the template is filled as Yaru's meson does (`Variant` = `YaruVariant` = dark|light, `UseGResource` = false so images resolve next to the file, `Contrast` = normal, `Colors` = colors), with `url(` rewritten to `yaru_url_handler(` in a build copy (as `tools/yaru-2404-shell.sh` does for 24.04). Today's `extension/stylesheet-*.css` are still built (Task 3 drops them).

- [ ] **Step 1: Write the failing tests** in `tests/test_build.sh`:
  - `test_shell_theme_copy_matches_installed_yaru`: for dark and light, the declarations of `extension/theme/dusk-MODE.css` (`color-inventory.py`'s `declarations()`, or a small parser in the test) equal those of the installed Yaru stylesheet (`gresource extract … gnome-shell[-dark].css`), with `url()` values compared by file name only.
  - `test_shell_theme_images_present`: every `url()` in both files names a file in `extension/theme/`.
  - `test_shell_theme_covers_shell_classes`: every `style_class`/`add_style_class_name` string literal in Shell 50's own JS (`gresource list` and `extract` on `/usr/lib/gnome-shell/libshell-*.so`) that the installed Yaru stylesheet has a rule for also has one in `dusk-dark.css`. (A widget a later update adds is listed here.)
- [ ] **Step 2: Run:** `tests/run.sh shell_theme` — FAIL.
- [ ] **Step 3:** Write `tools/yaru-shell-source.sh`, run it to fill `src/shell-theme/yaru/`, write `src/shell-theme/README.md` (source repo, tag, date, licence, "edited in place, every edit marked `// dusk:`").
- [ ] **Step 4:** Add the theme build to `build.sh` (a `compile_shell_theme MODE` function next to `compile`, same atomic write).
- [ ] **Step 5: Run:** `tests/run.sh shell_theme` — PASS; full suite — PASS.
- [ ] **Step 6: Commit** (the copy alone first, then the build): `feat: Yaru 26.04 Shell source, copied unchanged` and `build: compile dusk's Shell theme from the Yaru copy`.

### Task 3: The loader: dusk's theme in Yaru's place (gate 2)

**Files:**
- Modify: `extension/extension.js`, `build.sh` (stop building `extension/stylesheet-*.css`; delete them), `install.sh`, `uninstall.sh` (link `extension/theme/` as a real folder of per-file links, like the extension folder), `tests/headless/dusk-probe@local/extension.js`, `tests/test_headless.sh`, `tests/test_extension.sh`, `tests/test_install.sh`, `tests/test_golden.sh`, `tests/test_build.sh`
- Test: as listed

**Interfaces:**
- Produces in `extension/extension.js`:
  - `_themeFile(): Gio.File` — `this.dir/theme/dusk-${Main.getStyleVariant()}.css`.
  - `_applyTheme(): void` — if the stage's `St.ThemeContext` theme already has `_themeFile()` as `default_stylesheet` and no `application_stylesheet`, return; else build `new St.Theme({default_stylesheet: this._themeFile()})`, `load_stylesheet()` each of the current theme's `get_custom_stylesheets()` (other extensions'), and `set_theme()` it.
  - On enable: `_applyTheme()`, then connect the theme context's `changed` signal to `_applyTheme()` (a re-entrancy guard: a flag set while `_applyTheme` runs). Shell's own rebuilds (`Main.loadTheme()` on dark/light, High Contrast and Shell color-scheme changes) thus get dusk's base back within the same emission, before the next frame.
  - On disable: disconnect, then `Main.loadTheme()` (Shell's own theme back, keeping extension stylesheets).
  - The header comment lists three exceptions; the loader is number 3.
- Probe additions (`dusk-probe@local`): record `theme` = `{default: <path or uri>, application: <path or null>, custom: [paths]}` at start, after switching `color-scheme` dark↔light (with the panel menu open), after `high-contrast` on and off, after a foreign `Main.setThemeStylesheet(<a test css>); Main.loadTheme()`, after disabling dusk, after enabling it again; record whether Shell logged a JS error between.

- [ ] **Step 1: Write the failing tests:**
  - `test_headless_theme_is_dusks` (dark and light): `theme.default` is `extension/theme/dusk-MODE.css`, `application` null, at start and on the lock screen.
  - `test_headless_theme_survives_switches`: after each switch (dark↔light with a menu open, High Contrast on/off, foreign loadTheme) the default is dusk's file for the current variant, the open menu's computed colors match `golden.py`'s prediction for dusk's file, no JS error logged.
  - `test_headless_theme_keeps_extension_stylesheets`: in the dock and blur probe variants, Ubuntu Dock's and Blur my Shell's stylesheets are in `custom` after every switch.
  - `test_headless_theme_disable_restores_stock`: after disabling dusk, the default is Yaru's resource stylesheet and `application` null; after enabling, dusk's again, with exactly one `changed` handler (the probe counts dusk's handler ids).
  - `test_extension_js_has_three_exceptions` replaces `test_extension_js_patches_only_the_two_exceptions` (asserts the loader's `default_stylesheet` use, the `changed` connection and `Main.loadTheme()` in `disable`).
  - `test_install` cases: the theme folder is a real folder of links; the Extensions app's Remove keeps repo files; uninstall removes it.
- [ ] **Step 2: Run** them — FAIL.
- [ ] **Step 3: Implement** the loader, the build and install changes.
- [ ] **Step 4: Retire the overlay's own tests** in this task (they test files that no longer exist): `test_shell_colors_*`, `test_no_color_rules_outside_scope`, `test_shell_keeps_yaru_special_cases`, `test_shell_chunk_*_rules_present`, `test_shell_dock_rules_present`, `test_dialogs_set_only_corners_and_colors`, `test_blur_my_shell_entries_keep_its_look`, `test_headless_blur_my_shell_search_entry_keeps_its_look`, `test_golden_static_matches_today` and `test_golden_probe_matches_today` (their replacements, `test_golden_static_matches_theme` and `test_golden_probe_matches_theme`, run the checks on `extension/theme/dusk-MODE.css` and on fresh probe runs, all slots, and are expected to fail until Task 9). Re-point the color and radius checks (`colors.py check|clobbered`, `cascade.py check`) to dusk's theme alone (origin 0).
- [ ] **Step 5: Run** the full suite. Expected PASS except the look tests that Tasks 4–9 turn green, listed in the ledger: `test_golden_*_matches_theme`, `test_headless_shell_radii_match_stylesheets` token checks, `test_headless_workspace_corners_follow_stylesheet`, `test_headless_dock_follows_tokens`, `test_headless_lock_screen_follows_tokens`, `test_headless_clock_indicator_matches_clock`, the `*_colors_follow_*` tests, `test_headless_switches_show_their_track`.
- [ ] **Step 6: Commit:** `feat: dusk's extension loads dusk's Shell theme in Yaru's place`.
- [ ] **Step 7: Gate 2.** Install, then the owner logs out and in, switches dark/light, locks the screen: the desktop looks like stock Ubuntu with Blur my Shell as today, with no flash of a different look. Stop for the owner's OK.

### Task 4: Corners in the source

**Files:**
- Modify: `src/shell-theme/yaru/gnome-shell.scss.in` (import `tokens` from `src/`, marked `// dusk:`), `src/shell-theme/yaru/upstream/gnome-shell-sass/_common.scss` (`$base_border_radius`, `$modal_radius`, `$alert_radius` and the radii derived from them), the widget files whose radii the golden shows differ, `src/shell-theme/yaru/gnome-shell-sass/{_dock.scss,_tweaks.scss}`; `src/_tokens.scss` only if a token is missing
- Test: `tests/test_golden.sh`, `tests/test_headless.sh`

**Interfaces:**
- Consumes: the radius tokens in `src/_tokens.scss` (`$r-*` scale, `$radius-*` names) and `docs/inventory-shell.md` (which Yaru selector takes which token).

- [ ] **Step 1: Write and run the failing test** `test_golden_radii_match_theme`: `golden.py check-static` and `check-probe` with `--slots radius`, dark and light; plus the radius probe tests listed in Task 3, Step 5 — FAIL.
- [ ] **Step 2:** Set each radius where Yaru defines it to its dusk token; keep Yaru's circular values (`$forced_circular_radius`) where the inventory keeps them round.
- [ ] **Step 3: Run:** radius goldens (static and probe, dark and light) and the radius probe tests — PASS.
- [ ] **Step 4: Commit:** `feat(theme): dusk's corners in the source`.

### Tasks 5, 6, 7: 24.04's colors in the source, by surface group

One task per group, in this order; each a reviewer can approve on its own:
- **Task 5:** menus, quick settings, and the controls drawn on them (buttons, switches, entries, check boxes, scroll bars, sliders).
- **Task 6:** notifications (including banners) and the date menu.
- **Task 7:** dialogs, OSDs, Alt+Tab and other switchers, tooltips, the screenshot panel.

**Files (each task):**
- Create (Task 5): `src/shell-theme/_dusk-colors.scss` — Yaru 24.04's base colors per mode (from `docs/reference/` and the 24.04 source `tools/yaru-2404-shell.sh` uses), imported right after Yaru's color files in `gnome-shell.scss.in` (marked `// dusk:`), redefining the variables Yaru's widgets read.
- Modify: the widget files for the group under `src/shell-theme/yaru/upstream/gnome-shell-sass/widgets/` (Task 5: `_popovers.scss`, `_quick-settings.scss`, `_buttons.scss`, `_switches.scss`, `_entries.scss`, `_check-box.scss`, `_scrollbars.scss`, `_slider.scss`; Task 6: `_message-list.scss`, `_notifications.scss`, `_calendar.scss`; Task 7: `_dialogs.scss`, `_osd.scss`, `_switcher-popup.scss`, `_screenshot.scss`, `_misc.scss`), `_drawing.scss` where a shared mixin differs, Yaru's `_color-overrides.scss` and `_tweaks.scss`, each change in place where the value is defined.
- Test: `tests/test_golden.sh`, `tests/test_headless.sh`

- [ ] **Step 1: Write and run the failing test** `test_golden_colors_match_theme_<group>` (`menus`, `notifications`, `dialogs`): `golden.py check-static|check-probe` with `--only` the group's selectors (the regexes of `tools/color-inventory-table.py`'s `CHUNKS` 1, 2 and 3, copied into `tests/test_golden.sh`, since that tool retires in Task 10) and `--slots bg,fg,border,shadow`, dark and light; plus the group's existing probe tests (Task 5: `test_headless_popup_colors_follow_2404`, `test_headless_inactive_menu_items_have_no_background`, `test_headless_switches_show_their_track`; Task 6: `test_headless_notification_colors_follow_2404`; Task 7: `test_headless_dialog_osd_colors_follow_2404`) re-pointed to the theme in Task 3 — FAIL.
- [ ] **Step 2:** Change the values where they're defined until the group's goldens match: base colors in `_dusk-colors.scss`; a widget's own state colors in its widget file; an `!important` Yaru added only where it blocks 24.04's states (the menu item hover), changed in place. Accent expressions stay 26.04's, with 24.04's surface inside them (decision 22).
- [ ] **Step 3: Run:** the group's goldens and tests, plus `test_headless_colors_follow_accent` and the contrast check (`colors.py contrast` on the theme) — PASS; the earlier groups' goldens still PASS.
- [ ] **Step 4: Commit:** `feat(theme): 24.04's colors in the source — <group>`.

### Task 8: The leftovers, fixed

**Files:**
- Modify: the widget files involved; `tests/golden/exceptions.tsv` (one line per changed key, naming Task 8)
- Test: `tests/test_golden.sh`, `tests/test_headless.sh`

- [ ] **Step 1: Write the failing tests** (static, on `extension/theme/dusk-MODE.css`, dark and light):
  - `test_theme_accent_not_baked`: `.button.default:hover`, `.audio-selection-device:active` (and its dialog-scoped forms), `.message-list-controls .dnd-button:focus` hold no 24.04 orange (`#e64c17`, `#c04013`, `#d34615`, `#ef8661`, `#E95420` or 24.04's accent mixes) and use `-st-accent-color`.
  - `test_theme_overview_scrollbars_are_stock`: the scroll bar handles under `.apps-scroll-view` and `.search-display` predict what installed Yaru 26.04 alone predicts.
  - `test_theme_check_boxes_from_2404_pictures`: `.check-box StIcon` off, checked, hover colors equal the fills of 24.04's `checkbox-off`, `checkbox`, `checkbox-focused` SVGs per mode (read from the 24.04 source, as the switch colors were: `docs/inventory-shell-colors-images-*.tsv` shows the method).
  - `test_theme_slider_bars_from_2404`: `-barlevel-background-color`, `-barlevel-active-background-color`, `-barlevel-overdrive-color` and `-barlevel-border-color` on `.slider` equal 24.04's values in `docs/reference/`.
  - `test_theme_renamed_elements_from_2404`: the linked dialog buttons, `.audio-selection-device` states and `.datemenu-today-button:insensitive` labels equal 24.04's values under their 24.04 selectors.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3:** Fix each in place; add the matching `exceptions.tsv` lines.
- [ ] **Step 4: Run** the five tests and all goldens — PASS.
- [ ] **Step 5: Commit:** `fix(theme): the leftovers from the colors' final review`.

### Task 9: The grouped top bar (gate 3)

**Files:**
- Modify: `src/shell-theme/yaru/upstream/gnome-shell-sass/widgets/_panel.scss` and Yaru's `_tweaks.scss` panel rules (in place); `src/_tokens.scss` (new tokens below); `tests/golden/exceptions.tsv` (the top bar keys, Task 9); `tests/headless/dusk-probe@local/extension.js` (measure every top bar button and the clock label, on the desktop, in the overview and on the lock screen)
- Test: `tests/test_headless.sh`

**Interfaces:**
- Produces tokens: `$topbar-pill-background: rgba(0, 0, 0, 0.8)`, `$topbar-pill-text: white`, `$topbar-pill-border-width: 3px` (transparent, as Blur my Shell's), `$topbar-pill-highlight: rgba(255, 255, 255, 0.03)` (its inset 1px line), `$topbar-background: transparent`; existing `$radius-topbar-item`, `$topbar-indicator-padding`.

- [ ] **Step 1: Write the failing tests** (probe, dark and light, without Blur my Shell):
  - `test_headless_topbar_is_see_through`: `#panel` background alpha 0 on the desktop.
  - `test_headless_topbar_buttons_have_pills`: every mapped `.panel-button` except the clock button has background `$topbar-pill-background`, radius `$radius-topbar-item`, also hovered (`:hover` set by hand); the clock's `.clock` label and the bell (`.messages-indicator`) carry the pill instead; the bell keeps decision 24's padding and the clock's height.
  - `test_headless_lock_screen_topbar_has_no_pills`: on the lock screen no `.panel-button` has a background.
  - `test_headless_clock_indicator_matches_clock` (exists) — PASS again.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3:** Draw the pills in `_panel.scss` (and Yaru's panel tweaks) where the top bar's button backgrounds are defined, from the tokens; the bar's own background from `$topbar-background`; nothing on the lock screen's top bar.
- [ ] **Step 4: Run** the full suite — PASS (every test listed in Task 3, Step 5 now green; `exceptions.tsv` names only Task 8 and Task 9 keys).
- [ ] **Step 5: Commit:** `feat(theme): dusk draws the grouped top bar`.
- [ ] **Step 6: Gate 3.** Install; the owner switches Blur my Shell's top bar style off and checks everything in dark and light: today's dusk look, plus the pills and the fixes. Stop for the owner's OK.

### Task 10: Retire the old machinery, update the docs

**Files:**
- Delete: `src/shell.scss`, `src/shell-dark.scss`, `src/shell-light.scss`, `src/_shell-colors.scss`, `src/_shell-color-values.scss`, the `shell-color-*` functions in `src/_lib.scss`, `tools/shell-color-inventory.sh`, `tools/color-inventory.py`, `tools/color-inventory-table.py`, `tools/color-inventory-doc.py`, `tools/mirror-colors.py`, `docs/inventory-shell-colors*`, `tests/headless/chunk-*.selectors`, and their tests (`test_color_inventory_*`, `test_shell_color_value_follows_mode`, `test_shell_colors_on_follows_switches`) — keep `docs/reference/` (the 24.04 oracle), `tools/yaru-2404-shell.sh`, the radius inventory tools the GTK side uses, `cascade.py`, `colors.py`
- Modify: `README.md` (how dusk works now; changing a corner or color in `src/_tokens.scss` or the marked place in the copy; updating; Blur my Shell no longer needed), `docs/2026-10-28-dusk-design.md` (decision 26: dusk's own Shell theme, option B; decisions 22–25 noted as now made in the source), `docs/2026-10-30-dusk-shell-theme-design.md` (status: built)

- [ ] **Step 1:** Delete and update as listed; `grep -rn` for each removed name finds nothing outside git history.
- [ ] **Step 2: Run** the full suite — PASS.
- [ ] **Step 3: Commit:** `chore: retire the Shell override layer; docs for dusk's own theme`.

### Task 11: Merge (owner)

- [ ] **Step 1:** Whole-branch review; fix Critical/Important findings test-first; ledger the rest.
- [ ] **Step 2:** Ask the owner to merge into `main`; on their OK merge, run the full suite on `main`, and ask before pushing (and pushing the `dusk-overlay-final` tag). The owner turns Blur my Shell off.
