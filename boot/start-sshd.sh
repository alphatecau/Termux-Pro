#!/usr/bin/env bash
source "$(dirname "$0")/../scripts/lib.sh"
pgrep sshd >/dev/null 2>&1 || sshd -p 8022
log "sshd ensured"
