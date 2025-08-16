#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$ROOT_DIR"
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_NAME="${GIT_NAME:-User}"
GIT_EMAIL="${GIT_EMAIL:-user@example.com}"
git config user.name "$GIT_NAME"
git config user.email "$GIT_EMAIL"
git add -A
git commit -m "Auto-sync: $(date -Is)" || log "Nothing to commit"
git pull --rebase "$GIT_REMOTE" "$GIT_BRANCH" || true
git push "$GIT_REMOTE" "$GIT_BRANCH"
log "Pushed to $GIT_REMOTE/$GIT_BRANCH"
