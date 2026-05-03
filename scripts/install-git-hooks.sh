#!/usr/bin/env bash
# Activate the in-repo git hooks under .githooks/ for this clone.
#
# Idempotent: safe to re-run. Only modifies this clone's .git/config — does
# not touch global git config or other clones / worktrees.
#
# Run once after cloning:
#   ./scripts/install-git-hooks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -d .githooks ]]; then
  echo "ERROR: .githooks/ not found in $REPO_ROOT" >&2
  exit 1
fi

echo "[install] Setting core.hooksPath = .githooks for this clone"
git config core.hooksPath .githooks

echo "[install] Marking hooks executable"
chmod +x .githooks/* 2>/dev/null || true

echo "[install] Active hooks:"
ls -1 .githooks/ | sed 's/^/  - /'

echo "[done] In-repo git hooks active. Test with: git push (should fire pre-push)."
