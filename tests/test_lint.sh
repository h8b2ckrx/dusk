# Rule files: no literal values (spec §7) and a comment above every rule.

RULE_FILES=(src/gtk4.scss src/gtk3.scss src/_gtk4-radius.scss src/_gtk3-radius.scss)

# lint_literals FILE...: fails on any hex color, number with a unit, color
# function or named color in a declaration (`property: value;`). Selectors
# and `//` comments aren't checked (an id like #add isn't a color). Bare `0`
# is allowed.
lint_literals() {
  local f hits bad=0
  for f in "$@"; do
    [ -f "$f" ] || { echo "  missing $f" >&2; bad=1; continue; }
    hits=$(grep -nE '^\s*-*[a-zA-Z][a-zA-Z0-9-]*\s*:[^{]*;' "$f" \
      | grep -E '#[0-9a-fA-F]{3,8}\b|\b[0-9]*\.?[0-9]+(px|em|rem|pt|%)|\b(rgba?|hsla?)\(|\b(white|black|transparent)\b' || true)
    if [ -n "$hits" ]; then
      echo "$hits" | sed "s|^|  $f:|" >&2
      bad=1
    fi
  done
  return $bad
}

# lint_comments FILE...: every top-level rule (a line ending in `{` that
# isn't an @-rule) needs a `//` comment as the line before it. For selector
# lists spanning several lines, the comment goes above the first line.
lint_comments() {
  local f bad=0
  for f in "$@"; do
    [ -f "$f" ] || { echo "  missing $f" >&2; bad=1; continue; }
    awk -v file="$f" '
      /^[[:space:]]*$/ { next }
      /^[^[:space:]@}].*,[[:space:]]*$/ { if (!ingroup) { before = prev; ingroup = 1 } prev = $0; next }
      /^[^[:space:]@}].*\{[[:space:]]*$/ {
        check = ingroup ? before : prev
        if (check !~ /^[[:space:]]*\/\//) { print "  " file ":" NR ": rule without a comment above it" > "/dev/stderr"; bad = 1 }
        ingroup = 0
      }
      { prev = $0 }
      END { exit bad }
    ' "$f" || bad=1
  done
  return $bad
}

test_no_literal_values() {
  (cd "$REPO" && lint_literals "${RULE_FILES[@]}")
}

test_rules_are_commented() {
  (cd "$REPO" && lint_comments "${RULE_FILES[@]}")
}

# The lint itself must catch a bad file.
test_lint_catches_bad_fixture() {
  if lint_literals "$REPO/tests/fixtures/lint_bad.scss" 2> /dev/null; then
    fail "lint_literals missed 8px"
  fi
  if lint_comments "$REPO/tests/fixtures/lint_bad.scss" 2> /dev/null; then
    fail "lint_comments missed an uncommented rule"
  fi
}

# A commented multi-line selector list using tokens and bare 0 passes.
test_lint_accepts_good_fixture() {
  lint_literals "$REPO/tests/fixtures/lint_good.scss"
  lint_comments "$REPO/tests/fixtures/lint_good.scss"
}

# Only declarations are checked for literals: an id like #add in a selector
# is not a color.
test_lint_ignores_selectors() {
  lint_literals "$REPO/tests/fixtures/lint_selector_hex.scss"
}
