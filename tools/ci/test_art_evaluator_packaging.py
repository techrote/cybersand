"""Protect source identity and private profiles when repackaging an Art evaluator."""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import package_art_workbench_final as package_tool


class EvaluatorPackaging(unittest.TestCase):
    @staticmethod
    def git(root: Path, *args: str) -> bytes:
        return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.PIPE, timeout=30)

    def commit(self, root: Path) -> None:
        self.git(root, "add", ".")
        self.git(root, "-c", "user.name=Art fixture", "-c", "user.email=fixture@invalid",
                 "commit", "-qm", "synthetic packaging source")

    @staticmethod
    def archive_files(data: bytes) -> dict[str, bytes]:
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            return {entry.name: archive.extractfile(entry).read()
                    for entry in archive if entry.isfile()}

    def test_archive_preserves_committed_import_settings_under_crlf_git_configuration(self):
        descriptors = (
            "godot/addons/godot-rapier2d/Radial2D.svg.import",
            "godot/addons/godot-rapier2d/icons/Fluid2D.svg.import",
            "godot/addons/godot-rapier2d/icons/StateManager2D.svg.import",
            "godot/addons/godot-rapier2d/logo_square_2d.png.import",
        )
        # Use the actual committed descriptors, not rewritten settings or a
        # regenerated importer default. The old export is the negative control.
        committed = {name: self.git(ROOT, "show", "HEAD:" + name) for name in descriptors}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.git(root, "init", "-q")
            self.git(root, "config", "core.autocrlf", "true")
            self.git(root, "config", "core.eol", "crlf")
            (root / ".gitattributes").write_bytes(b"* text=auto\n*.ps1 text eol=crlf\n")
            for name, data in committed.items():
                target = root / name; target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            script = "tools/explicit-crlf.ps1"
            (root / "tools").mkdir()
            (root / script).write_bytes(b"Write-Output 'explicit attribute retained'\n")
            self.commit(root)
            paths = [*descriptors, script]
            legacy = self.archive_files(self.git(root, "archive", "HEAD", "--", *paths))
            with patch.object(package_tool, "ROOT", root):
                canonical = self.archive_files(package_tool.archive_source(paths))
            for name, blob in committed.items():
                with self.subTest(descriptor=name):
                    self.assertNotIn(b"\r\n", blob)
                    self.assertEqual(legacy[name], blob.replace(b"\n", b"\r\n"))
                    self.assertNotEqual(legacy[name], blob)
                    self.assertEqual(canonical[name], blob)
            # Explicit attributes still override core.eol; no blanket newline
            # rewrite silently changes files which intentionally require CRLF.
            self.assertEqual(canonical[script], b"Write-Output 'explicit attribute retained'\r\n")
            self.assertEqual(self.git(root, "config", "core.autocrlf").strip(), b"true")
            self.assertEqual(self.git(root, "config", "core.eol").strip(), b"crlf")

    def test_archive_keeps_lfs_pointer_without_fetching_or_using_worktree_payload(self):
        try:
            self.git(ROOT, "lfs", "version")
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.skipTest("Git LFS is unavailable; hosted packaging explicitly installs it")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.git(root, "init", "-q")
            self.git(root, "lfs", "install", "--local")
            (root / ".gitattributes").write_bytes(b"*.dll filter=lfs diff=lfs merge=lfs -text\n")
            payload = b"SYNTHETIC-NATIVE-PAYLOAD-NOT-FETCHED\x00\xff"
            pointer = ("version https://git-lfs.github.com/spec/v1\n"
                       "oid sha256:" + hashlib.sha256(payload).hexdigest() + "\n"
                       "size " + str(len(payload)) + "\n").encode()
            path = "fixture.dll"; (root / path).write_bytes(pointer)
            self.commit(root)
            self.assertEqual(self.git(root, "show", "HEAD:" + path), pointer)
            # There is no remote or LFS object. A materialized working file must
            # not replace the pointer in the committed archive; build performs
            # its separate OID/size-checked Windows payload admission afterwards.
            (root / path).write_bytes(payload)
            self.assertEqual(self.git(root, "remote").strip(), b"")
            objects = root / ".git/lfs/objects"
            self.assertFalse(any(p.is_file() for p in objects.rglob("*")))
            with patch.object(package_tool, "ROOT", root), \
                    patch.dict(os.environ, {"GIT_LFS_SKIP_SMUDGE": "0"}):
                exported = self.archive_files(package_tool.archive_source([path]))
            self.assertEqual(exported, {path: pointer})
            self.assertEqual((root / path).read_bytes(), payload)
            self.assertFalse(any(p.is_file() for p in objects.rglob("*")))

    def test_import_snapshot_preserves_newlines_and_excludes_private_or_unlisted_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            relative = "godot/addons/fixture.svg.import"
            descriptor = package / relative; descriptor.parent.mkdir(parents=True)
            crlf = b'[params]\r\nsvg/scale=1.0\r\n'
            lf = crlf.replace(b"\r\n", b"\n")
            descriptor.write_bytes(crlf)
            private = package / "profile/private.import"; private.parent.mkdir()
            private.write_text("PRIVATE-OWNER-METADATA")
            (package / "godot/unlisted.import").write_text("UNLISTED-PRIVATE-METADATA")
            large = package / "godot/oversized.import"; large.write_bytes(b"x" * 65537)
            identity = {"files_sha256": {relative: hashlib.sha256(crlf).hexdigest(),
                        "profile/private.import": "unused", "godot/missing.import": "unused",
                        "godot/oversized.import": "unused"}}
            before = package_tool.import_descriptor_snapshot(package, identity)
            descriptor.write_bytes(lf)
            after = package_tool.import_descriptor_snapshot(package, identity)
            self.assertEqual(before[relative], {"bytes": len(crlf),
                             "sha256": hashlib.sha256(crlf).hexdigest(), "utf8": crlf.decode()})
            self.assertEqual(after[relative], {"bytes": len(lf),
                             "sha256": hashlib.sha256(lf).hexdigest(), "utf8": lf.decode()})
            self.assertNotEqual(before[relative]["sha256"], after[relative]["sha256"])
            self.assertEqual(set(before), {relative, "godot/missing.import", "godot/oversized.import"})
            self.assertEqual(before["godot/missing.import"], {"missing": True})
            self.assertEqual(before["godot/oversized.import"]["bytes"], 65537)
            self.assertIn("content_omitted", before["godot/oversized.import"])
            self.assertNotIn("utf8", before["godot/oversized.import"])
            invalid_utf8 = b"\xff\x00not UTF-8 metadata"
            descriptor.write_bytes(invalid_utf8)
            invalid = package_tool.import_descriptor_snapshot(package, identity)[relative]
            self.assertEqual(invalid, {"bytes": len(invalid_utf8),
                             "sha256": hashlib.sha256(invalid_utf8).hexdigest(),
                             "content_omitted": "non-UTF8 import descriptor"})
            for unsafe in ("godot/../profile/private.import", "godot/./addons/fixture.svg.import",
                           "godot//addons/fixture.svg.import", "godot/addons\\fixture.svg.import",
                           "godot/C:/profile/private.import"):
                with self.subTest(unsafe_path=unsafe), \
                        patch.object(Path, "read_bytes", side_effect=AssertionError("Unsafe descriptor was read")):
                    with self.assertRaisesRegex(ValueError, "Invalid import descriptor path"):
                        package_tool.import_descriptor_snapshot(package, {"files_sha256": {unsafe: "unused"}})
            # A manifest path outside the public Godot prefix is never read,
            # including an absolute path to otherwise readable profile data.
            with patch.object(Path, "read_bytes", side_effect=AssertionError("Profile metadata was read")):
                self.assertEqual(package_tool.import_descriptor_snapshot(
                    package, {"files_sha256": {str(private.resolve()): "unused"}}), {})

    def test_import_snapshot_rejects_symlink_escape_before_reading(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary) / "package"
            (package / "godot").mkdir(parents=True)
            private = package / "profile/private.import"; private.parent.mkdir()
            private.write_text("PRIVATE-OWNER-METADATA")
            linked_package = Path(temporary) / "linked-package"; linked_package.mkdir()
            try:
                (package / "godot/escape.import").symlink_to(private)
                (linked_package / "godot").symlink_to(private.parent, target_is_directory=True)
            except (OSError, NotImplementedError):
                self.skipTest("This host cannot create the isolated symlink fixtures")
            for candidate, relative in ((package, "godot/escape.import"),
                                        (linked_package, "godot/private.import")):
                with self.subTest(package=candidate.name, path=relative), \
                        patch.object(Path, "read_bytes", side_effect=AssertionError("Symlink target was read")):
                    with self.assertRaisesRegex(ValueError, "Invalid import descriptor path"):
                        package_tool.import_descriptor_snapshot(
                            candidate, {"files_sha256": {relative: "unused"}})

    def test_source_gate_rejects_changed_and_untracked_imports(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for directory in ("godot", "tools/ci"):
                (root / directory).mkdir(parents=True)
            (root / "godot/main.gd").write_text("extends Node\n")
            helper = root / "tools/ci/helper.py"
            helper.write_text("SOURCE = 'committed'\n")
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "-c", "user.name=Art fixture", "-c", "user.email=fixture@invalid",
                            "commit", "-qm", "synthetic source"], cwd=root, check=True)
            with patch.object(package_tool, "ROOT", root):
                package_tool.check_source_inputs(["godot"])
                helper.write_text("SOURCE = 'changed'\n")
                with self.assertRaisesRegex(ValueError, "Commit application"):
                    package_tool.check_source_inputs(["godot"])
                helper.write_text("SOURCE = 'committed'\n")
                shadow = root / "tools/untracked_dependency.py"
                shadow.write_text("SOURCE = 'untracked'\n")
                with self.assertRaisesRegex(ValueError, "Commit application"):
                    package_tool.check_source_inputs(["godot"])
                shadow.unlink()
                (root / "godot/main.gd.uid").write_text("uid://synthetic-import\n")
                package_tool.check_source_inputs(["godot"])
                (root / "godot/untracked.gd").write_text("extends Node\n")
                with self.assertRaisesRegex(ValueError, "Commit application"):
                    package_tool.check_source_inputs(["godot"])

    def test_zip_excludes_owner_profile_and_generated_diagnostics(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary) / "Art evaluator with spaces"
            package.mkdir()
            source = package / "application.txt"
            source.write_bytes(b"immutable source fixture")
            identity = {"schema":"art-workbench-final-evaluator-v1", "files_sha256":{
                "application.txt":hashlib.sha256(source.read_bytes()).hexdigest()}}
            (package / package_tool.MANIFEST).write_text(json.dumps(identity))
            canary = "PRIVATE-OWNER-PROFILE-DO-NOT-DELIVER"
            for relative in ("profile/art-provider.cfg", "profile-local/private.txt",
                             "diagnostics/art-responsiveness.json", "godot/.godot/generated-cache"):
                path = package / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(canary)
            result = subprocess.run([sys.executable, str(ROOT / "tools/package_art_workbench_final.py"),
                                     "zip", "--output", str(package)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            with zipfile.ZipFile(package.with_suffix(".zip")) as archive:
                self.assertEqual(set(archive.namelist()), {
                    package.name + "/application.txt", package.name + "/" + package_tool.MANIFEST})
                for name in archive.namelist():
                    self.assertNotIn(canary.encode(), archive.read(name))
            self.assertTrue(package.with_suffix(".zip.sha256").is_file())

    def test_changed_immutable_payload_is_refused(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            source = package / "application.txt"
            source.write_bytes(b"original")
            (package / package_tool.MANIFEST).write_text(json.dumps({
                "schema":"art-workbench-final-evaluator-v1", "files_sha256":{
                    "application.txt":hashlib.sha256(source.read_bytes()).hexdigest()}}))
            package_tool.verify(package)
            source.write_bytes(b"changed after manifest")
            with self.assertRaisesRegex(ValueError, "Packaged file changed"):
                package_tool.verify(package)


if __name__ == "__main__":
    unittest.main()
