#!/usr/bin/env python3
"""Guards for the WAVE-WATERWALL-001 publisher profile: branch binding, request
shape, inherited publication guards and refusal of forged spill evidence."""
import inspect
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

import lcb001_shared_contract_runtime_publication as shared
import wave_waterwall_runtime_publication as profile

ROOT = Path(__file__).resolve().parents[2]


class WaterwallPublicationTests(unittest.TestCase):
    def test_branch_request_and_workflow_are_bound_to_this_lane(self):
        engine = profile.engine
        self.assertEqual(engine.BRANCH, "claude/wave-waterwall-001")
        self.assertEqual(engine.WORKFLOW, ".github/workflows/wave-waterwall-runtime-publication.yml")
        request = json.loads((ROOT / engine.REQUEST).read_text(encoding="utf-8"))
        self.assertEqual({k: v for k, v in request.items() if k != "request_sequence"}, engine.REQUEST_VALUE)
        self.assertIsInstance(request["request_sequence"], int)
        workflow = (ROOT / engine.WORKFLOW).read_text(encoding="utf-8")
        self.assertNotIn("astra/wave-mt-001-669-finisher", workflow)
        self.assertIn("refs/heads/claude/wave-waterwall-001", workflow)
        for target in ("wave-spill-test", "wave-spill-sanitize", "wave-spill-thread-sanitize",
                       "wave-body-boundary-test", "wave-body-boundary-sanitize", "wave-body-boundary-thread-sanitize"):
            self.assertIn(target, workflow)
        for path in (engine.WORKFLOW, engine.REQUEST, engine.EVIDENCE, "native/bench/wave_waterwall.cpp"):
            self.assertIn(path, engine.BUILD_EXACT)

    def test_inherited_source_and_publication_guards_are_unchanged(self):
        for name in ("context", "require_publication_request", "check_source", "check_index",
                     "input_ledgers", "runtime_identity", "verify_bundle", "record_build", "execute", "stage"):
            with self.subTest(name=name):
                self.assertEqual(inspect.getsource(getattr(profile.engine, name)), inspect.getsource(getattr(shared, name)))
        self.assertIn("test_workbench_wave", profile.engine.CASE_MARKERS)
        self.assertIn("test_workbench_wave_spill", profile.engine.CASE_MARKERS)
        for case in ("test_failed_world_status_survives", "test_workbench_failure_containment"):
            self.assertIn(case, profile.engine.CASE_MARKERS)
            self.assertTrue((ROOT / "godot/tests" / (case + ".gd")).is_file())

    def test_forged_or_incomplete_spill_summaries_are_refused(self):
        good = {"checks": 40, "failures": [], "sections": {name: True for name in profile.SPILL_SECTIONS}}
        profile.verify_spill_summary("WORKBENCH_WAVE_SPILL " + json.dumps(good))
        for bad in ["", "WORKBENCH_WAVE_SPILL {", "WORKBENCH_WAVE_SPILL " + json.dumps(good) + "\nWORKBENCH_WAVE_SPILL " + json.dumps(good),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"failures": ["x"]}),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"checks": 0}),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"sections": {"native_admission": True}}),
                    "WORKBENCH_WAVE_SPILL " + json.dumps(good | {"sections": {**good["sections"], "workbench_apply": False}})]:
            with self.subTest(bad=bad[:60]):
                with self.assertRaises(RuntimeError):
                    profile.verify_spill_summary(bad)

    @staticmethod
    def failure_summary():
        return {"checks": 180, "failures": [],
                "sections": {name: True for name in profile.FAILED_WORLD_SECTIONS},
                "faults": [
                    {"operation": "diagnostic_fill_rect", "error": "diagnostic_fill_rect failed: experimental Water state out of domain",
                     "count": 1, "completed_tick": 1, "attempted_tick": 1},
                    {"operation": "simulation_tick", "error": "simulation_tick failed: active scheduling-core capacity exhausted",
                     "count": 1, "completed_tick": 1, "attempted_tick": 2}]}

    @staticmethod
    def owner_summary():
        return {"checks": 80, "failures": [], "real_workbench": True, "recovered_ticks": 4,
                "sections": {name: True for name in profile.WORKBENCH_FAILURE_SECTIONS},
                "observations": [
                    {"case": "prepublication_fault", "failure_count": 1, "error": "diagnostic_fill_rect failed",
                     "late_fault_injected": False, "previous_tick": 0, "published_tick": 0},
                    {"case": "late_publication_fault", "failure_count": 1, "error": "diagnostic_fill_rect failed",
                     "late_fault_injected": True, "previous_tick": 0, "published_tick": 0},
                    {"case": "running_owner", "failure_count": 1, "error": "capacity exhausted",
                     "native": {"enabled": True, "spill": {"parcels": True}, "parameters": {"body_push": 0}}}]}

    def assert_summary_refusals(self, verifier, marker, good, malformed):
        valid = marker + " " + json.dumps(good)
        verifier(valid)
        for bad in ["", marker + " {", marker + " []", valid + "\n" + valid,
                    *[marker + " " + json.dumps(item) for item in malformed]]:
            with self.subTest(bad=bad[:100]):
                with self.assertRaises(RuntimeError):
                    verifier(bad)

    def test_missing_or_forged_native_failure_evidence_is_refused(self):
        good = self.failure_summary()
        malformed = [good | {"checks": True}, good | {"checks": 99}, good | {"failures": ["aborted"]},
                     good | {"sections": {}}, good | {"sections": {**good["sections"], "first_error": 1}},
                     good | {"faults": []}, good | {"faults": [good["faults"][0]]}]
        for index, key, value in [(0, "operation", []), (0, "error", "world is failed"),
                                  (0, "count", True), (0, "count", 2), (1, "operation", "diagnostic_fill_rect"),
                                  (1, "completed_tick", -1), (1, "attempted_tick", 0)]:
            bad = deepcopy(good)
            bad["faults"][index][key] = value
            malformed.append(bad)
        self.assert_summary_refusals(profile.verify_failed_world_summary, "FAILED_WORLD_STATUS", good, malformed)

    def test_missing_or_forged_workbench_failure_evidence_is_refused(self):
        good = self.owner_summary()
        malformed = [good | {"checks": 49}, good | {"failures": ["bad"]}, good | {"real_workbench": 1},
                     good | {"recovered_ticks": True}, good | {"recovered_ticks": 0},
                     good | {"observations": []}, good | {"sections": {}}]
        for index, key, value in [(0, "case", []), (0, "failure_count", True), (0, "error", ""),
                                  (1, "late_fault_injected", False), (1, "published_tick", 1),
                                  (1, "previous_tick", True), (2, "case", "late_publication_fault"),
                                  (2, "native", {"enabled": True, "spill": {"parcels": True},
                                                 "parameters": {"body_push": False}})]:
            bad = deepcopy(good)
            bad["observations"][index][key] = value
            malformed.append(bad)
        self.assert_summary_refusals(profile.verify_workbench_failure_summary,
                                     "WORKBENCH_FAILURE_CONTAINMENT", good, malformed)


if __name__ == "__main__":
    unittest.main()
