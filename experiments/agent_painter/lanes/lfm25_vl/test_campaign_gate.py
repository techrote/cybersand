#!/usr/bin/env python3
"""Model-free adversarial completion-gate tests. No Torch, model or FINAL inputs."""
from copy import deepcopy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from campaign_gate import validate

SOURCE = "e" * 40


def fixture(steps=48):
    config = {
        "profile": "lfm25_vl", "source_sha": SOURCE,
        "native_source_sha": "633920373a3d406a2ede61ce4137c324f76be23b",
        "corpus_manifest_sha256": "2fdef5a3639606fb9af68319f9747a1de1e9a573da5c6197a2dcbc96579cb6cc",
        "model": {"model_id": "LiquidAI/LFM2.5-VL-450M",
                  "revision": "fc6221ca597f3315e4f82fc2df606783267b34ba"},
        "numerics": {"profile": "portable-cpu-fp32-v1"},
        "device": "cpu", "dtype": "float32", "threads": 1,
        "final_targets_opened": False,
        "sample_order": [f"TRAIN-{i}" for i in range(1, 13)],
    }
    progress = [
        {"global_step": step, "sample_cursor": step,
         "sample_id": f"TRAIN-{1 + (step - 1) % 12}",
         "loss": 1 / step, "gradient_norm": 0.5, "loss_tokens": 200,
         "sequence_tokens": 245, "prompt_bytes": 90,
         "completion_bytes": 130, "seconds": 0.25}
        for step in range(1, steps + 1)
    ]
    summary = {
        "status": "completed", "actual_training": True, "global_step": steps,
        "optimizer_steps_this_job": steps, "sample_cursor": steps, "resume": None,
        "adapter_changed": True, "frozen_base_unchanged": True,
        "checkpoint_readback_exact": True, "native_execution": False,
        "model_quality_claim": False, "checkpoint": f"checkpoint-{steps:06d}",
        "adapter_before_sha256": "a" * 64, "adapter_after_sha256": "b" * 64,
        "frozen_base_sha256": "c" * 64, "config": config,
        "sample_ids_this_job": [event["sample_id"] for event in progress],
        "loss_tokens_this_job": sum(e["loss_tokens"] for e in progress),
        "sequence_tokens_this_job": sum(e["sequence_tokens"] for e in progress),
        "bytes_this_job": sum(e["prompt_bytes"] + e["completion_bytes"] for e in progress),
        "first_loss": progress[0]["loss"], "last_loss": progress[-1]["loss"],
        "runner": {"github_run_id": "43529993326"},
    }
    preflight = {"config": config, "resume": None, "train_rows": 12,
                 "trainable_parameters": 2998272}
    receipt = {"config": config, "global_step": steps, "sample_cursor": steps,
               "history": progress, "frozen_base_sha256": "c" * 64}
    return [summary, preflight, receipt, progress]


class GateTests(unittest.TestCase):
    def valid(self, items, arm="fresh48"):
        validate(*items, arm=arm, source_sha=SOURCE, run_id="43529993326")

    def test_complete_48_and_120_only(self):
        self.valid(fixture())
        self.valid(fixture(120), "fresh120")
        with self.assertRaises(ValueError):
            self.valid(fixture(48), "fresh120")

    def test_partial_rejected_even_if_checkpoint_exists(self):
        for key, value in (
            ("status", "stopped-checkpoint-saved"), ("actual_training", False),
            ("global_step", 40), ("optimizer_steps_this_job", 40),
            ("sample_cursor", 40), ("checkpoint_readback_exact", False),
        ):
            items = fixture()
            items[0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.valid(items)

    def test_wrong_model_corpus_source_and_numerical_recipe(self):
        changes = (
            ("source_sha", "a" * 40),
            ("native_source_sha", "a" * 40),
            ("corpus_manifest_sha256", "b" * 64),
            ("model", {"model_id": "substituted", "revision": "bad"}),
            ("numerics", {"profile": "unreviewed"}),
            ("final_targets_opened", True),
        )
        for key, value in changes:
            items = fixture()
            config = deepcopy(items[0]["config"])
            config[key] = value
            items[0]["config"] = items[1]["config"] = items[2]["config"] = config
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.valid(items)

    def test_checkpoint_history_and_lease_refusals(self):
        for kind in (
            "short_history", "wrong_cursor", "missing_event",
            "bad_step", "nan_gradient", "zero_gradient", "wrong_sample", "wrong_run",
        ):
            items = deepcopy(fixture())
            if kind == "short_history":
                items[2]["history"].pop()
            elif kind == "wrong_cursor":
                items[2]["sample_cursor"] = 47
            elif kind == "missing_event":
                items[3].pop()
            elif kind == "bad_step":
                items[3][3]["global_step"] = 17
            elif kind == "nan_gradient":
                items[3][0]["gradient_norm"] = float("nan")
            elif kind == "zero_gradient":
                items[3][0]["gradient_norm"] = 0.0
            elif kind == "wrong_sample":
                items[0]["sample_ids_this_job"][0] = "other"
            elif kind == "wrong_run":
                items[0]["runner"]["github_run_id"] = "other"
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.valid(items)

    def test_original_train_cycle_refusals(self):
        for kind in ("duplicate", "wrong_cycle", "missing", "short"):
            items = deepcopy(fixture())
            config = items[0]["config"]
            if kind == "duplicate":
                config["sample_order"][2] = config["sample_order"][1]
            elif kind == "wrong_cycle":
                # History/summary collusion cannot change the pinned sampler.
                items[3][15]["sample_id"] = "TRAIN-6"
                items[0]["sample_ids_this_job"][15] = "TRAIN-6"
            elif kind == "missing":
                del config["sample_order"]
            elif kind == "short":
                config["sample_order"].pop()
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.valid(items)

    def test_optimizer_aggregate_and_payload_refusals(self):
        for kind in ("loss_total", "sequence_total", "byte_total", "first_loss",
                     "last_loss", "short_sequence", "missing_bytes",
                     "nan_elapsed", "zero_completion"):
            items = deepcopy(fixture())
            summary, _, _, progress = items
            if kind == "loss_total":
                summary["loss_tokens_this_job"] -= 1
            elif kind == "sequence_total":
                summary["sequence_tokens_this_job"] += 1
            elif kind == "byte_total":
                summary["bytes_this_job"] += 1
            elif kind == "first_loss":
                summary["first_loss"] += 1
            elif kind == "last_loss":
                summary["last_loss"] += 1
            elif kind == "short_sequence":
                progress[0]["sequence_tokens"] = 199
            elif kind == "missing_bytes":
                del progress[0]["prompt_bytes"]
            elif kind == "nan_elapsed":
                progress[0]["seconds"] = float("nan")
            elif kind == "zero_completion":
                progress[0]["completion_bytes"] = 0
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.valid(items)

    def test_resumed_and_unsupported_promotion_claims_rejected(self):
        for key, value in (
            ("resume", {"from_step": 16}), ("native_execution", True),
            ("model_quality_claim", True), ("adapter_changed", False),
            ("frozen_base_unchanged", False),
        ):
            items = fixture()
            items[0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.valid(items)

    def test_workflow_gate_precedes_model_first_pass(self):
        workflow = (Path(__file__).resolve().parents[4]
                    / ".github/workflows/agent-painter-lfm25-vl-campaign.yml").read_text()
        self.assertIn("--source-sha", workflow)
        self.assertIn("--run-id", workflow)
        self.assertIn("campaign_gate.py", workflow)
        self.assertLess(workflow.index("campaign_gate.py"),
                        workflow.index("One raw original post-training first pass"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
