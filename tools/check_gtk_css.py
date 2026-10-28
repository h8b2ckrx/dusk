#!/usr/bin/env python3
"""Load a CSS file the way GTK does and report parsing errors.

Usage: check_gtk_css.py {3|4} FILE

Exits 0 when GTK parses FILE cleanly, 1 (printing each error) otherwise.
"""
import sys


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("3", "4"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    version, path = sys.argv[1], sys.argv[2]

    import gi
    gi.require_version("Gtk", f"{version}.0")
    from gi.repository import GLib, Gtk

    if version == "4":
        Gtk.init()

    errors = []

    def on_error(_provider, section, error):
        if version == "4":
            where = section.to_string()
        else:
            where = f"{path}:{section.get_start_line() + 1}"
        errors.append(f"{where}: {error.message}")

    provider = Gtk.CssProvider()
    provider.connect("parsing-error", on_error)
    try:
        provider.load_from_path(path)
    except GLib.Error as e:
        # GTK3 also raises on the first error; keep it if the signal didn't.
        if not errors:
            errors.append(f"{path}: {e.message}")

    for line in errors:
        print(line, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
