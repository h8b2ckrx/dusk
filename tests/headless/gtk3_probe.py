#!/usr/bin/env python3
"""Test-only GTK3 probe for tools/probe-gtk3.sh.

Builds sample GTK3 widgets (never shown) and reads the corner radius GTK3
computes for each from its style context, plus a few CSS nodes (switch knob,
check, trough, window frame) through style paths. GTK3 only reports the
`border-radius` shorthand, i.e. the top-left corner. Also records the title
bar close button's background (image or tint), the shape GTK3 draws for it,
and the corner of a button's keyboard focus ring, both drawn in offscreen
windows. Writes OUTDIR/gtk3.json.

Usage: gtk3_probe.py OUTDIR
"""
import json
import sys

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, Gtk  # noqa: E402

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
result = {name: radius(ctx) for name, ctx in samples.items()}

# Title bar buttons: Yaru draws their circle as a background gradient, not a
# radius. Record whether there's a background image, and the tint's alpha,
# in a focused and an unfocused (backdrop) window.
ctx = close.get_style_context()
for label, state in (("", Gtk.StateFlags.NORMAL), ("-backdrop", Gtk.StateFlags.BACKDROP)):
    result[f"titlebutton{label}-image"] = ctx.get_property("background-image", state) is not None
    result[f"titlebutton{label}-alpha"] = round(ctx.get_property("background-color", state).alpha, 3)

# Title bar buttons as GTK3 draws them: a real header bar in an offscreen
# window (never on screen), read back pixel by pixel. The shape is found from
# the pixels that differ from the header bar, along the button's middle row
# and column (Yaru's buttons have a margin, and Yaru draws its circle as a
# gradient, so neither the allocation nor the radius tells the shape). A
# circle has equal width and height and an empty corner.
def pump():
    while Gtk.events_pending():
        Gtk.main_iteration()


def find_close(widget):
    if isinstance(widget, Gtk.Button) and widget.get_style_context().has_class("close"):
        return widget
    found = []
    if isinstance(widget, Gtk.Container):
        widget.forall(lambda child: found.append(find_close(child)))
    return next((f for f in found if f), None)


offscreen = Gtk.OffscreenWindow()
bar = Gtk.HeaderBar(show_close_button=True, decoration_layout=":close", title="dusk")
bar.get_style_context().add_class("titlebar")
offscreen.add(bar)
offscreen.show_all()
pump()
a = find_close(offscreen).get_allocation()
pixbuf = offscreen.get_pixbuf()
n, stride, pixels = pixbuf.get_n_channels(), pixbuf.get_rowstride(), pixbuf.get_pixels()


def pixel(x, y):
    i = y * stride + x * n
    return pixels[i:i + 3]


above = pixel(a.x + a.width // 2, a.y - 2)  # the header bar, just above the button


def drawn(x, y):
    return max(abs(c - b) for c, b in zip(pixel(x, y), above)) > 6


xs = [x for x in range(a.x, a.x + a.width) if drawn(x, a.y + a.height // 2)]
ys = [y for y in range(a.y, a.y + a.height) if drawn(a.x + a.width // 2, y)]
result["titlebutton-shape"] = {
    "width": xs[-1] - xs[0] + 1 if xs else 0,
    "height": ys[-1] - ys[0] + 1 if ys else 0,
    "corner": bool(xs and ys and drawn(xs[0] + 2, ys[0] + 2)),
}

# Keyboard focus rings: GTK3 can't report their radius (asking for
# -gtk-outline-radius returns the border's), so draw one. A button in an
# offscreen window is drawn without and with keyboard focus; the pixels that
# change in its top-left corner are the ring's corner, as a mask. Rings are
# also drawn with each radius from 0 to 10px forced at a priority above
# gtk.css, so the test can tell which radius GTK drew. Each ring gets a new
# window: GTK3 doesn't restyle an offscreen one that's already drawn.
def snapshot(window):
    window.queue_draw()
    pump()
    window.get_window().process_updates(True)
    pump()
    pb = window.get_pixbuf()
    return pb.get_pixels(), pb.get_rowstride(), pb.get_n_channels()


def ring_corner(forced_css=None):
    screen = Gdk.Screen.get_default()
    forced = None
    if forced_css:
        forced = Gtk.CssProvider()
        forced.load_from_data(forced_css.encode())
        Gtk.StyleContext.add_provider_for_screen(screen, forced, Gtk.STYLE_PROVIDER_PRIORITY_USER + 100)
    window = Gtk.OffscreenWindow()
    button = Gtk.Button(label="dusk")
    box = Gtk.Box(margin=10)
    box.pack_start(button, False, False, 0)
    window.add(box)
    window.show_all()
    pump()
    unfocused, stride, n = snapshot(window)
    button.grab_focus()
    focus_in = Gdk.Event.new(Gdk.EventType.FOCUS_CHANGE)
    focus_in.focus_change.in_ = 1
    focus_in.focus_change.window = window.get_window()
    window.event(focus_in)
    window.set_focus_visible(True)
    button.set_state_flags(Gtk.StateFlags.FOCUSED, False)
    focused, _, _ = snapshot(window)
    a = button.get_allocation()

    def changed(x, y):
        i = y * stride + x * n
        return max(abs(p - q) for p, q in zip(focused[i:i + 3], unfocused[i:i + 3])) > 8

    mask = "/".join("".join("#" if changed(x, y) else "." for x in range(a.x, a.x + 8))
                    for y in range(a.y, a.y + 8))
    window.destroy()
    if forced:
        Gtk.StyleContext.remove_provider_for_screen(screen, forced)
    return mask


result["focus-ring"] = ring_corner()
result["focus-ring-for"] = {str(px): ring_corner(f"button {{ -gtk-outline-radius: {px}px; }}")
                            for px in range(11)}

with open(f"{OUT}/gtk3.json", "w") as f:
    json.dump(result, f, indent=1)
