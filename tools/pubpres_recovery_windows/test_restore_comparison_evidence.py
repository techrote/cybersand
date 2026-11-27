import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from restore_comparison_evidence import file_map, original_archive_settings, restore_project


class RehydrationTests(unittest.TestCase):
    def test_restore_validates_original_bytes_and_preserves_existing_receipts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            original = root / "staged"
            original.mkdir()
            (original / "original.gd.uid").write_bytes(b"uid://123\r\n")
            recorded = file_map(original)
            receipt = root / "receipt.json"
            receipt.write_bytes(b"archived original process")
            restored = root / "project"
            restore_project(original, restored, recorded, recorded)
            restore_project(original, restored, recorded, recorded)
            self.assertEqual(file_map(restored), recorded)
            (restored / "unrecorded").write_bytes(b"extra")
            with self.assertRaisesRegex(ValueError, "Existing replay project differs"):
                restore_project(original, restored, recorded, recorded)
            self.assertEqual(receipt.read_bytes(), b"archived original process")
            self.assertTrue((restored / "unrecorded").exists())

    def test_wrong_bytes_cannot_be_substituted_for_windows_archive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src = root / "original"
            src.mkdir()
            (src / "fixture.gd.uid").write_bytes(b"uid://123\r\n")
            archived = file_map(src)
            (src / "fixture.gd.uid").write_bytes(b"uid://123\n")
            with self.assertRaisesRegex(ValueError, "Committed stage differs"):
                restore_project(src, root / "project", file_map(src), archived)
            with self.assertRaisesRegex(ValueError, "Project copy changed"):
                restore_project(src, root / "project", archived, archived)
            self.assertFalse((root / "project").exists())

    def test_original_git_environment_is_scoped(self):
        with mock.patch.dict(os.environ, {"GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "user.name",
                                          "GIT_CONFIG_VALUE_0": "tester", "GIT_LFS_SKIP_SMUDGE": "0"}):
            before = dict(os.environ)
            with self.assertRaisesRegex(ValueError, "probe"):
                with original_archive_settings():
                    self.assertEqual(os.environ["GIT_CONFIG_COUNT"], "2")
                    self.assertEqual(os.environ["GIT_CONFIG_KEY_1"], "core.autocrlf")
                    self.assertEqual(os.environ["GIT_CONFIG_VALUE_1"], "true")
                    self.assertEqual(os.environ["GIT_LFS_SKIP_SMUDGE"], "1")
                    raise ValueError("probe")
            self.assertEqual(dict(os.environ), before)


if __name__ == "__main__":
    unittest.main()
