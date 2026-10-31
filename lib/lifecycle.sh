#!/usr/bin/env bash
# Termux-Pro managed library.
# Shared by the installer and installed uninstaller. Never source user configuration.

TP_COMMANDS=(termux-pro tp tp-health tp-config tp-update tp-uninstall)
TP_OWNS_TRANSACTION=0
TP_STAGE=preflight

tp_fail() { printf '[TP] ERROR: %s\n' "$*" >&2; exit 1; }
tp_digest() {
    local digest
    digest=$(sha256sum < "$1") || return 1
    printf '%s\n' "${digest%% *}"
}
tp_paths() {
    [[ -n ${HOME:-} && $HOME == /* && $HOME != *$'\n'* ]] || tp_fail 'HOME must be an absolute path without newlines.'
    [[ -n ${PREFIX:-} && $PREFIX == /* && $PREFIX != *[[:space:]]* ]] || tp_fail 'Run inside Termux with an absolute PREFIX containing no whitespace.'
    [[ -x $PREFIX/bin/bash ]] || tp_fail 'The Termux Bash interpreter is missing.'
    TP_STATE="$HOME/.config/termux-pro"
    TP_LIBRARY="$PREFIX/lib/termux-pro/lifecycle.sh"
    TP_RECORD="$TP_STATE/repository"
    TP_RECEIPT="$TP_STATE/receipt"
    TP_TRANSACTION="$PREFIX/bin/.termux-pro-transaction"
    TP_TARGETS=()
    local name
    for name in "${TP_COMMANDS[@]}"; do TP_TARGETS+=("$PREFIX/bin/$name"); done
    TP_TARGETS+=("$TP_LIBRARY" "$TP_RECORD" "$TP_RECEIPT")
    TP_RECEIPT_INDEX=$((${#TP_TARGETS[@]} - 1))
}
tp_phase() {
    printf '%s\n' "$1" > "$TP_TRANSACTION/phase.next" || return 1
    mv -f -- "$TP_TRANSACTION/phase.next" "$TP_TRANSACTION/phase"
}
tp_restore() {
    local index target failed=0
    tp_phase rolling-back || return 1
    for index in "${!TP_TARGETS[@]}"; do
        target=${TP_TARGETS[$index]}
        if [[ -f $TP_TRANSACTION/old/$index.present ]]; then
            if [[ -e $TP_TRANSACTION/old/$index || -L $TP_TRANSACTION/old/$index ]]; then
                mv -f -- "$TP_TRANSACTION/old/$index" "$target" || failed=1
            elif [[ ! -e $target && ! -L $target ]]; then
                # A previous recovery may already have restored the backup.
                failed=1
            fi
        else
            rm -f -- "$target" || failed=1
        fi
    done
    ((failed == 0))
}
tp_finish() {
    local status=$? phase='' recovery_failed=0
    trap - EXIT ERR HUP INT TERM
    set +e
    if ((TP_OWNS_TRANSACTION)); then
        [[ ! -f $TP_TRANSACTION/phase ]] || IFS= read -r phase < "$TP_TRANSACTION/phase"
        if [[ $phase == applying || $phase == rolling-back ]]; then
            tp_restore || recovery_failed=1
        fi
        if ((recovery_failed)); then
            printf '[TP] ERROR: Recovery could not finish. Backups retained at %s; rerun the installer after fixing the filesystem.\n' "$TP_TRANSACTION" >&2
            exit 125
        fi
        rm -rf -- "$TP_TRANSACTION" || printf '[TP] Could not remove the completed transaction directory: %s\n' "$TP_TRANSACTION" >&2
    fi
    exit "$status"
}
tp_acquire() {
    local pid='' saved_prefix='' saved_home='' phase='' format='' parent device
    umask 077
    if ! mkdir -- "$TP_TRANSACTION" 2>/dev/null; then
        [[ -d $TP_TRANSACTION && ! -L $TP_TRANSACTION ]] || tp_fail 'Transaction path is not a private directory.'
        [[ ! -f $TP_TRANSACTION/pid ]] || IFS= read -r pid < "$TP_TRANSACTION/pid"
        [[ $pid =~ ^[0-9]+$ ]] || tp_fail 'Incomplete transaction lock; inspect it before retrying.'
        if kill -0 "$pid" 2>/dev/null; then tp_fail 'Another Termux-Pro operation is running.'; fi
        IFS= read -r saved_prefix < "$TP_TRANSACTION/prefix" || tp_fail 'Transaction identity is unavailable.'
        IFS= read -r saved_home < "$TP_TRANSACTION/user-home" || tp_fail 'Transaction identity is unavailable.'
        [[ $saved_prefix == "$PREFIX" && $saved_home == "$HOME" ]] || tp_fail 'Transaction belongs to a different installation.'
        IFS= read -r format < "$TP_TRANSACTION/format" || tp_fail 'Transaction format is unavailable.'
        [[ $format == 'Termux-Pro transaction v1' ]] || tp_fail 'Unrecognised transaction format; backups have been retained.'
        IFS= read -r phase < "$TP_TRANSACTION/phase" || tp_fail 'Transaction phase is unavailable.'
        case "$phase" in
            applying|rolling-back) printf '[TP] Recovering an interrupted operation.\n'; tp_restore || tp_fail 'Recovery failed; backups have been retained.' ;;
            preparing|committed) ;;
            *) tp_fail 'Unrecognised transaction phase; backups have been retained.' ;;
        esac
        rm -rf -- "$TP_TRANSACTION"
        mkdir -- "$TP_TRANSACTION"
    fi
    TP_OWNS_TRANSACTION=1
    trap tp_finish EXIT
    trap 'status=$?; printf "[TP] ERROR: %s failed (exit %s).\n" "$TP_STAGE" "$status" >&2; exit "$status"' ERR
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    chmod 700 "$TP_TRANSACTION"
    printf '%s\n' "$$" > "$TP_TRANSACTION/pid"
    printf '%s\n' "$PREFIX" > "$TP_TRANSACTION/prefix"
    printf '%s\n' "$HOME" > "$TP_TRANSACTION/user-home"
    printf 'Termux-Pro transaction v1\n' > "$TP_TRANSACTION/format"
    tp_phase preparing
    mkdir -- "$TP_TRANSACTION/new" "$TP_TRANSACTION/old"
    # All replacements and restores must be renames on the same filesystem.
    device=$(stat -c '%d' "$PREFIX/bin")
    for parent in "$PREFIX/lib/termux-pro" "$TP_STATE"; do
        [[ ! -L $parent ]] || tp_fail "Refusing a symlinked managed directory: $parent"
        mkdir -p -- "$parent"
        [[ $(stat -c '%d' "$parent") == "$device" ]] || tp_fail 'Managed directories must be on the same filesystem for rollback.'
        local probe
        probe=$(mktemp "$parent/.termux-pro-write.XXXXXX")
        rm -f -- "$probe"
    done
}
tp_read_receipt() {
    local header index digest extra count=0
    TP_EXPECTED=()
    [[ -f $TP_RECEIPT && ! -L $TP_RECEIPT ]] || tp_fail 'Installation receipt is missing or is a link; rerun the installer.'
    {
        IFS= read -r header || tp_fail 'Incomplete installation receipt.'
        [[ $header == '# Termux-Pro receipt v1' ]] || tp_fail 'Unrecognised installation receipt.'
        while read -r index digest extra; do
            [[ $index == "$count" && $digest =~ ^[a-f0-9]{64}$ && -z $extra ]] || tp_fail 'Invalid installation receipt.'
            TP_EXPECTED+=("$digest")
            count=$((count + 1))
        done
    } < "$TP_RECEIPT"
    ((count == TP_RECEIPT_INDEX)) || tp_fail 'Incomplete installation receipt.'
}
tp_check_ownership() {
    local mode=$1 index target digest
    if [[ -e $TP_RECEIPT || -L $TP_RECEIPT ]]; then
        tp_read_receipt
        for ((index=0; index<TP_RECEIPT_INDEX; index++)); do
            target=${TP_TARGETS[$index]}
            if [[ -e $target || -L $target ]]; then
                [[ -f $target && ! -L $target ]] || tp_fail "Refusing an unrelated file or link: $target"
                digest=$(tp_digest "$target")
                [[ $digest == "${TP_EXPECTED[$index]}" ]] || tp_fail "Managed file has local changes; move it aside before retrying: $target"
            fi
        done
    elif [[ $mode == uninstall ]]; then
        tp_fail 'Installation receipt is missing; reinstall before uninstalling.'
    else
        # Upgrade the previous release, which used markers but had no receipt.
        for ((index=0; index<TP_RECEIPT_INDEX-1; index++)); do
            target=${TP_TARGETS[$index]}
            if [[ -e $target || -L $target ]]; then
                [[ -f $target && ! -L $target ]] || tp_fail "Refusing an unrelated file or link: $target"
                if ((index < ${#TP_COMMANDS[@]})); then
                    grep -qxF '# Termux-Pro managed command.' "$target" || tp_fail "Refusing an unrelated command: $target"
                else
                    grep -qxF '# Termux-Pro managed library.' "$target" || tp_fail "Refusing an unrelated library: $target"
                fi
            fi
        done
        [[ ! -e $TP_RECORD || ( -f $TP_RECORD && ! -L $TP_RECORD ) ]] || tp_fail 'Repository registration is not a regular file.'
    fi
}
tp_backup() {
    local index target
    for index in "${!TP_TARGETS[@]}"; do
        target=${TP_TARGETS[$index]}
        if [[ -e $target || -L $target ]]; then
            cp -pP -- "$target" "$TP_TRANSACTION/old/$index"
            printf 'present\n' > "$TP_TRANSACTION/old/$index.present"
        fi
    done
}
tp_publish() {
    local index
    tp_phase applying
    for index in "${!TP_TARGETS[@]}"; do
        mv -f -- "$TP_TRANSACTION/new/$index" "${TP_TARGETS[$index]}"
    done
    tp_phase committed
}
