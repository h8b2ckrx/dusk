# dusk

A small personal override layer for Ubuntu 26.04 (GNOME Shell 50, Wayland). It controls corner
radius everywhere: GNOME Shell, libadwaita (GTK4) apps and GTK3 apps. It also restores the Ubuntu
24.04-style Shell dialogs and leaves room for color tweaks. Everything else stays stock Yaru.

One file, [src/_tokens.scss](src/_tokens.scss), holds every value. Change a token, run
`./install.sh`, and the Shell and every GTK app follow.

- Design: [docs/2026-10-28-dusk-design.md](docs/2026-10-28-dusk-design.md)
- Plan: [docs/2026-10-28-dusk-plan.md](docs/2026-10-28-dusk-plan.md)
- Inventories: [Shell](docs/inventory-shell.md) · [GTK4](docs/inventory-gtk4.md) · [GTK3](docs/inventory-gtk3.md)

## How it works

| Layer | Hook | dusk's file |
|---|---|---|
| GNOME Shell | the `dusk@local` extension's stylesheet, loaded by Shell | `extension/stylesheet-dark.css` / `-light.css` |
| GTK4 / libadwaita apps | `~/.config/gtk-4.0/gtk.css` | `build/gtk4.css` |
| GTK3 apps | `~/.config/gtk-3.0/gtk.css` | `build/gtk3.css` |

All three beat the stock theme outright: an extension stylesheet beats Shell's theme, and a user
`gtk.css` beats the GTK theme, whatever the selectors' specificity. So a general rule of dusk's
would also erase the theme's deliberate special cases, like square inner corners in linked button
groups. dusk therefore:

- **Shell:** repeats Yaru's own selectors, and re-asserts Yaru's special cases next to any rule
  that would erase them.
- **GTK4 and GTK3:** mirrors **every** stock radius rule, in the stock order, with values from
  tokens, square ones included. These rules are generated from the inventories.

**Two small code exceptions** live in [extension/extension.js](extension/extension.js). They're
the only things CSS can't do in Shell 50:

1. the gap between dialog buttons (Shell sets 12px in code);
2. the overview's workspace corners (Shell clips them at 30px in code).

Both just make Shell honour the stylesheet's value, and `disable()` gives Shell its own values back.

## Files

| Path | What it does |
|---|---|
| `src/_tokens.scss` | the radius scale, every element radius, spacing and colors (null = stock) |
| `src/_lib.scss` | `token()` lookup (a typo stops the build), `color-vars()` |
| `src/shell.scss` | Shell rules; `shell-dark.scss` / `shell-light.scss` compile it per style |
| `src/gtk4.scss`, `src/gtk3.scss` | app layers: `--window-radius`, color hooks, GTK3 title bar buttons |
| `src/_gtk4-radius.scss`, `src/_gtk3-radius.scss` | **generated** mirrors of the stock radius rules; don't edit by hand |
| `build.sh` | compiles `src/` into `build/gtk4.css`, `build/gtk3.css` and the extension's stylesheets |
| `install.sh`, `uninstall.sh` | link / unlink the outputs, with backups and a state file |
| `extension/` | the `dusk@local` extension: metadata, `extension.js` (the two exceptions), compiled stylesheets |
| `docs/inventory-*.md` / `.tsv` | the approved radius tables; the `.tsv` files map every stock rule to a token |
| `tools/radius-inventory.py` | lists the radius of every selector in a stock stylesheet |
| `tools/mirror-radius.py` | turns an inventory `.tsv` into the generated `src/_*-radius.scss` |
| `tools/shell-reload.sh` | reloads the Shell stylesheet, checks Shell's log and that dusk is ACTIVE |
| `tools/check_gtk_css.py` | loads a CSS file in GTK 3 or 4 and fails on parse errors |
| `tools/headless-probe.sh` | throwaway headless Shell (isolated from your desktop) that measures and screenshots the Shell |
| `tools/headless-gtk.sh`, `tools/probe-gtk3.sh` | the same for real GTK4 / GTK3 widgets |
| `tests/` | `tests/run.sh` runs everything; `tests/run.sh <name>` runs a subset. The headless runs take a few minutes and are cached in `/tmp` until `src/` or the tests change |

## Install

```bash
cd ~/dusk && ./install.sh
```

The **first time,** log out and back in once: Shell only discovers a new extension at login.
Then run `./install.sh` again to enable it.

## Changing a value

1. Edit a token in [src/_tokens.scss](src/_tokens.scss), e.g. a scale step (`$r-sm`) or one
   element (`$radius-popover: $r-lg;`).
2. Run:

   ```bash
   cd ~/dusk && ./install.sh && tools/shell-reload.sh
   ```

   It should end with `clean`.
3. **Shell** changes show at once. **Apps** read `gtk.css` when they start, so reopen them.
   A change to `extension/extension.js` needs a log-out.

Check that dusk is running at any time:

```bash
gnome-extensions info dusk@local
```

It should show `State: ACTIVE`.

## Adding a customization

1. Find the element's selector (below).
2. Add a token to `src/_tokens.scss`.
3. Add a rule with a `//` comment saying what it targets:
   - **Shell:** in `src/shell.scss`, using Yaru's exact selector. Run `tests/run.sh keeps_yaru` to
     catch any Yaru special case your rule would erase.
   - **Apps:** change the token column for that row in `docs/inventory-gtk4.tsv` or
     `docs/inventory-gtk3.tsv`, then regenerate:

     ```bash
     tools/mirror-radius.py docs/inventory-gtk4.tsv > src/_gtk4-radius.scss
     ```

     (Likewise for `gtk3`.)
4. Run `tests/run.sh`.

Rule files may only contain tokens (and `0`): the lint test enforces it.

## Finding selectors

- **Shell:** Alt+F2 → `lg` → the picker (top-left of Looking Glass), then click the element.
  Or let `tools/headless-probe.sh` record every element's classes and radii in a throwaway Shell.
- **GTK apps:** `GTK_DEBUG=interactive <app>` opens the GTK Inspector; its CSS Nodes tab shows
  each widget's node names and classes.

## Uninstall

```bash
cd ~/dusk && ./uninstall.sh
```

It disables the extension, removes only dusk's links, restores anything it backed up, and removes
folders it created. Log out and back in (or reopen apps) to see stock Ubuntu. `./install.sh` brings
dusk back.

## Moving the repo

The links point into the repo, so after moving it, run `./install.sh` from the new place. It
recognises its own old links and replaces them.

## Updating after a GNOME, Yaru or libadwaita update

Most updates change nothing. After an Ubuntu upgrade (e.g. 26.10):

1. Run `tests/run.sh`. The live checks show what moved.
2. **Shell:** for a new GNOME version, add it to `shell-version` in `extension/metadata.json`.
   Re-run the inventory on the new Yaru stylesheet and compare it with `docs/inventory-shell.md`:

   ```bash
   gresource extract /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource /org/gnome/shell/theme/Yaru/gnome-shell-dark.css > /tmp/yaru-shell.css
   tools/radius-inventory.py /tmp/yaru-shell.css
   ```

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
  their own contents. Signal borrows its window buttons from GTK3, so those follow. Qt apps (VLC)
  and Flutter apps (LocalSend) draw their own UI.
- **Snap apps** keep their own config folders and aren't covered. Flatpak apps are, if Flatpak is
  installed (`install.sh` adds the overrides).
- **The volume and brightness slider tracks** have round ends drawn in Shell's code (`barLevel.js`).
  Left as they are.
- **Ubuntu Dock's right-click menus** follow the menu token (they share Shell's menu style).
- **Switch tracks** stay pills, by choice; every other pill is squared.
- **GTK3 color overrides are deferred:** GTK3 CSS can't tell light from dark mode. Radius works
  in both.
- **App-specific widgets:** an app that styles its own widgets with its own CSS classes can keep
  some rounding. Find the selector (above) and add a rule.
