#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR"/.. && pwd)"
# Load .env if present
if [ -f "$ROOT_DIR/.env" ]; then set -o allexport; source "$ROOT_DIR/.env"; set +o allexport; fi
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"; mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_FILE:-$LOG_DIR/$(basename "$0").log}"
LOCK_DIR="${LOCK_DIR:-$ROOT_DIR/.locks}"; mkdir -p "$LOCK_DIR"
LOCK_FILE="$LOCK_DIR/$(basename "$0").lock"

_ts(){ date -Is; }
log(){ printf "[%s] %s\n" "$(_ts)" "$*" | tee -a "$LOG_FILE"; }
die(){ log "ERROR: $*"; exit 1; }
cleanup(){ rm -f "$LOCK_FILE" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# file lock
( umask 022; : > "$LOCK_FILE" ) 2>/dev/null || true
if ! exec 9>"$LOCK_FILE"; then die "Cannot open lock $LOCK_FILE"; fi
if ! flock -n 9; then die "Another instance is running"; fi

# rotate logs (keep 10)
ls -1t "$LOG_DIR"/*.log 2>/dev/null | tail -n +11 | xargs -r rm -f
