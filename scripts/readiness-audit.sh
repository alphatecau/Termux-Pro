#!/usr/bin/env bash
# Read-only Android/Termux development readiness audit.
set -u
fail=0
warn=0
ok() { printf 'PASS %s\n' "$1"; }
warning() { printf 'WARN %s\n' "$1"; warn=$((warn + 1)); }
failure() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }
check_command() {
  if command -v "$1" >/dev/null 2>&1; then ok "$1 available"; else warning "$1 unavailable"; fi
}
printf 'Termux-Pro readiness audit (read-only)\n'
if [ -n "${PREFIX:-}" ] && [ -x "${PREFIX}/bin/pkg" ]; then
  ok "Termux package manager found"
else
  failure "Termux package manager not found; run inside Termux"
fi
if [ -n "${HOME:-}" ] && [ -d "$HOME" ] && [ -w "$HOME" ]; then
  ok "HOME exists and is writable"
else
  failure "HOME missing or not writable"
fi
for tool in bash git curl python ssh; do check_command "$tool"; done
if [ -d "${HOME:-/nonexistent}/storage" ]; then
  ok "Termux storage directory exists"
else
  warning "Shared storage not configured (optional: termux-setup-storage)"
fi
if command -v git >/dev/null 2>&1; then
  if git config --global --get user.name >/dev/null 2>&1 &&
     git config --global --get user.email >/dev/null 2>&1; then
    ok "Git author identity configured"
  else
    warning "Git author identity incomplete"
  fi
fi
printf 'Summary: %s failure(s), %s warning(s)\n' "$fail" "$warn"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
