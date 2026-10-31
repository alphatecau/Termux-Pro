"""Offline integration tests using isolated Termux paths and a stub pkg."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]
BASH = shutil.which("bash")
GIT = shutil.which("git")
COMMANDS = ("termux-pro", "tp", "tp-health", "tp-config", "tp-update", "tp-uninstall")


class TermuxProTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="termux-pro-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.checkout = self.root / "repo with spaces"
        shutil.copytree(SOURCE, self.checkout, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        self.prefix = self.root / "usr"
        self.commands = self.prefix / "bin"
        self.commands.mkdir(parents=True)
        self.user_home = self.root / "home with spaces"
        self.user_home.mkdir()
        self.pkg_log = self.root / "pkg.log"
        # Do not let host dependencies hide missing Termux tools.
        for name in ("bash", "cat", "chmod", "cmp", "dirname", "git", "grep", "mkdir",
                     "mktemp", "mv", "readlink", "rm", "tail", "touch", "cp", "stat", "sha256sum", "rmdir"):
            (self.commands / name).symlink_to(shutil.which(name))
        for name in ("curl", "wget", "nvim"):
            self.write_command(name, "exit 0\n")
        self.write_command("pkg", 'printf "%s\\n" "$*" >> "$TP_TEST_PKG_LOG"\n'
                           'if [[ ${TP_TEST_FAIL:-} == "$1" ]]; then exit 42; fi\n')
        self.env = {**os.environ, "HOME": str(self.user_home), "PREFIX": str(self.prefix),
                    "PATH": str(self.commands), "TP_TEST_PKG_LOG": str(self.pkg_log),
                    "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0"}
        for name in ("TP_TEST_FAIL", "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
            self.env.pop(name, None)

    def write_command(self, name, body):
        path = self.commands / name
        path.unlink(missing_ok=True)
        path.write_text(f"#!{BASH}\n{body}")
        path.chmod(0o755)

    def run_process(self, args, *, env=None, cwd=None):
        return subprocess.run([str(x) for x in args], env=env or self.env,
                              cwd=cwd or self.checkout, capture_output=True, text=True, timeout=20)

    def install(self, *args, env=None):
        return self.run_process([BASH, self.checkout / "install.sh", *args], env=env)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def install_ok(self):
        self.assert_ok(self.install())

    def git(self, *args, cwd=None):
        result = self.run_process([GIT, *args], cwd=cwd)
        self.assert_ok(result)
        return result.stdout.strip()

    def setup_tracking_checkout(self):
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Termux-Pro Tests")
        self.git("config", "user.email", "tests@example.invalid")
        self.git("add", ".")
        self.git("commit", "-m", "Initial fixture")
        self.remote = self.root / "remote.git"
        self.git("init", "--bare", "--initial-branch=main", str(self.remote))
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "-u", "origin", "main")
        self.install_ok()

    def test_install_registers_commands_and_preserves_user_settings(self):
        protected = (".bashrc", ".profile", ".git-credentials")
        for name in protected:
            (self.user_home / name).write_text("existing user content\n")
        self.install_ok()
        self.assertEqual(self.pkg_log.read_text().splitlines(),
                         ["update -y", "install -y git curl wget neovim"])
        for name in COMMANDS:
            path = self.commands / name
            self.assertTrue(os.access(path, os.X_OK))
            self.assertFalse(path.is_symlink())
            self.assertEqual(path.read_text().splitlines()[0], f"#!{self.commands}/bash")
        record = self.user_home / ".config/termux-pro/repository"
        self.assertEqual(record.read_text(), str(self.checkout) + "\n")
        self.assertEqual(record.stat().st_mode & 0o777, 0o600)
        for name in protected:
            self.assertEqual((self.user_home / name).read_text(), "existing user content\n")

    def test_reinstallation_is_idempotent(self):
        self.install_ok()
        before = {name: (self.commands / name).read_bytes() for name in COMMANDS}
        self.assert_ok(self.install("--skip-packages"))
        self.assertEqual(before, {name: (self.commands / name).read_bytes() for name in COMMANDS})
        self.assertEqual(len(self.pkg_log.read_text().splitlines()), 2)

    def test_package_failures_abort_without_claiming_success(self):
        for failure in ("update", "install"):
            with self.subTest(failure=failure):
                result = self.install(env={**self.env, "TP_TEST_FAIL": failure})
                self.assertEqual(result.returncode, 42)
                self.assertNotIn("Installation complete", result.stdout)
                self.assertFalse((self.commands / "tp").exists())
        self.assertEqual(self.pkg_log.read_text().splitlines(),
                         ["update -y", "update -y", "install -y git curl wget neovim"])

    def run_package_retry(self, failures):
        self.write_command("sleep", 'printf "%s\\n" "$1" >> "$TP_TEST_RETRY_DELAYS"\n')
        self.write_command("apt-get", '''
attempt=0
if [[ -f $TP_TEST_RETRY_COUNT ]]; then read -r attempt < "$TP_TEST_RETRY_COUNT"; fi
attempt=$((attempt + 1))
printf '%s\\n' "$attempt" > "$TP_TEST_RETRY_COUNT"
printf '%s\\n' "$*" >> "$TP_TEST_PKG_LOG"
if ((attempt <= TP_TEST_RETRY_FAILURES)); then exit 100; fi
''')
        environment = {**self.env, "TP_TEST_RETRY_COUNT": str(self.root / "attempts"),
                       "TP_TEST_RETRY_DELAYS": str(self.root / "delays"),
                       "TP_TEST_RETRY_FAILURES": str(failures)}
        return self.run_process([BASH, self.checkout / "scripts/package-retry.sh",
                                 "apt-get", "install", "-y", "python"], env=environment)

    def test_package_retry_succeeds_without_repeating_successful_command(self):
        self.assert_ok(self.run_package_retry(0))
        self.assertEqual(self.pkg_log.read_text().splitlines(), ["install -y python"])
        self.assertFalse((self.root / "delays").exists())

    def test_package_retry_recovers_from_transient_mirror_errors(self):
        self.assert_ok(self.run_package_retry(2))
        self.assertEqual(self.pkg_log.read_text().splitlines(), ["install -y python"] * 3)
        self.assertEqual((self.root / "delays").read_text().splitlines(), ["5", "10"])

    def test_package_retry_stops_and_preserves_final_failure_status(self):
        result = self.run_package_retry(9)
        self.assertEqual(result.returncode, 100)
        self.assertEqual(self.pkg_log.read_text().splitlines(), ["install -y python"] * 3)
        self.assertEqual((self.root / "delays").read_text().splitlines(), ["5", "10"])

    def test_skip_packages_is_offline(self):
        self.assert_ok(self.install("--skip-packages"))
        self.assertFalse(self.pkg_log.exists())

    def test_help_works_without_termux(self):
        result = self.install("--help", env={"PATH": "/usr/bin:/bin"})
        self.assert_ok(result)
        self.assertIn("Usage:", result.stdout)
        self.assertFalse(self.pkg_log.exists())

    def test_missing_prefix_is_rejected(self):
        environment = dict(self.env)
        environment.pop("PREFIX")
        self.assertNotEqual(self.install(env=environment).returncode, 0)
        self.assertFalse(self.pkg_log.exists())

    def test_unknown_installer_option_is_rejected(self):
        self.assertEqual(self.install("--bogus").returncode, 2)
        self.assertFalse(self.pkg_log.exists())

    def test_missing_source_fails_before_changing_packages(self):
        (self.checkout / "bin/tp-health").unlink()
        self.assertNotEqual(self.install().returncode, 0)
        self.assertFalse(self.pkg_log.exists())

    def test_conflicting_command_is_preserved(self):
        foreign = self.commands / "tp-health"
        foreign.write_text("unrelated executable\n")
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual(foreign.read_text(), "unrelated executable\n")
        self.assertFalse((self.commands / "termux-pro").exists())
        self.assertFalse(self.pkg_log.exists())

    def test_conflicting_symlink_is_preserved(self):
        foreign = self.commands / "tp"
        foreign.symlink_to(self.commands / "git")
        self.assertNotEqual(self.install().returncode, 0)
        self.assertTrue(foreign.is_symlink())

    def test_missing_dependency_prevents_installation(self):
        (self.commands / "nvim").unlink()
        self.assertNotEqual(self.install("--skip-packages").returncode, 0)
        self.assertFalse((self.commands / "tp").exists())

    def test_help_config_health_and_shortcuts(self):
        self.install_ok()
        for command in (["tp"], ["termux-pro", "--help"], ["tp", "health"],
                        ["tp-health"], ["tp", "config"], ["tp-config"]):
            with self.subTest(command=command):
                self.assert_ok(self.run_process([self.commands / command[0], *command[1:]]))
        self.assertIn(str(self.checkout), self.run_process([self.commands / "tp-config"]).stdout)
        self.assertEqual(self.run_process([self.commands / "tp", "unknown"]).returncode, 2)
        self.assertEqual(self.run_process([self.commands / "tp", "health", "extra"]).returncode, 2)

    def test_health_reports_missing_command_and_dependency(self):
        self.install_ok()
        (self.commands / "nvim").unlink()
        (self.commands / "tp-update").unlink()
        result = self.run_process([self.commands / "tp-health"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing dependency: nvim", result.stdout)
        self.assertIn("missing installed command: tp-update", result.stdout)

    def test_missing_registration_fails(self):
        self.install_ok()
        (self.user_home / ".config/termux-pro/repository").unlink()
        for name in ("tp-health", "tp-config", "tp-update"):
            self.assertNotEqual(self.run_process([self.commands / name]).returncode, 0)

    def test_repository_registration_is_data_not_shell_code(self):
        self.install_ok()
        record = self.user_home / ".config/termux-pro/repository"
        marker = self.root / "should-not-exist"
        record.write_text(f"$(touch {marker})\n")
        self.assertNotEqual(self.run_process([self.commands / "tp-config"]).returncode, 0)
        self.assertFalse(marker.exists())

    def test_update_fast_forwards_and_refreshes_installed_commands(self):
        self.setup_tracking_checkout()
        producer = self.root / "producer"
        self.git("clone", str(self.remote), str(producer))
        self.git("config", "user.name", "Termux-Pro Tests", cwd=producer)
        self.git("config", "user.email", "tests@example.invalid", cwd=producer)
        main = producer / "bin/termux-pro"
        main.write_text(main.read_text().replace("development tools for Termux", "updated development tools"))
        self.git("add", ".", cwd=producer)
        self.git("commit", "-m", "Update fixture", cwd=producer)
        self.git("push", cwd=producer)
        expected = self.git("rev-parse", "HEAD", cwd=producer)
        self.assert_ok(self.run_process([self.commands / "tp-update"]))
        self.assertEqual(self.git("rev-parse", "HEAD"), expected)
        self.assertIn("updated development tools", self.run_process([self.commands / "tp"]).stdout)
        self.assertEqual(len(self.pkg_log.read_text().splitlines()), 2)

    def test_update_preserves_local_changes_and_untracked_files(self):
        self.setup_tracking_checkout()
        main = self.checkout / "bin/termux-pro"
        original = main.read_text()
        main.write_text(original + "# user change\n")
        before = self.git("rev-parse", "HEAD")
        self.assertNotEqual(self.run_process([self.commands / "tp-update"]).returncode, 0)
        self.assertTrue(main.read_text().endswith("# user change\n"))
        main.write_text(original)
        untracked = self.checkout / "personal-note.txt"
        untracked.write_text("keep this\n")
        self.assertNotEqual(self.run_process([self.commands / "tp-update"]).returncode, 0)
        self.assertEqual(untracked.read_text(), "keep this\n")
        self.assertEqual(self.git("rev-parse", "HEAD"), before)

    def test_update_rejects_detached_checkout(self):
        self.setup_tracking_checkout()
        self.git("checkout", "--detach")
        self.assertNotEqual(self.run_process([self.commands / "tp-update"]).returncode, 0)

    def test_update_rejects_branch_without_upstream(self):
        self.setup_tracking_checkout()
        self.git("branch", "--unset-upstream")
        self.assertNotEqual(self.run_process([self.commands / "tp-update"]).returncode, 0)

    def test_update_refuses_divergent_history_without_overwriting_local_commit(self):
        self.setup_tracking_checkout()
        producer = self.root / "producer"
        self.git("clone", str(self.remote), str(producer))
        self.git("config", "user.name", "Termux-Pro Tests", cwd=producer)
        self.git("config", "user.email", "tests@example.invalid", cwd=producer)
        (producer / "remote-change.txt").write_text("upstream change\n")
        self.git("add", ".", cwd=producer)
        self.git("commit", "-m", "Remote change", cwd=producer)
        self.git("push", cwd=producer)
        (self.checkout / "local-change.txt").write_text("local change\n")
        self.git("add", ".")
        self.git("commit", "-m", "Local change")
        before = self.git("rev-parse", "HEAD")
        result = self.run_process([self.commands / "tp-update"])
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Update complete", result.stdout)
        self.assertEqual(self.git("rev-parse", "HEAD"), before)
        self.assertEqual((self.checkout / "local-change.txt").read_text(), "local change\n")

    def test_missing_pkg_is_rejected_even_with_skip_packages(self):
        (self.commands / "pkg").unlink()
        self.assertNotEqual(self.install("--skip-packages").returncode, 0)
        self.assertFalse((self.commands / "tp").exists())

    def test_health_detects_moved_checkout(self):
        self.install_ok()
        self.checkout.rename(self.root / "moved-repository")
        result = self.run_process([self.commands / "tp-health"], cwd=self.root)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unavailable", result.stderr)

    def test_failed_pull_never_claims_update_success(self):
        self.setup_tracking_checkout()
        self.git("remote", "set-url", "origin", str(self.root / "missing.git"))
        result = self.run_process([self.commands / "tp-update"])
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Update complete", result.stdout)


    @unittest.skipIf(not hasattr(os, "geteuid") or os.geteuid() == 0,
                         "Requires an unprivileged process; CI runs this test as the runner user")
    def test_real_directory_permission_error_preserves_installation(self):
        self.install_ok()
        before = self.managed_snapshot()
        directory = self.prefix / "lib/termux-pro"
        directory.chmod(0o500)
        try:
            result = self.install("--skip-packages")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.managed_snapshot(), before)
        finally:
            directory.chmod(0o700)

    def test_health_detects_modified_installed_file_and_missing_receipt(self):
        self.install_ok()
        target = self.commands / "tp-config"
        original = target.read_text()
        target.write_text(original + "# local edit\n")
        self.assertNotEqual(self.run_process([self.commands / "tp-health"]).returncode, 0)
        target.write_text(original)
        (self.user_home / ".config/termux-pro/receipt").unlink()
        self.assertNotEqual(self.run_process([self.commands / "tp-health"]).returncode, 0)

    def test_broken_runtime_dependency_fails_before_first_install(self):
        self.write_command("curl", 'printf "incompatible shared library\\n" >&2\nexit 127\n')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Dependency cannot execute: curl", result.stderr)
        self.assertIn("pkg upgrade", result.stderr)
        self.assertEqual(self.managed_snapshot(), {})
        self.assertNotIn("Installation complete", result.stdout)

    def test_broken_runtime_dependency_preserves_existing_installation(self):
        self.install_ok()
        before = self.managed_snapshot()
        self.write_command("nvim", 'exit 127\n')
        self.assertNotEqual(self.install("--skip-packages").returncode, 0)
        self.assertEqual(self.managed_snapshot(), before)

    def test_health_rejects_present_but_broken_runtime_dependency(self):
        self.install_ok()
        self.write_command("curl", 'exit 127\n')
        result = self.run_process([self.commands / "tp-health"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unable to execute", result.stdout)

    def managed_snapshot(self):
        paths = [self.commands / name for name in COMMANDS]
        paths += [self.prefix / "lib/termux-pro/lifecycle.sh",
                  self.user_home / ".config/termux-pro/repository",
                  self.user_home / ".config/termux-pro/receipt"]
        return {str(p): (p.read_bytes(), p.stat().st_mode & 0o777)
                for p in paths if p.exists()}

    def changed_release(self):
        main = self.checkout / "bin/termux-pro"
        main.write_text(main.read_text() + "# Changed release fixture\n")

    def fail_publish_once(self, status=13, signal_name=None):
        actual_mv = shutil.which("mv")
        flag = self.root / "fault-fired"
        action = f'exit {status}\n'
        if signal_name:
            action = (f'"{actual_mv}" "$@" || exit $?\n'
                      f'kill -{signal_name} "$PPID"\nexit 0\n')
        self.write_command("mv", f'if [[ ${{@: -1}} == "$PREFIX/bin/tp-config" && ! -e "{flag}" ]]; then\n'
                           f'  : > "{flag}"\n  {action}fi\nexec "{actual_mv}" "$@"\n')

    def test_failed_upgrade_rolls_back_bytes_modes_and_registration(self):
        for status in (13, 28):
            with self.subTest(status=status):
                self.install_ok()
                before = self.managed_snapshot()
                self.changed_release()
                self.fail_publish_once(status=status)
                result = self.install("--skip-packages")
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertEqual(self.managed_snapshot(), before)
                self.assertFalse((self.commands / ".termux-pro-transaction").exists())
                self.assertNotIn("Installation complete", result.stdout)
                (self.root / "fault-fired").unlink()
                (self.commands / "mv").unlink()
                (self.commands / "mv").symlink_to(shutil.which("mv"))

    def test_failed_first_install_removes_all_partial_managed_files(self):
        self.fail_publish_once(status=28)
        self.assertEqual(self.install().returncode, 28)
        self.assertEqual(self.managed_snapshot(), {})
        self.assertFalse((self.commands / ".termux-pro-transaction").exists())

    def test_staging_out_of_space_preserves_existing_installation(self):
        self.install_ok()
        before = self.managed_snapshot()
        self.write_command("tail", 'printf "No space left on device\\n" >&2\nprintf partial\nexit 28\n')
        result = self.install("--skip-packages")
        self.assertEqual(result.returncode, 28)
        self.assertEqual(self.managed_snapshot(), before)
        self.assertFalse((self.commands / ".termux-pro-transaction").exists())

    def test_backup_permission_failure_preserves_existing_installation(self):
        self.install_ok()
        before = self.managed_snapshot()
        self.write_command("cp", 'printf "Permission denied\\n" >&2\nexit 13\n')
        self.assertEqual(self.install("--skip-packages").returncode, 13)
        self.assertEqual(self.managed_snapshot(), before)

    def test_term_signal_restores_previous_installation(self):
        self.install_ok()
        before = self.managed_snapshot()
        self.changed_release()
        self.fail_publish_once(signal_name="TERM")
        result = self.install("--skip-packages")
        self.assertEqual(result.returncode, 143)
        self.assertEqual(self.managed_snapshot(), before)
        self.assertFalse((self.commands / ".termux-pro-transaction").exists())

    def test_killed_installer_is_recovered_before_next_package_operation(self):
        self.install_ok()
        before = self.managed_snapshot()
        self.changed_release()
        self.fail_publish_once(signal_name="KILL")
        result = self.install("--skip-packages")
        self.assertEqual(result.returncode, -9)
        self.assertTrue((self.commands / ".termux-pro-transaction").exists())
        self.assertNotEqual(self.managed_snapshot(), before)
        result = self.install(env={**self.env, "TP_TEST_FAIL": "update"})
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertIn("Recovering an interrupted operation", result.stdout)
        self.assertEqual(self.managed_snapshot(), before)
        self.assertFalse((self.commands / ".termux-pro-transaction").exists())

    def test_failed_rollback_retains_backups_and_recovers_on_retry(self):
        self.install_ok()
        before = self.managed_snapshot()
        self.changed_release()
        actual_mv = shutil.which("mv")
        flag = self.root / "fault-fired"
        self.write_command("mv", f'if [[ ${{@: -1}} == "$PREFIX/bin/tp-config" && ! -e "{flag}" ]]; then\n'
                           f'  : > "{flag}"\n  exit 28\nfi\n'
                           'if [[ $1 == -f && $3 == */old/* && ${@: -1} == "$PREFIX/bin/termux-pro" ]]; then exit 13; fi\n'
                           f'exec "{actual_mv}" "$@"\n')
        result = self.install("--skip-packages")
        self.assertEqual(result.returncode, 125, result.stdout + result.stderr)
        self.assertTrue((self.commands / ".termux-pro-transaction/old/0").exists())
        (self.commands / "mv").unlink()
        (self.commands / "mv").symlink_to(actual_mv)
        result = self.install(env={**self.env, "TP_TEST_FAIL": "update"})
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertEqual(self.managed_snapshot(), before)

    def test_live_operation_lock_prevents_concurrent_install(self):
        self.install_ok()
        before = self.managed_snapshot()
        transaction = self.commands / ".termux-pro-transaction"
        transaction.mkdir()
        (transaction / "pid").write_text(str(os.getpid()) + "\n")
        result = self.install("--skip-packages")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another Termux-Pro operation", result.stderr)
        self.assertEqual(self.managed_snapshot(), before)
        self.assertTrue(transaction.exists())

    def test_uninstall_preserves_checkout_packages_settings_and_personal_files(self):
        self.install_ok()
        for name in (".bashrc", ".profile", ".git-credentials"):
            (self.user_home / name).write_text("personal content\n")
        note = self.user_home / ".config/termux-pro/my-notes.txt"
        note.write_text("keep my notes\n")
        calls = self.pkg_log.read_text()
        self.assert_ok(self.run_process([self.commands / "tp", "uninstall"]))
        self.assertEqual(self.managed_snapshot(), {})
        self.assertEqual(note.read_text(), "keep my notes\n")
        self.assertTrue((self.checkout / "install.sh").exists())
        self.assertTrue((self.commands / "git").exists())
        self.assertEqual(self.pkg_log.read_text(), calls)
        for name in (".bashrc", ".profile", ".git-credentials"):
            self.assertEqual((self.user_home / name).read_text(), "personal content\n")

    def test_uninstall_works_without_source_checkout(self):
        self.install_ok()
        shutil.rmtree(self.checkout)
        self.assert_ok(self.run_process([self.commands / "tp-uninstall"], cwd=self.root))
        self.assertEqual(self.managed_snapshot(), {})

    def test_uninstall_refuses_modified_or_unrelated_managed_files(self):
        self.install_ok()
        changed = self.commands / "tp-health"
        changed.write_text(changed.read_text() + "# personal customisation\n")
        before = self.managed_snapshot()
        result = self.run_process([self.commands / "tp-uninstall"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("local changes", result.stderr)
        self.assertEqual(self.managed_snapshot(), before)

    def test_uninstall_removal_failure_restores_the_installation(self):
        self.install_ok()
        before = self.managed_snapshot()
        actual_rm = shutil.which("rm")
        flag = self.root / "fault-fired"
        self.write_command("rm", f'if [[ ${{@: -1}} == "$PREFIX/bin/tp-config" && ! -e "{flag}" ]]; then\n'
                           f'  : > "{flag}"\n  exit 13\nfi\nexec "{actual_rm}" "$@"\n')
        self.assertEqual(self.run_process([self.commands / "tp-uninstall"]).returncode, 13)
        self.assertEqual(self.managed_snapshot(), before)
        self.assertFalse((self.commands / ".termux-pro-transaction").exists())

    def test_reinstall_refuses_to_overwrite_modified_installed_commands(self):
        self.install_ok()
        changed = self.commands / "tp-health"
        changed.write_text(changed.read_text() + "# personal customisation\n")
        before = self.managed_snapshot()
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual(self.managed_snapshot(), before)


if __name__ == "__main__":
    unittest.main()
