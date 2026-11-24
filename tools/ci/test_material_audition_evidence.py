#!/usr/bin/env python3
"""Adversarial custody controls; these fixtures are not native effect evidence."""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_material_audition_qualification as subject
import package_material_audition_candidate as package


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="material-audition-evidence-test-")
        self.root = Path(self.temporary.name) / "source"
        self.root.mkdir()
        self.git("init", "-q")
        for relative in ("native/include/example.hpp", "native/src/example.cpp",
                         "godot/native_extension/example.cpp", "godot/scripts/example.gd",
                         "godot/tests/example.gd", "tools/ci/run_material_audition_qualification.py"):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("source fixture\n", encoding="utf-8")
        self.git("add", ".")
        self.commit()
        self.runtime = Path(self.temporary.name) / "fixture-runtime.so"
        self.runtime.write_bytes(b"\x7fELFcustody fixture, never executed as a runtime")
        self.candidate = Path(self.temporary.name) / "candidate"
        self.identity = subject.record(self.root, "linux", self.runtime, self.candidate)

    def tearDown(self):
        self.temporary.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.PIPE)

    def commit(self):
        return self.git("-c", "user.name=CustodyFixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "-qm", "fixture")

    def rewrite_manifest(self, **updates):
        changed = copy.deepcopy(self.identity)
        changed.update(updates)
        subject.write(self.candidate / subject.MANIFEST, changed)

    def test_source_bound_candidate_roundtrip_does_not_claim_execution(self):
        restored = subject.verify(self.root, self.candidate, "linux")
        self.assertEqual(restored, self.identity)
        self.assertEqual(restored["status"], "built-not-executed")
        self.assertEqual(restored["source_commit"], self.git("rev-parse", "HEAD").decode().strip())
        self.assertIn("godot/scripts/example.gd", restored["execution_inputs"])

    def test_existing_candidate_is_not_overwritten(self):
        before = (self.candidate / subject.MANIFEST).read_bytes()
        with self.assertRaisesRegex(ValueError, "immutable"):
            subject.record(self.root, "linux", self.runtime, self.candidate)
        self.assertEqual((self.candidate / subject.MANIFEST).read_bytes(), before)

    def test_actual_runtime_byte_change_refused(self):
        runtime = self.candidate / Path(subject.RUNTIMES["linux"]).name
        runtime.write_bytes(runtime.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "runtime bytes"):
            subject.verify(self.root, self.candidate)

    def test_wrong_platform_refused(self):
        with self.assertRaisesRegex(ValueError, "platform mismatch"):
            subject.verify(self.root, self.candidate, "windows")
        with self.assertRaisesRegex(ValueError, "declared platform"):
            subject.record(self.root, "windows", self.runtime, Path(self.temporary.name) / "wrong")

    def test_changed_source_commit_refused_even_with_equivalent_native_files(self):
        (self.root / "readme.txt").write_text("next source checkpoint")
        self.git("add", "readme.txt")
        self.commit()
        with self.assertRaisesRegex(ValueError, "source inputs"):
            subject.verify(self.root, self.candidate)

    def test_modified_host_script_refuses_before_receipt(self):
        (self.root / "godot/scripts/example.gd").write_text("dirty host")
        with self.assertRaises(subprocess.CalledProcessError):
            subject.verify(self.root, self.candidate)

    def test_modified_qualification_runner_refuses_before_receipt(self):
        (self.root / "tools/ci/run_material_audition_qualification.py").write_text("dirty runner")
        with self.assertRaises(subprocess.CalledProcessError):
            subject.source_identity(self.root)

    def test_untracked_host_implementation_refused(self):
        (self.root / "godot/scripts/extra.gd").write_text("untracked host")
        with self.assertRaisesRegex(ValueError, "Untracked implementation"):
            subject.verify(self.root, self.candidate)

    def test_manifest_artifact_path_cannot_escape_candidate(self):
        self.rewrite_manifest(artifact="../../other-runtime.so")
        with self.assertRaisesRegex(ValueError, "artifact path"):
            subject.verify(self.root, self.candidate)

    def test_manifest_source_inventory_tampering_refused(self):
        altered = copy.deepcopy(self.identity["native_inputs"])
        altered["native/src/example.cpp"] = "0" * 64
        self.rewrite_manifest(native_inputs=altered)
        with self.assertRaisesRegex(ValueError, "source inputs"):
            subject.verify(self.root, self.candidate)

    def test_frozen_toolchain_receipt_checked(self):
        toolchain = Path(self.temporary.name) / "compiler.txt"
        toolchain.write_text("compiler fixture")
        directory = Path(self.temporary.name) / "with-toolchain"
        subject.record(self.root, "linux", self.runtime, directory, toolchain)
        (directory / "toolchain.txt").write_text("different compiler")
        with self.assertRaisesRegex(ValueError, "toolchain receipt"):
            subject.verify(self.root, directory)

    def test_completion_requires_unique_explicit_nonzero_success(self):
        valid = 'RESULT {"checks":3,"failures":0,"status":"passed"}\n'
        self.assertEqual(subject.completion(valid, "RESULT")["checks"], 3)
        for text in ("", valid + valid, 'RESULT {"checks":0,"failures":0}',
                     'RESULT {"checks":true,"failures":0}', 'RESULT {"checks":3,"failures":false}',
                     'RESULT {"checks":3,"failures":1}', 'RESULT {"checks":3,"failures":0,"status":"running"}'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                subject.completion(text, "RESULT")

    def test_existing_native_summary_formats_are_supported(self):
        for value in ("3 assertions; 0 failures; artifacts=path", "3 assertions, 0 failures; readback", "3 checks, 0 failures"):
            self.assertEqual(subject.completion("RESULT " + value, "RESULT")["checks"], 3)

    def test_nonzero_process_preserves_original_failure_receipt(self):
        log = Path(self.temporary.name) / "nonzero.log"
        with self.assertRaisesRegex(ValueError, "Process failed"):
            subject.run_process([sys.executable, "-c", "print('RESULT {\"checks\":2,\"failures\":0}');raise SystemExit(7)"],
                                log, dict(os.environ), 30, "RESULT")
        receipt = json.loads(log.with_suffix(".receipt.json").read_text())
        self.assertEqual(receipt["exit_code"], 7)
        self.assertEqual(receipt["status"], "failed")
        self.assertEqual(receipt["log_sha256"], subject.sha(log))

    def test_parse_error_refused_despite_success_exit_and_marker(self):
        log = Path(self.temporary.name) / "parse-error.log"
        with self.assertRaisesRegex(ValueError, "Process failed"):
            subject.run_process([sys.executable, "-c", "print('SCRIPT ERROR: fixture');print('RESULT {\"checks\":2,\"failures\":0}')"],
                                log, dict(os.environ), 30, "RESULT")

    def test_timeout_kills_own_process_and_retains_failure(self):
        log = Path(self.temporary.name) / "timeout.log"
        with self.assertRaises(subprocess.TimeoutExpired):
            subject.run_process([sys.executable, "-c", "import time;print('started',flush=True);time.sleep(30)"],
                                log, dict(os.environ), 1)
        receipt = json.loads(log.with_suffix(".receipt.json").read_text())
        self.assertEqual(receipt["status"], "failed")
        self.assertNotEqual(receipt["exit_code"], 0)
        self.assertIn("started", log.read_text())

    def test_launcher_preserves_portable_tools_and_ordinary_workbench(self):
        text = package.launcher("a" * 40).decode()
        self.assertIn('-- --workbench', text)
        self.assertIn('set "GIT_DIR="', text)
        self.assertIn('set "PYTHONPATH="', text)
        self.assertIn('dependencies\\cxx\\bin', text)
        self.assertIn('opengl3_angle', text)
        self.assertNotIn('res://materials_lab.tscn', text)
        self.assertIn('res://materials_lab.tscn', package.launcher("a" * 40, laboratory=True).decode())

    def test_file_inventory_refuses_external_links(self):
        if os.name == "nt":
            self.skipTest("Windows symlink privileges differ; package verification still enforces the invariant")
        directory = Path(self.temporary.name) / "links"
        directory.mkdir()
        (directory / "external").symlink_to(self.runtime)
        with self.assertRaisesRegex(ValueError, "symlinks"):
            package.files(directory)

    def test_empty_or_missing_target_os_evidence_never_qualifies_package(self):
        directory = Path(self.temporary.name) / "empty-evidence"
        directory.mkdir()
        result = {"schema": "cybersand.material-audition.execution", "status": "passed",
                  "platform": "windows", "graphical": True, "cases": [], "files_sha256": {},
                  **{key: self.identity[key] for key in ("source_commit", "source_tree", "native_sha256")}}
        subject.write(directory / "execution.json", result)
        with self.assertRaisesRegex(ValueError, "omitted"):
            package.verified_execution(directory, self.identity, graphical=True)
        result["platform"] = "linux"
        subject.write(directory / "execution.json", result)
        with self.assertRaisesRegex(ValueError, "Windows execution"):
            package.verified_execution(directory, self.identity, graphical=True)


if __name__ == "__main__":
    unittest.main()
