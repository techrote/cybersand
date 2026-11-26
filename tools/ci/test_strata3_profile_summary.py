#!/usr/bin/env python3
"""Adverse arithmetic controls for a report, not substitute runtime evidence."""
import copy
import unittest

import strata3_profile_summary as summary


def samples():
    result = []
    names = ("classic", "gameplay_clarity", "architectural", "cinematic_deep_focus", "diorama")
    for repeat in range(3):
        for name in names if repeat != 1 else names[::-1]:
            result.append({"profile": name, "repeat": repeat, "quality": "high" if name == "diorama" else "balanced",
                           "native_ticks_per_second": 50., "rapier_ticks_per_second": 50.,
                           "physical_distribution_usec": {"p95": 20000, "p99": 30000, "max": 1000000},
                           "callback_distribution_usec": {"p95": 16000}, "godot_process_ms": [2., 3.],
                           "elapsed_usec": 1000000, "before": {"native_tick": 0, "rapier_tick": 0},
                           "after": {"native_tick": 50, "rapier_tick": 50}, "scene_admission_elapsed_ms": 46000,
                           "scene_admission_target_met": False, "native_publication_interval_distribution_usec": {"p95": 40000},
                           "actor_distance_cells": 4., "native_capture_delta": 0, "decorative_upload_delta": 0})
    return result


class SummaryControls(unittest.TestCase):
    def test_independent_rate_and_tail_criteria_preserve_misses(self):
        source = samples()
        for row in source:
            if row["profile"] == "architectural":
                row["native_ticks_per_second"] = 45.
                row["rapier_ticks_per_second"] = 44.9
                row["physical_distribution_usec"]["p95"] = 30000
        value = summary.cohort(source)["architectural"]
        gates = value["median_comparison_to_classic"]
        self.assertTrue(gates["observed_native_rate_target_met"])
        self.assertFalse(gates["observed_rapier_rate_target_met"])
        self.assertTrue(gates["observed_physical_p95_target_met"])
        self.assertEqual(gates["physical_p95_limit_usec"], 30000)
        self.assertEqual(value["physical_maximum_usec"]["median"], 1000000)
        self.assertFalse(value["repeats"][0]["scene_admission_target_met"])

    def test_median_does_not_hide_original_repeat_spread(self):
        source = samples()
        for row in source:
            if row["profile"] == "gameplay_clarity":
                row["native_ticks_per_second"] = [20., 50., 80.][row["repeat"]]
        result = summary.cohort(source)["gameplay_clarity"]["native_ticks_per_second"]
        self.assertEqual(result, {"original_order": [20., 50., 80.], "minimum": 20., "median": 50., "maximum": 80.})

    def test_missing_or_duplicate_repeats_refused(self):
        source = samples()
        with self.assertRaises(RuntimeError):
            summary.cohort(source[:-1])
        altered = copy.deepcopy(source)
        altered[-1]["repeat"] = 1
        with self.assertRaises(RuntimeError):
            summary.cohort(altered)


if __name__ == "__main__":
    unittest.main()
