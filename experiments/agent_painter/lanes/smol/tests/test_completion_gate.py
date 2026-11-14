"""Pure SMOL fail-closed promotion tests; synthetic receipts, no model or FINAL."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "completion_gate.py"
spec = importlib.util.spec_from_file_location("smol_completion_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
SHA = "a" * 40


def fixture(root):
    root = Path(root)
    cp = root / gate.CHECKPOINT
    (cp / "adapter").mkdir(parents=True)
    (cp / "adapter" / "adapter_model.safetensors").write_bytes(b"synthetic-test-only")
    (cp / "inventory.json").write_text('{"fixture":"non-model data"}')
    config = {"source_sha": SHA, "profile": "smol",
              "native_source_sha": gate.NATIVE_SOURCE,
              "corpus_manifest_sha256": gate.CORPUS}
    summary = {
        "status": "completed", "actual_training": True,
        "global_step": 120, "sample_cursor": 120,
        "optimizer_steps_this_job": 120, "checkpoint": gate.CHECKPOINT,
        "checkpoint_readback_exact": True, "frozen_base_unchanged": True,
        "adapter_changed": True, "resume": None,
        "native_execution": False, "model_quality_claim": False,
        "config": config,
        "checkpoint_inventory_sha256": hashlib.sha256(
            (cp / "inventory.json").read_bytes()).hexdigest(),
    }
    lane = {"lane": "smol", "source_sha": SHA, "target_global_steps": 120,
            "actual_training": True, "actual_global_step": 120,
            "optimizer_steps_this_job": 120, "checkpoint": gate.CHECKPOINT,
            "checkpoint_readback_exact": True, "status": "completed",
            "exit_code": 0, "native_execution": False,
            "final_targets_opened": False}
    (root / "summary.json").write_text(json.dumps(summary))
    (root / "lane-receipt.json").write_text(json.dumps(lane))
    (cp / "receipt.json").write_text(json.dumps(
        {"global_step": 120, "sample_cursor": 120, "config": config}))
    return root


def mutate_json(path, key, value):
    obj = json.loads(path.read_text())
    obj[key] = value
    path.write_text(json.dumps(obj))


class Fresh120PromotionTests(unittest.TestCase):
    def test_complete_fresh120_is_promotable(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            verdict = gate.verify_completion(root, 0, SHA)
            self.assertTrue(verdict["promotable"])
            self.assertFalse(verdict["training"])
            self.assertFalse(verdict["final_targets_accessed"])

    def test_partial_exit_two_does_not_promote(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            with self.assertRaisesRegex(ValueError, "exit must be 0"):
                gate.verify_completion(root, 2, SHA)

    def test_partial_checkpoint_with_zero_exit_is_still_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            mutate_json(root / "summary.json", "global_step", 40)
            with self.assertRaisesRegex(ValueError, "global_step"):
                gate.verify_completion(root, 0, SHA)

    def test_completed_flag_mismatch_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            mutate_json(root / "summary.json", "status", "stopped-checkpoint-saved")
            with self.assertRaisesRegex(ValueError, "status"):
                gate.verify_completion(root, 0, SHA)

    def test_fake_bool_and_optimizer_shortfall_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            mutate_json(root / "summary.json", "optimizer_steps_this_job", True)
            with self.assertRaisesRegex(ValueError, "optimizer_steps_this_job"):
                gate.verify_completion(root, 0, SHA)

    def test_lane_receipt_contradiction_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            mutate_json(root / "lane-receipt.json", "status", "FAILED")
            with self.assertRaisesRegex(ValueError, "status"):
                gate.verify_completion(root, 0, SHA)

    def test_mutated_inventory_hash_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            (root / gate.CHECKPOINT / "inventory.json").write_text("mutated")
            with self.assertRaisesRegex(ValueError, "checkpoint_inventory_sha256"):
                gate.verify_completion(root, 0, SHA)

    def test_checkpoint_receipt_contradiction_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            mutate_json(root / gate.CHECKPOINT / "receipt.json", "sample_cursor", 119)
            with self.assertRaisesRegex(ValueError, "sample_cursor"):
                gate.verify_completion(root, 0, SHA)

    def test_missing_adapter_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            (root / gate.CHECKPOINT / "adapter" / "adapter_model.safetensors").unlink()
            with self.assertRaisesRegex(ValueError, "missing/empty"):
                gate.verify_completion(root, 0, SHA)

    def test_wrong_source_and_changed_training_lineage_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = fixture(tmp)
            with self.assertRaisesRegex(ValueError, "source_sha"):
                gate.verify_completion(root, 0, "b"*40)
            mutate_json(root / "summary.json", "resume", {"from_step": 16})
            with self.assertRaisesRegex(ValueError, "resume"):
                gate.verify_completion(root, 0, SHA)


if __name__ == "__main__":
    unittest.main()
