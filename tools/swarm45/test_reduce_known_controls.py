"""Adversarial reducer fixtures only; no synthetic row is execution evidence."""
from __future__ import annotations

from collections import Counter
import copy
import gzip
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import reduce_known_controls as reducer
import replay_known_controls as replay
import runtime_custody as custody


class OriginalKnownControls(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / "candidate").mkdir()
        self.source = {"source_commit": "a" * 40, "native_definition_sha256": "b" * 64}
        self.receipt = {**self.source, "files": {"replay_swarm005_known": {"sha256": "c" * 64}}}
        mock = patch.object(custody, "source", return_value=self.source)
        mock.start(); self.addCleanup(mock.stop)
        self.documents, self.rows = [], []
        for index, case in enumerate(replay.CASES):
            value = {"schema": 5, "type": "reciprocal_assembly", "source": "swarm005-unseen-holdout-v1",
                     "status": "exhausted", "can_apply": False, "joints": [], "rounds": [], "cells": [0],
                     "metrics": {"total_charged_work": 27, "frame_work": 3, "mosaic_work": 7,
                                 "solver_work": 11, "shared_work": 6},
                     "input": {"options": reducer.policy_options(case[3])}}
            for owner, prefix in (("frame", "frameweaver.frontier-growth-v0."), ("mosaic", "mosaic.prepared-regions-v0.")):
                value["input"][owner] = {"definition": prefix + self.receipt["native_definition_sha256"],
                                        "source": value["source"], "fixture": case[0], "profile": {"name": case[1]},
                                        "seed": case[2]}
            self.documents.append(value)
            self.rows.append({"case_id": index, **dict(zip(("fixture", "profile", "seed", "policy"), case)),
                              "exitcode": 0, "stderr": "", "elapsed_seconds": 0.01})
            self.retain(index)
        self.manifest = {"schema": 1, "programme": "SWARM004-005-mainline-known-matrix-regression",
                         "registration": "https://github.com/techrote/cybersand/issues/698", "unseen": False,
                         "qualifying_source": True, "source": self.source, "expected_cases": 360,
                         "normalization": replay.NORMALIZATION, "result": "PASS", "errors": [], "records": self.rows,
                         "driver_sha256": custody.sha(custody.ROOT / "tools/swarm45/replay_known_control.cpp"),
                         "runner_sha256": custody.sha(custody.ROOT / "tools/swarm45/replay_known_controls.py"),
                         "executable_sha256": self.receipt["files"]["replay_swarm005_known"]["sha256"]}
        self.write_manifest()

    def retain(self, index):
        value, row = self.documents[index], self.rows[index]
        raw = json.dumps(value).encode()
        compressed = gzip.compress(raw, mtime=0)
        name = f"case-{index:03}.json.gz"
        (self.root / "candidate" / name).write_bytes(compressed)
        row.update(raw_sha256=replay.sha(raw), raw_bytes=len(raw), gzip_sha256=replay.sha(compressed),
                   gzip_bytes=len(compressed), file=name, behavior_sha256=replay.behavior_hash(value),
                   stdout=value["status"] + " apply=" + str(int(value["can_apply"])) + "\n", **replay.metrics(value))

    def write_manifest(self):
        self.manifest["summary"] = {policy: dict(Counter(row["status"] for row in self.rows if row["policy"] == policy))
                                    for policy in replay.POLICIES}
        (self.root / "manifest.json").write_text(json.dumps(self.manifest))

    def validate(self):
        self.write_manifest()
        return reducer.validate_known_controls(self.root, self.receipt)

    def test_complete_distinct_inventory_preserves_unknown_closure_failures(self):
        self.assertEqual(self.validate()["executions"], 360)
        self.assertIsNone(self.rows[0]["still_required"])
        self.assertFalse(self.rows[0]["closure_evaluated"])

    def test_count_does_not_admit_duplicates_reordered_or_missing_cases(self):
        original = copy.deepcopy(self.rows)
        for rows in ([copy.deepcopy(original[0]) for _ in original], list(reversed(original)), original[:-1]):
            with self.subTest(count=len(rows)):
                self.rows[:] = rows
                with self.assertRaises(ValueError):
                    self.validate()

    def test_original_child_failure_cannot_be_relabelled_passed(self):
        for changes in ({"exitcode": 99}, {"error": "native failed"}, {"timed_out": True}, {"stderr": "native failure"}):
            original = self.rows[0].copy()
            self.rows[0].update(changes)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.validate()
            self.rows[0] = original

    def test_rehashed_wrong_native_identity_or_policy_is_refused(self):
        original = copy.deepcopy(self.documents[0])
        changes = (("source", "forged"), ("fixture", "foreign_solid"), ("profile", {"name": "viaduct_like"}),
                   ("seed", 999), ("definition", "frameweaver.frontier-growth-v0." + "f" * 64))
        for key, wrong in changes:
            self.documents[0] = copy.deepcopy(original)
            self.documents[0]["input"]["frame"][key] = wrong
            self.retain(0)
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate()
        self.documents[0] = original
        self.documents[0]["input"]["options"]["supported_native_receptors"] = True
        self.retain(0)
        with self.assertRaisesRegex(ValueError, "native policy"):
            self.validate()

    def test_rehashed_invalid_status_and_false_apply_are_refused(self):
        for status in ("invalid", "exhausted"):
            self.documents[0]["status"] = status
            self.documents[0]["can_apply"] = True
            self.retain(0)
            with self.subTest(status=status), self.assertRaises(ValueError):
                self.validate()

    def test_summary_work_cannot_replace_original_native_metrics(self):
        self.rows[0]["total_charged_work"] += 1
        with self.assertRaisesRegex(ValueError, "summary differs"):
            self.validate()

    def test_raw_json_size_hash_and_gzip_are_checked(self):
        self.rows[0]["raw_sha256"] = "f" * 64
        with self.assertRaisesRegex(ValueError, "original JSON"):
            self.validate()
        self.retain(0)
        (self.root / "candidate" / self.rows[0]["file"]).write_bytes(b"not native output")
        with self.assertRaisesRegex(ValueError, "compressed bytes"):
            self.validate()


if __name__ == "__main__":
    unittest.main()
