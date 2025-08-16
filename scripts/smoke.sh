#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
log "Smoke: starting"
for c in git curl openssl tar zstd; do command -v "$c" >/dev/null || die "Missing: $c"; done
bash -n "$ROOT_DIR"/scripts/*.sh
log "Smoke: OK"
