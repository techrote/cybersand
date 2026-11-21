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
    blocked = example == "swarm005_viaduct"
    base = {"schema": 2, "mode": mode, "example": example, "checks": 40, "completed": True,
            "failures": [], "platform": "Windows", "display": "windows", "process_id": 41 if mode in ("create", "evaluate") else 42,
            "engine": "4.7-stable (official)", "test_sha256": TEST,
            "owner_visual_acceptance": "pending", "reciprocal_programme_acceptance": False,
            "transport_refusals": {"preexisting_job_directory": True, "failed_child_positive": True, "runtime_manifest_changed": True},
            "native_source": {"source": SOURCE, "sha256": CLI},
            "native_status": "blocked" if blocked else "complete", "native_can_apply": not blocked,
            "native_reason": "synthetic native metadata fixture", "native_stop_reason": "fixed_point" if blocked else "successful_full_closure",
            "native_work": {"still_required": 1 if blocked else 0}, "material_count": 3,
            "native_recipe": qualification.expected_recipe(example), "proposal_sha256": PROPOSAL,
            "native_receipt": {"operation": "build", "changed_cells": 100, "proposal_sha256": PROPOSAL},
            "joint_count": 8 if reciprocal else 0, "obligation_count": 8 if reciprocal else (1 if blocked else 0),
            "reciprocal_witness_passed": reciprocal,
            "reciprocal_witness": {"frame_occupied_changes": 55, "mosaic_occupied_changes": 56,
                                   "both_footprints_changed": True, "joint_count": 8 if reciprocal else 0,
                                   "obligation_count": 8 if reciprocal else (1 if blocked else 0),
                                   "foreign_joined": 8 if reciprocal else 0,
                                   "unresolved": 1 if blocked else 0, "all_foreign_closed": not blocked}}
    if qualification.EXAMPLES[example].get("evaluate"):
        base["transport_refusals"].update(changed_world_source=True, corrupted_saved_evidence=True)
        base["applied"] = mode == "evaluate"
    stages = ["reopened"] if mode == "reopen" else (["initial"] if blocked else ["initial", "regenerated"])
    base["inspector_evidence"] = {stage: {"schema": 1, "source": SOURCE, "round_count": 3,
        "round_indices": [-1, 0, 1, 2, -1], **{key: True for key in ("default_final", "native_pixels", "native_cell_picks", "final_only_layers", "letterbox_refusal", "restored_final")}}
        for stage in stages}
    return base


def errors(value: dict, example: str = "reciprocal", mode: str = "create") -> list[str]:
    return qualification.ui_report_errors(value, mode, example, SOURCE, CLI, TEST)


def synthetic_png() -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 512, 512, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(513 * 512))) + chunk(b"IEND", b""))


def native_artifacts(directory: Path, candidate: dict, regenerated: bool) -> None:
    records = {}
    witness = candidate["reciprocal_witness"]
    rounds = []
    for index in range(3):
        item = {}
        for owner in ("frame", "mosaic"):
            count = witness[owner+"_occupied_changes"] if index else 0
            # The third round changes material while retaining occupancy.
            cells = [1 if index == 1 else 2] * count + [0] * (64-count)
            item[owner] = {"result": {"cells": cells, "width": 8, "height": 8}}
        rounds.append(item)
    obligations = [{"state": "FOREIGN_JOINED", "foreign_joined": True} for _ in range(witness["foreign_joined"])]
    obligations += [{"state": "STILL_REQUIRED", "foreign_joined": False} for _ in range(witness["unresolved"])]
    value = {"source": SOURCE, "can_apply": candidate["native_can_apply"], "cells": [1, 2, 3] + [0]*61,
             "status": candidate["native_status"], "reason": candidate["native_reason"],
             "stop_reason": candidate["native_stop_reason"], "metrics": copy.deepcopy(candidate["native_work"]),
             "rounds": rounds, "joints": [{} for _ in range(witness["joint_count"])], "obligations": obligations}
    for stage in (("initial", "regenerated") if regenerated else ("initial",)):
        files = {stage+"-request.txt": b"synthetic transport-admission fixture\n",
                 stage+"-result.json": json.dumps(value).encode(), stage+"-native-pixels.png": synthetic_png(),
                 stage+"-material.le16": b"".join(cell.to_bytes(2, "little") for cell in value["cells"])}
        for name, content in files.items(): (directory/name).write_bytes(content)
        records[stage] = {name: hashlib.sha256(content).hexdigest() for name, content in files.items()}
    candidate["native_evidence_sha256"] = records


def rewrite_native(directory: Path, candidate: dict, stage: str, value: object) -> None:
    """Rehash the altered JSON so a refusal must be semantic, not stale custody."""
    path = directory/(stage+"-result.json")
    path.write_text(json.dumps(value), encoding="utf-8")
    candidate["native_evidence_sha256"][stage][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()


class EvidenceGates(unittest.TestCase):
    def test_actual_inspector_source_rounds_and_all_predicates_are_required(self) -> None:
        for mode, stage in (("create", "initial"), ("create", "regenerated"), ("reopen", "reopened")):
            candidate = report(mode=mode)
            for key, value in (("source", "0"*40), ("round_indices", [0, 1, 2]), ("round_count", True),
                               ("round_count", 6), ("native_pixels", False), ("native_cell_picks", False),
                               ("final_only_layers", False), ("default_final", False),
                               ("letterbox_refusal", False), ("restored_final", False)):
                broken = copy.deepcopy(candidate)
                broken["inspector_evidence"][stage][key] = value
                self.assertTrue(errors(broken, mode=mode), (mode, stage, key))
            del candidate["inspector_evidence"][stage]
            self.assertTrue(errors(candidate, mode=mode))

    def test_all_v3_and_inherited_recipes_and_pending_acceptance_pass(self) -> None:
        for example, selection in qualification.EXAMPLES.items():
            modes = ("blocked",) if selection.get("negative") else (("evaluate", "reopen") if selection.get("evaluate") else ("create", "reopen"))
            for mode in modes:
                with self.subTest(example=example, mode=mode):
                    self.assertEqual([], errors(report(example, mode), example, mode))

    def test_recovery_outcome_is_retained_without_fabricated_success(self) -> None:
        for example, selection in qualification.EXAMPLES.items():
            if not selection.get("evaluate"):
                continue
            positive = report(example, "evaluate")
            self.assertEqual([], errors(positive, example, "evaluate"))
            negative = copy.deepcopy(positive)
            negative.update(native_can_apply=False, native_status="blocked", native_receipt={}, applied=False)
            negative["inspector_evidence"].pop("regenerated")
            negative["transport_refusals"] = {"preexisting_job_directory": True}
            negative["reciprocal_witness"].update(unresolved=2, obligation_count=2, all_foreign_closed=False)
            negative["obligation_count"] = 2
            self.assertEqual([], errors(negative, example, "evaluate"))
            for key, value in (("applied", True), ("native_receipt", positive["native_receipt"]),
                               ("native_status", "invalid"), ("native_status", "cancelled"),
                               ("native_can_apply", 0), ("reciprocal_witness_passed", True)):
                broken = copy.deepcopy(negative);broken[key] = value
                self.assertTrue(errors(broken, example, "evaluate"), key)
            for key in ("changed_world_source", "corrupted_saved_evidence"):
                broken = copy.deepcopy(positive);broken["transport_refusals"].pop(key)
                self.assertTrue(errors(broken, example, "evaluate"), key)
            broken = copy.deepcopy(positive);broken["reciprocal_witness"]["unresolved"] = 1
            self.assertTrue(errors(broken, example, "evaluate"))
            for key, value in (("negotiated_recovery", not selection["recovery"]), ("world_extent", [512, 512]),
                               ("size", [64, 64]), ("profile", "substitute")):
                broken = copy.deepcopy(positive);broken["native_recipe"][key] = value
                self.assertTrue(errors(broken, example, "evaluate"), key)

    def test_v3_specific_negative_and_switch_admission_are_fail_closed(self) -> None:
        for example, mode in (("swarm005_irregular", "create"), ("swarm005_viaduct", "blocked")):
            actual = report(example, mode)
            self.assertEqual([], errors(actual, example, mode))
            for field in ("compact_native_termination", "supported_native_receptors"):
                broken = copy.deepcopy(actual)
                broken["native_recipe"][field] = False
                self.assertTrue(errors(broken, example, mode), field)
            broken = copy.deepcopy(actual)
            broken["native_recipe"]["layout"] = "centered_frame_rectangle"
            self.assertTrue(errors(broken, example, mode))
        blocked = report("swarm005_viaduct", "blocked")
        for key, value in (("native_status", "complete"), ("native_can_apply", True)):
            bad = copy.deepcopy(blocked);bad[key] = value
            self.assertTrue(errors(bad, "swarm005_viaduct", "blocked"), key)
        blocked["reciprocal_witness"]["unresolved"] = 0
        self.assertTrue(errors(blocked, "swarm005_viaduct", "blocked"))
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            negative = report("swarm005_viaduct", "blocked")
            sha = hashlib.sha256(bytes(512*512*2)).hexdigest()
            negative["native_planes_sha256"] = {"baseline": sha, "preview": sha}
            for stage in ("baseline", "preview"): (path/(stage+"-native.le16")).write_bytes(bytes(512*512*2))
            native_artifacts(path, negative, False)
            for name in ("native-preview.png", "native-unresolved.png", *qualification.INSPECTOR_CAPTURES):
                (path / name).write_bytes(synthetic_png())
            self.assertTrue(qualification.blocked_evidence(path, negative)["passed"])
            negative["native_planes_sha256"]["preview"] = "d"*64
            self.assertFalse(qualification.blocked_evidence(path, negative)["passed"])

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
            native_artifacts(root, create, True)
            create["native_planes_sha256"] = {stage: plane_sha for stage in ("expected", "applied", "regenerated", "saved")}
            create["native_planes_sha256"].update({stage: baseline for stage in ("baseline", "preview", "undone")})
            reopen["native_planes_sha256"] = {"expected": plane_sha, "reopened": plane_sha}
            for stage in ("baseline", "preview", "undone"): (root/(stage+"-native.le16")).write_bytes(bytes(len(plane)))
            for stage in ("applied", "regenerated", "saved", "reopened"): (root/(stage+"-native.le16")).write_bytes(plane)
            pair = {"create": create, "reopen": reopen}
            self.assertTrue(qualification.example_evidence(root, pair)["passed"])
            for mode, key, value in (("reopen", "process_id", create["process_id"]),
                                     ("reopen", "proposal_sha256", "0" * 64),
                                     ("reopen", "native_planes_sha256", {"expected": plane_sha, "reopened": baseline}),
                                     ("create", "native_planes_sha256", {"expected": plane_sha, "applied": plane_sha}),
                                     ("reopen", "native_status", "blocked"), ("reopen", "joint_count", 7),
                                     ("reopen", "obligation_count", 7)):
                changed = copy.deepcopy(pair)
                changed[mode][key] = value
                with self.subTest(mode=mode, key=key):
                    self.assertFalse(qualification.example_evidence(root, changed)["passed"])
            changed = copy.deepcopy(pair)
            changed["reopen"]["inspector_evidence"]["reopened"].update(round_count=1, round_indices=[-1, 0, -1])
            self.assertFalse(qualification.example_evidence(root, changed)["passed"])
            self.assertFalse(qualification.example_evidence(root, {"create": create})["passed"])
            screenshot = root / qualification.CAPTURES[-1]
            screenshot.write_bytes(synthetic_png()[:24])
            self.assertFalse(qualification.example_evidence(root, pair)["passed"])
            screenshot.write_bytes(synthetic_png())
            (root / "expected-native.le16").write_bytes(plane[:-2])
            self.assertFalse(qualification.example_evidence(root, pair)["passed"])

    def test_raw_native_records_and_exact_crop_material_bytes_are_required(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            candidate = report("swarm006_industrial_on", "evaluate")
            native_artifacts(directory, candidate, True)
            self.assertEqual([], qualification.native_evidence_errors(directory, candidate, True))
            path = directory/"initial-material.le16";path.write_bytes(b"\x00\x00")
            self.assertTrue(qualification.native_evidence_errors(directory, candidate, True))
            candidate["native_evidence_sha256"]["initial"][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertTrue(qualification.native_evidence_errors(directory, candidate, True))
            native_artifacts(directory, candidate, True)
            changed = copy.deepcopy(candidate);changed["native_source"]["source"] = "changed-source"
            self.assertTrue(qualification.native_evidence_errors(directory, changed, True))
            changed = copy.deepcopy(candidate);changed["native_evidence_sha256"].pop("regenerated")
            self.assertTrue(qualification.native_evidence_errors(directory, changed, True))

    def test_rehashed_native_metadata_must_match_each_report_and_inspector_stage(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            candidate = report()
            native_artifacts(directory, candidate, True)
            originals = {stage: json.loads((directory/(stage+"-result.json")).read_text())
                         for stage in ("initial", "regenerated")}
            self.assertEqual([], qualification.native_evidence_errors(directory, candidate, True))
            for stage in originals:
                original = originals[stage]
                mutations = {
                    "status": lambda value: value.update(status="blocked"),
                    "joints": lambda value: value["joints"].pop(),
                    "obligations": lambda value: value["obligations"].pop(),
                    "foreign_joined": lambda value: value["obligations"][0].update(foreign_joined=False),
                    "unresolved": lambda value: value["obligations"][0].update(state="STILL_REQUIRED", foreign_joined=False),
                    "round_count": lambda value: value["rounds"].append(copy.deepcopy(value["rounds"][-1])),
                    "frame_footprint": lambda value: value["rounds"][1]["frame"]["result"]["cells"].__setitem__(63, 1),
                    "mosaic_footprint": lambda value: value["rounds"][1]["mosaic"]["result"]["cells"].__setitem__(63, 1),
                    "work": lambda value: value["metrics"].update(still_required=1),
                }
                for name, mutate in mutations.items():
                    with self.subTest(stage=stage, mutation=name):
                        changed = copy.deepcopy(original);mutate(changed)
                        rewrite_native(directory, candidate, stage, changed)
                        self.assertTrue(qualification.native_evidence_errors(directory, candidate, True), name)
                rewrite_native(directory, candidate, stage, original)
                changed = copy.deepcopy(candidate)
                changed["inspector_evidence"][stage].update(round_count=1, round_indices=[-1, 0, -1])
                self.assertTrue(qualification.native_evidence_errors(directory, changed, True), stage)

    def test_rehashed_malformed_native_structures_fail_explicitly(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            candidate = report()
            native_artifacts(directory, candidate, False)
            original = json.loads((directory/"initial-result.json").read_text())
            malformed = [None, [], {"rounds": None}, {"rounds": [None]}, {"rounds": [{}]},
                         {"joints": None}, {"joints": [None]}, {"obligations": None},
                         {"obligations": [None]}, {"obligations": [{"state": []}]}, {"metrics": []}]
            for patch in malformed:
                with self.subTest(patch=patch):
                    changed = {**copy.deepcopy(original), **patch} if isinstance(patch, dict) else patch
                    rewrite_native(directory, candidate, "initial", changed)
                    self.assertTrue(qualification.native_evidence_errors(directory, candidate, False))
            for cells in (None, [True], [-1], [65536], ["1"]):
                with self.subTest(cells=cells):
                    changed = copy.deepcopy(original)
                    changed["rounds"][0]["frame"]["result"]["cells"] = cells
                    rewrite_native(directory, candidate, "initial", changed)
                    self.assertTrue(qualification.native_evidence_errors(directory, candidate, False))

    def test_exhausted_empty_obligations_do_not_claim_evaluated_closure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            candidate = report("swarm006_industrial_on", "evaluate")
            candidate.update(native_status="exhausted", native_can_apply=False, native_work={}, native_receipt={}, applied=False)
            candidate["inspector_evidence"].pop("regenerated")
            native_artifacts(directory, candidate, False)
            raw = json.loads((directory/"initial-result.json").read_text())
            raw["cells"] = [];candidate["material_count"] = 0
            self.assertTrue(candidate["reciprocal_witness"]["all_foreign_closed"])
            self.assertEqual([], qualification.native_document_errors(raw, candidate, "initial"))
            self.assertEqual({"closure_evaluated": False, "remaining": None}, qualification.closure_outcome(raw["status"], raw["metrics"]))
            # Relabeling exhausted zero counts as Complete cannot create an
            # evaluated closure metric or Apply authority.
            raw.update(status="complete", can_apply=True)
            candidate.update(native_status="complete", native_can_apply=True)
            self.assertTrue(qualification.native_document_errors(raw, candidate, "initial"))
            raw["metrics"] = candidate["native_work"] = {"still_required": 1}
            self.assertTrue(qualification.native_document_errors(raw, candidate, "initial"))

    def test_zero_original_obligations_and_native_joints_are_distinct(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            candidate = report("swarm006_industrial_on", "evaluate")
            candidate["joint_count"] = candidate["reciprocal_witness"]["joint_count"] = 5
            native_artifacts(directory, candidate, True)
            self.assertEqual([], qualification.native_evidence_errors(directory, candidate, True))
            self.assertEqual(0, candidate["reciprocal_witness"]["foreign_joined"])
            self.assertEqual({"closure_evaluated": True, "remaining": 0}, qualification.closure_outcome(candidate["native_status"], candidate["native_work"]))
            for key, value in (("frame_occupied_changes", True), ("mosaic_occupied_changes", 0.5),
                               ("both_footprints_changed", 1), ("all_foreign_closed", 1)):
                changed = copy.deepcopy(candidate);changed["reciprocal_witness"][key] = value
                self.assertTrue(qualification.native_evidence_errors(directory, changed, True), key)
            changed = copy.deepcopy(candidate);changed["material_count"] += 1
            self.assertTrue(qualification.native_evidence_errors(directory, changed, True))

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
