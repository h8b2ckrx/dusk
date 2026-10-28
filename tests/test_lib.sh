# src/_lib.scss: token lookup and color variables.

compile_fixture() {
  "${SASSC:-sassc}" -I "$REPO/src" "$REPO/tests/fixtures/$1"
}

test_null_token_emits_nothing() {
  local out; out=$(mktemp)
  compile_fixture lib_null.scss > "$out"
  assert_contains "$out" "background-color: #123456"
  ! grep -qE '^\s*color:' "$out" || fail "a declaration was emitted for a null token"
}

test_unknown_token_errors() {
  local err; err=$(mktemp)
  if compile_fixture lib_unknown.scss > /dev/null 2> "$err"; then
    fail "compiling an unknown token succeeded"
  fi
  assert_contains "$err" "dusk: unknown token 'zzz'"
}

test_color_vars_skips_null() {
  local out; out=$(mktemp)
  compile_fixture lib_vars.scss > "$out"
  assert_contains "$out" "--window-bg-color: #101010;"
  assert_not_contains "$out" "--view-bg-color"
}

test_shell_color_follows_mode() {
  local out; out=$(mktemp)
  compile_fixture shell_mode.scss > "$out"
  assert_contains "$out" "color: #222222"
  assert_not_contains "$out" "#111111"
}
