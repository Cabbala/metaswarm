#!/usr/bin/env bash
# Classify review feedback that is outside the current pull-request diff.
#
# Derived contract (call sites inspected before implementation):
# - skills/handling-pr-comments/SKILL.md:89 and :312 invoke this script as
#   bin/pr-comments-out-of-scope.sh <PR_NUMBER>.
# - Its Phase 2c defines the three classifications: comments on lines outside
#   the diff, comments with GitHub's GraphQL isOutdated flag, and general PR
#   discussion comments. commands/handle-pr-comments.md requires all such
#   comments to be handled but has no direct invocation.
# - For deterministic, CI-safe use, provide a JSON array or {"comments":[...]}
#   on stdin, or select an equivalent JSON file with --file <path>. The script
#   emits {"verdicts":[...]} JSON. Each verdict has id, out_of_scope, reasons,
#   and a compact comment summary. <PR_NUMBER> fetches the same data with gh
#   for the existing runtime call site; it is mutually exclusive with --file.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bin/pr-comments-out-of-scope.sh [--file <comments.json> | <PR_NUMBER>]

Input (stdin by default) must be a JSON array of comments or an object with a
comments array. A comment is out of scope when any of these is true:
  - in_diff/inDiff is false, or a supplied REST position is null
  - isOutdated/outdated is true
  - source, kind, or type is "general"

Options:
  --file <path>  Read JSON comments from a file
  -h, --help     Show this help text
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die 'jq is required to classify JSON comments'
}

read_pr_comments() {
  local pr_number="$1"
  local owner repo inline general threads inline_json general_json outdated_ids

  command -v gh >/dev/null 2>&1 || die 'GitHub CLI (gh) is required for PR-number mode'
  [[ "$pr_number" =~ ^[1-9][0-9]*$ ]] || die 'PR_NUMBER must be a positive integer'

  owner="$(gh repo view --json owner -q '.owner.login')" || die 'could not determine repository owner'
  repo="$(gh repo view --json name -q '.name')" || die 'could not determine repository name'
  inline="$(gh api --paginate "repos/$owner/$repo/pulls/$pr_number/comments")" || die 'could not fetch inline review comments'
  general="$(gh api --paginate "repos/$owner/$repo/issues/$pr_number/comments")" || die 'could not fetch general PR discussion comments'
  threads="$(gh api graphql \
    -f query='query($owner: String!, $repo: String!, $number: Int!) { repository(owner: $owner, name: $repo) { pullRequest(number: $number) { reviewThreads(first: 100) { nodes { isOutdated comments(first: 100) { nodes { databaseId } } } } } } }' \
    -F owner="$owner" -F repo="$repo" -F number="$pr_number")" || die 'could not fetch review-thread freshness'

  inline_json="$(printf '%s\n' "$inline" | jq -ces 'add // []')" || die 'could not parse inline review comments'
  general_json="$(printf '%s\n' "$general" | jq -ces 'add // []')" || die 'could not parse general PR discussion comments'
  outdated_ids="$(printf '%s\n' "$threads" | jq -ce '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isOutdated) | .comments.nodes[].databaseId]')" || die 'could not parse review-thread freshness'

  jq -cn \
    --argjson inline "$inline_json" \
    --argjson general "$general_json" \
    --argjson outdated_ids "$outdated_ids" \
    '{comments: ((($inline | map(. + {source: "inline"})) + ($general | map(. + {source: "general"}))) | map(if (.id as $id | $outdated_ids | index($id)) then . + {isOutdated: true} else . end))}'
}

input_file=''
pr_number=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      [[ $# -ge 2 ]] || die '--file requires a path'
      [[ -z "$input_file" ]] || die '--file may be specified only once'
      input_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      [[ -z "$pr_number" ]] || die "unexpected argument: $1"
      pr_number="$1"
      shift
      ;;
  esac
done

[[ -z "$input_file" || -z "$pr_number" ]] || die '--file and PR_NUMBER cannot be used together'
require_jq

if [[ -n "$input_file" ]]; then
  [[ -f "$input_file" ]] || die "comments file not found: $input_file"
  input_json="$(<"$input_file")"
elif [[ -n "$pr_number" ]]; then
  input_json="$(read_pr_comments "$pr_number")"
else
  input_json="$(cat)"
fi

comments="$(printf '%s\n' "$input_json" | jq -ce '
  if type == "array" then .
  elif type == "object" and (.comments | type == "array") then .comments
  else error("expected a JSON array or an object with a comments array")
  end
  | map(if type == "object" then . else error("each comment must be an object") end)
')" || die 'comments input must be valid JSON in the documented shape'

jq -cn --argjson comments "$comments" '
  def is_general:
    (.source? == "general") or (.kind? == "general") or (.type? == "general");
  def is_outdated:
    (.isOutdated? == true) or (.outdated? == true);
  def is_not_in_diff:
    (.in_diff? == false) or (.inDiff? == false) or
    ((has("position") and .position == null) and (is_general | not));
  {
    verdicts: [
      $comments[] |
      . as $comment |
      [
        if is_not_in_diff then "not_in_diff" else empty end,
        if is_outdated then "outdated" else empty end,
        if is_general then "general_discussion" else empty end
      ] as $reasons |
      {
        id: ($comment.id // null),
        out_of_scope: ($reasons | length > 0),
        reasons: $reasons,
        comment: {
          body: ($comment.body // null),
          path: ($comment.path // null),
          line: ($comment.line // $comment.original_line // null),
          source: ($comment.source // $comment.kind // $comment.type // "inline")
        }
      }
    ]
  }
'
