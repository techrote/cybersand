#!/usr/bin/env python3
"""Actual make dry-run inventory and adverse controls; no native execution."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import check_worldgen_build_inventory as inventory


# This executable double exercises the real make graph, not native behavior or
# elapsed performance. Its rendezvous fails unless both long objects are admitted
# together on a genuinely cold build with no pre-created object directories.
COMPILER_DOUBLE = r"""import json
import os
from pathlib import Path
import shlex
import sys
import time


def record(event):
    fd = os.open(os.environ["WORLDGEN_SCHEDULE_LOG"], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    try:
        os.write(fd, (json.dumps(event) + "\n").encode())
    finally:
        os.close(fd)


args = sys.argv[1:]
if args[0] == "--test":
    record({"kind": "test", "output": args[1]})
    raise SystemExit(19 if os.environ.get("WORLDGEN_SCHEDULE_FAIL") == args[1] else 0)
output = args[args.index("-o") + 1]
record({"kind": "compile", "output": output, "args": args})
path = Path(output)
assert path.parent.is_dir(), "The production make recipe must create the directory"
if output.endswith("/world_generation.o"):
    marker = path.with_suffix(".started")
    marker.write_text("started")
    folder = path.parent.name
    other = folder.removesuffix("-threaded") if folder.endswith("-threaded") else folder + "-threaded"
    sibling = path.parent.parent / other / marker.name
    deadline = time.monotonic() + 5
    while not sibling.exists():
        if time.monotonic() >= deadline:
            raise SystemExit("Both long translation units were not admitted together")
        time.sleep(0.005)
    if os.environ.get("WORLDGEN_SCHEDULE_FAIL") == "compile":
        raise SystemExit(19)
if output.endswith(".o"):
    path.write_bytes(b"compiler double; not native code")
else:
    path.write_text("#!/bin/sh\nexec " + shlex.quote(sys.executable) + " " +
                    shlex.quote(__file__) + " --test " + shlex.quote(output) + "\n")
    path.chmod(0o755)
"""


class WorldgenBuildInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = inventory.check(inventory.ROOT)

    def streams(self, target="worldgen-sanitize"):
        row = self.report["families"][target]
        return row["serial"]["stdout"], row["two_jobs"]["stdout"]

    def test_both_actual_graphs_have_twelve_objects_sixteen_binaries_and_ordered_tests(self):
        for target, row in self.report["families"].items():
            with self.subTest(target=target):
                self.assertEqual(row["object_count"], 12)
                self.assertEqual(row["binary_count"], 16)
                self.assertEqual(len(row["compile_link_commands"]), 28)
                self.assertEqual(len(row["ordered_tests"]), 16)


    def run_actual_graph(self, target, failure=""):
        with tempfile.TemporaryDirectory(prefix="worldgen-schedule-") as directory:
            root = Path(directory)
            shutil.copy2(inventory.ROOT / "Makefile", root / "Makefile")
            shutil.copytree(inventory.ROOT / "native", root / "native")
            compiler = root / "compiler_double.py"
            compiler.write_text(COMPILER_DOUBLE)
            log = root / "schedule.jsonl"
            env = os.environ.copy()
            for variable in ("MAKEFLAGS", "MFLAGS"):
                env.pop(variable, None)
            env.update(WORLDGEN_SCHEDULE_LOG=str(log), WORLDGEN_SCHEDULE_FAIL=failure)
            command = ["make", "--no-print-directory", "-j2",
                       f"CXX={shlex.quote(sys.executable)} {shlex.quote(str(compiler))}", target]
            process = subprocess.run(command, cwd=root, env=env, text=True,
                                     capture_output=True, timeout=30)
            records = [json.loads(line) for line in log.read_text().splitlines()]
            return process, records

    def test_actual_cold_graph_starts_both_long_objects_and_retains_every_command(self):
        for target, family in (("worldgen-test", "normal"), ("worldgen-sanitize", "sanitized")):
            with self.subTest(target=target):
                process, records = self.run_actual_graph(target)
                self.assertEqual(process.returncode, 0, process.stderr)
                compiles = [row for row in records if row["kind"] == "compile"]
                self.assertEqual({row["output"] for row in compiles[:2]}, {
                    f"build/worldgen-objects/{family}/world_generation.o",
                    f"build/worldgen-objects/{family}-threaded/world_generation.o",
                })
                expected = inventory.expected_commands(target.endswith("sanitize"))
                self.assertEqual(len(compiles), len(expected))
                self.assertEqual({row["output"]: row["args"] for row in compiles},
                                 {output: argv[1:] for output, argv in expected.items()})
                self.assertEqual(["./" + row["output"] for row in records if row["kind"] == "test"],
                                 self.report["families"][target]["ordered_tests"])

    def test_actual_graph_refuses_compile_failure_and_stops_after_test_failure(self):
        for target, suffix in (("worldgen-test", ""), ("worldgen-sanitize", "_sanitized")):
            with self.subTest(target=target, failure="compile"):
                process, records = self.run_actual_graph(target, "compile")
                self.assertNotEqual(process.returncode, 0)
                self.assertFalse(any(row["kind"] == "test" for row in records))
            with self.subTest(target=target, failure="test"):
                process, records = self.run_actual_graph(target, f"build/test_world_generation{suffix}")
                self.assertNotEqual(process.returncode, 0)
                self.assertEqual(["./" + row["output"] for row in records if row["kind"] == "test"],
                                 self.report["families"][target]["ordered_tests"][:8])

    def test_missing_prerequisite_is_rejected(self):
        serial, bounded = self.streams()
        lines = bounded.splitlines()
        index = next(index for index, line in enumerate(lines) if line.startswith(inventory.COMPILER))
        lines.pop(index)
        with self.assertRaisesRegex(ValueError, "Missing compilation"):
            inventory.compare(serial, "\n".join(lines), True)

    def test_omitted_test_is_rejected(self):
        serial, bounded = self.streams()
        altered = "\n".join(line for line in bounded.splitlines()
                            if line != "./build/test_generation_planes_sanitized")
        with self.assertRaisesRegex(ValueError, "Sixteen-test inventory/order"):
            inventory.compare(serial, altered, True)

    def test_reordered_tests_are_rejected(self):
        serial, bounded = self.streams()
        lines = bounded.splitlines()
        positions = [index for index, line in enumerate(lines) if line.startswith("./build/test_")]
        lines[positions[0]], lines[positions[1]] = lines[positions[1]], lines[positions[0]]
        with self.assertRaisesRegex(ValueError, "Sixteen-test inventory/order"):
            inventory.compare(serial, "\n".join(lines), True)

    def test_omitted_showcase_or_changed_sanitizer_environment_is_rejected(self):
        serial, bounded = self.streams()
        for before, after in (("build/test_suspended_arcology_sanitized; do", "; do"),
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

    def test_compilation_cannot_move_after_tests_begin(self):
        serial, bounded = self.streams()
        lines = bounded.splitlines()
        index = next(index for index, line in enumerate(lines) if line.startswith(inventory.COMPILER))
        lines.append(lines.pop(index))
        with self.assertRaisesRegex(ValueError, "Compilation appears after test"):
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


if __name__ == "__main__":
    unittest.main()
