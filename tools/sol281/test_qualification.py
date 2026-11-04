#!/usr/bin/env python3
"""Adverse controls for the scoped qualification reader; no physics claims."""
import argparse
import copy
from contextlib import redirect_stdout
import hashlib
import io
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import run_qualification as q


def payload(spec, platform="Linux"):
    result = {"checks": spec.checks or 200, "failures": [], "platform": platform}
    if spec.workers:
        result["workers"] = spec.workers
    if spec.script == "test_solid_contact_synchronized":
        result.update(schema="cybersand.sol364.synchronized-contact.v1", case_count=21, steps=180, complete_replay=True)
    if spec.name == "lifecycle":
        result["actual_host_replacement_cycles"] = 20
    if spec.script == "test_solid_detachment_displacement":
        result["checks"] = 292
        result["cases"] = 17
    if spec.script == "test_solid_detachment_populated":
        result["conservative_displacement"] = "--baseline" not in spec.flags
        result["surroundings"] = next(x.split("=", 1)[1] for x in spec.flags if x.startswith("--surroundings="))
    if spec.script == "test_solid_contact_response":
        gate = {"gate_passed": True, "proposed_gate_minimum_reduction": 0.25,
                "baseline_added_overlap_area_steps": 10.0, "candidate_added_overlap_area_steps": 1.0}
        result["mechanical"] = {**gate, "steps": 12, "mass": 520, "trajectory": [{}] * 12, "off_center": gate.copy()}
        result["cases"] = {"transported_original_segment": {
            "current_area": 0.015625, "current_depth": 0.0625, "vertex_drift": 0.1875,
            "source_length": 0.25, "remaining_length": 0.0625, "outcome": "Accepted",
            "mixed_clearance_outcome": "Accepted", "position_work": 0,
        }}
    if spec.script == "test_solid_contact_observation":
        result["cases"] = [{"id": x} for x in
                           ("partial_shared_edge", "float32_seam", "immutable_publication", "refusals")]
        result["cases"][2].update(attempts=3, complete_attempts=2, refused_attempts=1, stages_accounted=True)
    if spec.script == "test_solid_contact_fences":
        result["readback_failure_cases"] = [
            "velocity_x_nan", "velocity_y_inf", "velocity_negative_inf",
            "omega_nan", "omega_inf", "omega_negative_inf",
            "energy_nan", "energy_inf", "energy_negative_inf",
            "momentum_nan", "angular_momentum_inf", "finite_energy_increase",
        ]
    if spec.script == "test_solid_detachment_contact_recovery":
        result.update(schema="cybersand.sol281.contact-recovery.v1", case_count=18)
        result["cases"] = [{"surroundings": kind, "candidate": arm, "repeat": repeat, "steps": 360,
                            "sand_before": 100, "sand_after": 100, "water_before": 0, "water_after": 0,
                            "metrics": {"physical_contact": {"observations": 3, "energy_violations": 0,
                                "worker_observation_attempts": 3, "worker_contact_ms_total": 1.0,
                                "geometry_ms_total": 0.9, "response_ms_all_attempts": float(arm),
                                "response_ms_total": 0.5 * int(arm), "response_attempts": int(arm),
                                "response_accepts": int(arm), "impulse_magnitude_sum": float(arm)}},
                            "trace": [{**dict.fromkeys(("revision", "physics_epoch", "token", "body_generation",
                                "source_x", "source_y", "source_angle", "current_x", "current_y", "current_angle",
                                "source_published_usec", "observed_usec"), 1), "proxies": [{}] * 6}]}
                           for kind in ("packed_sand", "embedded_sand", "mixed") for repeat in range(3)
                           for arm in ((False, True) if repeat % 2 == 0 else (True, False))]
    return result


def synchronized_result(spec, footer):
    """Synthetic custody fixture only: constant states do not claim real physics."""
    result = copy.deepcopy(footer)
    fixture = json.loads((q.ROOT / q.SYNCHRONIZED_FIXTURE).read_text())
    rectangles = [44, 27, 29, 5, 44, 32, 16, 1, 61, 32, 12, 1, 44, 33, 29, 7, 50, 40, 15, 4, 50, 44, 4, 21]
    cells = sorted({(x, y) for i in range(0, 24, 4) for y in range(rectangles[i + 1], rectangles[i + 1] + rectangles[i + 3])
                    for x in range(rectangles[i], rectangles[i] + rectangles[i + 2])}, key=lambda point: (point[1], point[0]))
    center = [sum(point[axis] + 0.5 for point in cells) / 520 for axis in (0, 1)]
    inertia = sum((x + 0.5 - center[0]) ** 2 + (y + 0.5 - center[1]) ** 2 + 1 / 6 for x, y in cells)
    result.update(backend="Rapier2D", engine="4.7-stable (official)", fixed_delta=1 / 60, can_sleep=False,
        source_sha256="a" * 64, frozen_planner_source="749fb8b597ad866f7535f26442e904207c4f7611",
        source={"rectangles": rectangles, "members": [v for x, y in cells for v in (x, y, 43, 0, 0, 200)],
                "center": center, "inertia": inertia, "mass": 520, "member_count": 520, "shape_count": 6},
        input_hashes={path.removeprefix("godot/"): q.digest(q.ROOT / path) for path in q.SYNCHRONIZED_INPUTS},
        contact_columns=["proxy", "face", "cell_x", "cell_y", "point_x", "point_y", "normal_x", "normal_y",
                         "a_x", "a_y", "b_x", "b_y", "depth", "area", "weight"],
        proxy_metric_columns=["proxy", "area", "max_depth", "overlap_cells"],
        pose_columns=["x_axis_x", "x_axis_y", "y_axis_x", "y_axis_y", "origin_x", "origin_y"], geometries=[], cases=[])
    for key, path in (("script_sha256", q.SYNCHRONIZED_INPUTS[1]), ("fixture_sha256", q.SYNCHRONIZED_FIXTURE),
                      ("current_planner_sha256", q.SYNCHRONIZED_INPUTS[4]), ("frozen_planner_sha256", q.SYNCHRONIZED_INPUTS[3])):
        result[key] = q.digest(q.ROOT / path)
    field = "b" * 15  # Native String::num_uint64 hashes are not zero-padded.
    counts = [16375, 0, 9] + [0] * 41
    result["native_fields"] = {field: {"world_state_hash": field, "origin": [0, 0], "size": [128, 128],
        "native_ticks": 1, "water_mass": 0, "counts": counts, "material_runs": [[0, 16375], [2, 9]]}}

    def geometry(pose, overlap=1):
        def corners(x, y, width, height):
            return [[pose[0] * (px - center[0]) + pose[2] * (py - center[1]) + pose[4],
                     pose[1] * (px - center[0]) + pose[3] * (py - center[1]) + pose[5]]
                    for px, py in ((x, y), (x + width, y), (x + width, y + height), (x, y + height))]
        return {"pose": pose, "proxies": [corners(*rectangles[i:i + 4]) for i in range(0, 24, 4)],
            "hole_witnesses": [{"source_cell": hole, "corners": corners(*hole, 1, 1), "proxy_area": 0,
                                "method": "exact_source_partition_under_common_rigid_transform"} for hole in fixture["hole_cells"]],
            "contacts": [], "proxy_metrics": [[1, overlap, 1, overlap]] + [[i, 0, 0, 0] for i in range(2, 7)],
            "overlap_cells": overlap, "overlap_area": overlap, "sand_overlap_area": overlap,
            "max_penetration": 1, "max_sand_penetration": 1}

    idle = {"accepted": True, "outcome": "Accepted", "impulses": [], "approaching_count": 0}
    interior = geometry([1, 0, 0, 1, *center], 9)
    boundary = geometry([1, 0, 0, 1, center[0], center[1] + 1.5], 9)
    boundary["contacts"] = [[1, 0, 47, 28, 47.5, 28.5, 0, -1, 47, 28.5, 48, 28.5, 1, 1, 1]]
    result["controls"] = [
        {"id": "transported_midpoint", "source_accepts": True, "source_span_length": 0.25,
         "current_surviving_span_length": 0.0625, "current_area": 0.015625, "current_depth": 0.0625, "vertex_drift": 0.1875,
         "frozen_result": {"accepted": False, "outcome": "ClearedContact", "impulses": []},
         "candidate_result": {"accepted": True, "outcome": "Accepted", "impulses": [{"impulse": [0, -1], "offset": [0, 0]}]}},
        {"id": "stationary_velocity_limit", "positive_area": 0.0625, "position_work": 0, "result": copy.deepcopy(idle)},
        {"id": "interior_without_face", "geometry": interior, "boundary_control": boundary,
         "native_field": field, "native_state_hash_before": field, "native_state_hash_after": "c" * 16,
         "native_content_hash_before": "d" * 16, "native_content_hash_after": "d" * 16,
         "native_material_cells_preserved": True, "payload_preserved": True, "aggregate_owned": 520, "native_source_members": 0,
         "source_sha256": result["source_sha256"],
         "position_work": 0, "candidate": copy.deepcopy(idle), "velocity_control": copy.deepcopy(idle)}]
    for definition in fixture["fixtures"]:
        origin = definition.get("pose_origin", [center[axis] + definition["offset"][axis] for axis in (0, 1)])
        angle = definition["angle"]
        pose = [math.cos(angle), math.sin(angle), -math.sin(angle), math.cos(angle), *origin]
        geo = geometry(pose)
        geo["sha256"] = hashlib.sha256(json.dumps(geo, sort_keys=True).encode()).hexdigest()
        # Fixtures sharing a pose share the exact reporting geometry.
        index = next((i for i, existing in enumerate(result["geometries"]) if existing["sha256"] == geo["sha256"]), -1)
        if index < 0:
            index = len(result["geometries"])
            result["geometries"].append(geo)
        state = {"pose": pose, "velocity": definition["velocity"], "omega": definition["omega"], "mass": 520,
            "inertia": inertia, "kinetic": 260 * sum(v * v for v in definition["velocity"]) + 0.5 * inertia * definition["omega"] ** 2,
            "sleeping": False, "potential": 0, "potential_scope": "zero gravity causal control", "position_work": 0}
        for arm in q.SYNCHRONIZED_ARMS:
            def measurement(step):
                return {"geometry_id": index, "geometry_sha256": geo["sha256"], "sample_serial": step + 1,
                    "snapshot_serial": step + 1, "native_tick": 1, "revision": "1", "generation": "7", "token": "1:1",
                    "physics_epoch": 17, "published_usec": 1000000 + step * 1000, "rapier_source_corner_drift": 0,
                    "overlap_cells": 1, "overlap_area": 1, "sand_overlap_area": 1, "max_penetration": 1,
                    "max_sand_penetration": 1, "contact_count": 0, "geometry_probes": 1, "support_probes": 9,
                    "owner_ms": 1, "prepare_ms": 0.2, "observation_ms": 0.5, "envelope_freeze_ms": 0.3,
                    "native_geometry_ms": 0.4, "native_payload_freeze_ms": 0.1}
            trace, delivered, refusals = [], set(), {}
            delay = {"delay_one": 1, "delay_two": 2}.get(definition["schedule"], 0)
            for step in range(1, 181):
                missing = step <= delay or (definition["schedule"] == "drop_every_fourth" and step % 4 == 0)
                pair = {}
                response_ms = 0
                if missing:
                    receipt = {"delivered": False, "outcome": "MissingPublication"}
                    response = {"accepted": False, "outcome": "MissingPublication", "impulses": []}
                else:
                    serial = step - delay
                    delivered.add(serial)
                    selected = measurement(serial - 1)
                    receipt = {"delivered": True, "source_step": serial - 1, "sample_age": delay,
                        "sample_serial": serial, "snapshot_serial": serial, "tick": 1, "revision": "1", "generation": "7",
                        "token": "1:1", "physics_epoch": 17, "published_usec": selected["published_usec"],
                        "received_usec": selected["published_usec"] + 1000, "queue_latency_ms": 1}
                    pair = {"same_input": True, "velocity_control": copy.deepcopy(idle), "candidate": copy.deepcopy(idle)}
                    if arm == "conservative_baseline":
                        response = {"accepted": False, "outcome": "DisabledControl", "impulses": []}
                    elif delay > 1:
                        response = {"accepted": False, "outcome": "StaleContactSample"}
                        response_ms = 0.1
                        refusals["StaleContactSample"] = refusals.get("StaleContactSample", 0) + 1
                    else:
                        response = {**copy.deepcopy(idle), "readback_valid": True}
                        response_ms = 0.1
                trace.append({"step": step, "before": copy.deepcopy(state), "after_response": copy.deepcopy(state),
                    "after": copy.deepcopy(state), "receipt": receipt, "response": response, "matched": pair,
                    "measurement": measurement(step), "response_energy_change": 0, "rapier_energy_change": 0,
                    "response_ms": response_ms, "rapier_ms": 0.3, "matched_planner_ms": 0 if missing else 0.2})
            attempts = 0 if arm == "conservative_baseline" else len(delivered)
            stats = {"owner_attempts": 181, "complete_measurements": 181, "published": 181,
                "received": len(delivered), "missing": 180 - len(delivered), "queue_capacity": 3, "queue_peak": 3,
                "queue_evictions": 178, "overwritten": len(set(range(1, 179)) - delivered), "remaining_at_end": 3,
                "remaining_undelivered": len(set(range(179, 182)) - delivered), "response_attempts": attempts,
                "response_accepts": attempts - sum(refusals.values()), "response_refusals": refusals,
                "response_failures": 0, "energy_violations": 0, "nonfinite_states": 0, "sleep_steps": 0,
                "rapier_step_energy_violations": 0, "rapier_step_energy_change_sum": 0,
                "overlap_cell_ticks": 180, "area_cell_ticks": 180, "sand_area_cell_ticks": 180,
                "geometry_probes": 181, "support_probes": 1629, "positive_steps": 180, "longest_positive_run": 180,
                "max_penetration": 1, "max_sand_penetration": 1, "owner_ms_total": 181,
                "response_ms_total": attempts * 0.1, "rapier_ms_total": 54, "response_energy_change_sum": 0,
                "queue_latency_ms_max": 1, "impulse_magnitude_sum": 0, "torque_impulse_sum": 0,
                "max_speed": math.hypot(*state["velocity"]), "max_abs_omega": abs(state["omega"]),
                "max_translation": 0, "max_rotation_change": 0, "all_attempt_ms_per_complete_measurement": (181 + attempts * 0.1) / 181,
                "matched_planner_ms_total": len(delivered) * 0.2}
            gates = {"newly_proposed": True, "initially_embedded": True, "initial_depth": 1,
                "allowed_depth": 1.25, "depth_pass": True, "sustained_clearance_pass": False,
                "clearance_start_step": -1, "first_valid_impact_step": -1, "recurrence_pass": False,
                "observed_clearance_window_steps": 60, "recurrence_evaluable": False, "recurrence_detected": None,
                "response_energy_pass": True, "finite_state_pass": True, "position_work": 0, "physical_accepted": False}
            result["cases"].append({"id": definition["id"] + "/" + arm, "fixture": definition["id"], "arm": arm,
                "steps": 180, "workers": spec.workers, "source_sha256": result["source_sha256"],
                "native_field": field, "native_state_hash_after": field, "native_ticks_before": 1, "native_ticks_after": 1,
                "native_source_members": 0, "aggregate_owned": 520, "payload_preserved": True,
                "ordinary_native_integration": False, "schedule": definition["schedule"],
                "shape_partition": {"valid": True, "holes_empty": True, "member_count": 520, "covered_count": 520, "shape_count": 6},
                "initial": {"step": 0, "state": copy.deepcopy(state), "measurement": measurement(0)},
                "trace": trace, "stats": stats, "physical_gates": gates})
    return result


def structured_result(spec, footer):
    result = copy.deepcopy(footer)
    if spec.script == "test_solid_contact_synchronized":
        return synchronized_result(spec, footer)
    if spec.script == "test_solid_detachment_contact_recovery" and "cases" not in result:
        result.update(payload(spec, result["platform"]))
    if spec.script == "test_solid_detachment_displacement":
        path = q.ROOT / "godot/tests/fixtures/sol281/conservative_contacts.json"
        fixtures = json.loads(path.read_text(encoding="utf-8"))["fixtures"]
        result.update(schema="cybersand.sol281.conservative-displacement-replay.v1",
                      fixture_sha256=q.digest(path), cases=[{
                          "id": fixture["id"], "failure_count": 0,
                          "expected_accepted": fixture["expected_accepted"],
                          "outcome": "Applied" if fixture["expected_accepted"] else "GeometryBlocked",
                          "moved_cells": fixture["expected_minimum_moves"],
                          "path": fixture.get("expected_path", []),
                          "geometry_clear": fixture["expected_accepted"],
                          "before_sha256": "a" * 64,
                          "after_sha256": ("b" if fixture["expected_accepted"] else "a") * 64,
                      } for fixture in fixtures])
    return result


class QualificationReader(unittest.TestCase):
    def test_complete_inventory_and_parent_budgets(self):
        for cohort in q.COHORTS:
            cases = q.inventory(cohort)
            self.assertEqual(len({x.name for x in cases}), len(cases))
            for case in cases:
                self.assertTrue((q.ROOT / "godot/tests" / (case.script + ".gd")).is_file())
            allowance = (q.policy.aggregate_seconds([q.policy.case_seconds(x.script) for x in cases])
                         + (len(cases) + 1) * q.policy.godot_process_cleanup_seconds()
                         + q.policy.watchdog_seconds("godot_metadata_seconds")
                         + 2 * q.policy.watchdog_seconds("dependency_prepare_seconds"))
            self.assertLessEqual(allowance, q.policy.identity()["watchdogs"]["godot_job_minutes"] * 60)
            if cohort == "mechanism":
                msvc = (q.policy.watchdog_seconds("native_suite_seconds")
                        + 2 * q.policy.watchdog_seconds("terminate_grace_seconds")
                        + q.policy.watchdog_seconds("operation_seconds"))
                self.assertLessEqual(allowance + msvc, q.policy.identity()["watchdogs"]["godot_job_minutes"] * 60)
        self.assertEqual([len(q.inventory(x)) for x in q.COHORTS], [11, 11, 11, 4])

    def test_physical_gates_cannot_be_redefined_or_truncated(self):
        response = next(x for x in q.inventory("mechanism") if x.script == "test_solid_contact_response")
        for mutate in (lambda d: d["mechanical"].update(proposed_gate_minimum_reduction=0.1),
                       lambda d: d["mechanical"].update(candidate_added_overlap_area_steps=9.0),
                       lambda d: d["mechanical"]["off_center"].update(gate_passed=False),
                       lambda d: d["mechanical"]["trajectory"].pop(),
                       lambda d: d["cases"].pop("transported_original_segment"),
                       lambda d: d["cases"]["transported_original_segment"].update(outcome="StaleGeometry"),
                       lambda d: d["cases"]["transported_original_segment"].update(remaining_length=0.25),
                       lambda d: d["cases"]["transported_original_segment"].update(position_work=1.0)):
            value = payload(response)
            mutate(value)
            with self.assertRaises(RuntimeError):
                q.verify_footer(response, response.footer + " " + json.dumps(value), "Linux")
        recovery = next(x for x in q.inventory("contact-w1") if x.script == "test_solid_detachment_contact_recovery")
        for mutate in (lambda d: d["cases"].pop(),
                       lambda d: d["cases"].append(d["cases"][0]),
                       lambda d: d["cases"][0].update(sand_after=99),
                       lambda d: d["cases"][0]["metrics"]["physical_contact"].update(energy_violations=1),
                       lambda d: d["cases"][1]["metrics"]["physical_contact"].update(
                           response_failures={"NonFiniteContactReadback": 1}),
                       lambda d: d["cases"][1]["metrics"]["physical_contact"].update(response_accepts=0),
                       lambda d: d["cases"][1]["metrics"]["physical_contact"].update(impulse_magnitude_sum=0),
                       lambda d: d["cases"][0]["metrics"]["physical_contact"].update(response_accepts=1),
                       lambda d: d["cases"][0]["metrics"]["physical_contact"].update(worker_contact_ms_total=0.1),
                       lambda d: d["cases"][0]["metrics"]["physical_contact"].update(worker_observation_attempts=1),
                       lambda d: d["cases"][1]["metrics"]["physical_contact"].update(response_ms_all_attempts=0.1),
                       lambda d: d["cases"][0]["trace"][0].pop("source_angle")):
            value = payload(recovery)
            mutate(value)
            with self.assertRaises(RuntimeError):
                q.verify_footer(recovery, recovery.footer + " " + json.dumps(value), "Linux")

    def test_response_stage_work_preserves_inclusive_attempt_cost(self):
        spec = next(x for x in q.inventory("contact-w1") if x.script == "test_solid_detachment_contact_recovery")
        original = payload(spec)
        stage_names = ["response_" + stage + "_ms_all_attempts" for stage in
                       ("rid_state", "planner", "impulse_apply", "readback", "other")]
        for case in original["cases"]:
            physical = case["metrics"]["physical_contact"]
            physical.update({key: 0 for key in stage_names})
            physical[stage_names[-1]] = physical["response_ms_all_attempts"]
        q.verify_footer(spec, spec.footer + " " + json.dumps(original), "Linux")
        for mutate in (lambda d: d.pop(stage_names[1]), lambda d: d.update({stage_names[1]: -0.1}),
                       lambda d: d.update({stage_names[1]: float("inf")}), lambda d: d.update({stage_names[1]: 0.1})):
            value = copy.deepcopy(original)
            mutate(value["cases"][0]["metrics"]["physical_contact"])
            with self.assertRaises(RuntimeError):
                q.verify_footer(spec, spec.footer + " " + json.dumps(value), "Linux")

    def test_post_application_readback_failure_inventory_is_complete(self):
        spec = next(x for x in q.inventory("mechanism") if x.script == "test_solid_contact_fences")
        for mutate in (lambda d: d["readback_failure_cases"].pop(),
                       lambda d: d["readback_failure_cases"].append(d["readback_failure_cases"][0]),
                       lambda d: d["readback_failure_cases"].reverse(),
                       lambda d: d.update(checks=38)):
            value = payload(spec)
            mutate(value)
            with self.assertRaises(RuntimeError):
                q.verify_footer(spec, spec.footer + " " + json.dumps(value), "Linux")

    def test_immutable_observation_and_all_attempt_accounting_are_required(self):
        spec = next(x for x in q.inventory("contact-w1") if x.script == "test_solid_contact_observation")
        for mutate in (lambda d: d["cases"].pop(2),
                       lambda d: d["cases"][2].update(attempts=2),
                       lambda d: d["cases"][2].update(complete_attempts=1),
                       lambda d: d["cases"][2].update(refused_attempts=0),
                       lambda d: d["cases"][2].update(refused_attempts=True),
                       lambda d: d["cases"][2].update(stages_accounted=False)):
            value = payload(spec)
            mutate(value)
            with self.assertRaises(RuntimeError):
                q.verify_footer(spec, spec.footer + " " + json.dumps(value), "Linux")

    def test_all_declared_footers_and_worker_policies(self):
        for cohort in q.COHORTS:
            for spec in q.inventory(cohort):
                value = payload(spec)
                line = spec.footer + (" " + json.dumps(value) if spec.structured else "") + "\n"
                self.assertEqual(q.verify_footer(spec, line, "Linux"), value if spec.structured else None)
                with self.assertRaises(RuntimeError):
                    q.verify_footer(spec, line + line, "Linux")
                with self.assertRaises(RuntimeError):
                    q.verify_footer(spec, "", "Linux")
                if spec.structured:
                    with self.assertRaises(RuntimeError):
                        q.verify_footer(spec, line, "Windows")
                    value["failures"] = ["original failure must survive"]
                    with self.assertRaises(RuntimeError):
                        q.verify_footer(spec, spec.footer + " " + json.dumps(value), "Linux")

    def test_truncated_and_mislabelled_inventory_refused(self):
        for cohort in q.COHORTS:
            for spec in q.inventory(cohort):
                if not spec.structured:
                    continue
                fields = {"checks": payload(spec)["checks"] - 1}
                if spec.script == "test_solid_contact_synchronized":
                    fields = {"checks": 0, "steps": 179, "case_count": 20, "complete_replay": False}
                if spec.workers:
                    fields["workers"] = 4 if spec.workers == 1 else 1
                if spec.name == "lifecycle":
                    fields["actual_host_replacement_cycles"] = 19
                if spec.script == "test_solid_detachment_displacement":
                    fields["cases"] = 16
                if spec.script == "test_solid_detachment_populated":
                    fields["surroundings"] = "empty"
                    fields["conservative_displacement"] = "--baseline" in spec.flags
                for key, invalid in fields.items():
                    value = payload(spec)
                    value[key] = invalid
                    with self.assertRaises(RuntimeError, msg=spec.name + ":" + key):
                        q.verify_footer(spec, spec.footer + " " + json.dumps(value), "Linux")

    def test_original_result_required_and_reopened(self):
        spec = q.inventory("contact-w1")[1]
        footer = payload(spec)
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            with self.assertRaises(RuntimeError):
                q.verify_result_file(spec, directory, footer)
            value = structured_result(spec, footer)
            path = directory / (spec.name + ".json")
            q.write_json(path, value)
            self.assertEqual(q.verify_result_file(spec, directory, footer)["sha256"], q.digest(path))
            value["cases"].pop()
            q.write_json(path, value)
            with self.assertRaises(RuntimeError):
                q.verify_result_file(spec, directory, footer)

    def test_replay_case_inventory_and_dispositions_refuse_false_green(self):
        spec = q.inventory("contact-w1")[1]
        footer = payload(spec)
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            path = directory / (spec.name + ".json")
            original = structured_result(spec, footer)
            mutations = []
            for label, field, invalid in (
                ("missing-id", "id", None),
                ("duplicate-id", "id", original["cases"][1]["id"]),
                ("missing-case-assertions", "failure_count", None),
                ("case-failure", "failure_count", 1),
                ("bool-case-assertions", "failure_count", False),
                ("wrong-disposition", "outcome", "Applied"),
                ("quarantined", "outcome", "Quarantined"),
                ("refusal-mutation", "after_sha256", "b" * 64),
            ):
                value = copy.deepcopy(original)
                value["cases"][0][field] = invalid
                mutations.append((label, value))
            value = copy.deepcopy(original)
            value["cases"][0], value["cases"][1] = value["cases"][1], value["cases"][0]
            mutations.append(("reordered", value))
            value = copy.deepcopy(original)
            value["cases"] = [{}] * 17
            mutations.append(("empty-records", value))
            value = copy.deepcopy(original)
            value["fixture_sha256"] = "0" * 64
            mutations.append(("wrong-fixture", value))
            value = copy.deepcopy(original)
            next(case for case in value["cases"] if case["expected_accepted"])["outcome"] = "GeometryBlocked"
            mutations.append(("positive-control-refused", value))
            for label, value in mutations:
                q.write_json(path, value)
                with self.assertRaises(RuntimeError, msg=label):
                    q.verify_result_file(spec, directory, footer)

    def test_concise_contact_footer_requires_original_complete_trace(self):
        spec = next(x for x in q.inventory("contact-w1") if x.script == "test_solid_detachment_contact_recovery")
        original = payload(spec)
        footer = {key: value for key, value in original.items() if key != "cases"}
        self.assertEqual(q.verify_footer(spec, spec.footer + " " + json.dumps(footer), "Linux"), footer)
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)
            path = output / (spec.name + ".json")
            with self.assertRaisesRegex(RuntimeError, "Missing original"):
                q.verify_result_file(spec, output, footer)
            q.write_json(path, original)
            self.assertEqual(q.verify_result_file(spec, output, footer)["sha256"], q.digest(path))
            for mutate in (lambda d: d["cases"].pop(), lambda d: d["cases"][0].update(trace=[]),
                           lambda d: d["cases"][0].update(sand_after=99),
                           lambda d: d["cases"][0]["metrics"]["physical_contact"].update(worker_contact_ms_total=0)):
                value = copy.deepcopy(original)
                mutate(value)
                q.write_json(path, value)
                with self.assertRaises(RuntimeError):
                    q.verify_result_file(spec, output, footer)
            q.write_json(path, footer)
            with self.assertRaises(RuntimeError):
                q.verify_result_file(spec, output, footer)

    def test_synchronized_complete_steps_keep_physical_failure_separate(self):
        spec = next(x for x in q.inventory("mechanism") if x.workers == 1)
        footer = payload(spec)
        original = synchronized_result(spec, footer)
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            path = directory / (spec.name + ".json")
            q.write_json(path, original)
            checked = q.verify_result_file(spec, directory, footer)
            self.assertEqual(checked["sha256"], q.digest(path))
            outcome = checked["physical_outcomes"]
            self.assertFalse(outcome["physical_accepted"])
            self.assertEqual(len(outcome["sustained_clearance_failures"]), 21)
            self.assertEqual(len(outcome["cases"]), 21)
            self.assertTrue(all(case["overlap_cell_ticks"] == 180 for case in outcome["cases"]))

    def test_synchronized_compound_cell_union_allows_sibling_seam(self):
        spec = next(x for x in q.inventory("mechanism") if x.workers == 1)
        value = synchronized_result(spec, payload(spec))
        metrics = value["geometries"][0]["proxy_metrics"]
        # A single rotated native cell can intersect two disjoint proxy areas.
        # Each proxy counts one cell; the compound union still counts one.
        metrics[0] = [1, 0.5, 1, 1]
        metrics[1] = [2, 0.5, 1, 1]
        self.assertEqual(len(q.verify_synchronized_result(value, spec)["cases"]), 21)
        for outside_union in (0, 3):
            value["geometries"][0]["overlap_cells"] = outside_union
            with self.assertRaisesRegex(RuntimeError, "unique overlap cells"):
                q.verify_synchronized_result(value, spec)

    def test_synchronized_incomplete_or_invented_evidence_is_refused(self):
        spec = next(x for x in q.inventory("mechanism") if x.workers == 1)
        original = synchronized_result(spec, payload(spec))
        mutations = {
            "missing-source": lambda d: d["input_hashes"].pop("scripts/solid_contact_response.gd"),
            "wrong-current-source": lambda d: d.update(current_planner_sha256="0" * 64),
            "wrong-frozen-source": lambda d: d.update(frozen_planner_source="0" * 40),
            "missing-control": lambda d: d["controls"].pop(),
            "unsupported-interior-control": lambda d: d["controls"][2]["boundary_control"].update(contacts=[]),
            "interior-material-mutation": lambda d: d["controls"][2].update(native_content_hash_after="e" * 16),
            "interior-grid-mutation": lambda d: d["controls"][2].update(native_material_cells_preserved=False),
            "interior-payload-mutation": lambda d: d["controls"][2].update(payload_preserved=False),
            "changed-member-tuple": lambda d: d["source"]["members"].__setitem__(2, 2),
            "missing-hole": lambda d: d["geometries"][0]["hole_witnesses"].pop(),
            "wrong-rotated-corner": lambda d: d["geometries"][0]["proxies"][0][0].__setitem__(0, 999),
            "wrong-compound-measure": lambda d: d["geometries"][0].update(overlap_area=2),
            "truncated-native-field": lambda d: next(iter(d["native_fields"].values()))["material_runs"].pop(),
            "missing-case": lambda d: d["cases"].pop(),
            "duplicated-case": lambda d: d["cases"].__setitem__(1, d["cases"][0]),
            "wrong-workers": lambda d: d["cases"][0].update(workers=4),
            "native-mutation": lambda d: d["cases"][0].update(native_state_hash_after="c" * 16),
            "native-integration": lambda d: d["cases"][0].update(ordinary_native_integration=True),
            "missing-step": lambda d: d["cases"][0]["trace"].pop(),
            "duplicated-step": lambda d: d["cases"][0]["trace"][1].update(step=1),
            "missing-measurement": lambda d: d["cases"][0]["trace"][1].pop("measurement"),
            "wrong-geometry-reference": lambda d: d["cases"][0]["trace"][1]["measurement"].update(geometry_sha256="0" * 64),
            "wrong-revision": lambda d: d["cases"][0]["trace"][1]["receipt"].update(revision="2"),
            "mis-aged-receipt": lambda d: d["cases"][0]["trace"][1]["receipt"].update(sample_age=2),
            "sleep-confound": lambda d: d["cases"][0]["trace"][1]["after"].update(sleeping=True),
            "nonfinite-state": lambda d: d["cases"][0]["trace"][1]["after"].update(omega=float("nan")),
            "refused-impulse": lambda d: d["cases"][0]["trace"][1]["response"].update(impulses=[{"impulse": [0, 1], "offset": [0, 0]}]),
            "incomplete-response-stage": lambda d: d["cases"][1]["trace"][1]["response"].update(planner_ms=0.1),
            "owner-stage-understatement": lambda d: d["cases"][0]["trace"][1]["measurement"].update(owner_ms=0.9),
            "too-many-support-probes": lambda d: d["cases"][0]["trace"][1]["measurement"].update(support_probes=18),
            "incomplete-support-footprint": lambda d: d["cases"][0]["trace"][1]["measurement"].update(support_probes=8),
            "understated-attempts": lambda d: d["cases"][0]["stats"].update(owner_attempts=180),
            "understated-owner-work": lambda d: d["cases"][0]["stats"].update(owner_ms_total=180),
            "missing-diagnostic-work": lambda d: d["cases"][0]["stats"].update(matched_planner_ms_total=0),
            "wrong-overlap-denominator": lambda d: d["cases"][0]["stats"].update(overlap_cell_ticks=179),
            "hidden-queue-loss": lambda d: d["cases"][12]["stats"].update(overwritten=0),
            "hidden-stale-refusal": lambda d: d["cases"][19]["stats"].update(response_refusals={}),
            "integer-clearance-flag": lambda d: d["cases"][0]["physical_gates"].update(sustained_clearance_pass=0),
            "invented-clearance": lambda d: d["cases"][0]["physical_gates"].update(sustained_clearance_pass=True),
            "redefined-depth": lambda d: d["cases"][0]["physical_gates"].update(allowed_depth=10),
            "promoted-physical-acceptance": lambda d: d["cases"][0]["physical_gates"].update(physical_accepted=True),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                value = copy.deepcopy(original)
                mutate(value)
                with self.assertRaises(RuntimeError):
                    q.verify_synchronized_result(value, spec)

    def test_tracked_source_byte_mutation_is_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            attributes = root / ".gitattributes"
            attributes.write_bytes(b"*.cpp text eol=lf\n")
            (root / "native").mkdir()
            file = root / "native/fixture.cpp"
            file.write_bytes(b"canonical\n")
            subprocess.run(["git", "-C", str(root), "add", "."], check=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                            "commit", "-qm", "reader fixture"], check=True)
            with patch.object(q, "ROOT", root):
                self.assertEqual(q.source_inputs(), {"native/fixture.cpp": hashlib.sha256(b"canonical\n").hexdigest(),
                    ".gitattributes": hashlib.sha256(attributes.read_bytes()).hexdigest()})
                file.write_bytes(b"uncommitted mutation\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()

    def test_only_committed_crlf_conversion_is_admitted_and_raw_identity_is_retained(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            attributes = root / ".gitattributes"
            attributes.write_bytes(b"*.ps1 text eol=crlf\n*.cpp text eol=lf\n")
            (root / "tools").mkdir()
            (root / "native").mkdir()
            script = root / "tools/fixture.ps1"
            native = root / "native/fixture.cpp"
            script.write_bytes(b"first\nsecond\n")
            native.write_bytes(b"exact native source\n")
            subprocess.run(["git", "-C", str(root), "add", "."], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                            "commit", "-qm", "explicit CRLF checkout fixture"], check=True)
            with patch.object(q, "ROOT", root):
                canonical = q.source_inputs()
                raw_lf = q.checkout_inputs(canonical)
                script.write_bytes(b"first\r\nsecond\r\n")
                self.assertEqual(q.source_inputs(), canonical)
                raw_crlf = q.checkout_inputs(canonical)
                self.assertEqual(set(raw_lf), set(raw_crlf))
                self.assertNotEqual(raw_lf, raw_crlf)
                self.assertEqual(raw_crlf["tools/fixture.ps1"], hashlib.sha256(script.read_bytes()).hexdigest())
                for invalid in (b"first\r\nsecond\n", b"first\r\nchanged\r\n"):
                    script.write_bytes(invalid)
                    with self.assertRaises(RuntimeError):
                        q.source_inputs()
                script.write_bytes(b"first\r\nsecond\r\n")
                native.write_bytes(b"exact native source\r\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()
                attributes.write_bytes(b"*.ps1 text eol=crlf\n*.cpp text eol=crlf\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()
                attributes.write_bytes(b"*.ps1 text eol=crlf\n*.cpp text eol=lf\n")
                native.write_bytes(b"exact native source\n")
                (root / ".git/info/attributes").write_bytes(b"*.cpp eol=crlf\n")
                with self.assertRaises(RuntimeError):
                    q.source_inputs()

    def test_lf_checkout_default_preserves_real_attributes_and_explicit_ps1_crlf(self):
        # core.autocrlf=false alone retains the platform's core.eol default.
        # Reproduce the Windows CRLF default portably, then apply the hosted fix.
        attributes = q.git("show", "HEAD:.gitattributes")
        source = {".gitattributes": attributes,
                  "tools/fixture.ps1": b"first\nsecond\n",
                  "tools/implicit-eol.txt": b"ordinary auto text\n",
                  "native/fixture.cpp": b"explicit LF source\n"}
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            def git(*args):
                return subprocess.check_output(["git", "-C", str(root), "-c", "core.attributesFile=" + os.devnull,
                    *args], stderr=subprocess.PIPE, env={**os.environ, "GIT_ATTR_NOSYSTEM": "1"})
            git("init", "-q")
            git("config", "core.autocrlf", "false")
            git("config", "core.eol", "crlf")
            for relative, raw in source.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "commit", "-qm", "actual attributes checkout regression")
            for relative in source:
                (root / relative).unlink()
            git("checkout-index", "--all", "--force")
            self.assertEqual((root / ".gitattributes").read_bytes(), attributes.replace(b"\n", b"\r\n"))
            self.assertEqual((root / "tools/implicit-eol.txt").read_bytes(), b"ordinary auto text\r\n")
            with patch.object(q, "ROOT", root):
                with self.assertRaisesRegex(RuntimeError, "Checkout .gitattributes differs from Git"):
                    q.source_inputs()
                git("config", "core.eol", "lf")
                for relative in source:
                    (root / relative).unlink()
                git("checkout-index", "--all", "--force")
                self.assertEqual((root / ".gitattributes").read_bytes(), attributes)
                self.assertEqual((root / "tools/fixture.ps1").read_bytes(), b"first\r\nsecond\r\n")
                self.assertEqual((root / "tools/implicit-eol.txt").read_bytes(), source["tools/implicit-eol.txt"])
                self.assertEqual((root / "native/fixture.cpp").read_bytes(), source["native/fixture.cpp"])
                self.assertEqual(q.source_inputs(), {path: hashlib.sha256(raw).hexdigest() for path, raw in source.items()})

    def test_complete_aggregate_rejects_missing_and_altered_evidence(self):
        source = {"sha": "a" * 40, "tree": "b" * 40}
        with tempfile.TemporaryDirectory() as temp, patch.object(q, "source_identity", return_value=source), \
                patch.object(q, "source_inputs", return_value={"fixture": "identity"}):
            directory = Path(temp)
            first_path = None
            for platform in ("Linux", "Windows"):
                for cohort in q.COHORTS:
                    output = directory / (platform + "-" + cohort)
                    output.mkdir()
                    q.write_json(output / "inputs-before.json", {"fixture": "identity"})
                    q.write_json(output / "inputs-after.json", {"fixture": "identity"})
                    q.write_json(output / "checkout-inputs-before.json", {"fixture": "raw-" + platform})
                    q.write_json(output / "checkout-inputs-after.json", {"fixture": "raw-" + platform})
                    cases = q.inventory(cohort)
                    records = []
                    for spec in cases:
                        readback = payload(spec, platform) if spec.structured else None
                        if spec.script == "test_solid_detachment_contact_recovery":
                            readback.pop("cases")
                        text = spec.footer + (" " + json.dumps(readback) if spec.structured else "") + "\n"
                        log = output / (spec.name + ".log")
                        log.write_text(text, encoding="utf-8")
                        if spec.script in q.RESULT_FILES:
                            data = structured_result(spec, readback)
                            q.write_json(output / (spec.name + ".json"), data)
                        records.append({"name": spec.name, "status": "passed", "returncode": 0,
                            "natural_completion": True, "skip_messages": [], "readback": readback,
                            "log": log.name, "log_sha256": q.digest(log),
                            "result": q.verify_result_file(spec, output, readback)})
                    report = {"schema": "cybersand.sol281.qualification.v1", "status": "passed", "source": source,
                        "platform": platform, "cohort": cohort, "source_unchanged": True, "errors": [],
                        "checkout_inputs_unchanged": True,
                        "runtime": {"sha256": platform}, "expected_cases": [x.name for x in cases], "records": records}
                    q.write_json(output / "report.json", report)
                    if first_path is None:
                        first_path = output / "report.json"
            args = argparse.Namespace(input=directory, output=directory / "summary.json")
            with redirect_stdout(io.StringIO()):
                self.assertEqual(q.summarize(args), 0)
                # Agreement between all eight cohorts is insufficient: the
                # reducer must also authenticate their inventory against HEAD.
                inventories = list(directory.rglob("inputs-before.json")) + list(directory.rglob("inputs-after.json"))
                for inventory in inventories:
                    q.write_json(inventory, {"fixture": "self-consistent-wrong-source"})
                self.assertEqual(q.summarize(args), 1)
                for inventory in inventories:
                    q.write_json(inventory, {"fixture": "identity"})
                self.assertEqual(q.summarize(args), 0)
                raw_after = first_path.parent / "checkout-inputs-after.json"
                raw_original = raw_after.read_bytes()
                q.write_json(raw_after, {"fixture": "changed raw bytes with identical canonical source"})
                self.assertEqual(q.summarize(args), 1)
                raw_after.write_bytes(raw_original)
                self.assertEqual(q.summarize(args), 0)
                original = first_path.read_bytes()
                first_path.unlink()
                self.assertEqual(q.summarize(args), 1)
                first_path.write_bytes(original)
                log = first_path.parent / "motion-w1.log"
                log.write_text(log.read_text() + "unrecorded change\n")
                self.assertEqual(q.summarize(args), 1)


if __name__ == "__main__":
    unittest.main()
