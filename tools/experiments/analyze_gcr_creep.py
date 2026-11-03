"""Strict, observation-only reduction of GCR-LA creep and burrowing captures.

The reducer distinguishes an input command from the force actually submitted by
the controller. It does not infer correction causality, friction efficacy, sleep
admission, or whole-system passivity from a trajectory or a stage energy ledger.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path


class EvidenceError(ValueError):
    """The supplied evidence cannot support a complete capture reduction."""


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError("Duplicate JSON object key: " + key)
        result[key] = value
    return result


def read(path):
    """Reject duplicate keys and JSON extensions such as NaN/Infinity."""
    def bad_constant(value):
        raise EvidenceError("Nonfinite JSON constant: " + value)
    result = json.loads(Path(path).read_text(encoding="utf-8"),
                        object_pairs_hook=_unique_object,
                        parse_constant=bad_constant)
    _all_finite(result)
    return result


def _all_finite(value):
    if isinstance(value, float) and not math.isfinite(value):
        raise EvidenceError("Nonfinite numeric evidence")
    if isinstance(value, dict):
        for child in value.values():
            _all_finite(child)
    elif isinstance(value, list):
        for child in value:
            _all_finite(child)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def integer(value):
    # Godot JSON numbers are accepted only when exactly integral.
    return number(value) and value == int(value)


def vector(value):
    return isinstance(value, list) and len(value) == 2 and all(number(x) for x in value)


def require(condition, reason):
    if not condition:
        raise EvidenceError(reason)


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, math.ceil(len(ordered) * fraction) - 1)] if ordered else None


def _length(value):
    return math.hypot(*value)


def _kinetic(mass, inertia, velocity, omega):
    return .5 * mass * sum(x * x for x in velocity) + .5 * inertia * omega * omega


def motion(rows):
    if not rows:
        return None
    positions = [row["position"] for row in rows]
    angles = [row["rotation"] for row in rows]
    wrapped_deltas = [math.atan2(math.sin(b - a), math.cos(b - a))
                      for a, b in zip(angles, angles[1:])]
    return {
        "samples": len(rows),
        "first_tick": rows[0]["tick"], "last_tick": rows[-1]["tick"],
        "net_translation": [positions[-1][axis] - positions[0][axis] for axis in range(2)],
        "position_span": [max(p[axis] for p in positions) - min(p[axis] for p in positions) for axis in range(2)],
        "sampled_path_length": sum(math.dist(a, b) for a, b in zip(positions, positions[1:])),
        "net_rotation_unwrapped": sum(wrapped_deltas),
        "sampled_angular_travel": sum(abs(x) for x in wrapped_deltas),
        "speed_p50": percentile([_length(row["velocity"]) for row in rows], .5),
        "speed_p95": percentile([_length(row["velocity"]) for row in rows], .95),
        "speed_max": max(_length(row["velocity"]) for row in rows),
        "abs_omega_p95": percentile([abs(row["omega"]) for row in rows], .95),
        "scope": "Sampled physical state; path length excludes unobserved within-step motion",
    }


def application_summary(rows):
    """Deduplicate applications before accumulating correction and energy."""
    applications = []
    seen = set()
    refused = Counter()
    ages = Counter()
    missing = Counter()
    for row in rows:
        receipt = row.get("application")
        if receipt is None:
            missing["application"] += 1
            continue
        require(isinstance(receipt, dict), "Malformed application receipt")
        if receipt.get("accepted") is not True:
            refused[str(receipt.get("refusal", "unmeasured"))] += 1
            continue
        marker = row.get("application_step")
        if not isinstance(marker, dict) or marker.get("delivered_this_step") is not True:
            missing["accepted_but_not_new_this_step"] += 1
            continue
        bodies = receipt.get("bodies")
        require(isinstance(bodies, list) and len(bodies) == 1, "Accepted independent application must identify one body")
        body = bodies[0]
        require(isinstance(body, dict), "Malformed accepted body receipt")
        for key in ("session", "sample", "index", "age"):
            require(integer(body.get(key)), "Missing/nonintegral accepted application " + key)
        key = (body["session"], body["index"], body["sample"])
        if key in seen:
            continue
        seen.add(key)
        ages[str(int(body["age"]))] += 1
        applications.append(body)
    corrections = []
    potentials = []
    zeroing = []
    wrench_delta = []
    linear_errors = []
    angular_errors = []
    for body in applications:
        correction = body.get("correction")
        if vector(correction):
            corrections.append(correction)
        else:
            missing["correction"] += 1
        for name, values in (("correction_potential_delta", potentials), ("zeroing_removed_energy", zeroing)):
            if number(body.get(name)):
                values.append(body[name])
            else:
                missing[name] += 1
        before, after = body.get("kinetic_after_zeroing"), body.get("kinetic_after_wrench")
        if number(before) and number(after):
            wrench_delta.append(after - before)
        else:
            missing["wrench_energy_stages"] += 1
        mass, inertia = body.get("actual_mass"), body.get("actual_inertia")
        v0, v1, impulse = body.get("velocity_after_zeroing"), body.get("velocity_after_wrench"), body.get("impulse")
        w0, w1, torque = body.get("omega_after_zeroing"), body.get("omega_after_wrench"), body.get("angular_impulse")
        if number(mass) and mass > 0 and vector(v0) and vector(v1) and vector(impulse):
            linear_errors.append(math.hypot(*(v1[i] - v0[i] - impulse[i] / mass for i in range(2))))
        else:
            missing["delivered_linear_closure"] += 1
        if number(inertia) and inertia > 0 and all(number(x) for x in (w0, w1, torque)):
            angular_errors.append(abs(w1 - w0 - torque / inertia))
        else:
            missing["delivered_angular_closure"] += 1
    complete = lambda values: len(values) == len(applications) and bool(applications)
    return {
        "unique_accepted_applications": len(applications),
        "deduplication": "session/physical-body/sample; held receipts are not independent events",
        "refused_observations": dict(refused), "accepted_sample_age_counts": dict(ages),
        "correction_coverage": len(corrections) / len(applications) if applications else None,
        "correction_active_applications": sum(_length(value) > 0 for value in corrections),
        "correction_translation_sum": [sum(value[axis] for value in corrections) for axis in range(2)] if complete(corrections) else None,
        "correction_potential_delta_sum": sum(potentials) if complete(potentials) else None,
        "zeroing_removed_energy_sum": sum(zeroing) if complete(zeroing) else None,
        "wrench_kinetic_delta_sum": sum(wrench_delta) if complete(wrench_delta) else None,
        "delivered_delta_v_error_max": max(linear_errors) if linear_errors else None,
        "delivered_delta_omega_error_max": max(angular_errors) if angular_errors else None,
        "missing_measurement_observations": dict(missing),
        "scope": "Separate measured application stages; no whole-system energy or causal correction claim",
    }


def historical_summary(folder):
    """Re-reduce fixed old controls; their source and population remain historical."""
    folder = Path(folder)
    names = ["gentle-drive", "salt-gentle", "original-barrel-m1-v90", "edge"]
    result = {"schema": "cybersand.gcr-creep.historical-reduction.v1", "source": "594a1a732f477aef6a7aec783251e7a784315722",
              "scope": "Re-reduction of retained GCR-REST controls; not new execution or correction ablation", "captures": []}
    for platform in ("windows", "linux"):
        for name in names:
            path = folder / (platform + "-" + name + "-control-b20.json")
            raw = read(path)
            require(raw.get("ok") is True and raw.get("errors") == [], "Failed historical capture: " + path.name)
            require(raw["identity"]["source"] == result["source"], "Wrong historical source")
            require(raw["case"]["kind"] == "barrel" and raw["case"]["mode"] == "control" and raw["case"]["budget"] == 20, "Wrong historical control")
            rows = raw["rows"]
            require(len(rows) == 1800 and [row["tick"] for row in rows] == list(range(1800)), "Incomplete historical ticks")
            normalized = []
            for row in rows:
                out = row["out"]
                normalized.append(dict(row, position=out[:2], rotation=out[2], velocity=out[3:5], omega=out[5]))
            windows = []
            for first, end in ((300, 600), (660, 900), (906, 1200), (1500, 1800)):
                selected = normalized[first:end]
                windows.append({"ticks_inclusive": [first, end - 1], "motion": motion(selected),
                                "post_overlap_max": max(row["post_overlap"] for row in selected),
                                "commanded_impulse_sum": [sum(row["authored_drive_impulse"][axis] for row in selected) for axis in range(2)],
                                "hard_floor_contact_observations": sum(row["hard_floor_contact"] for row in selected),
                                "material_conserved": all(row["conserved"] for row in selected),
                                "applications": application_summary(selected)})
            traces = []
            for tick in (700, 701, 702, 1500, 1501, 1502):
                row = rows[tick]
                traces.append({key: row[key] for key in ("tick", "in", "out", "authored_drive_impulse", "pre_overlap", "post_overlap", "application")})
            result["captures"].append({"file": path.name, "sha256": sha(path), "identity": raw["identity"],
                                       "case": raw["case"], "windows": windows, "selected_traces": traces})
    result["limitations"] = ["Repeated corrections are correlated observations, not isolated treatment effects",
                              "Earlier R changed both correction translation and velocity zeroing",
                              "Stage energy changes exclude gravity, hard contact, cellular work and external controls outside the measured boundary"]
    return result


def _hex(value, size):
    return isinstance(value, str) and len(value) == size and all(c in "0123456789abcdef" for c in value)


def validate_capture(raw, spec, identity, protocol_hash, platform):
    """Validate completeness and external identity before calculating metrics."""
    _all_finite(raw)
    require(isinstance(raw, dict) and raw.get("schema") == 1, "Unsupported capture schema")
    require(raw.get("ok") is True and raw.get("errors") == [], "Capture failed or errors were not retained as an empty list")
    require(raw.get("case") == spec, "Executed case differs from committed protocol")
    require(raw.get("platform") in (["Windows"] if platform == "windows" else ["Linux"]), "Wrong target platform")
    actual = raw.get("identity", {})
    require(isinstance(actual, dict), "Missing capture identity")
    require(_hex(identity.get("source"), 40), "Malformed external source identity")
    require(actual.get("source") == identity["source"], "Capture source mismatch")
    require(actual.get("protocol_sha256") == protocol_hash, "Capture protocol mismatch")
    require(_hex(identity.get("source_inputs_sha256"), 64)
            and actual.get("input_identity") == identity["source_inputs_sha256"], "Application input identity mismatch")
    expected = identity.get("platforms", {}).get(platform, {})
    require(isinstance(expected, dict) and bool(expected), "Missing authenticated platform identity")
    for key in ("native_sha256", "engine_sha256"):
        target = expected.get(key)
        if key == "native_sha256" and target is None:
            target = expected.get("native", {}).get("sha256")
        require(_hex(target, 64) and actual.get(key) == target, "Capture runtime identity mismatch: " + key)
    require(actual.get("physics_backend") == "Rapier2D", "Capture is not the qualified Rapier backend")
    require("4.7" in str(actual.get("engine_version", "")), "Unexpected Godot engine version")
    require(number(raw.get("dt")) and abs(raw["dt"] - 1 / 60) <= 1e-15, "Unexpected physical timestep")
    for key in ("actual_mass", "actual_inertia"):
        require(number(raw.get(key)) and raw[key] > 0, "Missing/nonpositive actual body property " + key)
    rows = raw.get("rows")
    require(integer(spec.get("ticks")) and spec["ticks"] > 0, "Protocol needs a positive tick count")
    require(isinstance(rows, list) and len(rows) == spec["ticks"], "Incomplete capture row population")
    previous_snapshot = -1
    delivered = set()
    for tick, row in enumerate(rows):
        require(isinstance(row, dict) and integer(row.get("tick")) and row["tick"] == tick, "Missing, repeated or out-of-order physical tick")
        for field in ("position", "velocity"):
            require(vector(row.get(field)), "Missing/nonfinite body " + field)
        for field in ("rotation", "omega"):
            require(number(row.get(field)), "Missing/nonfinite body " + field)
        require(type(row.get("command_active")) is bool, "Missing explicit pilot command state")
        require(isinstance(row.get("drive_phase"), str) and bool(row["drive_phase"]), "Missing drive phase")
        controller = row.get("controller")
        require(isinstance(controller, dict), "Missing controller observation")
        for field in ("applied_force", "actual_impulse"):
            require(vector(controller.get(field)), "Missing/malformed primary actuation " + field)
        for field in ("applied_torque", "actual_torque_impulse"):
            require(number(controller.get(field)), "Missing/malformed primary actuation " + field)
        require(isinstance(row.get("input_action"), dict), "Missing recorded input action")
        require(isinstance(row.get("gcr"), dict), "Missing GCR diagnostics object")
        application, marker = row.get("application"), row.get("application_step")
        require(isinstance(application, dict) and isinstance(marker, dict), "Missing application/current-step marker")
        snapshot = application.get("snapshot", -1)
        require(integer(snapshot), "Nonintegral application snapshot")
        require(marker.get("version") == 1 and marker.get("physics_call") == tick
                and marker.get("snapshot_before") == previous_snapshot and marker.get("snapshot_after") == snapshot,
                "Application marker does not bind this physics call")
        fresh = snapshot > previous_snapshot and application.get("accepted") is True
        require(type(marker.get("delivered_this_step")) is bool and marker["delivered_this_step"] == fresh,
                "Application fresh-delivery marker is inconsistent")
        previous_snapshot = snapshot
        if fresh:
            bodies = application.get("bodies")
            require(isinstance(bodies, list) and len(bodies) == 1 and isinstance(bodies[0], dict), "Missing single-body application")
            body = bodies[0]
            require(all(integer(body.get(key)) for key in ("session", "index", "sample", "age")), "Malformed applied identity")
            key = (body["session"], body["index"], body["sample"])
            require(key not in delivered, "A physical sample was applied more than once")
            delivered.add(key)
        for field in ("pre_overlap", "post_overlap", "material_count", "water"):
            require(row.get(field) is None or (integer(row[field]) and row[field] >= 0), "Malformed optional integer " + field)
        for field in ("conserved", "hard_floor_contact", "hard_clearance"):
            require(row.get(field) is None or type(row[field]) is bool, "Malformed optional boolean " + field)
    return rows


def conservation(raw):
    """Compare stored native censuses; Water occupancy is not Water quantity."""
    first, last = raw.get("before"), raw.get("after")
    require(isinstance(first, dict) and isinstance(last, dict), "Missing boundary material census")
    observations = [("before", first)]
    observations.extend(("tick:" + str(row["tick"]), row["census"]) for row in raw["rows"] if "census" in row)
    observations.append(("after", last))
    expected_counts, expected_water = None, None
    for label, observed in observations:
        require(isinstance(observed, dict), "Malformed census " + label)
        counts, water = observed.get("counts"), observed.get("water_mass")
        require(isinstance(counts, list) and 4 <= len(counts) <= 256
                and all(integer(value) and value >= 0 for value in counts), "Malformed census counts " + label)
        require(integer(water) and water >= 0, "Malformed exact Water quantity " + label)
        require(observed.get("failed") is False, "Census from failed World " + label)
        if expected_counts is None:
            expected_counts, expected_water = counts, water
        require(len(counts) == len(expected_counts) and sum(counts) == sum(expected_counts), "Census domain/population changed " + label)
        require(all(counts[index] == expected_counts[index] for index in range(len(counts)) if index not in (0, 3)), "Unexplained stored material change " + label)
        require(water == expected_water, "Unexplained Water quantity change " + label)
    sampled = [row for row in raw["rows"] if row.get("conserved") is not None]
    require(bool(sampled) and all(row["conserved"] is True for row in sampled), "Missing or failed sampled conservation")
    if raw["case"]["kind"] == "flyer":
        expected_ticks = list(range(0, int(raw["case"]["ticks"]), 60))
        expected_ticks.append(int(raw["case"]["ticks"]) - 1)
        require([row["tick"] for row in sampled] == expected_ticks, "Incomplete flyer census schedule")
        require(all("census" in row for row in sampled), "Reported flyer conservation lacks raw census")
    else:
        require(len(sampled) == len(raw["rows"]), "Incomplete barrel per-step conservation")
    return {"exact": True, "boundary_and_raw_censuses": len(observations), "sampled_checks": len(sampled),
            "population_cells": sum(expected_counts), "stored_counts": expected_counts, "water_mass": expected_water,
            "scope": "Declared closed diagnostic domain; excludes Empty/Water cell count from substance comparison and compares exact stored Water quantity"}


def summarize_rows(rows, dt):
    require(number(dt) and dt > 0, "Invalid physical step")
    forces = [row["controller"].get("applied_force") for row in rows]
    torques = [row["controller"].get("applied_torque") for row in rows]
    measured = [(force, torque) for force, torque in zip(forces, torques) if vector(force) and number(torque)]
    no_command = [row for row in rows if not row["command_active"]]
    unactuated = [row for row in no_command
                  if vector(row["controller"].get("applied_force")) and number(row["controller"].get("applied_torque"))
                  and row["controller"]["applied_force"] == [0, 0] and row["controller"]["applied_torque"] == 0]
    overlaps = [row["post_overlap"] for row in rows if row.get("post_overlap") is not None]
    censused = [row["conserved"] for row in rows if row.get("conserved") is not None]
    hard = [row["hard_floor_contact"] for row in rows if row.get("hard_floor_contact") is not None]
    clear = [row["hard_clearance"] for row in rows if row.get("hard_clearance") is not None]
    limiters = Counter(str(row.get("gcr", {}).get("active_capacity_limiter", "unmeasured")) for row in rows)
    return {
        "motion": motion(rows),
        "command_active_observations": sum(row["command_active"] for row in rows),
        "no_command_observations": len(no_command),
        "exact_zero_actuation_no_command_observations": len(unactuated),
        "controller_measurement_coverage": len(measured) / len(rows) if rows else None,
        "controller_linear_impulse_sum": [sum(force[axis] * dt for force, _ in measured) for axis in range(2)] if len(measured) == len(rows) and rows else None,
        "controller_absolute_linear_impulse_sum": sum(_length(force) * dt for force, _ in measured) if len(measured) == len(rows) and rows else None,
        "controller_angular_impulse_sum": sum(torque * dt for _, torque in measured) if len(measured) == len(rows) and rows else None,
        "force_magnitude_max": max((_length(force) for force, _ in measured), default=None),
        "post_overlap_coverage": len(overlaps) / len(rows) if rows else None,
        "post_overlap_max": max(overlaps) if overlaps else None,
        "sampled_conservation_checks": len(censused),
        "sampled_conservation_all_pass": all(censused) if censused else None,
        "hard_floor_contact_observations": sum(hard),
        "hard_floor_contact_coverage": len(hard) / len(rows) if rows else None,
        "hard_clearance_observations": sum(clear),
        "hard_clearance_coverage": len(clear) / len(rows) if rows else None,
        "limiter_observations": dict(limiters),
        "applications": application_summary(rows),
        "interpretation": "No pilot command is distinct from zero actuator force; drag/assist/hover can remain active. Motion and correction correlation alone do not establish causation.",
    }


def reduce_capture(raw, spec, identity, protocol_hash, platform, protocol=None):
    rows = validate_capture(raw, spec, identity, protocol_hash, platform)
    dt = raw["dt"]
    balanced = conservation(raw)
    if protocol is not None:
        for row in rows:
            end = protocol["pulse_end"] if spec["drive"] == "pulse" else protocol["drive_end"]
            active = spec["drive"] in ("pulse", "sustained") and protocol["pulse_start"] <= row["tick"] < end
            require(row["command_active"] == active, "Executed command interval differs from registered schedule")
        expected_mass = protocol["fixture_barrel"]["mass"] if spec["kind"] == "barrel" else protocol["fixture_flyer"]["mass"]
        require(abs(raw["actual_mass"] - expected_mass) <= 1e-6 * max(1, expected_mass), "Actual body mass differs from registered authoring")
        if spec["kind"] == "flyer":
            expected_inertia = protocol["fixture_flyer"]["inertia"]
            require(abs(raw["actual_inertia"] - expected_inertia) <= 1e-6 * max(1, expected_inertia), "Actual flyer inertia differs from registered authoring")
        receipts = [row.get("rest_receipt") for row in rows]
        require(all(isinstance(receipt, dict) and receipt.get("mode") == "control" and receipt.get("base_budget") == 20 for receipt in receipts), "Unchanged native LA control configuration not proved for every row")
    phases = {}
    for phase in dict.fromkeys(row["drive_phase"] for row in rows):
        selected = [row for row in rows if row["drive_phase"] == phase]
        # A phase must be contiguous: jumping between intervals conceals motion.
        require(selected[-1]["tick"] - selected[0]["tick"] + 1 == len(selected), "Noncontiguous drive phase")
        phases[phase] = summarize_rows(selected, dt)
    tail = rows[-min(300, len(rows)):]
    windows = {}
    if protocol is not None:
        for name, (first, end) in protocol["windows"].items():
            require(integer(first) and integer(end) and 0 <= first < end <= len(rows), "Registered window outside capture")
            windows[name] = summarize_rows(rows[first:end], dt)
    return {"case": spec["id"], "platform": platform, "status": "complete_observation",
            "full_window": summarize_rows(rows, dt), "tail": summarize_rows(tail, dt), "phases": phases,
            "registered_windows": windows, "conservation": balanced,
            "body": {"actual_mass": raw["actual_mass"], "actual_inertia": raw["actual_inertia"], "gravity": raw.get("gravity")},
            "scope": "Registered independent-body observational comparison; no new response law or owner acceptance"}


def reduce_campaign(folder, protocol_path, platforms=None):
    folder = Path(folder)
    protocol = read(protocol_path)
    require(protocol.get("registration") == "GCR-CREEP-001-2026-11-03", "Wrong registered experiment")
    require(isinstance(protocol.get("cases"), list) and len(protocol["cases"]) == 16, "Wrong registered population")
    ids = [case.get("id") for case in protocol["cases"]]
    require(len(set(ids)) == len(ids) and all(isinstance(value, str) for value in ids), "Duplicate/malformed case IDs")
    identity = read(folder / "identity.json")
    protocol_hash = sha(protocol_path)
    require(identity.get("protocol_sha256") == protocol_hash, "Campaign protocol identity mismatch")
    platforms = protocol["platforms"] if platforms is None else platforms
    require(bool(platforms) and all(platform in protocol["platforms"] for platform in platforms), "Unregistered platform")
    results = []
    failures = []
    for platform in platforms:
        for spec in protocol["cases"]:
            path = folder / platform / (spec["id"] + ".json")
            try:
                raw = read(path)
                result = reduce_capture(raw, spec, identity, protocol_hash, platform, protocol)
                result.update(file=path.relative_to(folder).as_posix(), sha256=sha(path))
                results.append(result)
            except (EvidenceError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
                failures.append({"platform": platform, "case": spec["id"], "reason": str(error),
                                 "file": path.relative_to(folder).as_posix(), "sha256": sha(path) if path.is_file() else None})
    return {"schema": "cybersand.gcr-creep.reduction.v1", "source": identity["source"],
            "protocol_sha256": protocol_hash, "identity_sha256": sha(folder / "identity.json"),
            "platforms": platforms, "planned_captures": len(platforms) * len(protocol["cases"]),
            "complete_captures": len(results), "ok": not failures, "failures": failures, "captures": results,
            "interpretation": "Observation-only; phase and paired drive differences do not isolate correction, zeroing or friction causality"}


def _write(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8", newline="\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--historical-folder", type=Path)
    parser.add_argument("--historical-output", type=Path)
    parser.add_argument("--folder", type=Path)
    parser.add_argument("--protocol", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--platform", choices=("both", "windows", "linux"), default="both")
    args = parser.parse_args()
    if args.historical_folder or args.historical_output:
        if not args.historical_folder or not args.historical_output or args.folder:
            parser.error("Historical mode needs --historical-folder and --historical-output only")
        _write(args.historical_output, historical_summary(args.historical_folder))
        return 0
    if not args.folder or not args.protocol or not args.output:
        parser.error("Campaign mode needs --folder, --protocol and --output")
    platforms = ["windows", "linux"] if args.platform == "both" else [args.platform]
    result = reduce_campaign(args.folder, args.protocol, platforms)
    _write(args.output, result)
    print(json.dumps({"ok": result["ok"], "complete_captures": result["complete_captures"], "planned_captures": result["planned_captures"], "failures": result["failures"]}))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
