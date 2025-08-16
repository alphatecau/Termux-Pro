#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
NOTES_DIR="${NOTES_DIR:-$ROOT_DIR/notes}"; mkdir -p "$NOTES_DIR"
NOTES_PASSPHRASE="${NOTES_PASSPHRASE:-}"
tags="${NOTES_TAGS:-general}"
file="$NOTES_DIR/$(date +%Y%m%d-%H%M%S)_${tags//,/+}.md"
if [ $# -gt 0 ]; then printf "# Note %s\n\n%s\n" "$(date -Is)" "$*" > "$file"; else printf "# Note %s\n\n" "$(date -Is)" > "$file"; ${EDITOR:-nano} "$file"; fi
if [ -n "$NOTES_PASSPHRASE" ]; then
  openssl enc -aes-256-gcm -pbkdf2 -iter 200000 -salt -in "$file" -out "$file.enc" -pass pass:"$NOTES_PASSPHRASE"
  (command -v shred >/dev/null && shred -u "$file") || rm -f "$file"
  log "Encrypted: $file.enc"
else
  log "Saved: $file"
fi
