#!/usr/bin/env python3
"""Offline adverse controls; synthetic records are test doubles, never FXC results.

No compiler, graphics device, GPU or Godot process is invoked. --source optionally
checks real authenticated generation as well as the always-run synthetic custody
and decision tests. unittest assertions remain enabled under python -O.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import run_pace003_decomposition as harness

SOURCE_PATH: Path | None = None


class CustodyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def original_fixture(self, mutate=None, *, extra=None, compiler=None):
        """Synthetic ZIP with independently patched outer identity constants."""
        source = b"synthetic offline capture; never valid production evidence\n"
        begin = {"event": "compile_begin", "call": 44, "api": "D3DCompile",
                 "flags1": 0xC000, "flags2": 0, "include_pointer_present": False,
                 "secondary_flags": 0, "secondary_size": 0,
                 "source_name": {"value": "C:\\fakepath", "truncated": False},
                 "entry": {"value": "main", "truncated": False},
                 "target": {"value": "ps_5_0", "truncated": False},
                 "defines_present": True, "defines_truncated": False,
                 "defines": [{"name": {"value": "ANGLE_ENABLE_LOOP_FLATTEN", "truncated": False},
                              "definition": {"value": "1", "truncated": False}}],
                 "source": {"file": Path(harness.HLSL_PATH).name, "bytes": len(source),
                            "written": len(source), "complete": True}}
        if mutate:
            mutate(begin)
        compiler = compiler or harness.COMPILER_SHA256
        identity = {"event": "identity", "system_sha256": compiler,
                    "expected_system_sha256": compiler}
        archive = self.root / "synthetic-original.zip"
        with zipfile.ZipFile(archive, "w") as output:
            output.writestr(harness.TRACE_PATH, json.dumps(identity) + "\n" + json.dumps(begin) + "\n")
            output.writestr(harness.HLSL_PATH, source)
            output.writestr(harness.MANIFEST_PATH, json.dumps({"system_original": {"sha256": compiler}}))
            if extra:
                # ZipInfo normalizes the platform separator on both creation
                # and reading. Write a portable safe name, then mutate both
                # local and central directory names after the ZIP is closed.
                # This ensures the negative contains actual raw backslash
                # bytes on Windows as well as POSIX; writestr alone does not.
                output.writestr(extra.replace("\\", "/"), b"forbidden entry")
        if extra and "\\" in extra:
            encoded_safe = extra.replace("\\", "/").encode("ascii")
            encoded_raw = extra.encode("ascii")
            raw = archive.read_bytes()
            self.assertEqual(len(encoded_safe), len(encoded_raw))
            self.assertEqual(raw.count(encoded_safe), 2)
            archive.write_bytes(raw.replace(encoded_safe, encoded_raw))
        metadata = self.root / "metadata.json"
        metadata.write_text(json.dumps({"id": harness.ARTIFACT_ID,
                                       "workflow_run": {"id": harness.RUN_ID}, "expired": False}))
        constants = {"ARTIFACT_BYTES": archive.stat().st_size,
                     "ARTIFACT_SHA256": harness.sha256(archive.read_bytes()),
                     "SOURCE_BYTES": len(source), "SOURCE_SHA256": harness.sha256(source)}
        return archive, metadata, constants

    def records(self, *, rejected=False):
        """Construct clearly labelled blobs and counters without native execution."""
        name = "invalid-source" if rejected else "ordinary"
        source = b"synthetic generated input for offline record validation\n"
        generated = {"test_double": True, "case": name, "source_sha256": harness.sha256(source)}
        (self.root / "inputs").mkdir(exist_ok=True)
        (self.root / "inputs" / (name + ".hlsl")).write_bytes(source)
        (self.root / "captured-call44.hlsl").write_bytes(b"synthetic original")
        row_dir = self.root / name
        row_dir.mkdir(exist_ok=True)
        begin = {"case": name, "pid": 123, "tid": 456, "preflight": False,
                 "source_sha256": harness.sha256(source), "source_bytes": len(source),
                 "generator_receipt_sha256": harness.sha256(harness.json_bytes(generated)),
                 "flags1": 0xC000, "flags2": 0, "source_name": "C:\\fakepath", "entry": "main",
                 "target": "ps_5_0", "include_pointer_present": False,
                 "macros": [["ANGLE_ENABLE_LOOP_FLATTEN", "1"]],
                 "compiler": {"sha256": harness.COMPILER_SHA256}}
        returned = {key: begin[key] for key in ("case", "preflight", "pid", "tid", "flags1", "flags2")}
        returned.update(hresult=0x80004005 if rejected else 0,
                        compile_succeeded=not rejected, wall_s=1.0,
                        thread_cpu_s=0.75, process_cpu_s=0.8,
                        thread_start={"kernel_100ns": 0, "user_100ns": 0},
                        thread_end={"kernel_100ns": 0, "user_100ns": 7500000},
                        process_start={"kernel_100ns": 0, "user_100ns": 0},
                        process_end={"kernel_100ns": 0, "user_100ns": 8000000})
        blobs = {"messages.bin": b"synthetic PACE003_EXPECTED_INVALID_SOURCE_CONTROL rejection"} if rejected else {
            "bytecode.bin": b"DXBC-synthetic-test-double", "disassembly.txt": b"synthetic assembly test double"}
        for filename, data in blobs.items():
            (row_dir / filename).write_bytes(data)
        end = {**returned, "compiler_unchanged": True, "validation_disabled": False,
               "files": [harness.record(row_dir / filename) for filename in blobs],
               "disassembly_hresult": None if rejected else 0}
        return row_dir, source, generated, begin, returned, end

    def validate(self, fixture, *, begin=None, end=None):
        row_dir, source, generated, original_begin, _, original_end = fixture
        with patch.object(harness, "generate_case", return_value=(source, generated)):
            harness.validate_child_records(row_dir, original_begin if begin is None else begin,
                original_end if end is None else end, name=original_begin["case"], flags=0xC000,
                preflight=False, pid=123, compiler_sha256=harness.COMPILER_SHA256)

    def test_synthetic_original_reader_positive_and_no_execution(self):
        archive, metadata, constants = self.original_fixture()
        with patch.multiple(harness, **constants), patch.object(harness.subprocess, "Popen") as execute:
            source, receipt = harness.read_original(archive, metadata)
            self.assertEqual(harness.sha256(source), constants["SOURCE_SHA256"])
            self.assertEqual(receipt["original_call"]["flags1"], 0xC000)
            execute.assert_not_called()

    def test_archive_digest_and_captured_hlsl_digest_are_separate_guards(self):
        for key, message in (("ARTIFACT_SHA256", "ZIP identity"), ("SOURCE_SHA256", "HLSL identity")):
            archive, metadata, constants = self.original_fixture()
            constants[key] = "wrong"
            with self.subTest(key=key), patch.multiple(harness, **constants), self.assertRaisesRegex(ValueError, message):
                harness.read_original(archive, metadata)

    def test_metadata_identity_and_expiry_must_match(self):
        for field in ("id", "run", "expired"):
            archive, metadata, constants = self.original_fixture()
            value = json.loads(metadata.read_text())
            if field == "run":
                value["workflow_run"]["id"] += 1
            elif field == "expired":
                value[field] = True
            else:
                value[field] += 1
            metadata.write_text(json.dumps(value))
            with self.subTest(field=field), patch.multiple(harness, **constants), self.assertRaisesRegex(ValueError, "metadata mismatch"):
                harness.read_original(archive, metadata)

    def test_consistent_but_wrong_compiler_is_not_authentic(self):
        archive, metadata, constants = self.original_fixture(compiler="0" * 64)
        with patch.multiple(harness, **constants), self.assertRaisesRegex(ValueError, "compiler identities"):
            harness.read_original(archive, metadata)

    def test_macro_include_and_flags_cannot_drift(self):
        mutations = (lambda x: x.update(defines_truncated=True),
                     lambda x: x["defines"][0]["definition"].update(value="0"),
                     lambda x: x.update(include_pointer_present=True),
                     lambda x: x.update(flags1=0xC004), lambda x: x.update(flags1=0xC002))
        for number, mutate in enumerate(mutations):
            archive, metadata, constants = self.original_fixture(mutate)
            with self.subTest(number=number), patch.multiple(harness, **constants), self.assertRaises(ValueError):
                harness.read_original(archive, metadata)

    def test_archive_traversal_is_rejected_even_with_matching_digest(self):
        for extra in ("../escape", "C:/escape", "bad\\escape", "/absolute"):
            archive, metadata, constants = self.original_fixture(extra=extra)
            with self.subTest(extra=extra), patch.multiple(harness, **constants), self.assertRaisesRegex(ValueError, "Unsafe"):
                harness.read_original(archive, metadata)

    def test_raw_backslash_is_rejected_after_windows_filename_normalization(self):
        archive, metadata, constants = self.original_fixture(extra="bad\\escape")
        # Emulate the ZipInfo platform normalization on every host. The stored
        # orig_filename must retain the adversarial bytes even when filename
        # is rewritten to an apparently safe portable path.
        with patch.object(zipfile.os, "sep", "\\"):
            with zipfile.ZipFile(archive) as retained:
                entry = retained.infolist()[-1]
                self.assertEqual(entry.orig_filename, "bad\\escape")
                self.assertEqual(entry.filename, "bad/escape")
            with patch.multiple(harness, **constants), self.assertRaisesRegex(ValueError, "Unsafe"):
                harness.read_original(archive, metadata)

    def test_original_outputs_cannot_be_overwritten(self):
        target = self.root / "original.json"
        harness.write_new(target, b"first original")
        with self.assertRaises(FileExistsError):
            harness.write_new(target, b"replacement")
        self.assertEqual(target.read_bytes(), b"first original")

    def test_child_receipt_binds_process_generator_api_and_compiler(self):
        fixture = self.records()
        self.validate(fixture)
        for key, value in (("pid", 999), ("tid", 0), ("source_sha256", "wrong"),
                           ("generator_receipt_sha256", "wrong"), ("flags1", 0xC004),
                           ("flags2", 1), ("entry", "other"), ("target", "ps_4_0"),
                           ("include_pointer_present", True), ("macros", []),
                           ("compiler", {"sha256": "other"})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(fixture, begin={**fixture[3], key: value})

    def test_retained_generated_source_bytes_are_checked(self):
        fixture = self.records()
        (self.root / "inputs/ordinary.hlsl").write_bytes(b"changed input")
        with self.assertRaisesRegex(ValueError, "registered generation"):
            self.validate(fixture)

    def test_no_begin_cannot_have_a_completed_end(self):
        fixture = self.records()
        with self.assertRaisesRegex(ValueError, "no retained begin"):
            harness.validate_child_records(fixture[0], None, fixture[5], name="ordinary", flags=0xC000,
                                          preflight=False, pid=123, compiler_sha256=harness.COMPILER_SHA256)

    def test_hresult_timing_and_validation_contradictions_are_rejected(self):
        fixture = self.records()
        for key, value in (("hresult", 0x80004005), ("compile_succeeded", False),
                           ("compiler_unchanged", False), ("validation_disabled", True),
                           ("wall_s", float("nan")), ("thread_cpu_s", -1), ("process_cpu_s", float("inf"))):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.validate(fixture, end={**fixture[5], key: value})

    def test_missing_duplicate_or_unregistered_output_is_rejected(self):
        fixture = self.records()
        outputs = fixture[5]["files"]
        for files in (outputs[:1], outputs + outputs[:1], [{"file": "other.bin", "bytes": 1, "sha256": "x"}]):
            with self.subTest(files=files), self.assertRaises(ValueError):
                self.validate(fixture, end={**fixture[5], "files": files})

    def test_changed_bytecode_hash_and_non_dxbc_are_rejected(self):
        fixture = self.records()
        (fixture[0] / "bytecode.bin").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "bytes changed"):
            self.validate(fixture)
        refreshed = copy.deepcopy(fixture[5])
        refreshed["files"][0] = harness.record(fixture[0] / "bytecode.bin")
        with self.assertRaisesRegex(ValueError, "lacks valid"):
            self.validate(fixture, end=refreshed)

    def test_rejection_must_not_include_bytecode(self):
        fixture = self.records(rejected=True)
        self.validate(fixture)
        (fixture[0] / "bytecode.bin").write_bytes(b"DXBC-test-double")
        end = copy.deepcopy(fixture[5])
        end["files"].append(harness.record(fixture[0] / "bytecode.bin"))
        with self.assertRaisesRegex(ValueError, "unexpectedly has bytecode"):
            self.validate(fixture, end=end)

    def test_compile_return_is_required_before_final_result(self):
        fixture = self.records()
        begin, returned, end = fixture[3:]
        harness.validate_compile_return(begin, returned, end)
        harness.validate_compile_return(begin, returned, None)
        with self.assertRaisesRegex(ValueError, "no retained compile return"):
            harness.validate_compile_return(begin, None, end)
        with self.assertRaisesRegex(ValueError, "no retained begin"):
            harness.validate_compile_return(None, returned, end)

    def test_original_cpu_counters_and_recorded_durations_must_agree(self):
        fixture = self.records()
        begin, returned, end = fixture[3:]
        for key, value in (("thread_cpu_s", 0.1), ("process_cpu_s", 0.7),
                           ("thread_end", {"kernel_100ns": -1, "user_100ns": 7500000}),
                           ("process_start", {"kernel_100ns": 0, "user_100ns": 9000000})):
            with self.subTest(key=key), self.assertRaises(ValueError):
                harness.validate_compile_return(begin, {**returned, key: value}, None)
        with self.assertRaisesRegex(ValueError, "changed the recorded"):
            harness.validate_compile_return(begin, returned, {**end, "wall_s": 0.01})


class DecisionTests(unittest.TestCase):
    def row(self, name="ordinary", *, wall=1.0, process=1.5, rejected=False):
        returned = {"wall_s": wall, "hresult": 0x80004005 if rejected else 0,
                    "compile_succeeded": not rejected}
        row = {"name": name, "begin": {"case": name}, "compile_return": returned,
               "end": {**returned, "files": [{"file": "messages.bin", "bytes": 40}] if rejected else []},
               "returncode": 1 if rejected else 0, "timed_out": False,
               "completion_observed_within_limit": True,
               "completion_observation_elapsed_s": process,
               "diagnostic_control_marker": name == "invalid-source"}
        row["status"] = harness.classify_row(row)
        return row

    def matrix(self):
        return [self.row(name, rejected=name == "invalid-source") for name in harness.CASES]

    def test_valid_completed_rows_and_explicit_rejection(self):
        self.assertEqual(self.row()["status"], "compiled")
        self.assertEqual(self.row("invalid-source", rejected=True)["status"], "compiler_rejected")

    def test_crash_missing_return_or_empty_diagnostics_never_validate_rejection(self):
        original = self.row("invalid-source", rejected=True)
        changes = ({"returncode": -1073741819}, {"begin": None}, {"compile_return": None},
                   {"end": None}, {"end": {"compile_succeeded": False, "files": []}},
                   {"end": {"compile_succeeded": False, "files": [{"file": "messages.bin", "bytes": 0}]}})
        for changed in changes:
            with self.subTest(changed=changed):
                self.assertEqual(harness.classify_row({**original, **changed}), "apparatus_failed")

    def test_late_zero_exit_cannot_become_success(self):
        row = self.row()
        row.update(completion_observed_within_limit=False, completion_observation_elapsed_s=180.001)
        self.assertEqual(harness.classify_row(row), "deadline_not_proven")

    def test_timeout_before_and_after_compiler_return_are_distinct(self):
        row = self.row()
        row.update(timed_out=True, completion_observed_within_limit=False)
        self.assertEqual(harness.classify_row(row), "postprocessing_timeout")
        row.update(compile_return=None, end=None)
        self.assertEqual(harness.classify_row(row), "compiler_timeout")

    def test_all_complete_families_have_measured_serial_sums(self):
        result = harness.adjudicate(self.matrix(), [])
        self.assertEqual(result["decision"], "GO_PROTOTYPE")
        self.assertEqual(result["families"]["coarse"]["serial_compile_wall_s"], 3.0)
        self.assertEqual(result["families"]["coarse"]["serial_process_observation_s"], 4.5)
        self.assertEqual(result["families"]["fine-building"]["serial_compile_wall_s"], 6.0)
        self.assertFalse(result["graphical_qualification"])
        self.assertFalse(result["main_startup_qualified"])

    def test_serial_sum_cannot_be_replaced_by_fastest_or_max_member(self):
        rows = [self.row(name, wall=8.0, process=9.0, rejected=name == "invalid-source") for name in harness.CASES]
        result = harness.adjudicate(rows, [])
        self.assertEqual(result["decision"], "NO_GO_TESTED_DECOMPOSITION")
        self.assertEqual(result["families"]["coarse"]["serial_compile_wall_s"], 24.0)
        self.assertEqual(result["families"]["fine-building"]["serial_process_observation_s"], 54.0)

    def test_process_budget_is_required_even_when_compiler_budget_fits(self):
        rows = [self.row(name, wall=1.0, process=7.0, rejected=name == "invalid-source") for name in harness.CASES]
        result = harness.adjudicate(rows, [])
        self.assertEqual(result["families"]["coarse"]["serial_compile_wall_s"], 3.0)
        self.assertEqual(result["decision"], "NO_GO_TESTED_DECOMPOSITION")

    def test_monolith_timeout_does_not_invalidate_a_fast_complete_family(self):
        rows = self.matrix()
        row = next(item for item in rows if item["name"] == "original-control")
        row.update(timed_out=True, completion_observed_within_limit=False,
                   compile_return=None, end=None, returncode=-1, completion_observation_elapsed_s=180.01)
        row["status"] = harness.classify_row(row)
        result = harness.adjudicate(rows, [])
        self.assertEqual(result["decision"], "GO_PROTOTYPE")
        self.assertEqual(result["families"]["coarse"]["serial_compile_wall_s"], 3.0)

    def test_unexpected_fast_monolith_is_a_valid_reference(self):
        result = harness.adjudicate(self.matrix(), [])
        self.assertTrue(result["apparatus_completed"])
        self.assertTrue(result["controls_passed"])

    def test_fine_family_can_pass_when_coarse_building_is_rejected(self):
        rows = self.matrix()
        position = harness.CASES.index("building")
        rows[position] = self.row("building", rejected=True)
        result = harness.adjudicate(rows, [])
        self.assertEqual(result["families"]["coarse"]["decision"], "NO_GO_TESTED_FAMILY")
        self.assertIsNone(result["families"]["coarse"]["serial_compile_wall_s"])
        self.assertEqual(result["families"]["fine-building"]["decision"], "GO_PROTOTYPE")

    def test_missing_duplicate_or_reordered_cases_are_inconclusive(self):
        rows = self.matrix()
        for changed in (rows[:-1], rows + [copy.deepcopy(rows[-1])], [rows[1], rows[0], *rows[2:]],
                        [*rows[:-1], copy.deepcopy(rows[-2])]):
            with self.subTest(names=[item["name"] for item in changed]):
                result = harness.adjudicate(changed, [])
                self.assertEqual(result["decision"], "INCONCLUSIVE")
                self.assertFalse(result["apparatus_completed"])

    def test_absent_invalid_marker_or_failed_control_is_inconclusive(self):
        for changed in ({"diagnostic_control_marker": False}, {"status": "compiled"},
                        {"status": "compiler_timeout"}, {"status": "apparatus_failed"}):
            rows = self.matrix()
            rows[1].update(changed)
            with self.subTest(changed=changed):
                self.assertEqual(harness.adjudicate(rows, [])["decision"], "INCONCLUSIVE")

    def test_errors_and_unproved_deadlines_cannot_support_no_go_or_go(self):
        rows = self.matrix()
        self.assertEqual(harness.adjudicate(rows, ["custody failure"])["decision"], "INCONCLUSIVE")
        for status in ("deadline_not_proven", "postprocessing_timeout", "apparatus_failed"):
            changed = copy.deepcopy(rows)
            changed[3]["status"] = status
            with self.subTest(status=status):
                self.assertEqual(harness.adjudicate(changed, [])["decision"], "INCONCLUSIVE")


class AuthenticSourceTests(unittest.TestCase):
    def test_optional_authentic_input_generation_without_compiler(self):
        if SOURCE_PATH is None:
            self.skipTest("--source not supplied; synthetic custody tests still execute")
        original = SOURCE_PATH.read_bytes()
        harness.variants.validate_source(original)
        with patch.object(harness.subprocess, "Popen") as execute:
            for name in harness.CASES:
                source, receipt = harness.generate_case(original, name)
                self.assertTrue(source)
                self.assertIsInstance(receipt, dict)
                if name == "original-control":
                    self.assertEqual(source, original)
                elif name == "invalid-source":
                    self.assertEqual(source, harness.INVALID_PREFIX + original)
                elif name == "tiny-valid":
                    self.assertEqual(source, harness.PREFLIGHT_SOURCE)
            execute.assert_not_called()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source", type=Path)
    options, remaining = parser.parse_known_args()
    SOURCE_PATH = options.source
    unittest.main(argv=[__file__, *remaining], verbosity=2)
