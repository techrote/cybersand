"""Whole-job time must be attributed to a completed job and its actual runner."""
import copy
import unittest

import job_performance as subject


class JobTimes(unittest.TestCase):
    def setUp(self):
        self.job = {"id": 1, "name": "linux regression shard 0", "status": "completed", "conclusion": "success",
            "runner_name": "hosted-control", "started_at": "2026-10-31T19:00:00Z", "completed_at": "2026-10-31T19:03:00Z"}
        self.row = {"source": {"run_id": "123", "run_attempt": "1", "commit": "a"*40, "tree": "b"*40,
            "runner_name_sha256": subject.sha("hosted-control")}, "host": {"cpu_model": "control"},
            "fixture": "test", "phase": "case", "configuration": {"sample_ticks": 120}}

    def test_actual_completed_job_duration_and_runner_are_bound(self):
        rows, unavailable = subject.observations([self.job], [self.row], "123", "1")
        self.assertEqual(rows[0]["wall_seconds"], 180)
        self.assertEqual(rows[0]["host"], self.row["host"])
        self.assertFalse(unavailable)

    def test_wrong_attempt_or_unobserved_runner_has_no_invented_cpu(self):
        for run, attempt in (("123","2"),("124","1")):
            rows, missing = subject.observations([self.job], [self.row], run, attempt)
            self.assertFalse(rows)
            self.assertEqual(missing[0]["reason"], "no_unique_original_runner_observation")

    def test_failure_retains_original_conclusion_and_elapsed_time(self):
        self.job["conclusion"] = "failure"
        rows, _ = subject.observations([self.job], [self.row], "123", "1")
        self.assertEqual(rows[0]["result"], "failure")
        self.assertFalse(rows[0]["natural_completion"])
        self.assertEqual(rows[0]["wall_seconds"], 180)

    def test_running_or_invalid_job_clock_does_not_become_complete(self):
        self.job["status"] = "in_progress"
        self.assertEqual(subject.observations([self.job], [self.row], "123", "1"), ([], []))
        self.job.update(status="completed",completed_at="invalid")
        rows, missing = subject.observations([self.job], [self.row], "123", "1")
        self.assertFalse(rows)
        self.assertEqual(missing[0]["reason"], "invalid_completed_job_timestamps")

    def test_mixed_source_cannot_supply_a_job_identity(self):
        changed=copy.deepcopy(self.row);changed["source"]["commit"]="c"*40
        rows, missing = subject.observations([self.job], [self.row,changed], "123", "1")
        self.assertFalse(rows)
        self.assertEqual(missing[0]["reason"],"inconsistent_source_observations")


if __name__ == '__main__':
    unittest.main()
