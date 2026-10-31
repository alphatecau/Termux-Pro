#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    printf 'Usage: bash install.sh [--skip-packages]\n'
    printf 'Install Termux-Pro commands with rollback; --skip-packages uses existing dependencies.\n'
}
skip_packages=0
while (($#)); do
    case "$1" in
        --skip-packages) skip_packages=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf '[TP] Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
[[ $repository != *$'\n'* ]] || { printf '[TP] Invalid checkout path.\n' >&2; exit 1; }
# shellcheck source=lib/lifecycle.sh
source "$repository/lib/lifecycle.sh"
tp_paths
command -v pkg >/dev/null 2>&1 || tp_fail 'The Termux pkg command is missing.'
for name in "${TP_COMMANDS[@]}"; do
    [[ -f $repository/bin/$name ]] || tp_fail "Missing source: $repository/bin/$name"
    bash -n "$repository/bin/$name"
done
bash -n "$repository/lib/lifecycle.sh"
tp_acquire
tp_check_ownership install
if ((skip_packages == 0)); then
    TP_STAGE='package index refresh; check connectivity or run termux-change-repo'
    pkg update -y
    TP_STAGE='dependency installation'
    pkg install -y git curl wget neovim
fi
for dependency in git curl wget nvim; do
    command -v "$dependency" >/dev/null 2>&1 || tp_fail "Missing dependency: $dependency"
    if ! "$dependency" --version > "$TP_TRANSACTION/$dependency.version" 2>&1; then
        cat "$TP_TRANSACTION/$dependency.version" >&2
        tp_fail "Dependency cannot execute: $dependency. Run pkg update && pkg upgrade, then retry. If pkg is broken on apt-based Termux, use apt update && apt full-upgrade."
    fi
done
TP_STAGE='staging commands and recovery backups'
for index in "${!TP_COMMANDS[@]}"; do
    { printf '#!%s/bin/bash\n' "$PREFIX"; tail -n +2 "$repository/bin/${TP_COMMANDS[$index]}"; } > "$TP_TRANSACTION/new/$index"
    chmod 755 "$TP_TRANSACTION/new/$index"
    bash -n "$TP_TRANSACTION/new/$index"
done
index=${#TP_COMMANDS[@]}
cp -- "$repository/lib/lifecycle.sh" "$TP_TRANSACTION/new/$index"
chmod 600 "$TP_TRANSACTION/new/$index"
printf '%s\n' "$repository" > "$TP_TRANSACTION/new/$((index + 1))"
printf '# Termux-Pro receipt v1\n' > "$TP_TRANSACTION/new/$TP_RECEIPT_INDEX"
for ((index=0; index<TP_RECEIPT_INDEX; index++)); do
    digest=$(tp_digest "$TP_TRANSACTION/new/$index")
    printf '%s %s\n' "$index" "$digest" >> "$TP_TRANSACTION/new/$TP_RECEIPT_INDEX"
done
chmod 600 "$TP_TRANSACTION/new/$((TP_RECEIPT_INDEX - 1))" "$TP_TRANSACTION/new/$TP_RECEIPT_INDEX"
tp_backup
TP_STAGE='publishing commands'
tp_publish
printf '[TP] Installation complete. Run: tp health\n'
