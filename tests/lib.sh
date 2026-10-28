# Shared helpers for tests/test_*.sh. Sourced by tests/run.sh.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "  $*" >&2
  return 1
}

assert_eq() {
  [ "$1" = "$2" ] || fail "expected '$2', got '$1'${3:+ ($3)}"
}

# assert_contains FILE TEXT: FILE contains TEXT literally.
assert_contains() {
  grep -qF -- "$2" "$1" || fail "$1 does not contain: $2"
}

# assert_not_contains FILE TEXT: FILE does not contain TEXT literally.
assert_not_contains() {
  ! grep -qF -- "$2" "$1" || fail "$1 contains: $2"
}

# assert_symlink_to LINK TARGET: LINK is a symlink whose target is TARGET.
assert_symlink_to() {
  [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] || fail "$1 is not a symlink to $2"
}

# assert_missing PATH: nothing exists at PATH (not even a dangling symlink).
assert_missing() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1 exists"
}
