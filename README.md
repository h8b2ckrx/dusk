# dusk

A small personal override layer for Ubuntu 26.04 (GNOME Shell 50, Wayland).
It controls corner radius everywhere, restores the Ubuntu 24.04-style Shell
modal dialogs, and leaves room for color tweaks. Everything else stays stock
Yaru. One token file, `src/_tokens.scss`, drives all three layers: GNOME Shell
(through a stylesheet-only extension), libadwaita apps and GTK3 apps.

Design: [docs/2026-10-28-dusk-design.md](docs/2026-10-28-dusk-design.md) ·
Plan: [docs/2026-10-28-dusk-plan.md](docs/2026-10-28-dusk-plan.md)

## Files

| Path | What it does |
|---|---|
| `src/_tokens.scss` | radius scale, element radii, spacing, color maps (null = stock) |
| `src/_lib.scss` | `token()` lookup (typos stop the build), `color-vars()` mixin |
| `src/shell.scss` | Shell rules; `shell-dark.scss` / `shell-light.scss` compile it per style |
| `src/gtk4.scss`, `src/gtk3.scss` | libadwaita and GTK3 rules |
| `build.sh` | compiles `src/` into `build/gtk4.css`, `build/gtk3.css` and the extension's `stylesheet-dark.css` / `stylesheet-light.css` |
| `install.sh`, `uninstall.sh` | link / unlink the outputs, with backups and a state file |
| `extension/` | the `dusk@local` extension: metadata, empty `extension.js`, compiled stylesheets |
| `tools/check_gtk_css.py` | loads a CSS file in GTK 3 or 4 and fails on parse errors |
| `tools/radius-inventory.py` | lists the effective radius per selector in a stock stylesheet |
| `tools/shell-reload.sh` | reloads the extension's stylesheet and scans Shell's log |
| `tests/` | `tests/run.sh` runs everything; `tests/run.sh <name>` runs a subset |
| `docs/inventory-*.md` | the approved radius tables per layer |

## Install

_To be written in Task 12._

## Uninstall

_To be written in Task 12._

## Updating after a GNOME release

_To be written in Task 12._
