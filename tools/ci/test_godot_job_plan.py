"""The hosted parent must contain every original sequential child allowance."""

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
                self.assertLessEqual(result["shard_count"], 256)
                self.assertLessEqual(result["job_minutes"], 360)
                for shard in result["shards"]:
                    self.assertTrue(shard["cases"])
                    self.assertLessEqual(shard["case_budget_seconds"] + result["import_with_cleanup_seconds"]
                        + result["metadata_seconds"], result["execution_seconds"])
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
