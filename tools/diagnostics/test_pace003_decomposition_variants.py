#!/usr/bin/env python3
"""Offline deterministic/negative checks; supply authenticated captured HLSL.

Example: python test_pace003_decomposition_variants.py --source captured-call44.hlsl
No compiler or rendering is executed. Source-specific tests cannot silently skip.
"""
from __future__ import annotations

import argparse
import base64
import copy
import math
from pathlib import Path
import re
import sys
import unittest

import pace003_decomposition_variants as variants

CAPTURED_SOURCE: bytes | None = None
EXPECTED_INPUTS = {
    "original-control": (175942, "192c1a086d5124ce4b22cb172bd90876212779e4d6c67447f9278493ba3ff03c"),
    "compositor": (38990, "cc0c8afcec9ca9a86744534765a4fd185da7cb75f970b8e1bf1b5771cdb8f53b"),
    "ordinary": (118589, "f0ac359b0c8f461c123c3e48916d932b66d21562171c7fa4d12d827f5f726778"),
    "building": (83798, "27838223f2d09b4c0f095198d551ddf469f655808bfc686613c32b56db18d369"),
    "building-81-93": (56207, "0d1c2aa339f9632330aeb26756c35fad876edba5a1696c23ba7bc8c37dbcf00b"),
    "building-94-106": (53258, "c8155867b420b65745902568dfa36aea400cf5fad37af4210fc3c22be2a480e7"),
    "building-107-119": (53262, "9a1b0b96e41c68f781b7d1e10b1239cf486def4c9b555d45e802c3a3b6414653"),
    "building-120-131": (50059, "5120bcf03cb52080eb964790f13e12ea3eb4c87bd4aaa03cfbfcd390ea26e7d4"),
}


class DecompositionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if CAPTURED_SOURCE is None:
            raise RuntimeError("--source must name the authenticated original HLSL; source tests do not skip")
        variants.validate_source(CAPTURED_SOURCE)
        cls.source = CAPTURED_SOURCE
        cls.generated = {case: variants.generate(cls.source, case) for case in variants.CASES}

    def test_frozen_eight_input_identities(self):
        self.assertEqual(tuple(EXPECTED_INPUTS), variants.CASES)
        for case, (data, receipt) in self.generated.items():
            with self.subTest(case=case):
                self.assertEqual((len(data), variants.sha256(data)), EXPECTED_INPUTS[case])
                self.assertEqual(receipt["generated_sha256"], EXPECTED_INPUTS[case][1])

    def test_exact_source_refuses_single_byte_change_truncation_and_newline_conversion(self):
        for data in (self.source[:-1], self.source + b"\n", b"X" + self.source[1:],
                     self.source.replace(b"\n", b"\r\n")):
            with self.subTest(bytes=len(data)), self.assertRaises(ValueError):
                variants.generate(data, "ordinary")

    def test_unknown_case_is_rejected(self):
        for case in ("", "building-81-132", "ordinary-fast", "tiny-valid"):
            with self.subTest(case=case), self.assertRaises(ValueError):
                variants.generate(self.source, case)

    def test_original_control_is_byte_identical_without_changes(self):
        data, receipt = self.generated["original-control"]
        self.assertEqual(data, self.source)
        self.assertEqual(receipt["patches"], [])

    def test_every_variant_round_trips_all_original_bytes(self):
        for case, (data, receipt) in self.generated.items():
            with self.subTest(case=case):
                self.assertEqual(variants.restore_original(data, receipt["patches"]), self.source)
                self.assertEqual(variants.apply_patches(self.source, receipt["patches"]), data)
                variants.verify_generated(self.source, data, receipt)

    def test_changed_output_and_forged_metadata_are_rejected(self):
        data, receipt = self.generated["ordinary"]
        for changed_data, changed_receipt in (
            (b"X" + data[1:], receipt),
            (data + b"\n", receipt),
            (data, {**receipt, "graphical_equivalence_proven": True}),
            (data, {**receipt, "material_ids": list(range(81))}),
        ):
            with self.assertRaises(ValueError):
                variants.verify_generated(self.source, changed_data, changed_receipt)

    def test_changed_patch_payload_is_rejected(self):
        data, receipt = self.generated["compositor"]
        for key in ("before_b64", "after_b64"):
            changed = copy.deepcopy(receipt["patches"])
            changed[0][key] = base64.b64encode(b"changed").decode()
            with self.subTest(key=key), self.assertRaises(ValueError):
                variants.restore_original(data, changed)

    def test_missing_reordered_and_duplicated_patches_are_rejected(self):
        data, receipt = self.generated["ordinary"]
        patches = receipt["patches"]
        for changed in (patches[1:], list(reversed(patches)), patches[:1] + patches):
            with self.assertRaises(ValueError):
                variants.restore_original(data, changed)

    def test_patch_application_refuses_overlap_and_wrong_original(self):
        _, receipt = self.generated["building-81-93"]
        patches = receipt["patches"]
        changed = copy.deepcopy(patches)
        changed[1]["start"] = changed[0]["start"]
        with self.assertRaises(ValueError):
            variants.apply_patches(self.source, changed)
        changed = copy.deepcopy(patches)
        changed[0]["before_sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            variants.apply_patches(self.source, changed)

    def test_both_plans_cover_every_encoded_id_exactly_once(self):
        variants.validate_plans()
        for name, family in variants.FAMILIES.items():
            self.assertEqual(family.count("compositor"), 1)
            for material_id in range(256):
                with self.subTest(family=name, material_id=material_id):
                    owners = [case for case in family if material_id in variants.material_ids(case)]
                    self.assertEqual(len(owners), 1)
        self.assertIn(0, variants.material_ids("ordinary"))
        self.assertIn(132, variants.material_ids("ordinary"))
        self.assertIn(255, variants.material_ids("ordinary"))
        self.assertNotIn(81, variants.material_ids("ordinary"))

    def test_cross_snapshot_partition_ownership_is_independent(self):
        # This proves the discrete partition is not selected by current ID alone.
        # It deliberately makes no texture, blend or floating-point image claim.
        for name, family in variants.FAMILIES.items():
            ownership = {material_id: next(case for case in family
                                          if material_id in variants.material_ids(case))
                         for material_id in range(256)}
            for current in range(256):
                for previous in range(256):
                    self.assertIn(current, variants.material_ids(ownership[current]))
                    self.assertIn(previous, variants.material_ids(ownership[previous]))
            self.assertEqual(ownership[0], "ordinary", name)

    def test_compositor_retains_original_main_order_and_exact_surrounding_bytes(self):
        data, _ = self.generated["compositor"]
        expected = self.source[self.source.index(b"PS_OUTPUT main("):]
        replacements = (
            (b"f_m_material_colour_int(_m_material_id4086, _m_condition4084, _m_world_pixel4077, false)", b"pace_current_colour"),
            (b"f_m_material_colour_int(_m_previous_material_id4087, _m_previous_condition4085, _m_world_pixel4077, true)", b"pace_previous_colour"),
            (b"f_m_material_colour_int(0, 0.0, _m_world_pixel4077, false)", b"pace_air_colour"),
        )
        for before, texture in replacements:
            self.assertEqual(expected.count(before), 1)
            expected = expected.replace(before, texture + b".Load(int3(int2(input.dx_Position.xy), 0))")
        self.assertEqual(data[data.index(b"PS_OUTPUT main("):], expected)
        self.assertNotIn(variants.MATERIAL_FUNCTION, variants.functions(data))
        self.assertIn(b"f_m_apply_ambient_particles_float4", variants.functions(data))
        self.assertEqual(data.count(b"register(t8)"), 1)
        self.assertEqual(data.count(b"register(t9)"), 1)
        self.assertEqual(data.count(b"register(t10)"), 1)

    def test_subcell_counterexample_requires_framebuffer_not_logical_cell_address(self):
        # With 2x raster magnification, two raster centers belong to one logical
        # cell but have different Water subcells. At the bottom y subcell, the
        # original one-sample mask 1 displays Water at x=0 and Empty at x=1. Cell-addressed
        # storage aliases them; a same-viewport SV_Position address does not.
        raster_centers = (20.5, 21.5)
        continuous_cells = tuple(value / 2 for value in raster_centers)
        logical_cells = tuple(math.floor(value) for value in continuous_cells)
        subcells = tuple(int((value - math.floor(value)) >= 0.5) for value in continuous_cells)
        water_mask = 1
        displayed_ids = tuple(3 if water_mask & (1 << subcell) else 0 for subcell in subcells)
        self.assertEqual(logical_cells, (10, 10))
        self.assertEqual(subcells, (0, 1))
        self.assertEqual(displayed_ids, (3, 0))
        self.assertEqual(tuple(int(value) for value in raster_centers), (20, 21))
        self.assertIn(b"(_m_cell_fraction.x >= 0.5)", self.source)
        data, _ = self.generated["compositor"]
        self.assertEqual(data.count(b".Load(int3(int2(input.dx_Position.xy), 0))"), 3)
        self.assertNotIn(b".Load(int3(int2(_m_view_pixel4076)", data)

    def test_material_prefix_preserves_displayed_ids_and_no_compositor(self):
        original_start = self.source.index(b"PS_OUTPUT main(")
        original_end = self.source.index(variants.MAIN_MATERIAL, original_start)
        prefix = self.source[original_start:original_end]
        for case in variants.CASES[2:]:
            data, _ = self.generated[case]
            main = data[data.index(b"PS_OUTPUT main("):]
            self.assertTrue(main.startswith(prefix), case)
            self.assertNotIn(b"f_m_apply_ambient_particles_float4(", main, case)
            self.assertNotIn(b"_m_inside_player4090", main, case)
            self.assertNotIn(b"_m_inside_test_body4091", main, case)
            self.assertEqual(main.count(b"f_m_material_colour_int("), 1)
            self.assertIn(b"pace_snapshot_mode > 2", main)
            self.assertIn(b"pace_material_id = 0;", main)
            self.assertIn(b"pace_condition = 0.0;", main)

    def test_all_retained_general_formula_definitions_are_exact_original_bytes(self):
        originals = variants.functions(self.source)
        for case in variants.CASES[1:]:
            data, _ = self.generated[case]
            for name, (start, _, end) in variants.functions(data).items():
                if name in (variants.MATERIAL_FUNCTION, variants.BUILDING_FUNCTION):
                    continue
                original_start, _, original_end = originals[name]
                self.assertEqual(data[start:end], self.source[original_start:original_end],
                                 (case, name.decode()))

    def test_assigned_building_branches_keep_exact_formula_bytes(self):
        original_start, _, original_end = variants.functions(self.source)[variants.BUILDING_FUNCTION]
        original = self.source[original_start:original_end]
        for case in variants.BUILDING_RANGES:
            data, receipt = self.generated[case]
            start, _, end = variants.functions(data)[variants.BUILDING_FUNCTION]
            selected = data[start:end]
            low, high = variants.BUILDING_RANGES[case]
            expected = original
            deletions = [item for item in receipt["patches"]
                         if item["reason"].startswith("Remove building branch")]
            for item in reversed(deletions):
                a, b = item["start"] - original_start, item["end"] - original_start
                expected = expected[:a] + expected[b:]
            self.assertEqual(selected, expected, case)
            ids = {int(value) for value in re.findall(rb"_m_id == ([0-9]+)", selected)}
            self.assertEqual(ids, set(range(low, high + 1)), case)

    def test_ordinary_and_building_retain_mutually_exclusive_dispatch(self):
        ordinary, _ = self.generated["ordinary"]
        building, _ = self.generated["building"]
        self.assertNotIn(variants.BUILDING_FUNCTION, variants.functions(ordinary))
        self.assertIn(b"f_m_apply_material_flair_float4_int_int", variants.functions(ordinary))
        self.assertNotIn(b"f_m_apply_material_flair_float4_int_int", variants.functions(building))
        self.assertIn(variants.BUILDING_FUNCTION, variants.functions(building))
        for data in (ordinary, building):
            self.assertIn(b"f_m_apply_volume_and_contact_float4_int_int4", variants.functions(data))
            self.assertIn(b"f_m_apply_neighbour_relief_float4_int_int4", variants.functions(data))

    def test_every_actual_helper_call_has_a_retained_definition(self):
        for case, (data, _) in self.generated.items():
            names = set(variants.functions(data))
            self.assertEqual(set(variants.CALL_PATTERN.findall(data)), names, case)


def main() -> int:
    global CAPTURED_SOURCE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    args, unittest_args = parser.parse_known_args()
    CAPTURED_SOURCE = args.source.read_bytes()
    variants.validate_source(CAPTURED_SOURCE)
    program = unittest.main(argv=[sys.argv[0], *unittest_args], exit=False)
    return 0 if program.result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
