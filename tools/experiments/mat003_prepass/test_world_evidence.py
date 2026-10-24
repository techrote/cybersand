#!/usr/bin/env python3
"""Negative tests of independent S1 readback; all fixtures here are fabricated.

These deliberately small byte streams test evidence rejection, not native
simulation behavior. They are never recorded as observed experiment results.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest

from world_verify import (checked_path, decode_snapshot, decode_trace, load_json,
                          verify_directory, verify_overlay, verify_receipt,
                          validate_result, validate_memory)

REGISTRATION = json.loads(Path(__file__).with_name("world_registration.json").read_text())


def result_fixture():
    """Shape-valid declared outcome; never evidence of executed native tests."""
    spec = next(row for row in REGISTRATION["arms"] if row["id"] == "C80-E16-split")
    def memory(cells):
        return {
            "resident_cells": cells, "cell_array_used_bytes": cells * 8,
            "cell_array_capacity_bytes": cells * 8, "temperature_capacity_bytes": 0,
            "activity_capacity_bytes": 16, "tail_capacity_bytes": cells * 2,
            "chunk_descriptor_bytes": 256, "scratch_capacity_bytes": 64,
            "world_object_bytes": 256, "legacy_aggregate_bytes": cells * 8 + 16,
            "allocator_overhead_bytes": None, "legacy_aggregate_is_component_sum_not_additive": True,
        }
    def trace(name, ticks, backend, workers):
        return {
            "name": name, "file": name + ".bin", "ticks": ticks, "frames": ticks + 1,
            "backend": backend, "workers": workers, "clears": [] if ticks == 2048 else [65536, 131071],
            "clear_observations": [] if ticks == 2048 else [
                {"tick": tick, "before": 65535, "after": 1, "sentinel_observed": True,
                 "sentinel_before": 65534, "sentinel_after": 0} for tick in (65536, 131071)],
            "water_initial": 73, "water_final": 73, "sand_initial": 1, "sand_final": 1,
            "maximum_observed_cells": 256,
            "dispatch": {"observed": True, "calls": int(workers == 4),
                         "dispatched_tasks": 2 if workers == 4 else 0,
                         "worker_tasks": 2 if workers == 4 else 0},
            "memory": memory(256),
        }
    result = {
        "schema_version": 1, "stage": "S1-World-correctness", "status": "passed",
        "arm_id": spec["id"], "logical_bits": 80, "epoch_bits": 16, "representation": "split",
        "cell_stride": 8, "cell_alignment": 8, "assertions": 1,
        "epoch_counter_bytes": 2, "epoch_accessor_bytes": 2,
        "ordinary": [trace("ordinary-serial", 2048, "serial", 1),
                     trace("ordinary-phased-1", 2048, "phased", 1),
                     trace("ordinary-phased-4", 2048, "phased", 4)],
        "natural": trace("natural", 131080, "phased", 1),
        "forced": [{"resident_side": side, "resident_cells": side * side,
                    "cleared_cells": side * side, "global_tick_before": 0, "global_tick_after": 2,
                    "non_epoch_preserved": True, "raw_storage_stress": True, "natural_run": False,
                    "memory": memory(side * side)} for side in (512, 1024, 2048)],
        "lifecycle": {
            "checks": ["signed_move_swap_temperature_neutral_tail",
                       "partial_full_water_and_replacement_reset",
                       "new_water_destination_changed_write_and_noop_payload",
                       "admission_clear_replacement_first_update", "general_scan_path_signed_seam",
                       "failed_rollover_quarantine_clear_recovery",
                       "configured_transport_current_stamp_rejection_and_stale_pickup"],
            "configured_transport_grain_events": 1,
            "neutral_payload_is_synthetic": True, "high_a16_is_inert_raw_storage_probe": True,
            "coverage_gaps": ["Fabricated test fixture, not observed evidence."],
        },
        "scope": {"production_changed": False, "primary_timing": False, "natural_real_world": True},
    }
    return result, spec


class ResultContracts(unittest.TestCase):
    def test_shape_valid_fixture_is_accepted_but_is_not_execution_evidence(self):
        result, spec = result_fixture()
        self.assertEqual(validate_result(result, REGISTRATION, spec), [])

    def test_real_counter_and_accessor_types_required(self):
        for field in ("epoch_counter_bytes", "epoch_accessor_bytes"):
            result, spec = result_fixture()
            result[field] = 1
            self.assertTrue(validate_result(result, REGISTRATION, spec))

    def test_missing_natural_clear_cannot_qualify(self):
        result, spec = result_fixture()
        result["natural"]["clears"].pop()
        self.assertTrue(validate_result(result, REGISTRATION, spec))

    def test_labels_cannot_substitute_for_observed_typed_wrap(self):
        result, spec = result_fixture()
        result["natural"]["clear_observations"][0]["before"] = 255
        self.assertTrue(validate_result(result, REGISTRATION, spec))
        result, spec = result_fixture()
        result["natural"]["clear_observations"][1]["sentinel_after"] = 65534
        self.assertTrue(validate_result(result, REGISTRATION, spec))

    def test_vacuous_transport_entry_cannot_qualify_pickup(self):
        result, spec = result_fixture()
        result["lifecycle"]["configured_transport_grain_events"] = 0
        self.assertTrue(validate_result(result, REGISTRATION, spec))

    def test_actual_worker_execution_required(self):
        result, spec = result_fixture()
        result["ordinary"][2]["dispatch"]["worker_tasks"] = 0
        self.assertTrue(validate_result(result, REGISTRATION, spec))

    def test_duplicate_fixture_and_truncated_forced_membership_rejected(self):
        result, spec = result_fixture()
        result["ordinary"][1] = copy.deepcopy(result["ordinary"][0])
        self.assertTrue(validate_result(result, REGISTRATION, spec))
        result, spec = result_fixture()
        result["forced"][2]["cleared_cells"] -= 1
        self.assertTrue(validate_result(result, REGISTRATION, spec))

    def test_split_allocation_cannot_disappear(self):
        result, spec = result_fixture()
        memory = result["ordinary"][0]["memory"]
        memory["tail_capacity_bytes"] = 0
        self.assertTrue(validate_memory(memory, spec, 8))

    def test_aggregate_is_not_an_extra_memory_component(self):
        result, spec = result_fixture()
        memory = result["ordinary"][0]["memory"]
        memory["legacy_aggregate_bytes"] += memory["tail_capacity_bytes"]
        self.assertTrue(validate_memory(memory, spec, 8))

    def test_skip_and_invented_scope_rejected(self):
        result, spec = result_fixture()
        result["status"] = "skipped"
        result["scope"]["production_changed"] = True
        self.assertTrue(validate_result(result, REGISTRATION, spec))


def snapshot(tick=0, *, water_ledger=73, material_count=132):
    """Small explicit records, assembled independently from the native writer."""
    raw = bytearray()
    def put(fmt, *args):
        raw.extend(struct.pack("<" + fmt, *args))
    put("QQBBII", tick, tick, 0, 1, 8, 1)
    put("qqI", -1, -2, 64)
    cells = [(0, 0, 0, 200, 0)] * 64
    cells[0] = (3, 73, 0, 200, 0)
    cells[1] = (2, 17, 23, 777, 0)
    cells[2] = (0, 7, 91, 200, 0)
    cells[3] = (1, 65535, 255, -32768, 0)  # Explicit raw inert a16 sentinel.
    for cell in cells:
        put("HHBhB", *cell)
    put("I", 1)
    put("QIBB", 0, 3, 0, 0)
    put("QIBBBiiii", 3, 3, 0, 0, 0, 0, 0, 0, 0)
    put("BBB", 0, 0, 0)
    put("I", 0)
    put("Q", 0)
    put("Q" * 15, tick, *([0] * 14))
    put("QQI", water_ledger, 1, material_count)
    species = [0] * material_count
    species[0], species[1], species[2], species[3] = 61, 1, 1, 1
    put("Q" * material_count, *species)
    put("IqqBB", 1, -7, -15, 0, 0)
    put("IQ", 0, 0)
    return bytes(raw)


def full_frame(raw):
    return struct.pack("<IIII", len(raw), 1, 0, len(raw)) + raw


class TraceContracts(unittest.TestCase):
    def test_decoder_preserves_full_a16_empty_and_signed_temperature(self):
        observed = decode_snapshot(snapshot())
        self.assertEqual(observed["water"], 73)
        self.assertEqual(observed["sand"], 1)
        self.assertEqual(observed["high_a_cells"], 1)
        self.assertEqual(observed["nonzero_empty_cells"], 1)
        self.assertEqual(observed["nonambient_cells"], 2)
        self.assertEqual(observed["cells"], 64)

    def test_independent_mass_reduction_rejects_false_ledger(self):
        with self.assertRaisesRegex(ValueError, "reduction disagrees"):
            decode_snapshot(snapshot(water_ledger=74))

    def test_full_species_domain_is_required(self):
        with self.assertRaisesRegex(ValueError, "frozen catalogue"):
            decode_snapshot(snapshot(material_count=131))

    def test_truncated_or_trailing_fields_rejected(self):
        for raw in (snapshot()[:-1], snapshot() + b"\0"):
            with self.assertRaises(ValueError):
                decode_snapshot(raw)

    def test_invalid_material_cannot_hide_in_an_empty_slot(self):
        raw = bytearray(snapshot())
        # 26-byte global header + 20-byte chunk header = first material.
        struct.pack_into("<H", raw, 46, 10)
        with self.assertRaisesRegex(ValueError, "invalid material"):
            decode_snapshot(bytes(raw))

    def test_nonempty_bookkeeping_checked_against_cells(self):
        raw = bytearray(snapshot())
        nonempty_offset = 26 + 20 + 64 * 8 + 4 + 14
        struct.pack_into("<Q", raw, nonempty_offset, 4)
        with self.assertRaisesRegex(ValueError, "nonempty bookkeeping"):
            decode_snapshot(bytes(raw))

    def test_delta_replay_accepts_actual_changed_tick_bytes(self):
        first, second = snapshot(0), snapshot(1)
        differing = [index for index, (a, b) in enumerate(zip(first, second)) if a != b]
        ranges = b"".join(struct.pack("<II", offset, 1) + second[offset:offset + 1]
                          for offset in differing)
        data = (b"M3WDEL1\n" + full_frame(first)
                + struct.pack("<II", len(second), len(differing)) + ranges)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.bin"
            path.write_bytes(data)
            result = decode_trace(path, 1)
            self.assertEqual(result["frames"], 2)
            self.assertTrue(result["water_constant"])
            self.assertEqual(result["final"]["tick"], 1)

    def test_missing_tick_and_wrong_horizon_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.bin"
            path.write_bytes(b"M3WDEL1\n" + full_frame(snapshot(0)) + full_frame(snapshot(2)))
            with self.assertRaisesRegex(ValueError, "skipped, duplicated"):
                decode_trace(path, 2)
            path.write_bytes(b"M3WDEL1\n" + full_frame(snapshot(0)))
            with self.assertRaisesRegex(ValueError, "tick horizon"):
                decode_trace(path, 131080)

    def test_delta_overlaps_and_bounds_rejected(self):
        raw = snapshot()
        invalid_frames = [
            struct.pack("<IIII", len(raw), 1, len(raw), 1) + b"x",
            struct.pack("<IIII", len(raw), 2, 0, 2) + b"xx" + struct.pack("<II", 1, 1) + b"x",
            struct.pack("<IIII", len(raw), 1, 0, 0),
        ]
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.bin"
            for frame in invalid_frames:
                path.write_bytes(b"M3WDEL1\n" + full_frame(raw) + frame)
                with self.assertRaises(ValueError):
                    decode_trace(path)

    def test_missing_full_initial_record_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.bin"
            path.write_bytes(b"M3WDEL1\n" + struct.pack("<II", len(snapshot()), 0))
            with self.assertRaisesRegex(ValueError, "initial exact snapshot"):
                decode_trace(path)


class ArtifactContracts(unittest.TestCase):
    def test_path_escape_and_windows_drive_rejected(self):
        for name in ("../run.json", "/tmp/outside", "C:/outside", "..\\outside", ""):
            with self.assertRaises(ValueError):
                checked_path(Path("/tmp/fixture"), name)

    def test_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "outside").symlink_to("/tmp")
            with self.assertRaises(ValueError):
                checked_path(root, "outside/escape.json")

    def test_duplicate_json_fields_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.json"
            path.write_text('{"status":"passed","status":"failed"}')
            with self.assertRaisesRegex(ValueError, "duplicate JSON"):
                load_json(path)

    def test_hash_tamper_and_missing_artifacts_fail_directory_readback(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            original = b"retained fixture"
            (root / "run.json").write_text(json.dumps({
                "schema_version": 1, "stage": "S1-World-correctness", "status": "passed",
                "files": {"evidence.bin": {"bytes": len(original),
                         "sha256": hashlib.sha256(original).hexdigest()}}}))
            self.assertEqual(verify_directory(root)["status"], "failed")
            (root / "evidence.bin").write_bytes(b"altered fixture")
            self.assertTrue(any("identity mismatch" in error for error in verify_directory(root)["errors"]))

    def test_receipt_checks_timeout_failure_flags_and_raw_streams(self):
        files = {"out": {}, "err": {}}
        valid = {"command": ["g++", "-O2", "input.cpp"], "timeout_seconds": 240,
                 "exit_code": 0, "timed_out": False, "stdout": "out", "stderr": "err"}
        self.assertEqual(verify_receipt(Path("/tmp/fixture"), valid, files, "compile", 240, ["-O2"]), [])
        for field, value in (("exit_code", 1), ("exit_code", False), ("timed_out", True),
                             ("timeout_seconds", 241), ("stderr", "missing"),
                             ("command", ["g++", "-O0", "input.cpp"])):
            altered = copy.deepcopy(valid); altered[field] = value
            self.assertTrue(verify_receipt(Path("/tmp/fixture"), altered, files, "compile", 240, ["-O2"]))

    def test_developer_and_failed_status_never_qualify(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "run.json").write_text(json.dumps({"status": "failed", "developer_attempt": True,
                                                      "files": {}}))
            result = verify_directory(root)
            self.assertEqual(result["status"], "failed")
            self.assertTrue(any("developer subset" in error for error in result["errors"]))
            self.assertTrue(any("did not complete" in error for error in result["errors"]))

    def test_rehashed_source_control_change_still_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            files = {}
            def retain(name, raw):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
                files[name] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
            original = b"// Deliberately fabricated native source for verifier test.\n"
            relative = "native/src/world.cpp"
            retain("source/" + relative, original)
            retain("arm/overlay/" + relative, original)
            spec = {"id": "C64-E8-source", "representation": "source", "logical_bits": 64,
                    "epoch_bits": 8, "neutral_extra_bits": 0}
            registration = {"baseline_control_sha256": {relative: hashlib.sha256(original).hexdigest()}}
            registration_name = "tools/experiments/mat003_prepass/world_registration.json"
            raw_registration = json.dumps(registration).encode()
            retain("source/" + registration_name, raw_registration)
            retain("arm/overlay/" + registration_name, raw_registration)
            world_source = "/retained/arm/overlay/native/src/world.cpp"
            manifest = {
                "schema_version": 1, "arm": spec, "source_control_unchanged": True,
                "dispatch_observed": False, "split_tail_allocation": "inapplicable", "patches": [],
                "registration_sha256": hashlib.sha256(raw_registration).hexdigest(),
                "world_source": world_source,
                "compile_definitions": ['-DMAT003_ARM_ID="C64-E8-source"', '-DMAT003_STORAGE_KIND=0',
                    '-DMAT003_EPOCH_BITS=8', '-DMAT003_EXTRA_BYTES=0', '-DMAT003_SPLIT=0',
                    '-DMAT003_WORLD_SOURCE="' + world_source + '"'],
                "files": [{"path": relative, "input_sha256": hashlib.sha256(original).hexdigest(),
                           "output_sha256": hashlib.sha256(original).hexdigest()}],
            }
            name = "arm/overlay/overlay.json"
            retain(name, json.dumps(manifest).encode())
            self.assertEqual(verify_overlay(root, name, spec, registration, files), [])
            altered = original + b"// changed behavior\n"
            retain("arm/overlay/" + relative, altered)
            manifest["files"][0]["output_sha256"] = hashlib.sha256(altered).hexdigest()
            retain(name, json.dumps(manifest).encode())
            errors = verify_overlay(root, name, spec, registration, files)
            self.assertTrue(any("original source control was changed" in error for error in errors))

    def test_unreadable_overlay_cannot_be_a_success(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            errors = verify_overlay(root, "missing.json", {"id": "fake"}, {}, {})
            self.assertTrue(errors)


if __name__ == "__main__":
    unittest.main()
