#!/usr/bin/env bash
# tests/beads/test-bd-vocabulary.sh
# Fails when tracked, non-exempt text files use a bd 1.0.5-incompatible command form.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$SCRIPT_DIR/../..}"
cd "$REPO_ROOT"
PASS=0
FAIL=0

is_exempt() {
  case "$1" in
    docs/bd-compatibility.md|CHANGELOG.md|docs/plans/*) return 0 ;;
    *) return 1 ;;
  esac
}

record_failure() {
  local description="$1"
  local filepath="$2"
  local matches="$3"
  FAIL=$((FAIL + 1))
  echo "  FAIL: $description — $filepath"
  printf '%s\n' "$matches"
}

assert_no_matches() {
  local description="$1"
  local pattern="$2"
  local filepath="$3"
  local matches

  if matches=$(grep -I -nE -- "$pattern" "$filepath"); then
    record_failure "$description" "$filepath" "$matches"
  else
    PASS=$((PASS + 1))
  fi
}

assert_compaction_is_classified() {
  local filepath="$1"
  local matches
  local match
  local source_line
  local compact_pattern='(^|[^[:alnum:]-])bd[[:space:]]compact([^[:alnum:]]|$)'

  if ! matches=$(grep -I -nE -- "$compact_pattern" "$filepath"); then
    PASS=$((PASS + 1))
    return
  fi

  while IFS= read -r match; do
    source_line="${match#*:}"
    if ! grep -qE 'Dolt|history' <<< "$source_line"; then
      record_failure "unclassified top-level compaction invocation" "$filepath" "$match"
    fi
  done <<< "$matches"
}

echo "Running bd vocabulary compatibility guard..."

while IFS= read -r -d '' filepath; do
  if is_exempt "$filepath"; then
    continue
  fi

  assert_no_matches "unsupported scoped priming" 'bd prime --(work-type|files|keywords)' "$filepath"
  assert_no_matches "unsupported sync command" 'bd sync( |$)' "$filepath"
  assert_no_matches "unsupported start command" 'bd start [0-9a-z]' "$filepath"
  assert_no_matches "unsupported GitHub issue flag" 'bd create.*--issue[ =]' "$filepath"
  assert_no_matches "unsupported decision command" 'bd decision( |$)' "$filepath"
  assert_compaction_is_classified "$filepath"
done < <(git -C "$REPO_ROOT" ls-files -z)

echo "Results: $PASS checks passed, $FAIL failures"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
