# Termux-Pro

**A small, practical development toolkit for Termux on Android.**

Install essential tools, check your environment, and keep this checkout up to date from one command.

[Install](#install) · [Commands](#commands) · [Troubleshooting](#troubleshooting) · [Development](#development)

## What works today

| Capability | Behaviour |
| --- | --- |
| Installation | Refreshes the package index and installs Git, curl, wget and Neovim. |
| Command access | Installs `tp`, `termux-pro` and three maintenance shortcuts into `$PREFIX/bin`. |
| Health checks | Reports missing dependencies, missing commands and unavailable repository registration. |
| Configuration | Displays installation paths without loading user shell code or credentials. |
| Updates | Fast-forwards a clean tracked Git checkout, then refreshes the installed commands. |
| Recovery | Stages files and backups before replacement; rolls back failed toolkit changes and recovers interrupted publication. |
| Uninstall | Verifies installed file hashes before removing managed files; preserves the checkout, packages and personal settings. |

This is an early-stage shell toolkit. AI integration, module management, automatic security hardening and Debian/Ubuntu compatibility are development ideas, not implemented features. Termux-Pro is an independent project.

## Install

Run these commands **inside Termux**, with a working package mirror and internet connection. Keep the checkout in Termux's private home directory.

```bash
pkg update -y && pkg install -y git && \
  git clone https://github.com/alphatecau/Termux-Pro.git "$HOME/Termux-Pro" && \
  cd "$HOME/Termux-Pro" && bash install.sh
```

If you already have the checkout, use:

```bash
cd "$HOME/Termux-Pro" && git pull --ff-only && bash install.sh
```

Installation stops when a package operation fails. It never deletes an existing checkout or automatically runs a full `pkg upgrade`. It preserves shell startup files, Git credentials and unrelated commands. If a command name is already used by another tool, installation stops before changing packages or installed commands.

The six installed scripts receive the actual `$PREFIX/bin/bash` interpreter path, avoiding reliance on `/usr/bin/env` being available on Android. Rerunning the installer replaces its managed commands without appending duplicate shell settings. Files are staged and validated before replacement. Failed toolkit changes restore the previous installation. See [Recovery](#recovery) for interruption handling and the rollback boundary.

Already have all dependencies installed? Skip package operations explicitly:

```bash
bash install.sh --skip-packages
```

The installer still checks for `pkg`, Termux Bash and the required tools. Use `bash install.sh --help` to see its options.

## Commands

```bash
tp                  # Show help
tp health           # Check this installation
tp config           # Display paths
tp update           # Update the checkout and refresh commands
tp uninstall        # Remove unchanged managed toolkit files
```

| Shortcut | Equivalent |
| --- | --- |
| `termux-pro` | `tp` |
| `tp-health` | `tp health` |
| `tp-config` | `tp config` |
| `tp-update` | `tp update` |
| `tp-uninstall` | `tp uninstall` |

Failed health checks, failed updates and failed installation steps return a nonzero exit status. Unknown commands or invalid arguments return status `2`. Incomplete rollback returns `125` and retains its recovery files.

### Installation paths

| Path | Purpose |
| --- | --- |
| `$HOME/Termux-Pro` | Default source checkout; other checkout paths are supported. |
| `$PREFIX/bin` | Installed commands, normally already on Termux's `PATH`. |
| `$PREFIX/lib/termux-pro/lifecycle.sh` | Managed installation and recovery functions. |
| `$HOME/.config/termux-pro/receipt` | Expected hashes for managed files; detects local changes before replacement or removal. |
| `$HOME/.config/termux-pro/repository` | Checkout path stored as plain data, readable only by your user (`600`). |

The checkout and home paths may contain spaces. `PREFIX` must be absolute and contain no whitespace because it is used in script interpreter lines. After moving a checkout, rerun `bash install.sh --skip-packages` from its new location to update its registration.

### How updates behave

`tp update` requires a Git checkout on a branch with an upstream. It refuses to proceed when tracked files are modified or untracked files are present. Commit, move or stash those files first.

It uses `git pull --ff-only`: divergent history requires your decision. A successful pull is followed by the installer with `--skip-packages`, so updating this toolkit does not upgrade every package on your phone. An installation failure after the pull restores toolkit files and leaves the updated source available; rerun the installer to finish.

Package upgrades remain a separate operation you control:

```bash
pkg update && pkg upgrade
```

## Recovery

The installer stages complete replacement files and recovery backups before publishing anything. Each file replacement uses a rename on the same filesystem. Install and uninstall operations share a lock, so two operations cannot modify the installation concurrently.

Ordinary failures and `HUP`, `INT` or `TERM` trigger rollback. A forced stop such as `SIGKILL` cannot run a cleanup handler; rerunning the installer recovers a journalled interrupted publication before package operations begin. If filesystem errors prevent restoration, recovery files remain in `$PREFIX/bin/.termux-pro-transaction` and the operation fails with status `125`. Fix the permission or storage issue, then rerun the installer. Do not delete that directory while it contains needed recovery backups.

Rollback covers managed toolkit files, their permissions and installation records. Package-manager changes and Git source updates remain in place. The state directory and managed library directory must share the filesystem containing `$PREFIX/bin`. Filesystem damage or power-loss durability is not covered by the automated tests. An incomplete lock without a readable owner is preserved for inspection.

Once a receipt exists, installation and uninstall refuse to overwrite or remove modified managed files. Move an intentional personal modification aside, then rerun the operation. Startup files, credentials and unrelated files are outside the managed file list.

## Uninstall

```bash
tp uninstall
# Equivalent: tp-uninstall
```

This removes unchanged toolkit commands, its library and its installation records. It works even if the source checkout has been moved or deleted. Packages, the source checkout, startup files, credentials and personal files are retained. Managed directories are removed only when empty. A failed removal rolls back to the previous installation.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Package index or download fails | Check connectivity, run `termux-change-repo`, then retry installation. |
| `tp` is not found | Run `bash install.sh` from the checkout and confirm `$PREFIX/bin` is in `PATH`. |
| An unrelated command blocks installation | Inspect the named file; choose whether to rename that tool before retrying. The installer preserves it. |
| A dependency is missing | Run `bash install.sh` to install the required packages. |
| Registered checkout is unavailable | Run the installer from the checkout's current location. |
| A managed file has local changes | Move your customised copy aside before reinstalling or uninstalling; it is preserved on refusal. |
| A rollback cannot finish | Fix storage or permissions and rerun the installer; retain the transaction directory and backups. |
| Update reports local changes | Review `git status`; commit, move or stash your work before retrying. |
| Checkout has no upstream or is detached | Select the intended branch and configure its upstream before updating. |

An older README supplied a one-liner that appended aliases, a module path, `ulimit` and `umask` settings to shell startup files. The new installer leaves existing customisations in place. Review old entries in `.bashrc` and `.profile` manually if they cause errors. Setting `TERMUX_AI_HOOK=1` alone does not implement AI functionality.

Public cloning requires no GitHub token. This toolkit does not configure credential storage.

Official references: [Termux package management](https://github.com/termux/termux-packages/wiki/Package-Management) and [Termux interpreter paths](https://github.com/termux/termux-fix-shebang).

## Development

The automated suite uses Python's standard library, temporary directories, a stub package manager and local Git remotes. It runs offline and never installs packages on the host.

```bash
for script in install.sh bin/* lib/*.sh scripts/*.sh; do bash -n "$script"; done
shellcheck -x install.sh bin/* lib/*.sh scripts/*.sh
python3 -m unittest discover -s tests -v
```

The suite covers package failures, command conflicts, repeated installs, paths with spaces, file integrity, safe removal, rollback, interrupted publication and Git updates. Storage faults are injected rather than filling a real disk. A real directory-permission test runs under an unprivileged account and skips when the test process is root.

GitHub Actions runs Bash syntax checks, ShellCheck and the integration suite. Pull requests also run a disposable Android API 28 x86_64 emulator using the official Termux v0.118.3 GitHub APK, checked against the release checksum file. The Android job downloads real packages and exercises installation, checks, updates, the integration suite and uninstall. Emulator results do not establish physical-device or ARM64 compatibility. See [Testing and validation](docs/TESTING.md) for scope, commands and physical-device validation.

Report a reproducible problem through [GitHub Issues](https://github.com/alphatecau/Termux-Pro/issues). Include the failing command, output and `termux-info`, with credentials removed.

## Licence

[MIT](LICENSE).
