#!/usr/bin/env python3
"""Hermetic tests for the LCB-FEEL #360 preflight reducer.

The reducer must accept a complete, internally consistent synthetic receipt
pair and must stop, never repair, on each registered violation class.
"""
from __future__ import annotations

import copy
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import feel_preflight as fp  # noqa: E402

REGISTRATION = json.loads((fp.ROOT / fp.DEFAULT_REGISTRATION).read_text(encoding="utf-8"))
SCENARIO = REGISTRATION["scenarios"][0]
DEFAULTS = [{"material": 3, "name": "water", "applied_family": "freemass_v1", "applied_variant": "reference"},
            {"material": 16, "name": "oil", "applied_family": "cellular_yield_v1", "applied_variant": "reference"},
            {"material": 24, "name": "brine", "applied_family": "cellular_yield_v1", "applied_variant": "reference"}]
QUANTITY = SCENARIO["expected"]["initial_water_quantity"]
GATE = {"tick": 0, "kind": "erase", "x": 232, "y": 64, "width": 8, "height": 192,
        "material": 0, "normalized_mass": 0, "coherence": 0}


def census(walls: int, family: str) -> dict:
    water_cells = QUANTITY // 255
    inertial = {"available": False}
    if family == "inertial_cellular_v1":
        inertial = {"available": True, "complete": True, "inertial_cells": water_cells, "negative_vy_cells": 0,
                    "moving_cells": 0, "nonzero_accumulator_cells": 0, "sum_abs_vx": 0, "sum_vy": 0,
                    "max_abs_vx": 0, "max_vy": 0, "tuple_sha256": "00"}
    pressure = {"available": False}
    if family == "pressure_flow_v1":
        pressure = {"available": True, "gas_ledger_closes": True, "ledger": {"overfill_converted": 0},
                    "gas_ledger": {"created": 0}, "compartments": 0}
    return {"health": {"failed": False, "tick_failure_count": 0, "last_tick_error": "", "attempted_tick": 30, "tick_index": 30},
            "water": {"quantity": QUANTITY, "visible": QUANTITY, "overfill": 0, "water_cells": water_cells},
            "inventory": {"complete": True, "counts": {"1": walls, "3": water_cells, "0": 1024 * 1024 - walls - water_cells}},
            "physical_state_hash": "abc", "inertial": inertial, "pressure": pressure}


def receipt(case: dict) -> dict:
    assignments = copy.deepcopy(DEFAULTS)
    assignments[0]["applied_family"] = case["family"]
    walls = 16380
    initial = census(walls, case["family"])
    final = census(walls + SCENARIO["expected"]["wall_delta_after_tick_zero_events"], case["family"])
    ticks = [{"tick": index, "water_quantity": QUANTITY, "failed": False, "statistics_ok": True,
              "worker_threads_observed": min(case["workers"], 4),
              "native_tick_ms": 1.0, "host_advance_us": 1500, "phase_jobs": [4, 4], "scheduler_parallel_phases": 2,
              "moved_cells": 10, "chunk_allocations": 0, "physical_state_hash": f"h{index}"} for index in range(1, 31)]
    return {"schema": fp.RECEIPT_SCHEMA, "kind": "arm", "case_id": case["case_id"], "outcome": "completed",
            "requested": {"family": case["family"], "variant": case["variant"], "radius": case["radius"], "workers": case["workers"]},
            "fixture": {"id": SCENARIO["fixture_id"], "definition_hash": SCENARIO["definition_hash"]},
            "default_policy": copy.deepcopy(DEFAULTS),
            "applied": {"assignments": assignments, "maximum_rule_radius": case["radius"], "configured_workers": case["workers"],
                        "policy_hash": "p", "physical_state_hash_version": 2},
            "construction": {"maximum_rule_radius": case["radius"], "worker_threads": case["workers"], "run_intent": "controlled",
                             "receipt_hash": "r", "normalization": {"rule": "water-normalize-v1", "net_delta": 0, "positive_delta": 0,
                                                                    "negative_delta": 0, "water_before": QUANTITY, "water_after": QUANTITY}},
            "construction_us": 1000, "initial": initial, "final": final, "ticks": ticks,
            "host_ledger": {"source": 0, "sink": 0, "action_history": [
                {"tick": 0, "action": dict(GATE), "before_water_integer": 0, "after_water_integer": 0}]},
            "retirement": {"world_released": True}}


def arm_case(family: str = "inertial_cellular_v1", workers: int = 4) -> dict:
    arm = {"lane": "A", "role": "primary", "family": family, "variant": "reference", "radius": 3}
    return {"case_id": fp.case_id(SCENARIO["id"], arm, workers), "scenario": SCENARIO["id"], "workers": workers, **arm}


def negative() -> dict:
    def refused(code):
        return {"accepted": False, "previous_world_retained": True, "refusal": {"code": code}}
    return {"schema": fp.RECEIPT_SCHEMA, "kind": "negative", "outcome": "completed", "baseline_installed": True,
            "controls": [{"id": "inertial-water-radius-2", **refused("malformed_policy")},
                         {"id": "fractional-without-normalization-cellular_yield_v1", **refused("normalization_required")},
                         {"id": "fractional-without-normalization-inertial_cellular_v1", **refused("normalization_required")},
                         {"id": "fractional-with-normalization-cellular_yield_v1", "accepted": True, "cells": 18432,
                          "requested_fill_numerator_per_cell": 128, "maximum": 255,
                          "normalization": {"water_before": 128 * 18432, "water_after": 255 * 18432,
                                            "positive_delta": 127 * 18432, "negative_delta": 0}},
                         {"id": "pressure-for-material-16", "offered": [
                             {"variant": "reference", "accepted": False, "refusal": {"code": "combination_rejected"}}]},
                         {"id": "pressure-for-material-24", "offered": []},
                         {"id": "water-variant-catalogue", "offered": [
                             {"family": "pressure_flow_v1", "variant": "cached", "accepted": True},
                             {"family": "freemass_v1", "variant": "reference", "accepted": True}]}]}


class CaseEvaluation(unittest.TestCase):
    def evaluate(self, mutate=None, family: str = "inertial_cellular_v1", workers: int = 4):
        case = arm_case(family, workers)
        value = receipt(case)
        if mutate:
            mutate(value)
        return fp.evaluate_case(value, case, SCENARIO, REGISTRATION)

    def stops(self, mutate, family: str = "inertial_cellular_v1", workers: int = 4) -> str:
        with self.assertRaises(fp.StopCondition) as raised:
            self.evaluate(mutate, family, workers)
        return str(raised.exception)

    def test_consistent_receipts_pass_for_every_family(self):
        for family in ("freemass_v1", "cellular_yield_v1", "pressure_flow_v1", "inertial_cellular_v1"):
            for workers in (1, 4):
                result = self.evaluate(family=family, workers=workers)
                self.assertEqual(result["max_observed_claimants"], min(workers, 4))

    def test_quantity_loss_stops(self):
        self.assertIn("Water", self.stops(lambda r: r["final"]["water"].update(quantity=QUANTITY - 1, visible=QUANTITY - 1)))

    def test_per_tick_quantity_change_stops(self):
        self.assertIn("tick 7", self.stops(lambda r: r["ticks"][6].update(water_quantity=QUANTITY + 255)))

    def test_silent_policy_fallback_stops(self):
        self.assertIn("silent fallback", self.stops(lambda r: r["applied"]["assignments"][0].update(applied_family="freemass_v1")))

    def test_foreign_material_leak_stops(self):
        self.assertIn("material 24", self.stops(lambda r: r["applied"]["assignments"][2].update(applied_family="inertial_cellular_v1")))

    def test_radius_upgrade_stops(self):
        self.assertIn("radius", self.stops(lambda r: r["applied"].update(maximum_rule_radius=2)))

    def test_boolean_quantity_is_not_an_integer(self):
        self.assertIn("expected integer", self.stops(lambda r: r["host_ledger"].update(source=False)))

    def test_float_quantity_is_not_an_integer(self):
        self.assertIn("expected integer", self.stops(lambda r: r["final"]["water"].update(quantity=float(QUANTITY))))

    def test_wall_corruption_stops(self):
        self.assertIn("Wall changed", self.stops(lambda r: r["final"]["inventory"]["counts"].update(
            {"1": 16380, "0": r["final"]["inventory"]["counts"]["0"] - 1536})))

    def test_unregistered_material_stops(self):
        def add_sand(value):
            counts = value["final"]["inventory"]["counts"]
            counts["2"] = 1
            counts["0"] -= 1
        self.assertIn("unregistered materials", self.stops(add_sand))

    def test_failed_world_reported_healthy_stops(self):
        self.assertIn("health", self.stops(lambda r: r["final"]["health"].update(failed=True)))

    def test_negative_inertial_velocity_stops(self):
        self.assertIn("negative inertial", self.stops(lambda r: r["final"]["inertial"].update(negative_vy_cells=1)))

    def test_pressure_gas_ledger_must_close(self):
        self.assertIn("gas ledger", self.stops(lambda r: r["final"]["pressure"].update(gas_ledger_closes=False),
                                              family="pressure_flow_v1"))

    def test_unretired_owner_stops(self):
        self.assertIn("retired", self.stops(lambda r: r["retirement"].update(world_released=False)))

    def test_single_worker_cannot_report_multiple_claimants(self):
        self.assertIn("claimants", self.stops(lambda r: r["ticks"][0].update(worker_threads_observed=2), workers=1))

    def test_short_horizon_stops(self):
        self.assertIn("horizon", self.stops(lambda r: r["ticks"].pop()))

    def test_skipped_scheduled_edit_stops(self):
        self.assertIn("scheduled edits applied", self.stops(lambda r: r["host_ledger"]["action_history"].clear()))

    def test_edit_at_wrong_tick_stops(self):
        self.assertIn("differs from registered", self.stops(
            lambda r: r["host_ledger"]["action_history"][0].update(tick=1)))

    def test_missing_water_assignment_stops(self):
        def drop(value):
            value["applied"]["assignments"] = value["applied"]["assignments"][1:]
            value["default_policy"] = value["default_policy"][1:]
        self.assertIn("no applied assignment", self.stops(drop))

    def test_failed_statistics_readback_stops(self):
        self.assertIn("statistics", self.stops(lambda r: r["ticks"][3].update(statistics_ok=False)))

    def test_claimants_above_configured_workers_stop(self):
        self.assertIn("outside", self.stops(lambda r: r["ticks"][3].update(worker_threads_observed=5)))

    def test_unobserved_claimants_stop(self):
        self.assertIn("outside", self.stops(lambda r: r["ticks"][3].update(worker_threads_observed=-1)))

    def test_nonzero_normalization_delta_stops(self):
        self.assertIn("normalization", self.stops(lambda r: r["construction"]["normalization"].update(positive_delta=5)))


class LedgerRule(unittest.TestCase):
    """host_ledger scenarios: Water changes only by re-summed scheduled edits."""

    def setUp(self):
        self.scenario = copy.deepcopy(SCENARIO)
        self.scenario["expected"]["quantity_rule"] = "host_ledger"
        self.case = arm_case("cellular_yield_v1", 4)
        self.receipt = receipt(self.case)
        self.fill = {"tick": 10, "kind": "fill", "x": 48, "y": 124, "width": 4, "height": 4,
                     "material": 3, "normalized_mass": 255, "coherence": 0}
        self.events = [dict(GATE), dict(self.fill)]
        self.receipt["host_ledger"].update(source=255 * 16, sink=0, action_history=[
            {"tick": 0, "action": dict(GATE), "before_water_integer": 0, "after_water_integer": 0},
            {"tick": 10, "action": dict(self.fill), "before_water_integer": 0, "after_water_integer": 255 * 16}])
        for tick in self.receipt["ticks"]:
            if tick["tick"] > 10:
                tick["water_quantity"] = QUANTITY + 255 * 16
        self.receipt["final"]["water"].update(quantity=QUANTITY + 255 * 16, visible=QUANTITY + 255 * 16)

    def test_consistent_scheduled_source_passes(self):
        result = fp.evaluate_case(self.receipt, self.case, self.scenario, REGISTRATION, self.events)
        self.assertEqual(result["final_water_quantity"], QUANTITY + 255 * 16)

    def test_change_before_the_edit_applies_stops(self):
        self.receipt["ticks"][9]["water_quantity"] = QUANTITY + 255 * 16
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_case(self.receipt, self.case, self.scenario, REGISTRATION, self.events)

    def test_ledger_that_disagrees_with_edits_stops(self):
        self.receipt["host_ledger"]["source"] = 255 * 15
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_case(self.receipt, self.case, self.scenario, REGISTRATION, self.events)

    def test_fill_above_its_cell_bound_stops(self):
        history = self.receipt["host_ledger"]["action_history"]
        history[1]["after_water_integer"] = 255 * 17
        self.receipt["host_ledger"]["source"] = 255 * 17
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_case(self.receipt, self.case, self.scenario, REGISTRATION, self.events)

    def test_constant_rule_rejects_water_changing_edit(self):
        self.scenario["expected"]["quantity_rule"] = "constant"
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_case(self.receipt, self.case, self.scenario, REGISTRATION, self.events)


class NegativeControls(unittest.TestCase):
    def test_expected_controls_pass(self):
        self.assertEqual(len(fp.evaluate_negative(negative())), 7)

    def test_accepted_radius_two_inertial_stops(self):
        value = negative()
        value["controls"][0]["accepted"] = True
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_negative(value)

    def test_unretained_world_after_refusal_stops(self):
        value = negative()
        value["controls"][1]["previous_world_retained"] = False
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_negative(value)

    def test_normalization_delta_must_match_independent_rule(self):
        value = negative()
        value["controls"][3]["normalization"]["positive_delta"] -= 1
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_negative(value)

    def test_refusal_for_an_unrelated_reason_stops(self):
        value = negative()
        value["controls"][0]["refusal"]["code"] = "fixture_rejected"
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_negative(value)

    def test_pressure_admitted_for_oil_stops(self):
        value = negative()
        value["controls"][4]["offered"][0]["accepted"] = True
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_negative(value)

    def test_optimisation_variant_on_other_family_stops(self):
        value = negative()
        value["controls"][6]["offered"].append({"family": "inertial_cellular_v1", "variant": "cached", "accepted": True})
        with self.assertRaises(fp.StopCondition):
            fp.evaluate_negative(value)


class Registration(unittest.TestCase):
    def test_primary_preflight_is_exactly_32_rows(self):
        cases = fp.expand(REGISTRATION)
        primary = [case for case in cases if case["role"] == "primary"]
        self.assertEqual(len(primary) * len(REGISTRATION["platforms"]), 32)
        self.assertEqual({case["family"] for case in primary},
                         {"freemass_v1", "cellular_yield_v1", "pressure_flow_v1", "inertial_cellular_v1"})
        self.assertEqual({case["radius"] for case in primary}, {3})
        self.assertTrue(all(case["variant"] == "reference" for case in cases))

    def test_lane_b_never_reexecutes_inertial(self):
        lane_b = [case for case in fp.expand(REGISTRATION) if case["lane"] == "B"]
        self.assertTrue(lane_b)
        self.assertNotIn("inertial_cellular_v1", {case["family"] for case in lane_b})
        self.assertEqual({case["radius"] for case in lane_b}, {2})

    def test_registered_fixtures_keep_original_bytes(self):
        for scenario in REGISTRATION["scenarios"]:
            path = fp.ROOT / "godot" / scenario["fixture"].removeprefix("res://")
            self.assertEqual(fp.git("hash-object", str(path)), scenario["fixture_git_blob"], scenario["id"])

    def test_materialized_lfs_runtime_is_committed_content(self):
        native = fp.RUNTIMES["windows"][0]
        data = (fp.ROOT / native).read_bytes()
        materialized = not data.startswith(b"version https://git-lfs.github.com/spec/v1")
        self.assertEqual(fp.materialized_lfs_matches_head(native), materialized)
        self.assertFalse(fp.materialized_lfs_matches_head("tools/lcb/feel_preflight.py"))

    def test_committed_preflight_packet_still_reduces_admitted(self):
        evidence = fp.ROOT / "docs/audits/lcb360-preflight-2026-11-03"
        summary = fp.reduce_packets(fp.ROOT / fp.DEFAULT_REGISTRATION, [evidence / "windows", evidence / "linux"],
                                    logs_external=True)
        self.assertEqual(summary["verdict"], "ADMITTED")
        self.assertEqual(summary["primary_rows_total"], 32)
        self.assertTrue(all(row["tick_hashes_equal"] for row in summary["cross_platform_observation"]))

    def test_committed_packets_are_pinned(self):
        evidence = fp.ROOT / "docs/audits"
        pinned = {
            "lcb360-preflight-2026-11-03/windows/packet.json": "edf179e9335dab79657fda52c05107a4b78081e2bc7fafaaf661915a6347f1e9",
            "lcb360-preflight-2026-11-03/linux/packet.json": "1176818fc280d4dcbae67f9a1250db001cfe32824cbd91299c6d1788249f429b",
        }
        for relative, digest in pinned.items():
            data = (evidence / relative).read_bytes().replace(b"\r\n", b"\n")
            self.assertEqual(fp.sha256_bytes(data), digest, relative)

    def test_manifest_tampering_is_recomputed_not_trusted(self):
        source = fp.ROOT / "docs/audits/lcb360-preflight-2026-11-03/windows"
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "windows"
            shutil.copytree(source, target)
            manifest = json.loads((target / "packet.json").read_text(encoding="utf-8"))
            manifest["source"]["tree"] = "0" * 40
            (target / "packet.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaises(fp.StopCondition):
                fp.load_packet(target, fp.ROOT / fp.DEFAULT_REGISTRATION, logs_external=True)

    def test_receipts_copied_under_another_platform_stop(self):
        source = fp.ROOT / "docs/audits/lcb360-preflight-2026-11-03/windows"
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "linux"
            shutil.copytree(source, target)
            manifest = json.loads((target / "packet.json").read_text(encoding="utf-8"))
            linux = json.loads((fp.ROOT / "docs/audits/lcb360-preflight-2026-11-03/linux/packet.json").read_text(encoding="utf-8"))
            manifest["platform"] = "linux"
            manifest["runtime"] = linux["runtime"]
            (target / "packet.json").write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaises(fp.StopCondition):
                fp.load_packet(target, fp.ROOT / fp.DEFAULT_REGISTRATION, logs_external=True)

    def test_independent_normalization_rule(self):
        self.assertEqual(fp.normalized_water(128, 255), 255)
        self.assertEqual(fp.normalized_water(127, 255), 0)
        self.assertEqual(fp.normalized_water(255, 255), 255)


if __name__ == "__main__":
    unittest.main()
