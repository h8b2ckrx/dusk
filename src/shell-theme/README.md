# dusk's Shell theme source

`yaru/` is a copy of Yaru's GNOME Shell theme source, the base of dusk's own
Shell theme (design: `docs/2026-10-30-dusk-shell-theme-design.md`).

- **From:** https://github.com/ubuntu/yaru, tag `26.04.5.1ubuntu` (the release
  Ubuntu 26.04's `yaru-theme-gnome-shell` comes from), copied on 2026-10-30 by
  `tools/yaru-shell-source.sh`: Yaru's own Sass and images (`gnome-shell/src`),
  the GNOME Shell upstream Sass and images Yaru bundles (`upstream/`), and the
  Sass helpers its template imports (`common/`).
- **Licence:** Yaru's, kept with the copy: `yaru/COPYING` (GPL-3.0),
  `yaru/COPYING.LGPL-2.1`, `yaru/COPYING.LGPL-3.0`, `yaru/LICENSE_CCBYSA`
  (CC BY-SA 4.0), and the upstream Sass's own `COPYING` files.
- **Edited in place:** dusk's corners, 24.04's colors and the top bar are set
  where Yaru defines each value. Every edit is marked with a `// dusk:`
  comment, and the first commit of the copy is Yaru's own files unchanged, so
  `git log -p src/shell-theme/yaru` shows every change dusk made.
- **Built** by `build.sh` into `extension/theme/dusk-dark.css` and
  `extension/theme/dusk-light.css`, the way Yaru's own build does it.
