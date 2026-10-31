#!/usr/bin/env bash
# Run only in a fresh disposable Termux environment: installs packages and removes this toolkit.
set -Eeuo pipefail
[[ ${TERMUX_PRO_DISPOSABLE_TEST:-} == 1 ]] || { printf 'Set TERMUX_PRO_DISPOSABLE_TEST=1 only in a disposable Termux installation.\n' >&2; exit 2; }
[[ -x /system/bin/getprop && -n ${PREFIX:-} && -n ${HOME:-} ]] || { printf 'An Android Termux environment is required.\n' >&2; exit 1; }
[[ ! -e $PREFIX/bin/termux-pro ]] || { printf 'Refusing to replace an existing toolkit during a smoke test.\n' >&2; exit 1; }
repository=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repository"
printf 'Android API: %s\nABI: %s\n' "$(/system/bin/getprop ro.build.version.sdk)" "$(/system/bin/getprop ro.product.cpu.abi)"
settings_before=''
for name in .bashrc .profile .git-credentials; do
    if [[ -f $HOME/$name ]]; then settings_before+="$(sha256sum "$HOME/$name")"; fi
done
bash install.sh
bash install.sh --skip-packages
tp health
tp config
git --version
curl --version
wget --version
nvim --version
pkg install -y python
python -m unittest discover -s tests -v
# Exercise real Termux Git in a private copy; preserve the source checkout and its remotes.
fixture_directory=$(mktemp -d)
cp -R -- "$repository" "$fixture_directory/checkout"
rm -rf -- "$fixture_directory/checkout/.git"
cd -- "$fixture_directory/checkout"
git init -b smoke
git config user.name 'Termux-Pro Android Test'
git config user.email 'tests@example.invalid'
git add .
git commit -m 'Disposable Android smoke fixture'
remote_directory=$(mktemp -d "$HOME/termux-pro-smoke-remote.XXXXXX")
git init --bare --initial-branch=smoke "$remote_directory"
git remote add origin "$remote_directory"
git push -u origin smoke
bash install.sh --skip-packages
tp update
tp uninstall
for name in termux-pro tp tp-health tp-config tp-update tp-uninstall; do
    [[ ! -e $PREFIX/bin/$name ]] || { printf 'Command remained after uninstall: %s\n' "$name" >&2; exit 1; }
done
settings_after=''
for name in .bashrc .profile .git-credentials; do
    if [[ -f $HOME/$name ]]; then settings_after+="$(sha256sum "$HOME/$name")"; fi
done
[[ $settings_before == "$settings_after" ]] || { printf 'User settings changed during smoke test.\n' >&2; exit 1; }
cd -- "$repository"
rm -rf -- "$fixture_directory" "$remote_directory"
printf 'ANDROID_SMOKE_PASS\n'
