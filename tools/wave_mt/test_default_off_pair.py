#!/usr/bin/env python3
"""Adversarial controls for paired source custody and conservation evidence."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location("wave_default_pair", Path(__file__).with_name("run_default_off_pair.py"))
pair = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pair)


def valid_row(config: dict) -> dict:
    checkpoint = {"state_hash": "1234567890abcdef", "physical_hash": "fedcba0987654321", "physical_hash_version": 2,
                  "water_quantity": 255, "quantity_ledger": {"water_visible": 255, "water_overfill": 0}}
    return {"schema": "wave-default-off-pair-v1", "size": config["size"], "scene": config["scene"],
            "workers_requested": config["workers"], "workers_configured": config["workers"], "workers_observed": 1,
            "warm_ticks": config["warm"], "measured_ticks": config["ticks"], "water_family": 1, "water_variant": 0,
            "policy_hash": "1234567890abcdef", "conserved": True,
            "visited_cells_total": 10, "moved_cells_total": 3, "scheduled_cores_total": 1,
            "timing": {"tick_ns": [1000] * config["ticks"], "tick_p50_ns": 1000, "tick_p95_ns": 1000,
                       "tick_p99_ns": 1000, "tick_max_ns": 1000, "tick_mean_ns": 1000, "native_ticks_per_s": 1000000},
            "checkpoints": {name: {**copy.deepcopy(checkpoint), "tick": tick, "completed_tick": tick}
                            for name, tick in (("start", 0), ("warm", config["warm"]), ("final", config["warm"] + config["ticks"]))}}


class PairedEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.config = pair.configurations(True)[0]
        self.row = valid_row(self.config)

    def test_complete_campaign_has_48_processes_and_alternates_order(self):
        configurations = pair.configurations(False)
        self.assertEqual(len(configurations) * 2, 48)
        self.assertEqual({(c["size"], c["scene"]) for c in configurations},
                         {(256, "dam"), (1024, "dam"), (2048, "sparse"), (2048, "idle")})
        self.assertEqual({c["workers"] for c in configurations}, {1, 4})
        self.assertEqual([pair.pair_order(i) for i in range(3)],
                         [("baseline", "candidate"), ("candidate", "baseline"), ("baseline", "candidate")])

    def test_identity_and_actual_samples_must_match_request(self):
        pair.validate_row(self.row, self.config)
        for mutation in (lambda row: row.update(workers_configured=4),
                         lambda row: row.update(conserved=False),
                         lambda row: row["timing"]["tick_ns"].pop(),
                         lambda row: row["timing"].update(tick_p95_ns=999),
                         lambda row: row["checkpoints"]["final"].update(water_quantity=254)):
            damaged = copy.deepcopy(self.row)
            mutation(damaged)
            with self.assertRaises(ValueError):
                pair.validate_row(damaged, self.config)

    def test_faster_candidate_cannot_hide_state_or_ledger_change(self):
        candidate = copy.deepcopy(self.row)
        candidate["timing"]["tick_p50_ns"] = 1
        candidate["checkpoints"]["final"]["physical_hash"] = "0000000000000000"
        with self.assertRaisesRegex(ValueError, "physical_hash"):
            pair.compare_pair(self.row, candidate)
        candidate = copy.deepcopy(self.row)
        candidate["checkpoints"]["warm"]["quantity_ledger"]["water_visible"] = 0
        with self.assertRaisesRegex(ValueError, "quantity_ledger"):
            pair.compare_pair(self.row, candidate)

    def test_slower_but_equivalent_candidate_is_reported_without_threshold(self):
        candidate = copy.deepcopy(self.row)
        candidate["timing"]["tick_p50_ns"] = 2000
        records = [{"configuration": self.config, "arm": arm, "status": "PASS", "result": row}
                   for arm, row in (("baseline", self.row), ("candidate", candidate))]
        report = pair.reduce_results(records, 2, [])
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["summary"][0]["median_candidate_over_baseline_p50"], 2)

    def test_failure_missing_rows_and_duplicate_arms_never_pass(self):
        record = {"configuration": self.config, "arm": "baseline", "status": "PASS", "result": self.row}
        for records, planned in (([record], 2), ([record, record], 2),
                                  ([record, {**record, "arm": "candidate", "status": "TIMEOUT"}], 2)):
            with self.subTest(records=records):
                self.assertEqual(pair.reduce_results(records, planned, [])["status"], "failed")

    def test_original_failure_streams_and_nonfinite_json_are_retained(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "process"
            record = pair.command([sys.executable, "-c", "import sys; print('original stdout'); print('original failure',file=sys.stderr); sys.exit(7)"], output, 10)
            self.assertEqual(record["returncode"], 7)
            self.assertEqual(record["status"], "FAIL")
            self.assertIn("original failure", (output / "stderr.txt").read_text())
            self.assertEqual(json.loads((output / "process.json").read_text())["stdout"], "original stdout\n")
        for number in ("NaN", "Infinity", "1e999"):
            with self.subTest(number=number), self.assertRaises(ValueError):
                json.loads('{"timing":' + number + '}', parse_constant=pair.reject_constant, parse_float=pair.finite_float)

    def test_timeout_preserves_partial_output_and_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            record = pair.command([sys.executable, "-c", "import time; print('partial',flush=True); time.sleep(30)"], Path(directory) / "process", 0.1)
            self.assertEqual(record["status"], "TIMEOUT")
            self.assertEqual(record["stdout"], "partial\n")
            self.assertNotEqual(record["returncode"], 0)

    def test_exit_racing_timeout_still_retains_original_streams(self):
        process = Mock(pid=123, returncode=0)
        process.communicate.side_effect = [subprocess.TimeoutExpired(["fixture"], 1), ("partial output", "last diagnostic")]
        with tempfile.TemporaryDirectory() as directory, patch.object(pair.subprocess, "Popen", return_value=process), \
                patch.object(pair.os, "killpg", side_effect=ProcessLookupError):
            record = pair.command(["fixture"], Path(directory) / "process", 1)
            self.assertEqual(record["status"], "TIMEOUT")
            self.assertEqual(record["stdout"], "partial output")
            self.assertEqual(record["stderr"], "last diagnostic")


class SourceBindingTests(unittest.TestCase):
    def test_wrong_commit_and_mutated_native_inputs_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "--quiet", str(root)], check=True)
            for name in pair.SOURCES:
                path = root / "native/src" / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("// committed native source\n")
            header = root / "native/include/cybersand/world.hpp"
            header.parent.mkdir(parents=True)
            header.write_text("// committed header\n")
            subprocess.run(["git", "-C", str(root), "add", "native"], check=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=paired-test", "-c", "user.email=paired-test@example.invalid",
                            "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "test fixture"], check=True)
            sha = pair.git(root, "rev-parse", "HEAD")
            original = pair.source_identity(root, sha)
            self.assertEqual(original["commit"], sha)
            with self.assertRaisesRegex(ValueError, "HEAD"):
                pair.source_identity(root, "0" * 40)
            header.write_text("// uncommitted replacement\n")
            with self.assertRaisesRegex(ValueError, "changes"):
                pair.source_identity(root, sha)
            header.write_text("// committed header\n")
            (header.parent / "untracked.hpp").write_text("// unexpected include\n")
            with self.assertRaisesRegex(ValueError, "changes"):
                pair.source_identity(root, sha)


if __name__ == "__main__":
    unittest.main()
