import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import rapier_candidate_identity


class IdentityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.lock_path = self.root / "third_party/rapier-bvh-build.lock.json"
        self.lock_path.parent.mkdir()
        (self.root / "third_party/fix.patch").write_bytes(b"patch bytes")
        self.lock = {"patch": "third_party/fix.patch", "patch_sha256": hashlib.sha256(b"patch bytes").hexdigest(),
                     "rust_toolchain": "1.98.0", "base_join_source_sha256": "original", "patched_join_source_sha256": "patched",
                     "upstream_cargo_lock_sha256": "upstream-lock"}
        self.lock_path.write_text(json.dumps(self.lock))
        self.binary = self.root / "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"
        self.binary.parent.mkdir(parents=True)
        self.binary.write_bytes(b"MZ experimental runtime")
        self.manifest = self.root / "manifest.json"
        self.record = {"schema_version": 1, "source_sha": "head", "variant": "patched", "platform": "windows", "build_inputs": self.lock,
                       "build_lock_sha256": hashlib.sha256(self.lock_path.read_bytes()).hexdigest(), "join_regression_exit": 0,
                       "rustc": "rustc 1.98.0 (test)", "join_source_sha256": "patched", "upstream_cargo_lock_sha256": "upstream-lock",
                       "artifacts": {self.binary.name: hashlib.sha256(self.binary.read_bytes()).hexdigest()}}
        self.mock = patch("rapier_candidate_identity.subprocess.check_output", return_value="head\n")
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def verify(self):
        self.manifest.write_text(json.dumps(self.record))
        return rapier_candidate_identity.verify(self.root, self.manifest)

    def test_exact_candidate(self):
        self.assertEqual(self.verify()["variant"], "patched")

    def test_original_control(self):
        self.record.update(variant="control", join_source_sha256="original", join_regression_exit=124)
        self.assertEqual(self.verify()["variant"], "control")

    def test_stale_or_drifted_provenance(self):
        for key, value in [("source_sha", "old"), ("join_source_sha256", "other"), ("upstream_cargo_lock_sha256", "other"),
                           ("build_lock_sha256", "other"), ("join_regression_exit", 1), ("variant", "unknown"), ("rustc", "rustc 1.97.0 (test)")]:
            with self.subTest(key=key):
                original = self.record[key]
                self.record[key] = value
                with self.assertRaises(RuntimeError):
                    self.verify()
                self.record[key] = original

    def test_wrong_installed_binary(self):
        self.binary.write_bytes(b"MZ another build")
        with self.assertRaises(RuntimeError):
            self.verify()

    def test_changed_patch(self):
        (self.root / "third_party/fix.patch").write_bytes(b"different patch")
        with self.assertRaises(RuntimeError):
            self.verify()


if __name__ == "__main__":
    unittest.main()
