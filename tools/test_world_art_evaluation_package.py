"""Focused publication and portability guards for the World Art evaluator."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

try:
    from tools import world_art_evaluation_package as package
except ModuleNotFoundError:
    import world_art_evaluation_package as package


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def fixture(self) -> Path:
        root = self.root / "package"
        root.mkdir()
        for name in ("Open World Art.cmd", "Open Gallery.cmd", "Capture example.cmd", "Gallery.html", "godot/project.godot"):
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("fixture " + name, encoding="utf-8")
        engine = root / "engine.exe"
        engine.write_bytes(b"test package publication bytes, not a runtime")
        self.pins = {"engine.exe": package.support.sha256_file(engine)}
        manifest = package.support.seal_manifest({
            "schema": package.SCHEMA, "status": "complete", "source_commit": "a" * 40,
            "godot_files_sha256": self.pins, "source_files_sha256": {},
            "files_sha256": package.inventory(root),
        })
        (root / package.MANIFEST).write_text(json.dumps(manifest), encoding="utf-8")
        return root

    def test_path_names_reject_escape_and_windows_alternate_paths(self):
        for name in ("../x", "/x", "C:/x", "one/../two", "one\\two", "a//b", "./x", "a:stream"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                package.relative_name(name)
        self.assertEqual(package.relative_name("evidence/scenes/one.png"), "evidence/scenes/one.png")

    def test_verifier_detects_changed_missing_and_added_payload(self):
        root = self.fixture()
        with patch.object(package, "ENGINES", self.pins):
            package.verify(root)
            original = (root / "Gallery.html").read_bytes()
            (root / "Gallery.html").write_bytes(b"tampered")
            with self.assertRaisesRegex(ValueError, "inventory/hash mismatch"):
                package.verify(root)
            (root / "Gallery.html").write_bytes(original)
            (root / "unexpected.bin").write_bytes(b"extra")
            with self.assertRaisesRegex(ValueError, "inventory/hash mismatch"):
                package.verify(root)
            (root / "unexpected.bin").unlink()
            (root / "Open World Art.cmd").unlink()
            with self.assertRaisesRegex(ValueError, "inventory/hash mismatch"):
                package.verify(root)

    def test_verifier_allows_only_godot_runtime_cache_outside_ledger(self):
        root = self.fixture()
        cache = root / "godot/.godot/shader_cache/cache.bin"
        cache.parent.mkdir(parents=True)
        cache.write_bytes(b"generated")
        with patch.object(package, "ENGINES", self.pins):
            package.verify(root)
            (root / "godot/other-cache.bin").write_bytes(b"unaccounted")
            with self.assertRaises(ValueError):
                package.verify(root)

    def test_archive_never_overwrites_and_excludes_runtime_cache(self):
        root = self.fixture()
        cache = root / "godot/.godot/cache.bin"
        cache.parent.mkdir()
        cache.write_bytes(b"regenerated")
        target = self.root / "package.zip"
        with patch.object(package, "ENGINES", self.pins):
            package.archive(root, target)
            before = target.read_bytes()
            with self.assertRaises(FileExistsError):
                package.archive(root, target)
            self.assertEqual(before, target.read_bytes())
            with zipfile.ZipFile(target) as archive:
                self.assertNotIn("CyberSand-World-Art/godot/.godot/cache.bin", archive.namelist())
                self.assertIn("CyberSand-World-Art/" + package.MANIFEST, archive.namelist())

    def test_copy_refuses_symlinked_evidence(self):
        source = self.root / "evidence"
        source.mkdir()
        (self.root / "outside.txt").write_text("untrusted", encoding="utf-8")
        try:
            (source / "link.txt").symlink_to(self.root / "outside.txt")
        except OSError:
            self.skipTest("host does not permit creating symbolic links")
        with self.assertRaisesRegex(ValueError, "symbolic link"):
            package.copy_regular_tree(source, self.root / "copy")

    def test_viewer_source_must_match_final_commit_and_each_file(self):
        hashes = {"godot/" + name: str(index) for index, name in enumerate(package.launcher.FILES)}
        hashes.update({"tools/world_art_preview_launcher.py": "launcher", "tools/world_art_capture_support.py": "support",
                       "tools/world_art_stream_png.py": "stream"})
        batch = {"source_guard": {"unchanged": True}, "viewer": {"git_revision": "final",
            "files": {name: hashes["godot/" + name] for name in package.launcher.FILES},
            "launcher_sha256": "launcher", "capture_support_sha256": "support", "stream_png_sha256": "stream"}}
        package.viewer_matches(batch, hashes, "final")
        with self.assertRaisesRegex(ValueError, "commit differs"):
            package.viewer_matches(batch, hashes, "other")
        batch["viewer"]["files"][package.launcher.FILES[0]] = "stale"
        with self.assertRaisesRegex(ValueError, "source hashes differ"):
            package.viewer_matches(batch, hashes, "final")

    def test_launchers_use_relative_bundle_paths_and_do_not_download(self):
        package.write_launchers(self.root, "a" * 40, True)
        viewer = (self.root / "Open World Art.cmd").read_text(encoding="utf-8")
        capture = (self.root / "Capture example.cmd").read_text(encoding="utf-8")
        self.assertIn('"%~dp0Godot_v4.7-stable_win64_console.exe"', viewer)
        self.assertIn('"%~dp0dependencies\\python\\python.exe"', capture)
        self.assertIn('--output-dir "%~1"', capture)
        self.assertNotIn("http", viewer + capture)


if __name__ == "__main__":
    unittest.main()
