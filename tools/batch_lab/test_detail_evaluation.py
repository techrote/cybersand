"""Adversarial custody and independent geometry checks for detail reduction."""
import base64
import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest

from evaluate_detail_jobs import (REGISTRATION_SHA256, accepted_edit_replay,
                                 evaluate, evaluate_case, geometry_metrics, read_bound, sha)


class DetailEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.source = "a" * 40
        self.before = [0] * 4096
        self.before[4 * 64 + 4] = 58
        self.after = self.before.copy()
        self.after[4 * 64 + 5] = 28
        self.context = {"job_region": [4, 4, 8, 8], "protected": [[1, 1, 2, 2]],
                        "fixed_regions": [], "variable_regions": [], "attachment_cells": [[4, 4]],
                        "clearances": [[20, 20, 3, 3]]}
        before, after = (struct.pack("<4096H", *plane) for plane in (self.before, self.after))
        self.native = {"state": "completed", "config": {"extent": [64, 64]},
                       "source_materials_base64": base64.b64encode(before).decode(),
                       "material_cells_base64": base64.b64encode(after).decode(), "material_sha256": sha(after),
                       "provenance": {"source_material_sha256": sha(before), "source_revision": self.source,
                                      "native_binary_sha256": "b" * 64},
                       "accepted_edits": [[5, 4, 1, 1, 28]],
                       "receipts": [{"backend": "CyberNativeCellWorld", "status": "completed", "requested": 1,
                                     "checked": 1, "changed": 1, "unchanged": 0, "confirmed": 1, "excluded": 0, "refused": 0}]}
        self.recipe = {"input_snapshot_sha256": sha(before),
                       "operations": [{"shape": "pixels", "material": 28, "points": [[5, 4]]}]}
        program = json.dumps(self.recipe["operations"], sort_keys=True, separators=(",", ":")).encode()
        self.row = {"id": "contextual-ribs-deterministic", "job": "contextual_ribs", "arm": "deterministic",
                    "seed": 0, "extent": [64, 64], "status": "completed", "context": self.context,
                    "source_sha256": sha(before), "projection_sha256": sha(after), "program_sha256": sha(program),
                    "before": self.store("before.u16le", before), "after": self.store("after.u16le", after),
                    "native_record": self.store_json("native.json", self.native),
                    "recipe": self.store_json("recipe.json", self.recipe)}
        self.row["before"]["encoding"] = self.row["after"]["encoding"] = "u16le"

    def tearDown(self): self.temporary.cleanup()

    def store(self, name, raw):
        (self.base / name).write_bytes(raw)
        return {"path": name, "sha256": sha(raw)}

    def store_json(self, name, value):
        return self.store(name, json.dumps(value, separators=(",", ":")).encode())

    def result(self): return evaluate_case(self.row, self.base, self.source)

    def mutate_native(self, action):
        action(self.native)
        self.row["native_record"] = self.store_json("native.json", self.native)

    def test_complete_receipts_planes_and_replay(self):
        result = self.result()
        self.assertTrue(result["evaluable"], result)
        self.assertTrue(result["exact_compiled_projection_match"])
        self.assertEqual(result["metrics"]["source_anchored_components"], 1)

    def test_hash_tampering(self):
        self.row["after"]["sha256"] = "0" * 64
        self.assertFalse(self.result()["evaluable"])

    def test_escape_and_symlink_paths(self):
        with self.assertRaises(ValueError): read_bound(self.base, {"path": "../outside", "sha256": "0" * 64}, 100)
        (self.base / "escape").symlink_to(self.base.parent)
        with self.assertRaises(ValueError): read_bound(self.base, {"path": "escape/outside", "sha256": "0" * 64}, 100)

    def test_wrong_native_source(self):
        self.mutate_native(lambda native: native["provenance"].update(source_revision="c" * 40))
        self.assertFalse(self.result()["evaluable"])

    def test_queued_receipt_is_not_completion(self):
        self.mutate_native(lambda native: native["receipts"][0].update(status="queued"))
        self.assertFalse(self.result()["evaluable"])

    def test_boolean_receipt_counter_refuses(self):
        self.mutate_native(lambda native: native["receipts"][0].update(changed=True))
        self.assertFalse(self.result()["evaluable"])

    def test_missing_receipt_and_wrong_native_history(self):
        self.mutate_native(lambda native: native.update(receipts=[]))
        self.assertFalse(self.result()["evaluable"])
        with self.assertRaises(ValueError): accepted_edit_replay({"accepted_edits": []}, self.before, self.after, 64, 64)

    def test_oversized_history_refuses(self):
        with self.assertRaises(ValueError): accepted_edit_replay({"accepted_edits": [[0, 0, 64, 64, 28]]}, self.before, self.after, 64, 64)

    def test_wrong_program_identity(self):
        self.row["program_sha256"] = "0" * 64
        self.assertFalse(self.result()["evaluable"])

    def test_wrong_projection_is_reported_not_hidden(self):
        self.row["projection_sha256"] = "0" * 64
        result = self.result()
        self.assertTrue(result["evaluable"])
        self.assertFalse(result["exact_compiled_projection_match"])

    def test_floating_cluster_is_independent_of_cell_count(self):
        detached = self.before.copy(); detached[8 * 64 + 8] = 28
        metrics = geometry_metrics(self.before, detached, self.context, "contextual_ribs", 64, 64)
        self.assertEqual(metrics["changed_cells"], 1)
        self.assertEqual(metrics["unanchored_added_cells"], 1)
        self.assertTrue(metrics["constraints_preserved"])

    def test_guard_and_clearance_violations_are_measured(self):
        changed = self.after.copy(); changed[1 * 64 + 1] = 28; changed[20 * 64 + 20] = 28; changed[4 * 64 + 4] = 0
        metrics = geometry_metrics(self.before, changed, self.context, "contextual_ribs", 64, 64)
        self.assertEqual(metrics["protected_changed_cells"], 1)
        self.assertEqual(metrics["attachment_changed_cells"], 1)
        self.assertEqual(metrics["clearance_occupied_cells"], 1)
        self.assertFalse(metrics["constraints_preserved"])

    def test_wear_requires_variable_hardwall(self):
        changed = self.before.copy(); changed[4 * 64 + 4] = 0
        context = copy.deepcopy(self.context); context["attachment_cells"] = []
        metrics = geometry_metrics(self.before, changed, context, "edge_wear", 64, 64)
        self.assertEqual(metrics["invalid_source_write_cells"], 1)
        context["variable_regions"] = [[4, 4, 1, 1]]
        self.assertTrue(geometry_metrics(self.before, changed, context, "edge_wear", 64, 64)["constraints_preserved"])

    def test_malformed_case_does_not_crash(self):
        for malformed in (None, [], {"id": [], "status": []}, {**self.row, "before": []}):
            self.assertFalse(evaluate_case(malformed, self.base, self.source)["evaluable"])

    def test_registration_and_fixed_denominator(self):
        registration = Path(__file__).resolve().parents[2] / "godot/data/batch_lab/m67/detail-experiment.v1.json"
        raw = registration.read_bytes()
        self.assertEqual(sha(raw), REGISTRATION_SHA256)
        report = {"format": "cybersand-native-detail-comparison-evidence-v1", "source_revision": self.source,
                  "registration_sha256": REGISTRATION_SHA256, "cases": [self.row], "model_calls": False}
        reduced = evaluate(report, self.base, raw)
        self.assertEqual(len(reduced["cases"]), 24)
        self.assertEqual(reduced["evaluable_cases"], 1)
        self.assertIsNone(reduced["model_calls"])
        with self.assertRaises(ValueError): evaluate(report, self.base, raw + b" ")


if __name__ == "__main__": unittest.main()
