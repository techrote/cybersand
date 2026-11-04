"""Adversarial result/custody tests; no compiler or native simulation is run."""
from __future__ import annotations

import contextlib
import copy
from datetime import datetime
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import run_in_tools_native as runner


def valid_result() -> dict:
    """Synthetic complete registration, deliberately not native evidence."""
    cases = [dict(case_id=name, status="pass", **copy.deepcopy(values))
             for name, values in runner.SINGLETONS.items()]
    for case_id, material, family, width in sorted(runner.EXPECTED_FLOWS):
        initial = 1296 * (255 if material == "Water" else 1)
        removed = 8 * (255 if material == "Water" else 1) if case_id == runner.DRAIN else 0
        cases.append({
            "case_id": case_id, "status": "pass", "material": material, "family": family,
            "width": width, "ticks": 224, "initial_quantity": initial,
            "remaining_quantity": initial - removed, "removed_quantity": removed,
            "first_reservoir_depletion_tick": 1 if removed else 9,
            "close_applied_tick": 0 if removed else 24, "close_refusals": 0,
            "phase_jobs": 128, "workers1_observed": 1, "workers4_observed": 4, "parity": True,
            "inertial_ledger_parity": True, "census_completed_ticks": runner.CENSUS_TICKS.copy(),
            "census_cells": 393216, "census_chunks": 24, "restored_census_completed_tick": 232,
            "inertial_slot_bytes": 2359296 if family == "inertial_cellular_v1" else 0,
            "inertial_slot_size": 6,
            "inertial_total_component_bytes": 2982945 if family == "inertial_cellular_v1" else 623073,
            "resident_cells_bytes": 3151872,
            "instrumented_elapsed_ms_workers1": 1.0, "instrumented_elapsed_ms_workers4": 1.0,
        })
    return {"schema": runner.RESULT_SCHEMA, "scope": "native-core-only",
            "production_tool_implemented": False, "status": "pass", "checks": 8761999,
            "cases": cases, "census_negative_controls": runner.CENSUS_NEGATIVE_CONTROLS.copy()}


def flow(result: dict, case_id: str = runner.LEAK, material: str = "Water",
         family: str = "inertial_cellular_v1") -> dict:
    return next(case for case in result["cases"]
                if case["case_id"] == case_id and case["material"] == material
                and case["family"] == family and case["width"] == 1)


class ResultValidationTests(unittest.TestCase):
    def test_complete_registration_and_honest_claimant_counts(self) -> None:
        result = valid_result()
        runner.validate_native_result(result)
        for count in (2, 3, 4):
            flow(result)["workers4_observed"] = count
            runner.validate_native_result(result)
            self.assertEqual(flow(result)["workers4_observed"], count)

    def test_root_shape_and_discriminators(self) -> None:
        values = [None, [], True, 1, "pass", {},
                  {"schema": runner.RESULT_SCHEMA, "status": "pass"}]
        for key, value in (("schema", "unknown"), ("status", "fail"), ("scope", "gameplay"),
                           ("production_tool_implemented", True), ("production_tool_implemented", 0),
                           ("checks", True), ("checks", 0), ("checks", 8761999.0),
                           ("unexpected", "field")):
            result = valid_result()
            result[key] = value
            values.append(result)
        for value in values:
            with self.subTest(value=value if not isinstance(value, dict) else list(value)):
                with self.assertRaises(ValueError):
                    runner.validate_native_result(value)

    def test_missing_duplicate_unknown_and_failed_children(self) -> None:
        for mode in ("missing", "duplicate-singleton", "duplicate-flow", "unknown", "failed", "null"):
            result = valid_result()
            if mode == "missing":
                result["cases"].pop()
            elif mode == "duplicate-singleton":
                result["cases"][1] = copy.deepcopy(result["cases"][0])
            elif mode == "duplicate-flow":
                result["cases"][-1] = copy.deepcopy(result["cases"][-2])
            elif mode == "unknown":
                result["cases"][0]["case_id"] = "native.unregistered.v1"
            elif mode == "failed":
                result["cases"][0]["status"] = "fail"
            else:
                result["cases"][0] = None
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                runner.validate_native_result(result)

    def test_singleton_facts_are_exact_and_typed(self) -> None:
        for case_id, key, value in (
            ("native.ingress.v1", "water_quanta", [7, True]),
            ("native.ingress.v1", "brine_quantum_cells", True),
            ("native.edit-refusals.v1", "guarded_tool_api_exists", True),
            ("native.nozzle-no-input.v1", "source_initial_velocity", [0, -1]),
            ("native.mask-barrier.v1", "ticks_per_arm", 64.0),
            ("native.mask-barrier.v1", "barrier_kind", "Rapier"),
            ("native.sink-exhaustion.v1", "zero_removal_on_second_call", False),
            ("native.owner-reconstruction.v1", "fresh_setup_pairs_per_arm", 0),
            ("native.owner-reconstruction.v1", "restore_inertial_ledger_parity", False),
            ("native.owner-reconstruction.v1", "restore_inertial_ledger_parity", 1),
            ("native.capacity-quarantine.v1", "extra", True),
        ):
            result = valid_result()
            next(case for case in result["cases"] if case["case_id"] == case_id)[key] = value
            with self.subTest(case=case_id, key=key), self.assertRaises(ValueError):
                runner.validate_native_result(result)

    def test_flow_domain_types_and_participation(self) -> None:
        for key, value in (
            ("family", "pressure_flow_v1"), ("material", "Oil"), ("material", []),
            ("width", 2), ("width", True), ("ticks", 223), ("ticks", 224.0),
            ("phase_jobs", 0), ("phase_jobs", True), ("parity", False), ("parity", 1),
            ("workers1_observed", 2), ("workers1_observed", True),
            ("workers4_observed", 1), ("workers4_observed", 5), ("workers4_observed", True),
            ("inertial_slot_size", 8), ("inertial_slot_bytes", 0),
            ("inertial_slot_bytes", 7), ("inertial_total_component_bytes", 1),
            ("resident_cells_bytes", 0), ("instrumented_elapsed_ms_workers1", True),
            ("instrumented_elapsed_ms_workers1", -1), ("instrumented_elapsed_ms_workers1", 0),
            ("instrumented_elapsed_ms_workers1", float("nan")),
            ("instrumented_elapsed_ms_workers1", float("inf")),
            ("instrumented_elapsed_ms_workers1", 10**1000), ("unknown", 1),
        ):
            result = valid_result()
            flow(result)[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                runner.validate_native_result(result)
        result = valid_result()
        flow(result, family="freemass_v1")["inertial_slot_bytes"] = 6
        with self.assertRaises(ValueError):
            runner.validate_native_result(result)

    def test_quantity_balance_and_whole_in_water(self) -> None:
        for key, value in (("initial_quantity", 255), ("initial_quantity", 330480.0),
                           ("remaining_quantity", -1), ("remaining_quantity", True),
                           ("removed_quantity", 0), ("removed_quantity", 1.5)):
            result = valid_result()
            flow(result, runner.DRAIN)[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                runner.validate_native_result(result)
        result = valid_result()
        candidate = flow(result, runner.DRAIN)
        candidate["remaining_quantity"] -= 1
        candidate["removed_quantity"] += 1
        with self.assertRaises(ValueError):
            runner.validate_native_result(result)
        # Current FreeMass removal can be partial; it is not forced to IN's Q.
        result = valid_result()
        candidate = flow(result, runner.DRAIN, family="freemass_v1")
        candidate["removed_quantity"] = 1
        candidate["remaining_quantity"] = candidate["initial_quantity"] - 1
        runner.validate_native_result(result)

    def test_census_and_diagnostic_ledger_evidence_is_complete(self) -> None:
        for key, value in (("inertial_ledger_parity", False), ("inertial_ledger_parity", 1),
                           ("census_completed_ticks", [0, 8, 24, 32, 64]),
                           ("census_completed_ticks", [0, 8, 24, 32, 64, 64]),
                           ("census_completed_ticks", [False, 8, 24, 32, 64, 224]),
                           ("census_cells", 1024), ("census_chunks", 25),
                           ("restored_census_completed_tick", 224)):
            result = valid_result()
            flow(result)[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                runner.validate_native_result(result)
        for controls in ([], runner.CENSUS_NEGATIVE_CONTROLS[:-1],
                         runner.CENSUS_NEGATIVE_CONTROLS[:-1] + ["missing-wall"]):
            result = valid_result()
            result["census_negative_controls"] = controls
            with self.subTest(controls=controls), self.assertRaises(ValueError):
                runner.validate_native_result(result)

    def test_historical_v1_is_not_new_census_or_ledger_evidence(self) -> None:
        result = valid_result()
        result["schema"] = "in-tools-native-primitives-v1"
        with self.assertRaises(ValueError):
            runner.validate_native_result(result)

    def test_leak_must_reach_a_real_close_within_reopen_horizon(self) -> None:
        for key, value in (("first_reservoir_depletion_tick", 0), ("first_reservoir_depletion_tick", 8),
                           ("first_reservoir_depletion_tick", 225), ("close_applied_tick", 0),
                           ("close_applied_tick", 23), ("close_applied_tick", 200),
                           ("close_refusals", 1)):
            result = valid_result()
            flow(result)[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                runner.validate_native_result(result)
        result = valid_result()
        candidate = flow(result)
        candidate["removed_quantity"] = 255
        candidate["remaining_quantity"] -= 255
        with self.assertRaises(ValueError):
            runner.validate_native_result(result)

    def test_drain_has_no_valve_events_and_empty_intake_is_not_empty_tank(self) -> None:
        for key, value in (("close_applied_tick", 24), ("close_refusals", 1), ("first_reservoir_depletion_tick", 2)):
            result = valid_result()
            flow(result, runner.DRAIN)[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                runner.validate_native_result(result)
        result = valid_result()
        self.assertGreater(flow(result, runner.DRAIN)["remaining_quantity"], 0)
        runner.validate_native_result(result)

    def test_json_syntax_duplicate_keys_and_nonfinite_numbers(self) -> None:
        raw = json.dumps(valid_result())
        invalid = [raw[:-1], "[]", "null", raw + "trailing output",
                   raw[:-1] + ', "schema": "' + runner.RESULT_SCHEMA + '"}',
                   raw.replace('"instrumented_elapsed_ms_workers1": 1.0',
                               '"instrumented_elapsed_ms_workers1": NaN', 1)]
        self.assertEqual(runner.parse_native_result(raw), valid_result())
        for value in invalid:
            with self.subTest(raw=value[:80]), self.assertRaises(ValueError):
                runner.parse_native_result(value)


class RunnerRecordTests(unittest.TestCase):
    def invocation(self, raw: str | None = None, *, compile_exit: int = 0, run_exit: int = 0,
                   mutate: str | None = None, compiler_available: bool = True,
                   raise_on_run: bool = False, existing_unrelated: bool = False,
                   compiler_omits_executable: bool = False) -> tuple:
        with tempfile.TemporaryDirectory(prefix="in361-runner-test-") as temporary:
            root = Path(temporary)/"source"
            for name in [*runner.SOURCES, "native/include/cybersand/probe.hpp", "native/src/probe.inc"]:
                path = root/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(f"synthetic source for {name}\n")
            compiler = Path(temporary)/"compiler"
            compiler.write_text("synthetic compiler, never executed\n")
            build = Path(temporary)/"build"
            build.mkdir()
            output = Path(temporary)/"native.json"
            prior = "unrelated data" if existing_unrelated else json.dumps(
                {"schema": runner.RECORD_SCHEMA, "status": "pass", "stale": True})
            output.write_text(prior)
            (build/"run.stdout.json").write_text("stale output")
            (build/"run.stderr.log").write_text("stale stderr")
            executable = build/("in_tools_361.exe" if runner.os.name == "nt" else "in_tools_361")
            executable.write_text("stale executable")
            raw = json.dumps(valid_result()) if raw is None else raw
            initial_records = []

            def metadata(arguments: list[str], **_kwargs) -> str:
                if arguments[0] == "git":
                    if arguments[1] == "diff":
                        return ""
                    return ("2" if arguments[-1] == "HEAD^{tree}" else "1") * 40
                return "synthetic compiler version\n"

            def execute(arguments: list[str], _timeout: int, stdout: Path, stderr: Path) -> int:
                if "-o" in arguments:
                    initial_records.append(json.loads(output.read_text()))
                    stdout.write_text("")
                    stderr.write_text("")
                    if compile_exit == 0 and not compiler_omits_executable:
                        executable.write_text("new synthetic executable, never executed")
                    return compile_exit
                stdout.write_text(raw)
                stderr.write_text("")
                if raise_on_run:
                    raise OSError("synthetic execution error")
                if mutate == "source":
                    (root/runner.SOURCES[0]).write_text("changed after run")
                elif mutate == "missing-source":
                    (root/runner.SOURCES[0]).unlink()
                elif mutate == "compiler":
                    compiler.write_text("different compiler")
                elif mutate == "executable":
                    executable.write_text("different executable")
                return run_exit

            stdout, stderr = io.StringIO(), io.StringIO()
            with mock.patch.object(runner, "ROOT", root), \
                 mock.patch.object(runner, "command", side_effect=execute), \
                 mock.patch.object(runner.shutil, "which", return_value=str(compiler) if compiler_available else None), \
                 mock.patch.object(runner.subprocess, "check_output", side_effect=metadata), \
                 mock.patch.object(sys, "argv", ["runner", "--build-dir", str(build), "--output", str(output)]), \
                 contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                code = runner.main()
            text = output.read_text()
            record = None if existing_unrelated else json.loads(text)
            return code, record, initial_records, text, stderr.getvalue()

    def test_pass_requires_fresh_complete_result_and_records_utc_custody(self) -> None:
        code, record, initial, _, _ = self.invocation()
        self.assertEqual(code, 0)
        self.assertEqual(record["status"], "pass")
        self.assertNotIn("stale", record)
        self.assertEqual(initial[0]["status"], "not-run")
        self.assertIsNone(initial[0]["finished_at_utc"])
        self.assertEqual(record["results"], valid_result())
        for key in ("inputs_unchanged", "runner_unchanged", "compiler_unchanged", "executable_unchanged"):
            self.assertIs(record[key], True)
        for key in ("started_at_utc", "finished_at_utc"):
            self.assertTrue(record[key].endswith("Z"))
        self.assertLessEqual(datetime.fromisoformat(record["started_at_utc"]),
                             datetime.fromisoformat(record["finished_at_utc"]))

    def test_malformed_results_replace_previous_pass_and_return_nonzero(self) -> None:
        failed = valid_result()
        failed["cases"][0]["status"] = "fail"
        duplicate = valid_result()
        duplicate["cases"][-1] = copy.deepcopy(duplicate["cases"][-2])
        unknown = valid_result()
        unknown["cases"][0]["case_id"] = "unknown"
        for raw in ("[]", "null", "false", "3", '"pass"', '{"schema":',
                    json.dumps({"schema": runner.RESULT_SCHEMA, "status": "pass"}),
                    json.dumps(failed), json.dumps(duplicate), json.dumps(unknown)):
            with self.subTest(raw=raw[:80]):
                code, record, _, _, _ = self.invocation(raw)
                self.assertNotEqual(code, 0)
                self.assertEqual(record["status"], "malformed-result")
                self.assertNotIn("stale", record)
                self.assertNotIn("results", record)
                self.assertIsNotNone(record["finished_at_utc"])
                self.assertIn("stdout_sha256", record)

    def test_compile_failure_does_not_attach_stale_execution_artifacts(self) -> None:
        code, record, _, _, _ = self.invocation(compile_exit=1)
        self.assertEqual(code, 1)
        self.assertEqual(record["status"], "compile-failed")
        self.assertNotIn("stdout_sha256", record)
        self.assertNotIn("executable_sha256", record)
        self.assertNotIn("run.stderr.log", record["log_sha256"])
        self.assertNotIn("results", record)

    def test_successful_compiler_must_create_a_fresh_executable(self) -> None:
        code, record, _, _, _ = self.invocation(compiler_omits_executable=True)
        self.assertEqual(code, 1)
        self.assertEqual(record["status"], "runner-error")
        self.assertNotIn("run_exit", record)
        self.assertNotIn("results", record)

    def test_failure_and_timeout_cannot_be_promoted_by_valid_stdout(self) -> None:
        for exit_code in (1, 124):
            with self.subTest(exit_code=exit_code):
                code, record, _, _, _ = self.invocation(run_exit=exit_code)
                self.assertEqual(code, 1)
                self.assertEqual(record["status"], "run-failed")
                self.assertNotIn("results", record)
                self.assertIsNotNone(record["finished_at_utc"])

    def test_custody_changes_cannot_retain_a_pass(self) -> None:
        for mutation, expected in (("source", "source-changed-during-run"),
                                   ("missing-source", "custody-failed"),
                                   ("compiler", "artifact-changed-during-run"),
                                   ("executable", "artifact-changed-during-run")):
            with self.subTest(mutation=mutation):
                code, record, _, _, _ = self.invocation(mutate=mutation)
                self.assertEqual(code, 1)
                self.assertEqual(record["status"], expected)
                self.assertIsNotNone(record["finished_at_utc"])

    def test_execution_or_discovery_error_retires_old_pass(self) -> None:
        for options in ({"raise_on_run": True}, {"compiler_available": False}):
            with self.subTest(options=options):
                code, record, _, _, _ = self.invocation(**options)
                self.assertEqual(code, 1)
                self.assertEqual(record["status"], "runner-error")
                self.assertNotIn("stale", record)
                self.assertIsNotNone(record["finished_at_utc"])

    def test_unrelated_existing_output_is_preserved(self) -> None:
        code, _, initial, text, error = self.invocation(existing_unrelated=True)
        self.assertEqual(code, 1)
        self.assertEqual(text, "unrelated data")
        self.assertEqual(initial, [])
        self.assertIn("output refused", error)

    def test_timeout_function_retains_partial_logs(self) -> None:
        with tempfile.TemporaryDirectory(prefix="in361-timeout-test-") as temporary:
            out, err = Path(temporary)/"out", Path(temporary)/"err"

            def timeout(_args, **kwargs):
                kwargs["stdout"].write(b"partial output")
                raise subprocess.TimeoutExpired("synthetic", 1)

            with mock.patch.object(runner.subprocess, "run", side_effect=timeout):
                code = runner.command(["never-executed"], 1, out, err)
            self.assertEqual(code, 124)
            self.assertEqual(out.read_text(), "partial output")
            self.assertIn("not a pass", err.read_text())


if __name__ == "__main__":
    unittest.main()
