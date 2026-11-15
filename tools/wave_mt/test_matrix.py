#!/usr/bin/env python3
"""Regression contracts for retained benchmark failures and source custody."""
from __future__ import annotations

import contextlib
import csv
import importlib.util
import io
import json
import pathlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("wave_run_matrix", HERE / "run_matrix.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

HEADER = ("size,scene,family,variant,workers_requested,workers_configured,workers_observed,"
          "warm_ticks,measured_ticks,wave_substeps,tick_p50_ms,tick_p95_ms,tick_max_ms,native_ticks_per_s\n")
ROW = "128,dam,5,0,1,1,1,0,1,1,1e-3,0.002,0.003,1000\n"
IDENTITY = {"head": "frozen", "tree": "tree", "working_tree_status": "", "source_sha256": "stable", "source_files": {}}


class MatrixContractTests(unittest.TestCase):
    def run_case(self, outcome, identity_after=None):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            executable = root / "benchmark"
            executable.write_bytes(b"test executable identity")
            out = root / "matrix.csv"
            arguments = ["run_matrix", "--exe", str(executable), "--out", str(out), "--sizes", "128",
                         "--scenes", "dam", "--solvers", "5:0", "--workers", "1", "--repeats", "1",
                         "--warm", "0", "--ticks", "1"]
            header = subprocess.CompletedProcess([], 0, HEADER, "")
            with patch.object(runner.sys, "argv", arguments), patch.object(runner.subprocess, "run", side_effect=[header, outcome]), \
                    patch.object(runner, "source_identity", side_effect=[IDENTITY, identity_after or IDENTITY]), \
                    patch.object(runner.platform, "platform", return_value="test OS"), \
                    patch.object(runner.platform, "processor", return_value="test CPU"), \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                result = runner.main()
            with out.open(newline="") as handle:
                rows = list(csv.DictReader(handle))
            raw = [json.loads(line) for line in out.with_suffix(".runs.jsonl").read_text().splitlines()]
            metadata = json.loads(out.with_suffix(".metadata.json").read_text())
            return result, rows, raw, metadata

    def test_valid_scientific_notation_and_exact_configuration_pass(self):
        result, rows, raw, metadata = self.run_case(subprocess.CompletedProcess([], 0, ROW, ""))
        self.assertEqual(result, 0)
        self.assertEqual(rows[0]["status"], "PASS")
        self.assertEqual(raw[0]["stdout"], ROW)
        self.assertEqual(metadata["completed_rows"], metadata["planned_rows"])
        self.assertEqual(metadata["failed_rows"], 0)

    def test_process_failure_is_not_a_successful_campaign(self):
        result, rows, raw, metadata = self.run_case(subprocess.CompletedProcess([], 9, "partial", "conservation mismatch"))
        self.assertEqual(result, 1)
        self.assertEqual(rows[0]["status"], "FAIL")
        self.assertEqual(raw[0]["stderr"], "conservation mismatch")
        self.assertEqual(metadata["failed_rows"], 1)

    def test_timeout_is_retained_and_fails(self):
        result, rows, raw, _ = self.run_case(subprocess.TimeoutExpired(["fixture"], 1, output=b"partial", stderr=b"timeout context"))
        self.assertEqual(result, 1)
        self.assertEqual(rows[0]["status"], "TIMEOUT")
        self.assertEqual(raw[0]["stdout"], "partial")
        self.assertEqual(raw[0]["stderr"], "timeout context")

    def test_wrong_worker_row_cannot_be_attributed_to_requested_run(self):
        result, rows, _, _ = self.run_case(subprocess.CompletedProcess([], 0, ROW.replace(",1,1,1,0,1,1,", ",4,4,4,0,1,1,"), ""))
        self.assertEqual(result, 1)
        self.assertEqual(rows[0]["status"], "FAIL")
        self.assertIn("workers_requested", rows[0]["error"])

    def test_nan_and_duplicate_rows_are_not_passes(self):
        for output in (ROW.replace("1e-3", "nan"), ROW + ROW):
            with self.subTest(output=output):
                result, rows, _, _ = self.run_case(subprocess.CompletedProcess([], 0, output, ""))
                self.assertEqual(result, 1)
                self.assertEqual(rows[0]["status"], "FAIL")

    def test_source_changed_during_campaign_is_reported(self):
        changed = {**IDENTITY, "source_sha256": "moved"}
        result, rows, _, metadata = self.run_case(subprocess.CompletedProcess([], 0, ROW, ""), changed)
        self.assertEqual(result, 1)
        self.assertEqual(rows[0]["status"], "PASS")
        self.assertTrue(metadata["source_changed_during_run"])


if __name__ == "__main__":
    unittest.main()
