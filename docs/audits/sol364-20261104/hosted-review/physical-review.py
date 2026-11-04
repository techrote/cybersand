#!/usr/bin/env python3
"""Read complete hosted SOL364 replay evidence without changing source or inputs."""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import statistics
import struct
import sys

SOURCE = {"sha": "9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d",
          "tree": "b5baf8b23ff947c2d7b70e69745c10f18fbe9ebe"}
RUN = 41815817333
FIXTURES = ["embedded_stationary", "packed_impact", "offcenter_impact", "rotated_compound",
            "missed_publication", "delayed_publication", "stale_publication"]
ARMS = ["conservative_baseline", "velocity_control", "candidate"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def near(a, b):
    assert math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-7), (a, b)


def vector_length_squared(values):
    # Godot Vector2 uses float32 arithmetic even though GDScript scalar
    # energy/mass/inertia arithmetic is double. Reproduce that operation rather
    # than treating the printed vector components as a double-precision dot.
    f32 = lambda x: struct.unpack("f", struct.pack("f", x))[0]
    return f32(f32(values[0] * values[0]) + f32(values[1] * values[1]))


def canonical_hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def extent(values):
    return {"min": min(values), "max": max(values), "mean": statistics.mean(values),
            "sample_standard_deviation": statistics.stdev(values) if len(values) > 1 else 0,
            "count": len(values)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, required=True)
    ap.add_argument("--repository", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    sys.path.insert(0, str(args.repository / "tools/sol281"))
    import run_qualification as qualification
    reports, comparisons, support_proofs = [], {}, []
    trajectories, trajectory_states, geometry_points = {}, {}, {}
    portable_base = "docs/audits/sol281-20261103/hosted/" + SOURCE["sha"]
    for platform in ("linux", "windows"):
        host = args.root / "cohorts" / platform / "mechanism"
        if platform == "linux":
            host /= "host"
        host_report_path = host / "report.json"
        host_report = load(host_report_path)
        assert host_report["source"] == SOURCE and host_report["status"] == "passed" and not host_report["errors"]
        assert host_report["source_unchanged"] and host_report["checkout_inputs_unchanged"]
        inputs = load(host / "inputs-before.json")
        assert inputs == load(host / "inputs-after.json")
        checkout = load(host / "checkout-inputs-before.json")
        assert checkout == load(host / "checkout-inputs-after.json")
        build_path = args.root / ("build-" + platform) / "build.json"
        build = load(build_path)
        assert build["source"] == SOURCE and build["inputs"] == inputs
        assert sha(build_path) == host_report["build_manifest_sha256"]
        assert build["runtime"] == host_report["runtime"]
        runtime_path = build_path.parent / build["runtime"]["filename"]
        assert sha(runtime_path) == build["runtime"]["sha256"]
        for workers in (1, 4):
            name = f"synchronized-contact-w{workers}"
            record = next(x for x in host_report["records"] if x["name"] == name)
            assert record["status"] == "passed" and record["returncode"] == 0 and record["natural_completion"]
            log_path, path = host / record["log"], host / (name + ".json")
            assert sha(log_path) == record["log_sha256"] and sha(path) == record["result"]["sha256"]
            spec = next(x for x in qualification.inventory("mechanism") if x.name == name)
            footer = qualification.verify_footer(spec, log_path.read_text(encoding="utf-8"), platform.title())
            assert footer == record["readback"]
            assert qualification.verify_result_file(spec, host, footer) == record["result"]
            data = load(path)
            assert data["input_hashes"] == data["input_hashes_at_finish"]
            assert all(inputs["godot/" + key] == value == checkout["godot/" + key]
                       for key, value in data["input_hashes"].items())
            assert data["can_sleep"] is False and data["checks"] == 8338 and not data["failures"]
            assert data["workers"] == workers and data["platform"] == platform.title()
            assert [c["id"] for c in data["cases"]] == [f + "/" + a for f in FIXTURES for a in ARMS]
            case_rows = []
            for case in data["cases"]:
                trace, stats = case["trace"], case["stats"]
                assert len(trace) == 180 and [r["step"] for r in trace] == list(range(1, 181))
                assert stats["owner_attempts"] == stats["complete_measurements"] == 181
                assert case["native_ticks_before"] == case["native_ticks_after"] == 1
                assert case["native_state_hash_after"] == case["native_field"]
                assert case["payload_preserved"] and case["aggregate_owned"] == 520 and case["native_source_members"] == 0
                observations = [case["initial"]["measurement"]] + [r["measurement"] for r in trace]
                assert sum(r["measurement"]["overlap_cells"] for r in trace) == stats["overlap_cell_ticks"]
                near(sum(r["measurement"]["sand_overlap_area"] for r in trace), stats["sand_area_cell_ticks"])
                near(max(m["max_sand_penetration"] for m in observations), stats["max_sand_penetration"])
                previous = case["initial"]["state"]
                refusals, paired_outcomes = Counter(), Counter()
                pair_only_current_accepts = pair_only_current_nonzero = 0
                for row in trace:
                    assert row["before"] == previous
                    previous = row["after"]
                    for state_key in ("before", "after_response", "after"):
                        state = row[state_key]
                        assert state["sleeping"] is False and state["position_work"] == 0 and state["potential"] == 0
                        near(state["kinetic"], 0.5 * state["mass"] * vector_length_squared(state["velocity"])
                             + 0.5 * state["inertia"] * state["omega"]**2)
                    near(row["response_energy_change"], row["after_response"]["kinetic"] - row["before"]["kinetic"])
                    near(row["rapier_energy_change"], row["after"]["kinetic"] - row["after_response"]["kinetic"])
                    assert row["response_energy_change"] <= 1e-4 * max(1, row["before"]["kinetic"])
                    assert abs(row["rapier_energy_change"]) <= 1e-4 * max(1, row["after_response"]["kinetic"])
                    m = row["measurement"]
                    geometry = data["geometries"][m["geometry_id"]]
                    assert geometry["sha256"] == m["geometry_sha256"]
                    assert len(geometry["proxies"]) == 6 and len(geometry["hole_witnesses"]) == 2
                    if case["arm"] != "conservative_baseline" and row["receipt"]["delivered"] and not row["response"].get("accepted"):
                        refusals[row["response"]["outcome"]] += 1
                    pair = row["matched"]
                    if pair:
                        old, new = pair["velocity_control"], pair["candidate"]
                        paired_outcomes[(old["outcome"], new["outcome"])] += 1
                        if new.get("accepted") and not old.get("accepted"):
                            pair_only_current_accepts += 1
                            pair_only_current_nonzero += bool(new.get("impulses"))
                assert dict(refusals) == stats["response_refusals"]
                assert stats["sleep_steps"] == stats["energy_violations"] == stats["response_failures"] == 0
                assert stats["nonfinite_states"] == stats["rapier_step_energy_violations"] == 0
                assert stats["positive_steps"] == stats["longest_positive_run"] == 180
                gates = case["physical_gates"]
                assert gates["physical_accepted"] is False and gates["sustained_clearance_pass"] is False
                assert gates["recurrence_evaluable"] is False and gates["recurrence_detected"] is None
                row = {"id": case["id"], "initial": case["initial"]["state"], "final": trace[-1]["after"],
                       "stats": stats, "physical_gates": gates,
                       "final_sand_depth": trace[-1]["measurement"]["max_sand_penetration"],
                       "final_sand_area": trace[-1]["measurement"]["sand_overlap_area"],
                       "matched_planner_outcomes": [{"old": k[0], "current": k[1], "steps": v} for k,v in sorted(paired_outcomes.items())],
                       "matched_current_only_accepts": pair_only_current_accepts,
                       "matched_current_only_accepts_with_impulses": pair_only_current_nonzero}
                case_rows.append(row)
                comparisons.setdefault(case["id"], []).append({"platform": platform, "workers": workers, **row})
                states = [case["initial"]["state"]] + [r["after"] for r in trace]
                trajectory_states.setdefault(case["id"], []).append(states)
                geometry_points.setdefault(case["id"], []).append([
                    data["geometries"][m["geometry_id"]]["proxies"] for m in observations])
                trajectories.setdefault(case["id"], []).append({"platform": platform, "workers": workers,
                    "state_trace_sha256": canonical_hash(states),
                    "float32_rid_state_trace_sha256": hashlib.sha256(b"".join(struct.pack("<9f",
                        *(s["pose"] + s["velocity"] + [s["omega"]])) for s in states)).hexdigest(),
                    "geometry_trace_sha256": canonical_hash([m["geometry_sha256"] for m in observations])})
            for fixture in FIXTURES:
                arms = [c for c in data["cases"] if c["fixture"] == fixture]
                assert all(c["initial"]["state"] == arms[0]["initial"]["state"] and c["native_field"] == arms[0]["native_field"] for c in arms)
            packed = next(c for c in data["cases"] if c["id"] == "packed_impact/candidate")
            field = data["native_fields"][packed["native_field"]]
            cells = [material for material, count in field["material_runs"] for _ in range(count)]
            footprints = []
            for y in range(58, 65):
                footprint = [[cells[(y + dy)*128 + x] for x in range(53, 56)] for dy in range(3)]
                assert footprint == [[0, 2, 2]] * 3
                footprints.append({"cell": [54, y], "materials": footprint, "maximum_possible_stable_count": 6})
            first_contact = next(r["step"] for r in packed["trace"] if r["measurement"]["contact_count"] > 0)
            first_impulse = next(r["step"] for r in packed["trace"] if r["response"].get("impulses"))
            support_proofs.append({"platform": platform, "workers": workers, "native_field": packed["native_field"],
                "footprints": footprints, "unchanged_required_support_cells": 8,
                "first_positive_overlap_step": next(r["step"] for r in packed["trace"] if r["measurement"]["sand_overlap_area"] > 1e-6),
                "first_published_contact_geometry_step": first_contact, "first_applied_impulse_step": first_impulse,
                "pre_witness_positive_steps": [r["step"] for r in packed["trace"] if r["step"] < first_contact and r["measurement"]["sand_overlap_area"] > 1e-6],
                "explanation": "Each first-column Sand support footprint contains three Empty and six Sand cells. Its stable-count upper bound is6 even if all Sand is eligible; the unchanged threshold is8. Positive area before an eligible contact is therefore not attributable to publication delay or midpoint transport. No epoch eligibility assumption is needed for this upper-bound proof."})
            relative = path.relative_to(args.root).as_posix()
            reports.append({"platform": platform, "workers": workers, "local_path": str(path),
                "artifact_name": f"sol281-host-{platform}-mechanism-{RUN}-1",
                "artifact_member": path.relative_to(args.root / "cohorts" / platform / "mechanism").as_posix(),
                "repository_publication_target": portable_base + "/" + relative,
                "report_sha256": sha(path), "host_report_sha256": sha(host_report_path),
                "input_manifest_sha256": sha(host / "inputs-before.json"),
                "build_manifest_sha256": sha(build_path), "source": SOURCE,
                "runtime": host_report["runtime"], "rapier": host_report["rapier"], "engine": host_report["engine"],
                "compiler": build["compiler"].splitlines()[0], "bindings": build["bindings"],
                "checked_input_count": len(inputs), "input_hashes": data["input_hashes"],
                "checks": data["checks"], "scope": data["scope"], "sleep_control_note": data["sleep_control_note"],
                "controls": data["controls"], "cases": case_rows,
                "physical_accepted_cases": 0, "sustained_clearance_failures": 21,
                "depth_gate_failures": sum(not c["physical_gates"]["depth_pass"] for c in data["cases"])})
    cross = []
    for name, items in comparisons.items():
        metrics = {key: extent([x["stats"][key] for x in items]) for key in (
            "max_sand_penetration", "sand_area_cell_ticks", "overlap_cell_ticks", "max_speed", "max_abs_omega",
            "max_rotation_change", "max_translation", "impulse_magnitude_sum", "torque_impulse_sum", "response_energy_change_sum")}
        metrics.update(final_sand_depth=extent([x["final_sand_depth"] for x in items]),
                       final_sand_area=extent([x["final_sand_area"] for x in items]))
        signatures = trajectories[name]
        states = trajectory_states[name]
        pairs = [(a, b) for other in states[1:] for a, b in zip(states[0], other)]
        differences = {"reported_position_distance": max(math.dist(a["pose"][4:], b["pose"][4:]) for a,b in pairs),
            "basis_component": max(abs(x-y) for a,b in pairs for x,y in zip(a["pose"][:4], b["pose"][:4])),
            "velocity_distance": max(math.dist(a["velocity"], b["velocity"]) for a,b in pairs),
            "omega": max(abs(a["omega"]-b["omega"]) for a,b in pairs),
            "kinetic_energy": max(abs(a["kinetic"]-b["kinetic"]) for a,b in pairs)}
        points = geometry_points[name]
        differences["reported_proxy_corner_distance"] = max(math.dist(x,y)
            for other in points[1:] for a,b in zip(points[0],other)
            for sa,sb in zip(a,b) for x,y in zip(sa,sb))
        float32_identical = len({x["float32_rid_state_trace_sha256"] for x in signatures}) == 1
        cross.append({"id": name, "metrics": metrics, "state_and_geometry_signatures": signatures,
            "state_traces_identical_across_all_four": len({x["state_trace_sha256"] for x in signatures}) == 1,
            "geometry_traces_identical_across_all_four": len({x["geometry_trace_sha256"] for x in signatures}) == 1,
            "float32_rid_state_traces_identical_across_all_four": float32_identical,
            "maximum_cross_host_numeric_differences": differences,
            "worker_counts_match_within_each_os": all(signatures[i]["state_trace_sha256"] == signatures[i+1]["state_trace_sha256"]
                and signatures[i]["geometry_trace_sha256"] == signatures[i+1]["geometry_trace_sha256"] for i in (0,2))})
    result = {"schema": "cybersand.sol364.hosted-physical-review.v1", "status": "execution-verified-physical-no-go",
        "reviewer_role": "Synchronized apparatus author reviewing published physical evidence; separate independent production/geometry/concurrency reviews are retained elsewhere.",
        "run_id": RUN, "run_url": f"https://github.com/techrote/cybersand/actions/runs/{RUN}", "source": SOURCE,
        "review_script_sha256": sha(Path(__file__)), "reports": reports, "cross_host_comparisons": cross,
        "energy_recomputation_note": "Vector2.length_squared uses float32 dot arithmetic, reproduced explicitly; scalar mass/inertia/omega arithmetic is double. The first review calculation incorrectly used a double dot (1879.730744169781 versus measured1879.73075256891). Correct float32 evaluation matches within7e-12 in the first Linux report. No response-energy or physical threshold changed.",
        "support_eligibility_proof": support_proofs,
        "statistics_scope": "Four platform/worker configurations, one complete deterministic run per configuration. Cross-configuration range/standard deviation is descriptive and is not a repeated-trial uncertainty estimate. Timings and publication wall-clock stamps are excluded from trajectory equality.",
        "cross_host_precision_scope": "Raw JSON decimal equality and restored float32 RID state identity are reported separately. For example, Linux serializes the stationary y coordinate as41.5955200195312 and Windows as41.5955200195313; both round back to the same actual float32 value. Small platform differences in four state trajectories remain after float32 restoration and are not erased by rounding the physical acceptance gates.",
        "total_after_step_observations": 4 * 21 * 180, "total_complete_geometry_observations_including_initial": 4 * 21 * 181,
        "total_assertions": sum(r["checks"] for r in reports), "physical_accepted_cases": 0,
        "sustained_clearance_failures": sum(r["sustained_clearance_failures"] for r in reports),
        "depth_gate_failures": sum(r["depth_gate_failures"] for r in reports),
        "limitations": ["Frozen native fields after one initialization tick; native material integration and ordinary displacement are held identically in every arm. Real Rapier manual integration is zero-gravity/zero-damping with sleeping disabled uniformly.",
            "Worker counts configure the real native initialization, but synchronized publications are a deterministic test queue, not asynchronous worker scheduling or the registered CPU cohort.",
            "The retained historical embedded pose is reused with deliberately zero velocity over an authored frozen native field; unrecorded historical native cells are not reconstructed.",
            "All cases remain overlapped on all180 observed after-step measurements. Sustained clearance never begins, so recurrence is not evaluable; no recurrence pass may be inferred.",
            "Finite motion and dissipative response guards do not establish plausible physical acceptance. All registered failures are retained."]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"output": str(args.output), "sha256": sha(args.output), "reports": len(reports),
        "assertions": result["total_assertions"], "clearance_failures": result["sustained_clearance_failures"],
        "depth_failures": result["depth_gate_failures"],
        "identical_state_traces": sum(x["state_traces_identical_across_all_four"] for x in cross),
        "identical_float32_rid_state_traces": sum(x["float32_rid_state_traces_identical_across_all_four"] for x in cross),
        "identical_geometry_traces": sum(x["geometry_traces_identical_across_all_four"] for x in cross)}))


if __name__ == "__main__":
    main()
