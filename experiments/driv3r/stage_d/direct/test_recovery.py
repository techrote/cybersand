"""No-network tests for D-1A hypothetical recovery opportunity accounting."""
import copy
import random
import unittest

from experiments.driv3r.stage_d.direct import offline as d
from experiments.driv3r.stage_d.direct import recovery as r


class DevelopmentRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.route = d.routing_fixture("gate", "development")
        self.wall = d.wall_fixture("step", "development")

    def test_oracle_trace_has_no_disagreement(self):
        for f in (self.wall, self.route):
            policy = "contour_astar" if f.task == "wall_offset" else "astar"
            trace = d.run_episode(f, policy)
            report = r.audit_development_recovery(f, trace)
            self.assertIsNone(report["first_oracle_choice_disagreement_index"])
            self.assertIsNone(report["first_disagreement_recovery"])
            self.assertEqual(len(report["decision_windows"]), len(trace["events"]))
            self.assertEqual(report["verified_original_trajectory_sha256"], d.digest(trace["path"]))
            self.assertFalse(report["native_qualified"])

    def test_random_baseline_windows_are_exactly_replayed(self):
        trace = d.run_episode(self.route, "random_legal", seed=13)
        report = r.audit_development_recovery(self.route, trace)
        self.assertEqual(report["fixture_sha256"], self.route.sha256)
        self.assertEqual(report["sequential_native_receipts"], 0)
        self.assertFalse(report["model_evaluated"])
        for event, row in zip(trace["events"], report["decision_windows"]):
            self.assertEqual(row["decision_index"], event["seq"])
            self.assertEqual(row["selected_candidate_id"], event["choice_id"])
            self.assertEqual(row["original_candidate_set_sha256"],
                             event["observation"]["candidate_set_sha256"])
        divergence = next((row for row in report["decision_windows"]
                           if row["oracle_choice_disagreement"]), None)
        self.assertEqual(report["first_oracle_choice_disagreement_index"],
                         None if divergence is None else divergence["decision_index"])
        if divergence is not None:
            self.assertEqual(report["first_disagreement_recovery"]["remaining_decision_capacity"],
                             36 - divergence["decision_index"] - 1)

    def test_terminal_stop_is_not_fictitiously_recovered(self):
        opts = d.candidates(self.route, self.route.start)
        seed = next(s for s in range(128)
                    if random.Random(s).choice(opts).stop)
        trace = d.run_episode(self.route, "random_legal", seed=seed)
        self.assertEqual(trace["events"][0]["choice_id"], "STOP")
        report = r.audit_development_recovery(self.route, trace)
        self.assertEqual(report["first_oracle_choice_disagreement_index"], 0)
        rescue = report["first_disagreement_recovery"]
        self.assertEqual(rescue["status"], "terminal_stop")
        self.assertFalse(rescue["arrives_within_remaining_decisions"])
        self.assertEqual(len(trace["events"]), 1)

    def test_macro_arm_is_deterministic_and_remains_synthetic(self):
        trace = d.run_episode(self.route, "random_legal", seed=23,
                              lengths=(1, 2, 4, 8))
        a = r.audit_development_recovery(self.route, trace)
        b = r.audit_development_recovery(self.route, copy.deepcopy(trace))
        self.assertEqual(a, b)
        self.assertEqual(a["sequential_native_receipts"], 0)
        self.assertTrue(all(0 <= row["remaining_decisions_after_choice"] <= 35
                            for row in a["decision_windows"]))

    def test_heldout_behavior_stays_sealed(self):
        f = d.routing_fixture("offset_gates", "heldout")
        with self.assertRaisesRegex(ValueError, "Held-out behavioral"):
            r.audit_development_recovery(f, {})

    def test_tampered_trace_rejected_before_recovery_analysis(self):
        trace = d.run_episode(self.route, "astar")
        forged = copy.deepcopy(trace)
        forged["events"][0]["choice_id"] = "STOP"
        with self.assertRaises(ValueError):
            r.audit_development_recovery(self.route, forged)

    def test_zero_budget_continuation_does_not_invent_arrival(self):
        a = r._oracle_continuation(self.route, self.route.start, (1,), 0)
        self.assertFalse(a["arrives_within_remaining_decisions"])
        self.assertEqual(a["hypothetical_oracle_decisions"], 0)
        self.assertEqual(a["final_synthetic_cursor"], list(self.route.start))


if __name__ == "__main__":
    unittest.main()
