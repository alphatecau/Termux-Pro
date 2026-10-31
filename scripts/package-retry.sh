#!/usr/bin/env bash
# Bounded retries for package operations in the disposable Android test only.
retry_package() {
    local attempt status
    for attempt in 1 2 3; do
        if "$@"; then
            return 0
        else
            status=$?
        fi
        if ((attempt == 3)); then
            return "$status"
        fi
        printf 'Package command failed (exit %s); retrying in %s seconds (%s/3).\n' \
            "$status" "$((attempt * 5))" "$attempt" >&2
        sleep "$((attempt * 5))"
    done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    set -Eeuo pipefail
    (($#)) || { printf 'Usage: bash scripts/package-retry.sh command [args...]\n' >&2; exit 2; }
    retry_package "$@"
fi
