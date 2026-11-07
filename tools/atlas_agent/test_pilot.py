"""Keyless MAP-AUTO-03 planning and independent structural acceptance regression."""
from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from atlas_agent import pilot_quality
from atlas_agent.dryrun import DryRunBackend, load_plan, _first_shot
from atlas_agent.errors import ConfigError

PLANS = Path(__file__).resolve().parent / "pilots"


class PilotTests(unittest.TestCase):
    def test_three_lane_pilots_are_bounded_and_distinct(self):
        expected = {
            "lumen-fault": ("terrain-art", "seal-gate"),
            "silt-clockworks": ("ruin-detail", "flood-beacon"),
            "drowned-observatory": ("art-curation", "broken-star-dome"),
        }
        for collection, (lane, feature) in expected.items():
            plan = load_plan(PLANS / (collection + ".json"))
            self.assertEqual((plan["collection"], plan["lane"]), (collection, lane))
            self.assertEqual(len(plan["rectangle_edits"]), 1)
            self.assertEqual(plan["rectangle_edits"][0]["feature_id"], feature)
            batches = DryRunBackend._batches(collection, plan, True, True, True)
            tools = [name for batch in batches for name, _ in batch]
            self.assertIn("view_image", tools)
            self.assertIn("pack_add_rectangles", tools)
            self.assertIn("render_capture", tools)
            self.assertIn("compare_captures", tools)
            self.assertEqual(tools[-1], "submit_report")

    def test_wide_map_uses_viewport_instead_of_oversized_full_image(self):
        listing = {"list_captures": {"bundles": {"input": {"shots": [
            {"shot_id": "full", "kind": "full", "collection": "wide",
             "verified": True, "width": 2640, "height": 560},
            {"shot_id": "viewport", "kind": "viewport", "collection": "wide",
             "verified": True, "width": 1920, "height": 1080},
            {"shot_id": "detail", "kind": "detail", "collection": "wide",
             "verified": True, "width": 1920, "height": 768},
        ]}}}}
        shot = _first_shot(listing, "wide")
        self.assertEqual(shot["shot_id"], "viewport")

    def test_malformed_rectangle_pilot_is_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            filename = Path(root) / "plan.json"
            for entry in ({"feature_id": "gate", "rectangles": [[1, 2, 3]]},
                          {"feature_id": "../gate", "rectangles": [[1, 2, 3, 4, 5.5]]}):
                filename.write_text(json.dumps({"rectangle_edits": [entry]}), encoding="utf-8")
                with self.assertRaises(ConfigError):
                    load_plan(filename)

    @staticmethod
    def base():
        return {"schema_id": "pilot-fixture", "palette": [
            {"id": 40, "name": "stone", "kernel": 0, "movable": False}],
            "scene": {"size": [40, 40]}, "features": [
                {"id": "gate", "size": [40, 40], "status": "static",
                 "variants": [], "rectangles": [[10, 10, 10, 10, 40]]},
                {"id": "cistern", "size": [40, 40], "status": "dynamic-liquid",
                 "variants": [], "rectangles": [[2, 2, 5, 5, 40]]}]}

    def test_connected_addition_is_structurally_admitted(self):
        before = self.base()
        after = copy.deepcopy(before)
        after["features"][0]["rectangles"].append([20, 10, 10, 10, 40])
        result = pilot_quality.evaluate(before, after, {"gate"})
        self.assertEqual(result["status"], "pass", result)
        self.assertEqual(result["total_new_cells"], 100)
        self.assertEqual(result["features"][0]["unsupported_components"], 0)
        self.assertEqual(result["artistic_acceptance"], "pending_independent_human_reference_review")

    def test_detached_overlay_and_cistern_changes_are_rejected(self):
        before = self.base()
        after = copy.deepcopy(before)
        after["features"][0]["rectangles"] += [[0, 0, 5, 5, 40], [15, 10, 5, 5, 40]]
        after["features"][1]["rectangles"].append([7, 2, 6, 6, 40])
        result = pilot_quality.evaluate(before, after, {"gate"})
        self.assertEqual(result["status"], "fail")
        self.assertTrue(any("overwrote" in p for p in result["problems"]), result)
        self.assertTrue(any("detached" in p for p in result["problems"]), result)
        self.assertTrue(any("non-approved" in p for p in result["problems"]), result)


if __name__ == "__main__":
    unittest.main()
