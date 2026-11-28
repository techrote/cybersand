#!/usr/bin/env python3
"""Pinned portable-linker selection at both Materials Lab compile paths."""
from __future__ import annotations

import json
import os
import hashlib
from pathlib import Path
import subprocess
import tempfile
import sys
import unittest
from types import SimpleNamespace
from unittest import mock

import lab
import world_candidate as world


class PortableLinkerSelectionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="portable-linker-contract-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "Owner Ω With Spaces" / "dependencies" / "cxx"
        self.compiler = self.root / "bin" / "g++.exe"
        self.compiler.parent.mkdir(parents=True)
        self.compiler.write_bytes(b"pinned-gcc-fixture")
        self.marker = self.root / "CYBERSAND-PORTABLE-LINKER.json"

    def verifier(self, *, proof=None, error=None):
        def verify(root, *, execute=False):
            self.assertEqual(root, self.root)
            self.assertFalse(execute)
            if error is not None:
                raise error
            return proof if proof is not None else {
                "schema": "cybersand.portable-linker-v1", "status": "verified"}
        return SimpleNamespace(verify=mock.Mock(side_effect=verify))

    def test_legacy_no_marker_keeps_gcc_default_and_skips_verifier(self):
        with mock.patch.object(lab, "_portable_lld_module") as load_verifier:
            self.assertEqual(lab.compiler_linker_options(str(self.compiler)), [])
            load_verifier.assert_not_called()

    def test_marker_uses_pinned_lld_only_after_exact_root_proof(self):
        self.marker.write_text(json.dumps({"schema": "fixture marker"}), encoding="utf-8")
        verifier = self.verifier()
        with mock.patch.object(lab, "_portable_lld_module", return_value=verifier):
            self.assertEqual(lab.compiler_linker_options(str(self.compiler)), ["-fuse-ld=lld"])
        verifier.verify.assert_called_once_with(self.root, execute=False)

    def test_present_foreign_or_incomplete_marker_fails_without_gnu_fallback(self):
        self.marker.write_text("{}", encoding="utf-8")
        for failure in (ValueError("foreign GCC hash"), FileNotFoundError("missing ld.lld.exe")):
            verifier = self.verifier(error=failure)
            with self.subTest(failure=str(failure)), \
                    mock.patch.object(lab, "_portable_lld_module", return_value=verifier), \
                    self.assertRaisesRegex(lab.LabError, "failed verification"):
                lab.compiler_linker_options(str(self.compiler))
            verifier.verify.assert_called_once_with(self.root, execute=False)

    def test_unrecognized_proof_fails_closed(self):
        self.marker.write_text("{}", encoding="utf-8")
        verifier = self.verifier(proof={"schema": "foreign-linker"})
        with mock.patch.object(lab, "_portable_lld_module", return_value=verifier), \
                self.assertRaisesRegex(lab.LabError, "no recognized pinned proof"):
            lab.compiler_linker_options(str(self.compiler))

    def test_non_gcc_and_msvc_selections_never_load_lld_marker(self):
        self.marker.write_text("{}", encoding="utf-8")
        clang = self.compiler.with_name("clang++.exe")
        clang.write_bytes(b"foreign compiler")
        with mock.patch.object(lab, "_portable_lld_module") as load_verifier:
            self.assertEqual(lab.compiler_linker_options(str(clang)), [])
            self.assertEqual(lab.compiler_linker_options(str(self.compiler), msvc=True), [])
            load_verifier.assert_not_called()

    def test_verifier_uses_exact_ci_source_not_an_ambient_module(self):
        ambient = SimpleNamespace(verify=lambda *_args, **_kwargs: {"schema": "foreign"})
        path_before = list(sys.path)
        with mock.patch.dict(sys.modules, {"portable_lld": ambient}):
            verifier = lab._portable_lld_module()
            self.assertIs(sys.modules["portable_lld"], ambient)
        self.assertEqual(Path(verifier.__file__).resolve(),
                         (lab.ROOT / "tools/ci/portable_lld.py").resolve())
        self.assertEqual(sys.path, path_before)

    def test_world_command_and_receipt_keep_linker_flag_and_staged_paths(self):
        stage = Path(self.temporary.name) / "long staged path Ω with spaces" / "reference"
        stage.mkdir(parents=True)
        scenario = {"first": 2, "second": 3, "seed": 17, "ticks": 1, "workers": 1}
        calls = []

        def fake_run(argv, cwd, timeout, **kwargs):
            calls.append(list(argv))
            if len(calls) == 1:
                executable = stage / ("lab-world-probe.exe" if os.name == "nt" else "lab-world-probe")
                executable.write_bytes(b"linked-world-probe")
                return subprocess.CompletedProcess(argv, 0, "", "")
            return subprocess.CompletedProcess(argv, 0,
                json.dumps({"ok": True, "runtime_active": False}), "")

        with mock.patch.object(lab, "compiler_linker_options", return_value=["-fuse-ld=lld"]), \
                mock.patch.object(lab, "_run", side_effect=fake_run):
            observed, receipt = world._build_and_execute(
                stage, str(self.compiler), False, scenario, 2, False)
        self.assertTrue(observed["ok"])
        self.assertIn("-fuse-ld=lld", calls[0])
        self.assertIn("-fuse-ld=lld", receipt["argv"])
        self.assertTrue(all(not part.startswith(str(stage)) for part in receipt["argv"][1:]))
        self.assertEqual(receipt["native_executable_sha256"],
                         hashlib.sha256(b"linked-world-probe").hexdigest())

    def test_descriptor_compile_passes_same_linker_option_to_actual_run_boundary(self):
        class StopBeforeCompilation(Exception):
            pass

        observed_commands = []

        def stop_at_compiler(argv, directory, timeout, *, check=True):
            if argv[0] == "git":
                return subprocess.CompletedProcess(argv, 0, "test-source-commit\n", "")
            observed_commands.append(list(argv))
            raise StopBeforeCompilation

        with mock.patch.object(lab, "_source_identity", return_value={"digest": "fixture"}), \
                mock.patch.object(lab, "_toolchain", return_value=(str(self.compiler), False)), \
                mock.patch.object(lab, "compiler_linker_options", return_value=["-fuse-ld=lld"]), \
                mock.patch.object(lab, "_run", side_effect=stop_at_compiler), \
                self.assertRaises(StopBeforeCompilation):
            lab.compile_test(lab.create_candidate(2))
        self.assertEqual(len(observed_commands), 1)
        self.assertIn("-fuse-ld=lld", observed_commands[0])


if __name__ == "__main__":
    unittest.main()
