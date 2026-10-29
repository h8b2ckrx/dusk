# Shell pop-up color inventory

Waiting for the owner's approval (design decision 22, Task 3 of
[the plan](2026-10-29-dusk-shell-colors-plan.md)). Approve, or say what to change, before any color
rule is written.

- **What:** every color rule Yaru 26.04 has for the Shell's floating surfaces, in dark and light,
  next to Yaru 24.04's value for the same thing. Built by `tools/shell-color-inventory.sh` into
  [inventory-shell-colors.tsv](inventory-shell-colors.tsv), which has every row.
- **Rows:** 2232 (383 the same in both modes). Where the 24.04 value comes from:
  - **993 same:** 24.04 has the same rule; its exact value.
  - **16 renamed:** 24.04 has the element under another selector (scroll bar handles, the password
    dialog's labels); its exact value. [The renames](inventory-shell-colors-renames.tsv).
  - **13 unset:** 24.04 has the element but drew no background, border or shadow there: none.
  - **168 derived:** new in 26.04 (notification groups and stacks, CSS-drawn switches and check
    boxes, the quick-toggle arrow button…): 26.04's own formula with 24.04's colors swapped in.
    [Dark palette](inventory-shell-colors-palette-dark.tsv), [light palette](inventory-shell-colors-palette-light.tsv).
  - **548 accent:** uses your accent color (focus rings, checked toggles, the selected day…): 26.04's
    formula stays, so it follows the Settings picker; only a surface color inside it becomes 24.04's.
  - **494 keep:** an out-of-scope rule (lock screen, Blur my Shell's surfaces, the overview's
    search entry…) that one of these would otherwise override. It keeps today's value: no visible change.
- **Chunks:** 1 menus and quick settings, with the buttons, switches, entries, check boxes and scroll
  bars drawn on them (so those change everywhere they appear); 2 notifications and the date menu; 3 dialogs,
  OSDs, Alt+Tab, tooltips and the screenshot panel.
- **Not included** (design §3): the top bar, dock, overview and app grid, Blur my Shell's search cards and
  folder pop-up, the lock and login screens, the on-screen keyboard, Looking Glass, other extensions' panels.
  The dialog buttons keep the 24.04 colors dusk already gives them.

## The main surfaces

| Surface | Element | Dark now → 24.04 | Light now → 24.04 |
|---|---|---|---|
| Menus | `.popup-menu-content` background | `#36363a` → `#1d1d1d` | `white` → `#FAFAFA` |
| Menus | `.popup-menu-item:hover` background | `rgba(255, 255, 255, 0.1) !important` → `#464646` | `rgba(34, 34, 34, 0.1) !important` → `#dedede` |
| Menus | `.popup-menu-item:active` background | `st-lighten(#424247, 9%)` → `#535353` | `st-darken(#f2f2f2, 9%)` → `#d1d1d1` |
| Menus | `.popup-sub-menu` background | `#56565c` → `transparent` | `#d4d4d4` → `transparent` |
| Quick settings | `.quick-toggle-menu` background | `#47474c` → `#2f2f2f` | `white` → `white` |
| Quick settings | `.button` background | `st-mix(white, #36363a, 9%)` → `#313131` | `st-mix(#222222, white, 12%)` → `#e3e3e3` |
| Quick settings | `.button:hover` background | `st-lighten(st-mix(white, #36363a, 9%), 4%)` → `#3b3b3b` | `st-darken(st-mix(#222222, white, 12%), 4%)` → `#d9d9d9` |
| Notifications | `.message` background | `#54545a` → `#2f2f2f` | `white` → `white` |
| Notifications | `.message:hover` background | `st-lighten(#47474c, 4%)` → `#393939` | `st-darken(white, 4%)` → `whitesmoke` |
| Notifications | `.message:second-in-stack` background | `#45454a` → `#262626` | `whitesmoke` → `whitesmoke` |
| Date menu | `.events-button` background | `#47474c` → `#2f2f2f` | `white` → `white` |
| Date menu | `.world-clocks-button` background | `#47474c` → `#2f2f2f` | `white` → `white` |
| Dialogs | `.modal-dialog` background | `#36363a` → `#1d1d1d` | `white` → `#FAFAFA` |
| OSDs | `.osd-window` background | `#2f2f2f` → `rgba(29, 29, 29, 0.975)` | `#2f2f2f` → `rgba(29, 29, 29, 0.975)` |
| Switchers | `.switcher-list` background | `#2f2f2f` → `rgba(29, 29, 29, 0.975)` | `#2f2f2f` → `rgba(29, 29, 29, 0.975)` |
| Tooltips | `.dash-label` background | `rgba(0, 0, 0, 0.9)` → `#222222` | `rgba(0, 0, 0, 0.9)` → `#222222` |
| Screenshot | `.screenshot-ui-panel` background | `#2f2f2f` → `rgba(29, 29, 29, 0.975)` | `#2f2f2f` → `rgba(29, 29, 29, 0.975)` |
| Scroll bars | `StScrollBar > .vhandle` background | `#727275` → `#5e5e5e` | `#bdbdbd` → `#c1c1c1` |

## Derived rows (please check)

New in 26.04, so 24.04 has no value of its own: 26.04's formula with 24.04's colors swapped in.

| Mode | Selector | Property | 26.04 | 24.04 |
|---|---|---|---|---|
| dark | `.message-notification-group .message-collapse-button:focus` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .message-collapse-button:focus` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .message-collapse-button:hover` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .message-collapse-button:hover` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .message-collapse-button:insensitive` | color | `st-transparentize(white, 0.5)` | `st-transparentize(#F7F7F7, 0.5)` |
| light | `.message-notification-group .message-collapse-button:insensitive` | color | `st-transparentize(#222222, 0.6)` | `st-transparentize(#3D3D3D, 0.6)` |
| dark | `.message-notification-group .message-collapse-button:insensitive` | background-color | `st-darken(st-mix(white, #36363a, 9%), 3%)` | `st-darken(st-mix(#F7F7F7, #1d1d1d, 9%), 3%)` |
| light | `.message-notification-group .message-collapse-button:insensitive` | background-color | `st-lighten(st-mix(#222222, white, 12%), 3%)` | `st-lighten(st-mix(#3D3D3D, #FAFAFA, 12%), 3%)` |
| dark | `.message-notification-group .message-collapse-button:selected` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .message-collapse-button:selected` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .message-collapse-button:active` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .message-collapse-button:active` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .message-collapse-button:selected` | background-color | `st-lighten(st-mix(white, #36363a, 9%), 9%)` | `st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 9%)` |
| light | `.message-notification-group .message-collapse-button:selected` | background-color | `st-darken(st-mix(#222222, white, 12%), 9%)` | `st-darken(st-mix(#3D3D3D, #FAFAFA, 12%), 9%)` |
| dark | `.message-notification-group .message-collapse-button:selected:hover` | background-color | `st-lighten(st-lighten(st-mix(white, #36363a, 9%), 9%), 4%)` | `st-lighten(st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 9%), 4%)` |
| light | `.message-notification-group .message-collapse-button:selected:hover` | background-color | `st-darken(st-darken(st-mix(#222222, white, 12%), 9%), 4%)` | `st-darken(st-darken(st-mix(#3D3D3D, #FAFAFA, 12%), 9%), 4%)` |
| dark | `.message-notification-group .message-collapse-button:active:hover` | background-color | `st-lighten(st-lighten(st-mix(white, #36363a, 9%), 9%), 4%)` | `st-lighten(st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 9%), 4%)` |
| light | `.message-notification-group .message-collapse-button:active:hover` | background-color | `st-darken(st-darken(st-mix(#222222, white, 12%), 9%), 4%)` | `st-darken(st-darken(st-mix(#3D3D3D, #FAFAFA, 12%), 9%), 4%)` |
| dark | `.message-notification-group .message-collapse-button:checked` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .message-collapse-button:checked` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .message-collapse-button:checked` | background-color | `st-lighten(st-mix(white, #36363a, 9%), 8%)` | `st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 8%)` |
| light | `.message-notification-group .message-collapse-button:checked` | background-color | `st-darken(st-mix(#222222, white, 12%), 8%)` | `st-darken(st-mix(#3D3D3D, #FAFAFA, 12%), 8%)` |
| dark | `.message-notification-group .message-collapse-button:checked:hover` | background-color | `st-lighten(st-lighten(st-mix(white, #36363a, 9%), 8%), 4%)` | `st-lighten(st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 8%), 4%)` |
| light | `.message-notification-group .message-collapse-button:checked:hover` | background-color | `st-darken(st-darken(st-mix(#222222, white, 12%), 8%), 4%)` | `st-darken(st-darken(st-mix(#3D3D3D, #FAFAFA, 12%), 8%), 4%)` |
| dark | `.message-notification-group .message-collapse-button:checked:active` | background-color | `st-lighten(st-lighten(st-mix(white, #36363a, 9%), 8%), 9%)` | `st-lighten(st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 8%), 9%)` |
| light | `.message-notification-group .message-collapse-button:checked:active` | background-color | `st-darken(st-darken(st-mix(#222222, white, 12%), 8%), 9%)` | `st-darken(st-darken(st-mix(#3D3D3D, #FAFAFA, 12%), 8%), 9%)` |
| dark | `.message-notification-group .flat.message-collapse-button` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .flat.message-collapse-button` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .flat.message-collapse-button` | background-color | `#36363a` | `#1d1d1d` |
| light | `.message-notification-group .flat.message-collapse-button` | background-color | `white` | `#FAFAFA` |
| dark | `.message-notification-group .flat.message-collapse-button:focus` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .flat.message-collapse-button:focus` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .flat.message-collapse-button:hover` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .flat.message-collapse-button:hover` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .flat.message-collapse-button:hover` | background-color | `st-lighten(#36363a, 7%)` | `st-lighten(#1d1d1d, 7%)` |
| light | `.message-notification-group .flat.message-collapse-button:hover` | background-color | `st-darken(white, 7%)` | `st-darken(#FAFAFA, 7%)` |
| dark | `.message-notification-group .flat.message-collapse-button:insensitive` | color | `st-transparentize(white, 0.5)` | `st-transparentize(#F7F7F7, 0.5)` |
| light | `.message-notification-group .flat.message-collapse-button:insensitive` | color | `st-transparentize(#222222, 0.6)` | `st-transparentize(#3D3D3D, 0.6)` |
| dark | `.message-notification-group .flat.message-collapse-button:insensitive` | background-color | `#36363a` | `#1d1d1d` |
| light | `.message-notification-group .flat.message-collapse-button:insensitive` | background-color | `white` | `#FAFAFA` |
| dark | `.message-notification-group .flat.message-collapse-button:selected` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .flat.message-collapse-button:selected` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .flat.message-collapse-button:active` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .flat.message-collapse-button:active` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .flat.message-collapse-button:selected` | background-color | `st-lighten(#36363a, 9%)` | `st-lighten(#1d1d1d, 9%)` |
| light | `.message-notification-group .flat.message-collapse-button:selected` | background-color | `st-darken(white, 9%)` | `st-darken(#FAFAFA, 9%)` |
| dark | `.message-notification-group .flat.message-collapse-button:active` | background-color | `st-lighten(#36363a, 9%)` | `st-lighten(#1d1d1d, 9%)` |
| light | `.message-notification-group .flat.message-collapse-button:active` | background-color | `st-darken(white, 9%)` | `st-darken(#FAFAFA, 9%)` |
| dark | `.message-notification-group .flat.message-collapse-button:selected:hover` | background-color | `st-lighten(st-lighten(#36363a, 9%), 7%)` | `st-lighten(st-lighten(#1d1d1d, 9%), 7%)` |
| light | `.message-notification-group .flat.message-collapse-button:selected:hover` | background-color | `st-darken(st-darken(white, 9%), 7%)` | `st-darken(st-darken(#FAFAFA, 9%), 7%)` |
| dark | `.message-notification-group .flat.message-collapse-button:active:hover` | background-color | `st-lighten(st-lighten(#36363a, 9%), 7%)` | `st-lighten(st-lighten(#1d1d1d, 9%), 7%)` |
| light | `.message-notification-group .flat.message-collapse-button:active:hover` | background-color | `st-darken(st-darken(white, 9%), 7%)` | `st-darken(st-darken(#FAFAFA, 9%), 7%)` |
| dark | `.message-notification-group .flat.message-collapse-button:checked` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .flat.message-collapse-button:checked` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .flat.message-collapse-button:checked` | background-color | `st-lighten(#36363a, 8%)` | `st-lighten(#1d1d1d, 8%)` |
| light | `.message-notification-group .flat.message-collapse-button:checked` | background-color | `st-darken(white, 8%)` | `st-darken(#FAFAFA, 8%)` |
| dark | `.message-notification-group .flat.message-collapse-button:checked:hover` | background-color | `st-lighten(st-lighten(#36363a, 8%), 7%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 7%)` |
| light | `.message-notification-group .flat.message-collapse-button:checked:hover` | background-color | `st-darken(st-darken(white, 8%), 7%)` | `st-darken(st-darken(#FAFAFA, 8%), 7%)` |
| dark | `.message-notification-group .flat.message-collapse-button:checked:active` | background-color | `st-lighten(st-lighten(#36363a, 8%), 9%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 9%)` |
| light | `.message-notification-group .flat.message-collapse-button:checked:active` | background-color | `st-darken(st-darken(white, 8%), 9%)` | `st-darken(st-darken(#FAFAFA, 8%), 9%)` |
| both | `.check-box StIcon` | color | `transparent` | `transparent` |
| dark | `.check-box StIcon` | border | `2px solid rgba(255, 255, 255, 0.15)` | `2px solid rgba(247, 247, 247, 0.15)` |
| light | `.check-box StIcon` | border | `2px solid rgba(0, 0, 0, 0.15)` | `2px solid rgba(0, 0, 0, 0.15)` |
| dark | `.check-box:hover StIcon` | border-color | `rgba(255, 255, 255, 0.2)` | `rgba(247, 247, 247, 0.2)` |
| light | `.check-box:hover StIcon` | border-color | `rgba(0, 0, 0, 0.2)` | `rgba(0, 0, 0, 0.2)` |
| dark | `.check-box:active StIcon` | border-color | `rgba(255, 255, 255, 0.3)` | `rgba(247, 247, 247, 0.3)` |
| light | `.check-box:active StIcon` | border-color | `rgba(0, 0, 0, 0.3)` | `rgba(0, 0, 0, 0.3)` |
| both | `.check-box:checked StIcon` | border-color | `transparent` | `transparent` |
| dark | `.toggle-switch:hover` | background | `rgba(255, 255, 255, 0.2)` | `rgba(247, 247, 247, 0.2)` |
| light | `.toggle-switch:hover` | background | `rgba(0, 0, 0, 0.2)` | `rgba(0, 0, 0, 0.2)` |
| dark | `.toggle-switch .handle` | background | `#d7d7d8` | `#d7d7d8` |
| light | `.toggle-switch .handle` | background | `white` | `#FAFAFA` |
| both | `.toggle-switch .handle` | box-shadow | `0 2px 4px rgba(0, 0, 0, 0.2)` | `0 2px 4px rgba(0, 0, 0, 0.2)` |
| dark | `.toggle-switch:checked .handle` | background | `white` | `#F7F7F7` |
| light | `.toggle-switch:checked .handle` | background | `white` | `#FAFAFA` |
| dark | `.message-notification-group .message-collapse-button` | color | `white` | `#F7F7F7` |
| light | `.message-notification-group .message-collapse-button` | color | `#222222` | `#3D3D3D` |
| dark | `.message-notification-group .message-collapse-button` | background-color | `rgba(255, 255, 255, 0.2)` | `rgba(247, 247, 247, 0.2)` |
| light | `.message-notification-group .message-collapse-button` | background-color | `rgba(34, 34, 34, 0.2)` | `rgba(61, 61, 61, 0.2)` |
| both | `.message-notification-group .message-collapse-button` | border | `4px transparent solid` | `4px transparent solid` |
| dark | `.message-notification-group .message-collapse-button:hover` | background-color | `rgba(255, 255, 255, 0.3)` | `rgba(247, 247, 247, 0.3)` |
| light | `.message-notification-group .message-collapse-button:hover` | background-color | `rgba(34, 34, 34, 0.3)` | `rgba(61, 61, 61, 0.3)` |
| dark | `.message-notification-group .message-collapse-button:active` | background-color | `rgba(255, 255, 255, 0.2)` | `rgba(247, 247, 247, 0.2)` |
| light | `.message-notification-group .message-collapse-button:active` | background-color | `rgba(34, 34, 34, 0.2)` | `rgba(61, 61, 61, 0.2)` |
| dark | `.message:second-in-stack` | background-color | `#45454a` | `#262626` |
| light | `.message:second-in-stack` | background-color | `whitesmoke` | `whitesmoke` |
| dark | `.message:second-in-stack` | box-shadow | `0 1px 1px 0 transparent` | `0 1px 1px 0 transparent` |
| light | `.message:second-in-stack` | box-shadow | `0 1px 1px 0 rgba(0, 0, 0, 0.03)` | `0 1px 1px 0 rgba(0, 0, 0, 0.03)` |
| dark | `.message:lower-in-stack` | background-color | `#3d3d42` | `#222222` |
| light | `.message:lower-in-stack` | background-color | `#ededed` | `#e8e8e8` |
| both | `.message:lower-in-stack` | box-shadow | `none` | `none` |
| dark | `.message:lower-in-stack` | border-color | `transparent` | `transparent` |
| light | `.message:lower-in-stack` | border-color | `#e6e6e6` | `#e1e1e1` |
| dark | `.prompt-dialog .prompt-dialog-info-label` | color | `white` | `#F7F7F7` |
| light | `.prompt-dialog .prompt-dialog-info-label` | color | `#222222` | `#3D3D3D` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device` | color | `white` | `#F7F7F7` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device` | color | `#222222` | `#3D3D3D` |
| both | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device` | background-color | `transparent` | `transparent` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:focus` | color | `white` | `#F7F7F7` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:focus` | color | `#222222` | `#3D3D3D` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:hover` | color | `white` | `#F7F7F7` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:hover` | color | `#222222` | `#3D3D3D` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:hover` | background-color | `st-lighten(#36363a, 7%)` | `st-lighten(#1d1d1d, 7%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:hover` | background-color | `st-darken(white, 7%)` | `st-darken(#FAFAFA, 7%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:active` | color | `white` | `#F7F7F7` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:active` | color | `#222222` | `#3D3D3D` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:active` | background-color | `st-lighten(#36363a, 9%)` | `st-lighten(#1d1d1d, 9%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:active` | background-color | `st-darken(white, 9%)` | `st-darken(#FAFAFA, 9%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:active:hover` | background-color | `st-lighten(st-lighten(#36363a, 9%), 7%)` | `st-lighten(st-lighten(#1d1d1d, 9%), 7%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:active:hover` | background-color | `st-darken(st-darken(white, 9%), 7%)` | `st-darken(st-darken(#FAFAFA, 9%), 7%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted` | color | `white` | `#F7F7F7` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted` | color | `#222222` | `#3D3D3D` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected` | color | `white` | `#F7F7F7` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected` | color | `#222222` | `#3D3D3D` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked` | color | `white` | `#F7F7F7` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked` | color | `#222222` | `#3D3D3D` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted` | background-color | `st-lighten(#36363a, 8%)` | `st-lighten(#1d1d1d, 8%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted` | background-color | `st-darken(white, 8%)` | `st-darken(#FAFAFA, 8%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected` | background-color | `st-lighten(#36363a, 8%)` | `st-lighten(#1d1d1d, 8%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected` | background-color | `st-darken(white, 8%)` | `st-darken(#FAFAFA, 8%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked` | background-color | `st-lighten(#36363a, 8%)` | `st-lighten(#1d1d1d, 8%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked` | background-color | `st-darken(white, 8%)` | `st-darken(#FAFAFA, 8%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted:hover` | background-color | `st-lighten(st-lighten(#36363a, 8%), 7%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 7%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted:hover` | background-color | `st-darken(st-darken(white, 8%), 7%)` | `st-darken(st-darken(#FAFAFA, 8%), 7%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected:hover` | background-color | `st-lighten(st-lighten(#36363a, 8%), 7%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 7%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected:hover` | background-color | `st-darken(st-darken(white, 8%), 7%)` | `st-darken(st-darken(#FAFAFA, 8%), 7%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked:hover` | background-color | `st-lighten(st-lighten(#36363a, 8%), 7%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 7%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked:hover` | background-color | `st-darken(st-darken(white, 8%), 7%)` | `st-darken(st-darken(#FAFAFA, 8%), 7%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted:active` | background-color | `st-lighten(st-lighten(#36363a, 8%), 9%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 9%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:highlighted:active` | background-color | `st-darken(st-darken(white, 8%), 9%)` | `st-darken(st-darken(#FAFAFA, 8%), 9%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected:active` | background-color | `st-lighten(st-lighten(#36363a, 8%), 9%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 9%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:selected:active` | background-color | `st-darken(st-darken(white, 8%), 9%)` | `st-darken(st-darken(#FAFAFA, 8%), 9%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked:active` | background-color | `st-lighten(st-lighten(#36363a, 8%), 9%)` | `st-lighten(st-lighten(#1d1d1d, 8%), 9%)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:checked:active` | background-color | `st-darken(st-darken(white, 8%), 9%)` | `st-darken(st-darken(#FAFAFA, 8%), 9%)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:insensitive` | color | `st-transparentize(white, 0.5)` | `st-transparentize(#F7F7F7, 0.5)` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:insensitive` | color | `st-transparentize(#222222, 0.6)` | `st-transparentize(#3D3D3D, 0.6)` |
| dark | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:insensitive` | background-color | `#36363a` | `#1d1d1d` |
| light | `.audio-device-selection-dialog .audio-selection-box .audio-selection-device:insensitive` | background-color | `white` | `#FAFAFA` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button` | color | `white` | `#F7F7F7` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button` | color | `#222222` | `#3D3D3D` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button` | background-color | `st-mix(white, #4a4a4f, 9%)` | `st-mix(#F7F7F7, #1d1d1d, 9%)` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button` | background-color | `st-mix(#222222, #f2f2f2, 12%)` | `st-mix(#3D3D3D, #ededed, 12%)` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button:focus` | color | `white` | `#F7F7F7` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button:focus` | color | `#222222` | `#3D3D3D` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button:hover` | color | `white` | `#F7F7F7` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button:hover` | color | `#222222` | `#3D3D3D` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button:hover` | background-color | `st-lighten(st-mix(white, #4a4a4f, 9%), 4%)` | `st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 4%)` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button:hover` | background-color | `st-darken(st-mix(#222222, #f2f2f2, 12%), 4%)` | `st-darken(st-mix(#3D3D3D, #ededed, 12%), 4%)` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button:active` | color | `white` | `#F7F7F7` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button:active` | color | `#222222` | `#3D3D3D` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button:active` | background-color | `st-lighten(st-mix(white, #4a4a4f, 9%), 9%)` | `st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 9%)` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button:active` | background-color | `st-darken(st-mix(#222222, #f2f2f2, 12%), 9%)` | `st-darken(st-mix(#3D3D3D, #ededed, 12%), 9%)` |
| dark | `.quick-toggle-has-menu .quick-toggle-menu-button:active:hover` | background-color | `st-lighten(st-lighten(st-mix(white, #4a4a4f, 9%), 9%), 4%)` | `st-lighten(st-lighten(st-mix(#F7F7F7, #1d1d1d, 9%), 9%), 4%)` |
| light | `.quick-toggle-has-menu .quick-toggle-menu-button:active:hover` | background-color | `st-darken(st-darken(st-mix(#222222, #f2f2f2, 12%), 9%), 4%)` | `st-darken(st-darken(st-mix(#3D3D3D, #ededed, 12%), 9%), 4%)` |
| dark | `.quick-toggle-has-menu .quick-toggle-separator` | background-color | `rgba(255, 255, 255, 0.25)` | `rgba(247, 247, 247, 0.25)` |
| light | `.quick-toggle-has-menu .quick-toggle-separator` | background-color | `rgba(34, 34, 34, 0.25)` | `rgba(61, 61, 61, 0.25)` |
| dark | `.background-app-item .message-notification-group .message-collapse-button` | background-color | `rgba(255, 255, 255, 0.13)` | `rgba(247, 247, 247, 0.13)` |
| light | `.background-app-item .message-notification-group .message-collapse-button` | background-color | `rgba(34, 34, 34, 0.13)` | `rgba(61, 61, 61, 0.13)` |
| dark | `.message-notification-group .background-app-item .message-collapse-button` | background-color | `rgba(255, 255, 255, 0.13)` | `rgba(247, 247, 247, 0.13)` |
| light | `.message-notification-group .background-app-item .message-collapse-button` | background-color | `rgba(34, 34, 34, 0.13)` | `rgba(61, 61, 61, 0.13)` |
| dark | `.background-app-item .message-notification-group .message-collapse-button:hover` | background-color | `rgba(255, 255, 255, 0.22)` | `rgba(247, 247, 247, 0.22)` |
| light | `.background-app-item .message-notification-group .message-collapse-button:hover` | background-color | `rgba(34, 34, 34, 0.22)` | `rgba(61, 61, 61, 0.22)` |
| dark | `.message-notification-group .background-app-item .message-collapse-button:hover` | background-color | `rgba(255, 255, 255, 0.22)` | `rgba(247, 247, 247, 0.22)` |
| light | `.message-notification-group .background-app-item .message-collapse-button:hover` | background-color | `rgba(34, 34, 34, 0.22)` | `rgba(61, 61, 61, 0.22)` |
| dark | `.background-app-item .message-notification-group .message-collapse-button:active` | background-color | `rgba(255, 255, 255, 0.31)` | `rgba(247, 247, 247, 0.31)` |
| light | `.background-app-item .message-notification-group .message-collapse-button:active` | background-color | `rgba(34, 34, 34, 0.31)` | `rgba(61, 61, 61, 0.31)` |
| dark | `.message-notification-group .background-app-item .message-collapse-button:active` | background-color | `rgba(255, 255, 255, 0.31)` | `rgba(247, 247, 247, 0.31)` |
| light | `.message-notification-group .background-app-item .message-collapse-button:active` | background-color | `rgba(34, 34, 34, 0.31)` | `rgba(61, 61, 61, 0.31)` |

## Renamed rows

Same element, different selector in 24.04: its exact 24.04 value.

| Mode | Selector | Property | 26.04 | 24.04 |
|---|---|---|---|---|
| dark | `StScrollBar > .vhandle` | background-color | `#727275` | `#5e5e5e` |
| light | `StScrollBar > .vhandle` | background-color | `#bdbdbd` | `#c1c1c1` |
| dark | `StScrollBar > .hhandle` | background-color | `#727275` | `#5e5e5e` |
| light | `StScrollBar > .hhandle` | background-color | `#bdbdbd` | `#c1c1c1` |
| both | `StScrollBar > .vhandle` | border | `3px solid transparent` | `3px solid transparent` |
| both | `StScrollBar > .hhandle` | border | `3px solid transparent` | `3px solid transparent` |
| dark | `StScrollBar > .vhandle:hover` | background-color | `#9b9b9d` | `#8a8a8a` |
| light | `StScrollBar > .vhandle:hover` | background-color | `#919191` | `#9c9c9c` |
| dark | `StScrollBar > .hhandle:hover` | background-color | `#9b9b9d` | `#8a8a8a` |
| light | `StScrollBar > .hhandle:hover` | background-color | `#919191` | `#9c9c9c` |
| dark | `StScrollBar > .vhandle:active` | background-color | `#868689` | `#747474` |
| light | `StScrollBar > .vhandle:active` | background-color | `#a7a7a7` | `#aeaeae` |
| dark | `StScrollBar > .hhandle:active` | background-color | `#868689` | `#747474` |
| light | `StScrollBar > .hhandle:active` | background-color | `#a7a7a7` | `#aeaeae` |
| dark | `.prompt-dialog .prompt-dialog-error-label` | color | `#ffbd45` | `#f99b11` |
| light | `.prompt-dialog .prompt-dialog-error-label` | color | `#964001` | `#f9990c` |

## Unset rows

24.04 drew nothing there.

| Mode | Selector | Property | 26.04 | 24.04 |
|---|---|---|---|---|
| both | `.check-box:focus StBin` | background-color | `rgba(0, 0, 0, 0.01)` | `transparent` |
| dark | `.toggle-switch` | background | `rgba(255, 255, 255, 0.15)` | `transparent` |
| light | `.toggle-switch` | background | `rgba(0, 0, 0, 0.15)` | `transparent` |
| dark | `.popup-sub-menu` | background-color | `#56565c` | `transparent` |
| light | `.popup-sub-menu` | background-color | `#d4d4d4` | `transparent` |
| dark | `.prompt-dialog .prompt-dialog-info-label` | background-color | `rgba(255, 255, 255, 0.1)` | `transparent` |
| light | `.prompt-dialog .prompt-dialog-info-label` | background-color | `rgba(34, 34, 34, 0.1)` | `transparent` |
| dark | `.end-session-dialog .end-session-dialog-battery-warning` | background-color | `#4a4137` | `transparent` |
| light | `.end-session-dialog .end-session-dialog-battery-warning` | background-color | `#f6ede7` | `transparent` |
| dark | `.end-session-dialog .dialog-list-title` | background-color | `#4a4137` | `transparent` |
| light | `.end-session-dialog .dialog-list-title` | background-color | `#f6ede7` | `transparent` |
| dark | `.prompt-dialog .prompt-dialog-error-label` | background-color | `#4a4137` | `transparent` |
| light | `.prompt-dialog .prompt-dialog-error-label` | background-color | `#f6ede7` | `transparent` |
