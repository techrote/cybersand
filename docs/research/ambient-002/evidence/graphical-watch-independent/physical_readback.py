#!/usr/bin/env python3
"""Read retained ordinary-Workbench observations; never execute the application."""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path

SOURCE = "a7250e15495667b2fcf564cbed1eaa8dea217c45"
ENGINE = "f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75"
OBSERVER = "aac731d1d44fcc46beca22ea6b0ee84e1acfe4c09ad51cc47bd52abb8c922379"
REPORTS = {
    "ambient2-courtyard": (1, 8, "f65af557ec7365ccbf9f57615af65da6cfcdc22054b8de2f340715c2717aff9d"),
    "ambient2-refinery": (5, 6, "de7678b1e4876b89273270e6b2046da965a3e27d9e80bc33223dac622203c16c"),
    "ambient2-settlement": (7, 8, "241b442f92b4564b844b47c2c0f4d09ec6ddc42c940f6a8322a6b4890d3db466"),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def point(value):
    assert isinstance(value, list) and len(value) == 2
    assert all(isinstance(v, (int, float)) and math.isfinite(v) for v in value)
    return value


def label(actor):
    intent = actor["intent"]
    return intent.get("active_override") or intent.get("selected_goal") or "no_override_or_goal"


def components(actors, threshold=40.0):
    """Post-run geometry over copied actual poses; not a production policy scan."""
    positions = {int(a["instance_id"]): point(a["observation"]["position"]) for a in actors}
    remaining = set(positions)
    groups = []
    while remaining:
        start = min(remaining)
        remaining.remove(start)
        connected = {start}
        pending = [start]
        while pending:
            current = pending.pop()
            neighbors = {other for other in remaining
                         if math.dist(positions[current], positions[other]) <= threshold}
            remaining -= neighbors
            connected |= neighbors
            pending.extend(sorted(neighbors))
        if len(connected) > 1:
            groups.append(sorted(connected))
    return sorted(groups)


def motion(rows):
    points = [point(a["observation"]["position"]) for a in rows]
    return {
        "initial_position": points[0],
        "final_position": points[-1],
        "sampled_horizontal_range_cells": max(p[0] for p in points) - min(p[0] for p in points),
        "sampled_vertical_range_cells": max(p[1] for p in points) - min(p[1] for p in points),
        "net_horizontal_displacement_cells": points[-1][0] - points[0][0],
        "net_euclidean_displacement_cells": math.dist(points[0], points[-1]),
        "sampled_absolute_horizontal_travel_cells": sum(abs(b[0] - a[0]) for a, b in zip(points, points[1:])),
        "sampled_center_path_cells": sum(math.dist(a, b) for a, b in zip(points, points[1:])),
    }


def focus_record(sample, actor):
    intent = actor["intent"]
    env = actor["environment"]
    targets = {}
    for key, value in env.get("materials", {}).get("targets", {}).items():
        targets[key] = {k: value[k] for k in ("present", "available", "coverage_complete", "nearest", "distance", "sample_tick", "revision") if k in value}
    return {
        "requested_second": sample["requested_simulation_second"],
        "actual_simulation_seconds": sample["simulation_seconds_since_play"],
        "current_physical_tick": sample["diagnostics_physical_tick"],
        "position": actor["observation"]["position"],
        "selected_label": label(actor),
        "selected_goal": intent.get("selected_goal", ""),
        "goal_key": intent.get("goal_key", ""),
        "phase": intent.get("goal_phase", ""),
        "target": intent.get("goal_target"),
        "pace": intent.get("pace"),
        "reason": intent.get("reason", ""),
        "drives": actor["drives"],
        "failure_events": actor["memory"].get("failure_events"),
        "neighbors": [{k: p[k] for k in ("id", "position", "distance", "affinity", "sample_tick") if k in p}
                      for p in env.get("neighbors", {}).get("actors", [])],
        "material_targets": targets,
    }


def read_scene(root, scene, expected):
    focus, count, expected_sha = expected
    path = root / scene / "frames/watch-report.json"
    raw = path.read_bytes()
    assert sha(raw) == expected_sha
    report = json.loads(raw)
    assert report["source_revision"] == SOURCE
    assert report["engine_sha256"] == ENGINE
    assert report["observer_script_sha256"] == OBSERVER
    assert report["status"] == "passed" and report["failures"] == []
    assert report["physical_ticks"] == report["native_ticks"] == 3601
    assert report["follow_actor"] == focus
    samples = report["samples"]
    assert len(samples) == 61
    assert [s["requested_simulation_second"] for s in samples] == list(range(61))
    roster = list(range(1, count + 1))
    for sample in samples:
        assert sorted(a["instance_id"] for a in sample["actors"]) == roster
        for actor in sample["actors"]:
            point(actor["observation"]["position"])
    times = [s["simulation_seconds_since_play"] for s in samples]
    assert all(a < b for a, b in zip(times, times[1:]))
    rows = [next(a for a in s["actors"] if a["instance_id"] == focus) for s in samples]
    labels = collections.Counter(label(a) for a in rows[1:])
    peer_sets = collections.Counter(tuple(sorted(p["id"] for p in a["environment"].get("neighbors", {}).get("actors", []))) for a in rows[1:])
    peer_affinities = collections.Counter(str(p["affinity"]) for a in rows[1:] for p in a["environment"].get("neighbors", {}).get("actors", []))
    all_actors = []
    for instance in roster:
        actor_rows = [next(a for a in s["actors"] if a["instance_id"] == instance) for s in samples]
        all_actors.append({"instance_id": instance, "profile_name": actor_rows[-1]["profile_name"],
            "model": actor_rows[-1]["model"], **motion(actor_rows),
            "final_failure_events": actor_rows[-1]["memory"].get("failure_events"),
            "final_accepted_commands": actor_rows[-1]["accepted"], "final_rejected_commands": actor_rows[-1]["rejected"]})
    group_frames = [{"requested_second": s["requested_simulation_second"], "components": components(s["actors"])} for s in samples]
    grouped = sum(sum(len(g) for g in s["components"]) for s in group_frames[1:])
    copied_frame_matches = 0
    copied_frame_comparisons = 0
    for sample in samples:
        captured = {int(a["instance_id"]): a["current_physical_position"] for a in sample["capture"]["actors"]}
        for actor in sample["actors"]:
            copied_frame_comparisons += 1
            copied_frame_matches += actor["observation"]["position"] == captured[int(actor["instance_id"])]
    display_lags = []
    for sample in samples:
        frame = sample["capture"].get("rendered_actor_frame", {})
        if "sample_tick" in frame:
            display_lags.append(sample["diagnostics_physical_tick"] - frame["sample_tick"])
    return {
        "scene": scene, "report_member": str(path.relative_to(root)), "report_sha256": expected_sha,
        "focus_actor": focus, "profile_name": rows[-1]["profile_name"],
        "actor_count": count, "samples": len(samples),
        "actual_simulation_seconds": report["actual_simulation_seconds"],
        "elapsed_wall_seconds": report["elapsed_wall_seconds"],
        "last_sample_wall_seconds_since_play": samples[-1]["wall_seconds_since_play"],
        "renderer": report["renderer"], "actual_framebuffer_size": report["actual_framebuffer_size"],
        "camera_events": report["camera_events"],
        "focus_motion": motion(rows),
        "poststart_selection_snapshot_counts": dict(sorted(labels.items())),
        "copied_peer_sets_snapshot_counts": [{"ids": list(ids), "snapshots": n} for ids, n in sorted(peer_sets.items())],
        "copied_peer_affinity_sample_counts": dict(sorted(peer_affinities.items())),
        "poststart_grouped_actor_snapshot_fraction_at_40_cells": grouped / (60 * count),
        "proximity_components_by_snapshot": group_frames,
        "focus_final_failure_events": rows[-1]["memory"].get("failure_events"),
        "focus_sampled_trace": [focus_record(s, a) for s, a in zip(samples, rows)],
        "all_actor_motion": all_actors,
        "capture_copied_pose_comparisons": copied_frame_comparisons,
        "capture_copied_pose_exact_matches": copied_frame_matches,
        "display_sample_lag_ticks_range": [min(display_lags), max(display_lags)] if display_lags else None,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = {
        "schema": "ambient-002-independent-sustained-physical-readback/v1",
        "status": "PASS", "source_revision": SOURCE,
        "artifact_id": 14992866806,
        "artifact_sha256": "907f8bcdd11ef4c7150dc252844ec8545a0a7a46e66abf41ff10e889ad868cef",
        "reader_sha256": sha(Path(__file__).read_bytes()),
        "scope": "Post-run readback of three ordinary Workbench observations; zero new engine execution; separate from the primary 194 registered episodes.",
        "limits": [
            "Sixty post-start snapshots per actor are not complete 0.1-second traces. Selection counts are sampled occupancies, not exact seconds or counts of distinct goals.",
            "Range and path use the current copied physical body centers. Horizontal ground range excludes vertical settling and gait; center path includes them. Sparse summed travel can miss between-sample reversals.",
            "The 40-cell component calculation is descriptive post-run proximity over the copied roster, not cooperation, affinity causality or a production scan.",
            "Recorded peer/material observations belong to the last policy decision. Rendered frame identities and current copied body poses remain separate.",
            "Elapsed wall time covers this software-rendered observer run, not OS CPU utilization, continuous-video FPS, user-hardware playfeel or an isolated policy cost."
        ],
        "scenes": [read_scene(args.root, scene, expected) for scene, expected in REPORTS.items()],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "scenes": len(result["scenes"]), "source_revision": SOURCE, "output_sha256": sha(args.output.read_bytes())}))


if __name__ == "__main__":
    main()
