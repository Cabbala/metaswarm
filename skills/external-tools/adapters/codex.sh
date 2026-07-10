#!/bin/bash
# codex.sh — OpenAI Codex CLI adapter for external-tools
#
# Commands:
#   health     Preflight check: binary exists, version, auth status
#   implement  Write code on a worktree branch via a workspace-write sandbox
#   review     Review code changes (read-only sandbox) against a rubric/spec
#
# Usage:
#   codex.sh health
#   codex.sh implement --worktree <path> --prompt-file <path> [--model <slug>] [--effort <level>] [--allow-network]
#   codex.sh review   --worktree <path> --rubric-file <path> --spec-file <path> [--model <slug>] [--effort <level>]

set -euo pipefail

# ---------------------------------------------------------------------------
# Source shared helpers
# ---------------------------------------------------------------------------
source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
TOOL_NAME="codex"
TOOL_CMD="codex"
DEFAULT_EFFORT="xhigh"
REVIEW_DEFAULT_MODEL="gpt-5.6-sol"

# The implementation model is intentionally distinct from the review default.
DEFAULT_MODEL="gpt-5.6-terra"

validate_ultra_effort() {
  local model="${1:?validate_ultra_effort: model required}"
  local effort="${2:?validate_ultra_effort: effort required}"

  if [[ "$effort" == "ultra" ]] && { [[ "$model" != "gpt-5.6-sol" ]] || [[ "${XT_ULTRA_OPTIN:-}" != "1" ]]; }; then
    printf 'Error: ultra reasoning effort is experimental, Sol-only (MODEL=gpt-5.6-sol), and requires XT_ULTRA_OPTIN=1 (~2-3x tokens; XT_TIMEOUT is the hard backstop).\n' >&2
    return 2
  fi
}

codex_error_code() {
  local stderr_file="${1:-}"
  local stdout_file="${2:-}"
  local pattern='model.*(not[[:space:]_-]*found|unavailable|does[[:space:]_-]*not[[:space:]_-]*exist|unsupported)|unknown[[:space:]_-]*model|no[[:space:]_-]*such[[:space:]_-]*model'

  if grep -Eqi "$pattern" "$stderr_file" "$stdout_file" 2>/dev/null; then
    printf 'model_unavailable'
  else
    printf 'tool_error'
  fi
}

# ===========================================================================
# health — Preflight check
# ===========================================================================
cmd_health() {
  parse_args "$@"

  local status="ready"
  local version="unknown"
  local auth_valid=false
  local model="${MODEL:-$DEFAULT_MODEL}"

  # Check if codex binary exists
  if ! command -v "$TOOL_CMD" >/dev/null 2>&1; then
    printf '{"tool":"%s","status":"unavailable","version":"not_installed","auth_valid":false,"model":"%s"}\n' \
      "$TOOL_NAME" "$model"
    return 0
  fi

  # Get version
  version="$("$TOOL_CMD" --version 2>/dev/null || printf 'unknown')"
  # Trim whitespace
  version="$(printf '%s' "$version" | tr -d '\n' | xargs)"

  # Check auth: try `codex login status` first, then fall back to env vars
  if "$TOOL_CMD" login status >/dev/null 2>&1; then
    auth_valid=true
  elif [[ -n "${OPENAI_API_KEY:-}" || -n "${CODEX_API_KEY:-}" ]]; then
    auth_valid=true
  fi

  if [[ "$auth_valid" == "false" ]]; then
    status="unavailable"
  fi

  # Emit JSON — use jq if available for proper escaping, else manual
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg tool "$TOOL_NAME" \
      --arg status "$status" \
      --arg version "$version" \
      --argjson auth_valid "$auth_valid" \
      --arg model "$model" \
      '{tool: $tool, status: $status, version: $version, auth_valid: $auth_valid, model: $model}'
  else
    printf '{"tool":"%s","status":"%s","version":"%s","auth_valid":%s,"model":"%s"}\n' \
      "$TOOL_NAME" "$status" "$version" "$auth_valid" "$model"
  fi
}

# ===========================================================================
# implement — Write code on a worktree branch
# ===========================================================================
cmd_implement() {
  parse_args "$@"
  MODEL="${MODEL:-$DEFAULT_MODEL}"
  EFFORT="${EFFORT:-$DEFAULT_EFFORT}"

  validate_ultra_effort "$MODEL" "$EFFORT" || return $?

  # Validate required arguments
  if [[ -z "$XT_WORKTREE" ]]; then
    printf 'Error: --worktree is required for implement\n' >&2
    return 1
  fi
  if [[ -z "$XT_PROMPT_FILE" ]]; then
    printf 'Error: --prompt-file is required for implement\n' >&2
    return 1
  fi
  if [[ ! -d "$XT_WORKTREE" ]]; then
    printf 'Error: worktree directory does not exist: %s\n' "$XT_WORKTREE" >&2
    return 1
  fi
  if [[ ! -f "$XT_PROMPT_FILE" ]]; then
    printf 'Error: prompt file does not exist: %s\n' "$XT_PROMPT_FILE" >&2
    return 1
  fi

  local base_sha
  base_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD)"

  # Create secure tmp dir for capturing output
  local tmp_dir
  tmp_dir="$(create_secure_tmp)"
  local stdout_file="${tmp_dir}/stdout.jsonl"
  local stderr_file="${tmp_dir}/stderr.log"

  # Read prompt file content
  local prompt_content
  prompt_content="$(cat "$XT_PROMPT_FILE")"

  # Record start time
  local start_time
  start_time="$(date +%s)"

  # Invoke codex with minimal environment
  local exit_code=0
  local -a codex_args=(
    exec
    -c "model=${MODEL}"
    -c "model_reasoning_effort=${EFFORT}"
    --sandbox workspace-write
  )
  if [[ "$XT_ALLOW_NETWORK" != "1" ]]; then
    codex_args+=(-c "sandbox_workspace_write.network_access=false")
  fi
  codex_args+=(--json -C "$XT_WORKTREE" "$prompt_content")
  safe_invoke "$XT_TIMEOUT" "$stdout_file" "$stderr_file" \
    env -i \
      HOME="$HOME" \
      PATH="$PATH" \
      OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
      CODEX_API_KEY="${CODEX_API_KEY:-}" \
    "$TOOL_CMD" "${codex_args[@]}" \
    || exit_code=$?

  # Calculate duration
  local end_time
  end_time="$(date +%s)"
  local duration=$(( end_time - start_time ))

  # Save raw output to LOG_DIR
  mkdir -p "$LOG_DIR"
  chmod 700 "$LOG_DIR"
  local session_id
  session_id="${TOOL_NAME}-implement-$(date +%Y%m%dT%H%M%S)-$$"
  local raw_log_file="${LOG_DIR}/${session_id}.jsonl"
  if [[ -f "$stdout_file" ]]; then
    cp "$stdout_file" "$raw_log_file"
    chmod 600 "$raw_log_file"
  fi

  # Handle error
  if [[ "$exit_code" -ne 0 ]]; then
    local error_code
    error_code="$(codex_error_code "$stderr_file" "$stdout_file")"

    # Log and emit error
    local error_json
    error_json="$(emit_error \
      "$TOOL_NAME" \
      "implement" \
      "$MODEL" \
      "$XT_ATTEMPT" \
      "$exit_code" \
      "$stderr_file" \
      "$duration" \
      "$raw_log_file" \
      "$error_code")"
    log_session "$error_json"
    printf '%s\n' "$error_json"

    # Cleanup tmp
    rm -rf "$tmp_dir"
    return 1
  fi

  # Verify scope before staging so a rejected file cannot enter a commit.
  local branch=""
  local git_sha=""
  local scope_error_type=""
  local scope_status=0

  if [[ -d "$XT_WORKTREE" ]]; then
    # Verify scope against the pre-invocation commit, including untracked files.
    if [[ -n "$XT_CONTEXT_DIR" ]]; then
      verify_scope "$XT_WORKTREE" "$XT_CONTEXT_DIR" "$base_sha" || scope_status=$?
      if [[ "$scope_status" -eq 1 ]]; then
        scope_error_type="scope_violation"
      elif [[ "$scope_status" -ne 0 ]]; then
        printf 'Error: scope enforcement failed; changes were not staged.\n' >&2
        rm -rf "$tmp_dir"
        return "$scope_status"
      fi
    fi

    # Stage and commit only the scope-checked worktree changes.
    if ! git -C "$XT_WORKTREE" add -A; then
      printf 'Error: failed to stage scope-checked changes.\n' >&2
      rm -rf "$tmp_dir"
      return 1
    fi
    if ! git -C "$XT_WORKTREE" diff --cached --quiet 2>/dev/null; then
      if ! git -C "$XT_WORKTREE" commit -m "feat: codex implement (attempt ${XT_ATTEMPT})" \
        --author="Codex CLI <codex@openai.com>"; then
        printf 'Error: failed to commit scope-checked changes.\n' >&2
        rm -rf "$tmp_dir"
        return 1
      fi
    fi

    # Capture branch and SHA
    branch="$(git -C "$XT_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  fi

  # Extract cost/stats
  local cost_json
  cost_json="$(extract_cost_codex "$stdout_file")"

  local files_changed_json
  files_changed_json="$(get_changed_files "$XT_WORKTREE")"

  local diff_stats_json
  diff_stats_json="$(get_diff_stats "$XT_WORKTREE")"

  # Emit structured output
  local result_json
  result_json="$(emit_json \
    "$TOOL_NAME" \
    "implement" \
    "$MODEL" \
    "$XT_ATTEMPT" \
    "$exit_code" \
    "$branch" \
    "$git_sha" \
    "$files_changed_json" \
    "$diff_stats_json" \
    "$duration" \
    "$cost_json" \
    "$raw_log_file" \
    "$scope_error_type")"

  log_session "$result_json"
  printf '%s\n' "$result_json"

  # Cleanup tmp
  rm -rf "$tmp_dir"
}

# ===========================================================================
# review — Review code changes (read-only)
# ===========================================================================
cmd_review() {
  parse_args "$@"
  MODEL="${MODEL:-$REVIEW_DEFAULT_MODEL}"
  EFFORT="${EFFORT:-$DEFAULT_EFFORT}"

  validate_ultra_effort "$MODEL" "$EFFORT" || return $?

  # Validate required arguments
  if [[ -z "$XT_WORKTREE" ]]; then
    printf 'Error: --worktree is required for review\n' >&2
    return 1
  fi
  if [[ -z "$XT_RUBRIC_FILE" ]]; then
    printf 'Error: --rubric-file is required for review\n' >&2
    return 1
  fi
  if [[ -z "$XT_SPEC_FILE" ]]; then
    printf 'Error: --spec-file is required for review\n' >&2
    return 1
  fi
  if [[ ! -d "$XT_WORKTREE" ]]; then
    printf 'Error: worktree directory does not exist: %s\n' "$XT_WORKTREE" >&2
    return 1
  fi
  if [[ ! -f "$XT_RUBRIC_FILE" ]]; then
    printf 'Error: rubric file does not exist: %s\n' "$XT_RUBRIC_FILE" >&2
    return 1
  fi
  if [[ ! -f "$XT_SPEC_FILE" ]]; then
    printf 'Error: spec file does not exist: %s\n' "$XT_SPEC_FILE" >&2
    return 1
  fi

  # Create secure tmp dir
  local tmp_dir
  tmp_dir="$(create_secure_tmp)"
  local stdout_file="${tmp_dir}/stdout.jsonl"
  local stderr_file="${tmp_dir}/stderr.log"

  # Build review prompt from git diff + rubric + spec
  local diff_content
  diff_content="$(git -C "$XT_WORKTREE" diff HEAD 2>/dev/null || true)"
  if [[ -z "$diff_content" ]]; then
    # If no unstaged diff, try staged diff or diff against parent
    diff_content="$(git -C "$XT_WORKTREE" diff HEAD~1 HEAD 2>/dev/null || true)"
  fi

  local rubric_content
  rubric_content="$(cat "$XT_RUBRIC_FILE")"

  local spec_content
  spec_content="$(cat "$XT_SPEC_FILE")"

  local review_prompt
  review_prompt="$(cat <<'PROMPT_TEMPLATE'
You are a code reviewer. Review the following code changes against the provided rubric and specification.

## Git Diff
PROMPT_TEMPLATE
)"
  review_prompt+=$'\n```diff\n'"${diff_content}"$'\n```\n'
  review_prompt+=$'\n## Review Rubric\n'"${rubric_content}"$'\n'
  review_prompt+=$'\n## Specification\n'"${spec_content}"$'\n'
  review_prompt+="$(cat <<'PROMPT_FOOTER'

## Instructions
1. Evaluate each criterion in the rubric against the diff and spec.
2. For each finding, provide:
   - Verdict: PASS or FAIL
   - Classification: BLOCKING or WARNING
   - Citation: file:line reference(s)
   - Explanation: why the finding was made
3. At the end, provide an overall verdict: PASS or FAIL.
   - FAIL if any BLOCKING issue is found.
   - PASS if only WARNING issues or no issues.
4. Output your review as structured JSON with keys: "verdict", "findings" (array), "summary".
PROMPT_FOOTER
)"

  # Record start time
  local start_time
  start_time="$(date +%s)"

  # Invoke codex in read-only sandbox mode
  local exit_code=0
  safe_invoke "$XT_TIMEOUT" "$stdout_file" "$stderr_file" \
    env -i \
      HOME="$HOME" \
      PATH="$PATH" \
      OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
      CODEX_API_KEY="${CODEX_API_KEY:-}" \
    "$TOOL_CMD" exec \
      -c "model=${MODEL}" \
      -c "model_reasoning_effort=${EFFORT}" \
      --sandbox read-only \
      --json -C "$XT_WORKTREE" "$review_prompt" \
    || exit_code=$?

  # Calculate duration
  local end_time
  end_time="$(date +%s)"
  local duration=$(( end_time - start_time ))

  # Save raw output to LOG_DIR
  mkdir -p "$LOG_DIR"
  chmod 700 "$LOG_DIR"
  local session_id
  session_id="${TOOL_NAME}-review-$(date +%Y%m%dT%H%M%S)-$$"
  local raw_log_file="${LOG_DIR}/${session_id}.jsonl"
  if [[ -f "$stdout_file" ]]; then
    cp "$stdout_file" "$raw_log_file"
    chmod 600 "$raw_log_file"
  fi

  # Handle error
  if [[ "$exit_code" -ne 0 ]]; then
    local error_code
    error_code="$(codex_error_code "$stderr_file" "$stdout_file")"
    local error_json
    error_json="$(emit_error \
      "$TOOL_NAME" \
      "review" \
      "$MODEL" \
      "$XT_ATTEMPT" \
      "$exit_code" \
      "$stderr_file" \
      "$duration" \
      "$raw_log_file" \
      "$error_code")"
    log_session "$error_json"
    printf '%s\n' "$error_json"

    # Cleanup tmp
    rm -rf "$tmp_dir"
    return 1
  fi

  # Extract cost
  local cost_json
  cost_json="$(extract_cost_codex "$stdout_file")"

  # For review, capture branch/sha for context but no file changes expected
  local branch=""
  local git_sha=""
  if [[ -d "$XT_WORKTREE" ]]; then
    branch="$(git -C "$XT_WORKTREE" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    git_sha="$(git -C "$XT_WORKTREE" rev-parse HEAD 2>/dev/null || true)"
  fi

  # Emit structured output
  local result_json
  result_json="$(emit_json \
    "$TOOL_NAME" \
    "review" \
    "$MODEL" \
    "$XT_ATTEMPT" \
    "$exit_code" \
    "$branch" \
    "$git_sha" \
    "[]" \
    '{"additions": 0, "deletions": 0}' \
    "$duration" \
    "$cost_json" \
    "$raw_log_file")"

  log_session "$result_json"
  printf '%s\n' "$result_json"

  # Cleanup tmp
  rm -rf "$tmp_dir"
}

# ===========================================================================
# Command dispatch
# ===========================================================================
command="${1:-}"
shift || true

case "$command" in
  health)
    cmd_health "$@"
    ;;
  implement)
    cmd_implement "$@"
    ;;
  review)
    cmd_review "$@"
    ;;
  *)
    cat >&2 <<USAGE
Usage: $(basename "$0") <command> [options]

Commands:
  health      Check if Codex CLI is installed, authenticated, and ready
  implement   Run Codex in a workspace-write sandbox to implement changes
  review      Run Codex in read-only sandbox to review code changes

Options (implement):
  --worktree <path>       Path to the git worktree (required)
  --prompt-file <path>    Path to the prompt file (required)
  --attempt <N>           Attempt number (default: 1)
  --timeout <seconds>     Timeout in seconds (default: 300)
  --context-dir <dir>     Restrict changes to this directory
  --model <slug>          Codex model (default: gpt-5.6-terra)
  --effort <level>        Model reasoning effort (default: xhigh)
  --allow-network         Allow network access in the workspace-write sandbox

Options (review):
  --worktree <path>       Path to the git worktree (required)
  --rubric-file <path>    Path to the review rubric file (required)
  --spec-file <path>      Path to the specification file (required)
  --attempt <N>           Attempt number (default: 1)
  --timeout <seconds>     Timeout in seconds (default: 300)
  --model <slug>          Codex model (default: gpt-5.6-sol)
  --effort <level>        Model reasoning effort (default: xhigh)

Environment variables:
  OPENAI_API_KEY          OpenAI API key for authentication
  CODEX_API_KEY           Codex-specific API key (alternative)
  XT_MODEL                Default model when --model is omitted
  XT_EFFORT               Default reasoning effort when --effort is omitted
  XT_ALLOW_NETWORK=1      Allow network access for implement runs
  XT_ULTRA_OPTIN=1        Required with --effort ultra (experimental Sol-only mode)
USAGE
    exit 1
    ;;
esac
