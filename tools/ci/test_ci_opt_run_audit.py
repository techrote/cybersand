#!/usr/bin/env python3
from __future__ import annotations
import copy
import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parent))
import ci_opt_run_audit as audit


def fixture():
    return {"id": 80, "name": "GDExtension", "head_sha": "a" * 40,
            "event": "pull_request", "conclusion": "success", "total_count": 2,
            "jobs": [
                {"id": 1, "name": "linux build x86_64", "status": "completed",
                 "conclusion": "success", "started_at": "2026-11-21T10:00:00Z",
                 "completed_at": "2026-11-21T10:10:00Z"},
                {"id": 2, "name": "linux regression shard 0", "status": "completed",
                 "conclusion": "success", "started_at": "2026-11-21T10:05:00Z",
                 "completed_at": "2026-11-21T10:12:00Z"}]}


class AuditTests(unittest.TestCase):
    def test_wall_vs_runner_minutes(self):
        result = audit.analyze(fixture())
        self.assertEqual(result["known_runner_minutes"], 17)
        self.assertEqual(result["completed_job_span_minutes"], 12)
        self.assertEqual(result["runner_minutes_by_group"]["godot-regression"], 7)
        self.assertTrue(result["complete"])

    def test_inflight_is_not_estimated_as_complete(self):
        row = fixture()
        row["jobs"][1].update(status="in_progress", conclusion=None, completed_at=None)
        result = audit.analyze(row)
        self.assertFalse(result["complete"])
        self.assertEqual(result["known_runner_minutes"], 10)
        with self.assertRaises(ValueError):
            audit.compare(result, audit.analyze(fixture()))

    def test_failure_and_missing_jobs_block_comparison(self):
        first = audit.analyze(fixture())
        bad = fixture()
        bad["jobs"][0]["conclusion"] = "failure"
        with self.assertRaises(ValueError):
            audit.compare(first, audit.analyze(bad))
        bad = fixture()
        bad["total_count"] = 3
        with self.assertRaises(ValueError):
            audit.analyze(bad)

    def test_changed_source_or_test_inventory_refuses(self):
        before = audit.analyze(fixture())
        changed = fixture(); changed["head_sha"] = "b" * 40
        with self.assertRaises(ValueError):
            audit.compare(before, audit.analyze(changed))
        changed = fixture(); changed["jobs"][1]["name"] = "different test"
        with self.assertRaises(ValueError):
            audit.compare(before, audit.analyze(changed))

    def test_duplicate_job_is_rejected(self):
        changed = fixture(); changed["jobs"][1]["id"] = 1
        with self.assertRaises(ValueError):
            audit.analyze(changed)

    def test_new_engine_fetch_job_counts_cost_but_does_not_fake_test_coverage(self):
        old = audit.analyze(fixture())
        new = fixture()
        new["total_count"] = 3
        new["jobs"].append({
            "id": 3, "name": "Pinned Linux Godot archive shared by same-run shards",
            "status": "completed", "conclusion": "success",
            "started_at": "2026-11-21T10:01:00Z",
            "completed_at": "2026-11-21T10:02:00Z"})
        after = audit.analyze(new)
        self.assertEqual(after["runner_minutes_by_group"]["engine-preparation"], 1)
        self.assertEqual(audit.compare(old, after)["change_percent"], 5.88)

    def test_true_same_source_positive_comparison(self):
        before = audit.analyze(fixture())
        after = fixture()
        after["jobs"][1]["completed_at"] = "2026-11-21T10:11:00Z"
        result = audit.compare(before, audit.analyze(after))
        self.assertLess(result["change_percent"], 0)


if __name__ == "__main__":
    unittest.main()
