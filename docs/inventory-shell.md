# Shell radius inventory

Waiting for the owner's approval. Approve, or edit the **Proposed** column, before any Shell rules
(Tasks 5–7) get written.

- **Source:** the stylesheet Shell actually loads, `gnome-shell-dark.css` from
  `/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource` (Yaru 26.04.5,
  GNOME Shell 50.1). The light stylesheet has exactly the same radii.
- **Made with:** `tools/radius-inventory.py` (effective value per selector; radius 0 and
  `@media` rules skipped). It found 144 rounded selectors. Excluded ones are listed at the end.
- **Now:** Yaru's value in px. "pill" means 999px, which renders as a fully rounded end.
- **Proposed:** snap to the nearest scale step (6 / 9 / 12 / 15 / 18). Pills stay pills, round
  things stay round. ⚠ marks a big visible change. "LG" means confirm in Looking Glass while
  writing the rule.
- **Selectors** are copied exactly from Yaru. St ranks our stylesheet above Yaru's outright
  (found live in Task 5), so our rules win anyway. The flip side: a general rule of ours also
  erases Yaru's more specific special cases, so those get re-asserted. The tests check both.

> **Scale changed by the owner after chunk A (2026-10-28), twice:** steps are now xs 2, sm 3,
> md 4, lg 5, xl 6, xxl 8. The tokens in the tables are unchanged; read their px values with
> the new scale (e.g. `popover` → lg → 5).

> **No pills (owner, Task 8):** everything that was a pill now uses a scale step: top bar
> items, pill buttons, round icon buttons, switch tracks, sliders, OSD popups, the search entry,
> tooltips and labels, calendar days. Only truly round things stay round (`round`): avatars,
> dots and indicator bars, badges, round icon backgrounds, switch and slider knobs, handles.
> Rows below that still say "pill" read with this rule.

## Scale change to decide first

Yaru uses big radii (22–64px) on large overview surfaces: app tiles, the Alt+Tab panel, the
screenshot panel, the app folder popup. The current scale stops at 18, so all of those would
shrink to 18.

**Proposal:** add one step, `$r-xxl: 24px` (still a multiple of 3), for large surfaces only.
Rows that use it are marked *xxl* below. If you'd rather not, they become *xl (18)* instead.

## New element tokens

Reused core tokens: `checkbox`, `button`, `entry`, `search-entry`, `switch`, `slider`,
`menu-item`, `topbar-item`, `card`, `popover`, `notification`, `osd`, `quick-settings`,
`quick-toggle`, `window`.

| New token | Proposed | For |
|---|---|---|
| `$radius-round` | pill | things round by nature: avatars, round icon backgrounds, indicator dots, handles |
| `$radius-icon-button` | pill | round icon-only buttons (close, expand, arrows, quick settings top row) |
| `$radius-pill-button` | pill | text buttons that are pills ("Clear", calendar month, screenshot Shot/Cast) |
| `$radius-tooltip` | pill | pill labels: overview window titles, screenshot tooltips |
| `$radius-calendar-day` | pill | calendar day cells (today's highlight) |
| `$radius-small` | xs (6) | tiny boxes: week numbers, on-screen-keyboard suggestions, workspace thumbnails |
| `$radius-inset` | sm (9) | small boxes inside other surfaces: weekday headings, event rows, dialog info/warning labels, album art, Alt+Tab thumbnails |
| `$radius-scrollbar` | sm (9) | scrollbar handles |
| `$radius-key` | sm (9) | on-screen keyboard keys |
| `$radius-osd-label` | lg (15) | display-number labels, break countdown |
| `$radius-switcher-item` | lg (15) | Alt+Tab items |
| `$radius-screenshot-button` | lg (15) | screenshot Area / Screen / Window buttons |
| `$radius-folder-tile` | lg (15) | tiles inside an open folder |
| `$radius-dialog-tile` | lg (15) | device tiles in the audio device dialog |
| `$radius-tile` | xxl (24) | app grid and search tiles, search sections, page hints |
| `$radius-switcher` | xxl (24) | Alt+Tab panel |
| `$radius-workspace` | xxl (24) | workspace backgrounds in the overview |
| `$radius-screenshot-panel` | xxl (24) | screenshot toolbar |
| `$radius-folder-dialog` | xxl (24) | open app folder popup |

## Chunk A: top bar, menus, quick settings (Task 5)

| Element | Selectors | Now | Token → Proposed |
|---|---|---|---|
| Top bar items: clock, system menu, indicators (also in the overview) | `#panel .panel-button`, `#panel .panel-button.clock-display`, `#panel .panel-button.clock-display .clock`, `#panel .panel-button.screen-recording-indicator`, `#panel .panel-button.screen-sharing-indicator`, and the same five with `#panel:overview` | pill | `topbar-item` → pill (stock) |
| Activities workspace dots | `#panel .panel-button#panelActivities .workspace-dot` | pill | `round` → pill |
| Menus: top bar dropdowns, right-click menus (Ubuntu Dock's too) | `.popup-menu-content` | 16.8 | `popover` → 15 |
| Menu items | `.popup-menu-item` | 12 | `menu-item` → 9 |
| Open submenu header (top corners) | `.popup-menu-item:checked` | 12 12 0 0 | `menu-item` → 9 9 0 0 |
| Submenu body (bottom corners) | `.popup-sub-menu` | 0 0 13 13 | `menu-item` → 0 0 9 9 |
| Last item of a submenu (bottom corners) | `.popup-sub-menu .popup-menu-item:last-child`, `.popup-sub-menu .popup-menu-section:last-child .popup-menu-item:last-child` | 0 0 12 12 | `menu-item` → 0 0 9 9 |
| Quick settings panel | `.quick-settings` | 16.8 (its own rule says 36, but the panel is also a `.popup-menu-content` and that later rule wins; found live in Task 5) | `quick-settings` → 18 |
| Quick toggles | `.quick-toggle` | 16.8 | `quick-toggle` → 15 |
| Toggle with a menu arrow (outer shape) | `.quick-toggle-has-menu` | pill | `quick-toggle` → 15 ⚠ loses its pill shape |
| … its two halves (outer corners only) | `.quick-toggle-has-menu .quick-toggle:ltr` / `:rtl` / `:ltr:last-child` / `:rtl:last-child`, `.quick-toggle-has-menu .quick-toggle-menu-button:ltr` / `:rtl` | 16.8 on the outer side | `quick-toggle` → 15 on the same corners |
| Toggle menu (e.g. the Wi-Fi list) | `.quick-toggle-menu` | 16.8 | `popover` → 15 |
| Its header icon | `.quick-toggle-menu .header .icon` | pill | `round` → pill |
| Volume / brightness row highlight | `.quick-slider .slider-bin` | pill | `slider` → pill |
| Round icon buttons (quick settings top row, elsewhere) | `.icon-button` | pill | `icon-button` → pill |
| Power off menu icons | `.system-action-icon` | pill | `round` → pill |

Also in Task 5: top bar items added by Vitals, Tasks in Panel, Tiling Shell and AppIndicators.
Each gets checked in LG; any that don't use `.panel-button` get a rule with `topbar-item`.

## Chunk B: notifications, message list, calendar, OSDs, controls (Task 6)

| Element | Selectors | Now | Token → Proposed |
|---|---|---|---|
| Notification banners | `.notification-banner` | 16 | `notification` → 15 |
| Messages | `.message` | 16 | `notification` → 15 |
| Messages in the message list | `.message-view .message` | 18 | `notification` → 15 |
| Notification action buttons | `.notification-button` | 8 | `button` → 9 |
| Media player buttons | `.message-media-control` | 8 | `button` → 9 |
| Album art | `.media-message .message-icon` | 8 | `inset` → 9 |
| Round message icons | `.message .message-box .message-icon.message-themed-icon` | pill | `round` → pill |
| Message close / expand / collapse | `.message .message-header .message-close-button`, `.message .message-header .message-expand-button`, `.message-notification-group .message-collapse-button` | pill | `icon-button` → pill |
| "Clear" button | `.message-list-controls .message-list-clear-button` | pill | `pill-button` → pill |
| Calendar | `.calendar` | 12 | `card` → 12 |
| Calendar dropdown's box | `.datemenu-popover` | 16.8 (its own rule says 8, but the box is also a `.popup-menu-content` and that later rule wins; found live in Task 6) | `popover` (same as other menus) |
| Today button (date header) | `.datemenu-today-button` | 12 | `card` → 12 |
| Events, world clocks, weather boxes | `.events-button`, `.world-clocks-button`, `.weather-button` | 12 | `card` → 12 |
| Event rows | `.events-button .events-box .events-list .event-box` | 8 | `inset` → 9 |
| Calendar days | `.calendar .calendar-day` | pill | `calendar-day` → pill |
| Weekday headings | `.calendar .calendar-day-heading` | 8 | `inset` → 9 |
| Week numbers | `.calendar .calendar-week-number` | 4 | `small` → 6 |
| Month label | `.calendar .calendar-month-header .calendar-month-label` | pill | `pill-button` → pill |
| Month arrows | `.calendar .calendar-month-header .pager-button` | pill | `icon-button` → pill |
| Volume / brightness / keyboard-layout popups | `.osd-window` | pill | `osd` → pill (stock) |
| Display-number labels, break countdown | `.osd-monitor-label`, `.osd-break-countdown-label` | 16 | `osd-label` → 15 |
| Window resize size popup | `.resize-popup` | pill | `osd` → pill |
| Generic Shell buttons | `.button` | 8 | `button` → 9 |
| Text entries | `StEntry` | 8 | `entry` → 9 |
| Overview search entry | `.search-entry` | pill | `search-entry` → pill (stock) |
| Folder rename entry | `.app-folder-dialog .folder-name-container .folder-name-entry` | 8 | `entry` → 9 |
| Check boxes | `.check-box StBin` / `.check-box StIcon` | 7 / 6 | `checkbox` → 6 |
| Switches and their knob | `.toggle-switch`, `.toggle-switch .handle` | pill | `switch` → pill |
| Scrollbar handles | `StScrollBar > .vhandle`, `StScrollBar > .hhandle` | 8 | `scrollbar` → 9 |

## Chunk C: overview, switchers, app grid, search, screenshot UI, the rest (Task 7)

| Element | Selectors | Now | Token → Proposed |
|---|---|---|---|
| App grid and search tiles | `.overview-tile`, `.grid-search-result` | 24 | `tile` → xxl (24) |
| Tiles inside an open folder | `.app-folder-dialog .overview-tile`, `.app-folder-dialog .grid-search-result` | 16 | `folder-tile` → 15 |
| Folder icons in the grid | `.app-folder` | 24 (its own rule says 16, but folder icons are also `.overview-tile` and that later rule wins; found live in Task 7) | `tile` (same as app icons) |
| Open folder popup | `.app-folder-dialog` | 64 | `folder-dialog` → xxl (24) ⚠ much squarer |
| Search result sections | `.search-section-content` | 24 | `tile` → xxl (24) |
| Search result rows / provider icons | `.list-search-result`, `.search-provider-icon` | 13.2 | `card` → 12 |
| App grid page hints (inner corners) | `.page-navigation-hint.next:ltr` / `:rtl`, `.page-navigation-hint.previous:ltr` / `:rtl` | 24 on two corners | `tile` → xxl (24), same corners |
| App grid page arrows | `.page-navigation-arrow` | pill | `icon-button` → pill |
| App grid page dots, running-app dot | `.page-indicator .page-indicator-icon`, `.app-grid-running-dot` | pill / 5 | `round` → pill |
| Notification count badges | `.icon-grid .notification-badge`, `.grid-search-result .notification-badge`, `.overview-tile .notification-badge` | 1em | `round` → pill |
| Workspace backgrounds in the overview | `.workspace-background` | 30 | `workspace` → xxl (24) ⚠ |
| Workspace thumbnails / current-workspace outline | `.workspace-thumbnails .workspace-thumbnail`, `.workspace-thumbnail-indicator` | 4 / 8 | `small` → 6 / `inset` → 9 |
| Overview window titles | `.window-caption` | pill | `tooltip` → pill |
| Overview window close button | `.window-close` | pill | `icon-button` → pill |
| Workspace switch popup and its bars | `.workspace-switcher`, `.ws-switcher-indicator` | pill / 32 | `osd` → pill / `round` → pill (LG: 32 is probably already a full pill) |
| Alt+Tab panel | `.switcher-list` | 28 | `switcher` → xxl (24) |
| Alt+Tab items / window thumbnails | `.switcher-list .item-box`, `.switcher-list .thumbnail` | 16 / 8 | `switcher-item` → 15 / `inset` → 9 |
| Screenshot toolbar | `.screenshot-ui-panel` | 32 | `screenshot-panel` → xxl (24) ⚠ |
| Screenshot Area / Screen / Window | `.screenshot-ui-type-button` | 14 | `screenshot-button` → 15 |
| Screenshot Shot / Cast switch | `.screenshot-ui-shot-cast-container`, `.screenshot-ui-shot-cast-button` | pill | `pill-button` → pill |
| Screenshot shutter, close, show-pointer | `.screenshot-ui-capture-button`, `.screenshot-ui-capture-button .screenshot-ui-capture-button-circle`, `.screenshot-ui-close-button`, `.screenshot-ui-show-pointer-button` | pill | `icon-button` → pill |
| Screenshot handles and window checkmark | `.screenshot-ui-area-selector-handle`, `.screenshot-ui-window-selector-check` | pill | `round` → pill |
| Screenshot window outline | `.screenshot-ui-window-selector-window-border` | 16 | `window` → 15 |
| Screenshot tooltips | `.screenshot-ui-tooltip` | pill | `tooltip` → pill |
| Dialog info / warning labels | `.prompt-dialog .prompt-dialog-error-label`, `.prompt-dialog .prompt-dialog-info-label`, `.prompt-dialog .prompt-dialog-null-label`, `.end-session-dialog .dialog-list-title`, `.end-session-dialog .end-session-dialog-battery-warning` | 8 | `inset` → 9 |
| Audio device dialog tiles | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device` | 16 | `dialog-tile` → 15 |
| User avatars | `.user-icon` | pill | `round` → pill |
| On-screen keyboard keys | `.keyboard-key` | 0.546em | `key` → 9 (LG: em scales with the keyboard; px won't) |
| On-screen keyboard accent popup | `.keyboard-subkeys-boxpointer` | 22 | `popover` → 15 ⚠ |
| On-screen keyboard suggestions | `.word-suggestions StButton` | 4 | `small` → 6 |
| Input-method candidate popup | `.candidate-popup-content` | 16.8 | `popover` → 15 |
| Input-method candidates | `.candidate-box` | 8 | `menu-item` → 9 |
| Input-method page buttons (outer corners) | `.candidate-page-button-previous`, `.candidate-page-button-next` | 8 on the outer side | `button` → 9, same corners |
| Drawing tablet OSD buttons | `.pad-osd-window .button` | 8 | `button` → 9 |

## Excluded (stay stock)

- **Lock screen and login (design §2):** `#panel.login-screen …`, `#panel.unlock-screen …`
  (10 selectors), `.qr-code` and `.web-login-*` (web login), `.parental-controls-shield …`,
  `.conflicting-session-dialog …`.
- ~~Ubuntu Dock's own styling~~: brought in by the owner during Task 8, see "Ubuntu Dock" below.
- **Done in Task 3:** every `.modal-dialog …` selector.
- **Decorative animations:** `.ripple-box` / `.ripple-box:rtl` (the hot-corner ripple) and
  `.ripple-pointer-location`.
- **Not in the source at all:** Looking Glass and high-contrast rules (`@media`).

## Ubuntu Dock (added at the owner's request during Task 8)

The owner's dock: bottom, not extended, "shrink" on. In the Ubuntu session the dock's own
stylesheet (`ubuntu.css`) is empty and relies on these Yaru rules. dusk mirrors them in Yaru's
source order, because several share a specificity and the later one wins.

| Element | Selectors | Now | Token → Proposed |
|---|---|---|---|
| Dock background | `#dash .dash-background`; `#dashtodockContainer.{bottom,top,left,right} #dash .dash-background` and their `.shrink` variants | 28 / 22 / 15 (shrink) | `dock` → lg (5) |
| Dock background when extended edge-to-edge, or with straight corners | `#dashtodockContainer.{pos}.extended #dash .dash-background` (+ `.shrink`), `#dashtodockContainer.straight-corner #dash .dash-background` (+ `.shrink`) | 0 | stays square |
| Icon hover highlight, and the Show Apps button | `#dash .dash-item-container .{overview-tile,grid-search-result,show-apps} .overview-icon`; `#dashtodockContainer.{pos} .dash-item-container .{overview-tile .overview-icon, grid-search-result .overview-icon, show-apps, show-apps .overview-icon, app-well-app}` | 16 / 12 | `dock-item` → md (4) |
| The tiles under the icons | `#dash .dash-item-container .{overview-tile,grid-search-result,show-apps}`, `#dashtodockContainer.{pos} .dash-item-container .{overview-tile,grid-search-result}` | 0 | stays square |
| "Metro" style icons | `#dashtodockContainer .metro .overview-icon` | 0 | stays square |
| App name labels on hover | `.dash-label` | pill | `tooltip` |
| Notification badges | `#dashtodockContainer .notification-badge` | 1em | `round` |

Exact selectors: `tests/headless/dock.selectors`.
