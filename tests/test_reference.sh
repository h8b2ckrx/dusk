# docs/reference/: Yaru 24.04's Shell stylesheets, compiled from the source
# (tools/yaru-2404-shell.sh), the values the Shell colors follow (decision 22).

# The surfaces the design's recon read from the 24.04 source (design §2).
test_reference_2404_surfaces() {
  python3 - "$REPO/docs/reference" <<'EOF'
import re, sys
ref = sys.argv[1]

def background(path, selector):
    """The last background color a rule for exactly `selector` sets."""
    css = re.sub(r"/\*.*?\*/", "", open(path).read(), flags=re.S)
    found = None
    for m in re.finditer(r"([^{}]+)\{([^}]*)\}", css):
        if selector in [" ".join(s.split()) for s in m.group(1).split(",")]:
            for value in re.findall(r"background(?:-color)?\s*:\s*([^;]+);", m.group(2)):
                found = value.strip().lower()
    return found

want = [
    ("dark", ".popup-menu-content", "#1d1d1d"),
    ("dark", ".message", "#2f2f2f"),
    ("dark", ".osd-window", "rgba(29, 29, 29, 0.975)"),
    ("light", ".popup-menu-content", "#fafafa"),
    ("light", ".message", "white"),
]
bad = []
for mode, selector, value in want:
    path = f"{ref}/yaru-24.04-gnome-shell-{mode}.css"
    try:
        got = background(path, selector)
    except FileNotFoundError:
        bad.append(f"missing {path}")
        continue
    if got != value:
        bad.append(f"{mode} {selector}: {got}, want {value}")
print("\n".join(dict.fromkeys(bad)))
sys.exit(1 if bad else 0)
EOF
}
