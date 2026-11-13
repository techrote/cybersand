"""Publication corruption checks only; these fixtures are never training proof."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

LANE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LANE))
SPEC = importlib.util.spec_from_file_location("smol_package", LANE / "package.py")
package = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package)


class PublicationCustody(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source, self.tree, self.run, self.attempt = "a" * 40, "b" * 40, 12345, 2
        self.request = {"purpose": "unit-test protocol metadata only"}
        selected = package.common.profile("smol", require_supported=True)
        for arm in package.ARMS:
            folder = self.root / arm / "environment"
            folder.mkdir(parents=True)
            receipt = {
                "schema_version": 1, "lane": "smol", "arm": arm,
                "repository": package.REPOSITORY, "source_sha": self.source, "source_tree": self.tree,
                "run_id": self.run, "run_attempt": self.attempt, "job_id": "models",
                "runner_name": "test-runner-" + arm, "hostname": "test-vm-" + arm,
                "runner_environment": "github-hosted", "os": "Linux", "arch": "X64",
                "corpus": {"source_sha": package.contracts.FOUNDATION_SOURCE,
                           "run_id": package.CORPUS_RUN, "artifact": package.CORPUS_ARTIFACT},
                "model": {"model_id": package.contracts.MODEL_ID, "revision": package.contracts.MODEL_REVISION},
                "request": self.request,
            }
            self.write(folder / "run-receipt.json", receipt)
            self.write(folder / "model-download.json", {
                "model_id": selected["model_id"], "revision": selected["revision"], "trust_remote_code": False,
                "files": {name: {"sha256": digest, "bytes": 1} for name, digest in selected["required_hashes"].items()},
            })
            for name in ("cpu.txt", "pip-freeze.txt"):
                (folder / name).write_text("unit-test metadata; no model execution\n")
            (folder / "requirements.sha256").write_text(package.sha(package.PAINTER / "training/requirements.lock") + "  requirements.lock\n")

    def tearDown(self):
        self.temp.cleanup()

    def write(self, path, value):
        path.write_text(json.dumps(value))

    def verify(self):
        return package.verify_environments(self.root, self.source, self.tree, self.run, self.attempt, self.request)

    def mutate_receipt(self, arm, key, value):
        path = self.root / arm / "environment/run-receipt.json"
        receipt = json.loads(path.read_text())
        receipt[key] = value
        self.write(path, receipt)

    def test_matching_custody_accepts_distinct_vm_metadata(self):
        receipts, _ = self.verify()
        self.assertNotEqual(receipts["baseline"]["hostname"], receipts["candidate"]["hostname"])

    def test_same_vm_refused(self):
        self.mutate_receipt("candidate", "hostname", "test-vm-baseline")
        with self.assertRaisesRegex(ValueError, "separate hosted VMs"):
            self.verify()

    def test_wrong_source_or_run_attempt_refused(self):
        for key, value in (("source_sha", "c" * 40), ("run_attempt", 1), ("run_id", 999)):
            with self.subTest(key=key):
                path = self.root / "candidate/environment/run-receipt.json"
                original = json.loads(path.read_text())
                self.mutate_receipt("candidate", key, value)
                with self.assertRaisesRegex(ValueError, "custody mismatch"):
                    self.verify()
                self.write(path, original)

    def test_changed_base_model_bytes_refused(self):
        path = self.root / "candidate/environment/model-download.json"
        download = json.loads(path.read_text())
        name = next(iter(download["files"]))
        download["files"][name]["sha256"] = "0" * 64
        self.write(path, download)
        with self.assertRaisesRegex(ValueError, "reviewed pin"):
            self.verify()


class ArchiveCustody(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.evidence = self.root / "evidence"
        self.evidence.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_original_bytes_survive_zip_readback_and_output_is_immutable(self):
        original = b"original binary evidence\x00\xff\n"
        (self.evidence / "readback.bin").write_bytes(original)
        output = self.root / "evidence.zip"
        result = package.archive(output, package.inventory_files(self.evidence))
        self.assertEqual(package.sha(output), result["sha256"])
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(archive.read("readback.bin"), original)
            self.assertIsNone(archive.testzip())
        with self.assertRaisesRegex(ValueError, "overwrite"):
            package.archive(output, package.inventory_files(self.evidence))

    def test_final_target_refused(self):
        (self.evidence / "final.jsonl").write_text("unit test sentinel\n")
        with self.assertRaisesRegex(ValueError, "FINAL targets"):
            package.inventory_files(self.evidence)

    def test_symlink_refused(self):
        outside = self.root / "outside.txt"
        outside.write_text("outside fixture")
        (self.evidence / "link.txt").symlink_to(outside)
        with self.assertRaisesRegex(ValueError, "symlink"):
            package.inventory_files(self.evidence)

    def test_unsafe_zip_member_refused(self):
        path = self.evidence / "receipt.json"
        path.write_text("{}")
        with self.assertRaisesRegex(ValueError, "unsafe archive member"):
            package.archive(self.root / "invalid.zip", [("../escaped.json", path)])

    def test_checkpoint_inventory_tampering_refused_before_tensor_load(self):
        checkpoint = self.evidence / "checkpoint-000001"
        (checkpoint / "adapter").mkdir(parents=True)
        names = ("adapter/adapter_model.safetensors", "adapter/adapter_config.json", "training_state.pt", "receipt.json")
        for name in names:
            (checkpoint / name).write_bytes(b"unit-test inventory fixture only")
        inventory = {name: {"sha256": package.sha(checkpoint / name), "bytes": (checkpoint / name).stat().st_size}
                     for name in names}
        (checkpoint / "inventory.json").write_text(json.dumps(inventory))
        (checkpoint / "training_state.pt").write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "custody hash mismatch"):
            package.common.verify_checkpoint(checkpoint)

    def test_missing_or_failed_retained_regression_refused(self):
        labels = ("art_batch", "stored_material", "deferred_manual", "undo_1", "undo_4",
                  "combined_author", "combined_reopen")
        results = [{"label": label, "status": "passed", "exit_code": 0,
                    "completion": {"checks": 1, "failures": 0}} for label in labels]
        for label in labels:
            (self.evidence / (label + ".log")).write_text("unit-test protocol metadata\n")
        path = self.evidence / "results.json"
        path.write_text(json.dumps(results))
        self.assertEqual(package.verify_regressions(self.evidence)["checks"], 7)
        path.write_text(json.dumps(results[:-1]))
        with self.assertRaisesRegex(ValueError, "inventory differs"):
            package.verify_regressions(self.evidence)
        results[0]["completion"]["failures"] = 1
        path.write_text(json.dumps(results))
        with self.assertRaisesRegex(ValueError, "regression failed"):
            package.verify_regressions(self.evidence)


if __name__ == "__main__":
    unittest.main()
