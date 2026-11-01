"""Expected-cost planning preserves inventory and full individual allowances."""

from collections import Counter
import copy
from pathlib import Path
import re
import unittest
from unittest import mock

import execution_policy
import godot_job_plan as subject
import run_godot_regressions as runner


class HostedBudgetTests(unittest.TestCase):
    def test_original_linux_and_windows_inventory_is_complete_and_fits(self):
        all_cases = runner.discover_cases()
        for platform in ("linux", "windows"):
            cases = [case for case in all_cases if platform == "linux" or not case.requires_display]
            result = subject.plan(cases, platform=platform)
            with self.subTest(platform=platform):
                self.assertEqual(Counter(row["name"] for shard in result["shards"] for row in shard["cases"]),
                                 Counter(case.name for case in cases))
                self.assertGreaterEqual(result["shard_count"], 12)
                self.assertLessEqual(result["shard_count"], 24)
                self.assertLessEqual(result["job_minutes"], 360)
                for shard in result["shards"]:
                    self.assertTrue(shard["cases"])
                    self.assertLessEqual(shard["largest_case_allowance_seconds"] + result["import_with_cleanup_seconds"]
                        + result["metadata_seconds"], result["execution_seconds"])
                    self.assertFalse(shard["watchdog_sum_is_execution_deadline"])
                self.assertGreater(max(shard["case_budget_seconds"] for shard in result["shards"]),
                                   result["execution_seconds"], "Planning must not sum exceptional watchdog ceilings")
                self.assertLessEqual(result["execution_minutes"] * 60 + result["setup_artifact_seconds"]
                    + result["aggregate_headroom_seconds"], result["job_minutes"] * 60)

    def test_cannot_shorten_a_child_to_fit_a_small_parent(self):
        huge = runner.Case("large", (), 21600, 1)
        with self.assertRaisesRegex(ValueError, "child watchdog"):
            subject.plan([huge], platform="linux")

    def test_policy_scale_cannot_claim_more_than_hosted_limit(self):
        value = copy.deepcopy(execution_policy.identity())
        value["watchdogs"]["godot_job_minutes"] = 361
        with mock.patch.object(execution_policy, "identity", return_value=value):
            with self.assertRaisesRegex(ValueError, "six-hour"):
                subject.plan([runner.Case("small", (), 1, 1)], platform="linux")

    def test_planning_is_deterministic_and_weights_are_only_estimates(self):
        cases = [runner.Case(str(i), (), 3600, i + 1) for i in range(12)]
        first = subject.plan(cases, platform="linux")
        second = subject.plan(cases, platform="linux")
        self.assertEqual(first, second)
        self.assertEqual(sum(s["case_budget_seconds"] for s in first["shards"]), 12 * 4140)
        self.assertEqual(first["import_with_cleanup_seconds"], 1440)

    def test_typical_work_is_balanced_by_expected_cost_not_watchdog(self):
        cases = [runner.Case(str(i), (), 1200 if i % 2 else 3940, 15) for i in range(240)]
        result = subject.plan(cases, platform="linux")
        estimates = [shard["estimated_seconds"] for shard in result["shards"]]
        self.assertLessEqual(max(estimates) - min(estimates), 15)
        self.assertEqual(result["shard_count"], 15)

    def test_many_cheap_cases_cannot_all_collect_behind_expensive_bins(self):
        cases = [runner.Case("heavy" + str(i), (), 3940, 300) for i in range(16)]
        cases += [runner.Case("cheap" + str(i), (), 1200, 1) for i in range(240)]
        result = subject.plan(cases, platform="linux")
        self.assertLessEqual(max(len(shard["cases"]) for shard in result["shards"]), 16)
        self.assertEqual(sum(len(shard["cases"]) for shard in result["shards"]), 256)

    def test_expensive_case_keeps_watchdog_and_others_are_distributed(self):
        cases = [runner.Case("outlier", (), 3940, 1200)] + [runner.Case(str(i), (), 1200, 15) for i in range(240)]
        result = subject.plan(cases, platform="linux")
        containing = next(shard for shard in result["shards"] if any(c["name"] == "outlier" for c in shard["cases"]))
        self.assertEqual(len(containing["cases"]), 1)
        self.assertEqual(containing["cases"][0]["timeout_seconds"], 3940)
        self.assertEqual(sum(len(s["cases"]) for s in result["shards"]), len(cases))

    def test_expected_work_cannot_silently_exceed_hosted_boundary(self):
        with self.assertRaisesRegex(ValueError, "estimated case"):
            subject.plan([runner.Case("oversized", (), 3940, 20000)], platform="linux")
        with self.assertRaisesRegex(ValueError, "matrix limit"):
            subject.plan([runner.Case(str(i), (), 1200, 10000) for i in range(257)], platform="linux")

    def test_invalid_weights_and_duplicate_inventory_fail(self):
        for weight in (0, -1, float("inf"), float("nan"), True):
            with self.subTest(weight=weight), self.assertRaises(ValueError):
                subject.plan([runner.Case("invalid", (), 1200, weight)], platform="linux")
        with self.assertRaisesRegex(RuntimeError, "exactly once"):
            subject.plan([runner.Case("duplicate", (), 1200, 5)] * 2, platform="linux")

    def test_zero_cases_and_setup_consuming_parent_are_errors(self):
        with self.assertRaisesRegex(ValueError, "contain cases"):
            subject.plan([], platform="linux")
        value = copy.deepcopy(execution_policy.identity())
        value["watchdogs"]["godot_setup_seconds"] = 21600
        with mock.patch.object(execution_policy, "identity", return_value=value):
            with self.assertRaisesRegex(ValueError, "Setup"):
                subject.plan([runner.Case("small", (), 1200, 5)], platform="linux")

    def test_actual_workflow_setup_steps_fit_the_reserved_budget(self):
        source = (execution_policy.ROOT / ".github/workflows/gdextension.yml").read_text()
        for name, following in (("windows-regression", "windows-coverage"), ("linux-regression", "linux-regression-gate")):
            block = source.split("  " + name + ":\n", 1)[1].split("  " + following + ":\n", 1)[0]
            steps = re.findall(r"^      - name: (.+)$", block, re.M)
            allowances = [int(value) for value in re.findall(r"^        timeout-minutes: ([0-9]+)$", block, re.M)]
            with self.subTest(job=name):
                self.assertEqual(len(allowances), len(steps) - 1, "Every preparation/retention step needs a declared allowance")
                self.assertLessEqual(sum(allowances) * 60, execution_policy.watchdog_seconds("godot_setup_seconds"))


if __name__ == "__main__":
    unittest.main()
