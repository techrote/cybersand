"""Reduce registered operational GCR interventions without promoting a law.

Actuator delivery is measured around the direct actuator stage. In particular,
native-sample-to-application velocity gaps are not reused for T, whose sample is
deliberately moved after that stage. X keeps the bridge's corrected-COM wrench;
its observed post-delivery translation cancellation is accounted separately.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import math
from pathlib import Path

from analyze_gcr_creep import (EvidenceError, application_summary, conservation,
                               integer, motion, number, read, require, same_json,
                               sha, validate_capture, vector)

TC = "GCR-CAUSAL-TC-001-2026-11-03"
EVENT = "GCR-CAUSAL-EVENT-001-2026-11-03"
POPULATIONS = {TC: 12, EVENT: 8}


def length(value):
    return math.hypot(*value)


def close(actual, expected, tolerance=1e-5):
    return number(actual) and number(expected) and abs(actual - expected) <= tolerance * max(1, abs(expected))


def close_vector(actual, expected, tolerance=1e-5):
    return vector(actual) and vector(expected) and math.dist(actual, expected) <= tolerance * max(1, length(expected))


def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def validate_phase(row, spec, registration, tolerance):
    phase = row.get("causal_phase")
    require(isinstance(phase, dict), "Missing causal phase ledger")
    expected_arm = spec["arm"] if registration == TC else "C"
    require(phase.get("arm") == expected_arm, "Wrong operational pipeline arm")
    counts = phase.get("counts", {})
    expected_count = 1 if spec["kind"] == "flyer" else 0
    require(all(integer(counts.get(key)) and counts[key] == value for key, value in {
        "actuation": expected_count, "sample": 1, "native_tick": 1, "rapier_step": 1, "response_calls": 1}.items()),
        "Causal pipeline duplicated or omitted an owned stage")
    before_counter, after_counter = phase.get("counter_before", {}), phase.get("counter_after", {})
    require(all(integer(stage.get(key)) for stage in (before_counter, after_counter) for key in
                ("native_tick", "rapier_steps", "session_tick", "packed_sample", "last_applied_sample", "last_snapshot")),
            "Missing observed causal stage counters")
    require(after_counter["native_tick"] - before_counter["native_tick"] == counts["native_tick"]
            and after_counter["rapier_steps"] - before_counter["rapier_steps"] == counts["rapier_step"]
            and (after_counter["packed_sample"] - before_counter["packed_sample"]) % 1000000 == counts["sample"]
            and after_counter["session_tick"] - before_counter["session_tick"] == phase.get("observed_session_tick_delta") == 1,
            "Observed clock/sample/actuator counters disagree with pipeline")
    applied_identity = row["application"]["bodies"][0]
    require(phase.get("fresh_sample_applied") is True and after_counter["last_applied_sample"] == applied_identity["sample"]
            and after_counter["last_applied_sample"] != before_counter["last_applied_sample"]
            and after_counter["last_snapshot"] == row["application"]["snapshot"], "Observed counters do not witness a fresh response")
    actuation = phase.get("actuation")
    require(isinstance(actuation, dict) and actuation.get("count") == expected_count, "Actuator count disagreement")
    controller = row["controller"]
    if spec["kind"] == "barrel":
        require(controller["actual_impulse"] == [0, 0] and controller["actual_torque_impulse"] == 0
                and actuation.get("actual_impulse") == [0, 0] and actuation.get("actual_torque_impulse") == 0,
                "Registered passive barrel acquired an actuator")
        return
    before, after = actuation.get("before", {}), actuation.get("after", {})
    require(all(integer(stage.get("rig_tick")) for stage in (before_counter, after_counter))
            and after_counter["rig_tick"] - before_counter["rig_tick"] == 1
            and actuation.get("rig_tick_before") == before_counter["rig_tick"]
            and actuation.get("rig_tick_after") == after_counter["rig_tick"]
            and actuation.get("advance_call_count") == 1, "Missing actual actor-stage counter witness")
    for stage in (before, after):
        require(vector(stage.get("position")) and vector(stage.get("velocity"))
                and number(stage.get("rotation")) and number(stage.get("omega")), "Missing direct actuator state")
    mass, inertia = actuation.get("actual_mass"), actuation.get("actual_inertia")
    require(number(mass) and mass > 0 and number(inertia) and inertia > 0, "Invalid direct actuator mass properties")
    require(close(mass, applied_identity.get("actual_mass"), 1e-6)
            and close(inertia, applied_identity.get("actual_inertia"), 1e-6), "Actuator/response mass properties disagree")
    expected_impulse = [mass * (after["velocity"][axis] - before["velocity"][axis]) for axis in range(2)]
    expected_torque = inertia * (after["omega"] - before["omega"])
    require(close_vector(actuation.get("actual_impulse"), expected_impulse, tolerance)
            and close(actuation.get("actual_torque_impulse"), expected_torque, tolerance), "Direct actuator impulse does not close")
    require(controller.get("impulse_measurement") == "direct-actuation-stage-backend-velocity-difference"
            and controller.get("measurement_valid") is True, "Actuator observation is not the direct stage")
    require(close_vector(controller["actual_impulse"], expected_impulse, tolerance)
            and close(controller["actual_torque_impulse"], expected_torque, tolerance), "Controller aliases disagree with direct actuator stage")
    require(actuation.get("pose_unchanged") is True and close_vector(before["position"], after["position"], 1e-12)
            and close(before["rotation"], after["rotation"], 1e-12), "Actuation changed pose before sampling")
    sample = phase.get("sample", {})
    expected_stage = after if expected_arm == "T" else before
    require(sample.get("count") == 1 and sample.get("phase") == ("after-actuation" if expected_arm == "T" else "before-actuation"), "Sample phase is not the registered intervention")
    require(close_vector(sample.get("position"), expected_stage["position"], tolerance)
            and close(sample.get("rotation"), expected_stage["rotation"], tolerance)
            and close_vector(sample.get("velocity"), expected_stage["velocity"], tolerance)
            and close(sample.get("omega"), expected_stage["omega"], tolerance), "Sample state does not witness actuator ordering")
    applied = row["application"]["bodies"][0]
    require(sample.get("serial") == applied.get("sample") and sample.get("session") == applied.get("session"), "Causal sample/application identity mismatch")
    if spec["drive"] == "unactuated":
        require(expected_impulse == [0, 0] and expected_torque == 0, "Zero-ceiling fixture has nonzero measured actuation")


def validate_setter(row, spec, registration, gravity, tolerance):
    """Validate offered, observed and cancelled translations independently."""
    setter = row["causal_phase"].get("correction_setter")
    if registration == EVENT and spec["kind"] == "barrel":
        require(setter is None, "Event barrel acquired a position intervention")
        return
    require(isinstance(setter, dict) and setter.get("accepted") is True, "Position operation did not qualify")
    arm = spec["arm"] if registration == TC else "C"
    require(setter.get("arm") == arm, "Wrong position operation")
    for key in ("proposed_correction", "observed_translation", "pre_response_origin", "after_response_origin",
                "final_origin", "applied_translation", "inverse_translation", "velocity_before_setter", "velocity_after_setter"):
        require(vector(setter.get(key)), "Missing position ledger vector " + key)
    body = row["application"]["bodies"][0]
    require(setter.get("sample") == body.get("sample") and setter.get("session") == body.get("session"), "Position setter used a different application")
    before, delivered, final = setter["pre_response_origin"], setter["after_response_origin"], setter["final_origin"]
    require(close_vector(before, body.get("current_origin"), 1e-12)
            and close_vector(setter["velocity_before_setter"], body.get("velocity_after_wrench"), 1e-12)
            and close(setter.get("omega_before_setter"), body.get("omega_after_wrench"), 1e-12),
            "Position operation is not bound to original response receipt")
    observed = [delivered[axis] - before[axis] for axis in range(2)]
    offset = [final[axis] - delivered[axis] for axis in range(2)]
    require(close_vector(setter["observed_translation"], observed, tolerance)
            and close_vector(setter["applied_translation"], offset, tolerance), "Observed position translation does not close")
    require(close_vector(setter["proposed_correction"], body.get("correction"), tolerance), "Offered correction differs from original bridge receipt")
    translated = observed != [0, 0]
    expected_setters = int(translated and arm in ("S", "X"))
    require(integer(setter.get("setter_count")) and setter["setter_count"] == expected_setters, "Position setter condition/count changed")
    require(close_vector(setter["velocity_before_setter"], setter["velocity_after_setter"], 1e-12)
            and close(setter.get("omega_before_setter"), setter.get("omega_after_setter"), 1e-12), "Position operation changed velocity")
    require(close(setter.get("rotation_roundtrip_delta"), setter.get("rotation_after_setter", math.inf) - setter.get("rotation_before_setter", math.inf), 1e-12)
            and abs(setter["rotation_roundtrip_delta"]) <= 1e-5, "Position setter exceeded registered rotation roundtrip tolerance")
    if arm == "X" and translated:
        require(close_vector(final, before, 1e-12), "X did not restore the actual pre-response origin")
        require(close_vector(setter["inverse_translation"], offset, tolerance), "X inverse translation disagreement")
    else:
        require(close_vector(final, delivered, 1e-12) and setter["inverse_translation"] == [0, 0], "Control/sham translated the body")
    impulse = body["impulse"]
    proposed_cross = cross(setter["proposed_correction"], impulse)
    observed_cross = cross(observed, impulse)
    require(close(setter.get("proposed_c_cross_J"), proposed_cross, tolerance)
            and close(setter.get("observed_c_cross_J"), observed_cross, tolerance), "Correction torque transport ledger does not close")
    require(close(setter.get("retained_angular_impulse"), body["angular_impulse"], tolerance)
            and close(setter.get("counterfactual_no_correction_bridge_angular_impulse"), body["angular_impulse"] + proposed_cross, tolerance), "X hid retained corrected-COM torque")
    mass = body["actual_mass"]
    require(close(setter.get("offset_potential_delta"), -mass * gravity * offset[1], tolerance), "Setter potential-energy ledger does not close")
    require(close(setter.get("observed_bridge_potential_delta"), -mass * gravity * observed[1], tolerance), "Observed bridge potential-energy ledger does not close")


def validate_event_capture(raw, spec):
    native_hash = raw.get("initial_native_hash")
    require(isinstance(native_hash, str) and len(native_hash) == 16
            and all(character in "0123456789abcdefABCDEF" for character in native_hash),
            "Missing/malformed initial native physical hash")
    reconstruction = raw.get("native_reconstruction", {})
    require(isinstance(reconstruction, dict) and reconstruction.get("accepted") is True, "Fresh native reconstruction did not qualify")
    options = reconstruction.get("requested_options", {})
    require(close(options.get("contact"), spec["contact_gain"], 1e-12)
            and options.get("bearing_candidate") == "GCR-REST" and options.get("gcr_rest_mode") == "control"
            and options.get("gcr_base_budget") == 20 and options.get("workers") == 1, "Wrong event construction options")
    require(reconstruction.get("native_tick_after") == 0
            and same_json(reconstruction.get("body_before"), reconstruction.get("body_after")), "Event reset changed body or advanced native time")
    if spec["kind"] == "flyer":
        require(reconstruction.get("session_before") == reconstruction.get("session_after")
                and reconstruction.get("upright_prime") is True, "Event reconstruction lost body session/initial occupancy")
        require(raw.get("initial_authoring", {}).get("accepted") is True, "Event room authoring failed")
    counts = raw["before"]["counts"]
    require(all(value == 0 for index, value in enumerate(counts) if index not in (0, 1, spec["material"])), "Event fixture contains an additional active material channel")
    for row in raw["rows"]:
        gcr, channel = row["gcr"], row.get("event_channel", {})
        require(gcr.get("legacy_non_granular") == [0, 0], "Contact gain changed a non-granular response")
        require(close(channel.get("gain_requested"), spec["contact_gain"], 1e-12), "Row event-gain request disagrees with fixture")
        if spec["kind"] == "flyer":
            before, after = channel.get("native_counter_before"), channel.get("native_counter_after")
            require(integer(before) and integer(after) and after >= before and channel.get("native_blocked_contacts") == after - before, "Native blocked-contact counter is not a same-tick delta")
        else:
            require(channel.get("native_blocked_contacts") is None, "Retained barrel cannot expose pure native contact count")
        if spec["arm"] == "E0":
            require(gcr.get("event_raw") == [0, 0] and gcr.get("event_accepted") == [0, 0]
                    and gcr.get("event_raw_torque") == 0 and gcr.get("event_torque") == 0
                    and gcr.get("event_budget_cost") == 0, "Event removal was not applied before passive evaluation")


def validate_calibration(report, identity, protocol_hash, platform):
    """Behavioral gain readback must preserve the native contact experiment."""
    require(report.get("ok") is True and report.get("errors") == [] and integer(report.get("checks")) and report["checks"] > 0,
            "Failed event calibration/mechanical gate")
    actual = report.get("identity", {})
    expected = identity["platforms"][platform]
    require(actual.get("source") == identity["source"] and actual.get("input_identity") == identity["source_inputs_sha256"]
            and actual.get("protocol_sha256") == protocol_hash
            and all(actual.get(key) == expected.get(key) for key in ("native_sha256", "engine_sha256")),
            "Event mechanical witness is not source/runtime/protocol bound")
    calibration = report.get("calibration", {})
    control, muted = calibration.get("control", {}), calibration.get("muted", {})
    for witness, gain in ((control, .025), (muted, 0)):
        gcr = witness.get("gcr", {})
        count = witness.get("native_blocked_contacts")
        require(witness.get("ok") is True and witness.get("errors") == [] and witness.get("tick_ok") is True
                and integer(count) and count > 0 and witness.get("counter_after", -1) - witness.get("counter_before", -1) == count,
                "Gain witness lacks positive native blocked-contact generation")
        require(witness.get("moves") == 0 and witness.get("material_cells_unchanged") is True
                and witness.get("counts_before") == witness.get("counts_after")
                and witness.get("water_before") == witness.get("water_after") == 0,
                "Gain witness changed authoritative material")
        require(gcr.get("nodes") == 0 and gcr.get("legacy_non_granular") == [0, 0] and gcr.get("event_scale") == 1,
                "Gain witness contains passive or legacy response")
        require(vector(gcr.get("event_raw")) and close(witness.get("effective_gain"), gain, 1e-7)
                and close(gcr["event_raw"][1] * 1000 / (count * 1600), gain, 1e-7), "Effective event gain does not close")
    require(control.get("native_blocked_contacts") == muted.get("native_blocked_contacts")
            and control.get("native_hash_after") == muted.get("native_hash_after") and bool(control.get("native_hash_after"))
            and control.get("counts_before") == muted.get("counts_before"), "Event intervention changed native calibration path")
    parity = report.get("control_parity", {})
    require(parity.get("old_ok") is True and parity.get("new_ok") is True
            and all(close(parity.get(key), 0, 1e-5) for key in ("maximum_position_error", "maximum_velocity_error",
                "maximum_rotation_error", "maximum_omega_error", "maximum_impulse_error")), "Event retained-control parity failed")
    return {"ok": True, "positive_native_contacts": control["native_blocked_contacts"],
            "effective_control_gain": control["effective_gain"], "effective_muted_gain": muted["effective_gain"],
            "identical_native_post_tick_hash": control["native_hash_after"]}


def correction_summary(rows):
    offered, observed, offsets, effective = [], [], [], []
    cross_values, setter_counts, nominal_potential, observed_potential, offset_potential = [], [], [], [], []
    for row in rows:
        body = row["application"]["bodies"][0]
        correction = body["correction"]
        offered.append(correction)
        setter = row["causal_phase"].get("correction_setter")
        if setter is not None:
            delivery = setter["observed_translation"]
            offset = setter["applied_translation"]
            actual = [setter["final_origin"][axis] - setter["pre_response_origin"][axis] for axis in range(2)]
            setter_counts.append(setter["setter_count"])
            cross_values.append(setter["proposed_c_cross_J"])
            nominal_potential.append(setter.get("original_nominal_potential_delta", 0))
            observed_potential.append(setter["observed_bridge_potential_delta"])
            offset_potential.append(setter["offset_potential_delta"])
        else:
            delivery = [row["position"][axis] - body["current_origin"][axis] for axis in range(2)]
            offset, actual = [0, 0], delivery
            setter_counts.append(0)
            cross_values.append(cross(correction, body["impulse"]))
            nominal_potential.append(body.get("correction_potential_delta", 0))
        observed.append(delivery)
        offsets.append(offset)
        effective.append(actual)
    summed = lambda values: [sum(value[axis] for value in values) for axis in range(2)]
    return {"offered_correction_sum": summed(offered), "observed_bridge_translation_sum": summed(observed),
            "post_delivery_offset_sum": summed(offsets), "effective_translation_sum": summed(effective),
            "offered_active": sum(value != [0, 0] for value in offered),
            "observed_bridge_active": sum(value != [0, 0] for value in observed),
            "effective_translation_active": sum(length(value) > 1e-12 for value in effective),
            "setter_calls": sum(setter_counts), "retained_proposed_c_cross_J_sum": sum(cross_values),
            "nominal_bridge_potential_sum": sum(nominal_potential),
            "observed_bridge_potential_sum": sum(observed_potential) if len(observed_potential) == len(rows) else None,
            "post_delivery_potential_sum": sum(offset_potential) if len(offset_potential) == len(rows) else None,
            "scope": "X cancels observed withdrawal after original wrench delivery; offered correction and corrected-COM torque remain in original receipt"}


def window_summary(rows):
    direct = [row["causal_phase"]["actuation"]["actual_impulse"] for row in rows]
    angular = [row["causal_phase"]["actuation"]["actual_torque_impulse"] for row in rows]
    nodes = [row["gcr"].get("nodes") for row in rows]
    overlap = [row.get("effective_overlap", row.get("post_overlap")) for row in rows]
    overlap_values = [value for value in overlap if integer(value)]
    signatures = [str(row.get("rest_receipt", {}).get("bodies", [{}])[0].get("support_signature", "unmeasured")) for row in rows]
    pure_events = [row["event_channel"]["native_blocked_contacts"] for row in rows if isinstance(row.get("event_channel"), dict) and integer(row["event_channel"].get("native_blocked_contacts"))]
    return {"motion": motion(rows), "contact_node_frames": sum(number(value) and value > 0 for value in nodes),
            "contact_node_duty": sum(number(value) and value > 0 for value in nodes) / len(rows),
            "support_signature_count": len(set(signatures)),
            "effective_overlap_max": max(overlap_values) if overlap_values else None,
            "effective_overlap_coverage": len(overlap_values) / len(rows),
            "sampled_post_ejection_overlap_max": max((row["post_overlap"] for row in rows if integer(row.get("post_overlap"))), default=None),
            "hard_clear_frames": sum(row.get("hard_clearance") is True for row in rows),
            "hard_floor_frames": sum(row.get("hard_floor_contact") is True for row in rows),
            "direct_actuator_impulse_sum": [sum(value[axis] for value in direct) for axis in range(2)],
            "direct_actuator_angular_impulse_sum": sum(angular),
            "direct_zero_actuation_frames": sum(value == [0, 0] and torque == 0 for value, torque in zip(direct, angular)),
            "native_blocked_contacts": sum(pure_events) if len(pure_events) == len(rows) else None,
            "event_impulse_sum": [sum(row["gcr"]["event_accepted"][axis] for row in rows) for axis in range(2)],
            "event_budget_cost_sum": sum(row["gcr"]["event_budget_cost"] for row in rows),
            "computed_limiter_observations": dict(Counter(row["gcr"]["active_capacity_limiter"] for row in rows)),
            "material_move_reports_sum": sum(row["work"][1] for row in rows),
            "correction": correction_summary(rows), "applications": application_summary(rows)}


def reduce_capture(raw, spec, identity, protocol_hash, platform, protocol):
    registration = protocol["registration"]
    require(registration in POPULATIONS and raw.get("registration") == registration, "Wrong causal registration")
    rows = validate_capture(raw, spec, identity, protocol_hash, platform)
    require(len(rows) == 1800 and close(raw["dt"], protocol["dt"], 1e-12), "Causal capture horizon/timestep changed")
    require(raw.get("runtime_identity", {}).get("admission_variant") == "A1", "Missing native A1 identity")
    fixture = protocol["fixture_flyer"] if spec["kind"] == "flyer" else protocol["fixture_barrel_high"] if spec["geometry"] == "barrel-high" else protocol["fixture_barrel"]
    require(close(raw["actual_mass"], fixture["mass"], 1e-6), "Causal body mass changed")
    require(close(raw.get("gravity"), fixture["gravity"], 1e-12), "Causal gravity changed")
    if spec["kind"] == "flyer":
        require(close(raw["actual_inertia"], fixture["inertia"], 1e-6), "Causal body inertia changed")
    population = fixture["region"][2] * fixture["region"][3] if spec["kind"] == "flyer" else (fixture["width"] + 2) * (192 + fixture["depth"] + 1)
    balanced = conservation(raw, population)
    tolerance = protocol["tolerances"]["delivered_relative"]
    for row in rows:
        if spec["kind"] == "flyer":
            require(type(row["controller"].get("movement_limited")) is bool, "Missing explicit rig guard observation")
        else:
            require(integer(row.get("effective_overlap")) and row["effective_overlap"] >= 0,
                    "Missing complete effective-pose barrel overlap measurement")
        require(row["application_step"]["delivered_this_step"] is True and row["application"].get("accepted") is True
                and row["application"]["bodies"][0].get("age") == 0, "Causal capture lacks one fresh age0 application")
        receipt = row.get("rest_receipt", {})
        require(receipt.get("mode") == "control" and receipt.get("base_budget") == 20, "Native response mode/budget changed")
        driven = spec["drive"] == "sustained" and protocol["pulse_start"] <= row["tick"] < protocol["drive_end"]
        require(row["command_active"] == driven, "Causal pilot schedule changed")
        validate_phase(row, spec, registration, tolerance)
        validate_setter(row, spec, registration, raw["gravity"], tolerance)
    if registration == EVENT:
        validate_event_capture(raw, spec)
    applications = application_summary(rows)
    require(applications["unique_accepted_applications"] == len(rows) and applications["delivered_linear_measurement_complete"]
            and applications["delivered_angular_measurement_complete"], "Incomplete actual wrench-delivery measurement")
    require(applications["delivered_delta_v_relative_error_max"] <= tolerance
            and applications["delivered_delta_omega_relative_error_max"] <= tolerance, "Actual wrench delivery exceeds registered closure bound")
    windows = {name: window_summary(rows[int(bounds[0]):int(bounds[1])]) for name, bounds in protocol["windows"].items()}
    effective_overlap = [row.get("effective_overlap", row["post_overlap"]) for row in rows]
    positive = [index for index, value in enumerate(effective_overlap) if integer(value) and value > 0]
    first_hard = next((row["tick"] for row in rows if row.get("hard_clearance") is not True), None)
    return {"case": spec, "platform": platform, "status": "complete_operational_capture", "conservation": balanced,
            "initial_state": raw.get("initial_state"), "initial_native_hash": raw.get("initial_native_hash"),
            "initial_counts": raw["before"]["counts"], "actual_mass": raw["actual_mass"], "actual_inertia": raw["actual_inertia"],
            "first_hard_clearance_loss_tick": first_hard,
            "first_rig_guard_tick": next((row["tick"] for row in rows if row["controller"].get("movement_limited") is True), None),
            "first_hard_floor_tick": next((row["tick"] for row in rows if row.get("hard_floor_contact") is True), None),
            "reference_entry_peak": max((row["vertical_depth"] if number(row.get("vertical_depth")) else
                max(0, row["body_bounds"][3] - fixture["base"][1]) for row in rows
                if number(row.get("vertical_depth")) or isinstance(row.get("body_bounds"), list) and len(row["body_bounds"]) == 4
                and all(number(value) for value in row["body_bounds"])), default=None),
            "upward_velocity_max": max(0, -min(row["velocity"][1] for row in rows)),
            "zero_overlap_suffix_start": positive[-1] + 1 if positive and positive[-1] < len(rows) - 1 else 0 if not positive else None,
            "full_window": window_summary(rows), "windows": windows, "tail": windows["tail"],
            "scope": "Causal operational intervention in registered fixture; no production/owner acceptance"}


def compare_pair(control, candidate, control_raw, candidate_raw, protocol):
    require(same_json(control["initial_state"], candidate["initial_state"])
            and control["initial_counts"] == candidate["initial_counts"], "Matched causal arms have different initial body/material inputs")
    result = {"control": control["case"]["id"], "candidate": candidate["case"]["id"], "platform": control["platform"],
              "windows": {}, "initial_body_and_counts_match": True}
    end = min(value if value is not None else 1800 for capture in (control, candidate)
              for value in (capture["first_hard_clearance_loss_tick"], capture["first_rig_guard_tick"]))
    result["common_uncensored_end_exclusive"] = end
    result["censoring"] = {"control_first_hard": control["first_hard_clearance_loss_tick"],
        "candidate_first_hard": candidate["first_hard_clearance_loss_tick"], "control_first_rig_guard": control["first_rig_guard_tick"],
        "candidate_first_rig_guard": candidate["first_rig_guard_tick"],
        "scope": "Direct granular attribution only before first hard contact or rig safety/movement guard; later rows remain operational outcomes"}
    for name, bounds in protocol["windows"].items():
        a, b = control["windows"][name], candidate["windows"][name]
        travel_a, travel_b = a["motion"]["net_translation"][0], b["motion"]["net_translation"][0]
        duty_delta = b["contact_node_duty"] - a["contact_node_duty"]
        result["windows"][name] = {"horizontal_travel_control": travel_a, "horizontal_travel_candidate": travel_b,
                                     "horizontal_travel_difference": travel_b - travel_a, "contact_duty_difference": duty_delta,
                                     "hard_clear_control": a["hard_clear_frames"], "hard_clear_candidate": b["hard_clear_frames"],
                                     "effective_overlap_control": a["effective_overlap_max"], "effective_overlap_candidate": b["effective_overlap_max"],
                                     "direct_granular_comparison_supported": end >= bounds[1]}
    a_rows, b_rows = control_raw["rows"][:end], candidate_raw["rows"][:end]
    parity = {"observations": end,
        "maximum_position_error": max((math.dist(a["position"], b["position"]) for a, b in zip(a_rows,b_rows)), default=None),
        "maximum_velocity_error": max((math.dist(a["velocity"], b["velocity"]) for a, b in zip(a_rows,b_rows)), default=None),
        "maximum_rotation_error": max((abs(math.atan2(math.sin(a["rotation"]-b["rotation"]),math.cos(a["rotation"]-b["rotation"]))) for a,b in zip(a_rows,b_rows)), default=None),
        "maximum_omega_error": max((abs(a["omega"]-b["omega"]) for a,b in zip(a_rows,b_rows)), default=None)}
    parity["within_registered_tolerance"] = end > 0 and all(value <= 1e-5 for key,value in parity.items() if key.startswith("maximum"))
    result["common_uncensored_physical_parity"] = parity
    result["registered_null_comparison"] = (protocol["registration"] == TC and (candidate["case"]["arm"] == "S" or candidate["case"]["arm"] == "T" and candidate["case"]["drive"] == "unactuated")
        or protocol["registration"] == EVENT and candidate["case"]["geometry"] == "flat")
    if protocol["registration"] == TC:
        late = result["windows"]["drive_late"]
        threshold = max(.25, .25 * abs(late["horizontal_travel_control"]))
        result["registered_late_effect_threshold"] = threshold
        result["late_operational_reporting_effect"] = abs(late["horizontal_travel_difference"]) >= threshold or abs(late["contact_duty_difference"]) >= .10
        result["registered_late_reporting_effect"] = result["late_operational_reporting_effect"] if late["direct_granular_comparison_supported"] else None
        result["correction_operation_exercised"] = candidate["full_window"]["correction"]["setter_calls"] > 0 if candidate["case"]["arm"] in ("S", "X") else None
    else:
        at = 900 if end > 900 else end - 1
        if at >= 0:
            initial_y = control["initial_state"]["position"][1]
            descent_a = control_raw["rows"][at]["position"][1] - initial_y
            descent_b = candidate_raw["rows"][at]["position"][1] - initial_y
            threshold = max(2, .25 * abs(descent_a))
            result["descent_comparison"] = {"tick": at, "registered_tick900_supported": at == 900,
                                               "control": descent_a, "candidate": descent_b, "decrease": descent_a - descent_b,
                                               "threshold": threshold, "common_prefix_reporting_effect": descent_a - descent_b >= threshold,
                                               "registered_channel_effect": descent_a - descent_b >= threshold if at == 900 else None}
        else:
            result["descent_comparison"] = None
        result["initial_native_hash_match"] = control["initial_native_hash"] == candidate["initial_native_hash"]
        require(result["initial_native_hash_match"], "Fresh event arms begin from different native physical states")
    if control["case"]["kind"] == "barrel":
        require(control["full_window"].get("effective_overlap_coverage") == candidate["full_window"].get("effective_overlap_coverage") == 1,
                "Barrel guard lacks complete effective-pose overlap coverage")
        a_entry, b_entry = control["reference_entry_peak"], candidate["reference_entry_peak"]
        a_overlap, b_overlap = control["full_window"]["effective_overlap_max"], candidate["full_window"]["effective_overlap_max"]
        require(number(a_entry) and number(b_entry) and integer(a_overlap) and integer(b_overlap), "Missing barrel impact guard measurements")
        result["barrel_guards"] = {"entry_control": a_entry, "entry_candidate": b_entry,
                                      "entry_pass": b_entry <= a_entry + max(.5, .1 * a_entry),
                                      "overlap_control": a_overlap, "overlap_candidate": b_overlap,
                                      "overlap_pass": b_overlap <= a_overlap + max(1, .1 * a_overlap),
                                      "upward_velocity_control": control["upward_velocity_max"], "upward_velocity_candidate": candidate["upward_velocity_max"],
                                      "rebound_pass": candidate["upward_velocity_max"] <= control["upward_velocity_max"] + max(2, .25 * control["upward_velocity_max"])}
    return result


def validate_mechanical_gates(folder, platform, identity, protocol_hash, registration):
    gates_folder = folder.parent / platform
    gates = read(gates_folder / "gates.json")
    proofs = {}
    for test in ("test_gcr_causal_arena", "test_gcr_event_causal"):
        selected = [row for row in gates if row.get("test") == test]
        require(len(selected) == 1, "Missing/duplicate new mechanical gate " + test)
        gate = selected[0]
        log = gates_folder / (test + ".log")
        require(gate.get("ok") is True and gate.get("exit") == 0 and gate.get("timed_out") is False
                and gate.get("log_sha256") == sha(log) and "inherited_from" not in gate,
                "New mechanical gate lacks fresh successful hashed process proof " + test)
        proofs[test] = {"log_sha256": sha(log), "exit": 0}
    prefix = "GCR_CAUSAL_ARENA "
    lines = (gates_folder / "test_gcr_causal_arena.log").read_text(encoding="utf-8").splitlines()
    reports = [json.loads(line[len(prefix):]) for line in lines if line.startswith(prefix)]
    require(len(reports) == 1 and reports[0].get("failures") == 0 and integer(reports[0].get("checks")) and reports[0]["checks"] > 0,
            "Timing mechanical summary missing/failed")
    if registration == EVENT:
        path = gates_folder / "test_gcr_event_causal.json"
        proofs["event_gain_readback"] = validate_calibration(read(path), identity, protocol_hash, platform)
        proofs["event_gain_readback"]["sha256"] = sha(path)
    return proofs


def reduce_campaign(folder, protocol_path, platforms=None):
    folder = Path(folder)
    protocol = read(protocol_path)
    require(protocol.get("registration") in POPULATIONS and len(protocol.get("cases", [])) == POPULATIONS[protocol["registration"]], "Wrong causal population")
    identity, completion = read(folder / "identity.json"), read(folder / "completion.json")
    require(identity.get("protocol_sha256") == sha(protocol_path), "Causal campaign protocol binding failed")
    require(completion.get("ok") is True and completion.get("inputs_unchanged") is True and completion.get("complete_registered_population") is True
            and completion.get("source") == identity["source"] == completion.get("end_source")
            and completion.get("identity_sha256") == sha(folder / "identity.json")
            and completion.get("planned_captures") == completion.get("completed_captures") == 40
            and completion.get("complete_selected_lanes") is True and completion.get("selected_case") is None
            and completion.get("gates_only") is False
            and set(completion.get("selected_lanes", [])) == {"timing", "event"}
            and set(completion.get("selected_platforms", [])) == {"windows", "linux"}, "Incomplete causal campaign/end-input proof")
    platforms = protocol["platforms"] if platforms is None else platforms
    ids = [spec["id"] for spec in protocol["cases"]]
    require(len(set(ids)) == len(ids), "Duplicate registered causal IDs")
    results, failures, raw_captures = [], [], {}
    mechanical = {}
    for platform in platforms:
        mechanical[platform] = validate_mechanical_gates(folder, platform, identity, sha(protocol_path), protocol["registration"])
        records = read(folder / platform / "campaign.json")
        require([record.get("case") for record in records] == ids, "Causal acquisition case order/population changed")
        for spec, acquired in zip(protocol["cases"], records):
            path = folder / platform / (spec["id"] + ".json")
            try:
                require(acquired.get("ok") is True and acquired.get("exit") == 0 and acquired.get("identity_ok") is True
                        and acquired.get("raw_sha256") == sha(path) and acquired.get("rows") == spec["ticks"]
                        and acquired.get("log_sha256") == sha(path.with_suffix(".log")), "Causal raw/process acquisition mismatch")
                raw = read(path)
                result = reduce_capture(raw, spec, identity, sha(protocol_path), platform, protocol)
                result.update(file=path.relative_to(folder).as_posix(), sha256=sha(path))
                results.append(result)
                raw_captures[(platform, spec["id"])] = raw
            except (EvidenceError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
                failures.append({"platform": platform, "case": spec["id"], "reason": str(error), "sha256": sha(path) if path.is_file() else None})
    lookup = {(item["platform"], item["case"]["id"]): item for item in results}
    comparisons = []
    for candidate in results:
        arm = candidate["case"]["arm"]
        baseline_arm = "S" if protocol["registration"] == TC and arm == "X" and candidate["case"]["kind"] == "flyer" else "C"
        if arm == "C":
            continue
        baseline_id = candidate["case"]["id"].rsplit("-", 1)[0] + "-" + baseline_arm
        key = (candidate["platform"], baseline_id)
        if key not in lookup:
            continue
        baseline = lookup[key]
        try:
            comparisons.append(compare_pair(baseline, candidate, raw_captures[key], raw_captures[(candidate["platform"], candidate["case"]["id"])], protocol))
        except EvidenceError as error:
            failures.append({"platform": candidate["platform"], "case": candidate["case"]["id"], "reason": "Pair qualification: " + str(error)})
    for comparison in comparisons:
        if protocol["registration"] == TC and comparison["candidate"].endswith("-X") and not comparison["candidate"].startswith("barrel-"):
            sham = next((item for item in comparisons if item["platform"] == comparison["platform"] and item["candidate"] == comparison["control"]), None)
            comparison["sham_vs_control_physical_parity"] = sham["common_uncensored_physical_parity"] if sham else None
            comparison["translation_only_attribution_qualified"] = bool(sham and sham["common_uncensored_physical_parity"]["within_registered_tolerance"])
    return {"schema": "cybersand.gcr-causal.reduction.v1", "registration": protocol["registration"], "source": identity["source"],
            "protocol_sha256": sha(protocol_path), "identity_sha256": sha(folder / "identity.json"),
            "planned_captures": len(platforms) * len(ids), "complete_captures": len(results), "ok": not failures,
            "failures": failures, "mechanical": mechanical, "captures": results, "comparisons": comparisons,
            "production_selection": None, "owner_gameplay_acceptance": None,
            "scope": "Separate registered operational effects; X retains corrected-COM wrench, event removal changes event/budget/provisional state together"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", type=Path, required=True)
    parser.add_argument("--protocol", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--platform", choices=("both", "windows", "linux"), default="both")
    args = parser.parse_args()
    platforms = ["windows", "linux"] if args.platform == "both" else [args.platform]
    result = reduce_campaign(args.folder, args.protocol, platforms)
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"ok": result["ok"], "captures": result["complete_captures"], "failures": result["failures"]}))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
