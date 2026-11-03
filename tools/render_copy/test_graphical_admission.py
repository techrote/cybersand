#!/usr/bin/env python3
"""Deterministic aggregate-admission boundaries; no simulated engine acceptance."""
import math
import unittest

from run_graphical_campaign import campaign_plan, execution_policy_identity, process_admission


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.policy = execution_policy_identity()
        values = self.policy["watchdogs"]
        self.required = (values["graphical_case_seconds"] + 2*values["terminate_grace_seconds"]
                         + values["operation_seconds"] + values["aggregate_headroom_seconds"])

    def test_exact_complete_allowance_is_admitted_but_one_microsecond_less_is_not(self):
        budget = self.required + 100
        exact = process_admission(budget, 100, self.policy)
        refused = process_admission(budget, 100.000001, self.policy)
        self.assertTrue(exact["admitted"])
        self.assertFalse(refused["admitted"])
        self.assertEqual(exact["required_seconds"], self.required)
        self.assertEqual(refused["reason"], "aggregate_allowance_exhausted")
        self.assertEqual(exact["reserved_seconds"], refused["reserved_seconds"])

    def test_case_only_or_single_cleanup_wait_is_insufficient(self):
        values = self.policy["watchdogs"]
        for budget in (values["graphical_case_seconds"], self.required-values["terminate_grace_seconds"],
                       self.required-values["operation_seconds"], self.required-values["aggregate_headroom_seconds"]):
            with self.subTest(budget=budget):
                result = process_admission(budget, 0, self.policy)
                self.assertFalse(result["admitted"])
                self.assertEqual(result["reserved_seconds"]["case_watchdog_seconds"], values["graphical_case_seconds"])

    def test_uncapped_local_campaign_still_records_full_case_and_cleanup_allowances(self):
        result = process_admission(None, 1_000_000, self.policy)
        self.assertTrue(result["admitted"])
        self.assertIsNone(result["remaining_seconds"])
        self.assertEqual(result["required_seconds"], self.required)

    def test_invalid_limits_or_elapsed_values_are_refused(self):
        for limit in (0, -1, math.inf, math.nan):
            with self.subTest(limit=limit), self.assertRaises(ValueError):
                process_admission(limit, 0, self.policy)
        for elapsed in (-1, math.inf, math.nan):
            with self.subTest(elapsed=elapsed), self.assertRaises(ValueError):
                process_admission(9900, elapsed, self.policy)

    def test_registered_order_and_unstarted_cells_remain_explicit(self):
        cells = campaign_plan(3)
        expected = [("control", "N", 0), ("R", "N", 0), ("control", "W", 0), ("R", "W", 0),
                    ("R", "W", 1), ("control", "W", 1), ("R", "N", 1), ("control", "N", 1),
                    ("control", "N", 2), ("R", "N", 2), ("control", "W", 2), ("R", "W", 2)]
        self.assertEqual([(c["candidate"], c["arm"], c["repeat"]) for c in cells], expected)
        self.assertEqual([c["campaign_sequence"] for c in cells], list(range(1, 13)))
        # A refusal after five actual results leaves precisely the seven named
        # cells from the unchanged plan, without inventing skipped/pass results.
        self.assertEqual([(c["candidate"], c["arm"], c["repeat"]) for c in cells[5:]], expected[5:])


if __name__ == "__main__":
    unittest.main()
