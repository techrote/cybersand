from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import runtime_custody as custody
import native_checks
import package_owner
import linux_floor
from shared import ui_report_errors


def elf() -> bytes:
    value = bytearray(64)
    value[:6] = b"\x7fELF\x02\x01"
    struct.pack_into("<H", value, 18, 62)
    return bytes(value)


def identity() -> dict:
    return {"source_commit": "a" * 40, "source_tree": "b" * 40, "source_inputs_sha256": {"native/a.cpp": "c" * 64},
            "extension_inputs_sha256": {"native/a.cpp": "c" * 64}, "build_inputs_sha256": {"tools/build.py": "d" * 64},
            "native_definition_sha256": "e" * 64, "native_definition_inputs_sha256": {"native/a.cpp": "c" * 64},
            "source_hash_normalization": "fixture", "clean_source_required": True}


class RuntimeCustody(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.source = identity()
        mock = patch.object(custody, "source", return_value=self.source)
        mock.start(); self.addCleanup(mock.stop)
        for name in custody.expected_files("linux"):
            path = self.directory / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(elf())
        (self.directory / "toolchain.txt").write_text("godot_cpp_commit=" + custody.GODOT_CPP
            + "\nnative_definition_sha256=" + self.source["native_definition_sha256"]
            + "\ncompiler_policy=pinned-hosted\ntoolchain_drift=false\n")
        self.receipt = custody.create(self.directory, "linux", local_preflight=True)

    def test_local_diagnostics_cannot_be_admitted_as_hosted(self):
        with self.assertRaisesRegex(ValueError, "Local diagnostics"):
            custody.verify(self.directory)
        self.assertEqual(custody.verify(self.directory, allow_local=True), self.receipt)

    def test_changed_or_missing_runtime_bytes_fail_closed(self):
        name = self.receipt["cli"]
        (self.directory / name).write_bytes(elf() + b"tampered")
        with self.assertRaisesRegex(ValueError, "Runtime bytes changed"):
            custody.verify(self.directory, allow_local=True)
        (self.directory / name).unlink()
        with self.assertRaisesRegex(ValueError, "Missing source-built payload"):
            custody.create(self.directory, "linux", local_preflight=True)

    def test_changed_source_or_retagged_build_is_refused(self):
        self.source["source_tree"] = "f" * 40
        with self.assertRaisesRegex(ValueError, "source identity changed"):
            custody.verify(self.directory, allow_local=True)
        self.source["source_tree"] = self.receipt["source_tree"]
        self.receipt["build_commit"] = "f" * 40
        custody.write_json(self.directory / custody.NAME, self.receipt)
        with self.assertRaisesRegex(ValueError, "retagged"):
            custody.verify(self.directory, allow_local=True)

    def test_missing_native_or_sanitizer_test_cannot_pass_inventory(self):
        del self.receipt["files"]["sanitized/test_swarm005"]
        custody.write_json(self.directory / custody.NAME, self.receipt)
        with self.assertRaisesRegex(ValueError, "runtime binary inventory"):
            custody.verify(self.directory, allow_local=True)

    def test_run_attempt_is_part_of_producer_consumer_custody(self):
        context = {"run_id": "123", "run_attempt": "1"}
        with patch.object(custody, "build_context", return_value=context), patch.dict(os.environ, GITHUB_SHA=self.source["source_commit"]):
            custody.create(self.directory, "linux")
            custody.verify(self.directory)
            with patch.object(custody, "build_context", return_value={**context, "run_attempt": "2"}):
                with self.assertRaisesRegex(ValueError, "run/attempt differ"):
                    custody.verify(self.directory)

    def test_platform_binary_architecture_is_checked(self):
        binary = self.directory / "wrong"
        value = bytearray(elf()); struct.pack_into("<H", value, 18, 183)
        binary.write_bytes(value)
        self.assertFalse(custody.binary_format(binary, "linux"))
        value = bytearray(128); value[:2] = b"MZ"; struct.pack_into("<I", value, 0x3c, 64); value[64:70] = b"PE\0\0\x64\x86"
        binary.write_bytes(value)
        self.assertTrue(custody.binary_format(binary, "windows"))
        self.assertFalse(custody.binary_format(binary, "linux"))

    def test_cli_binding_preserves_original_source_and_definition_inputs(self):
        binding = custody.cli_binding(self.receipt)
        self.assertEqual(binding["source"], self.source["source_commit"])
        self.assertEqual(binding["build_commit"], self.source["source_commit"])
        self.assertEqual(binding["artifact"], "godot/tools/gentek_reciprocal")
        self.assertEqual(binding["native_definition_inputs_sha256"], self.source["native_definition_inputs_sha256"])

    def test_evidence_path_traversal_and_symlinks_are_refused(self):
        for name in ("../escape", "/absolute", "a\\b", "a/../b"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                custody.verify_inventory(self.directory, {name: "0" * 64})


class EvidenceGates(unittest.TestCase):
    def test_failed_linux_floor_names_binary_and_retains_both_symbol_tables(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            paths = [root / "adapter.so", root / "gentek_reciprocal"]
            for path in paths:
                path.write_bytes(elf())
            good = "(GLIBC_2.34) (GLIBCXX_3.4.30) (CXXABI_1.3.9)"
            bad = good + " (GLIBCXX_3.4.32) _ZSt21ios_base_library_initv"
            evidence = root / "evidence"
            with patch.object(linux_floor.subprocess, "check_output", side_effect=[good, bad]):
                with self.assertRaisesRegex(ValueError, "gentek_reciprocal: Raised Linux GLIBCXX requirement: 3.4.32"):
                    linux_floor.inspect(paths, evidence)
            report = json.loads((evidence / "linux-runtime-floor.json").read_text())
            self.assertFalse(report["passed"])
            self.assertTrue(report["binaries"][0]["passed"])
            self.assertFalse(report["binaries"][1]["passed"])
            for binary in report["binaries"]:
                self.assertEqual(custody.sha(evidence / binary["symbol_table"]), binary["symbol_table_sha256"])
            self.assertIn("_ZSt21ios_base_library_initv", (evidence / "gentek_reciprocal.objdump-T.log").read_text())

    def test_linux_symbol_ceiling_includes_the_cli_and_rejects_new_abi(self):
        good = "(GLIBC_2.34) (GLIBCXX_3.4.30) (CXXABI_1.3.9)"
        self.assertEqual(linux_floor.symbol_versions(good)["GLIBC"], "2.34")
        for text in (good + " (GLIBC_2.38)", good + " (GLIBCXX_3.4.31)",
                     good + " (CXXABI_1.3.13)", good + " GLIBC_PRIVATE", ""):
            with self.subTest(text=text), self.assertRaises(ValueError):
                linux_floor.symbol_versions(text)

    def test_native_markers_require_positive_complete_assertions(self):
        good = {"test_assembly": "SWARM004_ASSEMBLY: PASS checks=12",
                "test_reciprocal_mosaic": "reciprocal MOSAIC tests: 3 passed, 0 failed, 20 checks",
                "test_reciprocal": "reciprocal checks=25 both=2 joints=3 complete=4",
                "test_swarm005": "SWARM005_NATIVE_PILOT: PASS tests=8/8 assertions=90",
                "test_workbench_authoring_patch": "WORKBENCH_AUTHORING_PATCH_NATIVE checks=9 failures=0"}
        for name, text in good.items():
            with self.subTest(name=name):
                self.assertTrue(native_checks.marker_valid(name, text))
                self.assertFalse(native_checks.marker_valid(name, text + "\n" + text))
                self.assertFalse(native_checks.marker_valid(name, text + "\nruntime error: undefined behavior"))
                self.assertFalse(native_checks.marker_valid(name, ""))
        self.assertFalse(native_checks.marker_valid("test_swarm005", "SWARM005_NATIVE_PILOT: PASS tests=8/9 assertions=90"))

    def test_linux_and_windows_graphics_are_distinct_actual_os_gates(self):
        report = {"schema": 2, "mode": "lifecycle", "example": "transaction", "completed": True, "failures": [],
                  "checks": 1, "platform": "Linux", "display": "X11", "engine": "4.7-stable (official)",
                  "test_sha256": "f" * 64, "process_id": 42, "owner_visual_acceptance": "pending",
                  "reciprocal_programme_acceptance": False}
        arguments = ("lifecycle", "transaction", "a" * 40, "b" * 64, "f" * 64)
        self.assertEqual(ui_report_errors(report, *arguments, "linux"), [])
        self.assertTrue(ui_report_errors(report, *arguments, "windows"))
        for key, value in (("display", "headless"), ("platform", "Windows"), ("completed", False), ("checks", 0)):
            with self.subTest(key=key):
                self.assertTrue(ui_report_errors({**report, key: value}, *arguments, "linux"))

    def test_extracted_zip_requires_all_exact_archived_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); extracted = root / "extracted"; extracted.mkdir()
            (extracted / "app.exe").write_bytes(b"exact executable")
            manifest = {"files_sha256": {"app.exe": custody.sha(extracted / "app.exe")}}
            custody.write_json(extracted / "candidate-manifest.json", manifest)
            archive = root / "owner.zip"
            with zipfile.ZipFile(archive, "w") as zipped:
                for path in extracted.iterdir():
                    zipped.write(path, path.name)
            package_owner.verify_extracted_zip(archive, extracted, manifest)
            (extracted / "app.exe").write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "Changed evidence"):
                package_owner.verify_extracted_zip(archive, extracted, manifest)
            with zipfile.ZipFile(archive, "a") as zipped:
                zipped.writestr("../escape", b"refused")
            with self.assertRaisesRegex(ValueError, "Unsafe evaluator ZIP"):
                package_owner.verify_extracted_zip(archive, extracted, manifest)


if __name__ == "__main__":
    unittest.main()
