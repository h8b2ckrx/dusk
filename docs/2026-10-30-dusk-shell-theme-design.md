# dusk: its own GNOME Shell theme (design)

Status: built (2026-10-30), and checked by the owner in dark and light. Builds on
[2026-10-28-dusk-design.md](2026-10-28-dusk-design.md) (decisions 1–25) and
[2026-10-29-dusk-shell-colors-design.md](2026-10-29-dusk-shell-colors-design.md).

## 1. Intent

The owner wants the cleanest dusk possible: one that "does not depend on others". Today dusk paints
over Yaru's Shell theme from an extension stylesheet. That works, but it depends on Yaru's rule
names and values staying put, needs hand-kept lists (rules to keep stock, 24.04 rules to add back,
`!important` handling), copies Blur my Shell's colors so it doesn't override them, and relies on
Blur my Shell for the owner's top bar look (a dark pill behind each item). Every one of those is a
place an update of someone else's work can change dusk.

The fix: dusk draws the Shell itself. Its own complete Shell theme, built from a frozen copy of
Yaru 26.04's source with dusk's corners and 24.04's colors set once at the source, loaded by dusk's
own extension, in place of Yaru rather than on top of it. The look stays what the owner has
approved (plus the fixes in §3.5); the way it's made gets simple.

## 2. What stays the same

Everything the owner sees and approved stays, in dark and light:

- dusk's corners everywhere (the radius scale and tokens in `src/_tokens.scss`).
- Ubuntu 24.04's exact colors on every floating Shell surface (decision 22), with the accent
  following the Settings picker (now everywhere: §3.5).
- Dialogs in 26.04's own layout, with dusk's corners (decision 23).
- The lock screen follows dusk (decision 21); the login screen stays stock.
- The bell next to the clock matches the clock (decision 24).
- The two code tweaks: 96px app icons in the app grid and search, and the overview wallpaper's
  rounded corners (decision 20 and §2 of the main design).
- Apps: the GTK side is untouched (`~/.config/gtk-4.0/gtk.css`, `~/.config/gtk-3.0/gtk.css`).
- Icons: untouched (they come from the icon theme).

## 3. What changes

1. **dusk replaces Yaru as the Shell's theme (owner, 2026-10-30: option B).** Shell builds its
   theme from a base stylesheet (Yaru, which Ubuntu's session names and Shell only looks for in
   system folders) and an optional one on top (where GNOME's User Themes puts its theme). With
   Yaru underneath, it shows through wherever dusk's theme sets nothing, and its `!important`
   rules outrank dusk's: the layering trouble this rebuild exists to end. So the `dusk@local`
   extension puts dusk's own stylesheet in the base slot and nothing on top: Yaru isn't loaded.
   Shell rebuilds its theme itself whenever dark/light, High Contrast or the Shell color scheme
   changes, putting Yaru back; the loader then puts dusk's back (the dark or light file, keeping
   the other extensions' stylesheets), before anything is drawn. It stays on at the lock screen
   (session modes `user` and `unlock-dialog`). Disabling it rebuilds Shell's own theme: stock
   Ubuntu. No User Themes extension, no system files, nothing installed as root.
   - This is a third small code exception (the main design's §2), marked as such in the code.
     It relies on how Shell 50 rebuilds its theme; if a later Shell changed that, the desktop
     would fall back to stock Ubuntu (not break), and a test would say so.
2. **The top bar becomes dusk's own grouped look** (the owner's screenshot, 2026-10-30): the bar
   itself see-through, and one dark pill behind each top bar button, so each button's contents
   read as a group (the app button, the clock, Vitals' readings, each indicator, the system menu
   with Wi-Fi, Bluetooth, volume and battery). Pill color as today (black at 80%, Blur my Shell's
   "Contrasted" value), corners `$radius-topbar-item`, the same on hover and press as today, the
   clock and the bell as today. Other extensions' top bar buttons get pills too, as now.
3. **Blur my Shell is no longer needed.** The owner used it for the top bar pills. Once dusk draws
   them, the owner turns it off. Its other effects go with it: the overview, app folder and
   screenshot tool backgrounds are no longer blurred (the lock screen stays blurred: GNOME does
   that itself). dusk adds no blur.
4. **The current color machinery retires**: the extension stylesheets, the generated mirror of
   Yaru's rules, the keep and add lists, the `!important` handling, and the copy of Blur my
   Shell's colors. Today's version is tagged in git first, so going back is one command. (Once
   dusk draws the top bar, turning Blur my Shell back on no longer gives today's top bar; the tag
   does.)
5. **The leftovers from the colors' final review are fixed (owner, 2026-10-30: "fix them all"):**
   - the places that kept 24.04's baked-in orange (the default button's hover, a pressed audio
     device, the Do Not Disturb button's focus) follow the accent like the rest;
   - the overview's scroll bars are the overview's own again (today they take the pop-ups' 24.04
     colors);
   - check boxes take the colors 24.04 drew in its check box pictures, as the switches do;
   - slider bars (`-barlevel-*` colors) take 24.04's;
   - the elements 24.04 had under other names that were missed (the linked dialog buttons, the
     audio device chooser, the date menu's today button when disabled) take 24.04's.

## 4. Goals, non-goals, anti-goals

Goals:
- On the Shell side, dusk depends only on GNOME Shell 50 itself: an update of Yaru, Blur my Shell
  or any other extension can't change dusk's look (Yaru isn't loaded at all).
- One source of truth: each color and corner is set once, at the source.
- The same look as today (§2), proved by tests, apart from the top bar (§3.2) and the fixes
  (§3.5).

Non-goals:
- The login screen (GDM loads the system theme; changing it needs root).
- Apps and icons (unchanged), the on-screen keyboard's look beyond what Yaru's source gives.
- New looks anywhere else; blur.

Anti-goals (a failure even if it technically works):
- Editing or replacing system files, or installing anything as root.
- Depending on User Themes, Blur my Shell or any other extension.
- Dark/light switching that doesn't switch the Shell.
- Any visible change from today the owner didn't ask for.
- A theme that is "Yaru plus a pile of overrides" again: changes are made in the source.

## 5. How it's built (decided)

- **The source:** Yaru's GNOME Shell Sass sources from `ubuntu/yaru`, at the release tag matching
  the installed `yaru-theme-gnome-shell` (26.04.5.1ubuntu on 2026-10-30), copied into the repo and
  frozen. Yaru's licence files and attribution go with the copy (the repo has no licence of its own
  yet).
- **26.04's structure, 24.04's colors:** the copy is 26.04's because a Shell theme must fit the
  Shell it runs on (Shell 50; 24.04 ran Shell 46, and many parts changed). 24.04's colors and
  dusk's corners are set in that source.
- **Changes are made where a value is defined, never layered on top** (owner, 2026-10-30): dusk
  adds no override rules and no `!important` of its own. Yaru's own `!important` declarations in
  the copy stay as Yaru wrote them, unless one stands in the way of 24.04's look (e.g. Yaru's
  `!important` menu hover, which 24.04 didn't have): then it's changed in place. With Yaru not
  loaded, nothing outside the copy can outrank it.
- **Build:** `build.sh` compiles the dark and light theme into the extension folder, under names the
  extension system won't load as extension stylesheets (not `stylesheet*.css`).
- **dusk's copy is the whole theme:** with Yaru not loaded, anything dusk's copy doesn't style is
  unstyled. The coverage test (§6) keeps that from happening unnoticed.
- **Other extensions sit on top of dusk** (Shell layers extension stylesheets over the theme), so
  dusk never fights them.

## 6. Testing

- **Parity with today:** before the rebuild, record what today's dusk computes for every probed
  widget (colors and corners, dark and light, the existing probe variants), and require the new
  theme to compute the same, apart from the top bar (§3.2) and the fixes (§3.5), each checked on
  its own.
- **The existing outcome tests carry over:** colors follow 24.04's own cascade, corners follow the
  tokens, the lock screen, dialogs, icons, the bell.
- **New:** Yaru isn't loaded, also after switching dark/light and High Contrast (the probe switches
  them and re-measures); disabling dusk gives stock Ubuntu back; every top bar button has its pill
  with dusk's corner and color (not on the lock screen: §9); every style class Shell 50 uses in its
  own code has a rule in dusk's theme (catches unstyled widgets after an update).
- GTK tests unchanged.

## 7. Owner gates

1. This document.
2. **dusk's loader with the unchanged Yaru copy:** the desktop looks exactly like stock Ubuntu
   with Blur my Shell as today (proves loading, dark/light, the lock screen and disabling, before
   any look moves). The owner also logs out and in, switches dark/light and locks the screen,
   watching for any flash of a different look: there should be none (extensions start during
   Shell's startup, before its login animation shows the desktop, which is when dusk's look
   arrives today; and the loader swaps its theme back before the next frame is drawn).
3. **Corners, colors, the top bar pills and the fixes, in the source:** the owner turns Blur my
   Shell's top bar style off at this gate (while it's on, it outranks any Shell theme) and checks
   that everything looks like today's dusk, plus the pills and the fixes.
4. Retire the old machinery, update the docs, merge; the owner then turns Blur my Shell off.

## 8. Left to the builder

How the 24.04 colors get into the source (Yaru's color variables, edits in the component files, or
both) as long as parity holds; how the copied source is laid out and patched; token names; the
loader's code; how the parity record is stored; whether the 24.04 reference stylesheets stay as a
test oracle (recommended).

## 9. Calls made while writing this (owner: check these)

- The overview's search box, search result cards and app folder pop-up look as today's dusk shows
  them with Blur my Shell's styles off (26.04's overview look, dusk's corners). Bringing them to
  24.04's colors would be a later step.
- The extension keeps its id `dusk@local`; only its job changes.
- The top bar pills keep today's color and don't change on hover, as Blur my Shell's don't.
- High Contrast stays as accepted (dusk's theme stays on).
- The lock screen's top bar keeps no pills, as today (Blur my Shell switches its style off there).
- The pills arrive with the corners and colors (gate 3), not in a later step, because Blur my
  Shell's top bar style outranks any theme while it's on.
