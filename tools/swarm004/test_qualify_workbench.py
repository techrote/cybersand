#!/usr/bin/env python3
"""Adversarial evidence gates using synthetic fixtures, never owner acceptance."""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

import qualify_workbench as qualification

SOURCE, CLI, TEST, PROPOSAL = "a" * 40, "b" * 64, "c" * 64, "d" * 64


def report(example: str = "reciprocal", mode: str = "create") -> dict:
    reciprocal = example == "reciprocal"
    return {"schema": 2, "mode": mode, "example": example, "checks": 40, "completed": True,
            "failures": [], "platform": "Windows", "display": "windows", "process_id": 41 if mode == "create" else 42,
            "engine": "4.7-stable (official)", "test_sha256": TEST,
            "owner_visual_acceptance": "pending", "reciprocal_programme_acceptance": False,
            "transport_refusals": {"preexisting_job_directory": True, "failed_child_positive": True},
            "native_source": {"source": SOURCE, "sha256": CLI}, "native_status": "complete", "native_can_apply": True,
            "native_recipe": qualification.expected_recipe(example), "proposal_sha256": PROPOSAL,
            "native_receipt": {"operation": "build", "changed_cells": 100, "proposal_sha256": PROPOSAL},
            "joint_count": 8 if reciprocal else 0, "obligation_count": 8 if reciprocal else 0,
            "reciprocal_witness_passed": reciprocal,
            "reciprocal_witness": {"frame_occupied_changes": 55, "mosaic_occupied_changes": 56,
                                   "both_footprints_changed": True, "joint_count": 8 if reciprocal else 0,
                                   "obligation_count": 8 if reciprocal else 0, "foreign_joined": 8 if reciprocal else 0,
                                   "unresolved": 0, "all_foreign_closed": True}}


def errors(value: dict, example: str = "reciprocal", mode: str = "create") -> list[str]:
    return qualification.ui_report_errors(value, mode, example, SOURCE, CLI, TEST)


def synthetic_png() -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 512, 512, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(513 * 512))) + chunk(b"IEND", b""))


class EvidenceGates(unittest.TestCase):
    def test_both_fixed_recipes_and_pending_acceptance_pass(self) -> None:
        for example in qualification.EXAMPLES:
            for mode in ("create", "reopen"):
                with self.subTest(example=example, mode=mode):
                    self.assertEqual([], errors(report(example, mode), example, mode))

    def test_saved_godot_json_retains_integral_receipt_numbers(self) -> None:
        candidate = report(mode="reopen")
        candidate["native_receipt"]["changed_cells"] = 100.0
        self.assertEqual([], errors(candidate, mode="reopen"))
        for value in (True, 0.5, float("inf"), float("nan")):
            candidate["native_receipt"]["changed_cells"] = value
            self.assertTrue(errors(candidate, mode="reopen"))

    def test_create_requires_both_failed_transport_refusals(self) -> None:
        for value in ({}, {"preexisting_job_directory": True, "failed_child_positive": False},
                      {"preexisting_job_directory": False, "failed_child_positive": True}):
            candidate = report()
            candidate["transport_refusals"] = value
            self.assertTrue(errors(candidate))

    def test_global_seed_and_profile_cannot_leak_between_examples(self) -> None:
        inherited = {"SWARM004_UI_SEED": "605", "SWARM004_UI_MODE": "reopen", "APPDATA": "old-user"}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            first = qualification.isolated_environment(inherited, root / "transaction", "transaction")
            second = qualification.isolated_environment(inherited, root / "reciprocal", "reciprocal")
            self.assertNotIn("SWARM004_UI_SEED", second)
            self.assertNotIn("SWARM004_UI_MODE", second)
            self.assertEqual("reciprocal", second["SWARM004_UI_EXAMPLE"])
            for key, _ in qualification.PROFILE_DIRECTORIES:
                self.assertNotEqual(first[key], second[key])
            self.assertEqual("605", inherited["SWARM004_UI_SEED"])

    def test_recipe_seed_mask_policy_and_gentek_controls_are_all_bound(self) -> None:
        mutations = (("seed", 605), ("shared_ownership", True), ("shared_extent", 0),
                     ("layout", "left_right"), ("border", 0), ("activation", [[63, 48]]))
        for key, value in mutations:
            with self.subTest(key=key):
                candidate = report()
                candidate["native_recipe"][key] = value
                self.assertTrue(errors(candidate))
        for owner in ("frame", "mosaic"):
            candidate = report()
            candidate["native_recipe"]["gentek_parameters"][owner]["clutter"] = 0.15
            self.assertTrue(errors(candidate))

    def test_metadata_only_or_one_sided_changes_do_not_pass_reciprocal(self) -> None:
        for key, value in (("frame_occupied_changes", 0), ("mosaic_occupied_changes", 0),
                           ("both_footprints_changed", False), ("joint_count", 0), ("obligation_count", 0),
                           ("unresolved", 1), ("foreign_joined", 7), ("all_foreign_closed", False)):
            with self.subTest(key=key):
                candidate = report()
                candidate["reciprocal_witness"][key] = value
                self.assertTrue(errors(candidate))

    def test_zero_joint_transaction_cannot_be_relabeled_reciprocal(self) -> None:
        candidate = report("transaction")
        candidate["example"] = "reciprocal"
        candidate["native_recipe"] = qualification.expected_recipe("reciprocal")
        self.assertTrue(errors(candidate))

    def test_headless_other_host_failed_or_unfinished_reports_are_rejected(self) -> None:
        for key, value in (("display", "headless"), ("platform", "Linux"), ("completed", False),
                           ("failures", ["assertion failed"]), ("checks", 0), ("checks", True),
                           ("native_can_apply", False), ("native_status", "blocked"),
                           ("owner_visual_acceptance", "passed"), ("reciprocal_programme_acceptance", True)):
            with self.subTest(key=key):
                candidate = report()
                candidate[key] = value
                self.assertTrue(errors(candidate))

    def test_changed_source_runtime_or_acknowledgement_is_rejected(self) -> None:
        for field, key, value in (("native_source", "source", "another-source"),
                                  ("native_source", "sha256", "0" * 64),
                                  ("native_receipt", "proposal_sha256", "0" * 64),
                                  ("native_receipt", "operation", "remove"),
                                  ("native_receipt", "changed_cells", 0)):
            with self.subTest(field=field, key=key):
                candidate = report()
                candidate[field][key] = value
                self.assertTrue(errors(candidate))
        for field in ("native_source", "native_receipt", "reciprocal_witness"):
            candidate = report()
            candidate[field] = []
            self.assertTrue(errors(candidate))

    def test_controls_require_exactly_one_completed_marker(self) -> None:
        marker = "SWARM004_CONTROLS "
        complete = marker + json.dumps({"completed": True, "checks": 16, "failures": []}) + "\n"
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "controls.log"
            for content, passes in ((complete, True), ("", False), (complete * 2, False),
                                    (marker + "invalid JSON", False), (marker + "[]", False),
                                    (marker + '{"completed":true,"checks":0,"failures":[]}', False)):
                path.write_text(content, encoding="utf-8")
                self.assertEqual(passes, not qualification.marker_errors(path, marker))

    def test_full_planes_reopen_process_and_original_pngs_are_required(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            plane = b"\x01\x00" * (512 * 512)
            (root / "expected-native.le16").write_bytes(plane)
            plane_sha = hashlib.sha256(plane).hexdigest()
            baseline = hashlib.sha256(bytes(len(plane))).hexdigest()
            for name in qualification.CAPTURES:
                (root / name).write_bytes(synthetic_png())
            create, reopen = report(), report(mode="reopen")
            create["native_planes_sha256"] = {stage: plane_sha for stage in ("expected", "applied", "regenerated", "saved")}
            create["native_planes_sha256"].update({stage: baseline for stage in ("baseline", "preview", "undone")})
            reopen["native_planes_sha256"] = {"expected": plane_sha, "reopened": plane_sha}
            pair = {"create": create, "reopen": reopen}
            self.assertTrue(qualification.example_evidence(root, pair)["passed"])
            for mode, key, value in (("reopen", "process_id", create["process_id"]),
                                     ("reopen", "proposal_sha256", "0" * 64),
                                     ("reopen", "native_planes_sha256", {"expected": plane_sha, "reopened": baseline}),
                                     ("create", "native_planes_sha256", {"expected": plane_sha, "applied": plane_sha})):
                changed = copy.deepcopy(pair)
                changed[mode][key] = value
                self.assertFalse(qualification.example_evidence(root, changed)["passed"])
            self.assertFalse(qualification.example_evidence(root, {"create": create})["passed"])
            screenshot = root / qualification.CAPTURES[-1]
            screenshot.write_bytes(synthetic_png()[:24])
            self.assertFalse(qualification.example_evidence(root, pair)["passed"])
            screenshot.write_bytes(synthetic_png())
            (root / "expected-native.le16").write_bytes(plane[:-2])
            self.assertFalse(qualification.example_evidence(root, pair)["passed"])

    def test_lifecycle_still_requires_real_graphics_and_complete_assertions(self) -> None:
        candidate = report("transaction", "lifecycle")
        for key in tuple(candidate):
            if key.startswith("native_"):
                candidate.pop(key)
        self.assertEqual([], errors(candidate, "transaction", "lifecycle"))
        candidate["display"] = "headless"
        self.assertTrue(errors(candidate, "transaction", "lifecycle"))

    @unittest.skipIf(os.name == "nt", "actual Windows runner is exercised by the graphical workflow")
    def test_non_windows_runner_cannot_claim_owner_qualification(self) -> None:
        result = subprocess.run([sys.executable, str(Path(qualification.__file__)), "--godot", "missing",
                                 "--project", "missing", "--native-candidate", "missing", "--output", "missing"],
                                capture_output=True, text=True, timeout=30)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("requires actual Windows graphical execution", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
