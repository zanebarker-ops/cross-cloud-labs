#!/usr/bin/env bash
# Claude Code PreToolUse hook (matcher: Bash).
#
# Blocks `git commit` and `git push` when the current branch is `main` or
# `master`, enforcing the cross-cloud-labs project rule "never push to
# main; PR-only workflow" (see .claude/CLAUDE.md).
#
# Backstop for the gap in the settings.json `deny` list: bare `git push`
# resolves to the current branch's tracking ref at runtime and so does
# not match the literal pattern `git push origin main*`. This hook reads
# the live branch via `git branch --show-current`, so any push form is
# caught.
#
# Hook protocol:
#   stdin   JSON with .tool_input.command and .cwd
#   exit 0  allow the tool call
#   exit 2  block; stderr is shown to Claude as feedback

set -euo pipefail

input="$(cat)"

# jq is the supported parser for hook input. Fail loudly if it's missing
# rather than silently allowing every command.
if ! command -v jq >/dev/null 2>&1; then
  echo "block-main-write hook: jq not found; cannot parse tool input" >&2
  exit 1
fi

command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"

# Only inspect commands that look like git commit / git push at the start
# of a command segment. Word-boundary anchored to avoid false positives
# (e.g. "git commit-graph", "git push-back" if those ever exist).
if ! printf '%s' "$command" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(commit|push)([[:space:]]|$)'; then
  exit 0
fi

# Resolve the repo from the tool's cwd if provided; otherwise from $PWD.
repo_dir="${cwd:-$PWD}"

# `git branch --show-current` returns empty when detached HEAD — that is
# unusual for our workflow but should not be treated as `main`.
branch="$(git -C "$repo_dir" branch --show-current 2>/dev/null || true)"

case "$branch" in
  main|master)
    {
      echo "BLOCKED: refusing 'git commit' or 'git push' while on '$branch'."
      echo "Project rule (.claude/CLAUDE.md): all changes go through a feature branch + PR."
      echo
      echo "To proceed:"
      echo "  git checkout -b <feature-branch-name>"
      echo "  # then retry the commit/push"
    } >&2
    exit 2
    ;;
esac

exit 0
