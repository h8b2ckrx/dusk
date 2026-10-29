#!/usr/bin/env python3
"""Test-only plain-GTK4 probe (no libadwaita) for tools/headless-gtk.sh.

Plain GTK4 programs use the GTK theme's own gtk-4.0 stylesheet (Yaru's), not
libadwaita's. One of them draws the title bars of X11 apps such as VLC:
Mutter's frames helper. Records the radii GTK draws for a header bar's close
button icon (where the round tint is drawn), and the theme in use, in
OUTDIR/gtk4-plain.json.

Usage: gtk4_plain_probe.py OUTDIR   (inside a Wayland session, e.g. headless Shell)
"""
import json
import sys

import gi
gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk  # noqa: E402

from gtk4_shapes import first_shape, radii, window_button_image  # noqa: E402

OUT = sys.argv[1]


def build(app):
    win = Gtk.ApplicationWindow(application=app, default_width=400, default_height=200,
                                titlebar=Gtk.HeaderBar())

    def finish():
        image = window_button_image(win)
        result = {"theme": Gtk.Settings.get_default().props.gtk_theme_name}
        result["titlebutton-image"] = ({"error": "not found"} if image is None else
                                       {"radii": radii(image),
                                        "size": [image.get_width(), image.get_height()],
                                        "shape": first_shape(image)})
        with open(f"{OUT}/gtk4-plain.json", "w") as f:
            json.dump(result, f, indent=1)
        app.quit()
        return GLib.SOURCE_REMOVE

    win.present()
    GLib.timeout_add(1500, finish)


app = Gtk.Application(application_id="org.dusk.GtkPlainProbe")
app.connect("activate", build)
app.run([])
