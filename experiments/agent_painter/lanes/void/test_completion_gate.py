"""Model-free positive and adversarial checkpoint promotion controls for VOID."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from completion_gate import CHECKPOINT, verify_completion


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture(root: Path) -> tuple[dict, Path]:
    checkpoint = root / CHECKPOINT
    (checkpoint / "adapter").mkdir(parents=True)
    (checkpoint / "adapter/adapter_model.safetensors").write_bytes(b"synthetic adapter fixture only")
    (checkpoint / "training_state.pt").write_bytes(b"synthetic optimizer fixture only")
    history = [{"global_step": i, "sample_cursor": i,
                "sample_id": f"synthetic-train-{i % 12}", "gradient_norm": 1.0}
               for i in range(1, 121)]
    summary = {"schema_version": 1, "status": "completed", "global_step": 120,
               "optimizer_steps_this_job": 120, "sample_cursor": 120,
               "checkpoint": CHECKPOINT, "actual_training": True,
               "checkpoint_readback_exact": True, "frozen_base_unchanged": True,
               "adapter_changed": True, "resume": None, "native_execution": False,
               "model_quality_claim": False, "config": {"synthetic": "model-free"},
               "frozen_base_sha256": "b" * 64,
               "adapter_before_sha256": "a" * 64, "adapter_after_sha256": "c" * 64,
               "sample_ids_this_job": [e["sample_id"] for e in history]}
    receipt = {"global_step": 120, "sample_cursor": 120, "config": summary["config"],
               "frozen_base_sha256": summary["frozen_base_sha256"], "history": history}
    (checkpoint / "receipt.json").write_text(json.dumps(receipt))
    inventory = {p.relative_to(checkpoint).as_posix(): {"sha256": sha(p), "bytes": p.stat().st_size}
                 for p in sorted(checkpoint.rglob("*")) if p.is_file()}
    (checkpoint / "inventory.json").write_text(json.dumps(inventory))
    summary["checkpoint_inventory_sha256"] = sha(checkpoint / "inventory.json")
    return summary, checkpoint


class GateTests(unittest.TestCase):
    def setUp(self):
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.summary, self.checkpoint = fixture(Path(self._temp.name))

    def test_positive_model_free_fixture(self):
        result = verify_completion(self.summary, 0, self.checkpoint)
        self.assertTrue(result["promotable"])
        self.assertEqual(result["verified_optimizer_receipts"], 120)
        self.assertEqual(result["verified_checkpoint_files"], 3)

    def test_partial_and_nonzero_exit_refused(self):
        for code in (1, 2, 124, 137):
            with self.subTest(code=code), self.assertRaisesRegex(ValueError, "partial/failure"):
                verify_completion(self.summary, code, self.checkpoint)
        partial = dict(self.summary, status="stopped-checkpoint-saved", global_step=40,
                       sample_cursor=40, optimizer_steps_this_job=40, checkpoint="checkpoint-000040")
        with self.assertRaisesRegex(ValueError, "status"):
            verify_completion(partial, 0, self.checkpoint)

    def test_all_summary_promotion_fields_mandatory(self):
        overrides = {"schema_version": 2, "status": "incomplete", "global_step": 119,
                     "optimizer_steps_this_job": 119, "sample_cursor": 119,
                     "checkpoint": "checkpoint-000040", "actual_training": False,
                     "checkpoint_readback_exact": False, "frozen_base_unchanged": False,
                     "adapter_changed": False, "resume": {"from_step": 40},
                     "native_execution": True, "model_quality_claim": True}
        for key, value in overrides.items():
            with self.subTest(key=key):
                bad = dict(self.summary, **{key: value})
                with self.assertRaisesRegex(ValueError, key):
                    verify_completion(bad, 0, self.checkpoint)
                del bad[key]
                with self.assertRaisesRegex(ValueError, key):
                    verify_completion(bad, 0, self.checkpoint)

    def test_boolean_or_forged_adapter_change_refused(self):
        for key in ("global_step", "sample_cursor", "optimizer_steps_this_job"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_completion(dict(self.summary, **{key: True}), 0, self.checkpoint)
        with self.assertRaisesRegex(ValueError, "adapter change"):
            verify_completion(dict(self.summary, adapter_after_sha256="a"*64), 0, self.checkpoint)

    def test_missing_or_symlinked_checkpoint_refused(self):
        with self.assertRaisesRegex(ValueError, "directory"):
            verify_completion(self.summary, 0, self.checkpoint.parent / "checkpoint-000040")
        alias = self.checkpoint.parent / "alias"
        alias.symlink_to(self.checkpoint, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "directory"):
            verify_completion(self.summary, 0, alias)

    def test_truncated_or_mutated_adapter_and_state_refused(self):
        for name in ("adapter/adapter_model.safetensors", "training_state.pt"):
            with self.subTest(name=name):
                p = self.checkpoint / name
                previous = p.read_bytes()
                p.write_bytes(previous + b"mutated")
                with self.assertRaisesRegex(ValueError, "hash or length"):
                    verify_completion(self.summary, 0, self.checkpoint)
                p.write_bytes(previous)

    def test_inventory_summary_mismatch_refused(self):
        bad = dict(self.summary, checkpoint_inventory_sha256="0"*64)
        with self.assertRaisesRegex(ValueError, "inventory differs"):
            verify_completion(bad, 0, self.checkpoint)

    def test_manifest_path_traversal_or_extra_file_refused(self):
        extra = self.checkpoint / "unexpected.dat"
        extra.write_bytes(b"unknown")
        with self.assertRaisesRegex(ValueError, "inventory disagree"):
            verify_completion(self.summary, 0, self.checkpoint)
        extra.unlink()
        inventory = json.loads((self.checkpoint / "inventory.json").read_text())
        inventory["../escaping"] = {"bytes": 1, "sha256": "f"*64}
        (self.checkpoint / "inventory.json").write_text(json.dumps(inventory))
        self.summary["checkpoint_inventory_sha256"] = sha(self.checkpoint / "inventory.json")
        with self.assertRaises(ValueError):
            verify_completion(self.summary, 0, self.checkpoint)

    def test_receipt_history_mismatch_or_nonfinite_gradient_refused(self):
        p = self.checkpoint / "receipt.json"
        orig = p.read_text()
        for transform in (lambda r: r["history"].pop(),
                          lambda r: r["history"][119].update(global_step=119),
                          lambda r: r["history"][0].update(gradient_norm=0),
                          lambda r: r.update(sample_cursor=40)):
            receipt = json.loads(orig)
            transform(receipt)
            p.write_text(json.dumps(receipt))
            inventory = json.loads((self.checkpoint / "inventory.json").read_text())
            inventory["receipt.json"] = {"sha256": sha(p), "bytes": p.stat().st_size}
            (self.checkpoint / "inventory.json").write_text(json.dumps(inventory))
            self.summary["checkpoint_inventory_sha256"] = sha(self.checkpoint / "inventory.json")
            with self.assertRaises(ValueError):
                verify_completion(self.summary, 0, self.checkpoint)
        p.write_text(orig)


if __name__ == "__main__":
    unittest.main()
