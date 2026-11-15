"""Offline checks for the read-only readiness audit."""
import os
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "readiness-audit.sh"


class ReadinessAuditTests(unittest.TestCase):
    def test_missing_termux_prefix_fails_without_modification(self):
        with tempfile.TemporaryDirectory() as root:
            home = pathlib.Path(root) / "home"
            home.mkdir()
            env = os.environ.copy()
            env.update({"HOME": str(home), "PREFIX": str(pathlib.Path(root) / "missing")})
            before = set(home.iterdir())
            result = subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertIn("FAIL Termux package manager not found", result.stdout)
            self.assertEqual(before, set(home.iterdir()))

    def test_stub_termux_environment_succeeds(self):
        with tempfile.TemporaryDirectory() as root:
            base = pathlib.Path(root)
            prefix = base / "prefix"
            (prefix / "bin").mkdir(parents=True)
            pkg = prefix / "bin" / "pkg"
            pkg.write_text("#!/bin/sh\nexit 0\n")
            pkg.chmod(0o755)
            home = base / "home"
            home.mkdir()
            env = os.environ.copy()
            env.update({"HOME": str(home), "PREFIX": str(prefix)})
            result = subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("PASS Termux package manager found", result.stdout)


if __name__ == "__main__":
    unittest.main()
