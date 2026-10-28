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

test_extension_js_is_empty_enable_disable() {
  local js="$REPO/extension/extension.js"
  assert_contains "$js" "import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';"
  grep -qE '^export default class \w+ extends Extension \{' "$js" || fail "no default-exported Extension class"
  grep -qE '^\s+enable\(\) \{\}' "$js" || fail "enable() is not empty"
  grep -qE '^\s+disable\(\) \{\}' "$js" || fail "disable() is not empty"
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
  assert_eq "$(cat "$DUSK_STUB_LOG" | grep -c gnome-extensions)" 2 "disable + enable calls"
}

test_shell_reload_reports_stylesheet_errors() {
  local out rc=0
  export DUSK_STUB_LOG; DUSK_STUB_LOG=$(mktemp)
  out=$(DUSK_STUB_JOURNAL="St-WARNING: Error parsing stylesheet dusk@local/stylesheet-dark.css" reload_with_stubs) || rc=$?
  assert_eq "$rc" 1 "exit code"
  [[ "$out" == *"stylesheet-dark.css"* ]] || fail "log line not printed: $out"
}
