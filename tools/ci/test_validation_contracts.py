"""Regression checks: current evolution must not rewrite or disable historical integrity."""
import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest

import check_m11_consistency as legacy
import check_repository as current

class HistoricalChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((legacy.ROOT / "docs/audits/m11-retention.json").read_text(encoding="utf-8"))
        text = (legacy.ROOT / "docs/BUILD_ID.md").read_text(encoding="utf-8")
        paths = re.findall(r"^\| `([^`]+)` \| `[0-9a-f]{64}` \|$", text, re.MULTILINE)
        cls.blobs = {p: legacy.historical_blob(legacy.ROOT, p) for p in paths}

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        paths = list(self.manifest["files"]) + [self.manifest["legacy_checker"]["path"], "docs/audits/m11-retention.json"]
        for p in paths:
            target = self.root / p
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(legacy.ROOT / p, target)

    def read(self, root, relative):
        return self.blobs[relative]

    def test_current_evolution_is_separate_from_history(self):
        target = self.root / "native/src/world.cpp"
        target.parent.mkdir(parents=True)
        target.write_text("new implementation", encoding="utf-8")
        self.assertEqual(legacy.check(self.root, reader=self.read)["status"], "passed")
        strict = legacy.check(self.root, True, reader=self.read)
        self.assertEqual(strict["status"], "failed")
        self.assertIn("native/src/world.cpp", strict["working_tree_differences"])

    def test_retained_record_tampering_fails(self):
        path = self.root / "docs/audits/m11/checkpoint.json"
        path.write_bytes(path.read_bytes() + b"tampered")
        self.assertEqual(legacy.check(self.root, reader=self.read)["status"], "failed")

    def test_wrong_historical_blob_fails(self):
        self.assertEqual(legacy.check(self.root, reader=lambda *_: b"wrong revision")["status"], "failed")

    def test_missing_historical_objects_fail_closed(self):
        def missing(*_):
            raise FileNotFoundError("historical Git object unavailable")
        result = legacy.check(self.root, reader=missing)
        self.assertEqual(result["status"], "failed")
        self.assertIn("fetch full source history", result["errors"][0])

class CurrentRuntimeChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "solver.cpp").write_bytes(b"source\r\n")
        (self.root / "runtime.dll").write_bytes(b"tested-runtime")
        self.manifest = {"source_inputs": {"solver.cpp": current.digest(b"source\n")},
                         "artifact": "runtime.dll", "sha256": current.digest(b"tested-runtime"), "size":14}

    def test_matching_artifact_and_normalized_source_pass(self):
        self.assertEqual(current.verify_runtime(self.root, self.manifest), [])

    def test_source_change_requires_rebuild(self):
        (self.root / "solver.cpp").write_bytes(b"changed source")
        self.assertTrue(current.verify_runtime(self.root, self.manifest))

    def test_corrupt_runtime_fails(self):
        (self.root / "runtime.dll").write_bytes(b"corrupt")
        self.assertTrue(current.verify_runtime(self.root, self.manifest))

    def test_pointer_identity_is_distinct_from_materialization(self):
        (self.root / "runtime.dll").write_text("version https://git-lfs.github.com/spec/v1\noid sha256:" + self.manifest["sha256"] + "\nsize 14\n", encoding="utf-8", newline="\n")
        self.assertEqual(current.verify_runtime(self.root, self.manifest), [])
        self.manifest["size"] = 99
        self.assertTrue(current.verify_runtime(self.root, self.manifest))

class RapierBackportChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.build_lock = {
            "patch": "third_party/fix.patch", "patch_sha256": current.digest(b"patch\n"),
            "patched_join_source_sha256": "patched-join", "upstream_cargo_lock_sha256": "upstream-lock",
            "rust_toolchain": "1.98.0",
        }
        files = {"third_party/rapier-bvh-build.lock.json": json.dumps(self.build_lock).encode(),
                 "third_party/fix.patch": b"patch\n", "tools/ci/build_rapier_bvh_candidate.py": b"builder\n",
                 ".github/workflows/rapier-bvh-build.yml": b"workflow\n"}
        for name, data in files.items():
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        self.lock = {"runtime_overrides": {}}
        self.manifests = {}
        for platform, suffix in (("windows", "windows.x86_64-pc-windows-msvc.dll"),
                                 ("linux", "linux.x86_64-unknown-linux-gnu.so")):
            filename = "libgodot_rapier." + suffix
            artifact = "godot/addons/godot-rapier2d/bin/" + filename
            target = self.root / artifact
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"tested runtime")
            relative = f"godot/addons/godot-rapier2d/runtime-provenance.{platform}.json"
            self.lock["runtime_overrides"][platform] = relative
            self.manifests[platform] = {
                "schema_version": 1, "artifact": artifact, "build_commit": "immutable-build",
                "sha256": current.digest(b"tested runtime"), "size": len(b"tested runtime"),
                "source_inputs": {name: current.digest(data) for name, data in files.items()},
                "build_record": {
                    "schema_version": 1, "godot_version": current.GODOT,
                    "variant": "patched", "platform": platform, "source_sha": "immutable-build",
                    "build_inputs": self.build_lock,
                    "build_lock_sha256": current.digest(files["third_party/rapier-bvh-build.lock.json"]),
                    "join_source_sha256": "patched-join", "upstream_cargo_lock_sha256": "upstream-lock",
                    "join_regression_exit": 0, "rustc": "rustc 1.98.0 (fixture)",
                    "resolved_cargo_lock_sha256": "resolved-lock",
                    "artifacts": {filename: current.digest(b"tested runtime"), "Cargo.lock": "resolved-lock"},
                },
            }

    def verify(self):
        for platform, manifest in self.manifests.items():
            (self.root / self.lock["runtime_overrides"][platform]).write_text(json.dumps(manifest), encoding="utf-8")
        return current.verify_rapier_overrides(self.root, self.lock)

    def test_exact_selected_artifacts_and_immutable_build_record_pass(self):
        self.assertEqual(self.verify(), [])

    def test_blocking_control_cannot_be_selected_as_repair(self):
        self.manifests["windows"]["build_record"].update(variant="control", join_regression_exit=124)
        self.assertTrue(self.verify())

    def test_missing_build_input_coverage_fails(self):
        del self.manifests["linux"]["source_inputs"]["tools/ci/build_rapier_bvh_candidate.py"]
        self.assertTrue(self.verify())

    def test_changed_patch_requires_rebuild(self):
        (self.root / self.build_lock["patch"]).write_bytes(b"different patch\n")
        self.assertTrue(self.verify())

    def test_corrupt_selected_artifact_fails(self):
        (self.root / self.manifests["linux"]["artifact"]).write_bytes(b"other runtime")
        self.assertTrue(self.verify())

    def test_changed_build_identity_fails(self):
        record = self.manifests["linux"]["build_record"]
        for field, value in (("godot_version", "another engine"), ("schema_version", 2),
                             ("rustc", "rustc 1.97.0 (fixture)"),
                             ("resolved_cargo_lock_sha256", "changed dependency resolution"),
                             ("join_source_sha256", "other join")):
            with self.subTest(field=field):
                original = record[field]
                record[field] = value
                self.assertTrue(self.verify())
                record[field] = original

if __name__ == "__main__":
    unittest.main()
