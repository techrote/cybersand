#!/usr/bin/env python3
"""Regression checks for the retained-runtime Windows execution gate."""

from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

import run_windows_godot_regressions as subject


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def pointer(data: bytes) -> bytes:
    return ("version https://git-lfs.github.com/spec/v1\n"
            f"oid sha256:{digest(data)}\nsize {len(data)}\n").encode()


class RetainedRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        files = {
            "native/include/cybersand/world.hpp": b"header\n",
            "native/src/world.cpp": b"implementation\n",
            "godot/native_extension/bridge.cpp": b"bridge\n",
            subject.NATIVE: b"MZ-native-fixture",
            subject.RAPIER: b"MZ-rapier-fixture",
        }
        for relative, data in files.items():
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.manifest = {
            "schema_version": 1, "artifact": subject.NATIVE,
            "source_commit": "a" * 40, "build_commit": "b" * 40,
            "sha256": digest(files[subject.NATIVE]), "size": len(files[subject.NATIVE]),
            "source_inputs": {relative: digest(data) for relative, data in files.items()
                              if not relative.endswith(".dll")},
        }
        self.committed = {subject.NATIVE: pointer(files[subject.NATIVE]),
                          subject.RAPIER: pointer(files[subject.RAPIER])}
        self.save_manifest()
        patcher = mock.patch.object(subject, "RAPIER_SHA256", digest(files[subject.RAPIER]))
        patcher.start()
        self.addCleanup(patcher.stop)
        patcher = mock.patch.object(subject, "git", side_effect=lambda _root, _show, spec: self.committed[spec.removeprefix("HEAD:")])
        patcher.start()
        self.addCleanup(patcher.stop)

    def save_manifest(self):
        data = (json.dumps(self.manifest) + "\n").encode()
        (self.root / subject.PROVENANCE).write_bytes(data)
        self.committed[subject.PROVENANCE] = data

    def test_exact_retained_bytes_and_all_native_inputs_are_accepted(self):
        identity = subject.verify_retained_runtime(self.root)
        self.assertEqual(identity["runtime_source_commit"], "a" * 40)
        self.assertEqual(identity["cybersand_runtime"]["sha256"], self.manifest["sha256"])
        self.assertEqual(len(identity["native_source_inputs"]), 3)

    def test_pointer_and_modified_runtime_cannot_pass(self):
        for data in (self.committed[subject.NATIVE], b"MZ-replaced-fixture"):
            with self.subTest(data=data):
                (self.root / subject.NATIVE).write_bytes(data)
                with self.assertRaisesRegex(RuntimeError, "Materialized Windows runtime"):
                    subject.verify_retained_runtime(self.root)

    def test_lfs_matching_dll_still_must_match_provenance(self):
        replacement = b"MZ-new-runtime"
        self.committed[subject.NATIVE] = pointer(replacement)
        (self.root / subject.NATIVE).write_bytes(replacement)
        with self.assertRaisesRegex(RuntimeError, "differs from its runtime provenance"):
            subject.verify_retained_runtime(self.root)

    def test_changed_native_input_requires_rebuild(self):
        (self.root / "native/src/world.cpp").write_bytes(b"changed implementation\n")
        with self.assertRaisesRegex(RuntimeError, "requires rebuild for source input"):
            subject.verify_retained_runtime(self.root)

    def test_new_native_header_cannot_escape_manifest_coverage(self):
        (self.root / "native/src/new.hpp").write_bytes(b"new build input\n")
        with self.assertRaisesRegex(RuntimeError, "every current native source/header"):
            subject.verify_retained_runtime(self.root)

    def test_removing_manifest_input_cannot_bypass_stale_source_check(self):
        self.manifest["source_inputs"].pop("native/src/world.cpp")
        self.save_manifest()
        with self.assertRaisesRegex(RuntimeError, "every current native source/header"):
            subject.verify_retained_runtime(self.root)

    def test_working_provenance_edit_is_rejected(self):
        (self.root / subject.PROVENANCE).write_bytes(b"{}\n")
        with self.assertRaisesRegex(RuntimeError, "provenance differs from the tested Git commit"):
            subject.verify_retained_runtime(self.root)

    def test_rapier_lfs_identity_does_not_replace_the_official_pin(self):
        replacement = b"MZ-different-rapier"
        self.committed[subject.RAPIER] = pointer(replacement)
        (self.root / subject.RAPIER).write_bytes(replacement)
        with self.assertRaisesRegex(RuntimeError, "pinned official runtime"):
            subject.verify_retained_runtime(self.root)


class ExecutionTests(unittest.TestCase):
    def execute_fixture(self, import_message: str = "imported") -> dict:
        cases = [
            subject.runner.Case("zero_exit_error", (), 5, 1),
            subject.runner.Case("new_visual_render", (), 5, 1, True),
            subject.runner.Case("zero_exit_skip", (), 5, 1),
            subject.runner.Case("later_case", (), 5, 1),
        ]
        messages = {"import": import_message, "zero_exit_error": "SCRIPT ERROR: failure",
                    "zero_exit_skip": "SKIP: unavailable oracle", "later_case": "12 assertions passed"}
        report = {"results": [], "log_sha256": {}, "completed": False, "status": "running"}
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory)
            with mock.patch.object(subject.runner, "case_command", side_effect=lambda _godot, case: [sys.executable, "-c", f"print({messages[case.name]!r})"]):
                subject.execute_cases("fixture", output, report, cases)
            for record in report["results"]:
                self.assertEqual(report["log_sha256"][record["log"]], digest((output / record["log"]).read_bytes()))
                self.assertEqual(record["command"][0], sys.executable)
        return report

    def test_real_children_keep_going_without_passing_errors_or_skips(self):
        report = self.execute_fixture()
        self.assertTrue(report["completed"])
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["out_of_scope_graphical_cases"], ["new_visual_render"])
        self.assertEqual(report["assigned_cases"], ["zero_exit_error", "zero_exit_skip", "later_case"])
        self.assertEqual([item["name"] for item in report["results"]], ["import", "zero_exit_error", "zero_exit_skip", "later_case"])
        self.assertEqual([item["status"] for item in report["results"]], ["passed", "failed", "skipped", "passed"])
        self.assertEqual(report["executed_case_count"], 3)
        self.assertEqual([item["timeout_seconds"] for item in report["results"]], [240, 5, 5, 5])

    def test_failed_import_records_incomplete_suite(self):
        report = self.execute_fixture("ERROR: import failure")
        self.assertFalse(report["completed"])
        self.assertEqual(report["status"], "failed")
        self.assertEqual([item["name"] for item in report["results"]], ["import"])
        self.assertEqual(report["executed_case_count"], 0)

    def test_bad_archive_is_rejected_before_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "godot.zip"
            archive.write_bytes(b"not the official archive")
            with self.assertRaisesRegex(RuntimeError, "archive SHA-512 mismatch"):
                subject.prepare_godot(archive)


if __name__ == "__main__":
    unittest.main()
