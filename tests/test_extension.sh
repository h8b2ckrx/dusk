# The dusk@local extension and tools/shell-reload.sh.

test_metadata_is_valid() {
  python3 - "$REPO/extension/metadata.json" <<'EOF'
import json, sys
m = json.load(open(sys.argv[1]))
assert m["uuid"] == "dusk@local", m["uuid"]
assert m["shell-version"] == ["50"], m["shell-version"]
# No session-modes: the extension (and so its stylesheet) stays off on the lock screen.
assert "session-modes" not in m, "session-modes must not be set"
EOF
}

# extension.js holds exactly one approved exception (design §6, Result):
# dialog button rows honour CSS `spacing`. Nothing else.
test_extension_js_patches_only_dialog_spacing() {
  local js="$REPO/extension/extension.js"
  assert_contains "$js" "import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';"
  assert_contains "$js" "import * as Dialog from 'resource:///org/gnome/shell/ui/dialog.js';"
  grep -qE '^export default class \w+ extends Extension \{' "$js" || fail "no default-exported Extension class"
  assert_eq "$(grep -c 'overrideMethod(' "$js")" 1 "number of overrides"
  assert_contains "$js" "overrideMethod(proto, '_createDialog'"
  assert_contains "$js" "const proto = Dialog.Dialog?.prototype;"
  assert_contains "$js" "typeof proto?._createDialog !== 'function'"
  assert_contains "$js" "lookup_length('spacing', false)"
  assert_contains "$js" "this._injections.clear();"
  # Dialogs Shell built before enable() (Log Out / Power Off) are adopted too,
  # and disable() gives every adopted row back its own spacing.
  assert_contains "$js" "this._findRows(global.stage).forEach(row => this._adopt(row));"
  assert_contains "$js" "row.layout_manager.spacing = original;"
}

# gjs can't resolve Shell's resource:// imports outside Shell, but it parses
# the module first: a syntax error shows up as SyntaxError, a clean parse
# fails only at import resolution.
test_extension_js_parses() {
  local err; err=$(mktemp)
  timeout 10 gjs -m "$REPO/extension/extension.js" 2> "$err" || true
  assert_not_contains "$err" "SyntaxError"
  assert_contains "$err" "Failed to resolve imports"
}

reload_with_stubs() {
  PATH="$REPO/tests/stubs:$PATH" "$REPO/tools/shell-reload.sh"
}

test_shell_reload_clean() {
  local out rc=0
  export DUSK_STUB_LOG; DUSK_STUB_LOG=$(mktemp)
  out=$(DUSK_STUB_JOURNAL="" reload_with_stubs) || rc=$?
  assert_eq "$rc" 0 "exit code"
  assert_eq "$out" "clean"
  assert_contains "$DUSK_STUB_LOG" "gnome-extensions disable dusk@local"
  assert_contains "$DUSK_STUB_LOG" "gnome-extensions enable dusk@local"
}

test_shell_reload_reports_stylesheet_errors() {
  local out rc=0
  export DUSK_STUB_LOG; DUSK_STUB_LOG=$(mktemp)
  out=$(DUSK_STUB_JOURNAL="St-WARNING: Error parsing stylesheet dusk@local/stylesheet-dark.css" reload_with_stubs) || rc=$?
  assert_eq "$rc" 1 "exit code"
  [[ "$out" == *"stylesheet-dark.css"* ]] || fail "log line not printed: $out"
}

# If Shell doesn't end up running dusk, the reload says so instead of "clean".
test_shell_reload_fails_if_not_active() {
  local out rc=0
  export DUSK_STUB_LOG; DUSK_STUB_LOG=$(mktemp)
  out=$(DUSK_STUB_STATE=INACTIVE reload_with_stubs 2>&1) || rc=$?
  assert_eq "$rc" 1 "exit code"
  [[ "$out" == *"not active"* ]] || fail "no 'not active' message: $out"
}
