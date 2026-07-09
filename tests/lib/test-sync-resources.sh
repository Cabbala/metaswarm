#!/usr/bin/env bash
# tests/lib/test-sync-resources.sh
# Tests for sync-resources.js build script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../.."
PASS=0
FAIL=0
TOTAL=0
REAL_STATUS_BEFORE="$(git -C "$REPO_ROOT" status --porcelain)"
TEMP_DIR=""

cleanup() {
  [ -z "$TEMP_DIR" ] || rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
  fi
}

echo "Testing sync-resources.js..."

# Test 1: Check mode should pass when files are in sync
echo "Test 1: Check mode passes when synced"
if (cd "$REPO_ROOT" && node lib/sync-resources.js --check >/dev/null 2>&1); then
  result="PASS"
else
  result="FAIL"
fi
assert_eq "Check mode passes" "PASS" "$result"

# Test 2: Sync mode runs without error in an isolated copy
echo "Test 2: Sync mode runs without error in a temporary copy"
TEMP_DIR="$(mktemp -d)"
TEMP_REPO="$TEMP_DIR/repo"
mkdir "$TEMP_REPO"
for path in lib rubrics skills guides templates knowledge bin scripts commands; do
  cp -a "$REPO_ROOT/$path" "$TEMP_REPO/$path"
done
for path in .claude-plugin .codex-plugin; do
  cp -a "$REPO_ROOT/$path" "$TEMP_REPO/$path"
done
mkdir -p "$TEMP_REPO/.agents"
cp -a "$REPO_ROOT/.agents/plugins" "$TEMP_REPO/.agents/plugins"
for file in package.json gemini-extension.json AGENTS.md GEMINI.md; do
  cp -a "$REPO_ROOT/$file" "$TEMP_REPO/$file"
done

if (cd "$TEMP_REPO" && node lib/sync-resources.js --sync >/dev/null 2>&1); then
  result="PASS"
else
  result="FAIL"
fi
assert_eq "Sync mode succeeds" "PASS" "$result"

# Test 3: After syncing, check mode should still pass in the temporary copy
echo "Test 3: Check after sync still passes in the temporary copy"
if (cd "$TEMP_REPO" && node lib/sync-resources.js --check >/dev/null 2>&1); then
  result="PASS"
else
  result="FAIL"
fi
assert_eq "Check after sync passes" "PASS" "$result"

# Test 4: No arguments prints usage and exits non-zero
echo "Test 4: No arguments prints usage"
result=$(cd "$REPO_ROOT" && node lib/sync-resources.js 2>&1 || true)
TOTAL=$((TOTAL + 1))
if echo "$result" | grep -q "Usage"; then
  PASS=$((PASS + 1))
  echo "  PASS: Prints usage without arguments"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: Expected usage message, got: $result"
fi

# Test 5: The test must not mutate the real checkout
echo "Test 5: Real working tree remains unchanged"
REAL_STATUS_AFTER="$(git -C "$REPO_ROOT" status --porcelain)"
assert_eq "Real working tree unchanged" "$REAL_STATUS_BEFORE" "$REAL_STATUS_AFTER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
