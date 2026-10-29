#!/usr/bin/env python3
"""Adversarial verification of Windows sharded source/case/log custody."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import verify_windows_godot_shards as subject


SOURCE = "a" * 40


def make_fixture(root: Path, *, count: int = 2) -> None:
    for shard in range(count):
        directory = root / f"shard-{shard}"
        directory.mkdir()
        names = ["alpha"] if shard == 0 else ["beta"]
        records = []
        seals = {}
        for role, name in [("preflight", "import"), *[("case", x) for x in names]]:
            log = name + ".log"
            data = (name + " passed\n").encode()
            (directory / log).write_bytes(data)
            records.append({"role": role, "name": name, "status": "passed", "log": log})
            seals[log] = hashlib.sha256(data).hexdigest()
        report = {
            "source_commit": SOURCE, "source_tree": "tree", "run_id": "123",
            "run_attempt": "1", "shard_count": count, "shard_index": shard,
            "status": "passed", "completed": True, "errors": [], "source_drift": [],
            "all_discovered_case_count": 3, "applicable_case_count": 2,
            "applicable_cases": ["alpha", "beta"],
            "out_of_scope_graphical_cases": ["graphical"],
            "assigned_cases": names, "case_plan": [{"name": n} for n in names],
            "executed_case_count": len(names), "results": records, "log_sha256": seals,
            "runtime_source_commit": "release", "runtime_build_commit": "build",
            "runtime_provenance": {"sha256": "manifest"},
            "native_source_inputs": {"world.cpp": "frozen"},
            "cybersand_runtime": {"sha256": "dll"},
            "rapier_runtime": {"sha256": "rapier"},
            "godot_identity": {"version": "4.7"}, "godot_version": "4.7",
            "tested_inputs": {"source": SOURCE},
        }
        (directory / "windows-execution.json").write_text(json.dumps(report), encoding="utf-8")


class WindowsCoverageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        make_fixture(self.root)

    def verify(self):
        return subject.verify(self.root, SOURCE, "123", "1", 2)

    def mutate(self, shard, change):
        path = self.root / f"shard-{shard}" / "windows-execution.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        change(data)
        path.write_text(json.dumps(data), encoding="utf-8")

    def test_complete_source_matched_shards(self):
        result = self.verify()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["unique_case_count"], 2)
        self.assertEqual(result["raw_logs_verified"], 4)

    def test_missing_original_shard_is_refused(self):
        (self.root / "shard-1" / "windows-execution.json").unlink()
        with self.assertRaisesRegex(ValueError, "expected 2"):
            self.verify()

    def test_duplicate_shard_index_is_refused(self):
        self.mutate(1, lambda r: r.update(shard_index=0))
        with self.assertRaisesRegex(ValueError, "invalid shard"):
            self.verify()

    def test_mismatched_source_is_refused(self):
        self.mutate(1, lambda r: r.update(source_commit="b" * 40))
        with self.assertRaisesRegex(ValueError, "wrong source"):
            self.verify()

    def test_changed_runtime_is_refused(self):
        self.mutate(1, lambda r: r["cybersand_runtime"].update(sha256="different"))
        with self.assertRaisesRegex(ValueError, "mismatch"):
            self.verify()

    def test_duplicate_case_from_both_shards_is_refused(self):
        directory = self.root / "shard-1"
        (directory / "alpha.log").write_bytes(b"alpha passed\n")
        def update(report):
            report["assigned_cases"] = ["alpha"]
            report["case_plan"] = [{"name": "alpha"}]
            report["results"][1]["name"] = "alpha"
            report["results"][1]["log"] = "alpha.log"
            report["log_sha256"]["alpha.log"] = report["log_sha256"].pop("beta.log")
        self.mutate(1, update)
        with self.assertRaisesRegex(ValueError, "missing or duplicated|modified or missing"):
            self.verify()

    def test_corrupted_original_log_is_refused(self):
        (self.root / "shard-0" / "alpha.log").write_bytes(b"tampered")
        with self.assertRaisesRegex(ValueError, "modified or missing original raw log"):
            self.verify()

    def test_incomplete_or_skipped_case_is_refused(self):
        self.mutate(0, lambda r: r["results"][1].update(status="skipped"))
        with self.assertRaisesRegex(ValueError, "missing, duplicated, unexecuted or failed"):
            self.verify()

    def test_wrong_run_attempt_is_refused(self):
        self.mutate(0, lambda r: r.update(run_attempt="2"))
        with self.assertRaisesRegex(ValueError, "wrong run/attempt"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
