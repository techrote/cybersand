#!/usr/bin/env python3
"""Offline negative controls for compiler replay custody; never compiles HLSL."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import replay_pace003_hlsl as replay


class ReplayTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def records(self):
        begin = {"case": "original-o2", "pid": 123, "tid": 456, "preflight": False,
                 "source_sha256": replay.SOURCE_SHA256, "source_bytes": replay.SOURCE_BYTES,
                 "flags1": 0xC000, "flags2": 0, "source_name": "C:\\fakepath", "entry": "main",
                 "target": "ps_5_0", "include_pointer_present": False,
                 "macros": [["ANGLE_ENABLE_LOOP_FLATTEN", "1"]], "compiler": {"sha256": "compiler-hash"}}
        files = [replay.write_new(self.root / "bytecode.bin", b"DXBC-test-double"),
                 replay.write_new(self.root / "disassembly.txt", b"test-double-disassembly")]
        end = {"case": "original-o2", "preflight": False, "hresult": 0, "compile_succeeded": True,
               "compiler_unchanged": True, "validation_disabled": False, "wall_s": 1.0,
               "thread_cpu_s": 0.75, "process_cpu_s": 0.8, "files": files, "disassembly_hresult": 0}
        return begin, end

    def validate(self, begin, end):
        replay.validate_child_records(self.root, begin, end, name="original-o2", flags=0xC000,
            preflight=False, pid=123, compiler_sha256="compiler-hash")

    def original_fixture(self, mutate=lambda value: None, extra=None):
        source = b"immutable synthetic input for offline custody tests only"
        begin = {"event": "compile_begin", "call": 44, "api": "D3DCompile", "flags1": 0xC000,
                 "flags2": 0, "include_pointer_present": False, "secondary_flags": 0, "secondary_size": 0,
                 "source_name": {"value": "C:\\fakepath", "truncated": False},
                 "entry": {"value": "main", "truncated": False},
                 "target": {"value": "ps_5_0", "truncated": False},
                 "defines_present": True, "defines_truncated": False,
                 "defines": [{"name": {"value": "ANGLE_ENABLE_LOOP_FLATTEN", "truncated": False},
                              "definition": {"value": "1", "truncated": False}}],
                 "source": {"file": Path(replay.HLSL_PATH).name, "bytes": len(source),
                            "written": len(source), "complete": True}}
        mutate(begin)
        identity = {"event": "identity", "system_sha256": "system", "expected_system_sha256": "system"}
        archive = self.root / "original.zip"
        with zipfile.ZipFile(archive, "w") as output:
            output.writestr(replay.TRACE_PATH, json.dumps(identity) + "\n" + json.dumps(begin) + "\n")
            output.writestr(replay.HLSL_PATH, source)
            output.writestr(replay.MANIFEST_PATH, json.dumps({"system_original": {"sha256": "system"}}))
            if extra:
                output.writestr(extra, b"refused")
        metadata = self.root / "metadata.json"
        metadata.write_text(json.dumps({"id": replay.ARTIFACT_ID, "workflow_run": {"id": replay.RUN_ID}, "expired": False}))
        constants = {"ARTIFACT_BYTES": archive.stat().st_size, "ARTIFACT_SHA256": replay.sha256(archive.read_bytes()),
                     "SOURCE_BYTES": len(source), "SOURCE_SHA256": replay.sha256(source)}
        return archive, metadata, constants

    def test_only_predeclared_single_bit_contrast_is_allowed(self):
        for name, flags in replay.CASES:
            replay.validate_case(name, flags)
        for name, flags in (("original-o2", 0xC002), ("skip-optimization-only", 0xC006),
                            ("original-o2", 0), ("o0", 0x4000), ("original-o2", 0xC004)):
            with self.subTest(name=name, flags=flags), self.assertRaises(ValueError):
                replay.validate_case(name, flags)

    def test_original_input_is_read_without_execution_or_reconstruction(self):
        archive, metadata, constants = self.original_fixture()
        with patch.multiple(replay, **constants):
            source, receipt = replay.read_original(archive, metadata)
            self.assertEqual(replay.sha256(source), constants["SOURCE_SHA256"])
            self.assertEqual(receipt["original_call"]["flags1"], 0xC000)

    def test_original_zip_digest_is_mandatory(self):
        archive, metadata, constants = self.original_fixture()
        constants["ARTIFACT_SHA256"] = "wrong"
        with patch.multiple(replay, **constants), self.assertRaisesRegex(ValueError, "ZIP identity"):
            replay.read_original(archive, metadata)

    def test_artifact_run_identity_is_mandatory(self):
        archive, metadata, constants = self.original_fixture()
        value = json.loads(metadata.read_text())
        value["workflow_run"]["id"] += 1
        metadata.write_text(json.dumps(value))
        with patch.multiple(replay, **constants), self.assertRaisesRegex(ValueError, "metadata mismatch"):
            replay.read_original(archive, metadata)

    def test_captured_hlsl_digest_is_independent_of_zip_authentication(self):
        archive, metadata, constants = self.original_fixture()
        constants["SOURCE_SHA256"] = "wrong"
        with patch.multiple(replay, **constants), self.assertRaisesRegex(ValueError, "HLSL identity"):
            replay.read_original(archive, metadata)

    def test_truncated_macro_is_refused(self):
        archive, metadata, constants = self.original_fixture(lambda value: value.update(defines_truncated=True))
        with patch.multiple(replay, **constants), self.assertRaisesRegex(ValueError, "macro inputs"):
            replay.read_original(archive, metadata)

    def test_unretained_include_is_refused(self):
        archive, metadata, constants = self.original_fixture(lambda value: value.update(include_pointer_present=True))
        with patch.multiple(replay, **constants), self.assertRaisesRegex(ValueError, "API inputs"):
            replay.read_original(archive, metadata)

    def test_unsafe_archive_entry_is_refused(self):
        archive, metadata, constants = self.original_fixture(extra="../escape")
        with patch.multiple(replay, **constants), self.assertRaisesRegex(ValueError, "Unsafe"):
            replay.read_original(archive, metadata)

    def test_no_output_can_overwrite_an_original(self):
        path = self.root / "evidence.json"
        replay.write_new(path, b"original")
        with self.assertRaises(FileExistsError):
            replay.write_new(path, b"replacement")
        self.assertEqual(path.read_bytes(), b"original")

    def test_completed_record_requires_exact_process_and_api_inputs(self):
        begin, end = self.records()
        self.validate(begin, end)
        for key, value in (("pid", 124), ("flags1", 0xC004), ("flags2", 1), ("source_sha256", "wrong"),
                           ("entry", "other"), ("target", "ps_4_0"), ("include_pointer_present", True),
                           ("macros", []), ("compiler", {"sha256": "other"})):
            changed = {**begin, key: value}
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(changed, end)

    def test_missing_begin_cannot_produce_completed_compilation(self):
        begin, end = self.records()
        with self.assertRaisesRegex(ValueError, "no retained begin"):
            self.validate(None, end)
        self.assertEqual(replay.result_status(False, 0, None, end,
            decision_elapsed_s=1.0, case_limit_s=180.0), "compile_failed")

    def test_hresult_validation_and_timing_contradictions_are_refused(self):
        begin, end = self.records()
        for key, value in (("hresult", 0x80004005), ("validation_disabled", True), ("compiler_unchanged", False),
                           ("wall_s", float("nan")), ("thread_cpu_s", -1), ("process_cpu_s", float("inf"))):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(begin, {**end, key: value})

    def test_missing_or_changed_bytecode_cannot_report_success(self):
        begin, end = self.records()
        with self.assertRaisesRegex(ValueError, "lacks valid"):
            self.validate(begin, {**end, "files": [item for item in end["files"] if item["file"] != "bytecode.bin"]})
        (self.root / "bytecode.bin").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "bytes changed"):
            self.validate(begin, end)

    def test_timeout_is_never_masked_by_late_zero_exit_or_complete_output(self):
        begin, end = self.records()
        limits = {"decision_elapsed_s": 1.0, "case_limit_s": 180.0}
        self.assertEqual(replay.result_status(True, 0, begin, end, **limits), "case_timeout")
        self.assertEqual(replay.result_status(False, 1, begin, end, **limits), "compile_failed")
        self.assertEqual(replay.result_status(False, 0, begin, None, **limits), "compile_failed")
        self.assertEqual(replay.result_status(False, 0, begin, end, **limits), "compile_completed")

    def test_monitor_late_exit_without_latched_timeout_is_not_success(self):
        begin, end = self.records()
        # Model the inherited monitor returning no timeout when its next poll
        # observes an already-exited process immediately after the hard limit.
        self.assertEqual(replay.result_status(False, 0, begin, end,
            decision_elapsed_s=180.001, case_limit_s=180.0), "deadline_not_proven")
        self.assertEqual(replay.result_status(False, 0, begin, end,
            decision_elapsed_s=179.999, case_limit_s=180.0), "compile_completed")

    def test_compiler_return_survives_incomplete_postprocessing(self):
        begin, end = self.records()
        returned = {key: begin[key] for key in ("case", "preflight", "pid", "tid", "flags1", "flags2")}
        returned.update({key: end[key] for key in ("hresult", "compile_succeeded", "wall_s", "thread_cpu_s", "process_cpu_s")})
        returned.update(thread_start={"kernel_100ns": 0, "user_100ns": 0},
                        thread_end={"kernel_100ns": 0, "user_100ns": 7500000},
                        process_start={"kernel_100ns": 0, "user_100ns": 0},
                        process_end={"kernel_100ns": 0, "user_100ns": 8000000})
        replay.validate_compile_return(begin, returned, None)
        self.assertEqual(replay.result_status(True, -1, begin, None,
            decision_elapsed_s=180.0, case_limit_s=180.0), "case_timeout")
        final = {**end, **returned}
        replay.validate_compile_return(begin, returned, final)
        with self.assertRaisesRegex(ValueError, "changed the recorded"):
            replay.validate_compile_return(begin, returned, {**final, "wall_s": 0.5})
        with self.assertRaisesRegex(ValueError, "no retained compile return"):
            replay.validate_compile_return(begin, None, final)
        with self.assertRaisesRegex(ValueError, "original counters"):
            replay.validate_compile_return(begin, {**returned, "thread_cpu_s": 0.1}, None)


if __name__ == "__main__":
    unittest.main(verbosity=2)
