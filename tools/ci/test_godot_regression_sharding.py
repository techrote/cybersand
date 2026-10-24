#!/usr/bin/env python3
"""Unit tests for deterministic Godot regression shard planning."""

from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
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

    def test_zero_exit_with_script_error_fails(self):
        result, failed = self.run_child("print('SCRIPT ERROR: assertion failed')")
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


if __name__ == "__main__":
    unittest.main()
