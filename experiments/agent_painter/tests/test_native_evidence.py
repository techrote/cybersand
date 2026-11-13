"""Adversarial synthetic protocol fixtures; these tests do not claim native execution."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

BASE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE / "native"))
sys.path.insert(0, str(BASE))
from verify import reduce_receipts, safe_path, capture_matches, verified_receipt_file
from gallery import validate_custody, sha


def fixture():
    # Two native-sized chunks of overlapping proposals, with one real no-op.
    operations = [
        {"shape": "rectangle", "x0": 1, "y0": 2, "x1": 3, "y1": 2, "material": 58},
        {"shape": "pixels", "points": [[2, 2]], "material": 58},
        {"shape": "pixels", "points": [[3, 2]], "material": 0},
    ]
    receipts = [
        {"backend": "CyberNativeCellWorld", "status": "completed", "requested": 3,
         "confirmed": 3, "checked": 3, "changed": 3, "unchanged": 0, "excluded": 0, "refused": 0,
         "generation": 5, "revision": 103, "tick": 0,
         "before_source": {"generation": 5, "revision": 100, "tick": 0},
         "readback": [[1, 2, 0, 58], [2, 2, 0, 58], [3, 2, 0, 58]]},
        {"backend": "CyberNativeCellWorld", "status": "completed", "requested": 2,
         "confirmed": 2, "checked": 2, "changed": 1, "unchanged": 1, "excluded": 0, "refused": 0,
         "generation": 5, "revision": 104, "tick": 0,
         "before_source": {"generation": 5, "revision": 103, "tick": 0},
         "readback": [[2, 2, 58, 58], [3, 2, 58, 0]]},
    ]
    return operations, receipts


class PackagingEntrypointTests(unittest.TestCase):
    def test_packaging_reaches_evidence_validation_in_a_fresh_interpreter(self):
        # The production packager imports native.verify as a package. Running
        # this in the test process would hide a broken import behind its native
        # sys.path entry and cached runtime module.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            output = root / "release"
            argv = [str(BASE / "qualification.py"), "package", "--directory", str(root),
                    "--output", str(output), "--source-sha", "a" * 40]
            script = ("import runpy,sys; " + f"sys.path.insert(0, {str(BASE)!r}); " +
                      f"sys.argv={argv!r}; runpy.run_path(sys.argv[0], run_name='__main__')")
            result = subprocess.run([sys.executable, "-I", "-c", script], cwd=root,
                                    capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0, "Empty evidence must never publish")
            self.assertNotIn("ModuleNotFoundError", result.stderr)
            self.assertIn("FileNotFoundError", result.stderr)
            self.assertIn("native-summary.json", result.stderr)
            self.assertFalse(output.exists())


class ReceiptIntegrityTests(unittest.TestCase):
    def test_valid_overlap_and_noop_are_reconstructed(self):
        operations, receipts = fixture()
        world, counts = reduce_receipts(receipts, operations, 96, 96)
        self.assertEqual(world[2 * 512 + 1:2 * 512 + 4], [58, 58, 0])
        self.assertEqual(sum(value != 0 for value in world), 2)
        self.assertEqual(counts, {"checked": 5, "changed": 4, "unchanged": 1, "excluded": 0, "refused": 0})

    def refuse(self, mutation, message):
        operations, receipts = fixture()
        mutation(operations, receipts)
        with self.assertRaisesRegex(ValueError, message):
            reduce_receipts(receipts, operations, 96, 96)

    def test_forged_before_material_refused(self):
        self.refuse(lambda ops, rows: rows[1]["readback"][0].__setitem__(2, 0), "before-material")

    def test_reordered_native_cells_refused(self):
        self.refuse(lambda ops, rows: rows[0]["readback"].reverse(), "operation sequence")

    def test_forged_requested_material_refused(self):
        self.refuse(lambda ops, rows: rows[0]["readback"][0].__setitem__(3, 0), "operation sequence")

    def test_missing_native_rows_refused(self):
        self.refuse(lambda ops, rows: rows[0]["readback"].pop(), "count mismatch")

    def test_omitted_suffix_refused(self):
        self.refuse(lambda ops, rows: rows.pop(), "omits requested")

    def test_extra_native_rows_refused(self):
        operations, receipts = fixture()
        operations.pop()
        with self.assertRaisesRegex(ValueError, "operation sequence"):
            reduce_receipts(receipts, operations, 96, 96)

    def test_counter_tampering_refused(self):
        self.refuse(lambda ops, rows: rows[0].__setitem__("changed", 2), "counts disagree")

    def test_boolean_counter_refused(self):
        self.refuse(lambda ops, rows: rows[0].__setitem__("refused", False), "nonnegative integers")

    def test_partial_application_never_positive_admission(self):
        self.refuse(lambda ops, rows: rows[0].__setitem__("status", "partial"), "backend/completion")

    def test_source_generation_fence_refused(self):
        self.refuse(lambda ops, rows: rows[1]["before_source"].__setitem__("generation", 6), "source identity")

    def test_source_revision_chain_refused(self):
        self.refuse(lambda ops, rows: rows[1]["before_source"].__setitem__("revision", 102), "chain is broken")

    def test_simulation_tick_refused(self):
        self.refuse(lambda ops, rows: rows[0].__setitem__("tick", 1), "simulation tick")

    def test_backend_substitution_refused(self):
        self.refuse(lambda ops, rows: rows[0].__setitem__("backend", "PythonRaster"), "backend/completion")

    def test_outside_focus_refused(self):
        operations, receipts = fixture()
        operations[0]["x0"] = 94
        operations[0]["x1"] = 96
        receipts[0]["readback"] = [[94, 2, 0, 58], [95, 2, 0, 58], [96, 2, 0, 58]]
        with self.assertRaisesRegex(ValueError, "outside host focus"):
            reduce_receipts(receipts, operations, 96, 96)

    def test_evidence_path_escape_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            outside = root / "outside"
            outside.write_bytes(b"native")
            packet = root / "packet"
            packet.mkdir()
            with self.assertRaisesRegex(ValueError, "outside packet"):
                safe_path(packet, "../outside")
            with self.assertRaisesRegex(ValueError, "relative"):
                safe_path(packet, str(outside))

    def test_source_file_must_exist(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "missing"):
                safe_path(Path(folder), "absent.png")

    def test_capture_requires_actual_complete_read_only_native_region(self):
        row = {"backend": "CyberNativeCellWorld", "kind": "capture", "status": "completed",
               "termination": "completed", "tick": 0, "applied": 0, "changed": 0,
               "region_xywh": [0, 0, 96, 96], "checked": 9216, "requested_cells": 9216,
               "materials_i32le_sha256": "a" * 64, "generation": 4, "revision": 10}
        self.assertTrue(capture_matches([row], "a" * 64, [0, 0, 96, 96]))
        for key, value in (("status", "partial"), ("kind", "synthetic"), ("changed", 1),
                           ("checked", 9000), ("region_xywh", [1, 0, 96, 96])):
            bad = dict(row, **{key: value})
            self.assertFalse(capture_matches([bad], "a" * 64, [0, 0, 96, 96]))
        self.assertFalse(capture_matches([row, row], "a" * 64, [0, 0, 96, 96]))
        self.assertTrue(capture_matches([row], "a" * 64, [0, 0, 96, 96], row))
        self.assertFalse(capture_matches([row], "a" * 64, [0, 0, 96, 96], dict(row, generation=3)))
        self.assertFalse(capture_matches([row], "a" * 64, [0, 0, 96, 96], dict(row, revision=9)))

    def test_per_case_receipt_content_tamper_rejected_before_hashing(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            expected = {"id": "case", "passed": True, "crop_i32le_sha256": "a" * 64}
            path = root / "case.receipt.json"
            path.write_text(json.dumps(expected))
            self.assertEqual(verified_receipt_file(root, "case", expected), path)
            path.write_text(json.dumps(dict(expected, crop_i32le_sha256="b" * 64)))
            with self.assertRaisesRegex(ValueError, "differs"):
                verified_receipt_file(root, "case", expected)

    def test_gallery_rejects_post_verification_final_relabeling(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            candidate = {"id": "held-out", "split": "FINAL"}
            path = root / "candidates.json"
            path.write_text(json.dumps({"examples": [candidate]}))
            custody = {"candidates_sha256": sha(path)}
            validate_custody(root, [candidate], {"cases": []}, custody)
            candidate["split"] = "DEVELOPMENT"
            path.write_text(json.dumps({"examples": [candidate]}))
            with self.assertRaisesRegex(ValueError, "candidate custody changed"):
                validate_custody(root, [candidate], {"cases": []}, custody)


if __name__ == "__main__":
    unittest.main()
