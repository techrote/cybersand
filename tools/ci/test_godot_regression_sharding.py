#!/usr/bin/env python3
"""Unit tests for deterministic Godot regression shard planning."""

from collections import Counter
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import socket
import sys
import tempfile
import time
import unittest
from urllib.parse import urlsplit
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_godot_regressions as subject
import _architecture_campaign_context as context
import godot_job_plan
import run_windows_godot_regressions as windows


def fake(name: str, weight: float) -> subject.Case:
    return subject.Case(name, ("--script", name + ".gd"), 180, weight)


def art_durability_output() -> str:
    """Synthetic classifier control; never a replacement Godot qualification."""
    prefix = "ART_HISTORY_DURABILITY_CHECK "
    lines = [prefix + f"controlled assertion {index} true" for index in range(339)]
    lines += [
        "ERROR: ConfigFile parse error at user://art-provider.cfg:0: Unexpected EOF while parsing simple tag.",
        "   at: _parse (core/io/config_file.cpp:293)",
        "   GDScript backtrace (most recent call first):",
        "       [0] read_history_session (res://scripts/art_batch_panel.gd:908)",
        "       [4] unknown_profile_outage (res://tests/test_art_history_durability.gd:323)",
        prefix + "unknown corrupt profile cannot fabricate a source association true",
        prefix + "unknown corrupt profile reports actionable persistence failure true",
        "ERROR: Parse JSON failed. Error at line 0: Expected 'true', 'false', or 'null', got 'not'",
        "   at: parse_string (core/io/json.cpp:629)",
        "   GDScript backtrace (most recent call first):",
        "       [0] _read_pending_history_receipts (res://scripts/art_batch_panel.gd:1141)",
        "       [3] invalid_journal (res://tests/test_art_history_durability.gd:410)",
        prefix + "invalid malformed journal fails closed before writing valid receipts true",
        prefix + "invalid malformed preserves exact original archive bytes true",
        prefix + "valid journal recovers after malformed obstruction removed true",
        prefix + "all thirteen adversarial scenario families executed true",
        "ART_HISTORY_DURABILITY_RESULT " + json.dumps({"case": "suite", "checks": 345, "failures": [],
            "godot": "4.7-stable (official)", "os": "Windows", "native_sha256": "1" * 64,
            "test_sha256": "6659b017334d87f3f63c001caa402e08c6be24bdbb27579875a7d1a3aeb75a7a"}),
    ]
    return "\n".join(lines) + "\n"


class ArtDurabilityDiagnosticTests(unittest.TestCase):
    def test_exact_complete_negative_fixture_is_recognized(self):
        for newline in ("\n", "\r\n"):
            with self.subTest(newline=repr(newline)):
                self.assertFalse(subject.case_diagnostic_error("test_art_history_durability",
                    art_durability_output().replace("\n", newline), 0))

    def test_ordinary_cases_keep_original_error_semantics(self):
        for name in ("fixture", "test_art_traffic_panel_safety", "test_art_history_receipt_identity", "import"):
            for output in ("", "12 assertions passed", "ERROR: failure", "SCRIPT ERROR: failure", art_durability_output()):
                with self.subTest(name=name, output=output[:50]):
                    self.assertEqual(subject.case_diagnostic_error(name, output, 0),
                                     "SCRIPT ERROR:" in output or "ERROR:" in output)

    def test_registered_case_refuses_missing_duplicate_and_unexpected_diagnostics(self):
        good = art_durability_output()
        errors = [line for line in good.splitlines() if line.startswith("ERROR:")]
        controls = {
            "missing-all-errors": "\n".join(line for line in good.splitlines() if not line.startswith("ERROR:")),
            "unrelated-error": "ERROR: unexpected native failure\n" + good,
            "script-error": "SCRIPT ERROR: actual exception\n" + good,
            "script-parse-error": "SCRIPT ERROR: Parse Error: unexpected token\n" + good,
            "native-loader-error": "ERROR: GDExtension library could not be loaded\n" + good,
            "skipped-case": "SKIP: unavailable native runtime\n" + good,
            "shutdown-error": good + "ERROR: shutdown access violation\n",
            "nonterminal-footer": good + "unexpected activity after completion\n",
            "wrong-native-producer": good.replace("_parse (core/io/config_file.cpp:293)", "_parse (unrelated.cpp:293)"),
            "wrong-profile-producer": good.replace("read_history_session (", "unrelated_session ("),
            "wrong-json-producer": good.replace("_read_pending_history_receipts (", "unrelated_parser ("),
            "wrong-profile-fixture": good.replace("unknown_profile_outage (", "unrelated_profile_fixture ("),
            "wrong-journal-fixture": good.replace("invalid_journal (", "unrelated_journal_fixture ("),
            "missing-refusal-witness": good.replace("unknown corrupt profile reports actionable persistence failure true", "unrelated assertion true"),
            "missing-recovery-witness": good.replace("valid journal recovers after malformed obstruction removed true", "unrelated recovery true"),
            "missing-family-completion": good.replace("all thirteen adversarial scenario families executed true", "other completion true"),
            "false-assertion": good.replace("controlled assertion 1 true", "controlled assertion 1 false"),
            "missing-assertion": good.replace("ART_HISTORY_DURABILITY_CHECK controlled assertion 1 true\n", ""),
            "extra-assertion": "ART_HISTORY_DURABILITY_CHECK extra true\n" + good,
        }
        for index, error in enumerate(errors):
            controls[f"missing-error-{index}"] = good.replace(error + "\n", "")
            controls[f"duplicate-error-{index}"] = good.replace(error + "\n", error + "\n" + error + "\n")
            controls[f"altered-error-{index}"] = good.replace(error, error + " unexpected detail")
        for name, output in controls.items():
            with self.subTest(name=name):
                self.assertTrue(subject.case_diagnostic_error("test_art_history_durability", output, 0))

    def test_registered_case_requires_exact_successful_terminal_receipt(self):
        good = art_durability_output()
        marker = "ART_HISTORY_DURABILITY_RESULT "
        prefix, raw = good.rsplit(marker, 1)
        for key, value in (("case", "restart-recover"), ("checks", 344), ("checks", 346), ("checks", True),
                           ("failures", ["failure"]), ("failures", 0), ("test_sha256", "0" * 64),
                           ("passed", False), ("godot", "4.6"), ("os", "unknown"), ("native_sha256", "missing")):
            result = json.loads(raw); result[key] = value
            with self.subTest(key=key, value=value):
                self.assertTrue(subject.case_diagnostic_error("test_art_history_durability", prefix + marker + json.dumps(result), 0))
        for output in (prefix, prefix + marker + "{", good + marker + raw):
            with self.subTest(output=output[-120:]):
                self.assertTrue(subject.case_diagnostic_error("test_art_history_durability", output, 0))
        for returncode in (1, 7, -9, 3221225477, None, False):
            with self.subTest(returncode=returncode):
                self.assertTrue(subject.case_diagnostic_error("test_art_history_durability", good, returncode))

    def test_actual_child_process_uses_narrow_classification_and_keeps_original_log(self):
        for code in (0, 7):
            with self.subTest(code=code), tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
                output = Path(directory)
                original = art_durability_output()
                command = [sys.executable, "-c", "import sys; sys.stdout.write(" + repr(original) + "); sys.exit(" + str(code) + ")"]
                case = subject.Case("test_art_history_durability", ("--script", "res://tests/test_art_history_durability.gd"), 5, 1)
                with mock.patch.object(subject, "case_command", return_value=command):
                    record, failed = subject.run_case("unused", case, output, "case")
                self.assertEqual(record["returncode"], code)
                self.assertEqual(failed, code != 0)
                self.assertEqual(record["status"], "passed" if code == 0 else "failed")
                self.assertEqual((output / record["log"]).read_text(), original)


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

    def test_equal_expected_work_is_not_distorted_by_different_watchdogs(self):
        cases = [subject.Case("long_ceiling", (), 3940, 30),
                 subject.Case("normal_ceiling", (), 1200, 30), fake("short_a", 10), fake("short_b", 10)]
        _, weights = subject.build_shard_plan(cases, 2)
        self.assertEqual(weights, [40, 40])


class ResultTests(unittest.TestCase):
    def test_aggregate_deadline_persists_exact_incomplete_inventory_without_shortening_child(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            root = Path(directory)
            runtime, rapier = root / "runtime.so", root / "rapier.so"
            runtime.write_bytes(b"runtime")
            rapier.write_bytes(b"rapier")
            output = root / "results"
            cases = [subject.Case("slow", (), 3940, 100), fake("remaining", 5)]
            budget = mock.Mock()
            budget.metadata.return_value = {"execution_seconds": 6000}
            budget.admission.side_effect = [
                {"admitted": True}, {"admitted": True},
                {"admitted": False, "remaining_seconds": 100, "required_seconds": 1620},
            ]
            executed = []

            def run_case(_godot, case, output, role):
                # The complete assigned inventory already exists before import.
                initial = json.loads((output / "timings.json").read_text())
                self.assertEqual(initial["assigned_cases"], ["slow", "remaining"])
                self.assertFalse(initial["completed"])
                executed.append((case.name, case.timeout))
                return {"name": case.name, "role": role, "status": "passed"}, False

            with (
                mock.patch.object(subject, "ROOT", root),
                mock.patch.object(subject, "runtime_paths", return_value=(runtime, rapier)),
                mock.patch.object(subject, "discover_cases", return_value=cases),
                mock.patch.object(subject, "run_case", side_effect=run_case),
                mock.patch.object(subject, "tested_inputs", return_value={}),
                mock.patch.object(subject.scheduling, "ExecutionBudget", return_value=budget),
                mock.patch.object(subject.subprocess, "check_output", side_effect=["a" * 40, "Godot", "b" * 40]),
                mock.patch.object(sys, "argv", ["runner", "--godot", "unused", "--output", str(output), "--keep-going"]),
            ):
                status = subject.main()
            report = json.loads((output / "timings.json").read_text())
        self.assertEqual(status, 1)
        self.assertEqual(executed, [("import", 1200), ("slow", 3940)])
        self.assertEqual(report["incomplete_cases"], ["remaining"])
        self.assertEqual(report["incomplete_reason"], "aggregate_execution_budget_exhausted")
        self.assertFalse(report["completed"])
        self.assertEqual(report["status"], "failed")

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

    def test_local_close_gets_real_fixture_and_always_retires_listener(self):
        program = """
import json, os, urllib.request, urllib.error
endpoint = os.environ['WB_ART_CLOSE_ENDPOINT']
print(json.dumps({'endpoint':endpoint}), flush=True)
for model, expected in [('fixture-valid',200), ('fixture-invalid',404)]:
    request = urllib.request.Request(endpoint + '/chat/completions',
        data=json.dumps({'model':model}).encode(),
        headers={'Content-Type':'application/json'})
    try:
        response = urllib.request.urlopen(request, timeout=2)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        assert response.status == expected
        body = json.loads(response.read())
        assert ('choices' in body) == (expected == 200)
"""
        for exit_code in (0, 7):
            with self.subTest(exit_code=exit_code), tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
                command = [sys.executable, "-c", program + f"\nraise SystemExit({exit_code})\n"]
                output = Path(directory)
                with mock.patch.object(subject, "case_command", return_value=command):
                    result, failed = subject.run_case("unused", fake("test_art_local_close", 1), output, "case",
                        env={**os.environ, "WB_ART_CLOSE_ENDPOINT":"https://untrusted.invalid/v1"})
                self.assertEqual(failed, exit_code != 0)
                self.assertEqual(result["returncode"], exit_code)
                self.assertEqual(result["status"], "passed" if exit_code == 0 else "failed")
                endpoint = json.loads((output / "test_art_local_close.log").read_text().splitlines()[0])["endpoint"]
                parsed = urlsplit(endpoint)
                self.assertEqual(parsed.hostname, "127.0.0.1")
                with self.assertRaises(OSError):
                    socket.create_connection((parsed.hostname, parsed.port), timeout=0.2)

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
                mock.patch.object(subject.execution_telemetry, "source_identity", return_value={"commit":"a" * 40, "tree":"b" * 40}),
                mock.patch.object(subject, "discover_cases", return_value=cases),
                mock.patch.object(subject, "case_command", side_effect=child_command),
                mock.patch.object(subject, "tested_inputs", return_value={}),
                mock.patch.object(subject.subprocess, "check_output", side_effect=["a" * 40, "fixture-godot", "b" * 40]),
                mock.patch.object(sys, "argv", ["runner", "--godot", "fixture-godot", "--output", str(output), "--keep-going"]),
            ):
                status = subject.main()
            result = json.loads((output / "timings.json").read_text(encoding="utf-8"))
        self.assertEqual(status, 1)
        self.assertEqual(result["status"], "failed")
        self.assertTrue(result["completed"])
        self.assertEqual([case["name"] for case in result["results"]], ["import", "fails", "runs_after_failure"])
        self.assertEqual([case["status"] for case in result["results"]], ["passed", "failed", "passed"])

    def test_authoring_source_drift_cannot_pass_after_all_cases_succeed(self):
        relative = "tools/material_catalogue/lab.py"
        before = {relative: "c" * 64}
        for after in (before, {relative: "d" * 64}):
            changed = after != before
            with self.subTest(changed=changed), tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
                root = Path(directory)
                native, rapier = root / "native.so", root / "rapier.so"
                native.write_bytes(b"native-fixture")
                rapier.write_bytes(b"rapier-fixture")
                output = root / "results"

                def run_case(_godot, case, _output, role):
                    return {"name": case.name, "role": role, "status": "passed"}, False

                with (
                    mock.patch.object(subject, "ROOT", root),
                    mock.patch.object(subject, "runtime_paths", return_value=(native, rapier)),
                    mock.patch.object(subject, "discover_cases", return_value=[fake("authoring", 1)]),
                    mock.patch.object(subject, "run_case", side_effect=run_case),
                    mock.patch.object(subject, "tested_inputs", side_effect=[before, after]),
                    mock.patch.object(subject.subprocess, "check_output", side_effect=["a" * 40, "Godot", "b" * 40]),
                    mock.patch.object(sys, "argv", ["runner", "--godot", "unused", "--output", str(output)]),
                ):
                    status = subject.main()
                report = json.loads((output / "timings.json").read_text())
                self.assertEqual(status, int(changed))
                self.assertEqual(report["identity"]["tested_inputs"], before)
                self.assertEqual(report["source_drift"], [relative] if changed else [])
                self.assertEqual(report["completed"], not changed)
                self.assertEqual(len(report["results"]), 2)
                if changed:
                    self.assertIn("source inputs changed", report["error"])


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

        source_identity = mock.patch.object(subject, "readback_source_identity",
            side_effect=lambda source, relative, label, timeout=None: {
                "source_revision": source, "path": relative,
                "actual_sha256": subject.sha256(subject.ROOT / relative)})
        source_identity.start()
        self.addCleanup(source_identity.stop)

    def successful_verifier(self, command, **kwargs):
        self.assertIn("--self-test", command)
        self.assertEqual(command[command.index("--source") + 1], self.source)
        self.assertGreater(kwargs["timeout"], 0)
        self.assertLessEqual(kwargs["timeout"], subject.execution_policy.watchdog_seconds("operation_seconds"))
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
                                        cwd=root, timeout=subject.execution_policy.watchdog_seconds("operation_seconds"))
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
        self.assertLessEqual(timeout, subject.execution_policy.watchdog_seconds("operation_seconds"))
        source, path = command[2].split(":", 1)
        self.assertEqual(source, self.source)
        return self.source_bytes[path]

    def successful_verifier(self, command, **kwargs):
        self.assertIn("--self-test", command)
        self.assertEqual(command[command.index("--rig") + 1], "acrobat")
        self.assertEqual(command[command.index("--source") + 1], self.source)
        self.assertGreater(kwargs["timeout"], 0)
        self.assertLessEqual(kwargs["timeout"], subject.execution_policy.watchdog_seconds("operation_seconds"))
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
        self.assertEqual(len(result["source_input_identity"]), 9)
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

    def test_identity_checks_share_the_overall_operation_budget(self):
        with mock.patch.object(subject.time, "perf_counter", side_effect=[0, 301, 301]), \
             mock.patch.object(subject.subprocess, "run") as execute:
            result = subject.verify_case_evidence(self.case, self.record, self.output, self.source, self.contract)
        execute.assert_not_called()
        self.assertEqual(result["status"], "failed")
        self.assertIn("execution allowance", result["error"])

    def test_success_after_overall_deadline_is_failed(self):
        now = [0.0]
        def late(command, **kwargs):
            result = self.successful_verifier(command, **kwargs)
            now[0] = 301.0
            return result
        with mock.patch.object(subject.time, "perf_counter", side_effect=lambda: now[0]):
            result = self.verify(late)
        self.assertEqual(result["status"], "failed")
        self.assertIn("exceeded its execution allowance", result["error"])

    def test_parent_does_not_promote_zero_exit_after_failed_readback(self):
        with mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", "print('engine control')"]), \
             mock.patch.object(subject, "verify_case_evidence", return_value={"status": "failed", "error": "controlled refusal"}), \
             mock.patch.object(subject.execution_telemetry, "source_identity", return_value={"commit":self.source}), \
             redirect_stdout(io.StringIO()):
            record, failed = subject.run_case(sys.executable, self.case, self.output, "case")
        self.assertTrue(failed)
        self.assertEqual(record["status"], "failed")
        self.assertEqual(record["returncode"], 0)
        self.assertEqual(record["independent_evidence"]["error"], "controlled refusal")


class Life011ReadbackTests(unittest.TestCase):
    """Contract insertion controls only; the real solver trace has its own verifier."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.contract = subject.LIFE011_READBACK
        self.case = fake("test_play_life011_acrobat", 5)
        self.source = "2" * 40
        self.raw = b'{"scope":"synthetic parent contract control only"}\n'
        self.source_bytes = {
            path.format(rig="acrobat"): (path + "\n").encode()
            for path in (self.contract.verifier, *self.contract.source_inputs)}
        for name, data in self.source_bytes.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.queried = []
        self.attempt = 0
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
        self.assertLessEqual(timeout, subject.execution_policy.watchdog_seconds("operation_seconds"))
        source, path = command[2].split(":", 1)
        self.assertEqual(source, self.source)
        self.queried.append(path)
        return self.source_bytes[path]

    def successful_verifier(self, command, **kwargs):
        self.assertIn("--self-test", command)
        self.assertEqual(command[command.index("--source") + 1], self.source)
        self.assertEqual(command[command.index("--platform") + 1],
                         "Windows" if sys.platform == "win32" else "Linux")
        self.assertGreater(kwargs["timeout"], 0)
        self.assertLessEqual(kwargs["timeout"], subject.execution_policy.watchdog_seconds("operation_seconds"))
        result = dict(self.contract.required_values, source_revision=self.source, rig="acrobat")
        result["adverse_controls"] = [{"name": str(i), "rejected_for": "controlled"} for i in range(37)]
        for field, argument in (("process_sha256", "--process-json"), ("log_sha256", "--log"),
                                ("result_sha256", "--result")):
            result[field] = subject.sha256(Path(command[command.index(argument) + 1]))
        subject.write_json(Path(command[command.index("--output") + 1]), result)
        return subject.subprocess.CompletedProcess(command, 0)

    def verify(self, execute=None):
        self.output = self.root / ("attempt-" + str(self.attempt))
        self.attempt += 1
        self.output.mkdir()
        self.record = {"name": self.case.name, "status": "passed", "returncode": 0,
                       "log": self.case.name + ".log", "seconds": 1.0, "timeout_seconds": 180}
        (self.output / self.record["log"]).write_text("retained engine control\n", encoding="utf-8")
        raw_dir = self.output / (self.case.name + "-artifacts")
        raw_dir.mkdir()
        (raw_dir / "acrobat-life011.json").write_bytes(self.raw)
        with mock.patch.object(subject.subprocess, "run", side_effect=execute or self.successful_verifier):
            return subject.verify_case_evidence(self.case, self.record, self.output, self.source, self.contract)

    def alter_evidence(self, change):
        def altered(command, **kwargs):
            completed = self.successful_verifier(command, **kwargs)
            path = Path(command[command.index("--output") + 1])
            value = json.loads(path.read_text())
            change(value)
            subject.write_json(path, value)
            return completed
        return self.verify(altered)

    def test_external_result_and_all_policy_and_fixture_dependencies_are_bound(self):
        result = self.verify()
        self.assertEqual(result["status"], "passed")
        self.assertCountEqual(self.queried, self.source_bytes)
        self.assertEqual(len(result["source_input_identity"]), 13)
        self.assertEqual(json.loads((self.output / result["receipt"]).read_text()), self.record)
        self.assertEqual(result["input_sha256"]["result"], subject.hashlib.sha256(self.raw).hexdigest())
        self.assertEqual(subject.sha256(self.output / result["output"]), result["output_sha256"])
        self.assertEqual(subject.sha256(self.output / result["verifier_log"]), result["verifier_log_sha256"])

    def test_windows_platform_is_explicit(self):
        with mock.patch.object(subject.sys, "platform", "win32"):
            self.assertEqual(self.verify()["status"], "passed")

    def test_incomplete_policy_physics_refusal_or_retirement_inventory_is_refused(self):
        for field, expected in self.contract.required_values:
            if type(expected) is not int or expected == 0:
                continue
            with self.subTest(field=field):
                result = self.alter_evidence(lambda value: value.update({field: expected - 1}))
                self.assertEqual(result["status"], "failed")
                self.assertIn("result/control inventory", result["error"])

    def test_missing_or_duplicate_adverse_control_is_refused(self):
        for mutate in (lambda value: value["adverse_controls"].pop(),
                       lambda value: value["adverse_controls"].__setitem__(1, value["adverse_controls"][0])):
            with self.subTest(mutation=mutate):
                result = self.alter_evidence(mutate)
                self.assertEqual(result["status"], "failed")
                self.assertIn("result/control inventory", result["error"])

    def test_wrong_source_or_rig_is_refused(self):
        for field, value in (("source_revision", "3" * 40), ("rig", "jetbarrel")):
            with self.subTest(field=field):
                self.assertEqual(self.alter_evidence(lambda item: item.update({field: value}))["status"], "failed")

    def test_policy_dependency_substitution_is_refused_before_execution(self):
        for name in ("tools/lcb/policy_contract.py", "tools/lcb/inertial_parameter_contract.py",
                     "docs/reference/liquid-solver-capability-matrix.json"):
            with self.subTest(path=name):
                (self.root / name).write_bytes(b"substituted policy input\n")
                execute = mock.Mock(side_effect=self.successful_verifier)
                result = self.verify(execute)
                execute.assert_not_called()
                self.assertEqual(result["status"], "failed")
                self.assertIn("differs from its source commit", result["error"])
                (self.root / name).write_bytes(self.source_bytes[name])

    def test_policy_dependency_changes_during_readback_are_refused(self):
        for name in ("tools/lcb/policy_contract.py", "tools/lcb/inertial_parameter_contract.py",
                     "docs/reference/liquid-solver-capability-matrix.json"):
            with self.subTest(path=name):
                def changed(command, **kwargs):
                    completed = self.successful_verifier(command, **kwargs)
                    (self.root / name).write_bytes(b"changed after reduction\n")
                    return completed
                result = self.verify(changed)
                self.assertEqual(result["status"], "failed")
                self.assertIn("source input changed", result["error"])
                (self.root / name).write_bytes(self.source_bytes[name])

    def test_external_result_mutation_is_refused(self):
        def changed(command, **kwargs):
            completed = self.successful_verifier(command, **kwargs)
            Path(command[command.index("--result") + 1]).write_bytes(b"changed original\n")
            return completed
        result = self.verify(changed)
        self.assertEqual(result["status"], "failed")
        self.assertIn("original input changed", result["error"])

    def test_all_dependencies_share_one_operation_budget(self):
        now = [0.0]
        def slow_identity(command, **kwargs):
            data = self.canonical_source(command, **kwargs)
            now[0] += 40.0
            return data
        execute = mock.Mock(side_effect=self.successful_verifier)
        with mock.patch.object(subject.time, "perf_counter", side_effect=lambda: now[0]), \
             mock.patch.object(subject.subprocess, "check_output", side_effect=slow_identity):
            result = self.verify(execute)
        execute.assert_not_called()
        self.assertEqual(result["status"], "failed")
        self.assertIn("execution allowance", result["error"])


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

    def test_exact_five_life011_cases_require_readback(self):
        for rig in subject.READBACK_RIGS:
            self.assertIs(subject.case_readback_contract(fake("test_play_life011_" + rig, 5)), subject.LIFE011_READBACK)
        self.assertIsNone(subject.case_readback_contract(fake("test_play_life011_unknown", 5)))

    def test_windows_custody_includes_life011_policy_dependencies(self):
        import run_windows_godot_regressions as windows
        for path in (subject.LIFE011_READBACK.verifier, "tools/lcb/policy_contract.py",
                     "tools/lcb/inertial_parameter_contract.py",
                     "docs/reference/liquid-solver-capability-matrix.json"):
            self.assertIn(path, windows.INPUT_SCOPES)
        self.assertIn("native/include", windows.INPUT_SCOPES)


def registered_cases():
    names = {name for _component, members, _paths in context.COMPONENTS for name in members}
    return [case for case in subject.discover_cases() if case.name in names]


class ArchitectureContextTests(unittest.TestCase):
    def test_legacy_graphical_driver_flags_keep_the_exact_original_windows_command(self):
        flags = ("--rendering-driver", "opengl3_angle", "--script", "res://tests/test_water_presentation_render.gd")
        case = subject.Case("water-render", flags, 1200, 0, True)
        command = subject.case_command("godot", case, "win32")
        self.assertEqual(command, ["godot", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                                   "--path", str(subject.ROOT / "godot"), *flags])
        self.assertEqual(command.count("--rendering-driver"), 1)
        for name in context.GRAPHICAL_CASES:
            architecture = subject.Case(name, ("--script", "res://tests/" + name + ".gd"), 1200, 0, True)
            command = subject.case_command("godot", architecture, "win32")
            self.assertEqual(command.count("--rendering-driver"), 1)
            self.assertEqual(command[command.index("--rendering-driver") + 1], "opengl3_angle")

    def test_registered_graphics_use_the_graphical_watchdog_without_shortening_complex_cases(self):
        original = {case.name: case for case in subject.discover_cases()}
        policy = json.loads(json.dumps(subject.execution_policy.identity()))
        ordinary = policy["watchdogs"]["ordinary_case_seconds"]
        policy["watchdogs"]["graphical_case_seconds"] += 500
        with mock.patch.object(subject.execution_policy, "identity", return_value=policy):
            changed = {case.name: case for case in subject.discover_cases()}
        for name in context.GRAPHICAL_CASES:
            expected = (policy["watchdogs"]["graphical_case_seconds"]
                if original[name].timeout == ordinary else original[name].timeout)
            self.assertEqual(changed[name].timeout, expected)
            self.assertTrue(changed[name].requires_display)
        self.assertEqual(changed["test_architecture_gameplay"].timeout, original["test_architecture_gameplay"].timeout)
        self.assertGreater(changed["test_architecture_gameplay"].timeout, policy["watchdogs"]["graphical_case_seconds"])

    def test_complete_hosted_plans_keep_components_whole_ordered_and_every_case_once(self):
        discovered = subject.discover_cases()
        for platform in ("linux", "windows"):
            cases = [case for case in discovered if platform == "linux" or context.windows_applicable(case)]
            plan = godot_job_plan.plan(cases, platform=platform)
            shards, totals = subject.build_shard_plan(cases, plan["shard_count"])
            self.assertEqual(Counter(c.name for shard in shards for c in shard), Counter(c.name for c in cases))
            self.assertEqual(totals, [sum(c.weight for c in shard) for shard in shards])
            for shard in shards:
                self.assertLessEqual(len(shard), subject.scheduling.MAX_CASES_PER_SHARD)
                # The original Case objects, flags, display bits and complete
                # watchdogs survive scheduling, rather than synthetic wrappers.
                self.assertTrue(all(any(case is original for original in cases) for case in shard))
            for _component, names, _paths in context.COMPONENTS:
                containing = [shard for shard in shards if any(c.name in names for c in shard)]
                self.assertEqual(len(containing), 1)
                self.assertEqual([c.name for c in containing[0] if c.name in names], list(names))

    def test_partial_component_and_duplicate_case_are_refused(self):
        cases = registered_cases()
        cases = [case for case in cases if case.name != "test_architecture_stage_native"]
        with self.assertRaisesRegex(RuntimeError, "Incomplete Architecture context"):
            subject.build_shard_plan(cases, 2)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, "Incomplete Architecture context"):
                context.prepare_contexts(cases, Path(directory))
        with self.assertRaisesRegex(RuntimeError, "exactly once"):
            subject.build_shard_plan([subject.Case("duplicate", (), 1200, 1)] * 2, 1)

    def test_contexts_share_only_the_registered_component_and_fabricate_no_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            # Hosted Windows may spell the tempfile root using RUNNER~1 while
            # resolve() returns its long name. Exercise an unresolved lexical
            # alias on every host as well, and compare canonical roots.
            alias = Path(directory) / "unresolved-parent"
            alias.mkdir()
            output = alias / ".."
            contexts = context.prepare_contexts(registered_cases(), output)
            for _component, names, _paths in context.COMPONENTS:
                self.assertTrue(all(contexts[name]["APPDATA"] == contexts[names[0]]["APPDATA"] for name in names))
                if _component != "batch-provider-workbench":
                    self.assertTrue(all(contexts[name] == contexts[names[0]] for name in names))
            profiles = [contexts[names[0]]["APPDATA"] for _component, names, _paths in context.COMPONENTS]
            self.assertEqual(len(profiles), len(set(profiles)))
            for overrides in contexts.values():
                for value in overrides.values():
                    self.assertTrue(Path(value).is_relative_to(output.resolve()))
                for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME"):
                    self.assertTrue(Path(overrides[name]).is_dir())
            self.assertFalse(any(path.is_file() for path in output.rglob("*")))
            manifest = Path(contexts["test_architecture_gameplay"]["ARCHITECTURE_GAMEPLAY_MANIFEST"])
            self.assertFalse(manifest.exists())
            # Even a previous empty context cannot be reused to accidentally
            # inherit an old successful manifest/profile on a later run.
            with self.assertRaises(FileExistsError):
                context.prepare_contexts(registered_cases(), output)

    def test_batch_provider_precedes_workbench_in_one_profile_with_distinct_retained_outputs(self):
        cases = registered_cases()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            contexts = context.prepare_contexts(cases, output)
            provider = contexts["test_batch_lab_provider"]
            workbench = contexts["test_batch_lab_workbench"]
            ui = contexts["test_batch_lab_ui"]
            for variable in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME"):
                self.assertEqual(provider[variable], workbench[variable])
                self.assertNotEqual(provider[variable], ui[variable])
            self.assertNotEqual(provider["BATCH_LAB_EVIDENCE_DIR"], workbench["BATCH_LAB_EVIDENCE_DIR"])
            self.assertTrue(all(Path(ctx["BATCH_LAB_EVIDENCE_DIR"]).is_relative_to(output.resolve())
                                for ctx in (provider, workbench, ui)))
            self.assertEqual(context.failed_dependencies("test_batch_lab_workbench", []), ["test_batch_lab_provider"])
            self.assertEqual(context.failed_dependencies("test_batch_lab_workbench",
                [{"name": "test_batch_lab_provider", "role": "case", "status": "passed"}]), [])

    def test_complete_environment_preserves_source_and_path_and_other_cases_keep_defaults(self):
        cases = registered_cases()
        case = next(c for c in cases if c.name == "test_architecture_stage_native")
        with tempfile.TemporaryDirectory() as directory, mock.patch.dict(os.environ, {"PATH": "retained-path", "CYBERSAND_SOURCE_REVISION": "source-id"}):
            contexts = context.prepare_contexts(cases, Path(directory))
            kwargs = subject.context_case_kwargs(case, contexts, [])
            self.assertEqual(kwargs["env"]["PATH"], "retained-path")
            self.assertEqual(kwargs["env"]["CYBERSAND_SOURCE_REVISION"], "source-id")
            self.assertEqual(kwargs["env"]["APPDATA"], contexts[case.name]["APPDATA"])
            self.assertEqual(subject.context_case_kwargs(subject.Case("unrelated", (), 1200, 1), contexts, []), {})

    def test_failed_producer_still_runs_consumers_and_cannot_qualify_partial_inputs(self):
        # Real independent child processes: a failing producer leaves a file
        # that would otherwise let its consumer exit successfully. Keep both
        # raw logs and classify the consumer's context as failed nevertheless.
        names = context.COMPONENTS[3][1]
        cases = [subject.Case(name, ("--script", name + ".gd"), 3940, 1, name.endswith("_render")) for name in names]
        programs = {
            names[0]: "import os;from pathlib import Path;p=Path(os.environ['ARCHITECTURE_HIERARCHY_DIR'])/'hierarchy-native.json';p.write_text('{}');print('producer partial input');raise SystemExit(7)",
            names[1]: "import os;from pathlib import Path;assert (Path(os.environ['ARCHITECTURE_HIERARCHY_DIR'])/'hierarchy-native.json').is_file();print('consumer actually executed')",
            names[2]: "print('graphical consumer actually executed')",
        }
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            report = {"status": "running", "completed": False, "results": [], "log_sha256": {}}
            def command(_godot, case):
                if case.name == "import":
                    return [sys.executable, "-c", "print('imported')"]
                capture = ("import os;from pathlib import Path;"
                    "a=Path(os.environ['CYBERSAND_TEST_ARTIFACT_DIR']);a.mkdir();"
                    f"(a/'case.txt').write_text({case.name!r});")
                return [sys.executable, "-c", capture + programs[case.name]]
            with mock.patch.object(subject, "case_command", side_effect=command):
                windows.execute_cases("unused", output, report, cases)
            self.assertTrue(report["completed"])
            self.assertEqual(report["status"], "failed")
            self.assertEqual([r["name"] for r in report["results"]], ["import", *names])
            self.assertEqual([r["status"] for r in report["results"]], ["passed", "failed", "failed", "failed"])
            self.assertEqual([r["timeout_seconds"] for r in report["results"]][1:], [3940] * 3)
            for row in report["results"][2:]:
                self.assertEqual(row["returncode"], 0)
                self.assertEqual(row["process_status"], "passed")
                self.assertEqual(row["failed_context_producers"], [names[0]])
                self.assertIn("actually executed", (output / row["log"]).read_text())
                self.assertEqual(row["log_sha256"], subject.sha256(output / row["log"]))
            for name in names:
                self.assertEqual((output / (name + "-artifacts") / "case.txt").read_text(), name)

    def test_graphical_discovery_windows_intake_and_matrix_agree_without_broadening_scope(self):
        cases = subject.discover_cases()
        by_name = {case.name: case for case in cases}
        self.assertTrue(all(by_name[name].requires_display for name in context.GRAPHICAL_CASES))
        self.assertFalse(context.windows_applicable(subject.Case("unrelated_render", (), 1200, 1, True)))
        expected = [case for case in cases if context.windows_applicable(case)]
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            path = Path(directory) / "plan.json"
            with mock.patch.object(sys, "argv", ["planner", "--output", str(path)]):
                self.assertEqual(godot_job_plan.main(), 0)
            plan = json.loads(path.read_text())["windows"]
        report = {}
        windows.plan_cases(report, cases, shard_count=plan["shard_count"], shard_index=0)
        self.assertEqual(report["applicable_cases"], [case.name for case in expected])
        self.assertEqual(Counter(c["name"] for s in plan["shards"] for c in s["cases"]), Counter(report["applicable_cases"]))
        self.assertEqual(set(case.name for case in expected if case.requires_display), context.GRAPHICAL_CASES)
        self.assertEqual(report["case_plan"], plan["shards"][0]["cases"])
        command = subject.case_command("godot", by_name["test_architecture_gameplay"], "win32")
        self.assertNotIn("--headless", command)
        self.assertEqual(command[command.index("--rendering-method") + 1], "gl_compatibility")
        self.assertEqual(command[command.index("--rendering-driver") + 1], "opengl3_angle")

    def test_failed_context_does_not_erase_a_consumers_original_skip_or_timeout(self):
        for program, timeout, expected in (("print('SKIP: missing input')", 5, "skipped"),
                                            ("import time;time.sleep(30)", 0.1, "timeout")):
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
                case = subject.Case("fixture", (), timeout, 1)
                with mock.patch.object(subject, "case_command", return_value=[sys.executable, "-c", program]):
                    row, failed = subject.run_case("unused", case, Path(directory), "case", failed_context_producers=("producer",))
                self.assertTrue(failed)
                self.assertEqual(row["status"], expected)
                self.assertEqual(row["process_status"], expected)
                self.assertEqual(row["failed_context_producers"], ["producer"])


if __name__ == "__main__":
    unittest.main()
