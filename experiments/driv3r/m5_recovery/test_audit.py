"""Adversarial replay integrity and topology metrics, synthetic evidence only."""
import copy
import json
import unittest

from experiments.driv3r.m5_recovery.challenge import (
    make_case, run, cohort, POLICIES
)
from experiments.driv3r.m5_recovery.audit import verify, compare_arms


class M5AuditTests(unittest.TestCase):
    def test_original_artifacts_reconstruct_without_using_claimed_labels(self):
        for name in ("forced_culdesac", "switchback_gate",
                     "misleading_plateau", "sealed_negative", "unblocked_control"):
            case = make_case(name)
            for policy in POLICIES:
                with self.subTest(name=name, policy=policy):
                    original = run(case, policy)
                    check = verify(case, original)
                    self.assertEqual(check["goal_reached_verified"],
                                     original["terminated_at_goal"])
                    self.assertEqual(check["final_material_sha256"],
                                     original["final_material_sha256"])

    def test_json_round_trip_does_not_turn_cursor_tuples_into_false_failures(self):
        case = make_case("forced_culdesac")
        original = run(case, "a2_proxy")
        restored = json.loads(json.dumps(original))
        self.assertTrue(verify(case, restored)["goal_reached_verified"])

    def test_wrong_host_candidate_refused(self):
        case = make_case("forced_culdesac")
        broken = copy.deepcopy(run(case, "astar"))
        broken["events"][0]["choice"] = "MOVE_E"
        with self.assertRaises(ValueError):
            verify(case, broken)

    def test_material_substitution_refused(self):
        case = make_case("forced_culdesac")
        broken = copy.deepcopy(run(case, "astar"))
        broken["events"][2]["material_after_sha256"] = "0"*64
        with self.assertRaises(ValueError):
            verify(case, broken)

    def test_false_goal_label_refused_even_on_valid_trace(self):
        case = make_case("sealed_negative")
        original = run(case, "astar")
        broken = copy.deepcopy(original)
        broken["terminated_at_goal"] = True
        with self.assertRaises(ValueError):
            verify(case, broken)

    def test_native_or_model_claims_are_not_admitted(self):
        case = make_case("forced_culdesac")
        original = run(case, "astar")
        for key in ("model_qualified", "native_qualified"):
            broken = copy.deepcopy(original)
            broken[key] = True
            with self.assertRaises(ValueError):
                verify(case, broken)
        broken = copy.deepcopy(original)
        broken["events"][0]["native_receipt"] = {"actual_changed_cells": 1}
        with self.assertRaises(ValueError):
            verify(case, broken)

    def test_topology_audit_does_not_equate_connectivity_with_robustness(self):
        case = make_case("forced_culdesac")
        r = verify(case, run(case, "astar"))
        self.assertEqual(r["connected_components_verified"], 1)
        self.assertGreater(r["new_single_cell_articulations"], 0)
        self.assertGreater(r["new_articulation_fraction"], 0)

    def test_strong_astar_is_not_exceeded_by_proxy_goal_completion(self):
        report = compare_arms(cohort())
        self.assertEqual(report["rates"]["astar"]["reachable_completed"], 4)
        self.assertEqual(report["rates"]["a1_proxy"]["reachable_completed"], 1)
        self.assertEqual(report["rates"]["a2_proxy"]["reachable_completed"], 4)
        self.assertEqual(report["rates"]["a3_proxy"]["reachable_completed"], 4)
        self.assertFalse(report["genuine_native_material"])
        self.assertFalse(report["genuine_model_inference"])
        self.assertTrue(report["strong_astar_uplift_unproved"])


if __name__ == "__main__":
    unittest.main()
