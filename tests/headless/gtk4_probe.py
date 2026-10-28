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
gi.require_version("Gsk", "4.0")
from gi.repository import Adw, GLib, Gsk, Gtk  # noqa: E402

OUT = sys.argv[1]
# DUSK_GTK_DEBUG="button entry": print those samples' render trees.
DEBUG = (GLib.getenv("DUSK_GTK_DEBUG") or "").split()
SHAPES = (Gsk.RoundedClipNode, Gsk.BorderNode, Gsk.OutsetShadowNode, Gsk.InsetShadowNode)


def children(node):
    if isinstance(node, Gsk.ContainerNode):
        return [node.get_child(i) for i in range(node.get_n_children())]
    for getter in ("get_child",):
        if hasattr(node, getter):
            try:
                child = getattr(node, getter)()
                return [child] if child else []
            except TypeError:
                pass
    return []


def rounded_rect(node):
    if isinstance(node, Gsk.RoundedClipNode):
        return node.get_clip()
    if isinstance(node, Gsk.BorderNode):
        return node.get_outline()
    if isinstance(node, (Gsk.OutsetShadowNode, Gsk.InsetShadowNode)):
        return node.get_outline()
    return None


def dump(node, depth=0, out=None):
    """Debug: the render tree as text."""
    out = [] if out is None else out
    b = node.get_bounds()
    rect = rounded_rect(node)
    extra = f" corners={[round(c.width, 1) for c in rect.corner]}" if rect else ""
    out.append(f"{'  ' * depth}{type(node).__name__} {b.get_width():.0f}x{b.get_height():.0f}"
               f"@{b.get_x():.0f},{b.get_y():.0f}{extra}")
    for c in children(node):
        dump(c, depth + 1, out)
    return out


def radii(widget):
    """Corner radii [tl, tr, br, bl] of the widget's own background or border:
    the first shape in its render tree (GTK draws a widget's own background
    and border before its children). A plain color means square corners.
    None if GTK drew no shape at all."""
    snapshot = Gtk.Snapshot()
    Gtk.WidgetPaintable.new(widget).snapshot(snapshot, widget.get_width(), widget.get_height())
    node = snapshot.to_node()
    stack = [node] if node else []
    while stack:
        n = stack.pop(0)
        rect = rounded_rect(n)
        if rect is not None:
            return [round(c.width, 2) for c in rect.corner]
        if isinstance(n, Gsk.ColorNode):
            return [0.0] * 4
        stack[0:0] = children(n)
    return None


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

    win.set_content(box)

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
        result = {}
        for name, widget in parts.items():
            if widget is None:
                result[name] = {"error": "not found"}
                continue
            result[name] = {"radii": radii(widget), "size": [widget.get_width(), widget.get_height()]}
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


def iter_children(widget):
    child = widget.get_first_child()
    while child:
        yield child
        child = child.get_next_sibling()


def iter_descendants(widget):
    for child in iter_children(widget):
        yield child
        yield from iter_descendants(child)


app = Adw.Application(application_id="org.dusk.GtkProbe")
app.connect("activate", build)
app.run([])
