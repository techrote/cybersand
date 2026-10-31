#!/usr/bin/env python3
"""Actual make dry-run inventory and adverse controls; no native execution."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import check_worldgen_build_inventory as inventory


class WorldgenBuildInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = inventory.check(inventory.ROOT)

    def streams(self, target="worldgen-sanitize"):
        row = self.report["families"][target]
        return row["serial"]["stdout"], row["two_jobs"]["stdout"]

    def test_both_actual_graphs_have_twelve_objects_nine_binaries_and_ordered_tests(self):
        for target, row in self.report["families"].items():
            with self.subTest(target=target):
                self.assertEqual(row["object_count"], 12)
                self.assertEqual(row["binary_count"], 9)
                self.assertEqual(len(row["compile_link_commands"]), 21)
                self.assertEqual(len(row["ordered_tests"]), 9)

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
        with self.assertRaisesRegex(ValueError, "Nine-test inventory/order"):
            inventory.compare(serial, altered, True)

    def test_reordered_tests_are_rejected(self):
        serial, bounded = self.streams()
        lines = bounded.splitlines()
        positions = [index for index, line in enumerate(lines) if line.startswith("./build/test_")]
        lines[positions[0]], lines[positions[1]] = lines[positions[1]], lines[positions[0]]
        with self.assertRaisesRegex(ValueError, "Nine-test inventory/order"):
            inventory.compare(serial, "\n".join(lines), True)

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
