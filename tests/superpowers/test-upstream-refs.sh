#!/usr/bin/env bash
# tests/superpowers/test-upstream-refs.sh
# contract validated against superpowers v6.1.1 (d884ae0, 2026-07-02)
# Guards the upstream paths and skills that metaswarm's tracked files require.

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$SCRIPT_DIR/../..}"
PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  echo "  PASS: $1"
}

fail() {
  FAIL=$((FAIL + 1))
  echo "  FAIL: $1"
}

superpowers_root=""
if [ -n "${SUPERPOWERS_ROOT:-}" ]; then
  if [ ! -d "$SUPERPOWERS_ROOT" ]; then
    fail "SUPERPOWERS_ROOT is not a directory: $SUPERPOWERS_ROOT"
    echo "Results: $PASS checks passed, $FAIL failures"
    exit 1
  fi

  superpowers_root="$SUPERPOWERS_ROOT"
else
  candidates=()
  shopt -s nullglob
  candidates=("$HOME"/.claude/plugins/cache/*/superpowers*/)
  shopt -u nullglob

  if [ "${#candidates[@]}" -gt 0 ]; then
    superpowers_root="${candidates[0]%/}"
  fi
fi

if [ -z "$superpowers_root" ]; then
  echo "SKIP: superpowers not installed"
  exit 0
fi

echo "Running superpowers upstream reference guard..."
echo "Checkout: $superpowers_root"

version=""
if [ -f "$superpowers_root/RELEASE-NOTES.md" ]; then
  version="$(sed -n 's/^##[[:space:]]*\([^[:space:]].*\)$/\1/p' "$superpowers_root/RELEASE-NOTES.md" | head -n 1)"
fi
if [ -z "$version" ] && git -C "$superpowers_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  version="$(git -C "$superpowers_root" describe --tags --always 2>/dev/null || true)"
fi
echo "Superpowers version: ${version:-unknown}"

mapfile -t referenced_skills < <(
  git -C "$REPO_ROOT" grep -h -o -E 'superpowers:[[:alnum:]_-]+' |
    sed 's/^superpowers://' |
    sort -u
)

if [ "${#referenced_skills[@]}" -eq 0 ]; then
  fail "no tracked superpowers skill references found"
fi

for skill in "${referenced_skills[@]}"; do
  if [ -d "$superpowers_root/skills/$skill" ]; then
    pass "upstream skill exists: $skill"
  else
    fail "upstream skill missing: $skill"
  fi
done

brainstorming_skill="$superpowers_root/skills/brainstorming/SKILL.md"
if [ -f "$brainstorming_skill" ] && grep -qF 'docs/superpowers/specs/' "$brainstorming_skill"; then
  pass "brainstorming documents the primary design-spec path"
else
  fail "brainstorming does not document docs/superpowers/specs/"
fi

echo "Results: $PASS checks passed, $FAIL failures"
[ "$FAIL" -eq 0 ]
