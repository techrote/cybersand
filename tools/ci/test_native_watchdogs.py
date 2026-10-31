#!/usr/bin/env python3
"""Native execution-policy and real-shell failure controls; no native build."""
from __future__ import annotations

import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import threading
import unittest
from unittest import mock

import check_worldgen_build_inventory as worldgen
import execution_policy
import native_execution_policy as native_policy
import verify_native_shards as gate

ROOT = Path(__file__).resolve().parents[2]
FAMILY = ROOT / "tools/ci/run_native_family.sh"
WORKFLOW = ROOT / ".github/workflows/native.yml"


class NativeShellTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="native-watchdog-control-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        tools = self.root / "tools/ci"
        tools.mkdir(parents=True)
        shutil.copyfile(FAMILY, tools / FAMILY.name)
        for name in ("native_execution_policy.py", "execution_policy.py"):
            shutil.copyfile(ROOT / "tools/ci" / name, tools / name)
        policy = self.root / "godot/tests/support/ci_execution_policy.json"
        policy.parent.mkdir(parents=True)
        shutil.copyfile(execution_policy.POLICY_PATH, policy)
        # This records the actual shell's requested commands without executing a
        # compiler or altering a native fixture. The generic runner has its own
        # real-process timeout/termination tests.
        (tools / "run_timed_command.py").write_text(textwrap.dedent('''\
            import argparse, json, os, subprocess
            from pathlib import Path
            parser = argparse.ArgumentParser()
            parser.add_argument("--policy-key", required=True)
            parser.add_argument("--label", required=True)
            parser.add_argument("--output-dir", required=True)
            parser.add_argument("--timeout-seconds", required=True, type=float)
            parser.add_argument("command", nargs=argparse.REMAINDER)
            args = parser.parse_args()
            command = args.command[1:] if args.command[:1] == ["--"] else args.command
            record = {"label":args.label, "key":args.policy_key,
                      "output_dir":args.output_dir, "command":command,
                      "timeout_seconds":args.timeout_seconds}
            with Path(os.environ["CONTROL_LOG"]).open("a") as stream:
                stream.write(json.dumps(record) + "\\n")
            print("original command output " + args.label, flush=True)
            status = 0
            if args.label == os.environ.get("CONTROL_FAIL_LABEL"):
                status = int(os.environ["CONTROL_FAIL_CODE"])
            elif args.label.startswith("native-family-"):
                status = subprocess.run(command).returncode
            print("timed runner finalized " + args.label, flush=True)
            raise SystemExit(status)
        '''))
        (tools / "check_worldgen_build_inventory.py").write_text(textwrap.dedent('''\
            import argparse
            from pathlib import Path
            parser = argparse.ArgumentParser()
            parser.add_argument("--output", required=True, type=Path)
            args = parser.parse_args()
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text('{"synthetic_shell_control":true}\\n')
        '''))
        self.bin = self.root / "control-bin"
        self.bin.mkdir()
        compiler = self.bin / "g++-13"
        compiler.write_text("#!/bin/sh\nprintf 'synthetic shell control compiler\\n'\n")
        compiler.chmod(0o755)
        self.log = self.root / "commands.jsonl"
        self.environment = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                                CONTROL_LOG=str(self.log), GITHUB_SHA="a" * 40,
                                GITHUB_RUN_ID="1234", GITHUB_RUN_ATTEMPT="1")

    def execute(self, suite, *, failure=None, code=19, workflow=False):
        self.log.unlink(missing_ok=True)
        env = self.environment | {"SUITE": suite}
        if failure is not None:
            env.update(CONTROL_FAIL_LABEL=suite + "-" + failure, CONTROL_FAIL_CODE=str(code))
        if workflow:
            env["FAMILY_TIMEOUT_SECONDS"] = str(native_policy.family_timeout_seconds(suite))
            section = WORKFLOW.read_text().split(
                "      - name: Execute complete test family with shared watchdogs\n", 1)[1]
            section = section.split("      - name:", 1)[0].split("        run: |\n", 1)[1]
            command = ["bash", "-c", textwrap.dedent(section)]
        else:
            command = ["bash", "tools/ci/run_native_family.sh", suite, "build/native-parallel/" + suite]
        result = subprocess.run(command, cwd=self.root, env=env, capture_output=True,
                                text=True, timeout=execution_policy.watchdog_seconds("operation_seconds"))
        rows = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, rows

    def test_all_twenty_original_invocations_and_environments_are_preserved(self):
        count = 0
        for suite, expected in gate.COMMANDS.items():
            with self.subTest(suite=suite):
                result, rows = self.execute(suite)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual([(row["label"], row["key"], row["command"]) for row in rows],
                                 [(suite + "-" + label, key, command) for label, key, command in expected])
                for row, (label, _, _) in zip(rows, expected):
                    self.assertEqual(row["output_dir"], f"build/native-parallel/{suite}/commands/{label}")
                    self.assertEqual(row["timeout_seconds"], native_policy.command_timeout_seconds(suite, label))
                count += len(rows)
        self.assertEqual(count, 20)

    def test_each_original_command_preserves_error_and_timeout_exit(self):
        for suite, commands in gate.COMMANDS.items():
            for index, (label, _, _) in enumerate(commands):
                for code in (19, 124):
                    with self.subTest(suite=suite, label=label, code=code):
                        result, rows = self.execute(suite, failure=label, code=code)
                        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                        self.assertEqual(len(rows), index + 1, "execution continued after its first failure")

    def test_physics_log_capture_failure_stops_the_family(self):
        tee = self.bin / "tee"
        tee.write_text("#!/bin/sh\ncat\nexit 23\n")
        tee.chmod(0o755)
        result, rows = self.execute("worldgen")
        self.assertEqual(result.returncode, 23)
        self.assertEqual(len(rows), 1)

    def test_workflow_success_marker_follows_the_final_family_receipt(self):
        result, rows = self.execute("tsan", workflow=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(rows[0]["key"], "native_suite_seconds")
        self.assertEqual(rows[0]["timeout_seconds"], native_policy.family_timeout_seconds("tsan"))
        self.assertEqual(rows[0]["command"], ["bash", "tools/ci/run_native_family.sh", "tsan", "build/native-parallel/tsan"])
        folder = self.root / "build/native-parallel/tsan"
        self.assertTrue((folder / "run.log").read_text().rstrip().endswith("Native family passed: tsan"))
        self.assertEqual((folder / "family-exit-code.txt").read_text(), "0\n")
        self.assertEqual((folder / "log-capture-exit-code.txt").read_text(), "0\n")

    def test_workflow_retains_original_error_and_timeout_before_aggregation(self):
        for code in (19, 124):
            with self.subTest(code=code):
                result, _ = self.execute("native-normal", failure="build-tests", code=code, workflow=True)
                folder = self.root / "build/native-parallel/native-normal"
                self.assertEqual(result.returncode, code)
                self.assertEqual((folder / "family-exit-code.txt").read_text(), str(code) + "\n")
                self.assertEqual((folder / "log-capture-exit-code.txt").read_text(), "0\n")
                self.assertNotIn("Native family passed:", (folder / "run.log").read_text())

    def test_workflow_log_capture_failure_cannot_become_a_pass(self):
        tee = self.bin / "tee"
        tee.write_text("#!/bin/sh\ncat\nexit 23\n")
        tee.chmod(0o755)
        result, _ = self.execute("tsan", workflow=True)
        folder = self.root / "build/native-parallel/tsan"
        self.assertEqual(result.returncode, 23)
        self.assertEqual((folder / "family-exit-code.txt").read_text(), "0\n")
        self.assertEqual((folder / "log-capture-exit-code.txt").read_text(), "23\n")

    def test_unknown_family_is_rejected_without_running_commands(self):
        result, rows = self.execute("unregistered")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(rows, [])


class NativePolicyTests(unittest.TestCase):
    def test_hosted_jobs_leave_headroom_after_complete_family_watchdog(self):
        identity = execution_policy.identity()
        policy = identity["watchdogs"]
        limits = re.findall(r"^\s+timeout-minutes: (\d+)\s*$", WORKFLOW.read_text(), re.M)
        self.assertEqual(len(limits), 3)
        unscaled = json.loads(execution_policy.POLICY_PATH.read_text())["watchdogs"]
        self.assertTrue(all(int(value) == unscaled["hosted_job_minutes"] for value in limits))
        matrix = native_policy.matrix(identity)["include"]
        self.assertEqual({row["suite"] for row in matrix}, gate.SUITES)
        for row in matrix:
            children = sum(native_policy.command_timeout_seconds(row["suite"], label, identity)
                           for label, _, _ in gate.COMMANDS[row["suite"]])
            self.assertGreaterEqual(row["family_seconds"], children + policy["aggregate_headroom_seconds"])
            self.assertGreaterEqual(row["job_minutes"] * 60, row["family_seconds"]
                                    + policy["dependency_prepare_seconds"] + policy["aggregate_headroom_seconds"])
            self.assertLessEqual(row["job_minutes"], 360)
        self.assertIn("timeout-minutes: ${{ matrix.job_minutes }}", WORKFLOW.read_text())
        self.assertIn("matrix: ${{ fromJSON(needs.policy.outputs.matrix) }}", WORKFLOW.read_text())
        self.assertIn("CYBERSAND_CI_WATCHDOG_SCALE: '1'", WORKFLOW.read_text())
        self.assertIn("fail-fast: false", WORKFLOW.read_text())
        self.assertNotRegex(WORKFLOW.read_text() + FAMILY.read_text(), r"\btimeout\s+\d")

    def test_physics_parent_funds_all_twenty_dispatch_waves_and_build(self):
        policy = execution_policy.identity()
        values = policy["watchdogs"]
        self.assertEqual(native_policy.PHYSICS_INVOCATIONS, 154)
        self.assertEqual(native_policy.PHYSICS_DISPATCH_WORKERS, 8)
        self.assertEqual(native_policy.budget_inventory(policy)["physics_dispatch_waves"], 20)
        self.assertGreaterEqual(native_policy.command_timeout_seconds("worldgen", "physics-characterisation-sanitize", policy),
                                values["native_compile_seconds"] + 20 * values["operation_seconds"]
                                + values["aggregate_headroom_seconds"])

    def test_local_scale_enlarges_derived_parents_but_cannot_exceed_hosted_job_cap(self):
        source = json.loads(execution_policy.POLICY_PATH.read_text())
        ordinary = execution_policy.validate_policy(source)
        doubled = execution_policy.validate_policy(source, "2")
        for suite in gate.SUITES:
            self.assertEqual(native_policy.family_timeout_seconds(suite, doubled),
                             2 * native_policy.family_timeout_seconds(suite, ordinary))
        with self.assertRaisesRegex(ValueError, "supported hosted job limit"):
            native_policy.matrix(doubled)

    def test_native_metadata_commands_consume_operation_policy(self):
        limit = execution_policy.watchdog_seconds("operation_seconds")
        with mock.patch.object(gate.subprocess, "check_output", return_value="source\n") as process:
            self.assertEqual(gate.git(ROOT, "rev-parse", "HEAD"), "source")
            self.assertEqual(process.call_args.kwargs["timeout"], limit)

        result = subprocess.CompletedProcess([], 0, stdout="dry-run", stderr="")
        with mock.patch.object(worldgen.subprocess, "run", return_value=result) as process:
            worldgen.dry_run(ROOT, "worldgen-test", 2)
            self.assertEqual(process.call_args.kwargs["timeout"], limit)

    def test_required_native_gate_cannot_skip_after_scope_classifier_failure(self):
        aggregate = WORKFLOW.read_text().split("\n  native:\n", 1)[1]
        self.assertIn("needs.ready_scope.result != 'success'", aggregate.split("    runs-on:", 1)[0])


class NativeCliWatchdogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("native_characterisation_control", ROOT / "tools/physics/test_characterisation_cli.py")
        cls.cli = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.cli)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="native-cli-watchdog-")
        self.addCleanup(self.temporary.cleanup)
        self.case = self.cli.CharacterisationCliTests()
        self.case.output = Path(self.temporary.name)
        self.case.executable = self.case.output / "unexecuted-native-fixture"
        self.case.records = []
        self.case.prepared_results = None
        self.case.checked_invocations = []

    def test_full_material_inventory_and_one_tick_arguments_remain_unchanged(self):
        self.assertEqual(list(self.cli.BUILDING_IDS), list(range(81, 132)))
        self.assertEqual(len(self.cli.INVALID_IDS), 24)
        self.assertEqual(len(self.cli.BUILDING_IDS) * 2 + 4 + len(self.cli.INVALID_IDS) * 2, 154)
        completed = subprocess.CompletedProcess([], 0, stdout="original\n", stderr="")
        with mock.patch.object(self.cli.subprocess, "run", return_value=completed) as process:
            self.case.invoke("sample", 81, 1)
        self.assertEqual(process.call_args.args[0][1:], ["81", "1", "packed", "2", "0", "1", "1", "baseline", "1", "0", "3"])
        self.assertEqual(process.call_args.kwargs["timeout"], execution_policy.watchdog_seconds("operation_seconds"))

    def test_completion_after_old_ten_second_cap_is_retained(self):
        completed = subprocess.CompletedProcess([], 0, stdout="late original output\n", stderr="")
        with mock.patch.object(self.cli.subprocess, "run", return_value=completed), \
                mock.patch.object(self.cli.time, "monotonic", side_effect=[100.0, 125.0]):
            result = self.case.invoke("late-success", 81, 1)
        self.assertEqual(result["seconds"], 25.0)
        self.assertEqual(result["returncode"], 0)
        self.assertFalse(result["timed_out"])
        self.assertEqual((self.case.output / "late-success.jsonl").read_text(), "late original output\n")

    def test_failure_after_old_ten_second_cap_is_still_a_correctness_failure(self):
        completed = subprocess.CompletedProcess([], 19, stdout="original failure\n", stderr="failure diagnostic\n")
        with mock.patch.object(self.cli.subprocess, "run", return_value=completed), \
                mock.patch.object(self.cli.time, "monotonic", side_effect=[100.0, 125.0]):
            with self.assertRaises(AssertionError):
                self.case.check_material(81, "upper")
        self.assertEqual(self.case.records[0]["returncode"], 19)
        self.assertEqual(self.case.records[0]["seconds"], 25.0)
        self.assertEqual((self.case.output / "material-81-upper.stderr.log").read_text(), "failure diagnostic\n")

    def test_real_timeout_remains_failed_with_partial_original_output(self):
        limit = execution_policy.watchdog_seconds("operation_seconds")
        timeout = subprocess.TimeoutExpired(["unexecuted"], limit, output=b"partial stdout\n", stderr=b"partial stderr\n")
        with mock.patch.object(self.cli.subprocess, "run", side_effect=timeout):
            with self.assertRaisesRegex(AssertionError, "configured"):
                self.case.invoke("blocked", 81, 1)
        record = self.case.records[0]
        self.assertTrue(record["timed_out"])
        self.assertIsNone(record["returncode"])
        self.assertEqual(record["timeout_seconds"], limit)
        self.assertEqual((self.case.output / "blocked.jsonl").read_text(), "partial stdout\n")
        self.assertEqual((self.case.output / "blocked.stderr.log").read_text(), "partial stderr\n")

    def test_dispatch_retains_exact_union_and_order_with_at_most_eight_active_calls(self):
        plan = self.cli.invocation_plan()
        positions = {item["name"]: index for index, item in enumerate(plan)}
        lock = threading.Lock()
        barrier = threading.Barrier(8)
        release_first = threading.Event()
        state = {"active": 0, "peak": 0}
        started, finished, worker_threads = [], [], set()

        def execute(executable, output, item):
            index = positions[item["name"]]
            with lock:
                state["active"] += 1
                state["peak"] = max(state["peak"], state["active"])
                started.append(item["name"])
                worker_threads.add(threading.get_ident())
            if index < 8:
                barrier.wait(timeout=5)  # Deliberate bounded concurrency control.
            if index == 0 and not release_first.wait(timeout=5):
                raise RuntimeError("dispatch concurrency control did not release")
            with lock:
                finished.append(item["name"])
                state["active"] -= 1
            if index == 1:
                release_first.set()
            return {"name": item["name"], "command": self.cli.invocation_command(executable, item["top"], item["bottom"])}

        with mock.patch.object(self.cli, "execute_invocation", side_effect=execute):
            results = self.cli.dispatch_invocations(self.case.executable, self.case.output, plan)
        expected = [item["name"] for item in plan]
        self.assertEqual(len(started), 154)
        self.assertEqual(set(started), set(expected))
        self.assertEqual([row["name"] for row in results], expected)
        self.assertEqual(state["peak"], 8)
        self.assertNotEqual(finished, expected)
        self.assertNotIn(threading.get_ident(), worker_threads)

    def test_actual_dispatched_processes_keep_every_original_argument_and_output_label(self):
        executable = self.case.executable
        executable.write_text("#!" + sys.executable + "\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n")
        executable.chmod(0o755)
        plan = self.cli.invocation_plan()
        results = self.cli.dispatch_invocations(executable, self.case.output, plan)
        self.assertEqual(len(results), 154)
        for item, result in zip(plan, results):
            self.assertEqual(result["returncode"], 0)
            self.assertEqual(result["name"], item["name"])
            self.assertEqual(json.loads(result["stdout"]),
                             self.cli.invocation_command(executable, item["top"], item["bottom"])[1:])
            self.assertEqual((self.case.output / (item["name"] + ".jsonl")).read_text(), result["stdout"])
            self.assertTrue((self.case.output / (item["name"] + ".stderr.log")).is_file())

    def prepared_scientific_result(self, item):
        # Synthetic stream for exercising the unchanged main-thread assertions;
        # this is a dispatcher control, never native scientific qualification.
        record = {"name": item["name"], "command": self.cli.invocation_command(self.case.executable, item["top"], item["bottom"]),
                  "returncode": 1 if item["name"].startswith("invalid-") else 0,
                  "launch_error": None, "timed_out": False, "timeout_seconds": 300,
                  "seconds": 25.0, "stdout": "", "stderr": "synthetic rejection\n"}
        if record["returncode"] == 0:
            material = item["top"] if item["bottom"] == 1 else item["bottom"]
            upper = item["bottom"] == 1
            counts, sums = [0] * 132, [0] * 132
            counts[0], sums[0] = 550, 25625
            counts[1], sums[1] = (210, 10575) if upper else (252, 14196)
            counts[material], sums[material] = (48, 4200) if upper else (6, 579)
            sample = {"type": "sample", "counts": counts, "sum_y": sums, "water_mass": 0}
            summary = {"type": "result", "completed_ticks": 1, "overflow": 0,
                       "left_x": 64, "surface_y": 96, "floor_y": 98}
            record.update(stdout="\n".join(json.dumps(row) for row in [sample | {"tick": 0}, sample | {"tick": 1}, summary]) + "\n",
                          stderr="")
        return record

    def run_prepared_assertions(self, fail_label=None):
        plan = self.cli.invocation_plan()
        results = {item["name"]: self.prepared_scientific_result(item) for item in plan}
        if fail_label:
            results[fail_label]["returncode"] = 19
        threads = []
        original = self.cli.CharacterisationCliTests.invoke

        def invoke(case, *args):
            threads.append(threading.get_ident())
            return original(case, *args)

        prepared = type("PreparedAssertions", (self.cli.CharacterisationCliTests,), {
            "prepared_results": results, "checked_invocations": [], "records": [],
            "executable": self.case.executable, "output": self.case.output, "invoke": invoke,
        })
        outcome = unittest.TextTestRunner(stream=io.StringIO()).run(unittest.defaultTestLoader.loadTestsFromTestCase(prepared))
        self.assertEqual(prepared.checked_invocations, [item["name"] for item in plan])
        self.assertEqual(set(threads), {threading.get_ident()})
        return outcome, results

    def test_original_scientific_assertions_consume_all_prefetched_results_on_main_thread(self):
        outcome, _ = self.run_prepared_assertions()
        self.assertTrue(outcome.wasSuccessful(), outcome.failures + outcome.errors)
        self.assertEqual(outcome.testsRun, 3)

    def test_prefetched_late_failure_remains_red_and_does_not_hide_other_invocations(self):
        outcome, results = self.run_prepared_assertions("material-80-lower")
        self.assertFalse(outcome.wasSuccessful())
        self.assertEqual(len(outcome.failures), 1)
        self.assertEqual(results["material-80-lower"]["returncode"], 19)
        self.assertEqual(results["material-80-lower"]["seconds"], 25.0)

    def test_duplicate_or_escaping_labels_are_rejected_before_dispatch(self):
        item = self.cli.invocation_plan()[0]
        for plan in ([item, item], [item | {"name": "../outside"}]):
            with self.subTest(plan=plan), mock.patch.object(self.cli, "execute_invocation") as execute:
                with self.assertRaisesRegex(ValueError, "unique safe"):
                    self.cli.dispatch_invocations(self.case.executable, self.case.output, plan)
                execute.assert_not_called()


if __name__ == "__main__":
    unittest.main()
