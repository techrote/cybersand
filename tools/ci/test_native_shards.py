#!/usr/bin/env python3
"""Adverse controls for the required Native evidence gate; no native execution."""
from __future__ import annotations

from contextlib import redirect_stdout
import copy
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock

import verify_native_shards as gate


class NativeEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.evidence = self.root / "evidence"
        self.evidence.mkdir()
        self.source = "a" * 40
        self.identity = {
            "source_sha": self.source, "source_tree": "b" * 40,
            "source_fingerprints": {key: gate.digest(path.encode()) for key, path in gate.INPUTS.items()},
            "source_delta_paths": [], "expected_cases": ["case A", "case B"],
        }
        self.receipts = {}
        for suite in gate.SUITES:
            folder = self.evidence / ("artifact-" + suite) / "native-parallel" / suite
            folder.mkdir(parents=True)
            text = ""
            if suite in gate.CASE_SUITES:
                text = "[pass] case A\n[pass] case B\n2 tests passed\n"
            text += "Native family passed: " + suite + "\n"
            raw = text.encode()
            (folder / "run.log").write_bytes(raw)
            for name in gate.EXIT_FILES.values():
                (folder / name).write_bytes(b"0\n")
            commands = [("family", "native-family-" + suite, "native_suite_seconds", [
                "bash", "tools/ci/run_native_family.sh", suite, "build/native-parallel/" + suite])]
            commands += [("commands/" + label, suite + "-" + label, key, command)
                         for label, key, command in gate.COMMANDS[suite]]
            for directory, label, key, command in commands:
                destination = folder / directory
                destination.mkdir(parents=True)
                log = b"original command output\n"
                (destination / "command.log").write_bytes(log)
                command_receipt = {
                    "schema": "execution-command-v1", "label": label, "command": command,
                    "execution_policy": gate.execution_policy_identity(),
                    "timeout_seconds": gate.family_timeout_seconds(suite) if directory == "family" else gate.command_timeout_seconds(suite, directory.split("/")[1]),
                    "status": "passed",
                    "returncode": 0, "timed_out": False, "natural_completion": True,
                    "complete": True, "elapsed_seconds": 1.0, "log_sha256": gate.digest(log),
                }
                (destination / "receipt.json").write_text(json.dumps(command_receipt))
            outputs = {}
            if suite == "worldgen":
                outputs = {
                    "physics-cli-validation/validation.log": b"original validation output\n",
                    "physics-cli-validation/sanitized/control.jsonl": b'{}\n',
                    "physics-cli-validation/sanitized/control.stderr.log": b"",
                }
                report = {"invocations": [{"name": "control", "stdout_sha256": gate.digest(b'{}\n'),
                                           "stderr_sha256": gate.digest(b"")}]}
                outputs["physics-cli-validation/sanitized/results.json"] = json.dumps(report).encode()
            elif suite == "soliding-normal":
                outputs = {name: b'{}\n' for name in gate.STAGE_OUTPUTS}
            for name, data in outputs.items():
                file = folder.parent.parent / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(data)
            receipt = {
                "schema": gate.SCHEMA, "suite": suite, "source_sha": self.source,
                "source_tree": self.identity["source_tree"], "event_sha": self.source,
                "run_id": 1234, "run_attempt": 1, "job_outcome": "success", "runner_os": "Linux",
                "source_fingerprints": copy.deepcopy(self.identity["source_fingerprints"]),
                "source_delta_paths": [], "log_present": True, "log_bytes": len(raw),
                "log_sha256": gate.digest(raw), "errors": [],
                "exit_codes": {key: 0 for key in gate.EXIT_FILES},
                "exit_code_sha256": {key: gate.digest(b"0\n") for key in gate.EXIT_FILES},
                "scientific_outputs": {name: {"bytes": len(data), "sha256": gate.digest(data)}
                                       for name, data in outputs.items()},
                "command_outputs": gate.command_inventory(folder),
            }
            path = folder / "receipt.json"
            path.write_text(json.dumps(receipt))
            self.receipts[suite] = path

    def verify(self, **overrides):
        args = {
            "directory": self.evidence, "identity": self.identity, "expected_source": self.source,
            "run_id": 1234, "run_attempt": 1, "policy_result": "success", "matrix_result": "success",
        }
        args.update(overrides)
        return gate.verify_evidence(**args)

    def alter(self, **values):
        path = self.receipts["tsan"]
        receipt = json.loads(path.read_text())
        receipt.update(values)
        path.write_text(json.dumps(receipt))

    def replace_log(self, text):
        raw = text.encode()
        (self.receipts["tsan"].parent / "run.log").write_bytes(raw)
        self.alter(log_bytes=len(raw), log_sha256=gate.digest(raw))

    def alter_command(self, directory="commands/tests-tsan", **values):
        folder = self.receipts["tsan"].parent
        path = folder / directory / "receipt.json"
        record = json.loads(path.read_text())
        record.update(values)
        path.write_text(json.dumps(record))
        self.alter(command_outputs=gate.command_inventory(folder))

    def assert_failed(self, report, fragment=None):
        self.assertEqual(report["status"], "failed")
        self.assertTrue(report["errors"])
        if fragment is not None:
            self.assertIn(fragment, "\n".join(report["errors"]))

    def test_complete_distinct_families_and_source_cases_pass(self):
        report = self.verify()
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["errors"], [])
        self.assertEqual(set(report["received_suites"]), gate.SUITES)
        self.assertEqual(len(report["original_evidence"]), 6)
        self.assertEqual(report["expected_native_case_count"], 2)

    def test_missing_family_cannot_be_hidden_by_matrix_success(self):
        self.receipts["tsan"].unlink()
        self.assert_failed(self.verify(), "Missing Native families: tsan")

    def test_duplicate_family_is_rejected(self):
        shutil.copytree(self.receipts["tsan"].parent, self.evidence / "duplicate" / "tsan")
        self.assert_failed(self.verify(), "Duplicate Native family")

    def test_unknown_family_is_rejected(self):
        self.alter(suite="invented")
        self.assert_failed(self.verify(), "Unexpected Native family")

    def test_wrong_source_event_or_tree_is_rejected(self):
        for field in ("source_sha", "event_sha", "source_tree"):
            with self.subTest(field=field):
                original = self.receipts["tsan"].read_bytes()
                self.alter(**{field: "c" * 40})
                self.assert_failed(self.verify(), "mismatch")
                self.receipts["tsan"].write_bytes(original)

    def test_stale_or_boolean_run_identity_is_rejected(self):
        for field, value in (("run_id", 1235), ("run_attempt", 2), ("run_id", True), ("run_attempt", True)):
            with self.subTest(field=field, value=value):
                original = self.receipts["tsan"].read_bytes()
                self.alter(**{field: value})
                self.assert_failed(self.verify(), "run/attempt mismatch")
                self.receipts["tsan"].write_bytes(original)

    def test_experimental_candidate_schema_cannot_qualify_production(self):
        self.alter(schema="cybersand-native-parallel-candidate-v1")
        self.assert_failed(self.verify(), "Unknown Native receipt schema")

    def test_each_source_fingerprint_is_required_and_exact(self):
        for key in gate.INPUTS:
            with self.subTest(key=key):
                original = self.receipts["tsan"].read_bytes()
                changed = dict(self.identity["source_fingerprints"])
                changed[key] = "0" * 64
                self.alter(source_fingerprints=changed)
                self.assert_failed(self.verify(), "fingerprints differ")
                self.receipts["tsan"].write_bytes(original)

    def test_source_changes_or_retained_custody_errors_remain_red(self):
        for values in ({"source_delta_paths": ["native/src/world.cpp"]},
                       {"errors": ["source read failed"]}, {"source_delta_paths": None}):
            with self.subTest(values=values):
                original = self.receipts["tsan"].read_bytes()
                self.alter(**values)
                self.assert_failed(self.verify(), "source/custody errors")
                self.receipts["tsan"].write_bytes(original)

    def test_failed_skipped_or_cancelled_execution_cannot_qualify(self):
        for outcome in ("failure", "skipped", "cancelled", ""):
            with self.subTest(outcome=outcome):
                self.alter(job_outcome=outcome)
                self.assert_failed(self.verify(), "did not succeed")

    def test_failed_skipped_or_cancelled_matrix_and_policy_remain_red(self):
        for field in ("matrix_result", "policy_result"):
            for outcome in ("failure", "skipped", "cancelled", ""):
                with self.subTest(field=field, outcome=outcome):
                    self.assert_failed(self.verify(**{field: outcome}))

    def test_missing_log_is_rejected(self):
        (self.receipts["tsan"].parent / "run.log").unlink()
        self.assert_failed(self.verify(), "log is absent")

    def test_changed_original_log_is_rejected(self):
        (self.receipts["tsan"].parent / "run.log").write_text("new text\n")
        self.assert_failed(self.verify(), "bytes/hash differ")

    def test_exit_codes_are_original_numeric_zero_and_hash_bound(self):
        folder = self.receipts["tsan"].parent
        for key, name in gate.EXIT_FILES.items():
            path = folder / name
            for bad in (b"124\n", b"1\n", b"0", b"00\n", b"256\n", b"false\n"):
                with self.subTest(key=key, bad=bad):
                    path.write_bytes(bad)
                    self.assert_failed(self.verify())
                    path.write_bytes(b"0\n")
            path.unlink()
            self.assert_failed(self.verify(), "exit-code file is absent")
            path.write_bytes(b"0\n")
        self.alter(exit_codes={"family": False, "log_capture": 0})
        self.assert_failed(self.verify(), "exit code differs or is nonzero")

    def test_recorded_nonzero_exit_stays_red_even_with_success_labels(self):
        path = self.receipts["tsan"].parent / gate.EXIT_FILES["family"]
        path.write_bytes(b"124\n")
        self.alter(exit_codes={"family": 124, "log_capture": 0},
                   exit_code_sha256={"family": gate.digest(b"124\n"), "log_capture": gate.digest(b"0\n")})
        self.assert_failed(self.verify(), "exit code differs or is nonzero")

    def test_interrupted_failed_or_timed_out_command_cannot_qualify(self):
        path = self.receipts["tsan"].parent / "commands/tests-tsan/receipt.json"
        original = path.read_bytes()
        for values in ({"complete": False}, {"status": "failed"}, {"status": "timeout"},
                       {"returncode": 19}, {"returncode": False}, {"timed_out": True},
                       {"natural_completion": False}):
            with self.subTest(values=values):
                path.write_bytes(original)
                self.alter_command(**values)
                self.assert_failed(self.verify(), "did not complete naturally and successfully")

    def test_resealed_missing_or_extra_command_cannot_reduce_inventory(self):
        folder = self.receipts["tsan"].parent
        removed = folder / "commands/build-tests-tsan"
        shutil.rmtree(removed)
        self.alter(command_outputs=gate.command_inventory(folder))
        self.assert_failed(self.verify(), "command receipt inventory differs")
        shutil.copytree(folder / "commands/tests-tsan", folder / "commands/unregistered")
        self.alter(command_outputs=gate.command_inventory(folder))
        self.assert_failed(self.verify(), "command receipt inventory differs")

    def test_resealed_command_arguments_cannot_drop_sanitizer_controls(self):
        self.alter_command(command=["./build/tests_tsan"])
        self.assert_failed(self.verify(), "identity or ordered arguments differ")

    def test_resealed_policy_substitution_or_short_timeout_is_rejected(self):
        policy = gate.execution_policy_identity()
        self.alter_command(execution_policy=policy | {"sha256": "0" * 64})
        self.assert_failed(self.verify(), "execution policy differs")
        self.alter_command(execution_policy=policy, timeout_seconds=10)
        self.assert_failed(self.verify(), "execution policy differs")

    def test_raw_command_log_and_telemetry_bytes_are_retained(self):
        folder = self.receipts["tsan"].parent
        log = folder / "commands/tests-tsan/command.log"
        log.write_bytes(b"changed original output\n")
        self.assert_failed(self.verify(), "execution output inventory/bytes differ")
        self.alter(command_outputs=gate.command_inventory(folder))
        self.assert_failed(self.verify(), "command log hash differs")

    def test_incomplete_family_wrapper_cannot_be_hidden_by_all_passed_children(self):
        self.alter_command(directory="family", complete=False)
        self.assert_failed(self.verify(), "did not complete naturally and successfully")

    def test_missing_or_corrupted_retained_scientific_outputs_remain_red(self):
        for suite in ("worldgen", "soliding-normal"):
            receipt = json.loads(self.receipts[suite].read_text())
            for name in receipt["scientific_outputs"]:
                path = self.receipts[suite].parents[2] / name
                original = path.read_bytes()
                with self.subTest(suite=suite, name=name, defect="missing"):
                    path.unlink()
                    self.assert_failed(self.verify())
                with self.subTest(suite=suite, name=name, defect="corrupt"):
                    path.write_bytes(original + b"corrupted\n")
                    self.assert_failed(self.verify())
                path.write_bytes(original)

    def test_physics_output_cannot_be_removed_from_file_and_receipt(self):
        path = self.receipts["worldgen"]
        receipt = json.loads(path.read_text())
        name = "physics-cli-validation/sanitized/control.stderr.log"
        del receipt["scientific_outputs"][name]
        (path.parents[2] / name).unlink()
        path.write_text(json.dumps(receipt))
        self.assert_failed(self.verify(), "invocation output is absent or differs")

    def test_required_stage_outputs_cannot_be_removed_from_file_and_receipt(self):
        path = self.receipts["soliding-normal"]
        receipt = json.loads(path.read_text())
        name = next(iter(gate.STAGE_OUTPUTS))
        del receipt["scientific_outputs"][name]
        (path.parents[2] / name).unlink()
        path.write_text(json.dumps(receipt))
        self.assert_failed(self.verify(), "Required Stage3B scientific outputs")

    def test_scientific_inventory_has_exact_paths_sizes_and_hashes(self):
        path = self.receipts["worldgen"]
        original = path.read_bytes()
        name = "physics-cli-validation/sanitized/control.stderr.log"
        for value in ({"bytes": True, "sha256": gate.digest(b"")},
                      {"bytes": 1, "sha256": gate.digest(b"")},
                      {"bytes": 0, "sha256": "0" * 64}):
            with self.subTest(value=value):
                receipt = json.loads(original)
                receipt["scientific_outputs"][name] = value
                path.write_text(json.dumps(receipt))
                self.assert_failed(self.verify())
        path.write_bytes(original)
        extra = path.parents[2] / "physics-cli-validation/unexpected.jsonl"
        extra.write_bytes(b"unexpected\n")
        self.assert_failed(self.verify(), "inventory/bytes differ")

    def test_physics_report_cannot_name_duplicate_or_escaping_outputs(self):
        receipt_path = self.receipts["worldgen"]
        path = receipt_path.parents[2] / "physics-cli-validation/sanitized/results.json"
        original = json.loads(path.read_text())
        for rows in ([original["invocations"][0]] * 2,
                     [original["invocations"][0] | {"name": "../escaped"}], []):
            with self.subTest(rows=rows):
                data = json.dumps({"invocations": rows}).encode()
                path.write_bytes(data)
                receipt = json.loads(receipt_path.read_text())
                receipt["scientific_outputs"]["physics-cli-validation/sanitized/results.json"] = {
                    "bytes": len(data), "sha256": gate.digest(data)}
                receipt_path.write_text(json.dumps(receipt))
                self.assert_failed(self.verify())

    def test_log_byte_identity_requires_recorded_integer_and_presence(self):
        for values in ({"log_bytes": True}, {"log_present": False}, {"log_present": 1},
                       {"log_sha256": "0" * 64}):
            with self.subTest(values=values):
                original = self.receipts["tsan"].read_bytes()
                self.alter(**values)
                self.assert_failed(self.verify())
                self.receipts["tsan"].write_bytes(original)

    def test_complete_case_list_without_real_family_completion_is_rejected(self):
        self.replace_log("[pass] case A\n[pass] case B\n2 tests passed\n")
        self.assert_failed(self.verify(), "completion is absent")

    def test_filtered_duplicated_reordered_or_extra_cases_are_rejected(self):
        for cases in (["case A"], ["case A", "case A"], ["case B", "case A"],
                      ["case A", "case B", "unexpected"]):
            with self.subTest(cases=cases):
                self.replace_log("".join("[pass] " + name + "\n" for name in cases)
                                 + "2 tests passed\nNative family passed: tsan\n")
                self.assert_failed(self.verify(), "coverage/order differs")

    def test_missing_wrong_or_repeated_test_summary_is_rejected(self):
        for summary in ("", "1 tests passed\n", "2 tests passed\n2 tests passed\n"):
            with self.subTest(summary=summary):
                self.replace_log("[pass] case A\n[pass] case B\n" + summary + "Native family passed: tsan\n")
                self.assert_failed(self.verify(), "summary is missing or inconsistent")

    def test_sanitizer_failure_cannot_be_hidden_by_later_success_marker(self):
        for failure in ("[fail] hidden", "ERROR: AddressSanitizer", "WARNING: ThreadSanitizer",
                        "runtime error: signed overflow"):
            with self.subTest(failure=failure):
                self.replace_log(failure + "\n[pass] case A\n[pass] case B\n2 tests passed\nNative family passed: tsan\n")
                self.assert_failed(self.verify(), "sanitizer/test failure")

    def test_duplicate_json_keys_and_nonfinite_json_are_rejected(self):
        path = self.receipts["tsan"]
        original = path.read_text()
        for prefix in ('{"job_outcome":"failure",', '{"untrusted":NaN,'):
            with self.subTest(prefix=prefix):
                path.write_text(prefix + original[1:])
                self.assert_failed(self.verify())
        path.write_text(original)

    def test_malformed_receipt_is_a_failed_report(self):
        self.receipts["tsan"].write_text('{"incomplete":')
        self.assert_failed(self.verify(), "JSONDecodeError")

    def test_wrong_runner_and_wrong_receipt_location_are_rejected(self):
        self.alter(runner_os="Windows")
        self.assert_failed(self.verify(), "runner differs")
        self.alter(runner_os="Linux")
        self.receipts["tsan"].parent.rename(self.receipts["tsan"].parent.with_name("wrong"))
        self.assert_failed(self.verify(), "path does not identify its family")

    @unittest.skipIf(os.name == "nt", "Native gate runs on Linux; symlink creation is restricted on Windows")
    def test_symlinked_log_is_rejected(self):
        log = self.receipts["tsan"].parent / "run.log"
        retained = self.root / "outside.log"
        retained.write_bytes(log.read_bytes())
        log.unlink()
        log.symlink_to(retained)
        self.assert_failed(self.verify(), "symlinks")

    def test_absent_directory_and_incomplete_verifier_identity_remain_red(self):
        self.assert_failed(self.verify(directory=self.root / "missing"), "directory is absent")
        for changes in ({"source_sha": "c" * 40}, {"source_tree": ""},
                        {"source_fingerprints": {}}, {"source_delta_paths": ["Makefile"]},
                        {"expected_cases": []}):
            with self.subTest(changes=changes):
                self.assert_failed(self.verify(identity=self.identity | changes))

    def test_original_failed_outcome_is_retained_before_aggregate(self):
        output = self.root / "recorded"
        folder = output / "tsan"
        folder.mkdir(parents=True)
        (folder / "run.log").write_bytes(b"Original timeout after15m\n")
        (folder / gate.EXIT_FILES["family"]).write_bytes(b"124\n")
        (folder / gate.EXIT_FILES["log_capture"]).write_bytes(b"0\n")
        with mock.patch.object(gate, "source_identity", return_value=self.identity), \
             mock.patch.dict(os.environ, {"RUNNER_OS": "Linux"}):
            result = gate.record_shard(self.root, output, "tsan", "failure", self.source, 1234, 1)
        self.assertEqual(result["job_outcome"], "failure")
        self.assertTrue(result["errors"])
        self.assertEqual(result["log_sha256"], gate.digest(b"Original timeout after15m\n"))
        self.assertEqual(result["exit_codes"], {"family": 124, "log_capture": 0})
        self.assertEqual(json.loads((folder / "receipt.json").read_text()), result)

    def test_source_readback_exception_does_not_erase_failure_receipt(self):
        output = self.root / "recorded"
        with mock.patch.object(gate, "source_identity", side_effect=RuntimeError("source unavailable")), \
             mock.patch.dict(os.environ, {"RUNNER_OS": "Linux"}):
            result = gate.record_shard(self.root, output, "tsan", "failure", self.source, 1234, 1)
        self.assertTrue((output / "tsan/receipt.json").is_file())
        self.assertIsNone(result["source_sha"])
        self.assertIn("source: RuntimeError: source unavailable", result["errors"])
        self.assertFalse(result["log_present"])

    def test_source_failure_still_hashes_original_log_and_retains_numeric_exits(self):
        output = self.root / "recorded"
        folder = output / "tsan"
        folder.mkdir(parents=True)
        (folder / "run.log").write_bytes(b"original failure output\n")
        (folder / gate.EXIT_FILES["family"]).write_bytes(b"124\n")
        (folder / gate.EXIT_FILES["log_capture"]).write_bytes(b"0\n")
        with mock.patch.object(gate, "source_identity", side_effect=RuntimeError("dirty source")), \
             mock.patch.dict(os.environ, {"RUNNER_OS": "Linux"}):
            result = gate.record_shard(self.root, output, "tsan", "failure", self.source, 1234, 1)
        self.assertEqual(result["log_sha256"], gate.digest(b"original failure output\n"))
        self.assertEqual(result["exit_codes"], {"family": 124, "log_capture": 0})
        self.assertTrue(result["errors"])

    def test_aggregate_cli_retains_red_report_on_source_readback_exception(self):
        output = self.root / "aggregate.json"
        args = ["verify_native_shards.py", "verify", "--source-sha", self.source,
                "--run-id", "1234", "--run-attempt", "1", "--directory", str(self.evidence),
                "--policy-result", "success", "--matrix-result", "success", "--output", str(output)]
        with mock.patch("sys.argv", args), \
             mock.patch.object(gate, "source_identity", side_effect=RuntimeError("source unavailable")), \
             redirect_stdout(io.StringIO()):
            result = gate.main()
        self.assertEqual(result, 1)
        report = json.loads(output.read_text())
        self.assert_failed(report, "Verifier source readback: RuntimeError: source unavailable")

    def source_workspace(self):
        root = self.root / "source"
        for path in gate.INPUTS.values():
            file = root / path
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("source fixture\n")
        (root / gate.INPUTS["test_registry"]).write_text(
            'int main() {\n const TestCase tests[] = {\n'
            ' {"case A", test_a}, {"case B", test_b}\n };\n}\n')
        return root

    def test_source_case_inventory_is_derived_from_the_actual_registry(self):
        root = self.source_workspace()
        with mock.patch.object(gate, "git", side_effect=[self.source, "b" * 40, "", ""]):
            identity = gate.source_identity(root)
        self.assertEqual(identity["expected_cases"], ["case A", "case B"])
        self.assertEqual(identity["source_delta_paths"], [])
        self.assertEqual(set(identity["source_fingerprints"]), set(gate.INPUTS))

    def test_source_readback_queries_share_one_operation_clock(self):
        root = self.source_workspace()
        clock = [0.0]

        def slow_read(*args, **kwargs):
            self.assertLessEqual(kwargs["timeout_seconds"], gate.watchdog_seconds("operation_seconds"))
            clock[0] += gate.watchdog_seconds("operation_seconds") + 1
            return self.source

        with mock.patch.object(gate.time, "monotonic", side_effect=lambda: clock[0]), \
                mock.patch.object(gate, "git", side_effect=slow_read) as read:
            with self.assertRaisesRegex(ValueError, "readback exceeded"):
                gate.source_identity(root)
        self.assertEqual(read.call_count, 1)

    def test_tracked_or_untracked_execution_input_drift_is_rejected(self):
        root = self.source_workspace()
        for tracked, untracked in (("native/src/world.cpp", ""), ("", "native/src/extra.cpp"),
                                   ("tools/experiments/stage3b_validation.py", ""),
                                   ("", "tools/experiments/shadow_import.py"),
                                   ("", "new/transitive/helper.py")):
            with self.subTest(tracked=tracked, untracked=untracked), \
                 mock.patch.object(gate, "git", side_effect=[self.source, "b" * 40, tracked, untracked]):
                with self.assertRaisesRegex(ValueError, "Native execution inputs changed"):
                    gate.source_identity(root)

    def test_real_git_fence_includes_stage3b_and_future_transitive_inputs(self):
        root = self.source_workspace()
        helper = root / "tools/experiments/stage3b_validation.py"
        helper.parent.mkdir(parents=True)
        helper.write_text("# original scientific helper\n")
        (root / ".gitignore").write_text("/build/\n__pycache__/\n")
        subprocess.run(["git", "init", "-q", str(root)], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(root), "add", "."], check=True, capture_output=True)
        subprocess.run(["git", "-C", str(root), "-c", "user.name=Native test", "-c",
                        "user.email=native-test@example.invalid", "commit", "-qm", "fixture"],
                       check=True, capture_output=True)
        original = gate.source_identity(root)
        (root / "build").mkdir()
        (root / "build/generated.json").write_text("{}\n")
        self.assertEqual(gate.source_identity(root), original)
        helper.write_text("# changed scientific helper\n")
        with self.assertRaisesRegex(ValueError, "tools/experiments/stage3b_validation.py"):
            gate.source_identity(root)
        helper.write_text("# original scientific helper\n")
        for relative in ("tools/experiments/shadow_import.py", "new/transitive/helper.py"):
            extra = root / relative
            extra.parent.mkdir(parents=True, exist_ok=True)
            extra.write_text("# untracked execution input\n")
            with self.subTest(path=relative), self.assertRaisesRegex(ValueError, relative):
                gate.source_identity(root)
            extra.unlink()
        self.assertEqual(gate.source_identity(root), original)

    def test_unparseable_or_duplicate_source_registry_cannot_reduce_coverage(self):
        root = self.source_workspace()
        for registry in ('int main() {}', 'int main() { {"same", test_a}, {"same", test_b} }'):
            with self.subTest(registry=registry):
                (root / gate.INPUTS["test_registry"]).write_text(registry)
                with mock.patch.object(gate, "git", side_effect=[self.source, "b" * 40]):
                    with self.assertRaisesRegex(ValueError, "empty or ambiguous"):
                        gate.source_identity(root)


if __name__ == "__main__":
    unittest.main()
