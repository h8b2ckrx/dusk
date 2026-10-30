# The dusk@local extension and tools/shell-reload.sh.

test_metadata_is_valid() {
  python3 - "$REPO/extension/metadata.json" <<'EOF'
import json, sys
m = json.load(open(sys.argv[1]))
assert m["uuid"] == "dusk@local", m["uuid"]
assert m["shell-version"] == ["50"], m["shell-version"]
# On in the normal session and on the lock screen (decision 21), so its
# stylesheet styles the unlock dialog too. The login screen never loads it.
assert m["session-modes"] == ["user", "unlock-dialog"], m.get("session-modes")
EOF
}

# extension.js holds exactly three approved exceptions (design §2, §4.16,
# §4.20; the Shell theme design 2026-10-30): the overview's workspace
# wallpaper honours .workspace-background's CSS radius, app icons (the main
# app grid, search's app results) honour -dusk-app-icon-size, and dusk's
# theme takes the base slot of Shell's theme, in Yaru's place, coming back
# whenever Shell rebuilds its theme. Nothing else.
test_extension_js_has_three_exceptions() {
  local js="$REPO/extension/extension.js"
  assert_contains "$js" "import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';"
  grep -qE '^export default class \w+ extends Extension \{' "$js" || fail "no default-exported Extension class"
  assert_eq "$(grep -c 'overrideMethod(' "$js")" 1 "number of overrides"
  assert_not_contains "$js" "dialog.js"
  assert_contains "$js" "this._injections.clear();"
  # The workspace wallpaper: Shell's own method still runs first, and
  # disable() re-runs it so Shell's radius comes back.
  assert_contains "$js" "import * as Workspace from 'resource:///org/gnome/shell/ui/workspace.js';"
  assert_contains "$js" "typeof wsProto?._updateBorderRadius !== 'function'"
  assert_contains "$js" "overrideMethod(wsProto, '_updateBorderRadius'"
  assert_contains "$js" "get_border_radius(St.Corner.TOPLEFT)"
  # The app grid: the main grid only, through the layout's own property, and
  # disable() puts back the value Shell had.
  assert_contains "$js" "const grid = Main.overview._overview?._controls?._appDisplay?._grid;"
  assert_contains "$js" "lookup_length('-dusk-app-icon-size', false)"
  assert_contains "$js" "this._setAppGridIconSize(this._appGrid.original);"
  # Search's app results take the same size as search shows them, and get
  # Shell's back on disable. Not through createResultObject, which Ubuntu
  # Dock patches and unpatches on its own (taking a later patch with it).
  assert_contains "$js" "grid.connect('child-added'"
  assert_not_contains "$js" "createResultObject"
  assert_contains "$js" "result.icon.setIconSize(Main.defaultIconSize);"
  # The theme: dusk's file in the base slot, nothing on top, put back when
  # Shell rebuilds its theme, and Shell's own theme back on disable.
  assert_contains "$js" "new St.Theme({default_stylesheet:"
  assert_contains "$js" ".connect('changed'"
  assert_contains "$js" "dusk-\${Main.getStyleVariant()}.css"
  assert_contains "$js" "Main.loadTheme();"
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

# Shell ignores an enable that lands while it is still disabling, leaving the
# extension "Enabled: Yes, State: INACTIVE" (seen live). The reload waits for
# each state and retries once.
test_shell_reload_retries_an_ignored_enable() {
  local out rc=0
  export DUSK_STUB_LOG; DUSK_STUB_LOG=$(mktemp)
  out=$(DUSK_STUB_IGNORE_FIRST_ENABLE=1 reload_with_stubs 2>&1) || rc=$?
  assert_eq "$rc" 0 "exit code"
  assert_eq "$out" "clean"
  assert_eq "$(grep -c 'gnome-extensions enable dusk@local' "$DUSK_STUB_LOG")" 2 "enable calls"
}
