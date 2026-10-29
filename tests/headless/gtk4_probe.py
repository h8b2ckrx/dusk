#!/usr/bin/env python3
"""Test-only GTK4 / libadwaita probe for tools/headless-gtk.sh.

Builds sample libadwaita widgets in a window, then reads the corner radii GTK
actually draws for each one from its render nodes, and writes them to
OUTDIR/gtk4.json, with a picture of the window in OUTDIR/gtk4.png.

Usage: gtk4_probe.py OUTDIR   (inside a Wayland session, e.g. headless Shell)

A widget's radius is that of the first shape in its render tree: a rounded
clip, border, shadow or plain color (GTK draws a widget's own background and
border before its children). Samples are chosen to have a background.
"""
import json
import sys

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, GLib, Gtk  # noqa: E402

from gtk4_shapes import dump, first_shape, iter_descendants, radii, window_button_image  # noqa: E402

OUT = sys.argv[1]
# DUSK_GTK_DEBUG="button entry": print those samples' render trees.
DEBUG = (GLib.getenv("DUSK_GTK_DEBUG") or "").split()


def build(app):
    win = Adw.ApplicationWindow(application=app, default_width=720, default_height=640)
    samples = {}
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12,
                  margin_top=18, margin_bottom=18, margin_start=18, margin_end=18)

    def add(name, widget, parent=box):
        samples[name] = widget
        parent.append(widget)
        return widget

    row = Gtk.Box(spacing=12)
    box.append(row)
    add("button", Gtk.Button(label="Button"), row)
    add("button-circular", Gtk.Button(icon_name="list-add-symbolic", css_classes=["circular"]), row)
    add("button-pill", Gtk.Button(label="Pill", css_classes=["pill"]), row)
    add("avatar", Adw.Avatar(size=40, text="Dusk", show_initials=True), row)

    linked = Gtk.Box(css_classes=["linked"])
    for name in ("linked-first", "linked-middle", "linked-last"):
        add(name, Gtk.Button(label=name.split("-")[1]), linked)
    box.append(linked)

    add("entry", Gtk.Entry(text="Entry"))
    add("spinbutton", Gtk.SpinButton.new_with_range(0, 10, 1))

    row2 = Gtk.Box(spacing=12)
    box.append(row2)
    switch = add("switch", Gtk.Switch(active=True, valign=Gtk.Align.CENTER), row2)
    check = add("checkbutton", Gtk.CheckButton(label="Check", active=True), row2)
    radio_a = Gtk.CheckButton(label="Radio")
    radio_b = Gtk.CheckButton(label="Radio", group=radio_a, active=True)
    row2.append(radio_a)
    add("radiobutton", radio_b, row2)

    scale = add("scale", Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1))
    scale.set_value(40)
    add("progressbar", Gtk.ProgressBar(fraction=0.5))

    toggles = Adw.ToggleGroup()
    toggles.add(Adw.Toggle(label="Grid"))
    toggles.add(Adw.Toggle(label="List"))
    toggles.set_active(0)
    add("toggle-group", toggles)

    listbox = Gtk.ListBox(css_classes=["boxed-list"], selection_mode=Gtk.SelectionMode.NONE)
    for i in range(3):
        listbox.append(Adw.ActionRow(title=f"Row {i + 1}"))
    add("boxed-list", listbox)

    card = Gtk.Box(css_classes=["card"], height_request=40)
    add("card", card)

    popover = Gtk.Popover(child=Gtk.Label(label="Popover"))
    menu_button = Gtk.MenuButton(label="Menu", popover=popover)
    box.append(menu_button)

    # A header bar, for its window controls (close, minimize, maximize).
    view = Adw.ToolbarView(content=box)
    view.add_top_bar(Adw.HeaderBar())
    win.set_content(view)

    def internal(widget, css_name):
        """The first descendant whose CSS node name is css_name."""
        stack = [widget]
        while stack:
            w = stack.pop(0)
            if w is not widget and w.get_css_name() == css_name:
                return w
            child = w.get_first_child()
            while child:
                stack.append(child)
                child = child.get_next_sibling()
        return None

    def measure():
        popover.popup()
        GLib.timeout_add(600, finish)
        return GLib.SOURCE_REMOVE

    def finish():
        parts = dict(samples)
        parts["switch-knob"] = internal(switch, "slider")
        parts["check"] = internal(check, "check")
        parts["radio"] = internal(radio_b, "radio")
        parts["scale-trough"] = internal(scale, "trough")
        parts["scale-knob"] = internal(scale, "slider")
        parts["progressbar-trough"] = internal(samples["progressbar"], "trough")
        parts["boxed-list-first-row"] = listbox.get_first_child()
        checked = [t for t in iter_descendants(toggles) if t.get_css_name() == "toggle"
                   and t.get_state_flags() & Gtk.StateFlags.CHECKED]
        parts["toggle"] = checked[0] if checked else None
        parts["popover-contents"] = internal(popover, "contents")
        parts["window"] = win
        parts["titlebutton-image"] = window_button_image(win)
        result = {}
        for name, widget in parts.items():
            if widget is None:
                result[name] = {"error": "not found"}
                continue
            result[name] = {"radii": radii(widget), "size": [widget.get_width(), widget.get_height()]}
            if name == "titlebutton-image":
                result[name]["shape"] = first_shape(widget)
            if name in DEBUG:
                snap = Gtk.Snapshot()
                Gtk.WidgetPaintable.new(widget).snapshot(snap, widget.get_width(), widget.get_height())
                node = snap.to_node()
                print(f"== {name}\n" + ("\n".join(dump(node)) if node else "(no node)"), flush=True)
        with open(f"{OUT}/gtk4.json", "w") as f:
            json.dump(result, f, indent=1)
        texture = Gtk.WidgetPaintable.new(win)
        snap = Gtk.Snapshot()
        texture.snapshot(snap, win.get_width(), win.get_height())
        node = snap.to_node()
        renderer = win.get_native().get_renderer()
        renderer.render_texture(node, None).save_to_png(f"{OUT}/gtk4.png")
        app.quit()
        return GLib.SOURCE_REMOVE

    win.present()
    GLib.timeout_add(1500, measure)


app = Adw.Application(application_id="org.dusk.GtkProbe")
app.connect("activate", build)
app.run([])
