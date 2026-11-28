"""Actual native pool execution is mandatory before treating an arm as evidence."""
import copy
import json
import unittest
from run_comparison import (comparison_plan, comparison_role, compare_registered_direction,
                            task_completion_cases, campaign_settings, validate_task_completion,
                            TASK_COMPLETION_SELECTOR, TASK_COMPLETION_REGISTRATION,
                            TASK_COMPLETION_AMENDMENT, HERE)
from run_source_abba import GAP_THRESHOLDS


class TaskCompletionEvidence(unittest.TestCase):
    def test_original_registration_joins_actual_frozen_workloads(self):
        original = json.loads(TASK_COMPLETION_REGISTRATION.read_bytes())
        amendment = json.loads(TASK_COMPLETION_AMENDMENT.read_bytes())
        cases = task_completion_cases(original, amendment)
        campaign = campaign_settings(json.loads((HERE / "registration.json").read_bytes()), cases, False)
        self.assertEqual([case["id"] for case in campaign["cases"]],
                         ["wave_512_follow", "wave_gameplay_2048_follow"])
        self.assertEqual(original["comparison"]["workloads"][0], "wave512_follow")
        changed = copy.deepcopy(amendment)
        changed["workload_identifiers"]["wave512_follow"] = "wave_1024_follow_4"
        with self.assertRaises(ValueError): task_completion_cases(original, changed)

    def receipt(self, enabled):
        return {phase: {"requested": {TASK_COMPLETION_SELECTOR: "1" if enabled else "0"},
                        "task_completion": {"schema": "PUBPRES-TASK-COMPLETION-V1",
                                            "mode": "actual_tasks" if enabled else "all_workers",
                                            "completed_dispatches": count,
                                            "completed_tasks": count * 5}}
                for phase, count in (("selectors_before", 7), ("selectors_after", 107))}

    def test_actual_execution_and_frozen_control(self):
        for enabled in (False, True):
            self.assertEqual(validate_task_completion(self.receipt(enabled), enabled)["completed_tasks"], 500)
        self.assertEqual([item["task_completion"] for item in comparison_plan("task-completion-abba", 2)],
                         [False, True, True, False])

    def test_real_direction_reducer_receives_control_and_candidate_groups(self):
        plan = comparison_plan("task-completion-abba", 2)
        arms = []
        for index, treatment in enumerate(plan):
            candidate = treatment["task_completion"]
            arms.append({"arm": comparison_role("task-completion-abba", index, treatment["role"]),
                         "source_role": treatment["role"],
                         "statistics": {"windows": {"first_144_steps": {
                             "completed_rapier_steps": 144,
                             "rapier_steps_per_second": 40 if candidate else 20,
                             "physical_gap_ms": {key: 10 if candidate else 20 for key in ("p95", "p99", "max")}}},
                             "physical_gap_counts_above_ms": {"first_144_steps": {key: 0 for key in GAP_THRESHOLDS}}}})
        self.assertEqual([arm["source_role"] for arm in arms], ["C"] * 4)
        result = compare_registered_direction(arms)
        self.assertTrue(result["repeatable_direction"])
        # A slower treatment must remain adverse; group labels may not select it.
        arms[1]["statistics"]["windows"]["first_144_steps"]["rapier_steps_per_second"] = 10
        self.assertFalse(compare_registered_direction(arms)["repeatable_direction"])

    def test_noop_and_one_worker_are_not_exercised(self):
        data = self.receipt(True)
        data["selectors_after"] = copy.deepcopy(data["selectors_before"])
        with self.assertRaises(ValueError): validate_task_completion(data, True)

    def test_coerced_or_negative_counts_refuse(self):
        for key, value in (("completed_dispatches", True), ("completed_tasks", "535"),
                           ("completed_tasks", -1), ("completed_tasks", 0)):
            data = self.receipt(True)
            data["selectors_after"]["task_completion"][key] = value
            with self.subTest(key=key,value=value), self.assertRaises(ValueError): validate_task_completion(data, True)

    def test_wrong_actual_native_policy_refuses(self):
        for enabled in (False, True):
            data = self.receipt(enabled)
            data["selectors_after"]["task_completion"]["mode"] = "all_workers" if enabled else "actual_tasks"
            with self.assertRaises(ValueError): validate_task_completion(data, enabled)

    def test_counter_reset_and_wrong_request_refuse(self):
        data = self.receipt(True)
        data["selectors_after"]["task_completion"]["completed_dispatches"] = 3
        with self.assertRaises(ValueError): validate_task_completion(data, True)
        data = self.receipt(True)
        data["selectors_after"]["requested"][TASK_COMPLETION_SELECTOR] = "0"
        with self.assertRaises(ValueError): validate_task_completion(data, True)


if __name__ == "__main__": unittest.main()
