#!/usr/bin/env python3
"""Synthetic campaign accounting and process isolation, without running Godot."""

from contextlib import ExitStack, redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aggregate_physical_stress as reducer
import stress_physical_godot as stress

IDENTITY = {"expected_source_sha": "a" * 40, "expected_run_id": "42", "expected_run_attempt": "1"}


class CampaignAccountingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.files = []
        for host in ("linux", "win32"):
            for mode in ("serial", "parallel"):
                path = self.root / f"{host}-{mode}" / "stress-summary.json"
                path.parent.mkdir()
                path.write_text(json.dumps({
                    "source_sha": "a" * 40, "run_id": "42", "run_attempt": "1",
                    "godot_version": "4.7.fixture", "native_sha256": "b" * 64,
                    "rapier_sha256": "c" * 64, "platform": host, "mode": mode,
                    "batch": 0, "repetitions": 1, "cases": list(stress.CASES),
                    "completed": True, "status": "passed", "results": [
                        {"name": "import", "role": "preflight", "seconds": 1, "status": "passed"},
                        *[{"name": name, "role": "case", "repetition": 1,
                           "seconds": 5, "status": "passed", "timeout_seconds": 180}
                          for name in stress.CASES],
                    ],
                }), encoding="utf-8")
                self.files.append(path)

    def change(self, mutate):
        payload = json.loads(self.files[0].read_text(encoding="utf-8"))
        mutate(payload)
        self.files[0].write_text(json.dumps(payload), encoding="utf-8")

    def reduce(self, **kwargs):
        return reducer.aggregate(self.files, batches=1, per_batch=1, **(IDENTITY | kwargs))

    def test_complete_registered_600_attempt_campaign(self):
        files = []
        for path in self.files:
            original = json.loads(path.read_text(encoding="utf-8"))
            for batch in range(5):
                payload = original | {"batch": batch, "repetitions": 10}
                payload["results"] = [original["results"][0], *[
                    row | {"repetition": batch * 10 + local}
                    for local in range(1, 11) for row in original["results"][1:]
                ]]
                destination = path.parent / str(batch) / "stress-summary.json"
                destination.parent.mkdir()
                destination.write_text(json.dumps(payload), encoding="utf-8")
                files.append(destination)
        rows, errors = reducer.aggregate(files, batches=5, per_batch=10, **IDENTITY)
        self.assertFalse(errors, errors)
        self.assertEqual(len(rows), 600)
        distributions = reducer.distributions(rows)
        self.assertEqual(len(distributions), 12)
        self.assertTrue(all(row["samples"] == row["passed"] == 50 for row in distributions))
        self.assertTrue(all(row["timeouts"] == row["other_failures"] == 0 for row in distributions))

    def test_one_timeout_remains_a_failure_and_is_retained(self):
        def timeout(payload):
            payload["status"] = "failed"
            payload["results"][1].update(status="timeout", seconds=180,
                last_progress="REGRESSION_PROGRESS phase=roster_step rig=runner tick=60")
        self.change(timeout)
        rows, errors = self.reduce()
        self.assertEqual(len(rows), 12)
        self.assertTrue(any("timeout" in error for error in errors))
        self.assertIn("rig=runner", rows[0]["last_progress"])

    def test_campaigns_and_attempts_cannot_be_cherry_picked(self):
        for field, replacement in (("run_id", "43"), ("run_attempt", "2"), ("source_sha", "d" * 40)):
            with self.subTest(field=field):
                _, errors = self.reduce(**{"expected_" + field: replacement})
                self.assertTrue(any(field in error and "registered" in error for error in errors))

    def test_missing_runtime_identities_do_not_count_as_consistent(self):
        self.change(lambda payload: [payload.pop(field) for field in
                    ("native_sha256", "rapier_sha256", "godot_version")])
        _, errors = self.reduce()
        self.assertTrue(any("invalid native_sha256" in error for error in errors))
        self.assertTrue(any("missing Godot identity" in error for error in errors))

    def test_serial_parallel_runtime_mismatch_fails(self):
        self.change(lambda payload: payload.update(native_sha256="d" * 64))
        _, errors = self.reduce()
        self.assertTrue(any("across all modes" in error for error in errors))

    def test_missing_and_failed_preflights_fail(self):
        self.change(lambda payload: payload["results"].pop(0))
        _, errors = self.reduce()
        self.assertTrue(any("exactly one import preflight" in error for error in errors))
        self.change(lambda payload: payload["results"].append(
            {"name": "import", "role": "preflight", "status": "timeout", "seconds": 240}))
        _, errors = self.reduce()
        self.assertTrue(any("import repeat None: timeout" in error for error in errors))

    def test_duplicate_attempt_is_visible(self):
        self.change(lambda payload: payload["results"].append(payload["results"][1]))
        rows, errors = self.reduce()
        self.assertEqual(len(rows), 13)
        self.assertTrue(any("duplicate case repetitions" in error for error in errors))

    def test_invalid_timing_is_ambiguous_not_a_zero_second_success(self):
        self.change(lambda payload: payload["results"][1].pop("seconds"))
        rows, errors = self.reduce()
        self.assertIsNone(rows[0]["seconds"])
        self.assertTrue(any("invalid elapsed seconds" in error for error in errors))
        distribution = next(row for row in reducer.distributions(rows)
                            if row["platform"] == "linux" and row["mode"] == "stress-serial"
                            and row["test"] == stress.CASES[0])
        self.assertEqual(distribution["samples"], 1)
        self.assertEqual(distribution["timed_samples"], 0)
        self.assertIsNone(distribution["median_s"])

    def test_skip_unknown_status_and_timeout_increase_fail(self):
        self.change(lambda payload: payload["results"][1].update(status="skipped", timeout_seconds=241))
        _, errors = self.reduce()
        self.assertTrue(any("skipped" in error for error in errors))
        self.assertTrue(any("unregistered per-test timeout" in error for error in errors))

    def test_malformed_summary_still_writes_independent_audit(self):
        self.files[0].write_text("{broken", encoding="utf-8")
        output = self.root / "audit"
        argv = ["reducer", "--input", str(self.root), "--output", str(output),
                "--batches", "1", "--per-batch", "1", "--expected-source-sha", "a" * 40,
                "--expected-run-id", "42", "--expected-run-attempt", "1"]
        with mock.patch.object(sys, "argv", argv), redirect_stdout(io.StringIO()):
            self.assertEqual(reducer.main(), 1)
        audit = json.loads((output / "stress-audit.json").read_text(encoding="utf-8"))
        self.assertEqual(audit["status"], "failed")
        self.assertEqual(audit["observed_case_attempts"], 9)
        self.assertTrue(any("unreadable stress summary" in error for error in audit["errors"]))


class StressExecutionTests(unittest.TestCase):
    def test_process_and_user_writable_paths_are_isolated(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(stress.sys, "platform", "win32"):
            left = stress.case_environment(Path(tmp) / "left")
            right = stress.case_environment(Path(tmp) / "right")
            for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
                        "APPDATA", "LOCALAPPDATA", "TMPDIR", "TEMP", "TMP"):
                self.assertNotEqual(left[key], right[key])
                self.assertTrue(Path(left[key]).is_dir())

    def test_serial_parallel_cover_same_cases_and_continue_after_timeout(self):
        for mode in ("serial", "parallel"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as tmp, ExitStack() as stack:
                output = Path(tmp) / "output"
                native = Path(tmp) / "native"
                native.write_bytes(b"fixture")
                invocations = []

                def run_case(_godot, case, _output, role, **_kwargs):
                    invocations.append((case.name, role))
                    status = "timeout" if case.name == stress.CASES[0] else "passed"
                    return {"name": case.name, "role": role, "status": status,
                            "seconds": 180 if status == "timeout" else 1,
                            "timeout_seconds": case.timeout}, status == "timeout"

                argv = ["stress", "--godot", "fixture", "--expected-source-sha", "a" * 40,
                        "--output", str(output), "--mode", mode, "--repetitions", "2"]
                stack.enter_context(mock.patch.object(sys, "argv", argv))
                stack.enter_context(mock.patch.object(stress.subprocess, "check_output",
                    side_effect=lambda command, **_: "a" * 40 if command[0] == "git" else "4.7.fixture"))
                stack.enter_context(mock.patch.object(stress.runner, "runtime_paths", return_value=(native, native)))
                stack.enter_context(mock.patch.object(stress.runner, "run_case", side_effect=run_case))
                stack.enter_context(redirect_stdout(io.StringIO()))
                self.assertEqual(stress.main(), 1)
                report = json.loads((output / "stress-summary.json").read_text(encoding="utf-8"))
                self.assertTrue(report["completed"])
                self.assertEqual(report["status"], "failed")
                self.assertEqual(len(invocations), 7)  # One preflight plus six, with no retry.
                for name in stress.CASES:
                    self.assertEqual(invocations.count((name, "case")), 2)
                self.assertEqual(len(list(output.rglob("attempt-result.json"))), 6)
                # An attempted rerun cannot overwrite any retained failure.
                with self.assertRaisesRegex(RuntimeError, "preserve prior campaign"):
                    stress.main()


if __name__ == "__main__":
    unittest.main()
