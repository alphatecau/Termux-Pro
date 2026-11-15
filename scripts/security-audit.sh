#!/usr/bin/env bash
# Non-invasive permissions audit; deliberately does not print file contents.
set -euo pipefail
if (($# > 1)); then printf 'Usage: bash scripts/security-audit.sh [directory]\n' >&2; exit 2; fi
root=${1:-"$HOME"}
[[ -d $root ]] || { printf 'Not a directory: %s\n' "$root" >&2; exit 2; }
printf 'Termux-Pro permissions audit (no file contents read)\n'
warnings=0
for name in .ssh/id_rsa .ssh/id_ed25519 .config/gh/hosts.yml .git-credentials .netrc; do
  path="$root/$name"
  [[ -e $path || -L $path ]] || continue
  if [[ -L $path ]]; then
    printf 'WARN symbolic link at sensitive path: %s\n' "$name"
    warnings=$((warnings+1))
  elif [[ -f $path ]]; then
    mode=$(stat -c '%a' -- "$path")
    if [[ $(stat -c '%a' -- "$path" | tail -c 2) =~ [4567] ]]; then
      : # Full permission assessment below uses octal bits.
    fi
    numeric=$(stat -c '%f' -- "$path")
    permissions=$((16#$numeric & 077))
    if ((permissions != 0)); then
      printf 'WARN group/other permissions on: %s (mode %s)\n' "$name" "$mode"
      warnings=$((warnings+1))
    else
      printf 'PASS private permissions: %s\n' "$name"
    fi
  else
    printf 'WARN unexpected sensitive path type: %s\n' "$name"
    warnings=$((warnings+1))
  fi
done
printf 'Warnings: %s\n' "$warnings"
