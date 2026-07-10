#!/usr/bin/env bash
# Tests for lib/validate-project-profile.js. Each invalid fixture is expected to
# fail, proving the validator distinguishes the v1 command contract from legacy
# profiles that omit schema_version.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="$REPO_ROOT/lib/validate-project-profile.js"
TMP_DIR="$(mktemp -d)"
PASS=0
FAIL=0
TOTAL=0

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

write_profile() {
  printf '%s\n' "$2" > "$1"
}

expect_result() {
  local description="$1"
  local expected_status="$2"
  local expected_text="$3"
  shift 3
  local actual_status output

  if output="$("$@" 2>&1)"; then
    actual_status=0
  else
    actual_status=$?
  fi

  TOTAL=$((TOTAL + 1))
  if [[ "$actual_status" -eq "$expected_status" && "$output" == *"$expected_text"* ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $description"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $description"
    echo "    Expected status: $expected_status; actual: $actual_status"
    echo "    Expected output to contain: $expected_text"
  fi
  printf '%s\n' "$output"
}

VALID_PROFILE="$TMP_DIR/valid.json"
UNKNOWN_COMMAND="$TMP_DIR/unknown-command.json"
INVALID_VALUE="$TMP_DIR/invalid-value.json"
LEGACY_PROFILE="$TMP_DIR/legacy.json"

write_profile "$VALID_PROFILE" '{"schema_version":1,"commands":{"test":"npm test","coverage":null,"lint":"npm run lint","typecheck":null,"format_check":"npm run format:check"}}'
write_profile "$UNKNOWN_COMMAND" '{"schema_version":1,"commands":{"test":"npm test","coverage":null,"lint":null,"typecheck":null,"format_check":null,"deploy":"npm run deploy"}}'
write_profile "$INVALID_VALUE" '{"schema_version":1,"commands":{"test":42,"coverage":null,"lint":null,"typecheck":null,"format_check":null}}'
write_profile "$LEGACY_PROFILE" '{"commands":{"test":"npm test","coverage":null,"lint":null,"typecheck":null,"format_check":null}}'

echo "Testing project-profile validator..."

expect_result "valid v1 profile passes" 0 "VALID:" \
  node "$VALIDATOR" "$VALID_PROFILE"
expect_result "unknown command key fails" 1 "commands.deploy is not allowed" \
  node "$VALIDATOR" "$UNKNOWN_COMMAND"
expect_result "non-string non-null command fails" 1 "commands.test must be a non-empty string or null" \
  node "$VALIDATOR" "$INVALID_VALUE"
expect_result "legacy profile warns and passes by default" 0 "WARNING: schema_version is absent" \
  node "$VALIDATOR" "$LEGACY_PROFILE"
expect_result "legacy profile fails in strict mode" 1 "schema_version is required in --strict mode" \
  node "$VALIDATOR" --strict "$LEGACY_PROFILE"

echo
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
