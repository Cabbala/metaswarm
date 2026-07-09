#!/usr/bin/env bash
# Create a pull request and print the required PR-shepherd handoff.
#
# Derived contract (call sites inspected before implementation):
# - agents/issue-orchestrator.md:359 and its runtime copy at
#   skills/start/agents/issue-orchestrator.md:359 invoke
#   --title <title> --body <body> --base main.
# - skills/pr-shepherd/SKILL.md:32-36 and skills/start/SKILL.md:397-405
#   require a successful invocation to tell the orchestrator to run
#   /pr-shepherd <pr-number>.
# - --title and --body are required; --base defaults to main; --draft and
#   --no-shepherd are optional. --dry-run prints the exact gh command without
#   invoking gh and prints the handoff unless --no-shepherd was requested.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bin/create-pr-with-shepherd.sh --title <title> --body <body> [options]

Options:
  --base <branch>  Base branch for the pull request (default: main)
  --draft          Create the pull request as a draft
  --no-shepherd    Create the PR without printing the pr-shepherd handoff
  --dry-run        Print the gh command and shepherd handoff without running gh
  -h, --help       Show this help text
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

default_branch() {
  local remote_head head_branch

  if remote_head="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)"; then
    printf '%s\n' "${remote_head#origin/}"
  elif ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    head_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -n "$head_branch" ]]; then
      printf '%s\n' "$head_branch"
    else
      git config --get init.defaultBranch 2>/dev/null || printf '%s\n' 'main'
    fi
  elif git show-ref --verify --quiet refs/heads/main; then
    printf '%s\n' 'main'
  elif git show-ref --verify --quiet refs/heads/master; then
    printf '%s\n' 'master'
  else
    git config --get init.defaultBranch 2>/dev/null || printf '%s\n' 'main'
  fi
}

print_shepherd_instruction() {
  local pr_number="$1"

  cat <<EOF

Next step: start PR monitoring with the pr-shepherd skill:
  /pr-shepherd $pr_number
EOF
}

title=''
body=''
base='main'
draft=false
no_shepherd=false
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      [[ $# -ge 2 ]] || die '--title requires a value'
      title="$2"
      shift 2
      ;;
    --body)
      [[ $# -ge 2 ]] || die '--body requires a value'
      body="$2"
      shift 2
      ;;
    --base)
      [[ $# -ge 2 ]] || die '--base requires a value'
      base="$2"
      shift 2
      ;;
    --draft)
      draft=true
      shift
      ;;
    --no-shepherd)
      no_shepherd=true
      shift
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$title" ]] || die '--title is required'
[[ -n "$body" ]] || die '--body is required'
[[ -n "$base" ]] || die '--base must not be empty'

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die 'must run inside a git work tree'
current_branch="$(git branch --show-current)"
[[ -n "$current_branch" ]] || die 'must run from a named branch, not detached HEAD'

repo_default_branch="$(default_branch)"
if [[ "$current_branch" == "$repo_default_branch" ]]; then
  die "refusing to create a PR from the default branch '$repo_default_branch'"
fi

# Pin the target repository to origin. On a fork, bare `gh pr create` targets the
# PARENT repository — a cross-repo PR nobody asked for. Deriving --repo from the
# origin remote guarantees the PR lands on the repo this branch was pushed to.
origin_slug="$(git remote get-url origin | sed -E 's#(git@github\.com:|https://github\.com/)##; s#\.git$##')"
[ -n "$origin_slug" ] || die 'cannot derive origin repository slug'
gh_command=(gh pr create --repo "$origin_slug" --title "$title" --body "$body" --base "$base")
if [[ "$draft" == true ]]; then
  gh_command+=(--draft)
fi

if [[ "$dry_run" == true ]]; then
  printf 'Dry run — would execute:'
  printf ' %q' "${gh_command[@]}"
  printf '\n'
  if [[ "$no_shepherd" == false ]]; then
    print_shepherd_instruction '<pr-number>'
  fi
  exit 0
fi

command -v gh >/dev/null 2>&1 || die 'GitHub CLI (gh) is required'
pr_url="$("${gh_command[@]}")" || die 'gh pr create failed'
pr_number="$(sed -nE 's#^.*/([0-9]+)/?$#\1#p' <<<"$pr_url")"
[[ -n "$pr_number" ]] || die "created PR but could not parse its number from gh output: $pr_url"

echo "PR created: #$pr_number"
echo "URL: $pr_url"
if [[ "$no_shepherd" == false ]]; then
  print_shepherd_instruction "$pr_number"
fi
