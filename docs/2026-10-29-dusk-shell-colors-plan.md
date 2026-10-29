# Shell pop-up colors like 24.04: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every floating GNOME Shell surface, and everything drawn on it, shows Ubuntu 24.04 Yaru's exact colors, in dark and light, through dusk's tokens.

**Architecture:** Yaru 24.04's Shell stylesheets are compiled once from source and kept as reference files. A color inventory pairs each in-scope Yaru 26.04 color rule with its 24.04 value and a token; the owner approves it. A generator turns it into a mirrored Sass partial that reads `$shell-colors`. Filling tokens chunk by chunk switches surfaces over. Headless tests compare the colors Shell computes with a model of Yaru plus dusk, in both modes.

**Tech Stack:** Sass (sassc), St CSS, Python 3 test tools, the existing headless GNOME Shell probe (GJS), bash tests (`tests/run.sh`).

**Spec:** [docs/2026-10-29-dusk-shell-colors-design.md](2026-10-29-dusk-shell-colors-design.md) (decision 22), on top of [docs/2026-10-28-dusk-design.md](2026-10-28-dusk-design.md).

## Global Constraints

- 24.04 source of truth: GitHub `ubuntu/yaru`, tag `24.04.3-0ubuntu1`, `gnome-shell/src/` (plus whatever shared Sass it imports).
- Both modes: `src/shell-dark.scss` (`$mode: dark`) and `src/shell-light.scss` (`$mode: light`).
- Rule files hold no literal colors: values come from `src/_tokens.scss` (`$shell-colors`, read with `shell-color($key)`; `null` emits nothing). The lint test enforces it.
- Mirror Yaru 26.04's own selectors, in Yaru's source order, and re-assert Yaru special cases that a general rule of ours would erase.
- Mapping: element in both releases → 24.04's value for that element and state; new in 26.04 → 26.04's expression with 26.04 surface colors replaced by 24.04's; alpha tints keep 24.04's form.
- Accent: 26.04's accent expressions (`-st-accent-color`, incl. dark mode's 60%-whitened focus rings) stay; only a surface color inside one changes.
- Out of scope, no color rules: top bar, dock, overview and app grid backgrounds, what Blur my Shell styles (`.search-section-content`, `.app-folder-dialog` and their contents), the lock screen backdrop and its notifications (re-assert Yaru's), the login screen, the on-screen keyboard, other extensions' own UI, apps.
- Shell stylesheet only; no JS for colors.
- Owner gates: the inventory (Task 3), then each chunk (Tasks 5, 6, 7) installed and checked in dark and light before the next.
- Tests never run `install.sh`, `uninstall.sh`, `tools/shell-reload.sh`, `gnome-extensions` or `gsettings set` against the live session.
- Commit messages carry no attribution lines.

## Review Focus

- **Accent change:** with another accent picked, checked toggles, switches, the selected day and focus rings show that accent, not a 24.04-baked one. Test: Task 5, `test_headless_colors_follow_accent`.
- **Legibility:** text on every in-scope surface keeps a contrast of at least 4.5:1 against its computed background, in both modes. Test: Task 5, `test_headless_popup_text_contrast` (extended to its chunk's surfaces in Tasks 6 and 7).
- **Hover and pressed:** states the probe never shows must still be mirrored. Test: Task 4, `test_shell_colors_mirror_inventory`, plus `colors.py shadowed` on the stylesheets (Task 2).
- **Lock screen:** lock-screen notifications keep 26.04's translucent look even though dusk styles `.message`. Test: Task 6, `colors.py shadowed` without excluding the lock screen, and `test_no_color_rules_outside_scope`.
- **Blur my Shell:** dusk adds no color rule for its surfaces, so the search cards and folder pop-up keep its look. Test: Task 4, `test_no_color_rules_outside_scope`.

---

### Task 1: Yaru 24.04's Shell stylesheets as reference files

**Files:**
- Create: `tools/yaru-2404-shell.sh`
- Create: `docs/reference/yaru-24.04-gnome-shell-dark.css`, `docs/reference/yaru-24.04-gnome-shell-light.css`, `docs/reference/README.md`
- Test: `tests/test_reference.sh`

**Interfaces:**
- Produces: `tools/yaru-2404-shell.sh OUTDIR` writes `OUTDIR/gnome-shell-dark.css` and `OUTDIR/gnome-shell-light.css`, compiled from the tag with the default accent. The two reference files are that output, committed, so tests need no network.

- [ ] **Step 1: Write the failing test** `test_reference_2404_surfaces` in `tests/test_reference.sh`. It checks with Python that the dark file has `.popup-menu-content` background `#1d1d1d`, `.message` background `#2f2f2f`, `.osd-window` background `rgba(29, 29, 29, 0.975)`, and that the light file has `.popup-menu-content` `#FAFAFA` (any case) and `.message` white. These values were computed from the tag (design §2).
- [ ] **Step 2: Run** `tests/run.sh test_reference`. Expected: FAIL (no files).
- [ ] **Step 3: Write `tools/yaru-2404-shell.sh`.** It does a sparse, shallow `git clone` of `https://github.com/ubuntu/yaru` at the tag into a temporary folder, then fills in `gnome-shell/src/gnome-shell.scss.in` the way `gnome-shell/src/meson.build` does: `@DarkVariant@` true or false, `@YaruVariant@` `dark` or `default`, `@UseGResource@` true, `@HighContrast@` false, `@ColorableAssets@` `()`, `@Colors@` the colors file `meson.build` picks, plus the accent definitions it configures. Then it runs `sassc` for each variant. The script only reads the clone, never runs anything from it.
- [ ] **Step 4: Run it** into `docs/reference/`, renaming the outputs to the two reference names. Add `docs/reference/README.md`: where they come from (tag, command), and that they're Yaru's work (GPL-3.0 / CC-BY-SA-4.0), kept for reference.
- [ ] **Step 5: Run** `tests/run.sh test_reference`. Expected: PASS.
- [ ] **Step 6: Commit** `feat: Yaru 24.04 Shell stylesheets as reference files`.

### Task 2: Computed colors in the probe, and a color cascade model

**Files:**
- Modify: `tests/headless/dusk-probe@local/extension.js` (`snapshotStage`)
- Create: `tests/headless/colors.py`
- Create: `tests/fixtures/colors.css`
- Test: `tests/test_cascade.sh` (new `test_colors_*` functions)

**Interfaces:**
- Consumes: from `tests/headless/cascade.py`: `parse_selector`, `Rule`, `matches`, `winners`, `clobbered`, `narrows`, `st_parent`, `describe`.
- Produces:
  - Each snapshot record gains `"colors": [bg, fg, border, shadow]`. Each is `[r, g, b, a]` with 0–255 ints, read from the theme node: `get_background_color()`, `get_foreground_color()`, `get_border_color(St.Side.TOP)`, and `get_box_shadow()?.color` (or `null`).
  - `colors.SLOTS = {"background-color": 0, "color": 1, "border-color": 2, "box-shadow": 3}`. `background`, `border` and `border-top` shorthands map to slots 0 and 2 when their value holds a color; `background: none` means transparent.
  - `colors.parse_color_rules(css: str, origin: int) -> list[cascade.Rule]`: like `cascade.parse_rules`, with `corners` keyed by slot.
  - `colors.evaluate(value: str) -> tuple[int, int, int, int] | None`: hex, `rgb()`/`rgba()`, `white`/`black`/`transparent`, and St's `st-lighten`, `st-darken`, `st-mix`, `st-transparentize`, `st-opacify`, nested. Returns `None` for anything containing `-st-accent-color` (checked separately).
  - `colors.predict(records, rules) -> list[list[tuple | None]]`: per record and slot, the evaluated winner. Slot 1 (`color`) inherits from the nearest St parent when no rule sets it; the others default to transparent / none.
  - CLI `colors.py check SNAPSHOTS YARU DUSK`, `colors.py clobbered SNAPSHOTS YARU DUSK`, `colors.py shadowed YARU DUSK [EXCLUDE_REGEX]`. Same output and exit codes as `cascade.py`'s commands; `check` allows ±2 per channel.

- [ ] **Step 1: Write failing tests** in `tests/test_cascade.sh`, on `tests/fixtures/colors.css`:
  - `test_colors_evaluate_st_functions`: `evaluate("st-lighten(#36363a, 7%)")` equals what `sassc` gives for `lighten(#36363a, 7%)`; likewise for `st-darken`, `st-mix(white, #36363a, 9%)` (Sass `mix`) and `st-transparentize(#f2f2f2, 0.9)` (Sass `transparentize`). The live calibration against what St computes is Step 4's check, on stock Yaru rules that use these functions.
  - `evaluate("rgba(29, 29, 29, 0.975)") == (29, 29, 29, 249)`, and `evaluate("st-mix(-st-accent-color, #1d1d1d, 5%)") is None`.
  - `test_colors_foreground_inherits`: a fixture where the parent sets `color` and the child doesn't; the child's prediction is the parent's.
  - `test_colors_clobbered_finds_erased_special_case`: a general dusk rule erasing a more specific Yaru one.
- [ ] **Step 2: Run** `tests/run.sh test_colors`. Expected: FAIL (`colors.py` missing).
- [ ] **Step 3: Implement `colors.py`** and the probe's `colors` field. St's functions behave like Sass's: lighten and darken in HSL lightness, mix as a weighted RGB(A) average, transparentize subtracting alpha. Calibrate against the stock value from Step 1.
- [ ] **Step 4: Add `test_headless_shell_colors_match_stylesheets`** to `tests/test_headless.sh`: `colors.py check` and `colors.py clobbered` on the dark and light probe runs (`probe_dir dark`, `probe_dir light`) against the installed Yaru stylesheet (`yaru_dark_css`, and a new `yaru_light_css`) and ours. It must pass now: dusk sets no pop-up colors yet, apart from the dialog colors it already has.
- [ ] **Step 5: Run** `tests/run.sh test_colors` and `tests/run.sh shell_colors_match`. Expected: PASS.
- [ ] **Step 6: Commit** `test: computed colors in the probe, and a color cascade model`.

### Task 3: The color inventory (owner gate)

**Files:**
- Create: `tools/color-inventory.py`
- Create: `docs/inventory-shell-colors.md`, `docs/inventory-shell-colors.tsv`
- Test: `tests/test_inventory.sh` (`test_color_inventory_*`)

**Interfaces:**
- Consumes: `docs/reference/yaru-24.04-gnome-shell-{dark,light}.css` (Task 1), `colors.SLOTS` (Task 2).
- Produces:
  - `tools/color-inventory.py STOCK.css OLD.css --scope SCOPE_REGEX [--exclude REGEX] [--palette PALETTE.tsv]` prints, in STOCK's source order, one line per in-scope selector and color property: `selector<TAB>property<TAB>26.04 value<TAB>24.04 value<TAB>source`. `source` is `same` (same selector and property in OLD), `derived` (26.04's expression with each 26.04 color found in PALETTE's first column replaced by its second), or `accent` (holds `-st-accent-color`: 26.04's expression, palette-substituted).
  - `docs/inventory-shell-colors.tsv` columns: `mode` (`dark`, `light` or `both`), `selector`, `property`, `26.04 value`, `24.04 value`, `source`, `token`, `chunk` (1, 2 or 3). Comment lines start with `# `. Values containing tokens are templates, e.g. `st-mix(-st-accent-color, {card-bg}, 5%)`.
  - Token names follow `<surface>-<part>[-<state>]`, e.g. `menu-bg`, `menu-item-hover-bg`, `card-bg`, `notification-bg`, `popup-fg`, `osd-bg`, `dialog-bg`. The inventory fixes the final list.
  - The TSV's first comment lines record the exact `tools/color-inventory.py` commands (scope, exclude and palette) for each mode, so the drift test (Task 4) can re-run them.

- [ ] **Step 1: Write failing tests** `test_color_inventory_lists_scope` and `test_color_inventory_derives`: on two small fixture stylesheets, the tool lists only in-scope selectors in source order. A selector present in both gets `same` with the old value. One only in the new file gets `derived` with the palette substitution applied. An accent expression gets `accent`.
- [ ] **Step 2: Run** `tests/run.sh test_color_inventory`. Expected: FAIL.
- [ ] **Step 3: Implement `tools/color-inventory.py`.** It reuses `colors.parse_color_rules` for parsing, and keeps the last declaration per selector and property, as `tools/radius-inventory.py` does.
- [ ] **Step 4: Run it** on the installed Yaru 26.04 dark and light stylesheets against the two reference files. Scope: the design's §4 surfaces. Exclude: the out-of-scope list in Global Constraints. The palette starts with the design §2 pairs (`#36363a`→`#1d1d1d`, `#47474c`→`#2f2f2f`, `#54545a`→`#2f2f2f` in dark; their light pairs). Extend it as rows show new 26.04 colors.
- [ ] **Step 5: Write `docs/inventory-shell-colors.tsv`.** Merge the dark and light outputs into one table (`mode`: `both` when the selector and property appear in both). Give each row its token and chunk: 1 is menus and quick settings, 2 is notifications and the date menu, 3 is dialogs, OSDs, switchers, tooltips and the screenshot panel. Each surface gets its own tokens, so filling one chunk's tokens changes nothing else. A palette map in the tokens can still share values between them (Task 4).
- [ ] **Step 6: Write `docs/inventory-shell-colors.md`** for the owner, like the radius inventories. It has a table per surface (element, state, 26.04, 24.04, token), every `derived` row marked for review, the token list with dark and light values, and what was left out and why.
- [ ] **Step 7: Run** `tests/run.sh test_color_inventory`. Expected: PASS.
- [ ] **Step 8: Commit** `docs: Shell color inventory for owner review`. **Owner gate: the owner approves the inventory (or changes rows) before Task 4.**

### Task 4: Tokens, generator and mirror (no colors switched on yet)

**Files:**
- Create: `tools/mirror-colors.py`, `src/_shell-colors.scss` (generated)
- Modify: `src/_tokens.scss` (`$yaru-2404` palette, `$shell-colors` keys), `src/shell.scss` (import the partial)
- Test: `tests/test_build.sh` (`test_shell_colors_*`, `test_no_color_rules_outside_scope`), `tests/test_inventory.sh` (`test_color_inventory_matches_installed_yaru`)

**Interfaces:**
- Consumes: `docs/inventory-shell-colors.tsv` (Task 3).
- Produces:
  - `tools/mirror-colors.py TSV` prints `src/_shell-colors.scss`: rules in the TSV's order. Each declaration is `property: shell-color(token)`, or the template with each `{token}` as `#{shell-color(token)}`. It's wrapped in `@if shell-color(token) { … }` for every token it uses, so a `null` token emits nothing, and in `@if $mode == dark/light` for single-mode rows.
  - `$yaru-2404: (dark: (…), light: (…))` in `src/_tokens.scss`: 24.04's named colors per mode. `$shell-colors` gets every inventory token, set to `null` in this task. The old unused keys (`notification-bg`, `quick-settings-bg`, …) are replaced by the inventory's.

- [ ] **Step 1: Write failing tests:**
  - `test_shell_colors_generated_up_to_date`: generator output equals `src/_shell-colors.scss`.
  - `test_shell_colors_mirror_inventory`: with every token temporarily set, built from a copy of `src/` (as `test_gtk3_titlebutton_token_switches_tint` does), each TSV row appears in the right mode's built stylesheet, in order, with its 24.04 value.
  - `test_no_color_rules_outside_scope`: the built stylesheets have no color declaration on `#panel`, `#dash`, `.search-section-content`, `.app-folder-dialog`, `.unlock-dialog` notifications, `.login-dialog`, `.keyboard` selectors.
  - `test_color_inventory_matches_installed_yaru`: the TSV's selector, property and 26.04 value columns still match the installed Yaru 26.04 stylesheets, using `tools/color-inventory.py` with the scope recorded in the TSV header, the same way `assert_inventory_current` does for radii.
- [ ] **Step 2: Run** `tests/run.sh shell_colors` and `tests/run.sh color_inventory_matches`. Expected: FAIL.
- [ ] **Step 3: Implement** the generator and token keys, generate the partial, and import it in `src/shell.scss` after the existing rules.
- [ ] **Step 4: Run** the full suite, `tests/run.sh`. Expected: all pass. Built stylesheets are unchanged apart from comments, because every new token is `null`.
- [ ] **Step 5: Commit** `feat: Shell color tokens and mirror, all unset`.

### Task 5: Chunk 1, menus and quick settings (owner gate)

**Files:**
- Modify: `src/_tokens.scss` (chunk 1 tokens, dark and light)
- Test: `tests/test_headless.sh` (`test_headless_popup_colors_follow_2404`, `test_headless_popup_text_contrast`, `test_headless_colors_follow_accent`), `tests/headless/dusk-probe@local/extension.js` if a state is missing

**Interfaces:**
- Consumes: the chunk 1 rows and tokens (Tasks 3 and 4); `colors.py` and the probe's `colors` (Task 2).
- Produces: `expected_colors(mode, chunk) -> {(selector, slot): rgba}` in `tests/headless/colors.py`: the TSV's `24.04 value` column, evaluated, for that mode and chunk; `accent` rows are left out. Tasks 6 and 7 reuse it.

- [ ] **Step 1: Write failing tests:**
  - `test_headless_popup_colors_follow_2404`: in the dark and light probe runs, every element whose winning rule for a slot (`cascade.winners` over Yaru plus dusk color rules) is a chunk 1 row shows that row's `expected_colors` value. The probe must also show `.popup-menu-content`, `.popup-menu-item`, `.quick-settings` and `.quick-toggle-menu` (`cascade.py unmatched`).
  - `test_headless_popup_text_contrast`: for those elements, the contrast between foreground and background (composited over the element's nearest opaque ancestor) is at least 4.5.
  - `test_headless_colors_follow_accent`: a probe run with `DUSK_GSETTINGS="org.gnome.desktop.interface accent-color blue"` shows a checked quick toggle's background different from the default (slate) run's, for the same element.
- [ ] **Step 2: Run** `tests/run.sh popup_colors`. Expected: FAIL (tokens unset).
- [ ] **Step 3: Fill the chunk 1 tokens** in `$shell-colors` for both modes, from `$yaru-2404`.
- [ ] **Step 4: Run** the full suite. Expected: all pass, including `test_headless_shell_colors_match_stylesheets` and `clobbered`. Re-assert any Yaru special case `clobbered` reports.
- [ ] **Step 5: Install and reload** on the live desktop (`./install.sh && tools/shell-reload.sh`), outside the tests.
- [ ] **Step 6: Commit and push** `feat: menus and quick settings in 24.04 colors (chunk 1)`. **Owner gate: the owner checks the menus and quick settings in dark and light before Task 6.**

### Task 6: Chunk 2, notifications and the date menu (owner gate)

**Files:**
- Modify: `src/_tokens.scss` (chunk 2 tokens), `src/shell.scss` (re-asserted lock-screen notification rules, if `shadowed` reports them)
- Test: the Task 5 headless tests extended to chunk 2; `tests/test_build.sh` (`colors.py shadowed` without a lock-screen exclusion)

**Interfaces:**
- Consumes: `expected_colors(mode, chunk)` (Task 5).

- [ ] **Step 1: Extend the tests** to chunk 2: the probe's `notification`, `date-menu` and `lock-screen` states. Add a build test: `colors.py shadowed` on Yaru 26.04 and our stylesheet reports nothing, including `.unlock-dialog-notifications-container …` rules.
- [ ] **Step 2: Run** `tests/run.sh popup_colors`. Expected: FAIL.
- [ ] **Step 3: Fill the chunk 2 tokens.** Re-assert Yaru's lock-screen notification color rules in `src/shell.scss` (values from new tokens holding 26.04's own lock-screen values) where `shadowed` reports them.
- [ ] **Step 4: Run** the full suite. Expected: all pass.
- [ ] **Step 5: Install, reload, commit and push** `feat: notifications and the date menu in 24.04 colors (chunk 2)`. **Owner gate.**

### Task 7: Chunk 3, dialogs, OSDs, switchers, tooltips, screenshot panel (owner gate)

**Files:**
- Modify: `src/_tokens.scss` (chunk 3 tokens; the existing `dialog-*` tokens stay)
- Modify: `tests/headless/dusk-probe@local/extension.js`: add an Alt+Tab switcher state if none exists (`Main.wm._startSwitcher` is private; use `new SwitcherPopup.*` or `AltTab.AppSwitcherPopup`, shown and destroyed by hand)
- Test: the Task 5 headless tests extended to chunk 3

- [ ] **Step 1: Extend the tests** to chunk 3: the probe's dialog, `osd`, `screenshot-ui` and switcher states, and a dash label tooltip if the probe shows one.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Fill the chunk 3 tokens.**
- [ ] **Step 4: Run** the full suite. Expected: all pass, including the existing dialog tests (`test_headless_*_dialog_buttons_flush`).
- [ ] **Step 5: Install, reload, commit and push** `feat: dialogs, OSDs and switchers in 24.04 colors (chunk 3)`. **Owner gate.**

### Task 8: Docs

**Files:**
- Modify: `README.md` ("How it works", "Changing a value": colors; "Updating after …": the color inventory and reference files), `docs/2026-10-28-dusk-design.md` (§7.2 now points to decision 22), `docs/inventory-shell-colors.md` (status: built)

- [ ] **Step 1: Update the docs.** Run `tests/run.sh test_lint` and the full suite. Expected: PASS.
- [ ] **Step 2: Commit and push** `docs: Shell colors`.
