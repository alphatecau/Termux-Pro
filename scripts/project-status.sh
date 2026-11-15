#!/usr/bin/env bash
# Read-only status for local Git worktrees; no fetch, pull, or credentials.
set -euo pipefail
if (($# > 1)); then printf 'Usage: bash scripts/project-status.sh [directory]\n' >&2; exit 2; fi
root=${1:-"$PWD"}
[[ -d $root ]] || { printf 'Not a directory: %s\n' "$root" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'Git is required\n' >&2; exit 1; }
if ! top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null); then
  printf 'Not a Git worktree: %s\n' "$root" >&2; exit 1
fi
printf 'Repository: %s\n' "$top"
branch=$(git -C "$top" symbolic-ref --quiet --short HEAD || true)
printf 'Branch: %s\n' "${branch:-DETACHED}"
git -C "$top" status --short --untracked-files=normal
if git -C "$top" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
  counts=$(git -C "$top" rev-list --left-right --count 'HEAD...@{upstream}')
  printf 'Ahead/behind upstream: %s\n' "$counts"
else
  printf 'Upstream: not configured\n'
fi
