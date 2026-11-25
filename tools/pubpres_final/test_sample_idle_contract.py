"""Reject unexercised, coerced and mislabeled completed-sample idle evidence."""
import copy
import unittest
from run_comparison import comparison_plan, validate_sample_idle, SAMPLE_IDLE_SELECTOR


class SampleIdleEvidence(unittest.TestCase):
    def receipt(self, enabled):
        result = {}
        for phase, count in (("selectors_before", 3 if enabled else 0), ("selectors_after", 7 if enabled else 0)):
            result[phase] = {"requested": {SAMPLE_IDLE_SELECTOR: "1" if enabled else "0"},
                             "workbench_sample_idle": {"enabled": enabled, "heartbeat_usec": 250000,
                                                       "physical_credit": 0, "waits": count,
                                                       "wait_usec": count * 1000}}
        return result

    def test_true_runtime_execution_and_control(self):
        self.assertEqual(validate_sample_idle(self.receipt(True), True)["capture_waits"], 4)
        self.assertEqual(validate_sample_idle(self.receipt(False), False)["capture_waits"], 0)
        self.assertEqual([v["sample_idle"] for v in comparison_plan("sample-idle-abba", 2)],
                         [False, True, True, False])

    def test_no_op_is_not_treatment(self):
        data = self.receipt(True)
        data["selectors_after"] = copy.deepcopy(data["selectors_before"])
        with self.assertRaises(ValueError): validate_sample_idle(data, True)

    def test_actual_selector_cannot_differ(self):
        data = self.receipt(True)
        data["selectors_after"]["workbench_sample_idle"]["enabled"] = False
        with self.assertRaises(ValueError): validate_sample_idle(data, True)

    def test_coerced_counts_and_physical_credit_refuse(self):
        for key, value in (("waits", True), ("wait_usec", "7000"), ("heartbeat_usec", True),
                           ("physical_credit", False), ("physical_credit", 1)):
            data = self.receipt(True)
            data["selectors_after"]["workbench_sample_idle"][key] = value
            with self.subTest(key=key,value=value), self.assertRaises(ValueError):
                validate_sample_idle(data, True)

    def test_regressed_and_contaminated_controls_refuse(self):
        data = self.receipt(True)
        data["selectors_after"]["workbench_sample_idle"]["waits"] = 1
        with self.assertRaises(ValueError): validate_sample_idle(data, True)
        data = self.receipt(False)
        data["selectors_before"]["workbench_sample_idle"]["waits"] = 1
        with self.assertRaises(ValueError): validate_sample_idle(data, False)


if __name__ == "__main__": unittest.main()
