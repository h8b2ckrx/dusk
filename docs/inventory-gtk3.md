# GTK3 radius inventory

Waiting for the owner's approval. Approve, or change a mapping, before any GTK3 rules (Task 11)
get written.

- **Source:** your GTK theme's stylesheet, found with `gresource list`:
  `/com/ubuntu/themes/Yaru-sage-dark/3.0/gtk.css` inside
  `/usr/share/themes/Yaru-sage-dark/gtk-3.0/gtk.gresource`. The theme folder's `gtk.css` only
  imports it, and its `gtk-dark.css` twin is byte-identical. The blue accent's stylesheet has
  **identical radii**, so this works whatever accent you pick.
- **Made with:** `tools/radius-inventory.py --include-zero --source-order`: **618** radius rules,
  327 rounded and 291 square.
- **Exact mapping:** [inventory-gtk3.tsv](inventory-gtk3.tsv), every rule in Yaru's order:
  selector, property, Yaru value, dusk token (`0` = stays square). Task 11 builds the GTK3 rules
  from it with the same generator as GTK4 (`tools/mirror-radius.py`).
- **Proposed** values use your scale (xs 2 · sm 3 · md 4 · lg 5 · xl 6 · xxl 8) and the no-pills
  rule. **No new tokens:** every GTK3 element maps onto a token you already have, so GTK3 apps
  match your libadwaita apps and the Shell.

## How Task 11 will apply it

The same as GTK4. `~/.config/gtk-3.0/gtk.css` loads at user priority and beats Yaru outright, so
Task 11 repeats every Yaru radius rule with the same selector, in the same order, changing only
the values. Square stays square: linked groups, maximized and tiled windows, joined edges. Yaru's
own logic for which rule wins stays intact.

## Tokens

Yaru's GTK3 uses its own steps (mostly 6, 8 and 5), so the mapping is by element, not by number.

| Token | Proposed | Yaru now | For (examples) |
|---|---|---|---|
| `button` | sm 3 | 6 | buttons, combo boxes, path bar buttons, inline-toolbar end buttons, OSD buttons |
| `icon-button` | sm 3 | 6 / pill / circle | **title bar buttons (close, minimize, maximize)**, circular buttons, tab close buttons, sidebar buttons |
| `entry` | sm 3 | 6 | entries, spin buttons (and their end buttons' outer corners) |
| `checkbox` | xs 2 | 3–5 | check boxes, selection checks in Files' grid |
| `radio` | circle | circle | radio buttons |
| `switch` | pill | 14 | switch tracks, kept as pills (owner, Task 12) |
| `round` | circle | circle | switch and slider knobs, avatars |
| `slider` | sm 3 | 3–5 | slider troughs, fill, highlight |
| `bar` | sm 3 | 1–6 | progress and level bars (thin bars stay capped at half their height) |
| `scrollbar` | sm 3 | 8 / circle | scrollbars and their sliders |
| `menu-item` | sm 3 | 6–12 | menu items, model buttons, emoji picker items |
| `popover` | lg 5 | 8–20 | popovers, menus and context menus (and their scroll arrows), popup-menu frames |
| `card` | md 4 | 8 | frames, boxed / content lists and their rows, scroll edge glows |
| `row` | sm 3 | 3–6 | selected rows and items, text selection, icon view items, calendar selection |
| `window` | lg 5 | 15–16 | window frames and title bars (see below) |
| `dialog` | xl 6 | 15–16 | message dialogs, and their flush buttons' outer bottom corners |
| `notification` | lg 5 | 5–6 | in-app notification bars, gedit's search bar, inline toolbars, Files' floating status bar |
| `osd-toolbar` | lg 5 | 5–15 | OSD toolbars and OSD windows |
| `app-tooltip` | sm 3 | 5 | tooltips |
| `swatch` | sm 3 | 4–5.5 | color swatches |
| `small` | xs 2 | 2–8 | thumbnails in Files, keycaps |

## Windows (design decision 13)

- **Window frame** (`decoration`): Yaru rounds the **top corners only** (15 15 0 0). It becomes
  5 5 0 0 with your window token. Bottom corners stay square, as you decided; Rounded Window
  Corners Reborn handles those.
- **Maximized, tiled, fullscreen and solid-CSD** frames and title bars stay square, as in Yaru.
- **Found while mapping:** for "unified" CSD windows (`window.csd.unified … > decoration`),
  Yaru itself rounds all four corners. Mirroring Yaru keeps that shape, with your window value.
  It's Yaru's choice for those windows, not a change from decision 13.
- **Title bars and header bars** follow the window token on their top corners, so they match
  the frame.

## Your Terminal and Signal close buttons

They're Yaru's GTK3 title bar buttons (`button.titlebutton`), round today. They map to
`icon-button`, so they become 3px squares, matching your other apps. Signal borrows those
buttons from GTK3, so it follows too.

## Notes

- Rules for other desktops' apps (MATE panel, Caja, Nemo, Brisk menu, Unity) are in Yaru's
  stylesheet too. They're mapped by the same rules and are harmless if you don't use those apps.
- Inventory comments start with `# `. Some selectors start with `#` (ids such as
  `#MatePanelPopupWindow`); the generator and tests handle both (found and fixed in this task).
- **"Yaru now"** is each selector's own value. Task 11 checks the real result on GTK3 widgets.
  GTK3 can report a widget's computed corner radius directly, so that check is simpler than the
  GTK4 one.
