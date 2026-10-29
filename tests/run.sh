#!/usr/bin/env bash
# Runs every test_* function in tests/test_*.sh, each in its own bash process
# with `set -e`. Optional argument: only run tests whose file or function name
# contains it, e.g. `tests/run.sh test_lib`.

cd "$(dirname "$0")/.." || exit 1
filter="${1:-}"
passed=0
failed=0

for file in tests/test_*.sh; do
  # A file that doesn't parse would quietly contribute fewer tests.
  if ! err=$(bash -n "$file" 2>&1); then
    echo "FAIL $file (does not parse)"
    echo "$err" | sed 's/^/    /'
    failed=$((failed + 1))
    continue
  fi
  tests=$(bash -c "source tests/lib.sh; source '$file'; declare -F" | awk '{print $3}' | grep '^test_')
  for t in $tests; do
    case "$file $t" in *"$filter"*) ;; *) continue ;; esac
    if out=$(bash -c "set -e; source tests/lib.sh; source '$file'; $t" 2>&1); then
      echo "PASS $t"
      passed=$((passed + 1))
    else
      echo "FAIL $t"
      [ -n "$out" ] && echo "$out" | sed 's/^/    /'
      failed=$((failed + 1))
    fi
  done
done

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
