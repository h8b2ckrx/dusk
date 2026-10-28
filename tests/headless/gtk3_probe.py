#!/usr/bin/env python3
"""Test-only GTK3 probe for tools/probe-gtk3.sh.

Builds sample GTK3 widgets (never shown) and reads the corner radius GTK3
computes for each from its style context, plus a few CSS nodes (switch knob,
check, trough, window frame) through style paths. GTK3 only reports the
`border-radius` shorthand, i.e. the top-left corner. Writes OUTDIR/gtk3.json.

Usage: gtk3_probe.py OUTDIR
"""
import json
import sys

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk  # noqa: E402

OUT = sys.argv[1]


def radius(ctx):
    return ctx.get_property("border-radius", ctx.get_state())


def node(parent_ctx, name, classes=()):
    """A style context for a CSS node `name` under parent_ctx's widget."""
    path = parent_ctx.get_path().copy()
    path.append_type(Gtk.Widget)
    path.iter_set_object_name(-1, name)
    for c in classes:
        path.iter_add_class(-1, c)
    ctx = Gtk.StyleContext()
    ctx.set_path(path)
    ctx.set_parent(parent_ctx)
    return ctx


def path_ctx(*nodes):
    """A style context for a path of (name, [classes]) nodes, e.g. a window frame."""
    path = Gtk.WidgetPath()
    for name, classes in nodes:
        path.append_type(Gtk.Window if name in ("window", "messagedialog") else Gtk.Widget)
        path.iter_set_object_name(-1, name)
        for c in classes:
            path.iter_add_class(-1, c)
    ctx = Gtk.StyleContext()
    ctx.set_path(path)
    return ctx


win = Gtk.Window()
box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
win.add(box)

headerbar = Gtk.HeaderBar()
win.set_titlebar(headerbar)
close = Gtk.Button()
for c in ("titlebutton", "close"):
    close.get_style_context().add_class(c)
headerbar.pack_end(close)

button = Gtk.Button(label="Button")
linked = Gtk.Box()
linked.get_style_context().add_class("linked")
linked_buttons = [Gtk.Button(label=str(i)) for i in range(3)]
for b in linked_buttons:
    linked.pack_start(b, False, False, 0)
entry = Gtk.Entry()
spin = Gtk.SpinButton.new_with_range(0, 10, 1)
switch = Gtk.Switch()
check = Gtk.CheckButton(label="Check")
scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
progress = Gtk.ProgressBar()
for w in (button, linked, entry, spin, switch, check, scale, progress):
    box.pack_start(w, False, False, 0)
# GTK3 only works out first/last-child positions for visible children; show
# the contents, never the window itself.
box.show_all()
headerbar.show_all()
popover = Gtk.Popover(relative_to=button)

samples = {
    "titlebutton": close.get_style_context(),
    "button": button.get_style_context(),
    "linked-first": linked_buttons[0].get_style_context(),
    "linked-middle": linked_buttons[1].get_style_context(),
    "entry": entry.get_style_context(),
    "spinbutton": spin.get_style_context(),
    "switch": switch.get_style_context(),
    "switch-knob": node(switch.get_style_context(), "slider"),
    "check": node(check.get_style_context(), "check"),
    "scale-trough": node(scale.get_style_context(), "trough"),
    "progress-trough": node(progress.get_style_context(), "trough"),
    "linked-last": linked_buttons[2].get_style_context(),
    "popover": popover.get_style_context(),
    "menu": path_ctx(("window", ["background", "csd", "popup"]), ("menu", [])),
    "menu-frame": path_ctx(("window", ["background", "csd", "popup"]), ("decoration", [])),
    "tooltip": path_ctx(("tooltip", ["background"])),
    "window-frame": path_ctx(("window", ["background", "csd"]), ("decoration", [])),
    "window-frame-maximized": path_ctx(("window", ["background", "csd", "maximized"]), ("decoration", [])),
    "dialog-frame": path_ctx(("messagedialog", ["background", "csd"]), ("decoration", [])),
}
with open(f"{OUT}/gtk3.json", "w") as f:
    json.dump({name: radius(ctx) for name, ctx in samples.items()}, f, indent=1)
