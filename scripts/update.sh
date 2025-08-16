#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
log "START update"
if command -v pkg >/dev/null 2>&1; then
  yes | pkg update && yes | pkg upgrade
  pkg install -y git curl wget zstd tar openssh coreutils grep sed findutils procps termux-api openssl || true
fi
command -v pip >/dev/null 2>&1 && python -m pip install --upgrade pip setuptools wheel >/dev/null || true
command -v npm >/dev/null 2>&1 && npm -g update >/dev/null || true
git -C "$ROOT_DIR" pull --rebase || true
log "DONE update"
