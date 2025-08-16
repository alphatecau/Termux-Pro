#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
BACKUP_DIR="${BACKUP_DIR:-/sdcard/termux-backups}"
COMPRESS_LEVEL="${COMPRESS_LEVEL:-6}"
BACKUP_PASSPHRASE="${BACKUP_PASSPHRASE:-}"
ts="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
tmp="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"; mkdir -p "$tmp"
archive="$tmp/termux-$ts.tar.zst"
target="$BACKUP_DIR/termux-$ts.tar.zst${BACKUP_PASSPHRASE:+.enc}"
log "Creating archive…"
tar --exclude='*.tmp' --exclude='cache/*' --exclude='**/.git' \
    -I "zstd -T0 -${COMPRESS_LEVEL}" \
    -cf "$archive" \
    "$HOME/.termux" "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/bin" "$ROOT_DIR" 2>/dev/null || true
if [ -n "$BACKUP_PASSPHRASE" ]; then
  log "Encrypting (AES-256-GCM, PBKDF2)…"
  openssl enc -aes-256-gcm -pbkdf2 -iter 300000 -salt -in "$archive" -out "$target" -pass pass:"$BACKUP_PASSPHRASE"
  rm -f "$archive"
else
  mv "$archive" "$target"
fi
log "Stored: $target"
ls -1t "$BACKUP_DIR"/termux-*.zst* 2>/dev/null | tail -n +8 | xargs -r rm -f
