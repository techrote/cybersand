"""Protect source identity and private profiles when repackaging an Art evaluator."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import package_art_workbench_final as package_tool


class EvaluatorPackaging(unittest.TestCase):
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
