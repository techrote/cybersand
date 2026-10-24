#!/usr/bin/env python3
"""Retain failures and uncertainty when reducing historical physical CI logs."""

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import physical_timing_report as timing


class HistoricalTimingTests(unittest.TestCase):
    def rows(self, text):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "job.log"
            path.write_text(text, encoding="utf-8")
            return timing.historical_log_rows(path, "windows", "42", "2")

    def test_nonzero_exit_script_error_and_skip_are_not_passes(self):
        rows = self.rows(
            "2026-10-24T01:00:00Z Running test_physical_actor_arena, timeout 180s: []\n"
            "2026-10-24T01:00:02Z test_physical_actor_arena failed; exit=1; see arena.log\n"
            "2026-10-24T01:00:03Z Running test_physical_actor_rigs, timeout 180s: []\n"
            "2026-10-24T01:00:04Z SCRIPT ERROR: fixture problem\n"
            "2026-10-24T01:00:05Z Running test_physical_usable_course, timeout 180s: []\n"
            "2026-10-24T01:00:06Z SKIP display unavailable\n"
            "2026-10-24T01:00:07Z Running another_case, timeout 180s: []\n"
        )
        self.assertEqual([r["status"] for r in rows], ["failed", "failed", "skipped"])
        self.assertEqual([r["seconds"] for r in rows], [3, 2, 2])
        self.assertTrue(all(r["timing_basis"] == "next-start-boundary" for r in rows))

    def test_final_unfinished_case_is_retained_with_unknown_duration_and_outcome(self):
        rows = self.rows(
            "2026-10-24T01:00:00Z Running test_physical_actor_arena, timeout 180s: []\n"
            "2026-10-24T01:00:01Z REGRESSION_PROGRESS case=test_physical_actor_arena phase=roster_step rig=runner tick=60\n"
        )
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["status"], "unknown")
        self.assertIsNone(rows[0]["seconds"])
        self.assertIn("rig=runner tick=60", rows[0]["last_progress"])
        self.assertEqual(rows[0]["timing_basis"], "unavailable")

    def test_final_timeout_preserves_threshold_without_inventing_elapsed_time(self):
        rows = self.rows(
            "2026-10-24T01:00:00Z Running test_physical_actor_rigs, timeout 180s: []\n"
            "2026-10-24T01:03:08Z TIMEOUT after 180s\n"
            "2026-10-24T01:03:08Z test_physical_actor_rigs timeout; exit=None; see rigs.log\n"
        )
        self.assertEqual(rows[0]["status"], "timeout")
        self.assertEqual(rows[0]["timeout_seconds"], 180)
        self.assertIsNone(rows[0]["seconds"])
        self.assertEqual(timing.distributions(rows)[0]["timeout_frequency"], "1/1")

    def test_progress_watchdog_timeout_is_not_inferred_as_a_pass_or_180_second_measurement(self):
        prefix = (
            "2026-10-24T01:00:00Z Running test_physical_actor_rigs, timeout 180s: []\n"
            "2026-10-24T01:00:46Z TIMEOUT (progress_watchdog) after 45.106s; case limit 180s\n"
        )
        unfinished = self.rows(prefix)[0]
        self.assertEqual(unfinished["status"], "timeout")
        self.assertEqual(unfinished["timeout_seconds"], 180)
        self.assertIsNone(unfinished["seconds"])
        complete = self.rows(prefix + "2026-10-24T01:00:47Z Running another_case, timeout 180s: []\n")[0]
        self.assertEqual(complete["status"], "timeout")
        self.assertEqual(complete["seconds"], 47)
        self.assertEqual(complete["timing_basis"], "next-start-boundary")

    def test_final_explicit_failure_and_pass_keep_outcome_with_unknown_duration(self):
        for status, exitcode in (("failed", 1), ("passed", 0)):
            with self.subTest(status=status):
                row = self.rows(
                    "2026-10-24T01:00:00Z Running test_physical_actor_arena, timeout 180s: []\n"
                    f"2026-10-24T01:00:02Z test_physical_actor_arena {status}; exit={exitcode}\n"
                )[0]
                self.assertEqual(row["status"], status)
                self.assertIsNone(row["seconds"])

    def test_later_timeout_takes_precedence_over_script_error(self):
        rows = self.rows(
            "2026-10-24T01:00:00Z Running test_physical_actor_rigs, timeout 180s: []\n"
            "2026-10-24T01:00:01Z SCRIPT ERROR: fixture problem\n"
            "2026-10-24T01:03:00Z TIMEOUT after 180s\n"
            "2026-10-24T01:03:01Z Running another_case, timeout 180s: []\n"
        )
        self.assertEqual(rows[0]["status"], "timeout")
        self.assertEqual(rows[0]["seconds"], 181)


class TimingExportTests(unittest.TestCase):
    def test_unknown_or_invalid_durations_count_without_entering_distribution(self):
        durations = [1, None, "not-a-number", -1, float("inf"), float("nan"), True, 3]
        rows = [{"platform": "linux", "mode": "historical-job-log", "test": "test_physical_actor_arena",
                 "seconds": duration, "status": "passed" if i == 0 else "timeout" if i == 1 else "unknown"}
                for i, duration in enumerate(durations)]
        value = timing.distributions(rows)[0]
        self.assertEqual(value["samples"], 8)
        self.assertEqual(value["timed_samples"], 2)
        self.assertEqual(value["passed"], 1)
        self.assertEqual(value["timeouts"], 1)
        self.assertEqual(value["other_failures"], 6)
        self.assertEqual(value["timeout_frequency"], "1/8")
        self.assertEqual((value["median_s"], value["p95_s"], value["max_s"]), (2, 3, 3))

    def test_no_measured_duration_produces_no_zero_timing(self):
        value = timing.distributions([{
            "platform": "windows", "mode": "historical-job-log", "test": "test_physical_actor_rigs",
            "seconds": None, "status": "failed",
        }])[0]
        self.assertEqual(value["timed_samples"], 0)
        self.assertIsNone(value["median_s"])
        self.assertIsNone(value["p95_s"])
        self.assertIsNone(value["max_s"])

    def test_exports_actual_runtime_identities_for_all_json_formats(self):
        identity = {"godot_version": "4.7.stable.fixture", "cybersand_runtime": {"sha256": "b" * 64},
                    "rapier_runtime": {"sha256": "c" * 64}}
        record = {"role": "case", "name": "test_physical_actor_arena", "seconds": 3,
                  "status": "passed", "timeout_seconds": 180}
        payloads = {
            "timings.json": {"identity": {"source_sha": "a" * 40, **identity}, "results": [record]},
            "windows-execution.json": {"source_commit": "a" * 40, **identity, "results": [record]},
            "stress-summary.json": {"source_sha": "a" * 40, "godot_version": identity["godot_version"],
                                    "native_sha256": "b" * 64, "rapier_sha256": "c" * 64,
                                    "platform": "linux", "mode": "serial", "results": [record]},
        }
        with tempfile.TemporaryDirectory() as folder:
            for filename, payload in payloads.items():
                with self.subTest(filename=filename):
                    path = Path(folder) / filename
                    path.write_text(json.dumps(payload), encoding="utf-8")
                    row = timing.rows_from_json(path, "42", "2")[0]
                    self.assertEqual(row["source_sha"], "a" * 40)
                    self.assertEqual(row["godot_version"], identity["godot_version"])
                    self.assertEqual(row["native_sha256"], "b" * 64)
                    self.assertEqual(row["rapier_sha256"], "c" * 64)
                    self.assertEqual(row["timing_basis"], "runner-elapsed")


if __name__ == "__main__":
    unittest.main()
