#!/usr/bin/env python3
"""Adverse controls for complete original cost-matrix admission."""
import copy
import math
import unittest

from analyze_contact_recovery import full_matrix_cost_gate


def matrix():
    return [{"platform": platform, "workers": workers,
             "groups": [{"surroundings": kind, "candidate": arm,
                         "metrics": {"combined_contact_ms_per_observation": {"max": 1.5}}}
                        for kind in ("packed_sand", "embedded_sand", "mixed") for arm in (False, True)]}
            for platform in ("Linux", "Windows") for workers in (1, 4)]


class FullMatrixGate(unittest.TestCase):
    def test_retained_windows_baseline_failure_is_not_hidden_by_candidate_success(self):
        cohorts = matrix()
        group = next(group for group in cohorts[-1]["groups"]
                     if group["surroundings"] == "embedded_sand" and not group["candidate"])
        group["metrics"]["combined_contact_ms_per_observation"]["max"] = 480.685 / 224
        gate = full_matrix_cost_gate(cohorts)
        self.assertEqual(gate["verdict"], "FAIL")
        self.assertEqual(gate["passed_groups"], 23)
        self.assertEqual(gate["candidate_groups_passed"], 12)
        self.assertEqual(gate["failed_groups"][0]["workers"], 4)
        self.assertAlmostEqual(gate["failed_groups"][0]["maximum_repeat_mean_ms"], 2.145915178571)

    def test_missing_windows_or_one_worker_never_claims_full_acceptance(self):
        for cohorts in (matrix()[:2], matrix()[:-1], []):
            gate = full_matrix_cost_gate(cohorts)
            self.assertEqual(gate["verdict"], "INCOMPLETE")
            self.assertFalse(gate["complete"])

    def test_threshold_is_inclusive_and_unmodified(self):
        cohorts = matrix()
        cohorts[0]["groups"][0]["metrics"]["combined_contact_ms_per_observation"]["max"] = 2.0
        self.assertEqual(full_matrix_cost_gate(cohorts)["verdict"], "PASS")
        cohorts[0]["groups"][0]["metrics"]["combined_contact_ms_per_observation"]["max"] = math.nextafter(2.0, math.inf)
        self.assertEqual(full_matrix_cost_gate(cohorts)["verdict"], "FAIL")

    def test_duplicated_or_missing_groups_and_nonfinite_cost_cannot_pass(self):
        original = matrix()
        mutations = [lambda value: value.append(copy.deepcopy(value[0])),
                     lambda value: value[0]["groups"].pop(),
                     lambda value: value[0]["groups"].append(copy.deepcopy(value[0]["groups"][0]))]
        for number in (math.nan, math.inf, -1.0, True):
            mutations.append(lambda value, number=number: value[0]["groups"][0]["metrics"]
                             ["combined_contact_ms_per_observation"].update(max=number))
        for mutate in mutations:
            value = copy.deepcopy(original)
            mutate(value)
            with self.assertRaises(ValueError):
                full_matrix_cost_gate(value)


if __name__ == "__main__":
    unittest.main()
