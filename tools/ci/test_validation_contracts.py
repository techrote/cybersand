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

if __name__ == "__main__":
    unittest.main()
