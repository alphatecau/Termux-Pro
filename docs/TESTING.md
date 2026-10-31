# Testing and validation

Use the checks below to distinguish simulated failures, Android emulator behaviour and physical-device evidence.

| Check | Environment | What it establishes |
| --- | --- | --- |
| Bash syntax and ShellCheck | GitHub Ubuntu runner | Syntax and static shell analysis. |
| Integration suite | Temporary paths; stub package manager; real local Git | Installation, update, ownership, uninstall and recovery behaviour. |
| Permission test | Unprivileged process | An actual unwritable managed directory causes a failure while preserving the installation. Skips for root. |
| Storage fault tests | Injected `ENOSPC`-style failures | Staging and publication failures restore or preserve toolkit files. They do not fill the physical disk. |
| Signal tests | Subprocesses receiving `TERM` and `KILL` | Rollback on catchable termination and journal recovery after forced termination. |
| Android smoke job | Android API 28, x86_64, Termux v0.118.3 GitHub APK | Real Android userspace, Termux packages, command execution, updates and uninstall. |
| Physical Android phone | User-owned device | Still requires a recorded device run; emulator results do not establish this. |

## Repeatable host checks

```bash
for script in install.sh bin/* lib/*.sh scripts/*.sh; do bash -n "$script"; done
shellcheck -x install.sh bin/* lib/*.sh scripts/*.sh
python3 -m unittest discover -s tests -v
```

The suite isolates its files in temporary directories and never invokes the host's real package manager. Package errors, storage faults and selected command failures use test wrappers. Git operations use local temporary remotes. Tests preserve bytes and permissions after failed upgrades and failed removals. A separate permission test uses real directory permissions and is intentionally skipped under root.

## Android emulator job

The `android-smoke` job runs for pull requests and manual workflow runs. It uses a pinned emulator action, an Android API 28 x86_64 system image, and the official architecture-specific Termux v0.118.3 APK. The APK is checked against its release's checksum file before installation. The job has read-only repository permissions.

The host harness starts Termux, waits for bootstrap, transfers the tested source into its private home and invokes `scripts/android-smoke.sh`. It first upgrades the disposable Termux bootstrap to avoid incompatible partial package updates. That fresh test environment accepts package-maintainer configuration defaults noninteractively; production installation does not make those configuration choices. This script installs actual dependencies, exercises all public commands, runs the Python suite under Termux, creates a local Git upstream, tests an update and uninstalls. `ANDROID_SMOKE_PASS` appears only after those steps succeed and the startup-file hashes match.

Read the actual [workflow run](https://github.com/alphatecau/Termux-Pro/actions) before claiming a configuration passed. A checked-in workflow is not evidence of a successful run.

The disposable harness retries bootstrap package operations and Python installation at most three times, waiting five and ten seconds between attempts. This handles transient mirror-sync failures while retaining package signature and checksum checks. A persistent failure retains its final exit status and stops the job. The normal installer still propagates its package failures directly.

## Physical-device validation

Use a fresh disposable Termux profile or a spare device with no existing Termux-Pro installation. The smoke script installs packages, creates a temporary local Git repository and removes this toolkit at the end. It refuses to replace an existing toolkit.

Review the script before running it:

```bash
cd "$HOME/Termux-Pro"
TERMUX_PRO_DISPOSABLE_TEST=1 bash scripts/android-smoke.sh
```

Record the tested commit, Android version/API, CPU ABI, Termux app version and installation source, then retain the final exit status and `ANDROID_SMOKE_PASS` output. Do not switch an existing Termux app between signing sources for this test.

For validation on a non-disposable installation, preserve your work and test installation, `tp health`, `tp config` and updates individually. Do not invoke the disposable smoke harness there.

## Limits

Toolkit rollback does not undo package installations or Git commits/pulls. Operations require managed paths on one filesystem. Journal recovery relies on readable recovery files and a filesystem that can accept restoration. A busy or malformed lock is preserved rather than removed speculatively. Physical power failure, arbitrary filesystem corruption, every Android version and every CPU architecture are outside the automated coverage.
