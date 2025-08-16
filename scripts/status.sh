#!/bin/bash
cd "$(dirname "$0")/.." || exit 1

# Colors
RED=$(printf '\033[0;31m')
GRN=$(printf '\033[0;32m')
YEL=$(printf '\033[1;33m')
NC=$(printf '\033[0m')

echo "📂 Project Path: $(pwd)"
echo "🗂 Files Snapshot:"; ls -R | head -50; echo

echo "🔗 Git Remote(s):"; git remote -v; echo
echo "🌳 Branch Info:"; git branch -vv; echo
echo "📌 Git Status:"; git status -s; echo
echo "✅ Last Commit:"; git log -1 --pretty=format:"%h | %an | %s | %cd" --date=short; echo

echo "🌐 Remote Sync Check:"
git fetch -q
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "none")
BASE=$(git merge-base @ @{u} 2>/dev/null || echo "none")
if [ "$REMOTE" = "none" ]; then
  echo "${YEL}No upstream tracking branch set.${NC}"
elif [ "$LOCAL" = "$REMOTE" ]; then
  echo "${GRN}✔ Local is up-to-date with remote.${NC}"
elif [ "$LOCAL" = "$BASE" ]; then
  echo "${YEL}⬇ Local is behind remote (run: git pull).${NC}"
elif [ "$REMOTE" = "$BASE" ]; then
  echo "${YEL}⬆ Local is ahead of remote (run: git push).${NC}"
else
  echo "${RED}⚠ Local and remote have diverged.${NC}"
fi
echo

echo "📊 Disk Usage:"; du -sh . 2>/dev/null; echo

echo "⚡ Package Versions:"
echo -n "Git: " && git --version
command -v zsh >/dev/null && echo -n "Zsh: " && zsh --version
echo -n "Apt: " && apt --version 2>/dev/null | head -1
echo

echo "🩺 Script Health Check:"
for f in scripts/*.sh; do
  [ -f "$f" ] || continue
  if [ ! -x "$f" ]; then
    echo "${YEL}⚠ $f is not executable (fix with chmod +x).${NC}"
  fi
  bash -n "$f" 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "${GRN}✔ $f syntax OK${NC}"
  else
    echo "${RED}✖ $f has syntax errors${NC}"
  fi
done
