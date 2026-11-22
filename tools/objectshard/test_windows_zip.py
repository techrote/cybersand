"""Archive admission tests; actual command-line qualification runs on Windows."""
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

import package_windows_lab
import qualify_windows_zip as probe


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


if __name__ == "__main__":
    unittest.main()
