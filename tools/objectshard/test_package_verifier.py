"""Synthetic custody failures; these fixtures do not qualify a real DLL."""
import json
from pathlib import Path
import tempfile
import unittest

import verify_package as verifier


class PackageVerifierTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)
        for name in verifier.REQUIRED | {"native/src/object_shard.cpp"}:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(("synthetic fixture: " + name + "\n").encode())
        inputs = {"native/src/object_shard.cpp": verifier.digest(self.root / "native/src/object_shard.cpp")}
        candidate = {"source_commit": "1" * 40, "source_tree": "2" * 40, "source_inputs": inputs,
                     "sha256": verifier.digest(self.root / verifier.NATIVE)}
        (self.root / "source-built-candidate-provenance.json").write_text(json.dumps(candidate))
        files = {p.relative_to(self.root).as_posix(): verifier.digest(p) for p in self.root.rglob("*") if p.is_file()}
        self.manifest = {"schema": "objectshard-lab-package-v1", "source_commit": "1" * 40, "source_tree": "2" * 40,
            "files_sha256": files, "native": {"path": verifier.NATIVE, "sha256": files[verifier.NATIVE], "source_inputs": inputs},
            "rapier": {"path": verifier.RAPIER, "sha256": files[verifier.RAPIER]},
            "godot": {"version": "4.7.stable.official.5b4e0cb0f", "runtime_sha256": files["Godot_v4.7-stable_win64.exe"],
                      "console_sha256": files["Godot_v4.7-stable_win64_console.exe"]},
            "vc_runtime_sha256": files["vcruntime140.dll"]}
        self.write_manifest()

    def write_manifest(self):
        (self.root / verifier.MANIFEST).write_text(json.dumps(self.manifest))

    def test_complete_synthetic_bundle(self):
        self.assertEqual(verifier.verify(self.root)["source_commit"], "1" * 40)

    def test_changed_native_bytes(self):
        (self.root / verifier.NATIVE).write_bytes(b"changed runtime")
        with self.assertRaisesRegex(ValueError, "Package file changed"):
            verifier.verify(self.root)

    def test_missing_file(self):
        (self.root / "godot/object_shard_lab.tscn").unlink()
        with self.assertRaisesRegex(ValueError, "Missing or external"):
            verifier.verify(self.root)

    def test_omitted_required_file_cannot_be_hidden_by_inventory(self):
        del self.manifest["files_sha256"]["godot/object_shard_lab.tscn"]
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Incomplete package inventory"):
            verifier.verify(self.root)

    def test_source_change_even_when_package_manifest_is_updated(self):
        name = "native/src/object_shard.cpp"
        (self.root / name).write_bytes(b"new source\n")
        self.manifest["files_sha256"][name] = verifier.digest(self.root / name)
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Native source differs"):
            verifier.verify(self.root)

    def test_stale_candidate_commit(self):
        name = "source-built-candidate-provenance.json"
        candidate = json.loads((self.root / name).read_text())
        candidate["source_commit"] = "3" * 40
        (self.root / name).write_text(json.dumps(candidate))
        self.manifest["files_sha256"][name] = verifier.digest(self.root / name)
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Candidate source identity"):
            verifier.verify(self.root)

    def test_external_path_refused(self):
        self.manifest["files_sha256"]["../outside"] = "a" * 64
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Unsafe package path"):
            verifier.verify(self.root)

    def test_wrong_engine_identity(self):
        self.manifest["godot"]["runtime_sha256"] = "4" * 64
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, "Windows engine file identity"):
            verifier.verify(self.root)


if __name__ == "__main__":
    unittest.main()
