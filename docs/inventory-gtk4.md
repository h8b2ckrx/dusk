# GTK4 / libadwaita radius inventory

**Approved by the owner (Task 8),** with one rule added during review: **no pills.**
Everything that was a pill becomes a scale step. Only truly round things stay round: avatars,
dots, badges, round icons, and switch and slider knobs. Radio buttons stay round too, so they
don't look like check boxes.

- **Source:** libadwaita 1.9.1's Yaru stylesheet for your accent, found with `gresource list`:
  `/org/gnome/Adwaita/styles/default-dark-yaru-sage.css` inside
  `/usr/lib/x86_64-linux-gnu/libadwaita-1.so.0` (`main-dark-yaru-sage.css` only imports it).
  The blue accent's stylesheet has **identical radii**, so this works whatever accent you pick.
- **Made with:** `tools/radius-inventory.py --include-zero --source-order`. It found 425 radius
  rules: 238 rounded, 187 square. The 3 rules for libadwaita's adaptive-preview developer tool
  are left out, and so are high-contrast rules (inside `@media`).
- **Exact mapping:** [inventory-gtk4.tsv](inventory-gtk4.tsv) has every rule in libadwaita's
  order: selector, property, libadwaita value, dusk token (`0` = stays square). Task 9 builds
  `src/gtk4.scss` from it, and its tests check against it.
- **Proposed** values use the scale at the time: xs 2 · sm 3 · md 4 · lg 5 · xl 6 · xxl 8 ·
  pill · circle. libadwaita's own steps line up one-to-one: 6 → xs, 9 → sm, 12 → md, 15 → lg,
  18 → xl.

> **Scale changed again by the owner (2026-10-29), a little rounder:** xs 3 · sm 4 · md 6 ·
> lg 7 · xl 9 · xxl 12. The tokens in the tables are unchanged; read their px values with the
> current scale in `src/_tokens.scss`.

## How Task 9 will apply it

Our `~/.config/gtk-4.0/gtk.css` loads at user priority, so in GTK, as in Shell, it beats
libadwaita outright. A general rule of ours would erase libadwaita's deliberate square corners:
the inner corners of 132 linked button groups, spin buttons, split buttons, window frames and so
on. So Task 9 repeats **every** libadwaita radius rule from the `.tsv`, with the same selectors,
in the same order, changing only the values. Rounded ones get their token; square ones stay
square. libadwaita's own logic for which rule wins on a widget stays exactly as it is, and only
the numbers change.

## Tokens

### Reused from the core set and the Shell layer

| Token | Proposed | libadwaita now | For (examples) |
|---|---|---|---|
| `button` | sm 3 | 9 | buttons, split buttons, opaque/suggested menu buttons, check button areas |
| `entry` | sm 3 | 9 | entries, spin buttons (and their end buttons' outer corners) |
| `checkbox` | xs 2 | 6 | check boxes |
| `radio` | circle | circle | radio buttons, grouped check buttons |
| `switch` | pill | pill | switch tracks, kept as pills (owner, Task 12); the knob is `round` |
| `slider` | sm 3 | pill | slider troughs, fill, highlight (knobs are `round`) |
| `menu-item` | sm 3 | 9 | menu items, menu bar items, emoji picker items |
| `popover` | lg 5 | 15 | popovers, menus |
| `card` | md 4 | 12 | cards, frames, boxed lists (and their first/last rows' corners), file chooser grid items |
| `window` | lg 5 | 15 | windows (through `--window-radius`), floating and bottom sheets |
| `dialog` | xl 6 | 18 | alert dialogs, GTK message dialogs (same as Shell dialogs) |
| `notification` | lg 5 | 15 | in-app notification bars (bottom corners) |
| `icon-button` | sm 3 | pill/circle | circular buttons, tab close buttons, round spin buttons |
| `titlebutton` | circle | circle | window buttons (close, minimize, maximize), kept round (decision 19, after Task 12) |
| `pill-button` | sm 3 | pill | pill buttons, round toggle groups, the About dialog's version label |
| `round` | circle | circle | truly round, kept round: avatars, indicator dots, slider and switch knobs, accent color circles, the video play button |
| `small` | xs 2 | 2–6 | tab underline indicators, keyboard shortcut keycaps, expander titles, color button swatches |
| `inset` | sm 3 | 10 | color picker sliders |
| `scrollbar` | sm 3 | pill | scrollbar troughs and sliders (same as Shell) |

### New for apps

| New token | Proposed | libadwaita now | For |
|---|---|---|---|
| `$radius-row` | sm 3 | 9 | selected rows and items: sidebars, lists, grids, icon views, text selection, calendar days |
| `$radius-tab` | sm 3 | 9 | tabs (tab bar, dragged tab) |
| `$radius-tab-thumbnail` | lg 5 | 16 | tab overview thumbnails |
| `$radius-toggle-group` | sm 3 | 9 | toggle groups; their toggles get this minus the group's padding, as libadwaita does |
| `$radius-swatch` | sm 3 | 9–9.5 | color swatches in color pickers |
| `$radius-response-button` | md 4 | 12 | alert dialog and message dialog response buttons |
| `$radius-app-tooltip` | sm 3 | 9 | app tooltips (Shell's `tooltip` token is for pill labels) |
| `$radius-osd-toolbar` | lg 5 | 15 | OSD toolbars, e.g. video player controls |
| `$radius-bar` | sm 3 | pill | progress bars and level bars |
| `$radius-toast` | lg 5 | pill | toasts |

## Decided while reviewing

- **No pills** (owner): scrollbars, sliders, progress bars, toasts, and circular
  and pill buttons all become scale steps (see the tables). Knobs, avatars, dots, badges and
  radio buttons stay round.
- **Big but consistent changes:** at your scale, buttons and entries go 9 → 3, cards 12 → 4,
  windows and popovers 15 → 5, alert dialogs 18 → 6. Apps end up as square as the Shell.
- **Toggle groups** (e.g. Files' grid/list switch): libadwaita computes the inner toggles'
  radius as the group's radius minus its padding. At 3px that comes out at about 0, so the inner
  toggles turn square inside a slightly rounded group. That's expected; Task 9 checks it.

## Notes

- **Variables:** windows use `var(--window-radius)`. Task 9 sets that variable from the
  `window` token, and libadwaita's own window rule picks it up.
- **"libadwaita now"** is each selector's own value, as in the Shell inventory. Task 9 checks the
  values widgets actually end up with, as far as GTK lets us measure them.
- **Plain GTK4 apps** (GTK4 without libadwaita) use Yaru's own GTK4 theme. `gtk.css` applies to
  them too, but these rules are written against libadwaita's selectors. Task 9 checks one, if any
  is installed.
