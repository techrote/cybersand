#!/usr/bin/env python3
"""Negative controls for the WATER-CONTACT #362 evidence reducer.

A synthetic, internally consistent stage-1 packet must pass; each targeted
corruption (the failure classes the reducer exists to catch) must fail it.
"""
from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import reduce_impact_evidence as reducer  # noqa: E402

MANIFEST = reducer.MANIFEST
DIGEST = reducer.manifest_digest(MANIFEST)
SPEC = json.loads(MANIFEST.read_text(encoding="utf-8"))


def record(case: dict, arm: dict, workers: int) -> dict:
    with_water = bool(case.get("water", True)) and int(case.get("depth", 0)) > 0
    with_body = bool(case.get("body", True))
    quantity = SPEC["world"]["basin"]["width"] * int(case.get("depth", 0)) * 255 if with_water else 0
    displaced = 12 if with_body and with_water else 0
    out = {
        "schema": reducer.RECORD_SCHEMA, "manifest_sha256": DIGEST, "case": case["id"], "arm": arm["id"],
        "family": arm["family"], "variant": arm["variant"], "radius": arm["radius"], "workers_configured": workers,
        "horizon": SPEC["horizon_ticks"], "ok": True, "violations": [],
        "identity": {"applied_family": arm["family"], "applied_variant": arm["variant"], "applied_radius": arm["radius"],
                     "backend": "native-phased", "configured_workers": workers},
        "runtime": {"runtime_matches_provenance": True, "physics_engine_setting": "Rapier2D",
                    "rapier_server_class_present": True},
        "initial_water": {"global": {"quantity": quantity}, "interior": {"quantity": quantity}},
        "final": {"completed_ticks": SPEC["horizon_ticks"], "failed": False, "tick_failures": 0,
                  "global_water": {"quantity": quantity}, "physical_state_hash": f"{case['id']}-{arm['id']}"},
        "relocation": {"histogram_total": {"total": displaced, "up": displaced, "lateral": 0, "down": 0, "other_material": 0},
                       "results": {"displaced": displaced, "destinations_in_roi": displaced, "contacts": 40 if with_body else 0,
                                   "unresolved": 3, "carried_state_mismatches": 0, "global_checks": 30,
                                   "masked_water_cells": {"p50": 0, "max": 0}}},
        "decomposition": {}, "peaks": {}, "return": {},
        "inertial": {"censuses": 150, "negative_vy": 0, "destinations_negative_vy": 0}
        if arm["family"] == "inertial_cellular_v1" else {"available": False},
        "pressure": {"available": True, "max_overfill": 0} if arm["family"] == "pressure_flow_v1" else {"available": False},
        "boundary": {"max_body_floor_penetration": 0.0}, "mask": {"checks": 150, "mismatched_cells": 0},
        "workers": {"observed_participant_histogram": {str(min(workers, 2)): SPEC["horizon_ticks"]}},
        "cost": {}, "trace_sha256": f"trace-{case['id']}-{arm['id']}",
    }
    if with_body:
        out["rapier"] = {"manual_steps": SPEC["horizon_ticks"], "stale_rejected": 0}
        if case.get("stale_duplicate_probe"):
            out["stale_duplicate_probe"] = {"duplicate_snapshot_applied": 0, "stale_applied": 0, "stale_rejected": 1}
    else:
        out["relocation"]["results"]["unresolved"] = 0
    return out


def probes() -> dict:
    rows = []
    for arm in SPEC["arms"]:
        for mode in SPEC["kinematic_probe"]["modes"]:
            overlap = mode["mode"] == "overlap"
            rows.append({"schema": reducer.PROBE_SCHEMA, "arm": arm["id"], "probe_id": mode["id"], "mode": mode["mode"],
                         "ok": True, "source": [240, 406], "destination": [240, 403] if overlap else [240, 406],
                         "relocation_rows_up": 3 if overlap else 0, "state_before": "3,255,0",
                         "state_after": "3,255,0", "state_carried_unchanged": overlap})
    return {"manifest_sha256": DIGEST, "probes": rows}


def write_packet(directory: Path, records: list[dict], probe_packet: dict | None) -> None:
    for item in records:
        name = f"{item['case']}_{item['arm']}_w{item['workers_configured']}.json"
        (directory / name).write_text(json.dumps(item), encoding="utf-8")
    if probe_packet is not None:
        (directory / "kinematic_probes.json").write_text(json.dumps(probe_packet), encoding="utf-8")


def stage1() -> list[dict]:
    out = []
    for case in SPEC["cases"]:
        if int(case.get("stage", 2)) > 1:
            continue
        for arm in SPEC["arms"]:
            for workers in SPEC["workers"]:
                out.append(record(case, arm, workers))
    return out


def find(records: list[dict], case: str, arm: str, workers: int) -> dict:
    return next(r for r in records if (r["case"], r["arm"], r["workers_configured"]) == (case, arm, workers))


class ReducerNegativeControls(unittest.TestCase):
    def reduce(self, records: list[dict], probe_packet: dict | None = None, use_default_probes: bool = True) -> dict:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "packet"
            path.mkdir()
            write_packet(path, records, probes() if use_default_probes and probe_packet is None else probe_packet)
            return reducer.reduce([path], MANIFEST, 1, SPEC["workers"])

    def assert_rejected(self, records: list[dict], needle: str, **kwargs) -> None:
        report = self.reduce(records, **kwargs)
        self.assertEqual(report["status"], "failed")
        self.assertTrue(any(needle in error for error in report["errors"]), report["errors"])

    def test_valid_packet_passes(self) -> None:
        report = self.reduce(stage1())
        self.assertEqual(report["status"], "passed", report["errors"])
        self.assertEqual(report["packets"][0]["runs"], 30)

    def test_quantity_change_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "PF3", 1)["final"]["global_water"]["quantity"] -= 255
        self.assert_rejected(records, "global Water quantity")

    def test_unnormalized_construction_rejected(self) -> None:
        records = stage1()
        item = find(records, "C0S", "CY3", 4)
        item["initial_water"]["global"]["quantity"] -= 1
        item["final"]["global_water"]["quantity"] -= 1
        self.assert_rejected(records, "whole-cell expectation")

    def test_hidden_policy_fallback_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "IN3", 1)["identity"]["applied_family"] = "freemass_v1"
        self.assert_rejected(records, "hidden fallback")

    def test_radius_mismatch_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "FM2", 1)["identity"]["applied_radius"] = 3
        self.assert_rejected(records, "applied_radius")

    def test_runtime_mismatch_rejected(self) -> None:
        records = stage1()
        find(records, "C1", "FM3", 4)["runtime"]["runtime_matches_provenance"] = False
        self.assert_rejected(records, "provenance")

    def test_negative_inertial_velocity_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "IN3", 4)["inertial"]["negative_vy"] = 1
        self.assert_rejected(records, "negative vy")

    def test_relocation_census_mismatch_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "CY3", 1)["relocation"]["histogram_total"]["total"] = 11
        self.assert_rejected(records, "BodyDisplacement events")

    def test_carried_state_change_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "PF3", 4)["relocation"]["results"]["carried_state_mismatches"] = 1
        self.assert_rejected(records, "carried stored state")

    def test_worker_parity_failure_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "IN3", 4)["trace_sha256"] = "different"
        self.assert_rejected(records, "worker parity failed")

    def test_missing_run_rejected(self) -> None:
        records = [r for r in stage1() if (r["case"], r["arm"], r["workers_configured"]) != ("C0S", "PF3", 4)]
        self.assert_rejected(records, "missing registered run")

    def test_duplicate_or_stale_acceptance_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "FM3", 1)["stale_duplicate_probe"]["stale_applied"] = 1
        self.assert_rejected(records, "duplicate/stale rejection")

    def test_ordinary_stale_rejection_rejected(self) -> None:
        records = stage1()
        find(records, "C1", "IN3", 1)["rapier"]["stale_rejected"] = 2
        self.assert_rejected(records, "stale result rejected")

    def test_step_order_mismatch_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "CY3", 4)["rapier"]["manual_steps"] = 299
        self.assert_rejected(records, "Rapier manual steps")

    def test_mask_mismatch_rejected(self) -> None:
        records = stage1()
        find(records, "S-H-C", "FM3", 4)["mask"]["mismatched_cells"] = 3
        self.assert_rejected(records, "body mask")

    def test_recorded_violation_rejected(self) -> None:
        records = stage1()
        item = find(records, "C0S", "IN3", 1)
        item["violations"] = [{"kind": "outside_basin_water", "tick": 9, "detail": 255}]
        item["ok"] = False
        self.assert_rejected(records, "outside_basin_water")

    def test_body_free_coupling_rejected(self) -> None:
        records = stage1()
        find(records, "C0S", "FM3", 1)["relocation"]["results"]["contacts"] = 5
        self.assert_rejected(records, "body-free control")

    def test_manifest_hash_rejected(self) -> None:
        records = stage1()
        find(records, "C1", "CY3", 1)["manifest_sha256"] = "0" * 64
        self.assert_rejected(records, "manifest hash")

    def test_velocity_dependent_relocation_rejected(self) -> None:
        packet = probes()
        packet["probes"][1]["destination"] = [240, 402]
        self.assert_rejected(stage1(), "depends on body velocity", probe_packet=packet)

    def test_missing_probes_rejected(self) -> None:
        self.assert_rejected(stage1(), "kinematic probe packet missing", use_default_probes=False)


if __name__ == "__main__":
    unittest.main()
