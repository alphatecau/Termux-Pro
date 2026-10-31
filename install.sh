#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    printf 'Usage: bash install.sh [--skip-packages]\n'
    printf 'Install Termux-Pro commands; --skip-packages uses existing dependencies.\n'
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

fail() { printf '[TP] ERROR: %s\n' "$*" >&2; exit 1; }
stage=preflight
temporary_file=''
trap 'status=$?; printf "[TP] ERROR: %s failed (exit %s).\n" "$stage" "$status" >&2; exit "$status"' ERR
trap 'if [[ -n $temporary_file ]]; then rm -f -- "$temporary_file"; fi' EXIT

[[ -n ${HOME:-} && $HOME == /* ]] || fail 'HOME must be an absolute directory.'
[[ -n ${PREFIX:-} && $PREFIX == /* && $PREFIX != *[[:space:]]* ]] ||
    fail 'Run this installer inside Termux with its absolute PREFIX set (no whitespace).'
[[ -x $PREFIX/bin/bash ]] || fail 'The Termux Bash interpreter is missing.'
command -v pkg >/dev/null 2>&1 || fail 'The Termux pkg command is missing.'

repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
[[ $repository != *$'\n'* ]] || fail 'The repository path must not contain a newline.'
commands=(termux-pro tp tp-health tp-config tp-update)

# Validate every source and destination before changing packages or commands.
for name in "${commands[@]}"; do
    source_file="$repository/bin/$name"
    target="$PREFIX/bin/$name"
    [[ -f $source_file ]] || fail "Missing source: $source_file"
    bash -n "$source_file"
    if [[ -e $target || -L $target ]]; then
        [[ ! -d $target ]] || fail "Destination is a directory: $target"
        if [[ -L $target ]]; then
            [[ $(readlink -- "$target") == "$source_file" ]] ||
                fail "Refusing to replace an unrelated link: $target"
        else
            grep -qxF '# Termux-Pro managed command.' "$target" ||
                cmp -s "$source_file" "$target" ||
                fail "Refusing to replace an unrelated command: $target"
        fi
    fi
done

if ((skip_packages == 0)); then
    stage='package index refresh; check connectivity or run termux-change-repo'
    pkg update -y
    stage='dependency installation'
    pkg install -y git curl wget neovim
fi
for dependency in git curl wget nvim; do
    command -v "$dependency" >/dev/null 2>&1 || fail "Missing dependency: $dependency"
done

stage='command installation'
umask 077
for name in "${commands[@]}"; do
    temporary_file=$(mktemp "$PREFIX/bin/.termux-pro.XXXXXX")
    # Installed copies use the real interpreter; the checkout stays portable.
    { printf '#!%s/bin/bash\n' "$PREFIX"; tail -n +2 "$repository/bin/$name"; } > "$temporary_file"
    chmod 755 "$temporary_file"
    mv -f -- "$temporary_file" "$PREFIX/bin/$name"
    temporary_file=''
done

stage='repository registration'
state_directory="$HOME/.config/termux-pro"
mkdir -p -- "$state_directory"
chmod 700 "$state_directory"
temporary_file=$(mktemp "$state_directory/.repository.XXXXXX")
printf '%s\n' "$repository" > "$temporary_file"
chmod 600 "$temporary_file"
mv -f -- "$temporary_file" "$state_directory/repository"
temporary_file=''
printf '[TP] Installation complete. Run: tp health\n'
