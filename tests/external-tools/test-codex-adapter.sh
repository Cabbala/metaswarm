#!/usr/bin/env bash
# Validate the Codex external-tools adapter without invoking a real Codex CLI.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADAPTER="$ROOT/skills/external-tools/adapters/codex.sh"
PASS=0
FAIL=0
TMP_DIR="$(mktemp -d)"
TEST_HOME="$TMP_DIR/home"
FAKE_BIN="$TMP_DIR/bin"
WORKTREE="$TMP_DIR/worktree"
ARGV_FILE="$TEST_HOME/fake-codex-argv"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_line() {
  local description="$1"
  local expected="$2"
  local file="${3:-$ARGV_FILE}"
  if grep -Fqx -- "$expected" "$file"; then
    pass "$description"
  else
    fail "$description (missing: $expected)"
  fi
}

assert_no_line() {
  local description="$1"
  local unexpected="$2"
  local file="${3:-$ARGV_FILE}"
  if grep -Fqx -- "$unexpected" "$file"; then
    fail "$description (unexpected: $unexpected)"
  else
    pass "$description"
  fi
}

assert_output_contains() {
  local description="$1"
  local expected="$2"
  local output="$3"
  if grep -Fq -- "$expected" <<< "$output"; then
    pass "$description"
  else
    fail "$description (missing: $expected)"
  fi
}

run_adapter() {
  HOME="$TEST_HOME" PATH="$FAKE_BIN:$PATH" bash "$ADAPTER" "$@"
}

mkdir -p "$TEST_HOME" "$FAKE_BIN" "$WORKTREE/src"
cat > "$FAKE_BIN/codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" >> "$HOME/fake-codex-argv"

args=("$@")
worktree=""
for ((index = 0; index < ${#args[@]}; index++)); do
  if [[ "${args[$index]}" == "-C" ]]; then
    worktree="${args[$((index + 1))]}"
    break
  fi
done

prompt="${args[$(( ${#args[@]} - 1 ))]}"
if [[ "$prompt" == *"FAKE_MODEL_UNAVAILABLE_JSONL"* ]]; then
  printf '{"error":{"message":"model not found"}}\n'
  exit 42
fi

if [[ "$prompt" == *"FAKE_MODEL_UNAVAILABLE"* ]]; then
  printf 'requested model is unavailable\n' >&2
  exit 42
fi

if [[ "$prompt" == *"FAKE_OUT_OF_SCOPE"* ]]; then
  printf 'outside scope\n' > "$worktree/outside.txt"
  printf 'inside scope\n' > "$worktree/src/in-scope.txt"
fi

if [[ "$prompt" == *"FAKE_IN_SCOPE"* ]]; then
  printf 'green path\n' > "$worktree/src/green.txt"
fi

if [[ "$prompt" == *"FAKE_LARGE_LOG"* ]]; then
  payload="$(printf 'x%.0s' {1..200})"
  for _ in {1..400}; do
    printf '{"event":"%s"}\n' "$payload"
  done
fi

printf '{"usage":{"input_tokens":1,"output_tokens":2}}\n'
FAKE_CODEX
chmod +x "$FAKE_BIN/codex"

git -C "$WORKTREE" init -q
git -C "$WORKTREE" config user.name "Adapter Test"
git -C "$WORKTREE" config user.email "adapter-test@example.invalid"
printf 'base\n' > "$WORKTREE/src/base.txt"
git -C "$WORKTREE" add src/base.txt
git -C "$WORKTREE" commit -qm "initial fixture"

PROMPT_DEFAULT="$TMP_DIR/default.md"
PROMPT_CUSTOM="$TMP_DIR/custom.md"
PROMPT_ULTRA="$TMP_DIR/ultra.md"
PROMPT_SCOPE="$TMP_DIR/scope.md"
PROMPT_GREEN="$TMP_DIR/green.md"
PROMPT_UNAVAILABLE="$TMP_DIR/unavailable.md"
PROMPT_UNAVAILABLE_JSONL="$TMP_DIR/unavailable-jsonl.md"
PROMPT_LARGE="$TMP_DIR/large.md"
RUBRIC="$TMP_DIR/rubric.md"
SPEC="$TMP_DIR/spec.md"
printf 'default implement\n' > "$PROMPT_DEFAULT"
printf 'custom implement\n' > "$PROMPT_CUSTOM"
printf 'ultra implement\n' > "$PROMPT_ULTRA"
printf 'FAKE_OUT_OF_SCOPE\n' > "$PROMPT_SCOPE"
printf 'FAKE_IN_SCOPE\n' > "$PROMPT_GREEN"
printf 'FAKE_MODEL_UNAVAILABLE\n' > "$PROMPT_UNAVAILABLE"
printf 'FAKE_MODEL_UNAVAILABLE_JSONL\n' > "$PROMPT_UNAVAILABLE_JSONL"
printf 'FAKE_LARGE_LOG\n' > "$PROMPT_LARGE"
printf 'review rubric\n' > "$RUBRIC"
printf 'review spec\n' > "$SPEC"

echo ""
echo "Codex External-Tools Adapter Tests"
echo "=================================="
echo ""

# (a) Implement defaults must be passed to the real invocation envelope.
: > "$ARGV_FILE"
if default_output="$(run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_DEFAULT" 2>&1)"; then
  pass "default implement invocation succeeds"
else
  fail "default implement invocation succeeds"
fi
assert_line "implement passes Terra model" "model=gpt-5.6-terra"
assert_line "implement passes xhigh reasoning effort" "model_reasoning_effort=xhigh"
assert_line "implement uses workspace-write sandbox" "workspace-write"
assert_line "implement disables network by default" "sandbox_workspace_write.network_access=false"
assert_output_contains "implement JSON metadata reports the Terra model" "gpt-5.6-terra" "$default_output"

if health_output="$(run_adapter health 2>&1)"; then
  pass "health check succeeds with the fake CLI"
else
  fail "health check succeeds with the fake CLI"
fi
assert_output_contains "health reports the implement default model" "gpt-5.6-terra" "$health_output"

# (b) Explicit flags override defaults and --allow-network omits the denial.
: > "$ARGV_FILE"
if custom_output="$(run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_CUSTOM" --model gpt-5.6-sol --effort high --allow-network 2>&1)"; then
  pass "custom implement invocation succeeds"
else
  fail "custom implement invocation succeeds"
fi
assert_line "--model overrides the implement model" "model=gpt-5.6-sol"
assert_line "--effort overrides the reasoning effort" "model_reasoning_effort=high"
assert_no_line "--allow-network omits the network denial" "sandbox_workspace_write.network_access=false"
assert_output_contains "custom JSON metadata reports the selected model" "gpt-5.6-sol" "$custom_output"

# Environment fallbacks supply the same routing and network controls.
: > "$ARGV_FILE"
if env_output="$(XT_MODEL=gpt-5.6-sol XT_EFFORT=medium XT_ALLOW_NETWORK=1 run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_CUSTOM" 2>&1)"; then
  pass "environment fallback implement invocation succeeds"
else
  fail "environment fallback implement invocation succeeds"
fi
assert_line "XT_MODEL supplies the model fallback" "model=gpt-5.6-sol"
assert_line "XT_EFFORT supplies the effort fallback" "model_reasoning_effort=medium"
assert_no_line "XT_ALLOW_NETWORK omits the network denial" "sandbox_workspace_write.network_access=false"

# (c) Review has Sol/xhigh defaults and is always read-only.
: > "$ARGV_FILE"
if review_output="$(run_adapter review --worktree "$WORKTREE" --rubric-file "$RUBRIC" --spec-file "$SPEC" 2>&1)"; then
  pass "review invocation succeeds"
else
  fail "review invocation succeeds"
fi
assert_line "review passes Sol model" "model=gpt-5.6-sol"
assert_line "review passes xhigh reasoning effort" "model_reasoning_effort=xhigh"
assert_line "review uses read-only sandbox" "read-only"
assert_no_line "review never requests workspace-write" "workspace-write"
assert_output_contains "review JSON metadata reports the Sol model" "gpt-5.6-sol" "$review_output"

# (d) The ultra guard is red without opt-in and green with Sol plus opt-in.
: > "$ARGV_FILE"
if ultra_error="$(env -u XT_ULTRA_OPTIN HOME="$TEST_HOME" PATH="$FAKE_BIN:$PATH" bash "$ADAPTER" implement --worktree "$WORKTREE" --prompt-file "$PROMPT_ULTRA" --model gpt-5.6-sol --effort ultra 2>&1)"; then
  fail "ultra without opt-in exits nonzero"
else
  pass "ultra without opt-in exits nonzero"
fi
assert_output_contains "ultra rejection explains the experimental Sol-only opt-in" "experimental" "$ultra_error"
assert_output_contains "ultra rejection includes the token and timeout guardrail" "XT_TIMEOUT is the hard backstop" "$ultra_error"
if terra_ultra_error="$(XT_ULTRA_OPTIN=1 run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_ULTRA" --model gpt-5.6-terra --effort ultra 2>&1)"; then
  fail "ultra rejects a non-Sol model even with opt-in"
else
  pass "ultra rejects a non-Sol model even with opt-in"
fi
assert_output_contains "non-Sol ultra rejection identifies the Sol-only rule" "Sol-only" "$terra_ultra_error"
if ultra_success="$(XT_ULTRA_OPTIN=1 run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_ULTRA" --model gpt-5.6-sol --effort ultra 2>&1)"; then
  pass "ultra with Sol and opt-in succeeds"
else
  fail "ultra with Sol and opt-in succeeds"
fi

# (e) Scope enforcement must run before commit: red violation then green commit.
: > "$ARGV_FILE"
if scope_output="$(run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_SCOPE" --context-dir src 2>&1)"; then
  pass "out-of-scope change is handled without failing the adapter"
else
  fail "out-of-scope change is handled without failing the adapter"
fi
if [[ ! -e "$WORKTREE/outside.txt" ]]; then
  pass "out-of-scope file is reverted"
else
  fail "out-of-scope file is reverted"
fi
if [[ -f "$WORKTREE/src/in-scope.txt" ]] && git -C "$WORKTREE" show --format= --name-only HEAD | grep -Fqx 'src/in-scope.txt'; then
  pass "in-scope change survives and is committed"
else
  fail "in-scope change survives and is committed"
fi
assert_output_contains "scope violation is reported" "scope_violation" "$scope_output"
if green_output="$(run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_GREEN" --context-dir src 2>&1)"; then
  pass "in-scope-only change succeeds"
else
  fail "in-scope-only change succeeds"
fi
if [[ -f "$WORKTREE/src/green.txt" ]] && git -C "$WORKTREE" show --format= --name-only HEAD | grep -Fqx 'src/green.txt'; then
  pass "in-scope-only change is committed"
else
  fail "in-scope-only change is committed"
fi
if grep -Fq 'scope_violation' <<< "$green_output"; then
  fail "in-scope-only change does not report a scope violation"
else
  pass "in-scope-only change does not report a scope violation"
fi

# A staging or commit error must not be reported as a successful implementation.
COMMIT_FAILURE_WORKTREE="$TMP_DIR/commit-failure-worktree"
mkdir -p "$COMMIT_FAILURE_WORKTREE/src"
git -C "$COMMIT_FAILURE_WORKTREE" init -q
git -C "$COMMIT_FAILURE_WORKTREE" config user.name "Fixture Author"
git -C "$COMMIT_FAILURE_WORKTREE" config user.email "fixture-author@example.invalid"
printf 'base\n' > "$COMMIT_FAILURE_WORKTREE/src/base.txt"
git -C "$COMMIT_FAILURE_WORKTREE" add src/base.txt
git -C "$COMMIT_FAILURE_WORKTREE" commit -qm "initial fixture"
git -C "$COMMIT_FAILURE_WORKTREE" config --unset user.name
git -C "$COMMIT_FAILURE_WORKTREE" config --unset user.email
commit_failure_base="$(git -C "$COMMIT_FAILURE_WORKTREE" rev-parse HEAD)"
if commit_failure_output="$(GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null run_adapter implement --worktree "$COMMIT_FAILURE_WORKTREE" --prompt-file "$PROMPT_GREEN" --context-dir src 2>&1)"; then
  fail "commit failure exits nonzero"
else
  pass "commit failure exits nonzero"
fi
assert_output_contains "commit failure is explained" "failed to commit scope-checked changes" "$commit_failure_output"
if [[ "$(git -C "$COMMIT_FAILURE_WORKTREE" rev-parse HEAD)" == "$commit_failure_base" ]]; then
  pass "commit failure leaves HEAD unchanged"
else
  fail "commit failure leaves HEAD unchanged"
fi

# (f) Model availability failures are distinguished for escalation.
: > "$ARGV_FILE"
if unavailable_output="$(run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_UNAVAILABLE" 2>&1)"; then
  fail "model-unavailable invocation exits nonzero"
else
  pass "model-unavailable invocation exits nonzero"
fi
assert_output_contains "model-unavailable error has a distinct code" "model_unavailable" "$unavailable_output"
if unavailable_jsonl_output="$(run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_UNAVAILABLE_JSONL" 2>&1)"; then
  fail "JSONL model-unavailable invocation exits nonzero"
else
  pass "JSONL model-unavailable invocation exits nonzero"
fi
assert_output_contains "JSONL model-unavailable error has a distinct code" "model_unavailable" "$unavailable_jsonl_output"

# (g) Session logs are private, and embedded raw log content is bounded.
: > "$ARGV_FILE"
if large_output="$(run_adapter implement --worktree "$WORKTREE" --prompt-file "$PROMPT_LARGE" 2>&1)"; then
  pass "large-log implement invocation succeeds"
else
  fail "large-log implement invocation succeeds"
fi
LOG_DIR="$TEST_HOME/.claude/sessions"
if [[ "$(stat -c '%a' "$LOG_DIR")" == "700" ]]; then
  pass "session directory is mode 700"
else
  fail "session directory is mode 700"
fi
if [[ "$(stat -c '%a' "$LOG_DIR/external-tools.jsonl")" == "600" ]]; then
  pass "structured session log is mode 600"
else
  fail "structured session log is mode 600"
fi
if raw_log="$(find "$LOG_DIR" -maxdepth 1 -name 'codex-implement-*.jsonl' -print -quit)" && [[ -n "$raw_log" ]] && [[ "$(stat -c '%a' "$raw_log")" == "600" ]]; then
  pass "raw Codex session log is mode 600"
else
  fail "raw Codex session log is mode 600"
fi
if grep -Eq '"truncated"[[:space:]]*:[[:space:]]*true' <<< "$large_output"; then
  pass "embedded raw log is marked truncated"
else
  fail "embedded raw log is marked truncated"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
