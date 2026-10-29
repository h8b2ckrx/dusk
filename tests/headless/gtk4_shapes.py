"""Shared by the GTK4 probes: the corner radii GTK draws for a widget, read
from its render nodes, and widget-tree helpers. Plain GTK4 only (no
libadwaita), so the plain-GTK4 probe can use it too."""
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gsk", "4.0")
from gi.repository import Gsk, Gtk  # noqa: E402

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


def first_shape(widget):
    """The first shape in the widget's render tree, i.e. its own background or
    border (GTK draws those before its children): {"radii": [tl, tr, br, bl],
    "bounds": [w, h]}. A plain color means square corners. None if GTK drew
    no shape at all."""
    snapshot = Gtk.Snapshot()
    Gtk.WidgetPaintable.new(widget).snapshot(snapshot, widget.get_width(), widget.get_height())
    node = snapshot.to_node()
    stack = [node] if node else []
    while stack:
        n = stack.pop(0)
        rect = rounded_rect(n)
        if rect is not None:
            b = rect.bounds
            return {"radii": [round(c.width, 2) for c in rect.corner],
                    "bounds": [round(b.get_width(), 2), round(b.get_height(), 2)]}
        if isinstance(n, Gsk.ColorNode):
            b = n.get_bounds()
            return {"radii": [0.0] * 4, "bounds": [round(b.get_width(), 2), round(b.get_height(), 2)]}
        stack[0:0] = children(n)
    return None


def radii(widget):
    """Corner radii [tl, tr, br, bl] of the widget's first shape (first_shape)."""
    shape = first_shape(widget)
    return shape and shape["radii"]


def iter_children(widget):
    child = widget.get_first_child()
    while child:
        yield child
        child = child.get_next_sibling()


def iter_descendants(widget):
    for child in iter_children(widget):
        yield child
        yield from iter_descendants(child)


def window_button_image(root):
    """The close button's icon in root's window controls: the node Yaru and
    libadwaita draw the button's round tint on."""
    for w in iter_descendants(root):
        if w.get_css_name() == "button" and w.has_css_class("close") \
                and w.get_parent() and w.get_parent().get_css_name() == "windowcontrols":
            return next((c for c in iter_children(w) if c.get_css_name() == "image"), None)
    return None
