#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
conf="$PREFIX/etc/ssh/sshd_config"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then ssh-keygen -t ed25519 -a 100 -f "$HOME/.ssh/id_ed25519" -N ""; fi
pkg install -y openssh >/dev/null 2>&1 || true
# Harden sshd
declare -A kv=(
  [PasswordAuthentication]=no [PermitRootLogin]=no [PubkeyAuthentication]=yes
  [ChallengeResponseAuthentication]=no [KbdInteractiveAuthentication]=no
  [X11Forwarding]=no [AllowTcpForwarding]=no [AllowAgentForwarding]=no
  [ClientAliveInterval]=300 [ClientAliveCountMax]=2 [LoginGraceTime]=20
  [MaxAuthTries]=3 [MaxSessions]=2 [UsePAM]=no [AddressFamily]=inet
)
for k in "${!kv[@]}"; do grep -q "^$k" "$conf" 2>/dev/null || echo "$k ${kv[$k]}" >> "$conf"; done
sshd || (sshd -p 8022 || true)
ip4=$(ip -4 addr 2>/dev/null | awk '/inet / && $2 !~ /^127/{print $2}' | head -n1)
log "SSH key:"; cat "$HOME/.ssh/id_ed25519.pub"
log "Connect: ssh -p 8022 $(whoami)@${ip4%%/*}"
