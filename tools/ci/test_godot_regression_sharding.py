#!/usr/bin/env python3
"""Unit tests for deterministic Godot regression shard planning."""

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_godot_regressions as subject


def fake(name: str, weight: float) -> subject.Case:
    return subject.Case(name, ("--script", name + ".gd"), 180, weight)


class ShardingTests(unittest.TestCase):
    def test_runtime_identity_follows_host_platform(self):
        windows_runtime, windows_rapier = subject.runtime_paths("win32")
        self.assertEqual(windows_runtime.name, "cybersand_native.windows.x86_64.dll")
        self.assertEqual(windows_rapier.name, "libgodot_rapier.windows.x86_64-pc-windows-msvc.dll")

        linux_runtime, linux_rapier = subject.runtime_paths("linux")
        self.assertEqual(linux_runtime.name, "libcybersand_native.linux.x86_64.so")
        self.assertEqual(linux_rapier.name, "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")

        with self.assertRaises(RuntimeError):
            subject.runtime_paths("darwin")

    def test_four_way_plan_has_exact_coverage(self):
        cases = [
            fake("a", 54),
            fake("b", 37),
            fake("c", 20),
            fake("d", 14),
            fake("e", 13),
            fake("f", 11),
            fake("g", 10),
            fake("h", 5),
        ]
        shards, _ = subject.build_shard_plan(cases, 4)
        flattened = [case.name for shard in shards for case in shard]
        self.assertCountEqual(flattened, [case.name for case in cases])
        self.assertEqual(len(flattened), len(set(flattened)))

    def test_plan_is_deterministic(self):
        cases = [fake("slow", 20), fake("mid", 10), fake("small", 5), fake("tiny", 1)]
        first, first_totals = subject.build_shard_plan(cases, 3)
        second, second_totals = subject.build_shard_plan(cases, 3)
        self.assertEqual(
            [[case.name for case in shard] for shard in first],
            [[case.name for case in shard] for shard in second],
        )
        self.assertEqual(first_totals, second_totals)

    def test_worker_parity_case_is_assigned_once(self):
        cases = subject.discover_cases()
        shards, _ = subject.build_shard_plan(cases, 4)
        parity_shards = [
            index
            for index, shard in enumerate(shards)
            if any(case.name == "test_web_worker_parity" for case in shard)
        ]
        # Every current Linux shard uses the same >=2-vCPU GitHub-hosted runner.
        # New fixtures can legitimately move this case under weighted scheduling.
        self.assertEqual(len(parity_shards), 1)

    def test_new_render_cases_are_automatically_graphical(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tests = root / "godot/tests"
            tests.mkdir(parents=True)
            (tests / "test_cpu.gd").write_text("extends SceneTree\n", encoding="utf-8")
            (tests / "test_new_render.gd").write_text("extends SceneTree\n", encoding="utf-8")
            cases = subject.discover_cases(root)
        graphical = [case.name for case in cases if case.requires_display]
        self.assertEqual(graphical, ["test_new_render"])
        shards, _ = subject.build_shard_plan(cases, 4)
        self.assertEqual(sum(case.requires_display for shard in shards for case in shard), 1)

    def test_render_command_requires_a_display_and_compatibility_renderer(self):
        case = subject.Case("test_pixels_render", ("--script", "test.gd"), 180, 5, True)
        command = subject.case_command("godot", case, "linux")
        self.assertNotIn("--headless", command)
        self.assertEqual(command[command.index("--display-driver") + 1], "x11")
        self.assertEqual(command[command.index("--rendering-method") + 1], "gl_compatibility")
        self.assertIn("--headless", subject.case_command("godot", fake("test_cpu", 1), "linux"))

    def test_unknown_case_weight_is_conservative(self):
        self.assertEqual(subject._weight("brand_new_test"), subject.DEFAULT_UNKNOWN_WEIGHT_SECONDS)

    def test_invalid_shard_count_is_rejected(self):
        with self.assertRaises(ValueError):
            subject.build_shard_plan([fake("a", 1)], 0)


class ResultTests(unittest.TestCase):
    def run_child(self, program: str, *, timeout: float = 5) -> tuple[dict, bool]:
        case = subject.Case("fixture", (), timeout, 1)
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            # Exercise real subprocess output/exit/timeout handling independently
            # of the installed Godot runtime and local graphical capabilities.
            with mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", program]):
                return subject.run_case("unused", case, Path(directory), "case")

    def test_zero_exit_after_actual_assertions_passes(self):
        result, failed = self.run_child("print('PIXELS: 12 assertions; 0 failures')")
        self.assertEqual(result["status"], "passed")
        self.assertFalse(failed)

    def test_process_can_retain_raw_artifacts_beside_its_log(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            command = [sys.executable, "-c", (
                "import os; from pathlib import Path; "
                "p=Path(os.environ['CYBERSAND_TEST_ARTIFACT_DIR']); "
                "p.mkdir(); (p/'pixel-control.txt').write_text('retained child output'); "
                "print('artifact control passed')"
            )]
            with mock.patch.object(subject, "case_command", return_value=command):
                result, failed = subject.run_case("unused", fake("fixture", 1), output, "case")
            self.assertFalse(failed)
            self.assertEqual(result["status"], "passed")
            self.assertEqual((output / "fixture-artifacts/pixel-control.txt").read_text(), "retained child output")

    def test_zero_exit_with_script_error_fails(self):
        result, failed = self.run_child("print('SCRIPT ERROR: assertion failed')")
        self.assertEqual(result["status"], "failed")
        self.assertTrue(result["diagnostic_error"])
        self.assertTrue(failed)

    def test_internal_guard_error_cannot_pass_after_zero_exit(self):
        result, failed = self.run_child("print('ERROR: REGRESSION_WATCHDOG expired without main-thread progress')")
        self.assertEqual(result["returncode"], 0)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(result["diagnostic_error"])
        self.assertTrue(failed)

    def test_headless_skip_cannot_pass(self):
        for message in (
            "MATERIAL_PRESENTATION_RENDER: skipped (headless DisplayServer has no frame submission)",
            "Depth surface pixel check skipped: requires a rendering display",
            "SKIP: backend unavailable",
        ):
            with self.subTest(message=message):
                result, failed = self.run_child(f"print({message!r})")
                self.assertEqual(result["status"], "skipped")
                self.assertEqual(result["returncode"], 0)
                self.assertEqual(result["skip_messages"], [message])
                self.assertTrue(failed)

    def test_nonzero_exit_without_error_text_fails(self):
        result, failed = self.run_child("raise SystemExit(7)")
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["returncode"], 7)
        self.assertTrue(failed)

    def test_timeout_remains_a_required_failure(self):
        result, failed = self.run_child("import time; time.sleep(10)", timeout=0.05)
        self.assertEqual(result["status"], "timeout")
        self.assertTrue(failed)

    def test_timeout_preserves_test_duration_tail_and_snapshot(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            case = fake("stalled", 1)
            child = (
                "import sys,time;"
                "print('REGRESSION_PROGRESS case=stalled phase=world tick=120',flush=True);"
                "time.sleep(5)"
            )
            with mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", child]):
                result, failed = subject.run_case("fixture", case.__class__(
                    case.name, case.flags, 0.05, case.weight), output, "case")
            self.assertTrue(failed)
            self.assertEqual(result["status"], "timeout")
            self.assertLess(result["seconds"], 1.0)
            self.assertGreaterEqual(result["diagnostic_seconds"], 0)
            self.assertIn("phase=world", result["last_progress"])
            self.assertIn("TIMEOUT", (output / result["log"]).read_text())
            snapshot = output / result["timeout_diagnostics"]
            self.assertTrue(snapshot.exists())
            self.assertIn("Last 60 lines", snapshot.read_text())
            self.assertIn("world tick=120", snapshot.read_text())

    def test_snapshot_failure_still_kills_and_records_timeout(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            case = subject.Case("snapshot_failure", (), 0.05, 1)
            processes = []
            kill_tree = subject._kill_process_tree

            def kill_and_observe(process):
                processes.append(process)
                kill_tree(process)

            with (
                mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", "import time;time.sleep(30)"]),
                mock.patch.object(subject, "_capture_timeout_snapshot", side_effect=RuntimeError("synthetic observation failure")),
                mock.patch.object(subject, "_kill_process_tree", side_effect=kill_and_observe),
            ):
                result, failed = subject.run_case("fixture", case, output, "case")
            self.assertTrue(failed)
            self.assertEqual(result["status"], "timeout")
            self.assertIsNone(result["launch_error"])
            self.assertIn("synthetic observation failure", result["timeout_diagnostic_error"])
            self.assertIn("synthetic observation failure", (output / result["timeout_diagnostics"]).read_text())
            self.assertEqual(len(processes), 1)
            self.assertIsNotNone(processes[0].poll())

    def test_snapshot_precedes_process_tree_kill(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            events = []
            kill_tree = subject._kill_process_tree

            def snapshot(pid, path, _log, _elapsed):
                events.append(("snapshot", pid))
                path.write_text("snapshot while alive")

            def kill_and_observe(process):
                self.assertIsNone(process.poll())
                events.append(("kill", process.pid))
                kill_tree(process)

            with (
                mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", "import time;time.sleep(30)"]),
                mock.patch.object(subject, "_capture_timeout_snapshot", side_effect=snapshot),
                mock.patch.object(subject, "_kill_process_tree", side_effect=kill_and_observe),
            ):
                result, failed = subject.run_case("fixture", subject.Case("ordering", (), 0.05, 1), Path(directory), "case")
            self.assertTrue(failed)
            self.assertEqual(events, [("snapshot", result["pid"]), ("kill", result["pid"])])

    def test_unavailable_executable_is_recorded_as_failure(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            result, failed = subject.run_case(str(Path(directory) / "missing-godot"), fake("missing", 1), Path(directory), "case")
        self.assertEqual(result["status"], "failed")
        self.assertIsNotNone(result["launch_error"])
        self.assertTrue(failed)

    def test_keep_going_runs_the_complete_plan_and_still_fails(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            root = Path(directory)
            native, rapier = root / "native.so", root / "rapier.so"
            native.write_bytes(b"native-fixture")
            rapier.write_bytes(b"rapier-fixture")
            output = root / "results"
            cases = [fake("fails", 1), fake("runs_after_failure", 1)]

            def child_command(_godot, case):
                code = "print('assertion failed'); raise SystemExit(9)" if case.name == "fails" else "print('12 assertions; 0 failures')"
                return [sys.executable, "-c", code]

            with (
                mock.patch.object(subject, "ROOT", root),
                mock.patch.object(subject, "runtime_paths", return_value=(native, rapier)),
                mock.patch.object(subject, "discover_cases", return_value=cases),
                mock.patch.object(subject, "case_command", side_effect=child_command),
                mock.patch.object(subject.subprocess, "check_output", side_effect=["a" * 40, "fixture-godot"]),
                mock.patch.object(sys, "argv", ["runner", "--godot", "fixture-godot", "--output", str(output), "--keep-going"]),
            ):
                status = subject.main()
            result = json.loads((output / "timings.json").read_text(encoding="utf-8"))
        self.assertEqual(status, 1)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(result["completed"])
        self.assertEqual([case["name"] for case in result["results"]], ["import", "fails", "runs_after_failure"])
        self.assertEqual([case["status"] for case in result["results"]], ["passed", "failed", "passed"])


class SnapshotTests(unittest.TestCase):
    def test_tail_is_bounded_even_with_a_single_oversized_line(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "long.log"
            path.write_bytes(b"x" * (1024 * 1024) + b"\nlast line\n")
            tail = subject._tail(path)
        self.assertIn("tail capped", tail)
        self.assertLessEqual(len(tail), 256 * 1024 + 100)
        self.assertTrue(tail.endswith("last line"))

    def test_command_output_is_capped_with_an_explicit_marker(self):
        result = subject._snapshot_command([
            sys.executable, "-c", "import sys;sys.stdout.write('o'*200000);sys.stderr.write('e'*200000)",
        ])
        self.assertIn("exit=0", result)
        self.assertIn("snapshot output capped", result)
        self.assertLess(len(result), 81000)
        self.assertTrue(result.endswith("e" * 16000))

    def test_command_timeout_cannot_wait_on_descendant_output_pipes(self):
        # The child inherits output and survives longer than its parent timeout.
        # A subprocess.run(..., PIPE) cleanup can block waiting on these handles.
        command = [sys.executable, "-c", (
            "import subprocess,sys,time;"
            "subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)']);"
            "print('before timeout',flush=True);time.sleep(30)"
        )]
        started = time.perf_counter()
        result = subject._snapshot_command(command, timeout=0.25)
        self.assertLess(time.perf_counter() - started, 8)
        self.assertIn("TimeoutExpired", result)
        self.assertIn("before timeout", result)

    def test_unavailable_debugger_command_is_explicit(self):
        result = subject._snapshot_command(["missing-issue233-snapshot-command"])
        self.assertIn("SNAPSHOT UNAVAILABLE: FileNotFoundError", result)

    def test_linux_snapshot_retains_session_tree_threads_and_ptrace_refusal(self):
        commands = []

        def command_result(command):
            commands.append(command)
            return "ptrace: Operation not permitted" if "gdb" in command else "process wait state"

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "snapshot.txt"
            log = Path(directory) / "fixture.log"
            log.write_text("REGRESSION_PROGRESS phase=bridge_step tick=120\n")
            with (
                mock.patch.object(subject.sys, "platform", "linux"),
                mock.patch.object(subject.shutil, "which", side_effect=lambda name: "/usr/bin/" + name),
                mock.patch.object(subject, "_snapshot_command", side_effect=command_result),
            ):
                subject._capture_timeout_snapshot(123, path, log, 180)
            output = path.read_text()
        self.assertEqual(commands[0][:4], ["ps", "--forest", "-s", "123"])
        self.assertIn("wchan:32", commands[0][-1])
        self.assertEqual(commands[1][:4], ["ps", "-T", "-p", "123"])
        self.assertEqual(commands[2][:3], ["sudo", "-n", "gdb"])
        self.assertIn("Operation not permitted", output)
        self.assertIn("phase=bridge_step tick=120", output)

    @unittest.skipUnless(sys.platform == "win32", "actual Windows process/thread observation")
    def test_windows_snapshot_has_actual_per_thread_state_without_a_debugger(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "snapshot.txt"
            log = Path(directory) / "fixture.log"
            log.write_text("REGRESSION_PROGRESS phase=world tick=120\n")
            subject._capture_timeout_snapshot(os.getpid(), path, log, 180)
            output = path.read_text()
        self.assertRegex(output, r"(?m)^ProcessId\s*:\s*\d+")
        self.assertRegex(output, r"(?m)^ThreadId\s*:\s*\d+")
        self.assertRegex(output, r"(?m)^WaitReason\s*:\s*\w+")
        self.assertRegex(output, r"(?m)^State\s*:\s*\w+")
        self.assertIn("without a preinstalled debugger", output)
        self.assertNotIn("\nSNAPSHOT UNAVAILABLE:", output)
        self.assertNotIn("\nTHREAD SNAPSHOT UNAVAILABLE:", output)


class Life010ReadbackTests(unittest.TestCase):
    """Parent-runner failure controls; these are not engine executions."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.output = Path(self.temporary.name)
        self.case = fake("test_play_life010_acrobat", 5)
        self.source = "1" * 40
        self.record = {"name": self.case.name, "status": "passed", "returncode": 0,
                       "log": self.case.name + ".log", "seconds": 1.0, "timeout_seconds": 180}
        (self.output / self.record["log"]).write_bytes(b"original engine evidence\n")
        artifacts = self.output / (self.case.name + "-artifacts")
        artifacts.mkdir()
        (artifacts / "acrobat-life010.json").write_bytes(b"original raw result\n")
        self.identity = {"source_revision": self.source,
                         "actual_sha256": subject.sha256(subject.ROOT / "tools/ci/verify_play_life010.py")}
        identity = mock.patch.object(subject, "life010_verifier_identity", return_value=self.identity)
        identity.start()
        self.addCleanup(identity.stop)

    def successful_verifier(self, command, **kwargs):
        self.assertIn("--self-test", command)
        self.assertEqual(command[command.index("--source") + 1], self.source)
        self.assertGreater(kwargs["timeout"], 0)
        self.assertLessEqual(kwargs["timeout"], 15)
        result = {"source_revision": self.source, "rig": "acrobat", "failures": 0,
                  "real_lifetimes": 2, "rejected_deliveries": 5, "native_commits": 2,
                  "lease_valid_cancellations": 1,
                  "adverse_controls": [{"name": str(i), "rejected_for": "controlled"} for i in range(21)]}
        for name, argument in (("process", "--process-json"), ("log", "--log"), ("result", "--result")):
            result[name + "_sha256"] = subject.sha256(Path(command[command.index(argument) + 1]))
        subject.write_json(Path(command[command.index("--output") + 1]), result)
        return subject.subprocess.CompletedProcess(command, 0)

    def test_full_readback_preserves_original_engine_receipt(self):
        with mock.patch.object(subject.subprocess, "run", side_effect=self.successful_verifier):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "passed")
        receipt = self.output / result["receipt"]
        self.assertEqual(json.loads(receipt.read_text()), self.record)
        self.assertEqual(subject.sha256(receipt), result["receipt_sha256"])
        self.assertEqual((self.output / self.record["log"]).read_bytes(), b"original engine evidence\n")

    def test_nonzero_verifier_cannot_promote_successful_engine(self):
        with mock.patch.object(subject.subprocess, "run", return_value=subject.subprocess.CompletedProcess([], 1)):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["returncode"], 1)
        self.assertEqual(self.record["status"], "passed")
        self.assertEqual(self.record["returncode"], 0)

    def test_timeout_is_an_incomplete_readback(self):
        with mock.patch.object(subject.subprocess, "run", side_effect=subject.subprocess.TimeoutExpired([], 15)):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertIn("TimeoutExpired", result["error"])

    def test_zero_exit_without_result_is_not_a_pass(self):
        with mock.patch.object(subject.subprocess, "run", return_value=subject.subprocess.CompletedProcess([], 0)):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")

    def test_missing_control_is_not_a_pass(self):
        def incomplete(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            path = Path(command[command.index("--output") + 1])
            value = json.loads(path.read_text())
            value["adverse_controls"].pop()
            subject.write_json(path, value)
            return result
        with mock.patch.object(subject.subprocess, "run", side_effect=incomplete):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertIn("inventory is incomplete", result["error"])

    def test_existing_original_receipt_is_never_overwritten(self):
        directory = self.output / (self.case.name + "-readback")
        directory.mkdir()
        original = directory / "engine-process.json"
        original.write_bytes(b"original retained attempt\n")
        with mock.patch.object(subject.subprocess, "run") as execute:
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        execute.assert_not_called()
        self.assertEqual(original.read_bytes(), b"original retained attempt\n")

    def test_malformed_result_is_recorded_without_aborting_later_cases(self):
        def malformed(command, **kwargs):
            subject.write_json(Path(command[command.index("--output") + 1]), [])
            return subject.subprocess.CompletedProcess(command, 0)
        with mock.patch.object(subject.subprocess, "run", side_effect=malformed):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertIn("result is not an object", result["error"])

    def test_malformed_control_is_recorded_without_aborting_later_cases(self):
        def malformed(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            path = Path(command[command.index("--output") + 1])
            value = json.loads(path.read_text())
            value["adverse_controls"][0] = 1
            subject.write_json(path, value)
            return result
        with mock.patch.object(subject.subprocess, "run", side_effect=malformed):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertIn("control inventory is malformed", result["error"])

    def digest_substitution(self, name):
        def substituted(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            path = Path(command[command.index("--output") + 1])
            value = json.loads(path.read_text())
            value[name + "_sha256"] = "0" * 64
            subject.write_json(path, value)
            return result
        with mock.patch.object(subject.subprocess, "run", side_effect=substituted):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertIn("input digest mismatch", result["error"])

    def test_substituted_process_digest_is_rejected(self):
        self.digest_substitution("process")

    def test_substituted_log_digest_is_rejected(self):
        self.digest_substitution("log")

    def test_substituted_raw_result_digest_is_rejected(self):
        self.digest_substitution("result")

    def test_verifier_byte_change_is_rejected(self):
        self.identity["actual_sha256"] = "0" * 64
        with mock.patch.object(subject.subprocess, "run", side_effect=self.successful_verifier):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertIn("verifier changed during readback", result["error"])

    def test_original_input_change_during_readback_is_rejected(self):
        def mutate_input(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            path = Path(command[command.index("--result") + 1])
            path.write_bytes(path.read_bytes() + b"changed after verification\n")
            return result
        with mock.patch.object(subject.subprocess, "run", side_effect=mutate_input):
            result = subject.verify_life010_case(self.case, self.record, self.output, self.source)
        self.assertEqual(result["status"], "failed")
        self.assertIn("original input changed during readback", result["error"])

    def test_parent_case_fails_after_a_successful_engine_when_readback_fails(self):
        with mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", "print('engine control')"]), \
             mock.patch.object(subject, "verify_life010_case", return_value={"status": "failed", "error": "controlled refusal"}), \
             redirect_stdout(io.StringIO()):
            record, failed = subject.run_case(sys.executable, self.case, self.output, "case")
        self.assertTrue(failed)
        self.assertEqual(record["status"], "failed")
        self.assertEqual(record["returncode"], 0)
        self.assertEqual(record["independent_evidence"]["error"], "controlled refusal")


class Life010VerifierIdentityTests(unittest.TestCase):
    def check_identity(self, actual, canonical):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "tools/ci/verify_play_life010.py"
            path.parent.mkdir(parents=True)
            path.write_bytes(actual)
            with mock.patch.object(subject, "ROOT", root), \
                 mock.patch.object(subject.subprocess, "check_output", return_value=canonical) as git:
                result = subject.life010_verifier_identity("1" * 40)
            git.assert_called_once_with(["git", "show", "1" * 40 + ":tools/ci/verify_play_life010.py"],
                                        cwd=root, timeout=5)
        return result

    def test_exact_source_bytes_are_identified(self):
        result = self.check_identity(b"original verifier\n", b"original verifier\n")
        self.assertEqual(result["actual_sha256"], result["canonical_sha256"])

    def test_crlf_checkout_preserves_separate_actual_byte_identity(self):
        result = self.check_identity(b"original verifier\r\n", b"original verifier\n")
        self.assertNotEqual(result["actual_sha256"], result["canonical_sha256"])
        self.assertEqual(result["actual_sha256"], subject.hashlib.sha256(b"original verifier\r\n").hexdigest())

    def test_modified_verifier_is_refused_before_execution(self):
        with self.assertRaisesRegex(ValueError, "differs from its source commit"):
            self.check_identity(b"altered verifier\n", b"original verifier\n")


class Input011ReadbackTests(unittest.TestCase):
    """Controlled parent receipts only; no Godot or gameplay qualification."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.output = self.root / "output"
        self.output.mkdir()
        self.contract = subject.INPUT011_READBACK
        self.case = fake("test_play_input011_acrobat", 5)
        self.source = "1" * 40
        self.record = {"name": self.case.name, "status": "passed", "returncode": 0,
                       "log": self.case.name + ".log", "seconds": 1.0, "timeout_seconds": 180}
        self.raw = b'{"scope":"synthetic parent gate control only"}'
        self.original_log = b"engine control\nPLAY_INPUT011_RESULT " + self.raw + b"\n"
        (self.output / self.record["log"]).write_bytes(self.original_log)
        paths = (self.contract.verifier, *self.contract.source_inputs)
        self.source_bytes = {path.format(rig="acrobat"): (path + "\n").encode() for path in paths}
        for name, data in self.source_bytes.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        root_patch = mock.patch.object(subject, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        git_patch = mock.patch.object(subject.subprocess, "check_output", side_effect=self.canonical_source)
        git_patch.start()
        self.addCleanup(git_patch.stop)

    def canonical_source(self, command, *, cwd, timeout):
        self.assertEqual(command[:2], ["git", "show"])
        self.assertEqual(cwd, self.root)
        self.assertGreater(timeout, 0)
        self.assertLessEqual(timeout, 5)
        source, path = command[2].split(":", 1)
        self.assertEqual(source, self.source)
        return self.source_bytes[path]

    def successful_verifier(self, command, **kwargs):
        self.assertIn("--self-test", command)
        self.assertEqual(command[command.index("--rig") + 1], "acrobat")
        self.assertEqual(command[command.index("--source") + 1], self.source)
        self.assertGreater(kwargs["timeout"], 0)
        self.assertLessEqual(kwargs["timeout"], 15)
        result = dict(self.contract.required_values, source_revision=self.source, rig="acrobat")
        result.update(self.contract.minimum_values)
        for field, count in self.contract.control_counts:
            result[field] = [{"name": str(index), "rejected_for": "controlled"} for index in range(count)]
        for field, argument in (("process_sha256", "--process-json"), ("log_sha256", "--log"),
                                ("raw_result_sha256", "--result")):
            result[field] = subject.sha256(Path(command[command.index(argument) + 1]))
        result["verifier_sha256"] = subject.sha256(self.root / self.contract.verifier)
        result["consumed_source_sha256"] = {
            field: subject.hashlib.sha256(self.source_bytes[path]).hexdigest()
            for field, path in self.contract.consumed_source_fields}
        subject.write_json(Path(command[command.index("--output") + 1]), result)
        return subject.subprocess.CompletedProcess(command, 0)

    def verify(self, execute=None):
        with mock.patch.object(subject.subprocess, "run", side_effect=execute or self.successful_verifier):
            return subject.verify_case_evidence(self.case, self.record, self.output, self.source, self.contract)

    def alter_evidence(self, change):
        def altered(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            path = Path(command[command.index("--output") + 1])
            value = json.loads(path.read_text())
            change(value)
            subject.write_json(path, value)
            return result
        return self.verify(altered)

    def test_exact_embedded_payload_and_original_receipt_are_retained(self):
        result = self.verify()
        self.assertEqual(result["status"], "passed")
        self.assertEqual((self.output / result["raw_result"]).read_bytes(), self.raw)
        self.assertEqual((self.output / self.record["log"]).read_bytes(), self.original_log)
        self.assertEqual(json.loads((self.output / result["receipt"]).read_text()), self.record)
        self.assertEqual(len(result["source_input_identity"]), 5)
        self.assertEqual(subject.sha256(self.output / result["output"]), result["output_sha256"])
        self.assertEqual(subject.sha256(self.output / result["verifier_log"]), result["verifier_log_sha256"])

    def test_nonzero_verifier_cannot_promote_engine_success(self):
        result = self.verify(lambda *args, **kwargs: subject.subprocess.CompletedProcess([], 1))
        self.assertEqual(result["status"], "failed")
        self.assertEqual(result["returncode"], 1)
        self.assertEqual(self.record["returncode"], 0)

    def test_timeout_cannot_promote_engine_success(self):
        def timeout(*args, **kwargs):
            raise subject.subprocess.TimeoutExpired([], 15)
        result = self.verify(timeout)
        self.assertEqual(result["status"], "failed")
        self.assertIn("TimeoutExpired", result["error"])

    def test_zero_exit_without_evidence_is_incomplete(self):
        result = self.verify(lambda *args, **kwargs: subject.subprocess.CompletedProcess([], 0))
        self.assertEqual(result["status"], "failed")

    def test_missing_raw_marker_is_refused_before_verifier_execution(self):
        (self.output / self.record["log"]).write_bytes(b"engine footer only\n")
        with mock.patch.object(subject.subprocess, "run") as execute:
            result = subject.verify_case_evidence(self.case, self.record, self.output, self.source, self.contract)
        execute.assert_not_called()
        self.assertEqual(result["status"], "failed")
        self.assertIn("raw result inventory", result["error"])

    def test_duplicate_raw_marker_is_not_arbitrarily_selected(self):
        (self.output / self.record["log"]).write_bytes(self.original_log * 2)
        result = self.verify()
        self.assertEqual(result["status"], "failed")
        self.assertIn("raw result inventory", result["error"])

    def test_missing_trace_control_is_incomplete(self):
        result = self.alter_evidence(lambda value: value["adverse_controls"].pop())
        self.assertEqual(result["status"], "failed")
        self.assertIn("inventory is incomplete", result["error"])

    def test_missing_process_control_is_incomplete(self):
        result = self.alter_evidence(lambda value: value["process_adverse_controls"].pop())
        self.assertEqual(result["status"], "failed")
        self.assertIn("inventory is incomplete", result["error"])

    def test_duplicate_control_cannot_replace_missing_control(self):
        result = self.alter_evidence(lambda value: value["adverse_controls"][1].update(name="0"))
        self.assertEqual(result["status"], "failed")
        self.assertIn("inventory is incomplete", result["error"])

    def test_malformed_control_does_not_abort_later_cases(self):
        result = self.alter_evidence(lambda value: value["process_adverse_controls"].__setitem__(0, 1))
        self.assertEqual(result["status"], "failed")
        self.assertIn("inventory is malformed", result["error"])

    def test_incomplete_physical_result_cannot_pass(self):
        result = self.alter_evidence(lambda value: value.update(completed_fresh_steps=0))
        self.assertEqual(result["status"], "failed")
        self.assertIn("inventory is incomplete", result["error"])

    def test_additional_valid_physics_samples_do_not_fail_the_parent(self):
        result = self.alter_evidence(lambda value: value.update(completed_held_steps=22, completed_fresh_steps=22))
        self.assertEqual(result["status"], "passed")

    def test_below_minimum_completed_samples_are_refused(self):
        result = self.alter_evidence(lambda value: value.update(completed_held_steps=20))
        self.assertEqual(result["status"], "failed")
        self.assertIn("inventory is incomplete", result["error"])

    def test_wrong_rig_cannot_pass(self):
        result = self.alter_evidence(lambda value: value.update(rig="jetbarrel"))
        self.assertEqual(result["status"], "failed")

    def test_substituted_raw_payload_digest_is_refused(self):
        result = self.alter_evidence(lambda value: value.update(raw_result_sha256="0" * 64))
        self.assertEqual(result["status"], "failed")
        self.assertIn("input digest mismatch", result["error"])

    def test_substituted_original_log_digest_is_refused(self):
        result = self.alter_evidence(lambda value: value.update(log_sha256="0" * 64))
        self.assertEqual(result["status"], "failed")
        self.assertIn("input digest mismatch", result["error"])

    def test_substituted_engine_receipt_digest_is_refused(self):
        result = self.alter_evidence(lambda value: value.update(process_sha256="0" * 64))
        self.assertEqual(result["status"], "failed")
        self.assertIn("input digest mismatch", result["error"])

    def test_substituted_consumed_source_digest_is_refused(self):
        result = self.alter_evidence(lambda value: value["consumed_source_sha256"].update(main_sha256="0" * 64))
        self.assertEqual(result["status"], "failed")
        self.assertIn("consumed source digest mismatch", result["error"])

    def test_substituted_verifier_digest_is_refused(self):
        result = self.alter_evidence(lambda value: value.update(verifier_sha256="0" * 64))
        self.assertEqual(result["status"], "failed")
        self.assertIn("verifier digest mismatch", result["error"])

    def test_source_mismatch_prevents_verifier_execution(self):
        self.source_bytes["godot/scripts/main.gd"] = b"different canonical source\n"
        with mock.patch.object(subject.subprocess, "run") as execute:
            result = subject.verify_case_evidence(self.case, self.record, self.output, self.source, self.contract)
        execute.assert_not_called()
        self.assertEqual(result["status"], "failed")
        self.assertIn("differs from its source commit", result["error"])

    def test_original_log_mutation_during_verification_fails(self):
        def changed(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            path = Path(command[command.index("--log") + 1])
            path.write_bytes(path.read_bytes() + b"changed\n")
            return result
        result = self.verify(changed)
        self.assertEqual(result["status"], "failed")
        self.assertIn("original input changed", result["error"])

    def test_source_mutation_during_verification_fails(self):
        def changed(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            (self.root / "godot/scripts/main.gd").write_bytes(b"changed during readback\n")
            return result
        result = self.verify(changed)
        self.assertEqual(result["status"], "failed")
        self.assertIn("source input changed", result["error"])

    def test_verifier_mutation_during_verification_fails(self):
        def changed(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            (self.root / self.contract.verifier).write_bytes(b"changed during readback\n")
            return result
        result = self.verify(changed)
        self.assertEqual(result["status"], "failed")
        self.assertIn("verifier changed", result["error"])

    def test_existing_readback_is_never_overwritten(self):
        folder = self.output / (self.case.name + "-readback")
        folder.mkdir()
        receipt = folder / "engine-process.json"
        receipt.write_bytes(b"retained original attempt\n")
        result = self.verify()
        self.assertEqual(result["status"], "failed")
        self.assertEqual(receipt.read_bytes(), b"retained original attempt\n")

    def test_identity_checks_share_the_overall_fifteen_second_budget(self):
        with mock.patch.object(subject.time, "perf_counter", side_effect=[0, 16, 16]), \
             mock.patch.object(subject.subprocess, "run") as execute:
            result = subject.verify_case_evidence(self.case, self.record, self.output, self.source, self.contract)
        execute.assert_not_called()
        self.assertEqual(result["status"], "failed")
        self.assertIn("15-second bound", result["error"])

    def test_success_after_overall_deadline_is_failed(self):
        now = [0.0]
        def late(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            now[0] = 16.0
            return result
        with mock.patch.object(subject.time, "perf_counter", side_effect=lambda: now[0]):
            result = self.verify(late)
        self.assertEqual(result["status"], "failed")
        self.assertIn("exceeded its 15-second bound", result["error"])

    def test_parent_does_not_promote_zero_exit_after_failed_readback(self):
        with mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", "print('engine control')"]), \
             mock.patch.object(subject, "verify_case_evidence", return_value={"status": "failed", "error": "controlled refusal"}), \
             redirect_stdout(io.StringIO()):
            record, failed = subject.run_case(sys.executable, self.case, self.output, "case")
        self.assertTrue(failed)
        self.assertEqual(record["status"], "failed")
        self.assertEqual(record["returncode"], 0)
        self.assertEqual(record["independent_evidence"]["error"], "controlled refusal")


class ReadbackRegistrationTests(unittest.TestCase):
    def test_exact_five_input011_cases_require_readback(self):
        for rig in subject.READBACK_RIGS:
            self.assertIs(subject.case_readback_contract(fake("test_play_input011_" + rig, 5)), subject.INPUT011_READBACK)

    def test_legacy_input011_case_keeps_its_own_ordinary_contract(self):
        self.assertIsNone(subject.case_readback_contract(fake("test_play_input011_legacy_pause", 5)))

    def test_life010_entry_points_remain_registered(self):
        for rig in subject.READBACK_RIGS:
            self.assertIs(subject.case_readback_contract(fake("test_play_life010_" + rig, 5)), subject.LIFE010_READBACK)

    def test_windows_custody_includes_both_current_verifiers(self):
        import run_windows_godot_regressions as windows
        self.assertIn(subject.LIFE010_READBACK.verifier, windows.INPUT_SCOPES)
        self.assertIn(subject.INPUT011_READBACK.verifier, windows.INPUT_SCOPES)


if __name__ == "__main__":
    unittest.main()
