#!/usr/bin/env bash
# tests/cli/test-installer.sh
# Validate cross-platform installer and platform detection

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "Cross-Platform Installer Tests"
echo "=============================="
echo ""

# 1. CLI entry point exists
if [ -f "$ROOT/cli/metaswarm.js" ]; then
  pass "cli/metaswarm.js exists"
else
  fail "cli/metaswarm.js not found"
fi

# 2. Platform detection module exists
if [ -f "$ROOT/lib/platform-detect.js" ]; then
  pass "lib/platform-detect.js exists"
else
  fail "lib/platform-detect.js not found"
fi

# 3. Platform detection runs without error
if node "$ROOT/lib/platform-detect.js" >/dev/null 2>&1; then
  pass "platform-detect.js runs successfully"
else
  fail "platform-detect.js failed to run"
fi

# 4. Platform detection returns valid JSON-like output
detect_output=$(node "$ROOT/lib/platform-detect.js" 2>&1)
if echo "$detect_output" | grep -q "Claude Code\|Codex CLI"; then
  pass "platform-detect.js detects known platforms"
else
  fail "platform-detect.js output doesn't mention known platforms"
fi

# 5. CLI help works
if node "$ROOT/cli/metaswarm.js" --help 2>&1 | grep -q "metaswarm"; then
  pass "metaswarm --help works"
else
  fail "metaswarm --help failed"
fi

# 6. CLI version works
pkg_ver=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$ROOT/package.json','utf-8')).version)")
cli_ver=$(node "$ROOT/cli/metaswarm.js" --version 2>&1)
if [ "$pkg_ver" = "$cli_ver" ]; then
  pass "CLI version ($cli_ver) matches package.json ($pkg_ver)"
else
  fail "CLI version ($cli_ver) != package.json ($pkg_ver)"
fi

# 7. CLI detect command works
if node "$ROOT/cli/metaswarm.js" detect 2>&1 | grep -q "platform detection"; then
  pass "metaswarm detect runs"
else
  fail "metaswarm detect failed"
fi

# 8. Project setup dry run (in temp dir)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"
git init -q .

# Run setup for claude platform
node "$ROOT/cli/metaswarm.js" setup --claude 2>&1 | grep -q "setup complete" && \
  pass "metaswarm setup --claude works" || \
  fail "metaswarm setup --claude failed"

# Check files were created
if [ -f "$TMP_DIR/CLAUDE.md" ]; then
  pass "setup created CLAUDE.md"
else
  fail "setup did not create CLAUDE.md"
fi

if [ -f "$TMP_DIR/.coverage-thresholds.json" ]; then
  pass "setup created .coverage-thresholds.json"
else
  fail "setup did not create .coverage-thresholds.json"
fi

# 9. Version sync across manifests
versions_match=true
first_ver=""

for manifest in "$ROOT/package.json" "$ROOT/.claude-plugin/plugin.json" "$ROOT/.codex-plugin/plugin.json"; do
  if [ -f "$manifest" ]; then
    ver=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$manifest','utf-8')).version)")
    if [ -n "$first_ver" ] && [ "$ver" != "$first_ver" ]; then
      versions_match=false
    fi
    first_ver="${first_ver:-$ver}"
  fi
done

if [ "$versions_match" = true ]; then
  pass "All manifests have matching versions ($first_ver)"
else
  fail "Manifest versions are out of sync"
fi

# 10. sync-resources.js --check passes
cd "$ROOT"
if node "$ROOT/lib/sync-resources.js" --check 2>&1 | grep -q "in sync"; then
  pass "sync-resources.js --check passes"
else
  fail "sync-resources.js --check found issues"
fi

# 11. Codex marketplace install and legacy fallback paths use only PATH shims.
NODE_BIN="$(command -v node)"

write_git_shim() {
  local bin_dir="$1"
  cat > "$bin_dir/git" <<'EOF'
#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$GIT_LOG"
if [ "$1" = "clone" ]; then
  destination="${!#}"
  /bin/mkdir -p "$destination/skills/demo"
fi
EOF
  chmod +x "$bin_dir/git"
}

write_codex_shim() {
  local bin_dir="$1"
  cat > "$bin_dir/codex" <<'EOF'
#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$CODEX_LOG"
if [ "${CODEX_SHIM_MODE:-success}" = "fail-second" ] && \
   [ "$1" = "plugin" ] && [ "$2" = "add" ] && [ "$3" = "metaswarm@metaswarm" ]; then
  exit 1
fi
if [ "${CODEX_SHIM_MODE:-success}" != "no-cache" ] && \
   [ "$1" = "plugin" ] && [ "$2" = "add" ] && [ "$3" = "metaswarm@metaswarm" ]; then
  /bin/mkdir -p "$CODEX_HOME/plugins/cache/metaswarm/1.0.0"
fi
EOF
  chmod +x "$bin_dir/codex"
}

assert_clone_symlink_fallback() {
  local case_dir="$1"
  local output="$2"

  if grep -q '^clone ' "$case_dir/git.log" && \
     [ -L "$case_dir/home/.agents/skills/metaswarm-demo" ] && \
     grep -q 'Falling back to clone + symlink installation' "$output"; then
    return 0
  fi
  return 1
}

marketplace_case="$TMP_DIR/codex-marketplace"
mkdir -p "$marketplace_case/bin" "$marketplace_case/home" "$marketplace_case/codex-home"
write_codex_shim "$marketplace_case/bin"
write_git_shim "$marketplace_case/bin"

if HOME="$marketplace_case/home" CODEX_HOME="$marketplace_case/codex-home" \
   CODEX_LOG="$marketplace_case/codex.log" GIT_LOG="$marketplace_case/git.log" \
   PATH="$marketplace_case/bin" "$NODE_BIN" "$ROOT/cli/metaswarm.js" init --codex \
   > "$marketplace_case/output.log" 2>&1 && \
   [ "$(sed -n '1p' "$marketplace_case/codex.log")" = "plugin marketplace add Cabbala/metaswarm" ] && \
   [ "$(sed -n '2p' "$marketplace_case/codex.log")" = "plugin add metaswarm@metaswarm" ] && \
   [ "$(wc -l < "$marketplace_case/codex.log")" -eq 2 ] && \
   [ -d "$marketplace_case/codex-home/plugins/cache/metaswarm" ] && \
   [ ! -s "$marketplace_case/git.log" ]; then
  pass "Codex marketplace install runs both qualified commands and verifies the cache"
else
  fail "Codex marketplace install did not complete through the cache-verified path"
fi

command_failure_case="$TMP_DIR/codex-command-failure"
mkdir -p "$command_failure_case/bin" "$command_failure_case/home" "$command_failure_case/codex-home"
write_codex_shim "$command_failure_case/bin"
write_git_shim "$command_failure_case/bin"

HOME="$command_failure_case/home" CODEX_HOME="$command_failure_case/codex-home" \
  CODEX_LOG="$command_failure_case/codex.log" GIT_LOG="$command_failure_case/git.log" \
  CODEX_SHIM_MODE="fail-second" PATH="$command_failure_case/bin" \
  "$NODE_BIN" "$ROOT/cli/metaswarm.js" init --codex \
  > "$command_failure_case/output.log" 2>&1 || true
if assert_clone_symlink_fallback "$command_failure_case" "$command_failure_case/output.log"; then
  pass "Codex command failure falls back to clone and symlink installation"
else
  fail "Codex command failure did not use the clone and symlink fallback"
fi

cache_failure_case="$TMP_DIR/codex-cache-failure"
mkdir -p "$cache_failure_case/bin" "$cache_failure_case/home" "$cache_failure_case/codex-home"
write_codex_shim "$cache_failure_case/bin"
write_git_shim "$cache_failure_case/bin"

HOME="$cache_failure_case/home" CODEX_HOME="$cache_failure_case/codex-home" \
  CODEX_LOG="$cache_failure_case/codex.log" GIT_LOG="$cache_failure_case/git.log" \
  CODEX_SHIM_MODE="no-cache" PATH="$cache_failure_case/bin" \
  "$NODE_BIN" "$ROOT/cli/metaswarm.js" init --codex \
  > "$cache_failure_case/output.log" 2>&1 || true
if assert_clone_symlink_fallback "$cache_failure_case" "$cache_failure_case/output.log"; then
  pass "Codex completion-check failure falls back to clone and symlink installation"
else
  fail "Codex completion-check failure did not use the clone and symlink fallback"
fi

missing_codex_case="$TMP_DIR/codex-missing"
mkdir -p "$missing_codex_case/bin" "$missing_codex_case/home" "$missing_codex_case/codex-home"
write_git_shim "$missing_codex_case/bin"

HOME="$missing_codex_case/home" CODEX_HOME="$missing_codex_case/codex-home" \
  GIT_LOG="$missing_codex_case/git.log" PATH="$missing_codex_case/bin" \
  "$NODE_BIN" "$ROOT/cli/metaswarm.js" init --codex \
  > "$missing_codex_case/output.log" 2>&1 || true
if assert_clone_symlink_fallback "$missing_codex_case" "$missing_codex_case/output.log" && \
   grep -q 'Codex CLI is not on PATH' "$missing_codex_case/output.log"; then
  pass "Missing Codex binary skips marketplace commands and uses the fallback"
else
  fail "Missing Codex binary did not use the fallback"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
