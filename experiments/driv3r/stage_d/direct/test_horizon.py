"""Cheap, no-model tests for exact budget feasibility and held-out isolation."""
import copy
import unittest

from experiments.driv3r.stage_d.direct import horizon


class DecisionHorizonTests(unittest.TestCase):
    def test_unit_and_macro_horizon_are_exact(self):
        legal = lambda p: True
        unit = horizon.exact_remaining_decisions(9, 1, (8, 0), legal, (1,))
        macro = horizon.exact_remaining_decisions(9, 1, (8, 0), legal,
                                                   (1, 2, 4, 8))
        self.assertEqual(unit[(0, 0)], 8)
        self.assertEqual(macro[(0, 0)], 1)
        self.assertEqual(macro[(7, 0)], 1)
        self.assertEqual(macro[(8, 0)], 0)

    def test_swept_collision_requires_actual_detour(self):
        blocked = {(3, 1)}
        legal = lambda p: p not in blocked
        distances = horizon.exact_remaining_decisions(
            7, 3, (6, 1), legal, (1, 2, 4, 8))
        self.assertNotIn((3, 1), distances)
        self.assertGreater(distances[(0, 1)], 1)
        self.assertEqual(distances[(6, 1)], 0)
        # Reversing a legal macro must preserve the exact decision distance.
        from_start = horizon.exact_remaining_decisions(
            7, 3, (0, 1), legal, (1, 2, 4, 8))
        self.assertEqual(distances[(0, 1)], from_start[(6, 1)])

    def test_sealed_wall_is_not_bypassed_by_long_macro(self):
        legal = lambda p: p[0] != 2
        distances = horizon.exact_remaining_decisions(5, 2, (4, 0), legal,
                                                      (1, 2, 4, 8))
        self.assertNotIn((0, 0), distances)
        self.assertNotIn((2, 0), distances)

    def test_boolean_and_menu_admission_is_type_exact(self):
        for lengths in ((), (2,), (1, 1), (1, 3), (1, True), (2, 1)):
            with self.subTest(lengths=lengths), self.assertRaises(ValueError):
                horizon.exact_remaining_decisions(5, 5, (4, 4),
                                                  lambda p: True, lengths)
        with self.assertRaises(ValueError):
            horizon.exact_remaining_decisions(5, 5, (4, 4),
                                              lambda p: "ALLOW")
        with self.assertRaises(ValueError):
            horizon.exact_remaining_decisions(True, 5, (4, 4),
                                              lambda p: True)

    def test_replayed_development_horizon_is_non_native(self):
        from experiments.driv3r.stage_d.direct import offline as d
        for fixture, policy in (
            (d.routing_fixture("gate", "development"), "astar"),
            (d.wall_fixture("step", "development"), "contour_astar"),
        ):
            with self.subTest(fixture=fixture.fixture_id):
                episode = d.run_episode(fixture, policy)
                report = horizon.audit_development_horizon(fixture, episode)
                self.assertEqual(report["fixture_sha256"], fixture.sha256)
                self.assertFalse(report["native_qualified"])
                self.assertFalse(report["model_evaluated"])
                self.assertEqual(report["sequential_native_receipts"], 0)
                self.assertEqual(len(report["original_decision_horizons"]),
                                 len(episode["events"]))
                self.assertEqual(report["original_terminal_arrival"],
                                 episode["metrics"]["arrived"])

    def test_stopped_trace_is_not_resumed_and_tamper_rejected(self):
        from experiments.driv3r.stage_d.direct import offline as d
        fixture = d.routing_fixture("gate", "development")
        episode = d.run_episode(fixture, "random_legal", seed=0)
        report = horizon.audit_development_horizon(fixture, episode)
        self.assertEqual(report["original_stop_reason"],
                         episode["metrics"]["stop_reason"])
        self.assertEqual(len(report["original_decision_horizons"]),
                         len(episode["events"]))
        forged = copy.deepcopy(episode)
        forged["metrics"]["native_receipts"] = 1
        with self.assertRaises(ValueError):
            horizon.audit_development_horizon(fixture, forged)

    def test_heldout_behavior_cannot_run_horizon_audit(self):
        from experiments.driv3r.stage_d.direct import offline as d
        fixture = d.routing_fixture("nested_corners", "heldout")
        with self.assertRaises(ValueError):
            horizon.audit_development_horizon(fixture, {})


if __name__ == "__main__":
    unittest.main()
