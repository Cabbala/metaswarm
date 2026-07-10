#!/usr/bin/env bash
# Guards D8 path resolution in reviewer dispatch prompts.
#
# Heuristic: inspect only fenced code blocks that contain Task( or recognizable
# reviewer-prompt wording. This intentionally permits ordinary prose citations
# such as ./rubrics/... outside those templates. The check itself uses Bash and
# grep only, so it is CI-safe and independent of Node or installed plugins.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TEMP_DIR="$(mktemp -d)"
PASS=0
FAIL=0
TOTAL=0

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

check_dispatch_prompt_paths() {
  local root="$1"
  local relative file line fence block block_start matches
  local found=0
  local -a files=(
    "skills/design-review-gate/SKILL.md"
    "skills/plan-review-gate/SKILL.md"
    "skills/orchestrated-execution/SKILL.md"
  )

  for relative in "${files[@]}"; do
    file="$root/$relative"
    fence=""
    block=""
    block_start=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -z "$fence" ]]; then
        if [[ "$line" =~ ^\`{3,} ]]; then
          fence="${BASH_REMATCH[0]}"
          block="$line"
          block_start=$((block_start + 1))
        else
          block_start=$((block_start + 1))
        fi
        continue
      fi

      block+=$'\n'"$line"
      block_start=$((block_start + 1))
      if [[ "$line" =~ ^${fence}[[:space:]]*$ ]]; then
        if grep -Eq 'Task\(|[Dd]ispatch|[Pp]rompt:|You are (the )?.*[Rr][Ee][Vv][Ii][Ee][Ww][Ee][Rr]' <<< "$block"; then
          if matches="$(grep -nE "(^|[[:space:]\"'(:=])(\\./)?(rubrics|guides)/" <<< "$block")"; then
            echo "FAIL: bare relative rubric/guide path in dispatch prompt: $relative"
            printf '%s\n' "$matches"
            found=1
          fi
        fi
        fence=""
        block=""
      fi
    done < "$file"
  done

  [[ "$found" -eq 0 ]]
}

assert_result() {
  local description="$1"
  local expected_status="$2"
  local root="$3"
  local output actual_status

  if output="$(check_dispatch_prompt_paths "$root" 2>&1)"; then
    actual_status=0
  else
    actual_status=$?
  fi

  TOTAL=$((TOTAL + 1))
  if [[ "$actual_status" -eq "$expected_status" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $description"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $description (expected $expected_status, got $actual_status)"
  fi
  printf '%s\n' "$output"
}

echo "Testing reviewer dispatch prompt path guard..."

SEED_ROOT="$TEMP_DIR/repo"
for file in \
  skills/design-review-gate/SKILL.md \
  skills/plan-review-gate/SKILL.md \
  skills/orchestrated-execution/SKILL.md; do
  mkdir -p "$SEED_ROOT/$(dirname "$file")"
  cp "$REPO_ROOT/$file" "$SEED_ROOT/$file"
done
printf '%s\n' '' '```text' 'Task({ prompt: "Read ./rubrics/forbidden.md" })' '```' \
  >> "$SEED_ROOT/skills/plan-review-gate/SKILL.md"

assert_result "seeded relative rubric path fails" 1 "$SEED_ROOT"
assert_result "real reviewer prompts use resolved paths" 0 "$REPO_ROOT"

echo
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
