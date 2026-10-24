#!/usr/bin/env python3
"""Synthetic no-Godot proof of physical timeout evidence and stress readback."""

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stress_physical_godot as stress
import physical_timing_report as timing
import aggregate_physical_stress as aggregate


class TimingContractTests(unittest.TestCase):
    def test_nearest_rank_p95_is_conservative(self):
        self.assertEqual(timing.percentile95([1, 2, 3, 4, 180]), 180)
        self.assertEqual(timing.percentile95([1, 2]), 2)

    def test_retains_failure_and_last_progress(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "timings.json"
            path.write_text(json.dumps({
                "identity": {"source_sha": "a" * 40}, "results": [
                    {"name": "import", "role": "preflight", "status": "passed", "seconds": 1},
                    {"name": "test_physical_actor_arena", "role": "case", "status": "timeout",
                     "seconds": 180, "timeout_seconds": 180,
                     "last_progress": "REGRESSION_PROGRESS case=arena phase=roster_step rig=runner tick=60"},
                    {"name": "test_material", "role": "case", "status": "passed", "seconds": 1},
                ],
            }), encoding="utf-8")
            rows = timing.rows_from_json(path, "42", "2")
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["status"], "timeout")
            self.assertEqual(rows[0]["run_id"], "42")
            self.assertIn("rig=runner", rows[0]["last_progress"])
            distribution = timing.distributions(rows)
            self.assertEqual(distribution[0]["timeouts"], 1)
            self.assertEqual(distribution[0]["p95_s"], 180)

    def test_historical_job_logs_do_not_erase_timeout(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "job.log"
            path.write_text(
                "2026-10-23T01:00:00Z Running test_physical_actor_arena, timeout 180s: []\n"
                "2026-10-23T01:03:00Z TIMEOUT after 180s\n"
                "2026-10-23T01:03:00.010Z Running test_physical_actor_rigs, timeout 180s: []\n"
                "2026-10-23T01:03:19Z Running another_case, timeout 180s: []\n",
                encoding="utf-8",
            )
            rows = timing.historical_log_rows(path, "windows", "77", "1")
            self.assertEqual(len(rows), 2)
            self.assertEqual(rows[0]["status"], "timeout")
            self.assertAlmostEqual(rows[0]["seconds"], 180.01)
            self.assertEqual(rows[1]["status"], "passed")


class StressContractTests(unittest.TestCase):
    def test_last_phase_distribution(self):
        rows = [{"role": "case", "name": "test_physical_actor_arena", "seconds": 180,
                 "status": "timeout", "last_progress": "REGRESSION_PROGRESS phase=world_built"}]
        value = stress.summarize(rows)
        arena = value[0]
        self.assertEqual(arena["timeouts"], 1)
        self.assertEqual(arena["timeout_by_last_phase"], {"world_built": 1})
        self.assertEqual(arena["median_seconds"], 180)

    def test_missing_batches_refuse_admission(self):
        with tempfile.TemporaryDirectory() as tmp:
            files = []
            for platform in ("linux", "win32"):
                for mode in ("serial", "parallel"):
                    path = Path(tmp) / f"{platform}-{mode}.json"
                    rows = [{"name": case, "role": "case", "status": "passed", "seconds": 5,
                             "timeout_seconds": 180, "repetition": 1}
                            for case in stress.CASES]
                    path.write_text(json.dumps({
                        "status": "passed", "completed": True, "mode": mode, "platform": platform,
                        "batch": 0, "source_sha": "a"*40, "godot_version": "fixture",
                        "native_sha256": "b"*64, "rapier_sha256": "c"*64,
                        "run_id": "42", "run_attempt": "1", "cases": list(stress.CASES), "repetitions": 1,
                        "results": [{"name": "import", "role": "preflight", "status": "passed", "seconds": 1}, *rows],
                    }), encoding="utf-8")
                    files.append(path)
            identity = {"expected_source_sha": "a"*40, "expected_run_id": "42", "expected_run_attempt": "1"}
            rows, errors = aggregate.aggregate(files, batches=1, per_batch=1, **identity)
            self.assertEqual(len(rows), 12)
            self.assertFalse(errors, errors)
            missing, errors = aggregate.aggregate(files[:-1], batches=1, per_batch=1, **identity)
            self.assertTrue(any("expected one file" in error for error in errors))
            path = files[0]
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["results"][1]["status"] = "timeout"
            path.write_text(json.dumps(payload), encoding="utf-8")
            _, errors = aggregate.aggregate(files, batches=1, per_batch=1, **identity)
            self.assertTrue(any("timeout" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
