#!/usr/bin/env bash
# Behavioral tests for the PR helper scripts. These tests use dry-run and local
# fixtures only; they never invoke gh or make network calls.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CREATE_PR="$ROOT/bin/create-pr-with-shepherd.sh"
OUT_OF_SCOPE="$ROOT/bin/pr-comments-out-of-scope.sh"
PASS=0
FAIL=0
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

echo "PR helper script tests"
echo "======================"

named_branch_repo="$TMP_DIR/named-branch"
git -c init.defaultBranch=main init --initial-branch=main -q "$named_branch_repo"
git -C "$named_branch_repo" -c user.name='PR Helper Test' -c user.email='pr-helper@example.invalid' \
  commit --allow-empty -qm 'fixture root'
(
  cd "$named_branch_repo"
  git checkout -q -b pr-helper-tests
  # the script derives --repo from origin; give the fixture a fake one
  git remote add origin 'git@github.com:fixture-owner/fixture-repo.git'
)

run_create_pr_dry_run() {
  (
    cd "$named_branch_repo"
    "$CREATE_PR" "$@"
  )
}

dry_run_output="$(run_create_pr_dry_run --dry-run --title "Dry run title" --body "Dry run body" --base release 2>&1)" || {
  fail "create-pr dry run succeeds"
  dry_run_output=""
}
if [[ -n "$dry_run_output" ]]; then
  pass "create-pr dry run succeeds"
fi
if grep -Fq -- 'gh pr create --repo fixture-owner/fixture-repo --title Dry\ run\ title --body Dry\ run\ body --base release' <<<"$dry_run_output"; then
  pass "dry run prints the exact gh title, body, and base command"
else
  fail "dry run prints the exact gh title, body, and base command"
fi
if grep -Fq -- '/pr-shepherd <pr-number>' <<<"$dry_run_output"; then
  pass "dry run prints the shepherd handoff instruction"
else
  fail "dry run prints the shepherd handoff instruction"
fi

if run_create_pr_dry_run --dry-run --body "Missing title" >/dev/null 2>&1; then
  fail "missing --title exits nonzero"
else
  pass "missing --title exits nonzero"
fi

default_branch_repo="$TMP_DIR/default-branch"
git -c init.defaultBranch=master init --initial-branch=main -q "$default_branch_repo"
if (
  cd "$default_branch_repo"
  "$CREATE_PR" --dry-run --title "Blocked" --body "Must not create from main"
) >"$TMP_DIR/default-branch.out" 2>&1; then
  fail "default-branch guard exits nonzero"
else
  pass "default-branch guard exits nonzero"
fi
if grep -qi 'default branch' "$TMP_DIR/default-branch.out"; then
  pass "default-branch guard explains the refusal"
else
  fail "default-branch guard explains the refusal"
fi

draft_output="$(run_create_pr_dry_run --dry-run --draft --title "Draft" --body "Draft body" 2>&1)" || draft_output=""
if [[ -n "$draft_output" ]] && grep -Fq -- ' --draft' <<<"$draft_output"; then
  pass "--draft dry run succeeds and adds the gh draft flag"
else
  fail "--draft dry run succeeds and adds the gh draft flag"
fi

no_shepherd_output="$(run_create_pr_dry_run --dry-run --no-shepherd --title "Deferred" --body "Monitor later" 2>&1)" || no_shepherd_output=""
if [[ -n "$no_shepherd_output" ]] && ! grep -Fq -- '/pr-shepherd' <<<"$no_shepherd_output"; then
  pass "--no-shepherd suppresses the shepherd handoff"
else
  fail "--no-shepherd suppresses the shepherd handoff"
fi

in_scope_output="$(printf '%s\n' '[{"id": 1, "body": "Fix the changed line", "path": "bin/helper.sh", "line": 8, "in_diff": true, "isOutdated": false, "source": "inline"}]' | "$OUT_OF_SCOPE" 2>&1)" || {
  fail "stdin JSON classification succeeds"
  in_scope_output=""
}
if [[ -n "$in_scope_output" ]]; then
  pass "stdin JSON classification succeeds"
fi
if jq -e '.verdicts | length == 1 and .[0].id == 1 and .[0].out_of_scope == false and .[0].reasons == []' <<<"$in_scope_output" >/dev/null; then
  pass "in-scope inline comment is not flagged"
else
  fail "in-scope inline comment is not flagged"
fi

cat >"$TMP_DIR/out-of-scope.json" <<'EOF'
{
  "comments": [
    {"id": 2, "body": "This line is no longer in the diff", "path": "lib/old.js", "line": 17, "in_diff": false, "isOutdated": false, "source": "inline"},
    {"id": 3, "body": "This review thread is outdated", "path": "lib/current.js", "line": 4, "in_diff": true, "isOutdated": true, "source": "inline"},
    {"id": 4, "body": "General PR discussion", "source": "general"}
  ]
}
EOF

out_of_scope_output="$("$OUT_OF_SCOPE" --file "$TMP_DIR/out-of-scope.json" 2>&1)" || {
  fail "--file JSON classification succeeds"
  out_of_scope_output=""
}
if [[ -n "$out_of_scope_output" ]]; then
  pass "--file JSON classification succeeds"
fi
if jq -e '
  .verdicts | length == 3
  and (map(select(.id == 2)) | .[0].out_of_scope == true and .[0].reasons == ["not_in_diff"])
  and (map(select(.id == 3)) | .[0].out_of_scope == true and .[0].reasons == ["outdated"])
  and (map(select(.id == 4)) | .[0].out_of_scope == true and .[0].reasons == ["general_discussion"])
' <<<"$out_of_scope_output" >/dev/null; then
  pass "off-diff, outdated, and general comments are flagged with reasons"
else
  fail "off-diff, outdated, and general comments are flagged with reasons"
fi

if printf '%s\n' '{not valid json' | "$OUT_OF_SCOPE" >"$TMP_DIR/malformed.out" 2>&1; then
  fail "malformed JSON exits nonzero"
else
  pass "malformed JSON exits nonzero"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
