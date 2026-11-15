"""Offline integration checks for optional read-only project/security tools."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run_script(name, directory):
    return subprocess.run(["bash", str(ROOT / "scripts" / name), str(directory)],
                          capture_output=True, text=True, check=False)


class OptionalToolsTests(unittest.TestCase):
    def test_project_status_requires_repository(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = run_script("project-status.sh", tmp)
            self.assertEqual(result.returncode, 1)
            self.assertIn("Not a Git worktree", result.stderr)

    def test_project_status_does_not_change_worktree(self):
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(["git", "init", "-q", tmp], check=True)
            Path(tmp, "untracked.txt").write_text("keep")
            result = run_script("project-status.sh", tmp)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("untracked.txt", result.stdout)
            self.assertEqual(Path(tmp, "untracked.txt").read_text(), "keep")

    def test_security_audit_flags_public_private_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            key = Path(tmp, ".ssh", "id_ed25519")
            key.parent.mkdir()
            key.write_text("placeholder; never a real credential")
            key.chmod(0o644)
            result = run_script("security-audit.sh", tmp)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("WARN group/other permissions", result.stdout)
            self.assertNotIn("placeholder", result.stdout)
            self.assertEqual(key.stat().st_mode & 0o777, 0o644)

    def test_security_audit_accepts_private_key_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            key = Path(tmp, ".ssh", "id_ed25519")
            key.parent.mkdir()
            key.write_text("placeholder")
            key.chmod(0o600)
            result = run_script("security-audit.sh", tmp)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("PASS private permissions", result.stdout)


if __name__ == "__main__":
    unittest.main()
