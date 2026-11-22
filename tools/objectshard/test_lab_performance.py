"""Synthetic negative cases for interpreting retained performance evidence."""
from copy import deepcopy
import json
from pathlib import Path
import unittest

from lab_performance import check


class PerformanceEvidence(unittest.TestCase):
    def setUp(self) -> None:
        self.budget = json.loads(Path(__file__).with_name("lab_budgets.json").read_text())
        self.budget.update(minimum_samples_per_workload=2, required_workloads=["fixture"])
        self.case = {"name": "fixture", "failed": False, "profile_samples": [{"frame_usec": 1}, {"frame_usec": 10}],
                     "timings": {"frame_usec": {"samples": 2, "p95": 10, "p99": 10, "max": 10}},
                     "promotion_max_usec": 1, "physics_metrics": {"geometry_install_max_usec": 1},
                     "native_metrics": {"maximum_geometry_age": 0, "maximum_geometry_wait_ns": 1000}}
        self.report = {"schema": "objectshard-lab-profile-v1", "failures": 0, "rendered": False, "cases": [self.case]}

    def test_complete_synthetic_observation(self) -> None:
        self.assertEqual(check(self.report, self.budget, rendered=False)["status"], "passed")

    def test_missing_or_duplicated_workload(self) -> None:
        for cases in ([], [self.case, self.case]):
            with self.subTest(cases=len(cases)):
                self.assertEqual(check({**self.report, "cases": cases}, self.budget, rendered=False)["status"], "failed")

    def test_summary_cannot_hide_a_sparse_stall(self) -> None:
        report = deepcopy(self.report)
        report["cases"][0]["profile_samples"][1]["frame_usec"] = 999999
        result = check(report, self.budget, rendered=False)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(any("summary differs" in message for message in result["failures"]))

    def test_missing_or_nan_frame_is_not_dropped(self) -> None:
        for sample in ({}, {"frame_usec": float("nan")}):
            report = deepcopy(self.report)
            report["cases"][0]["profile_samples"][1] = sample
            self.assertEqual(check(report, self.budget, rendered=False)["status"], "failed")

    def test_failed_worker_and_wrong_render_scope_are_refused(self) -> None:
        for update in ({"failures": 1}, {"rendered": True}):
            self.assertEqual(check({**self.report, **update}, self.budget, rendered=False)["status"], "failed")


if __name__ == "__main__":
    unittest.main()
