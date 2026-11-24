#!/usr/bin/env python3
"""Adversarial diagnostic matching and actual completion-credit checks."""
import copy
import unittest
from unittest.mock import patch

from causal_completion_contract import registration, summarize


def fixture():
    result = []
    for index, enabled in enumerate((False, True, True, False)):
        stats = {"source": "exact-source", "match": {"engine": "exact-engine", "water_law": "wave_flow",
                 "water_profile": "current", "adapter": "same-adapter"},
                 "first_144_body_trajectory_sha256": "same-body-sequence",
                 "first_144_admitted_moves_sha256": "same-control-sequence",
                 "command_counts": {"admitted": 144}, "command_mode": "repeated_callback",
                 "windows": {"first_144_steps": {"completed_rapier_steps": 144,
                     "rapier_steps_per_second": 12.0 - int(enabled),
                     "physical_gap_ms": {"p50": 80, "p95": 90, "p99": 95, "max": 100}},
                     "whole_capture": {"completed_rapier_steps": 150}},
                 "physical_gap_counts_above_ms": {"first_144_steps": {"100": 0, "250": 0, "500": 0, "1000": 0}}}
        causal = {"enabled": enabled}
        if enabled:
            causal.update(actual_completed_rapier_steps=150, exact_application_and_exit_joins=150,
                          matched_native_to_rapier_transactions=149,
                          unavailable_producer_joins=[{"step": 1, "missing": ["native_tick"]}])
        else:
            causal["causal_events"] = 0
        result.append({"arm": "C", "index": index, "causal_enabled": enabled, "statistics": stats,
                       "causal": causal, "observers": {"presentation_enabled": True, "cpu": {"complete": True},
                        "presentation": {"windows": {"whole_capture": {"withheld_body_submissions": 3,
                          "withholding_censored_episodes": 1}}}}})
    return result


class CausalCompletionTests(unittest.TestCase):
    def test_only_narrow_registered_windows_case(self):
        value = registration()
        self.assertEqual(value["cases"], ["wave_512_follow"])
        self.assertEqual(value["material_step_interval"], 0)
        self.assertEqual(value["material_deadline_hz"], 0)
        for key, invalid in (("minimum_real_steps", 144.0), ("material_step_interval", False),
                             ("same_frame_continuation", 0), ("presentation_observer", 1)):
            altered = copy.deepcopy(value)
            altered[key] = invalid
            with self.subTest(key=key), patch("causal_completion_contract.json.loads", return_value=altered):
                with self.assertRaises(ValueError):
                    registration()

    def test_off_on_controls_report_cost_without_winner_credit(self):
        value = summarize(fixture())
        self.assertEqual(value["performance_selection"], "NOT_AN_OPTIMIZATION_COMPARISON")
        self.assertEqual(len(value["all_cross_arm_ratios"]), 4)
        self.assertTrue(all(row["physical_rate_on_over_off"] < 1 for row in value["all_cross_arm_ratios"]))
        self.assertEqual(value["readings"][1]["unavailable_producer_joins"], [{"step": 1, "missing": ["native_tick"]}])
        self.assertEqual(value["readings"][1]["presentation"]["whole_capture"]["withheld_body_submissions"], 3)

    def test_no_extra_or_missing_completed_step_application_credit(self):
        for key in ("actual_completed_rapier_steps", "exact_application_and_exit_joins"):
            for bad in (149, 151, 150.0, True):
                arms = fixture()
                arms[1]["causal"][key] = bad
                with self.assertRaises(ValueError):
                    summarize(arms)
        arms = fixture()
        arms[0]["causal"]["causal_events"] = 1
        with self.assertRaises(ValueError):
            summarize(arms)
        for location, field, bad in (("first_144_steps", "completed_rapier_steps", 144.0),
                                     ("whole_capture", "completed_rapier_steps", 150.0)):
            arms = fixture()
            arms[1]["statistics"]["windows"][location][field] = bad
            with self.assertRaises(ValueError):
                summarize(arms)
        for bad in (0.0, False):
            arms = fixture()
            arms[0]["causal"]["causal_events"] = bad
            with self.assertRaises(ValueError):
                summarize(arms)

    def test_incomplete_order_or_selector_is_not_a_cohort(self):
        arms = fixture()
        with self.assertRaises(ValueError):
            summarize(arms[:-1])
        for mutation in (lambda a: a.reverse(), lambda a: a[1].update(causal_enabled=1),
                         lambda a: a[1]["causal"].update(enabled=False)):
            arms = fixture()
            mutation(arms)
            with self.assertRaises(ValueError):
                summarize(arms)

    def test_different_source_hardware_or_physical_outcomes_refuse_attribution(self):
        for location, key, value in (("statistics", "source", "other-source"),
                                    ("match", "adapter", "other-adapter"),
                                    ("statistics", "first_144_body_trajectory_sha256", "other-bodies"),
                                    ("statistics", "first_144_admitted_moves_sha256", "other-controls")):
            arms = fixture()
            target = arms[2]["statistics"] if location == "statistics" else arms[2]["statistics"]["match"]
            target[key] = value
            with self.assertRaises(ValueError):
                summarize(arms)

    def test_missing_observer_or_unavailable_coverage_is_not_silently_zero(self):
        mutations = (lambda a: a[1]["observers"].update(presentation_enabled=False),
                     lambda a: a[1]["observers"]["cpu"].update(complete=False),
                     lambda a: a[1]["causal"].update(matched_native_to_rapier_transactions=0),
                     lambda a: a[1]["causal"].update(unavailable_producer_joins=None))
        for mutation in mutations:
            arms = fixture()
            mutation(arms)
            with self.assertRaises(ValueError):
                summarize(arms)


if __name__ == "__main__":
    unittest.main()
