#!/usr/bin/env python3
"""Scheduling reduction rejects partial/mixed inventories and separates clocks."""
import json
from pathlib import Path
import tempfile
import unittest
import ci_run_metrics as metrics


def job(number, start, end, *, created="2026-11-01T00:10:00Z", conclusion="success"):
    return {"id": number, "run_id": 10, "run_attempt": 1, "status": "completed",
            "name": f"linux regression shard {number}", "conclusion": conclusion,
            "created_at": created, "started_at": start, "completed_at": end,
            "steps": [{"name": "Run isolated regression shard with actual rendered-pixel tests",
                       "started_at": start, "completed_at": end, "conclusion": conclusion}]}


class MetricsTests(unittest.TestCase):
    def test_full_pagination_required(self):
        pages = [{"total_count": 3, "jobs": [{"id": 1}, {"id": 2}]},
                 {"total_count": 3, "jobs": [{"id": 3}]}]
        self.assertEqual(len(metrics.flatten_pages(pages, "jobs")), 3)
        with self.assertRaisesRegex(ValueError, "Truncated"):
            metrics.flatten_pages(pages[:1], "jobs")
        pages[1]["jobs"] = [{"id": 2}]
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            metrics.flatten_pages(pages, "jobs")

    def test_clocks_and_skips(self):
        jobs = [job(1, "2026-11-01T00:12:00Z", "2026-11-01T00:14:00Z"),
                job(2, "2026-11-01T00:13:00Z", "2026-11-01T00:15:00Z"),
                job(3, "2026-11-01T00:10:00Z", "2026-11-01T00:10:00Z", conclusion="skipped")]
        result = metrics.summarize({"id": 10, "created_at": "2026-11-01T00:00:00Z"}, jobs, 1)
        self.assertEqual(result["pre_dispatch_seconds"], 600)
        self.assertEqual(result["workflow_created_to_last_job_seconds"], 900)
        self.assertEqual(result["total_runner_execution_seconds"], 240)
        self.assertEqual(result["peak_active_jobs"], 2)
        self.assertEqual(result["job_records"], 3)
        self.assertEqual(result["executed_jobs"], 2)
        self.assertEqual(result["groups"]["linux_regression"]["queue_seconds"]["median"], 150)
        self.assertIsNone(result["jobs"][2]["queue_seconds"])

    def test_peak_half_open_intervals(self):
        jobs = [job(1, "2026-11-01T00:10:00Z", "2026-11-01T00:11:00Z"),
                job(2, "2026-11-01T00:11:00Z", "2026-11-01T00:12:00Z")]
        self.assertEqual(metrics.peak_active(jobs), 1)

    def test_incomplete_and_mixed_attempt_rejected(self):
        jobs = [job(1, "2026-11-01T00:10:00Z", "2026-11-01T00:11:00Z")]
        jobs[0]["status"] = "in_progress"
        with self.assertRaisesRegex(ValueError, "completed"):
            metrics.summarize({"id": 10}, jobs, 1)
        jobs[0]["status"] = "completed"
        with self.assertRaisesRegex(ValueError, "Mixed"):
            metrics.summarize({"id": 10}, jobs, 2)

    def test_bad_clock_is_unavailable(self):
        self.assertIsNone(metrics.elapsed("2026-11-01T00:11:00Z", "2026-11-01T00:10:00Z"))
        self.assertIsNone(metrics.elapsed("2026-11-01T00:10:00", "2026-11-01T00:11:00Z"))

    def test_step_classification_and_outlier(self):
        self.assertEqual(metrics.step_phase("Retain shard evidence"), "publication_and_teardown")
        self.assertEqual(metrics.step_phase("Install software rendering display"), "preparation_and_controls")
        result = metrics.distribution([1, 1, 1, 1, 500])
        self.assertEqual(result["median"], 1)
        self.assertEqual(result["p95"], 500)

    def test_evidence_missing_cases_remain_explicit(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = {"commit": "a" * 40, "tree": "b" * 40,
                      "run_id": "10", "run_attempt": "1", "tracked_delta_sha256": None}
            (root / "execution-plan.json").write_text(json.dumps({"linux": {"shard_count": 1,
                "source": source,
                "shards": [{"cases": [{"name": "a"}, {"name": "b"}]}]}}), encoding="utf-8")
            row = {"source": source.copy(),
                   "phase": "case", "host": {"platform": "Linux"}, "fixture": "a", "wall_seconds": 5,
                   "result": "passed", "natural_completion": True, "watchdog_reached": False}
            (root / "current.jsonl").write_text(json.dumps(row) + "\n", encoding="utf-8")
            (root / "linux-coverage.json").write_text('{"status":"failed","error":"missing shard"}', encoding="utf-8")
            platform = metrics.summarize_evidence(root, run_id=10, attempt=1)["platforms"]["linux"]
            self.assertEqual(platform["missing_observed_cases"], ["b"])
            self.assertEqual(platform["coverage_verdict"]["status"], "failed")
            self.assertEqual(platform["successful_natural_cases"], 1)
            (root / "current.jsonl").write_text((json.dumps(row) + "\n") * 2, encoding="utf-8")
            self.assertEqual(metrics.summarize_evidence(root, run_id=10, attempt=1)["platforms"]["linux"]["duplicate_observed_cases"], ["a"])
            for key, value in (("commit", "c" * 40), ("tree", "d" * 40), ("run_id", "11"), ("run_attempt", "2")):
                with self.subTest(key=key):
                    row["source"] = {**source, key: value}
                    (root / "current.jsonl").write_text(json.dumps(row) + "\n", encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "source/run/attempt"):
                        metrics.summarize_evidence(root, run_id=10, attempt=1)
            row["source"] = source
            (root / "current.jsonl").write_text(json.dumps(row) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "source/run/attempt"):
                metrics.summarize_evidence(root, run_id=11, attempt=1)
            (root / "linux-coverage.json").write_text(json.dumps({"status": "passed", "source_sha": source["commit"],
                "source_tree": source["tree"], "run_id": "11", "run_attempt": "1"}), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "source/run/attempt"):
                metrics.summarize_evidence(root, run_id=10, attempt=1)

    def test_original_clean_and_materialized_runtime_deltas_are_preserved(self):
        # Shape recovered from original run 44967549040/attempt 2: preflight
        # and case telemetry share source/run/attempt, with both null and digest
        # tracked deltas. Reporting them must neither crash nor erase a delta.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = {"commit": "662df51cd8409a52332fa7ef15d06d8ab8945aed",
                      "tree": "39b658c5de9c5e541312b5190bd5d8ba797c6bed",
                      "run_id": "44967549040", "run_attempt": "2"}
            delta = "b0080a34bea508f46f0a0057dfe36eab18a77593a9fcc3401fe2fdd905ab10dd"
            (root / "execution-plan.json").write_text(json.dumps({"linux": {
                "shard_count": 1, "source": source,
                "shards": [{"cases": [{"name": "sample"}]}]}}), encoding="utf-8")
            rows = [{"source": {**source, "tracked_delta_sha256": value},
                     "phase": phase, "fixture": fixture, "host": {"platform": "Linux"},
                     "wall_seconds": 1, "result": "passed", "natural_completion": True,
                     "watchdog_reached": False}
                    for value, phase, fixture in ((None, "preflight", "import"),
                                                   (delta, "case", "sample"))]
            (root / "linux-coverage.json").write_text(json.dumps({
                "status": "passed", "source_sha": source["commit"],
                "source_tree": source["tree"], "run_id": source["run_id"],
                "run_attempt": source["run_attempt"]}), encoding="utf-8")
            expected = [(source["commit"], source["tree"], None),
                        (source["commit"], source["tree"], delta)]
            for order in (rows, list(reversed(rows)), [*rows, rows[0]]):
                (root / "current.jsonl").write_text(
                    "".join(json.dumps(row) + "\n" for row in order), encoding="utf-8")
                result = metrics.summarize_evidence(root, run_id=44967549040, attempt=2)
                self.assertEqual(result["tested_sources"], expected)
                self.assertEqual(result["platforms"]["linux"]["successful_natural_cases"], 1)
                self.assertEqual(result["platforms"]["linux"]["missing_observed_cases"], [])


if __name__ == "__main__":
    unittest.main()
