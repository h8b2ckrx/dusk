# dusk

A small personal GNOME theme for Ubuntu 26.04 (GNOME Shell 50, Wayland). dusk is its own complete
Shell theme, and it controls corner radius everywhere: GNOME Shell, libadwaita (GTK4) apps and GTK3
apps. Shell dialogs keep 26.04's own layout, Shell's pop-ups take Ubuntu 24.04's colors, and the top
bar is see-through with a pill behind each button. GTK apps otherwise stay stock Yaru.

One file, [src/_tokens.scss](src/_tokens.scss), holds every corner and the top bar's values. Change a
token, run `./install.sh`, and the Shell and every GTK app follow.

- Design: [docs/2026-10-28-dusk-design.md](docs/2026-10-28-dusk-design.md), and for the Shell theme
  [docs/2026-10-30-dusk-shell-theme-design.md](docs/2026-10-30-dusk-shell-theme-design.md)
- Plan: [docs/2026-10-28-dusk-plan.md](docs/2026-10-28-dusk-plan.md)
- Inventories: [Shell](docs/inventory-shell.md) · [GTK4](docs/inventory-gtk4.md) · [GTK3](docs/inventory-gtk3.md)

## How it works

| Layer | Hook | dusk's file |
|---|---|---|
| GNOME Shell (and the lock screen) | the `dusk@local` extension puts dusk's theme in Shell's base slot, in Yaru's place | `extension/theme/dusk-dark.css` / `-light.css` |
| GTK4 / libadwaita apps | `~/.config/gtk-4.0/gtk.css` | `build/gtk4.css` |
| GTK3 apps | `~/.config/gtk-3.0/gtk.css` | `build/gtk3.css` |

**Shell:** dusk's theme is built from a copy of Yaru 26.04's Sass source, in
[src/shell-theme/](src/shell-theme/README.md), and it replaces Yaru: Yaru isn't loaded, so nothing
overrides anything and no Yaru update can change the look. Every change dusk makes is in the copy,
where the value is defined, marked `// dusk:`. Ubuntu's session names Yaru as Shell's base theme, so
the extension swaps dusk's in as it starts, and again whenever Shell rebuilds its theme (dark/light,
High Contrast). It doesn't need the User Themes extension, and other extensions' stylesheets keep
working on top.

**GTK4 and GTK3:** a user `gtk.css` beats the GTK theme outright, whatever the selectors'
specificity, so a general rule of dusk's would also erase the theme's deliberate special cases, like
square inner corners in linked button groups. dusk therefore mirrors **every** stock radius rule, in
the stock order, with values from tokens, square ones included. These rules are generated from the
inventories.

**Three small code exceptions** live in [extension/extension.js](extension/extension.js). They're
the only things CSS can't do in Shell 50:

1. the overview's workspace corners (Shell clips them at 30px in code);
2. the app icon size in the app grid and in search results (Shell picks 64px in code; dusk uses
   `$app-grid-icon-size`, 96px);
3. loading dusk's theme in Yaru's place.

Each just makes Shell honour the theme's value, and `disable()` gives Shell its own values back.

## Files

| Path | What it does |
|---|---|
| `src/_tokens.scss` | the radius scale, every element radius, spacing, the top bar's values and app colors (null = stock) |
| `src/_lib.scss` | `token()` lookup (a typo stops the build), `color-vars()` |
| `src/shell-theme/` | dusk's Shell theme: the copy of Yaru's source, with dusk's edits marked `// dusk:` ([README](src/shell-theme/README.md)) |
| `src/gtk4.scss`, `src/gtk3.scss` | app layers: `--window-radius`, color hooks, GTK3 title bar buttons |
| `src/_gtk4-radius.scss`, `src/_gtk3-radius.scss` | **generated** mirrors of the stock radius rules; don't edit by hand |
| `build.sh` | compiles `src/` into `build/gtk4.css`, `build/gtk3.css` and the extension's `theme/` folder |
| `install.sh`, `uninstall.sh` | link / unlink the outputs, with backups and a state file |
| `extension/` | the `dusk@local` extension: metadata, `extension.js` (the three exceptions), the compiled theme |
| `docs/inventory-*.md` / `.tsv` | the approved radius tables; the GTK `.tsv` files map every stock rule to a token |
| `tools/radius-inventory.py` | lists the radius of every selector in a stock stylesheet |
| `tools/mirror-radius.py` | turns an inventory `.tsv` into the generated `src/_*-radius.scss` |
| `tools/build-shell-theme.sh` | compiles the copy into a Shell stylesheet, the way Yaru's own build does |
| `tools/yaru-shell-source.sh` | fetches Yaru's Shell source, for a new copy |
| `tools/shell-reload.sh` | reloads the Shell theme, checks Shell's log and that dusk is ACTIVE |
| `tools/yaru-2404-shell.sh`, `docs/reference/` | Yaru 24.04's Shell stylesheets, compiled from source, that the colors follow |
| `tests/golden/` | the recorded Shell look the theme has to reproduce, and the deliberate changes from it (`exceptions.tsv`) |
| `tools/check_gtk_css.py` | loads a CSS file in GTK 3 or 4 and fails on parse errors |
| `tools/headless-probe.sh` | throwaway headless Shell (isolated from your desktop) that measures and screenshots the Shell |
| `tools/headless-gtk.sh` | the same for real GTK4 widgets (libadwaita, and plain GTK4) |
| `tools/probe-gtk3.sh` | real GTK3 widgets with their own config folder, on your display but never shown |
| `tests/` | `tests/run.sh` runs everything; `tests/run.sh <name>` runs a subset. The headless runs take a few minutes and are cached in `/tmp` until `src/` or the tests change |

## Install

On a fresh Ubuntu 26.04, get the two tools it needs, then the repo (any folder works; the links
point wherever you clone it):

```bash
sudo apt install git sassc
```

```bash
git clone https://github.com/h8b2ckrx/dusk.git ~/dusk
```

Then install:

```bash
cd ~/dusk && ./install.sh
```

The **first time,** log out and back in once: Shell only discovers a new extension at login.
Then run `./install.sh` again to enable it. Reopen your apps, and for rounded bottom window
corners install **Rounded Window Corners Reborn** (see below).

## Changing a value

1. Edit a token in [src/_tokens.scss](src/_tokens.scss), e.g. a scale step (`$r-sm`) or one
   element (`$radius-popover: $r-lg;`).
2. Run:

   ```bash
   cd ~/dusk && ./install.sh && tools/shell-reload.sh
   ```

   It should end with `clean`.
3. **Shell** changes show at once. **Apps** read `gtk.css` when they start, so reopen them.
   Title bars of X11 apps (e.g. VLC) come from a Mutter helper that starts at login, and a
   change to `extension/extension.js` needs one too: log out and back in.

**Shell colors** aren't tokens: they live where the theme defines them, in
[src/shell-theme/yaru/](src/shell-theme/yaru). The pop-ups' colors are Yaru 24.04's (decision 22), in
`upstream/gnome-shell-sass/_colors.scss` and the widget files; the `$yaru_*` colors there are 26.04's
own, for what stays as stock (the lock screen, the on-screen keyboard, the dock). Search for
`// dusk:` to see every change. The top bar's pills are tokens (`$topbar-pill-*`, one set per mode).

Check that dusk is running at any time:

```bash
gnome-extensions info dusk@local
```

It should show `State: ACTIVE`.

## Adding a customization

1. Find the element's selector (below).
2. Add a token to `src/_tokens.scss`.
3. Add a rule with a `//` comment saying what it targets:
   - **Shell:** edit the rule where it's defined in `src/shell-theme/yaru/`, and mark the line
     `// dusk:`.
   - **Apps:** change the token column for that row in `docs/inventory-gtk4.tsv` or
     `docs/inventory-gtk3.tsv`, then regenerate:

     ```bash
     tools/mirror-radius.py docs/inventory-gtk4.tsv > src/_gtk4-radius.scss
     ```

     (Likewise for `gtk3`.)
   - **An app's own selector** (one no stock rule has): add it by hand at the end of
     `src/gtk4.scss` or `src/gtk3.scss`, after the generated import, with a `//` comment naming
     the app.
4. Run `tests/run.sh`.

The GTK rule files may only contain tokens (and `0`): the lint test enforces it.

## Finding selectors

- **Shell:** Alt+F2 → `lg` → the picker (top-left of Looking Glass), then click the element.
  Or let `tools/headless-probe.sh` record every element's classes and radii in a throwaway Shell.
- **GTK apps:** `GTK_DEBUG=interactive <app>` opens the GTK Inspector; its CSS Nodes tab shows
  each widget's node names and classes.

## Uninstall

```bash
cd ~/dusk && ./uninstall.sh
```

It disables the extension (and takes it out of Shell's extension lists), removes only dusk's links,
restores anything it backed up, and removes folders it created. If a step fails, the rest still
runs and it tells you; run it again once that's fixed. Log out and back in (or reopen apps) to see
stock Ubuntu. `./install.sh` brings dusk back.

Use `./uninstall.sh` rather than **Remove** in the Extensions app. Remove only deletes the Shell
part (the links in `dusk@local`, never the repo's files) and leaves the GTK links in place.

## Moving the repo

The links point into the repo, so after moving it, run `./install.sh` from the new place. It
recognises its own old links and replaces them.

## Updating after a GNOME, Yaru or libadwaita update

Most updates change nothing, and a Yaru update never changes the Shell: dusk's theme doesn't read
the installed Yaru. After an Ubuntu upgrade (e.g. 26.10):

1. Run `tests/run.sh`. The `inventory_matches_installed` tests list every GTK rule that changed
   in the installed stylesheets, and the live checks show what moved in Shell and apps.
2. **Shell:** for a new GNOME version, add it to `shell-version` in `extension/metadata.json`, take
   a new copy of Yaru's source with `tools/yaru-shell-source.sh`, and bring dusk's marked edits over
   (`git log -p src/shell-theme/yaru` shows every one). Run the theme checks: `tests/golden/` shows
   what moved.
3. **GTK4:** find the stylesheet with `gresource list /usr/lib/x86_64-linux-gnu/libadwaita-1.so.0`
   and extract `/org/gnome/Adwaita/styles/default-dark-yaru-<accent>.css`. Run
   `tools/radius-inventory.py` on it with the options listed at the top of
   `docs/inventory-gtk4.md`, and compare the result with the first three columns of
   `docs/inventory-gtk4.tsv`. Keep the tokens of unchanged rows, give new rows a token, then
   regenerate `src/_gtk4-radius.scss`.
4. **GTK3:** the same, with `gresource list /usr/share/themes/<your theme>/gtk-3.0/gtk.gresource`,
   `docs/inventory-gtk3.md` and `docs/inventory-gtk3.tsv`.
5. Run `tests/run.sh` again, then `./install.sh && tools/shell-reload.sh`.

## Bottom window corners

GTK3 windows are rounded on top only (Yaru's choice, kept). For rounded bottom corners on every
window, and corners on apps that aren't GTK at all, install the **Rounded Window Corners Reborn**
extension.

## Known limits

- **Not GTK, so not themed:** Electron/Chromium apps (Claude, VS Code, Signal, browsers) style
  their own contents. Qt apps (VLC) and Flutter apps (LocalSend) draw their own UI.
- **Window buttons are round everywhere** (`$radius-titlebutton`), because some apps draw their
  own. Claude hides the system title bar, and Chromium draws its round buttons in code, out of
  any theme's reach. Signal borrows its buttons from GTK3, so those follow. X11 apps (VLC) get
  their title bar from Mutter's helper, a plain GTK4 program. Set the token to a scale step to
  square them all again (except Claude's).
- **Snap apps** keep their own config folders and aren't covered. Flatpak apps are, if Flatpak is
  installed (`install.sh` adds the overrides).
- **The volume and brightness slider tracks** have round ends drawn in Shell's code (`barLevel.js`).
  Left as they are.
- **Ubuntu Dock's right-click menus** follow the menu token (they share Shell's menu style).
- **The login screen** (after power-on or logging out) stays stock Yaru. It's a separate Shell
  run by the system before anyone logs in, and it never loads dusk. The lock screen does
  follow dusk.
- **High Contrast** doesn't get a theme of its own: dusk's normal theme stays on.
- **Blur:** dusk adds none. Blur my Shell isn't needed for the top bar any more, and turning its
  top bar style on draws its own pills over dusk's.
- **Colored tray icons:** an app's own picture in the top bar (Telegram's, Claude's) keeps its
  colors, so a white one has little contrast on a light-mode pill. The theme can't recolor it.
- **Screen recording and sharing indicators** keep their red and orange, not a pill.
- **Switch tracks** stay pills, by choice; every other pill is squared.
- **Plain GTK4 apps** (GTK4 without libadwaita, like Mutter's title bars for X11 apps) use
  Yaru's separate `gtk-4.0` stylesheet. dusk's GTK4 rules are mirrored from libadwaita's, which
  match the same widgets in most cases, but only the window buttons are measured there.
- **GTK3 color overrides are deferred:** GTK3 CSS can't tell light from dark mode. Radius works
  in both.
- **App-specific widgets:** an app that styles its own widgets with its own CSS classes can keep
  some rounding. Find the selector (above) and add a rule.
- **Mixed corners in apps with their own CSS:** `gtk.css` also beats an app's own stylesheet on
  standard widgets. So an app's custom container can keep its own radius while the buttons inside
  it take dusk's (e.g. Files' path bar: 9px around 3px buttons). Add a rule for the container.
- **Flatpak installed later:** run `./install.sh` again so Flatpak apps can read dusk's files.
