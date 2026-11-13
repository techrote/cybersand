"""Versioned coral-layout candidate tests (compiler-only; native replay is separate)."""
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import unittest

import pattern_compiler as baseline
import pattern_compiler_v11 as candidate


class VersionedCoralTests(unittest.TestCase):
    def test_frozen_parent_and_explicit_identity(self):
        self.assertEqual(hashlib.sha256(Path(baseline.__file__).read_bytes()).hexdigest(),
                         candidate.BASE_COMPILER_SHA256)
        self.assertEqual(baseline.COMPILER_VERSION, "wb-art-slm-001/1.0.0")
        self.assertNotEqual(candidate.COMPILER_VERSION, baseline.COMPILER_VERSION)
        self.assertIsNot(candidate._v1, baseline)
        self.assertIsNot(candidate._v1._DRAW, baseline._DRAW)
        self.assertIsNot(candidate._v1._DRAW["fan"], baseline._DRAW["fan"])

    def test_all_non_fan_reference_geometry_is_identical(self):
        # Changing the compiler identity must not perturb unrelated motifs.
        for theme in baseline.THEMES:
            if theme == "coral":
                continue
            for variant in range(8):
                program = baseline.make_program(theme, variant)
                for seed in (17, 73):
                    with self.subTest(theme=theme, variant=variant, seed=seed):
                        self.assertEqual(baseline.compile_program(program, 96, 96, seed),
                                         candidate.compile_program(program, 96, 96, seed))

    def test_coral_occupies_upper_and_lower_field(self):
        program = baseline.make_program("coral")
        for seed in (17, 73, 101):
            before = baseline.compile_program(program, 96, 96, seed)
            after = candidate.compile_program(program, 96, 96, seed)
            starts_before = {op["points"][0][1] for op in before if op["shape"] == "polyline"}
            starts_after = {op["points"][0][1] for op in after if op["shape"] == "polyline"}
            self.assertTrue(starts_before)
            self.assertGreater(min(starts_before), 96 * 0.65)
            self.assertLess(min(starts_after), 96 * 0.40)
            self.assertGreater(max(starts_after), 96 * 0.65)
            self.assertNotEqual(before, after)

    def test_coral_variants_bounds_budgets_and_voids(self):
        for variant in range(8):
            for width, height in ((64, 64), (96, 96), (128, 64), (64, 128), (256, 256)):
                for seed in (17, 73):
                    program = baseline.make_program("coral", variant)
                    with self.subTest(variant=variant, size=(width, height), seed=seed):
                        report = candidate.compile_with_report(program, width, height, seed)
                        self.assertEqual(report["compiler_version"], candidate.COMPILER_VERSION)
                        self.assertEqual(report["base_compiler_sha256"], candidate.BASE_COMPILER_SHA256)
                        self.assertTrue(0 < report["operation_count"] <= 2048)
                        self.assertTrue(0 < report["estimated_cell_work"] <= 131072)
                        for op in report["operations"]:
                            if op["shape"] == "disc":
                                x0, y0, x1, y1 = (op["x"] - op["radius"], op["y"] - op["radius"],
                                                  op["x"] + op["radius"], op["y"] + op["radius"])
                            else:
                                pts = op.get("points", [[op.get("x0") or 0, op.get("y0") or 0],
                                                        [op.get("x1") or 0, op.get("y1") or 0]])
                                margin = math.ceil(op.get("width", 1)/2) if op.get("width", 1) > 1 else 0
                                x0 = min(pt[0] for pt in pts) - margin
                                y0 = min(pt[1] for pt in pts) - margin
                                x1 = max(pt[0] for pt in pts) + margin
                                y1 = max(pt[1] for pt in pts) + margin
                            self.assertTrue(0 <= x0 <= x1 < width and 0 <= y0 <= y1 < height, op)
                            if variant in (3, 7):
                                self.assertTrue(x1 < width * 0.27 or x0 > width * 0.73 or
                                                y1 < height * 0.27 or y0 > height * 0.73, op)

    def test_split_mirror_and_host_preflight(self):
        program = baseline.make_program("coral", 2)
        ops = candidate.compile_program(program, 96, 96, 73)
        unique = {json.dumps(op, sort_keys=True) for op in ops}
        for op in ops:
            self.assertIn(json.dumps(candidate.reflected_operation(op, 96), sort_keys=True), unique)
        with self.assertRaises(candidate.CompilerError):
            candidate.compile_program(program, 96, 96, 73, max_shapes=1)
        with self.assertRaises(candidate.CompilerError):
            candidate.compile_program(program, 96, 96, 73, max_estimated_cells=1)
        with self.assertRaises(candidate.CompilerError):
            candidate.compile_program(program, 96, 96, 73, material=1)

    def test_repeatable_without_global_shared_v1_patch(self):
        program = baseline.make_program("coral", 4)
        original = baseline.compile_program(program, 96, 96, 17)
        expected = candidate.compile_program(program, 96, 96, 17)
        self.assertEqual(baseline.compile_program(program, 96, 96, 17), original)
        self.assertEqual(candidate.compile_program(program, 96, 96, 17), expected)
        code = ("import json,pattern_compiler_v11 as c,pattern_compiler as p;"
                "print(p.canonical_json(c.compile_program(p.make_program('coral',4),96,96,17)))")
        actual = subprocess.check_output([sys.executable, "-c", code], cwd=Path(__file__).parent, text=True).strip()
        self.assertEqual(candidate.canonical_json(expected), actual)


if __name__ == "__main__":
    unittest.main()
