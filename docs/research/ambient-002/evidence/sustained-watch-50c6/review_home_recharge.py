"""Read the source-bound, ordinary Workbench Foundry home-rest confirmation.

This is an external evidence reader. It does not run CyberSand or count a new
episode. Approximately one-Hz snapshots establish sampled phase/geometry/drive
relations, not an unobserved continuous trajectory or exact selected duration.

Usage: python review_home_recharge.py BASELINE_REPORT CURRENT_REPORT SCENE OUTPUT
"""
from collections import Counter
from pathlib import Path
import hashlib
import json
import math
import sys


BASELINE = "a7250e15495667b2fcf564cbed1eaa8dea217c45"
CURRENT = "50c6df89528dc9ecdc5316d8c67abf203e192254"
OBSERVER = "52900f9d8ead1f6d0b3c4ae6fbdc1e0ac049ce4b"
SCENE_BLOB = "f58e156157b703ef1222673405374745bf73e098"
WATCHER_SHA = "aac731d1d44fcc46beca22ea6b0ee84e1acfe4c09ad51cc47bd52abb8c922379"
GODOT_SHA = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def git_blob(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def checked_read(path):
    raw = Path(path).read_bytes()
    return json.loads(raw), digest(raw)


def scene_contract(path):
    raw = Path(path).read_bytes()
    assert git_blob(raw) == SCENE_BLOB, "authored scene differs from both frozen applications"
    scene = json.loads(raw)
    actor = next(actor for actor in scene["actors"] if actor["id"] == 7)
    profile = actor["control"]["ambient"]
    homes = [r for r in profile["regions"] if r["kind"] == "home"]
    assert len(homes) == 1
    region = homes[0]
    center = [region["x"] + region["width"] / 2, region["y"] + region["height"] / 2]
    modules = [m for m in profile["modules"] if m["type"] == "seek_home_drive" and m["enabled"] and m["weight"] > 0]
    assert len(modules) == 1
    module = modules[0]
    assert actor["model"] == "4ly_trainer" and profile["drives_enabled"]
    assert center == [365.0, 355.0] and module["params"]["arrival_radius"] == 20
    return {
        "scene_sha256": digest(raw), "scene_git_blob": git_blob(raw),
        "actor_instance_id": 7, "model": actor["model"], "spawn": actor["spawn"],
        "profile_id": profile["id"], "profile_seed": profile["seed"],
        "home_center": center, "home_module_instance": module["id"],
        "arrival_radius": float(module["params"]["arrival_radius"]),
        "rest_seconds": float(module["params"]["rest_seconds"]),
        "ordinary_neutral_recharge_radius": 16.0, "recharge_rate_per_second": 0.09,
    }


def physical_start(report):
    # Random run IDs and runtime counters are identity fences, not initial poses.
    return [{"instance_id": a["instance_id"], "actor_id": a["actor_id"],
             "model": a["model"], "profile_id": a["profile_id"],
             "observation": a["observation"]}
            for a in sorted(report["samples"][0]["actors"], key=lambda a: a["instance_id"])]


def phase_identity(row):
    return row["override"], row["selected_goal"], row["phase"], str(row["goal_key"])


def analyze(report, source, contract):
    assert report["source_revision"] == source
    assert report["status"] == "passed" and not report["failures"]
    assert report["scene"] == "ambient2-settlement" and report["follow_actor"] == 7
    assert report["observer_script_sha256"] == WATCHER_SHA and report["engine_sha256"] == GODOT_SHA
    assert len(report["samples"]) == 61
    assert [s["requested_simulation_second"] for s in report["samples"]] == list(range(61))
    assert report["actual_simulation_seconds"] >= 60 and report["physical_ticks"] >= 3600
    assert report["native_ticks"] == report["physical_ticks"]
    rows = []
    for sample in report["samples"]:
        selected = [a for a in sample["actors"] if a["instance_id"] == 7]
        assert len(selected) == 1
        a = selected[0]
        assert a["model"] == contract["model"] and a["profile_id"] == contract["profile_id"]
        assert not a["error"] and a["rejected"] == 0
        assert math.isfinite(a["simulation_time_seconds"])
        i, o, d = a["intent"], a["observation"], a["drives"]
        assert len(o["position"]) == 2 and all(math.isfinite(x) for x in o["position"])
        if d:
            assert all(math.isfinite(d[k]) and 0 <= d[k] <= 1 for k in ("exploration", "social"))
        distance = math.dist(o["position"], contract["home_center"])
        row = {
            "requested_second": sample["requested_simulation_second"],
            "copied_simulation_seconds": sample["simulation_seconds_since_play"],
            "actor_simulation_seconds": a["simulation_time_seconds"],
            "actor_tick": a["tick"], "decisions": a["decisions"],
            "override": i.get("active_override", ""),
            "selected_goal": i.get("selected_goal", ""), "phase": i.get("goal_phase", ""),
            "goal_key": i.get("goal_key", ""), "phase_selected_seconds": i.get("phase_selected_seconds"),
            "pace": i.get("pace"), "target": i.get("goal_target"),
            "position": o["position"], "velocity": o["velocity"], "energy": o["energy"],
            "distance_to_authored_home": distance,
            "inside_authored_arrival_region": distance <= contract["arrival_radius"],
            "inside_separate_16_cell_metric": distance <= 16,
            "exploration_drive": d.get("exploration"), "social_drive": d.get("social"),
            "failure_events": a["memory"].get("failure_events"),
            "reason": i.get("reason", ""),
            # Retain the relevant resumption tail once; complete originals stay
            # in the authoring archive rather than duplicating it in every row.
            "recent_decisions_tail": a["recent_decisions_tail"] if sample["requested_simulation_second"] == 52 else [],
        }
        row["selected_home_rest"] = (row["selected_goal"] == contract["home_module_instance"]
                                      and row["phase"] == "home_rest" and not row["override"])
        rows.append(row)
    assert all(a["copied_simulation_seconds"] < b["copied_simulation_seconds"] for a, b in zip(rows, rows[1:]))
    assert all(a["actor_simulation_seconds"] < b["actor_simulation_seconds"] for a, b in zip(rows, rows[1:]))
    intervals = []
    for left, right in zip(rows, rows[1:]):
        if not (left["selected_home_rest"] and right["selected_home_rest"]):
            continue
        duration = right["actor_simulation_seconds"] - left["actor_simulation_seconds"]
        drive_change = right["exploration_drive"] - left["exploration_drive"]
        dwell_change = (right["phase_selected_seconds"] - left["phase_selected_seconds"]
                        if phase_identity(left) == phase_identity(right) else None)
        expected = min(1.0, left["exploration_drive"] + duration * 0.09) - left["exploration_drive"]
        intervals.append({
            "from_requested_second": left["requested_second"], "to_requested_second": right["requested_second"],
            "elapsed_copied_actor_seconds": duration,
            "same_sampled_goal_and_phase": phase_identity(left) == phase_identity(right),
            "selected_dwell_counter_change": dwell_change,
            "both_sampled_positions_inside_authored_region": left["inside_authored_arrival_region"] and right["inside_authored_arrival_region"],
            "both_sampled_positions_outside_separate_16_cell_metric": not left["inside_separate_16_cell_metric"] and not right["inside_separate_16_cell_metric"],
            "exploration_drive_change": drive_change,
            "expected_change_if_eligible_for_entire_interval": expected,
            "matches_full_interval_recharge_rate": math.isclose(drive_change, expected, abs_tol=1e-7),
            "sampled_euclidean_displacement": math.dist(left["position"], right["position"]),
            "sampled_horizontal_displacement": abs(right["position"][0] - left["position"][0]),
        })
    counts = Counter((r["override"], r["selected_goal"], r["phase"]) for r in rows[1:])
    return {
        "actual_simulation_seconds": report["actual_simulation_seconds"],
        "physical_ticks": report["physical_ticks"], "native_ticks": report["native_ticks"],
        "initial_copied_actor_states": physical_start(report),
        "phase_sample_counts": [{"override": k[0], "goal": k[1], "phase": k[2], "samples": v} for k, v in sorted(counts.items())],
        "home_rest_sample_seconds": [r["requested_second"] for r in rows if r["selected_home_rest"]],
        "consecutive_sampled_home_rest_intervals": intervals,
        "first_post_start_drives": {"exploration": rows[1]["exploration_drive"], "social": rows[1]["social_drive"]},
        "last_drives": {"exploration": rows[-1]["exploration_drive"], "social": rows[-1]["social_drive"]},
        "sampled_timeline": rows,
    }


def main():
    baseline_path, current_path, scene_path, output_path = map(Path, sys.argv[1:])
    contract = scene_contract(scene_path)
    baseline_report, baseline_hash = checked_read(baseline_path)
    current_report, current_hash = checked_read(current_path)
    baseline = analyze(baseline_report, BASELINE, contract)
    current = analyze(current_report, CURRENT, contract)
    pairs = current["consecutive_sampled_home_rest_intervals"]
    extension_pairs = [p for p in pairs if p["both_sampled_positions_inside_authored_region"]
                       and p["both_sampled_positions_outside_separate_16_cell_metric"]]
    confirmation = bool(extension_pairs) and all(p["exploration_drive_change"] > 0 and p["matches_full_interval_recharge_rate"] for p in extension_pairs)
    old_rows, new_rows = baseline["sampled_timeline"], current["sampled_timeline"]
    comparison = {
        "exactly_equal_selected_position_samples": [b["requested_second"] for a, b in zip(old_rows, new_rows) if a["position"] == b["position"]],
        "first_different_selected_position_sample": next((b["requested_second"] for a, b in zip(old_rows, new_rows) if a["position"] != b["position"]), None),
        "first_different_exploration_drive_sample": next((b["requested_second"] for a, b in zip(old_rows, new_rows) if a["exploration_drive"] != b["exploration_drive"]), None),
        "same_sampled_goal_key_phase_and_override_at_all_samples": all(phase_identity(a) == phase_identity(b) for a, b in zip(old_rows, new_rows)),
        "sampled_position_displacements_between_runs": [{"requested_second": b["requested_second"], "distance": math.dist(a["position"], b["position"])} for a, b in zip(old_rows, new_rows)],
        "drive_change_samples48_to51": {"baseline": old_rows[51]["exploration_drive"] - old_rows[48]["exploration_drive"], "current": new_rows[51]["exploration_drive"] - new_rows[48]["exploration_drive"]},
        "resumption_sample52": {"selected_goal": new_rows[52]["selected_goal"], "goal_key": new_rows[52]["goal_key"], "credited_phase_seconds": new_rows[52]["phase_selected_seconds"], "exploration_drive": new_rows[52]["exploration_drive"], "copied_decision_tail": new_rows[52]["recent_decisions_tail"]},
    }
    # These five originals were actually viewed by the independent reviewer.
    graphics = ["frames/frame-0048.png", "frames/frame-0050.png", "frames/frame-0052.png", "frames/frame-0060.png", "media/ambient2-settlement-contact-sheet.png"]
    viewed = {name: digest((current_path.parent.parent / name).read_bytes()) for name in graphics}
    result = {
        "scope": "Independent readback of a repeated ordinary Workbench scene; no new registered episode credit, runtime rerun, or replacement for full artifact custody.",
        "baseline_application": BASELINE, "current_application": CURRENT, "observer_source": OBSERVER,
        "observer_workflow_run": 45552888360,
        "observer_artifact": {"id": 14994329664, "bytes": 25590794, "sha256": "0c13de36d1d60935a6d1e4b20ce764da670851f7199d402caf5059d493bd9447", "custody_scope": "Metadata independently retrieved; the authoring lane owns the original download, full archive/frame audit and source/runtime custody."},
        "reader_sha256": digest(Path(__file__).read_bytes()),
        "original_report_sha256": {"baseline": baseline_hash, "current": current_hash},
        "authored_contract": contract,
        "initial_copied_actor_states_equal": baseline["initial_copied_actor_states"] == current["initial_copied_actor_states"],
        "initial_native_material_byte_equality": "not measured by this watcher; authored scene bytes are verified unchanged",
        "baseline": baseline, "current": current,
        "authored_radius_extension_observed": bool(extension_pairs),
        "sampled_extension_recharge_confirmation": confirmation,
        "paired_sample_comparison": comparison,
        "viewed_original_graphics_sha256": viewed,
        "qualitative_readback": "The original Follow frames make the selected flyer recognizable below the canopy. At sample50 the copied rest label, home region and nearby geometry are visible; at52 an exploratory direction is displayed, and later samples show displacement from that position. Overlay/model labels can overlap. The increase in exploration drive is established by copied diagnostics, not colors or presumed physical stillness. The resumed goal5 retains prior selected dwell; this is not a new goal or an uninterrupted exploration interval.",
        "limits": [
            "One-Hz snapshots and selected-dwell counters do not reconstruct every intervening policy decision or physical position.",
            "The expected per-interval change is conditional on eligibility throughout that interval; a numerical match corroborates the mechanism but does not directly observe continuous occupancy.",
            "Home module arrival inside20 is separate from the primary16-cell geometric return metric. Sampled neutral pace is separate from physical stillness.",
            "The same authored source, seed, initial copied states and runtime do not imply bit-deterministic Rapier physics across executions.",
            "An absent or negative confirmation remains a recorded result and must not be hidden by retuning or relabelling the original source.",
        ],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"application": CURRENT, "home_rest_samples": current["home_rest_sample_seconds"],
                      "observed_extension_intervals": len(extension_pairs), "confirmation": confirmation,
                      "initial_copied_states_equal": result["initial_copied_actor_states_equal"]}))


if __name__ == "__main__":
    main()
