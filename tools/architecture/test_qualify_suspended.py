#!/usr/bin/env python3
"""Fault-inject actual Git/source changes into the qualification boundary."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import qualify_suspended as qualification


class QualificationSourceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="suspended-source-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in [*qualification.SOURCES, qualification.TEST,
                     qualification.DRIVER_TEST, "Makefile",
                     "native/include/fixture.hpp", "native/src/detail.hpp"]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("original fixture input\n")
        (self.root / qualification.DRIVER).write_bytes(
            Path(qualification.__file__).read_bytes())
        (self.root / ".gitignore").write_text("build/\n")
        self.git("init", "-q")
        self.commit("initial fixture")

    def git(self, *arguments: str) -> str:
        return subprocess.check_output(
            ["git", "-c", "user.name=Qualification test", "-c",
             "user.email=qualification@example.invalid", *arguments],
            cwd=self.root, text=True).strip()

    def commit(self, message: str, *, empty: bool = False) -> None:
        self.git("add", "-A")
        self.git("commit", "-qm", message, *( ["--allow-empty"] if empty else [] ))

    def change_input(self) -> None:
        (self.root / qualification.SOURCES[0]).write_text("modified fixture input\n")

    def test_clean_inputs_allow_ignored_build_output(self) -> None:
        before = qualification.capture_source_identity(self.root)
        output = self.root / "build/native-result.bin"
        output.parent.mkdir()
        output.write_bytes(b"actual build output is not source")
        self.assertEqual(qualification.require_unchanged_source(self.root, before), before)

    def test_initial_unstaged_input_is_rejected(self) -> None:
        self.change_input()
        with self.assertRaises(RuntimeError):
            qualification.capture_source_identity(self.root)

    def test_staged_only_change_is_rejected(self) -> None:
        self.change_input()
        self.git("add", qualification.SOURCES[0])
        # Even restoring the working bytes must not conceal a dirty index.
        (self.root / qualification.SOURCES[0]).write_text("original fixture input\n")
        with self.assertRaises(RuntimeError):
            qualification.capture_source_identity(self.root)

    def test_same_size_timestamp_preserved_mutation_is_rejected(self) -> None:
        before = qualification.capture_source_identity(self.root)
        path = self.root / "native/src/detail.hpp"
        original = path.stat()
        data = path.read_bytes()
        path.write_bytes(b"X" + data[1:])
        os.utime(path, ns=(original.st_atime_ns, original.st_mtime_ns))
        with self.assertRaises(RuntimeError):
            qualification.require_unchanged_source(self.root, before)

    def test_new_header_is_not_omitted_from_final_ledger(self) -> None:
        before = qualification.capture_source_identity(self.root)
        (self.root / "native/include/new.hpp").write_text("new compile input\n")
        with self.assertRaises(RuntimeError):
            qualification.require_unchanged_source(self.root, before)

    def test_committed_input_change_is_rejected(self) -> None:
        before = qualification.capture_source_identity(self.root)
        self.change_input()
        self.commit("concurrent clean source change")
        self.assertEqual(self.git("status", "--porcelain"), "")
        with self.assertRaises(RuntimeError):
            qualification.require_unchanged_source(self.root, before)

    def test_same_tree_new_head_is_rejected(self) -> None:
        before = qualification.capture_source_identity(self.root)
        self.commit("concurrent metadata-only commit", empty=True)
        self.assertEqual(self.git("rev-parse", "HEAD^{tree}"), before["tree"])
        with self.assertRaises(RuntimeError):
            qualification.require_unchanged_source(self.root, before)

    def test_dirty_cli_refuses_before_build_and_preserves_previous_report(self) -> None:
        output = self.root / "build/qualification"
        output.mkdir(parents=True)
        previous = output / "qualification.json"
        previous.write_bytes(b"previous immutable successful evidence\n")
        self.change_input()
        command = [sys.executable, qualification.DRIVER,
                   "--parent-ref", self.git("rev-parse", "HEAD"),
                   "--compiler", "compiler-must-never-be-invoked",
                   "--output", str(output)]
        result = subprocess.run(command, cwd=self.root, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must be clean and tracked before use", result.stderr)
        self.assertNotIn("FileNotFoundError", result.stderr)
        self.assertEqual(previous.read_bytes(), b"previous immutable successful evidence\n")
        self.assertFalse((self.root / "build/test_suspended_arcology").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
