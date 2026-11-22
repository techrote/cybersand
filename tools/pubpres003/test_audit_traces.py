#!/usr/bin/env python3
"""Synthetic measurement adversaries. None is simulation/performance evidence."""
from __future__ import annotations

import copy
import unittest

from audit_traces import (assert_selected_equal, distribution,
                          first_healthy_handoffs, independent_window,
                          summarize_cohorts)


def fixture():
    receipt = {"capture_start_usec": 1000, "capture_end_usec": 11_000}
    rows = []
    for tick, complete, first, last, begin, end in (
            (1, 2000, 2100, 3900, 4000, 4100),
            (2, 5000, 5200, 7900, 8000, 8200)):
        rows.append({"event": "native_completion_observed", "world_generation": 7,
                     "tick_index": tick, "time_usec": complete})
        for handoff in (first, last):
            rows.append({"event": "worker_snapshot", "world_generation": 7,
                         "tick_index": tick, "completed_body_sample": tick + 1,
                         "required_hard_revision": 9, "hard_surface_revision": 9,
                         "failed": False, "time_usec": handoff + 5,
                         "physics_handoff_usec": handoff, "native_tick_ms": 1.5})
        rows.append({"event": "rapier_step", "world_generation": 7,
                     "native_tick_used": tick, "completed_body_sample": tick + 1,
                     "required_hard_revision": 9, "start_usec": begin, "time_usec": end,
                     "native_completed_usec": complete, "step": tick, "solver_usec": 25})
        rows.append({"event": "physics_callback", "start_usec": begin, "time_usec": end + 1,
                     "process_frame": tick, "before_step": tick - 1, "after_step": tick,
                     "pending_hard_chunks": 0})
    return receipt, rows


class IndependentTimingTests(unittest.TestCase):
    def test_repeated_publication_cannot_make_old_packet_fresh(self):
        receipt, rows = fixture()
        result = independent_window(rows, receipt, receipt["capture_end_usec"])
        self.assertEqual(result["completed_rapier_steps"], 2)
        self.assertAlmostEqual(result["first_physics_handoff_to_execution_start_ms"]["p50"], 2.35)
        self.assertAlmostEqual(result["native_exact_to_first_physics_handoff_ms"]["p50"], .15)
        self.assertEqual(result["native_tick_ms"]["count"], 2)

    def test_other_world_sample_and_terrain_do_not_win_identity_join(self):
        receipt, rows = fixture()
        good = first_healthy_handoffs(rows)
        original = next(r for r in rows if r["event"] == "worker_snapshot")
        for field in ("world_generation", "completed_body_sample", "required_hard_revision"):
            wrong = {**original, field: 99, "physics_handoff_usec": 1}
            rows.append(wrong)
        after = first_healthy_handoffs(rows)
        self.assertTrue(all(after[k] == v for k, v in good.items()))
        self.assertAlmostEqual(independent_window(rows, receipt, 11_000)["first_physics_handoff_to_execution_start_ms"]["p50"], 2.35)

    def test_failed_or_incomplete_terrain_does_not_establish_readiness(self):
        receipt, rows = fixture()
        packet = next(r for r in rows if r["event"] == "worker_snapshot")
        rows += [{**packet, "failed": True, "physics_handoff_usec": 1},
                 {**packet, "hard_surface_revision": 8, "physics_handoff_usec": 2}]
        self.assertEqual(first_healthy_handoffs(rows)[(7, 1, 2, 9)], 2100)

    def test_forged_future_handoff_is_refused(self):
        receipt, rows = fixture()
        for r in rows:
            if r["event"] == "worker_snapshot":
                r["physics_handoff_usec"] = 9000
        with self.assertRaisesRegex(ValueError, "published after"):
            independent_window(rows, receipt, 11_000)

    def test_no_step_window_retains_censored_freeze_and_unknown_gap(self):
        receipt, rows = fixture()
        result = independent_window(rows, receipt, 1999)
        self.assertEqual(result["completed_rapier_steps"], 0)
        self.assertEqual(result["rapier_steps_per_second"], 0)
        self.assertIsNone(result["physical_gap_ms"])
        self.assertAlmostEqual(result["physical_no_step_prefix_ms"], .999)
        self.assertAlmostEqual(result["physical_no_step_suffix_ms"], .999)

    def test_never_extrapolate_capture_past_actual_end(self):
        receipt, rows = fixture()
        with self.assertRaisesRegex(ValueError, "exceeds"):
            independent_window(rows, receipt, 11_001)

    def test_continuation_attempt_is_not_actual_step_credit(self):
        receipt, rows = fixture()
        rows.append({"event": "physics_continuation", "start_usec": 6000, "time_usec": 6100,
                     "advanced": False, "status": "contended"})
        result = independent_window(rows, receipt, 11_000)
        self.assertEqual(result["completed_rapier_steps"], 2)
        self.assertEqual(result["continuation_attempts"], 1)
        self.assertEqual(result["continuation_completed"], 0)
        self.assertEqual(result["continuation_outcomes"], {"contended": 1})

    def test_quantiles_and_invalid_clocks(self):
        self.assertEqual(distribution([0, 10, 20, 30])["p50"], 15)
        self.assertAlmostEqual(distribution([0, 10, 20, 30])["p95"], 28.5)
        self.assertIsNone(distribution([]))
        for value in (-1, float("nan"), float("inf")):
            with self.subTest(value=value), self.assertRaises(ValueError):
                distribution([value])

    def test_crosscheck_does_not_tolerate_missing_or_different_statistics(self):
        assert_selected_equal({"p95": .1 + .2}, {"p95": .3})
        for expected in ({}, {"p95": .301}, {"p95": None}):
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                assert_selected_equal({"p95": .3}, expected)


def cohort():
    _, events = fixture()
    result = independent_window(events, {"capture_start_usec": 1000, "capture_end_usec": 11_000}, 11_000)
    template = {"platform": "synthetic", "case": "test", "diagnostic": "same-frame-abba",
                "source_commit": "a" * 40, "source_tree": "b" * 40,
                "native_runtime_sha256": "c" * 64, "engine_sha256": "d" * 64,
                "cpu": "synthetic", "adapter": "synthetic", "water_profile": "test", "fixture": "test",
                "worker_capacity": [4], "physical_outcome_sha256": "e" * 64,
                "admitted_moves_sha256": "f" * 64,
                "windows": {name: result for name in ("first_10s", "first_144_steps", "whole_capture")}}
    return [{**copy.deepcopy(template), "order_index": index,
             "treatment": {"same_frame_continuation": index in (1, 2), "wave_column_probe": False}}
            for index in range(4)]


class PairedIdentityTests(unittest.TestCase):
    def test_two_run_rate_is_not_a_pooled_quantile(self):
        rows = cohort()
        result = summarize_cohorts(rows)[0]
        self.assertEqual(len(result["settings"]["ON"]["first_10s"]["physical_p95_ms_runs"]), 2)
        self.assertEqual(result["paired_identity"], "PASS")

    def test_mismatched_source_runtime_workload_or_outcome_refuses_attribution(self):
        for field in ("source_commit", "native_runtime_sha256", "engine_sha256", "cpu",
                      "adapter", "water_profile", "fixture", "worker_capacity",
                      "physical_outcome_sha256", "admitted_moves_sha256"):
            with self.subTest(field=field):
                rows = cohort()
                rows[1][field] = "other"
                with self.assertRaises(ValueError):
                    summarize_cohorts(rows)

    def test_missing_arm_or_second_intervention_refuses_attribution(self):
        rows = cohort()
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            summarize_cohorts(rows[:3])
        rows[1]["treatment"]["wave_column_probe"] = True
        with self.assertRaisesRegex(ValueError, "Uncontrolled"):
            summarize_cohorts(rows)


if __name__ == "__main__":
    unittest.main()
