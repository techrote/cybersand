"""Offline-only horizon-constrained oracle checks. No native/model runs."""
import unittest
from dataclasses import replace

from experiments.driv3r.stage_d.direct.budget_oracle import (
    bounded_optimal_route, audit_development_budget_route)
from experiments.driv3r.stage_d.direct import offline


class BudgetOracleTests(unittest.TestCase):
    def test_macro_arrival_exactly_at_budget(self):
        result = bounded_optimal_route(12, 3, (0, 1), (10, 1),
                                       lambda p: True, decision_budget=2)
        self.assertTrue(result["feasible_arrival_within_budget"])
        self.assertEqual(len(result["decisions"]), 2)
        self.assertEqual(result["cursor_path"][-1], [10, 1])
        self.assertEqual(result["optimal_cost_within_budget"], [0, 0, 2, 10])

    def test_zero_step_arrival_does_not_expand_the_global_budget(self):
        visited = []
        def legal(p):
            visited.append(p)
            return True
        result = bounded_optimal_route(
            20, 20, (7, 7), (7, 7), legal, decision_budget=36)
        self.assertTrue(result["feasible_arrival_within_budget"])
        self.assertEqual(result["optimal_cost_within_budget"], [0, 0, 0, 0])
        self.assertEqual(result["cursor_path"], [[7, 7]])
        self.assertEqual(result["decisions"], [])
        self.assertEqual(visited, [(7, 7)])

    def test_one_move_optimality_cutoff_for_routing_and_clean_wall(self):
        for clearance in (None, lambda p: 8):
            with self.subTest(wall=clearance is not None):
                visited = []
                def legal(p):
                    visited.append(p)
                    return True
                result = bounded_optimal_route(
                    20, 20, (0, 10), (1, 10), legal,
                    selected_clearance=clearance, decision_budget=36)
                self.assertTrue(result["feasible_arrival_within_budget"])
                self.assertEqual(len(result["decisions"]), 1)
                self.assertEqual(result["optimal_cost_within_budget"], [0, 0, 1, 1])
                # One optimal predecessor layer, not a 36-layer search.
                self.assertLess(len(visited), 40)

    def test_infeasible_horizon_is_not_a_false_success(self):
        result = bounded_optimal_route(12, 3, (0, 1), (10, 1),
                                       lambda p: True, decision_budget=1)
        self.assertFalse(result["feasible_arrival_within_budget"])
        self.assertIsNone(result["optimal_cost_within_budget"])
        self.assertEqual(result["decisions"], [])
        self.assertFalse(result["native_qualified"])

    def test_hard_budget_can_require_wall_departure(self):
        def selected_distance(p):
            return 8 if p[1] == 1 or p in ((0, 2), (5, 2)) else 0
        short = bounded_optimal_route(6, 4, (0, 2), (5, 2),
                                      lambda p: True, (1, 2, 4, 8),
                                      selected_distance, decision_budget=2)
        long = bounded_optimal_route(6, 4, (0, 2), (5, 2),
                                     lambda p: True, (1, 2, 4, 8),
                                     selected_distance, decision_budget=5)
        self.assertTrue(short["feasible_arrival_within_budget"])
        self.assertGreater(short["optimal_cost_within_budget"][0], 0)
        self.assertEqual(long["optimal_cost_within_budget"][0], 0)
        self.assertGreater(len(long["decisions"]), len(short["decisions"]))

    def test_blocked_sweeps_cannot_be_jumped(self):
        blocked = {(3, 1)}
        result = bounded_optimal_route(8, 4, (1, 1), (6, 1),
                                       lambda p: p not in blocked)
        self.assertTrue(result["feasible_arrival_within_budget"])
        self.assertNotIn([3, 1], result["cursor_path"])

    def test_invalid_callback_and_budgets_fail_closed(self):
        for budget in (0, 145, True, 1.5):
            with self.subTest(budget=budget), self.assertRaises(ValueError):
                bounded_optimal_route(6, 3, (0, 1), (5, 1),
                                       lambda p: True, decision_budget=budget)
        with self.assertRaisesRegex(ValueError, "callback"):
            bounded_optimal_route(6, 3, (0, 1), (5, 1),
                                  lambda p: 1)

    def test_deterministic_and_development_only(self):
        fixture = offline.routing_fixture("gate", "development")
        a = audit_development_budget_route(fixture)
        self.assertEqual(a, audit_development_budget_route(fixture))
        self.assertEqual(a["structural_split"], "development")
        held = replace(offline.wall_fixture("switchback", "heldout"),
                       split="development")
        with self.assertRaisesRegex(ValueError, "Unpinned"):
            audit_development_budget_route(held)


if __name__ == "__main__":
    unittest.main()
