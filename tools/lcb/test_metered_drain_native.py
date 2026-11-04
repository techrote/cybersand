"""Adversarial qualification-runner tests; every result packet is synthetic.

These execute no World, Godot, Rapier or desktop input. The invented packets
exercise strict parsing only and must never be published as native evidence.
"""
from __future__ import annotations

import contextlib
import copy
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import run_metered_drain_native as runner


def synthetic_packet() -> dict:
    """Independent compact valid shape, not a captured executable result."""
    axes = (
        ("water-in-3", 3, 7, 112), ("water-in-8", 8, 255, 4080),
        ("water-fm-3", 3, 3, 54), ("water-fm-8", 8, 3, 1834),
        ("brine-cy-8", 8, 1, 16), ("brine-in-8", 8, 1, 16),
        ("water-cy-3", 3, 7, 112), ("water-cy-8", 8, 255, 4080),
    )
    rows = []
    for profile, bits, single, multi in axes:
        water = profile.startswith("water")
        for count, quantity in ((1, single), (16, multi)):
            rows.append({
                "case_id": f"exact.{profile}.{count}", "status": "pass",
                "cells": count, "water_units": quantity if water else 0,
                "brine_cells": 0 if water else quantity, "initial_quantity": quantity,
                "remaining_quantity": 0, "remaining_resource": 11,
                "native_water_sink_delta": quantity if water else 0,
                "mass_bits": bits, "policy_hash": "0" * 64,
            })
        initial = 1296 * (((1 << bits) - 1) if water else 1)
        removed = ((1 << bits) - 1) if water and "-fm-" not in profile else 1
        rows.append({
            "case_id": f"workers.{profile}", "status": "pass", "ticks_per_arm": 64,
            "initial_quantity": initial, "removed_quantity": removed,
            "remaining_quantity": initial - removed, "operations_per_arm": 1,
            "maximum_cells_per_operation": 16, "workers1_observed": 1,
            "workers4_observed": 4, "phase_jobs_workers4": 1,
            "moved_cells_after_stop_workers1": 1, "moved_cells_after_stop_workers4": 1,
            "water_units": removed if water else 0, "brine_cells": 0 if water else removed,
            "physical_hash_parity": True, "inertial_ledger_parity": True,
            "resident_census_cells": 131072, "resident_census_ticks": [0, 8, 20, 32, 64],
            "resident_domain_chunk_count": 8,
            "flow_initial_water_model": "whole-cells-for-matched-geometry",
        })
    controls = {
        "refusal.complete-preflight": {
            "refusals": 16, "motion_witness": True, "spatial_wall_checks": True,
        },
        "hazard.raw-empty-under-mask": {
            "profiles": 8, "guarded_refusal_preserves_state": True,
            "raw_erasure_removes_stored_material": True,
        },
        "refusal.policy-and-fractional-whole-cell": {
            "water_quanta": [7, 255], "pressure_world_refused": True,
            "oil_in_refused": True, "water_cy_full_cells_only": True,
        },
        "capacity.resident-erase-and-failed-tick": {
            "resident_erase_at_chunk_limit": True, "failed_tick_quarantined": True,
            "clear_recovery": True,
        },
        "lifecycle.native-retirement-persistence-reconstruction": {
            "profiles": 8, "continuation_ticks_per_profile": 8,
            "native_motion_witness": True, "inertial_ledger_continuation_parity": True,
            "application_lifecycle_tested": False,
        },
        "oracle.complete-resident-census": {
            "resident_cells": 131072, "resident_chunks": 8, "negative_controls": 5,
        },
    }
    rows.extend({"case_id": key, "status": "pass", **value} for key, value in controls.items())
    return {
        "schema": "metered-drain-native-primitives-v1", "scope": "native-core-only",
        "production_application_executed": False, "status": "pass",
        "assertions": 1000, "cases": rows,
    }


def worker(packet: dict) -> dict:
    return next(row for row in packet["cases"] if row["case_id"].startswith("workers."))


class ParserControls(unittest.TestCase):
    def setUp(self) -> None:
        self.packet = synthetic_packet()

    def reject(self, edit) -> None:
        altered = copy.deepcopy(self.packet)
        edit(altered)
        with self.assertRaises(ValueError):
            runner.parse_result(json.dumps(altered))

    def test_valid_synthetic_shape(self):
        self.assertEqual(runner.parse_result(json.dumps(self.packet)), self.packet)

    def test_missing_case(self):
        self.reject(lambda p: p["cases"].pop())

    def test_duplicate_case(self):
        self.reject(lambda p: p["cases"].__setitem__(-1, copy.deepcopy(p["cases"][0])))

    def test_boolean_cell_count(self):
        self.reject(lambda p: p["cases"][0].__setitem__("cells", True))

    def test_floating_quantity(self):
        self.reject(lambda p: p["cases"][0].__setitem__("water_units", 7.0))

    def test_wrong_water_units(self):
        self.reject(lambda p: p["cases"][0].__setitem__("water_units", 255))

    def test_brine_as_water_quantity(self):
        self.reject(lambda p: next(r for r in p["cases"] if r["case_id"] == "exact.brine-cy-8.1")
                    .__setitem__("water_units", 201))

    def test_wrong_native_sink(self):
        self.reject(lambda p: p["cases"][0].__setitem__("native_water_sink_delta", 0))

    def test_application_scope_overclaim(self):
        self.reject(lambda p: p.__setitem__("production_application_executed", True))

    def test_configured_workers_without_actual_claimants(self):
        self.reject(lambda p: worker(p).__setitem__("workers4_observed", 1))

    def test_boolean_claimant_count(self):
        self.reject(lambda p: worker(p).__setitem__("workers4_observed", True))

    def test_unexplained_quantity_residual(self):
        self.reject(lambda p: worker(p).__setitem__("remaining_quantity", 0))

    def test_physical_hash_mismatch(self):
        self.reject(lambda p: worker(p).__setitem__("physical_hash_parity", False))

    def test_unknown_field(self):
        self.reject(lambda p: p.__setitem__("native_receipt", "fabricated"))

    def test_inertial_ledger_mismatch(self):
        self.reject(lambda p: worker(p).__setitem__("inertial_ledger_parity", False))

    def test_incomplete_resident_domain(self):
        self.reject(lambda p: worker(p).__setitem__("resident_census_cells", 3040))

    def test_extra_resident_chunk(self):
        self.reject(lambda p: worker(p).__setitem__("resident_domain_chunk_count", 9))

    def test_vacuous_census(self):
        self.reject(lambda p: worker(p).__setitem__("resident_census_ticks", []))

    def test_duplicate_json_key(self):
        raw = json.dumps(self.packet)
        with self.assertRaisesRegex(ValueError, "duplicate JSON field"):
            runner.parse_result(raw.replace('"status": "pass"', '"status": "pass", "status": "pass"', 1))

    def test_trailing_json(self):
        with self.assertRaises(ValueError):
            runner.parse_result(json.dumps(self.packet) + "{}")

    def test_nonfinite_json(self):
        with self.assertRaisesRegex(ValueError, "nonfinite"):
            runner.parse_result(json.dumps(self.packet).replace('"assertions": 1000', '"assertions": NaN'))


class OutputCustodyControls(unittest.TestCase):
    def test_existing_output_refused_without_rewriting_previous_record_or_executable(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            previous_record = directory / "record.json"
            previous_binary = directory / "metered_drain"
            previous_record.write_text('{"status":"previous-result-must-remain-historical"}')
            previous_binary.write_bytes(b"previous-executable-must-not-be-reused")
            record_bytes, binary_bytes = previous_record.read_bytes(), previous_binary.read_bytes()
            with patch.object(sys, "argv", ["runner", "--output-dir", str(directory)]), \
                    patch.object(runner, "command") as command, \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(runner.main(), 1)
                command.assert_not_called()
            self.assertEqual(previous_record.read_bytes(), record_bytes)
            self.assertEqual(previous_binary.read_bytes(), binary_bytes)

    def test_successful_compiler_exit_without_new_binary_is_failed_never_run(self):
        # No compiler is executed: command() is a deliberate zero-exit double.
        # The existing interpreter only supplies stable file/version metadata.
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "fresh"
            with patch.object(sys, "argv", ["runner", "--output-dir", str(directory)]), \
                    patch.object(runner.shutil, "which", return_value=sys.executable), \
                    patch.object(runner, "command", return_value=0) as command, \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(runner.main(), 1)
                self.assertEqual(command.call_count, 1)
                self.assertEqual(command.call_args.args[3], "compile")
            record = json.loads((directory / "record.json").read_text())
            self.assertEqual(record["status"], "failed")
            self.assertNotIn("run_exit", record)
            self.assertNotIn("results", record)
            self.assertFalse((directory / "metered_drain").exists())
            self.assertFalse((directory / "metered_drain.exe").exists())


if __name__ == "__main__":
    unittest.main()
