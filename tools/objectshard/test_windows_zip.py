"""Archive admission tests; actual command-line qualification runs on Windows."""
from pathlib import Path
import io
import json
import subprocess
import tempfile
import unittest
from unittest import mock
import zipfile

import package_windows_lab
import qualify_windows_zip as probe
import test_package_verifier


class WindowsZipTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_launcher_refuses_nonexact_source_before_generating_commands(self):
        for value in ("HEAD", "abc123", '" & unexpected-command', "f" * 41):
            with self.assertRaises(ValueError):
                package_windows_lab.launchers(value)

    def test_archive_preserves_unicode_and_parentheses(self):
        archive = self.root / "evaluation.zip"
        with zipfile.ZipFile(archive, "w") as stream:
            stream.writestr("ObjectShard_日本語_é (1)/source.txt", "unchanged source\n")
        probe.extract(archive, self.root / "output")
        self.assertEqual((self.root / "output/ObjectShard_日本語_é (1)/source.txt").read_text(), "unchanged source\n")

    def test_archive_traversal_cannot_write_outside_extraction(self):
        for member in ("../outside.txt", "/outside.txt", "C:/outside.txt", "folder\\..\\outside.txt"):
            archive = self.root / "invalid.zip"
            with zipfile.ZipFile(archive, "w") as stream:
                stream.writestr(member, "must not be written")
            with self.assertRaisesRegex(ValueError, "Unsafe ZIP member"):
                probe.extract(archive, self.root / "output")
            self.assertFalse((self.root / "outside.txt").exists())

    def test_archive_symlink_refused(self):
        archive = self.root / "invalid.zip"
        item = zipfile.ZipInfo("link")
        item.external_attr = 0o120777 << 16
        with zipfile.ZipFile(archive, "w") as stream:
            stream.writestr(item, "../outside")
        with self.assertRaisesRegex(ValueError, "symlinks"):
            probe.extract(archive, self.root / "output")

    def test_linux_cannot_supply_windows_execution_evidence(self):
        with mock.patch.object(probe.sys, "platform", "linux"):
            with self.assertRaisesRegex(ValueError, "actual Windows"):
                probe.qualify(self.root / "missing.zip", self.root / "output")

    def test_successful_unicode_report_survives_windows_legacy_console(self):
        report = {"status": "passed", "root": "ObjectShard_日本語_é (1)"}
        output = io.BytesIO()
        console = io.TextIOWrapper(output, encoding="cp1252")
        try:
            with mock.patch.object(probe, "qualify", return_value=report), \
                 mock.patch.object(probe.sys, "argv", ["qualify_windows_zip.py", "--zip", "fixture.zip", "--output", str(self.root)]), \
                 mock.patch.object(probe.sys, "stdout", console):
                probe.main()
            console.flush()
            self.assertEqual(json.loads(output.getvalue().decode("cp1252")), report)
        finally:
            console.detach()

    def _verifier_fixture(self):
        # Reuse the deliberately synthetic inventory; these tests establish
        # restoration/failure semantics, never execution of a real Windows CMD.
        fixture = test_package_verifier.PackageVerifierTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        return fixture.root

    def test_tamper_probe_restores_exact_inventory_after_expected_hash_refusal(self):
        target = self._verifier_fixture()
        original = (target / "READ-ME.md").read_bytes()

        def execute(command, **_kwargs):
            if command[0] == "powershell.exe":
                return subprocess.CompletedProcess(command, 0, b"package PASS")
            self.assertNotEqual((target / "READ-ME.md").read_bytes(), original)
            return subprocess.CompletedProcess(command, 1, b"Package file changed: READ-ME.md\r\n")

        with mock.patch.object(probe.subprocess, "run", side_effect=execute):
            report = probe.qualify_verifier_adversaries(target, self.root, 1)
        self.assertTrue(report["specific_hash_failure_observed"])
        self.assertEqual((target / "READ-ME.md").read_bytes(), original)
        self.assertTrue(report["after_restoration_inventory_verified"])

    def test_tamper_probe_restores_exact_inventory_after_timeout(self):
        target = self._verifier_fixture()
        original = (target / "READ-ME.md").read_bytes()
        results = [subprocess.CompletedProcess(["powershell.exe"], 0, b"package PASS"),
                   subprocess.TimeoutExpired(["cmd.exe"], 1)]
        with mock.patch.object(probe.subprocess, "run", side_effect=results):
            with self.assertRaises(subprocess.TimeoutExpired):
                probe.qualify_verifier_adversaries(target, self.root, 1)
        self.assertEqual((target / "READ-ME.md").read_bytes(), original)
        probe.verify(target)

    def test_non_hash_failure_cannot_pass_the_tamper_gate(self):
        target = self._verifier_fixture()
        original = (target / "READ-ME.md").read_bytes()
        results = [subprocess.CompletedProcess(["powershell.exe"], 0, b"package PASS"),
                   subprocess.CompletedProcess(["cmd.exe"], 1, b"Get-FileHash is not recognized")]
        with mock.patch.object(probe.subprocess, "run", side_effect=results):
            with self.assertRaisesRegex(ValueError, "specifically reject"):
                probe.qualify_verifier_adversaries(target, self.root, 1)
        self.assertEqual((target / "READ-ME.md").read_bytes(), original)
        probe.verify(target)


if __name__ == "__main__":
    unittest.main()
