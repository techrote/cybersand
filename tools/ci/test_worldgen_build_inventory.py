#!/usr/bin/env python3
"""Actual make graph and watchdog controls with compiler/test doubles only."""

from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

import check_worldgen_build_inventory as inventory
import run_timed_command as timed


class WorldgenBuildInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = inventory.check(inventory.ROOT)

    def streams(self, target="worldgen-sanitize"):
        row = self.report["families"][target]
        return row["serial"]["stdout"], row["two_jobs"]["stdout"]

    def test_both_actual_graphs_have_twelve_objects_sixteen_binaries_and_all_tests(self):
        for target, row in self.report["families"].items():
            with self.subTest(target=target):
                self.assertEqual(row["object_count"], 12)
                self.assertEqual(row["binary_count"], 16)
                self.assertEqual(len(row["compile_link_commands"]), 28)
                self.assertEqual(len(row["required_showcase_tests"]), 7)
                self.assertEqual(len(row["ordered_main_tests"]), 9)
                self.assertEqual(row["execution_count"], 16)

    def test_missing_prerequisite_is_rejected(self):
        serial, bounded = self.streams()
        lines = bounded.splitlines()
        index = next(index for index, line in enumerate(lines) if line.startswith(inventory.COMPILER))
        lines.pop(index)
        with self.assertRaisesRegex(ValueError, "Missing compilation|before object prerequisite"):
            inventory.compare(serial, "\n".join(lines), True)

    def test_omitted_test_is_rejected(self):
        serial, bounded = self.streams()
        altered = "\n".join(line for line in bounded.splitlines()
                            if line != "./build/test_generation_planes_sanitized")
        with self.assertRaisesRegex(ValueError, "Nine-main-test inventory/order"):
            inventory.compare(serial, altered, True)

    def test_reordered_tests_are_rejected(self):
        serial, bounded = self.streams()
        lines = bounded.splitlines()
        positions = [index for index, line in enumerate(lines) if line.startswith("./build/test_")]
        lines[positions[0]], lines[positions[1]] = lines[positions[1]], lines[positions[0]]
        with self.assertRaisesRegex(ValueError, "Nine-main-test inventory/order"):
            inventory.compare(serial, "\n".join(lines), True)

    def test_omitted_showcase_or_changed_sanitizer_environment_is_rejected(self):
        serial, bounded = self.streams()
        for before, after in (("\"build/test_suspended_arcology_sanitized\"", ""),
                              ("UBSAN_OPTIONS=${UBSAN_OPTIONS:-halt_on_error=1}", "")):
            with self.subTest(change=before), self.assertRaisesRegex(ValueError, "Seven-showcase"):
                inventory.compare(serial, bounded.replace(before, after), True)

    def test_dropped_sanitizer_flag_fails_even_when_both_dry_runs_match(self):
        serial, bounded = self.streams()
        serial = serial.replace(" -fsanitize=address,undefined", "")
        bounded = bounded.replace(" -fsanitize=address,undefined", "")
        with self.assertRaisesRegex(ValueError, "Compiler flag/source contract"):
            inventory.compare(serial, bounded, True)

    def test_threaded_and_plain_object_alias_is_rejected(self):
        serial, bounded = self.streams()
        bounded = bounded.replace("sanitized-threaded", "sanitized")
        with self.assertRaisesRegex(ValueError, "Compiler flag/source contract|Wrong or duplicate"):
            inventory.compare(serial, bounded, True)

    def test_normal_werror_cannot_disappear(self):
        serial, bounded = self.streams("worldgen-test")
        with self.assertRaisesRegex(ValueError, "Compiler flag/source contract"):
            inventory.compare(serial, bounded.replace(" -Werror", ""), False)

    def test_compilation_cannot_move_after_ordered_main_tests_begin(self):
        serial, bounded = self.streams()
        lines = bounded.splitlines()
        index = next(index for index, line in enumerate(lines) if line.startswith(inventory.COMPILER))
        lines.append(lines[index])
        with self.assertRaisesRegex(ValueError, "Compilation appears after ordered main tests"):
            inventory.compare(serial, "\n".join(lines), True)

    def test_unexpected_executable_is_not_ignored(self):
        serial, bounded = self.streams()
        with self.assertRaisesRegex(ValueError, "Unexpected executable"):
            inventory.compare(serial, bounded + "\n./build/unregistered-test\n", True)

    def test_unbounded_or_unrelated_request_is_refused_before_execution(self):
        for target, jobs in (("worldgen-test", 0), ("worldgen-sanitize", 64), ("tests_tsan", 2)):
            with self.subTest(target=target, jobs=jobs):
                with self.assertRaisesRegex(ValueError, "Unbounded or unrelated"):
                    inventory.dry_run(inventory.ROOT, target, jobs)

    def test_recorded_commands_are_forced_dry_runs_with_nonexistent_compiler(self):
        for row in self.report["families"].values():
            for name, jobs in (("serial", 1), ("two_jobs", 2)):
                command = row[name]["command"]
                self.assertIn("--dry-run", command)
                self.assertIn("--always-make", command)
                self.assertIn(f"-j{jobs}", command)
                self.assertIn("--output-sync=target", command)
                self.assertIn(f"CXX={inventory.COMPILER}", command)

    def test_dry_run_cannot_create_or_touch_prerequisites_with_inherited_make_flags(self):
        # Exercise the real make process on a disposable source tree. A stale
        # zero-byte output is a canary, never an acceptable compiled object.
        with tempfile.TemporaryDirectory(prefix="worldgen-inventory-") as directory:
            root = Path(directory)
            shutil.copy2(inventory.ROOT / "Makefile", root / "Makefile")
            shutil.copytree(inventory.ROOT / "native", root / "native")
            canary = root / "build/worldgen-objects/normal/generation_grammar.o"
            canary.parent.mkdir(parents=True)
            canary.write_bytes(b"")

            def state():
                return {str(path.relative_to(root)):
                        (path.stat().st_mtime_ns, hashlib.sha256(path.read_bytes()).hexdigest())
                        for path in root.rglob("*") if path.is_file()}

            before = state()
            with patch.dict(os.environ, {"MAKEFLAGS":"-t", "MFLAGS":"-t"}):
                for target in ("worldgen-test", "worldgen-sanitize"):
                    for jobs in (1, 2):
                        result = inventory.dry_run(root, target, jobs)
                        inventory.inspect_commands(result["stdout"], target.endswith("sanitize"))
            self.assertEqual(state(), before, "A dry-run created or touched a build prerequisite")

    def test_duplicate_or_missing_showcase_cannot_satisfy_the_main_tail(self):
        serial, bounded = self.streams("worldgen-test")
        marker = 'echo "Running build/test_megatruss_station"\n"build/test_megatruss_station"\n'
        for replacement in ("", marker * 2):
            with self.subTest(replacement=replacement), self.assertRaisesRegex(
                    ValueError, "Main tests start before all seven|duplicate showcase"):
                inventory.compare(serial, bounded.replace(marker, replacement), False)

    def test_showcase_must_be_linked_before_it_runs(self):
        serial, bounded = self.streams("worldgen-test")
        marker = 'echo "Running build/test_megatruss_station"\n"build/test_megatruss_station"\n'
        with self.assertRaisesRegex(ValueError, "Showcase execution precedes its binary"):
            inventory.compare(serial, marker + bounded.replace(marker, ""), False)


@unittest.skipUnless(sys.platform.startswith("linux"), "Native Make/watchdog boundary is Linux-only")
class WorldgenExecutionGraphTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="worldgen-execution-control-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copy2(inventory.ROOT / "Makefile", self.root / "Makefile")
        shutil.copytree(inventory.ROOT / "native", self.root / "native")
        self.events = self.root / "events.jsonl"
        self.controls = self.root / "control.json"
        self.compiler = self.root / "compiler-double.py"
        # Real Make executes this double for every unchanged compiler argv. Its
        # linked executables exercise scheduling and failure propagation only,
        # never substitute for real native/scientific qualification.
        self.compiler.write_text("#!" + sys.executable + "\n" + r'''
import json, os, sys, time
from pathlib import Path
controls = json.loads(Path("control.json").read_text())
compiling = "-o" in sys.argv
name = sys.argv[-1] if compiling else sys.argv[0]
name = str(Path(name).relative_to(Path.cwd())) if Path(name).is_absolute() else str(Path(name))
kind = "compile" if compiling else "test"
def event(phase):
    row = {"phase":phase, "kind":kind, "name":name, "pid":os.getpid(),
           "time":time.monotonic(), "args":sys.argv[1:],
           "asan":os.environ.get("ASAN_OPTIONS"), "ubsan":os.environ.get("UBSAN_OPTIONS")}
    descriptor = os.open("events.jsonl", os.O_APPEND | os.O_CREAT | os.O_WRONLY, 0o600)
    try:
        os.write(descriptor, (json.dumps(row) + "\n").encode())
    finally:
        os.close(descriptor)
event("start")
if compiling:
    output = Path(name)
    output.parent.mkdir(parents=True, exist_ok=True)
    time.sleep(.005)
    if controls.get("partial") == name:
        output.write_text("incomplete compiler output")
        event("failed")
        raise SystemExit(27)
    if controls.get("missing") != name:
        output.write_bytes(b"object-double" if output.suffix == ".o" else Path(__file__).read_bytes())
        output.chmod(0o755)
else:
    print("CONTROL-BEGIN " + name, flush=True)
    print("CONTROL-ERR " + name, file=sys.stderr, flush=True)
    if controls.get("fail") == name:
        if controls.get("hang"):
            deadline = time.monotonic() + 5
            while not any(row["name"] == controls["hang"] and row["phase"] == "start"
                          for row in map(json.loads, Path("events.jsonl").read_text().splitlines())):
                if time.monotonic() > deadline:
                    raise SystemExit("hanging peer was never scheduled")
                time.sleep(.01)
        event("failed")
        raise SystemExit(29)
    time.sleep(60 if controls.get("hang") == name else .08)
    print("CONTROL-END " + name, flush=True)
event("end")
''')
        self.compiler.chmod(0o755)
        self.reset()

    def reset(self, **controls):
        self.events.unlink(missing_ok=True)
        self.controls.write_text(json.dumps(controls))

    def command(self, sanitized=False):
        return ["make", "--no-print-directory", "-j2", "--output-sync=target",
                "CXX=" + str(self.compiler), "worldgen-sanitize" if sanitized else "worldgen-test"]

    def environment(self, **extra):
        env = os.environ.copy()
        for key in ("MAKEFLAGS", "MFLAGS", "ASAN_OPTIONS", "UBSAN_OPTIONS"):
            env.pop(key, None)
        return env | extra

    def execute(self, sanitized=False, **environment):
        result = subprocess.run(self.command(sanitized), cwd=self.root, env=self.environment(**environment),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
        return result, self.rows()

    def rows(self):
        return [json.loads(line) for line in self.events.read_text().splitlines()] if self.events.exists() else []

    def assert_contract(self, result, rows, sanitized=False, warm=False):
        self.assertEqual(result.returncode, 0, result.stdout)
        compile_rows = [row for row in rows if row["kind"] == "compile" and row["phase"] == "start"]
        expected = inventory.expected_commands(sanitized)
        self.assertEqual({row["name"]:[inventory.COMPILER, *row["args"]] for row in compile_rows},
                         {} if warm else expected)
        self.assertEqual(len(compile_rows), 0 if warm else 28)
        starts = [row["name"] for row in rows if row["kind"] == "test" and row["phase"] == "start"]
        suffix = "_sanitized" if sanitized else ""
        showcases = [f"build/test_{name}{suffix}" for name in inventory.SHOWCASES]
        main = [f"build/test_{name}{suffix}" for name in inventory.TESTS]
        self.assertCountEqual(starts, showcases + main)
        self.assertEqual(starts[-9:], main)
        self.assertEqual([row["name"] for row in rows if row["phase"] == "end" and row["kind"] == "test"][-9:], main)
        first_main = next(row["time"] for row in rows if row["kind"] == "test" and
                          row["name"] == main[0] and row["phase"] == "start")
        self.assertTrue(all(row["time"] < first_main for row in rows
                            if row["name"] in showcases and row["phase"] == "end"))
        active, active_showcases, peak, peak_showcases = set(), set(), 0, 0
        for row in rows:
            if row["phase"] == "start":
                active.add(row["pid"])
                if row["kind"] == "test" and row["name"] in showcases:
                    active_showcases.add(row["pid"])
                peak, peak_showcases = max(peak, len(active)), max(peak_showcases, len(active_showcases))
            else:
                active.remove(row["pid"])
                active_showcases.discard(row["pid"])
        self.assertEqual((active, peak, peak_showcases), (set(), 2, 2))
        output = [line for line in result.stdout.splitlines() if line.startswith("CONTROL-")]
        self.assertEqual(len(output), 48)
        for index in range(0, len(output), 3):
            name = output[index].split(" ", 1)[1]
            self.assertEqual(output[index:index + 3], [f"CONTROL-{part} {name}" for part in ("BEGIN", "ERR", "END")])

    def test_actual_graph_shares_two_jobs_groups_output_and_runs_warm_tests_again(self):
        for sanitized in (False, True):
            with self.subTest(sanitized=sanitized):
                self.reset()
                result, rows = self.execute(sanitized)
                self.assert_contract(result, rows, sanitized)
                if sanitized:
                    for row in rows:
                        if row["kind"] == "test" and any(name in row["name"] for name in inventory.SHOWCASES):
                            self.assertEqual((row["asan"], row["ubsan"]),
                                             ("detect_leaks=1:strict_string_checks=1", "halt_on_error=1"))
                suffix = "_sanitized" if sanitized else ""
                for name in inventory.SHOWCASES:
                    (self.root / f"build/test_{name}{suffix}.run").write_text("stale run marker")
                self.reset()
                result, rows = self.execute(sanitized, ASAN_OPTIONS="detect_leaks=0:strict_string_checks=1",
                                             UBSAN_OPTIONS="halt_on_error=1")
                self.assert_contract(result, rows, sanitized, warm=True)
                self.assertTrue(all(row["asan"] == "detect_leaks=0:strict_string_checks=1" and
                                    row["ubsan"] == "halt_on_error=1" for row in rows))

    def timed(self, label, timeout=10):
        with patch.dict(os.environ, self.environment(), clear=True), redirect_stdout(io.StringIO()):
            receipt = timed.run(self.command(), timeout_seconds=timeout, label=label,
                                output_dir=self.root / label, root=self.root)
        self.assertEqual(receipt, json.loads((self.root / label / "receipt.json").read_text()))
        return receipt

    def assert_no_main_or_live_peer(self, rows):
        main = {f"build/test_{name}" for name in inventory.TESTS}
        self.assertFalse(any(row["kind"] == "test" and row["name"] in main for row in rows))
        table = timed.process_table()
        self.assertTrue(all(row["pid"] not in table or table[row["pid"]]["state"] == "Z" for row in rows))

    def test_each_failed_showcase_blocks_the_main_tail(self):
        result, _ = self.execute()
        self.assertEqual(result.returncode, 0, result.stdout)
        for name in inventory.SHOWCASES:
            with self.subTest(showcase=name):
                self.reset(fail="build/test_" + name)
                receipt = self.timed(name)
                self.assertEqual(receipt["status"], "failed")
                self.assertNotEqual(receipt["returncode"], 0)
                self.assert_no_main_or_live_peer(self.rows())

    def test_missing_binary_and_partial_failed_compilation_cannot_qualify(self):
        for control in ("missing", "partial"):
            with self.subTest(control=control):
                shutil.rmtree(self.root / "build", ignore_errors=True)
                self.reset(**{control:"build/test_megatruss_station"})
                receipt = self.timed(control)
                self.assertEqual(receipt["status"], "failed")
                self.assertNotEqual(receipt["returncode"], 0)
                self.assert_no_main_or_live_peer(self.rows())

    def prepare_failure_and_hang(self):
        result, _ = self.execute()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.reset(fail="build/test_megatruss_station", hang="build/test_seeded_typology_megablock")

    def test_failure_with_hanging_peer_times_out_and_reaps_the_peer(self):
        self.prepare_failure_and_hang()
        receipt = self.timed("timeout", timeout=1)
        self.assertEqual(receipt["status"], "timeout")
        self.assertTrue(receipt["timed_out"])
        self.assertFalse(receipt["natural_completion"])
        rows = self.rows()
        hanging = [row for row in rows if row["name"] == "build/test_seeded_typology_megablock"]
        self.assertEqual([row["phase"] for row in hanging], ["start"])
        self.assertIn(str(hanging[0]["pid"]), receipt["terminated_descendants"])
        self.assert_no_main_or_live_peer(rows)

    def test_cancellation_after_failure_reaps_the_inflight_peer_and_is_incomplete(self):
        self.prepare_failure_and_hang()
        program = ("import sys; from pathlib import Path; "
                   f"sys.path.insert(0, {str(inventory.ROOT / 'tools/ci')!r}); import run_timed_command as timed; "
                   f"timed.run({self.command()!r}, timeout_seconds=10, label='cancel', "
                   f"output_dir=Path({str(self.root / 'cancel')!r}), root=Path({str(self.root)!r}))")
        process = subprocess.Popen([sys.executable, "-u", "-c", program], cwd=self.root,
                                   env=self.environment(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, start_new_session=True)
        try:
            deadline = time.monotonic() + 5
            while not any(row["phase"] == "failed" for row in self.rows()) and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(any(row["phase"] == "failed" for row in self.rows()))
            process.send_signal(signal.SIGINT)
            output, _ = process.communicate(timeout=10)
            self.assertNotEqual(process.returncode, 0, output)
            receipt = json.loads((self.root / "cancel/receipt.json").read_text())
            self.assertEqual(receipt["status"], "interrupted")
            self.assertFalse(receipt["complete"])
            self.assertFalse(receipt["natural_completion"])
            self.assert_no_main_or_live_peer(self.rows())
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                process.communicate(timeout=10)


if __name__ == "__main__":
    unittest.main()
