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
| Configuration | Displays installation paths without loading shell code or credentials. |
| Updates | Fast-forwards a clean tracked Git checkout, then refreshes the installed commands. |

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

The five installed scripts receive the actual `$PREFIX/bin/bash` interpreter path, avoiding reliance on `/usr/bin/env` being available on Android. Rerunning the installer replaces its managed commands without appending duplicate shell settings. Files are replaced individually; if installation is interrupted, rerun it to finish.

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
```

| Shortcut | Equivalent |
| --- | --- |
| `termux-pro` | `tp` |
| `tp-health` | `tp health` |
| `tp-config` | `tp config` |
| `tp-update` | `tp update` |

Failed health checks, failed updates and failed installation steps return a nonzero exit status. Unknown commands or invalid arguments return status `2`.

### Installation paths

| Path | Purpose |
| --- | --- |
| `$HOME/Termux-Pro` | Default source checkout; other checkout paths are supported. |
| `$PREFIX/bin` | Installed commands, normally already on Termux's `PATH`. |
| `$HOME/.config/termux-pro/repository` | Checkout path stored as plain data, readable only by your user (`600`). |

The checkout and home paths may contain spaces. `PREFIX` must be absolute and contain no whitespace because it is used in script interpreter lines. After moving a checkout, rerun `bash install.sh --skip-packages` from its new location to update its registration.

### How updates behave

`tp update` requires a Git checkout on a branch with an upstream. It refuses to proceed when tracked files are modified or untracked files are present. Commit, move or stash those files first.

It uses `git pull --ff-only`: divergent history requires your decision. A successful pull is followed by the installer with `--skip-packages`, so updating this toolkit does not upgrade every package on your phone. An installation failure after the pull leaves the updated source available; rerun the installer to finish.

Package upgrades remain a separate operation you control:

```bash
pkg update && pkg upgrade
```

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Package index or download fails | Check connectivity, run `termux-change-repo`, then retry installation. |
| `tp` is not found | Run `bash install.sh` from the checkout and confirm `$PREFIX/bin` is in `PATH`. |
| An unrelated command blocks installation | Inspect the named file; choose whether to rename that tool before retrying. The installer preserves it. |
| A dependency is missing | Run `bash install.sh` to install the required packages. |
| Registered checkout is unavailable | Run the installer from the checkout's current location. |
| Update reports local changes | Review `git status`; commit, move or stash your work before retrying. |
| Checkout has no upstream or is detached | Select the intended branch and configure its upstream before updating. |

An older README supplied a one-liner that appended aliases, a module path, `ulimit` and `umask` settings to shell startup files. The new installer leaves existing customisations in place. Review old entries in `.bashrc` and `.profile` manually if they cause errors. Setting `TERMUX_AI_HOOK=1` alone does not implement AI functionality.

Public cloning requires no GitHub token. This toolkit does not configure credential storage.

Official references: [Termux package management](https://github.com/termux/termux-packages/wiki/Package-Management) and [Termux interpreter paths](https://github.com/termux/termux-fix-shebang).

## Development

The automated suite uses Python's standard library, temporary directories, a stub package manager and local Git remotes. It runs offline and never installs packages on the host.

```bash
for script in install.sh bin/*; do bash -n "$script"; done
python3 -m unittest discover -s tests -v
```

The suite covers package failures, command conflicts, repeated installs, spaces in paths, preserved user settings, health checks and successful or refused Git updates. GitHub Actions runs syntax checks and the same tests on pushes and pull requests. These checks verify shell behaviour; they do not substitute for testing real package downloads and execution on an Android device.

Report a reproducible problem through [GitHub Issues](https://github.com/alphatecau/Termux-Pro/issues). Include the failing command, output and `termux-info`, with credentials removed.

## Licence

[MIT](LICENSE).
