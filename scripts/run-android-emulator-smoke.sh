#!/usr/bin/env bash
# Host-side runner for an ephemeral GitHub Actions Android emulator.
set -Eeuo pipefail
[[ -n ${RUNNER_TEMP:-} && ${GITHUB_ACTIONS:-} == true ]] || { printf 'Run this harness in the disposable Android CI job.\n' >&2; exit 2; }
repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repository"
release='https://github.com/termux/termux-app/releases/download/v0.118.3'
apk_name='termux-app_v0.118.3+github-debug_x86_64.apk'
curl --fail --location --retry 3 "$release/${apk_name/+/%2B}" --output "$RUNNER_TEMP/termux.apk"
curl --fail --location --retry 3 "$release/termux-app_v0.118.3%2Bgithub-debug_sha256sums" --output "$RUNNER_TEMP/termux.sha256sums"
python3 - "$RUNNER_TEMP/termux.apk" "$RUNNER_TEMP/termux.sha256sums" "$apk_name" <<'PY'
import hashlib, pathlib, sys
apk, checksums, name = sys.argv[1:]
expected = [line.split()[0] for line in pathlib.Path(checksums).read_text().splitlines()
            if len(line.split()) == 2 and pathlib.PurePosixPath(line.split()[1].lstrip('*')).name == name]
if len(expected) != 1 or hashlib.sha256(pathlib.Path(apk).read_bytes()).hexdigest() != expected[0]:
    raise SystemExit('Termux APK checksum verification failed')
PY
adb install "$RUNNER_TEMP/termux.apk"
adb shell am start -n com.termux/.app.TermuxActivity
android_run() {
    local quoted
    printf -v quoted '%q' "$1"
    adb shell "run-as com.termux /system/bin/sh -c $quoted"
}
ready=0
for ((attempt=0; attempt<90; attempt++)); do
    if android_run 'test -x files/usr/bin/bash && test -f files/usr/etc/profile'; then ready=1; break; fi
    sleep 2
done
((ready)) || { printf 'Termux bootstrap did not become ready.\n' >&2; exit 1; }
android_run 'mkdir -p files/home/Termux-Pro'
tar --exclude=.git --exclude=__pycache__ -cf - . | android_run 'cd files/home/Termux-Pro && /system/bin/toybox tar -xf -'
android_run 'exec /system/bin/env HOME=/data/data/com.termux/files/home PREFIX=/data/data/com.termux/files/usr PATH=/data/data/com.termux/files/usr/bin:/system/bin TMPDIR=/data/data/com.termux/files/usr/tmp LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec.so TERM=xterm-256color TERMUX_VERSION=0.118.3 TERMUX_APK_RELEASE=GITHUB TERMUX_PRO_DISPOSABLE_TEST=1 /data/data/com.termux/files/usr/bin/bash /data/data/com.termux/files/home/Termux-Pro/scripts/android-smoke.sh'
