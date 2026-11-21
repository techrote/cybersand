#!/usr/bin/env python3
"""Regression witnesses for the exact-pixel and component evidence boundaries."""
from __future__ import annotations

import copy
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image

import gentek80_campaign as campaign


class EvidenceBoundaries(unittest.TestCase):
    def test_diagonal_contact_is_not_a_cardinal_connection(self):
        # The central pixel touches the corner pixels only by diagonal edges.
        mask = bytes([1, 0, 1, 0, 1, 0, 1, 0, 1])
        result = campaign.component_metrics(mask, 3, 3, 1)
        self.assertEqual(result["count"], 5)
        self.assertEqual(result["isolated_single_cells"], 5)
        self.assertEqual(result["touching_crop_boundary_cells"], 4)
        self.assertEqual(result["total_cells"], 5)

    def test_bridge_joins_multiple_preceding_runs(self):
        mask = bytes([1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1])
        result = campaign.component_metrics(mask, 5, 3, 1)
        self.assertEqual(result["count"], 1)
        self.assertEqual(result["largest_cells"], 11)
        self.assertEqual(result["largest_bounds"], [0, 0, 5, 3])

    def test_hole_and_solid_components_are_independent(self):
        mask = bytes([1, 1, 1, 1, 0, 1, 1, 1, 1])
        solid = campaign.component_metrics(mask, 3, 3, 1)
        empty = campaign.component_metrics(mask, 3, 3, 0)
        self.assertEqual(solid["count"], 1)
        self.assertEqual(solid["largest_cells"], 8)
        self.assertEqual(empty["count"], 1)
        self.assertEqual(empty["touching_crop_boundary_cells"], 0)

    def test_modified_preview_pixel_cannot_keep_native_qualification(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            raw = bytes([0, 1, 1, 0])
            (output / "example.cells").write_bytes(raw)
            colours = [(0, 0, 0, 255), (100, 110, 120, 255)]
            image = Image.frombytes("RGBA", (2, 2), bytes(component for value in raw for component in colours[value]))
            image.save(output / "example.png")
            case = {"name": "example", "status": "pass", "module": "fixture", "profile": "default",
                    "extent": [2, 2], "raw": "example.cells", "png": "example.png",
                    "material_sha256": campaign.sha(raw), "occupancy_sha256": campaign.sha(raw),
                    "material_counts": {"0": 2, "1": 2}}
            result = campaign.verify_originals(output, {"cases": [case]}, colours)
            self.assertEqual(len(result), 1)
            image.putpixel((0, 0), (255, 0, 0, 255))
            image.save(output / "example.png")
            with self.assertRaisesRegex(RuntimeError, "PNG pixels differ"):
                campaign.verify_originals(output, {"cases": [case]}, colours)

    def test_different_source_commit_cannot_be_relabelled_as_current_build(self):
        record = {"schema": "gentek80-native-build-v1", "source_commit": "historical",
                  "source_tree": "tree", "runtime_sha256": "binary", "returncode": 0,
                  "source_inputs_sha256": {}}
        with self.assertRaisesRegex(RuntimeError, "different source commit/tree"):
            campaign.verify_build_ledger(record, {"commit": "candidate", "tree": "tree", "inputs": {}}, "binary")

    def test_public_gallery_needs_all_eighty_matching_pixels_and_source_inputs(self):
        records = [{"module": f"fixture_{index}", "preset_id": f"gentek_{index}", "profile": "default", "status": "pass",
                    "extent": [2, 2], "seed": 271828, "material_sha256": f"{index:064x}",
                    "occupancy_sha256": "a" * 64, "recipe_sha256": "b" * 64, "project_sha256": "c" * 64,
                    "rgba_sha256": f"{index + 80:064x}", "native_pixels_verified": True} for index in range(80)]
        inputs = {"native/src/world_generation.cpp": "d" * 64, campaign.PALETTE: "e" * 64}
        source = {"commit": "2" * 40, "tree": "3" * 40, "inputs": inputs}
        reference = {"schema": "gentek80-public-gallery-v1", "source_commit": "1" * 40,
                     "source_tree": "4" * 40, "rendering_inputs_sha256": inputs, "defaults": copy.deepcopy(records)}
        # A docs/gallery commit may differ while every executed input and pixel
        # remains identical. It must still name both commits rather than relabel.
        result = campaign.reference_gallery_comparison(reference, source, {"cases": records}, records)
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["matched_defaults"], 80)
        self.assertNotEqual(result["reference_source_commit"], result["candidate_source_commit"])
        policy = {"schema":"gentek80-merged-reference-delta-v1",
                  "reference_commit":reference["source_commit"],
                  "reference_tree":reference["source_tree"],
                  "baseline_sha256":{campaign.PALETTE:inputs[campaign.PALETTE]}}
        drifted = copy.deepcopy(source)
        drifted["inputs"][campaign.PALETTE] = "0"*64
        self.assertEqual(campaign.reference_gallery_comparison(reference,drifted,{"cases":records},records)["status"],"fail")
        admitted = campaign.reference_gallery_comparison(reference,drifted,{"cases":records},records,policy)
        self.assertEqual(admitted["status"],"pass")
        self.assertFalse(admitted["rendering_inputs_equal"])
        modified = copy.deepcopy(reference)
        modified["defaults"][17]["rgba_sha256"]="f"*64
        self.assertEqual(campaign.reference_gallery_comparison(modified,drifted,{"cases":records},records,policy)["status"],"fail")
        changed = copy.deepcopy(reference)
        changed["defaults"][17]["rgba_sha256"] = "f" * 64
        self.assertEqual(campaign.reference_gallery_comparison(changed, source, {"cases": records}, records)["status"], "fail")
        changed = copy.deepcopy(reference)
        changed["defaults"].pop()
        self.assertEqual(campaign.reference_gallery_comparison(changed, source, {"cases": records}, records)["status"], "fail")
        changed = copy.deepcopy(reference)
        changed["rendering_inputs_sha256"][campaign.PALETTE] = "f" * 64
        self.assertEqual(campaign.reference_gallery_comparison(changed, source, {"cases": records}, records)["status"], "fail")


if __name__ == "__main__":
    unittest.main()
