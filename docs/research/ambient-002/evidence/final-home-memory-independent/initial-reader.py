"""Independent selected-shard reading of final paired memory and home outcomes.

Usage: python review_final_home_and_memory.py OLD_ZIP NEW_ZIP SUMMARY OUTPUT
No engine execution, full aggregate decode or new episode credit is involved.
"""
from pathlib import Path
from statistics import median
import copy
import hashlib
import json
import math
import sys
import zipfile

SOURCES = {"old": "a7250e15495667b2fcf564cbed1eaa8dea217c45", "current": "50c6df89528dc9ecdc5316d8c67abf203e192254"}
ARCHIVES = {"old": "eac23768f3b18dc95a35554328f700daa8a81fa9920bab39fa7148aca1958e30", "current": "e96d284ac7e44eea93ff9269461166a09cc40b8a352893cb43dc9975c24bf9ac"}


def sha_file(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        while data := stream.read(65536):
            h.update(data)
    return h.hexdigest()


def read_case(archive, case_id, source):
    name = f"episodes-full/shards/{case_id}/attempt-001/report.json"
    raw = archive.read(name)
    report = json.loads(raw)
    assert report["source_identity"]["source_revision"] == source
    assert report["complete"] and not report["failures"] and len(report["campaigns"]) == 1
    campaign = report["campaigns"][0]
    assert campaign["id"] == case_id and len(campaign["episodes"]) == 1
    assert campaign["native_ticks"] == campaign["physical_ticks"] == campaign["seconds"] * 60
    return campaign, campaign["episodes"][0], {"path": name, "sha256": hashlib.sha256(raw).hexdigest()}


def direct_metrics(row):
    trace = row["trace"]
    points = [s["position"] for s in trace] + [row["last"]]
    extent = max(p[0] for p in points) - min(p[0] for p in points)
    active = stalled = 0
    flight = row["model"] == "4ly_trainer"
    for a, b in zip(trace, trace[1:]):
        if math.hypot(*a["action_move"]) > 0.05:
            active += 1
            progress = math.dist(a["position"], b["position"]) if flight else abs(a["position"][0] - b["position"][0])
            stalled += progress < 0.25
    return {"x_range_cells": extent, "active_intervals": active,
            "stalled_active_intervals": stalled,
            "stalled_active_fraction": stalled / active if active else 0.0}


def home_readback(row):
    trace = row["trace"]
    assert len(trace) == 1200 and row["model"] == "4ly_trainer"
    modules = [m for m in row["profile"]["modules"] if m["type"] == "seek_home_drive"]
    assert len(modules) == 1 and modules[0]["params"]["arrival_radius"] == 20
    events, windows, away = [], [], False
    for sample in trace:
        distance = math.dist(sample["position"], row["start"])
        assert abs(distance - sample["home_distance"]) < 1e-4
        kind = None
        if not away and distance >= 40:
            away, kind = True, "departure"
        elif away and distance <= 16:
            away, kind = False, "return"
        if kind:
            events.append({"kind": kind, "seconds": sample["seconds"], "distance": distance,
                           "selection": sample["selection"], "phase": sample["phase"],
                           "home_module_selected_at_crossing": sample["selection"] == modules[0]["id"]})
    previous, start = None, None
    for index, sample in enumerate(trace + [None]):
        key = (sample["selection"], sample["phase"]) if sample and sample["selection"] == modules[0]["id"] else None
        if key == previous:
            continue
        if previous is not None:
            part = trace[start:index]
            changes = [b["drives"]["exploration"] - a["drives"]["exploration"] for a, b in zip(part, part[1:])]
            windows.append({
                "selected_module": previous[0], "phase": previous[1],
                "from_seconds": part[0]["seconds"], "until_exclusive_seconds": round(part[-1]["seconds"] + 0.1, 6),
                "samples": len(part), "sampled_phase_occupancy_seconds": len(part) * 0.1,
                "first_to_last_sample_elapsed_seconds": part[-1]["seconds"] - part[0]["seconds"],
                "home_distance_first": part[0]["home_distance"], "home_distance_last": part[-1]["home_distance"],
                "home_distance_minimum": min(p["home_distance"] for p in part),
                "home_distance_maximum": max(p["home_distance"] for p in part),
                "exploration_drive_first": part[0]["drives"]["exploration"],
                "exploration_drive_last": part[-1]["drives"]["exploration"],
                "first_to_last_drive_change": part[-1]["drives"]["exploration"] - part[0]["drives"]["exploration"],
                "positive_drive_intervals": sum(change > 1e-8 for change in changes),
                "negative_drive_intervals": sum(change < -1e-8 for change in changes),
            })
        previous, start = key, index if key is not None else None
    return {"arrival_radius": modules[0]["params"]["arrival_radius"], "rest_seconds": modules[0]["params"]["rest_seconds"],
            "geometric_events": events, "geometric_returns": sum(e["kind"] == "return" for e in events),
            "geometric_returns_while_home_module_selected": sum(e["kind"] == "return" and e["home_module_selected_at_crossing"] for e in events),
            "selected_home_windows": windows,
            "selected_home_seconds": sum(w["sampled_phase_occupancy_seconds"] for w in windows),
            "selected_rest_seconds": sum(w["sampled_phase_occupancy_seconds"] for w in windows if w["phase"] == "home_rest"),
            "final_drives": row["final_drives"], "final_failure_events": row["final_memory"]["failure_events"]}


def main():
    old_path, current_path, summary_path, output_path = map(Path, sys.argv[1:])
    for label, path in (("old", old_path), ("current", current_path)):
        assert sha_file(path) == ARCHIVES[label]
    summary = json.loads(summary_path.read_bytes())
    assert summary["source_identity"]["source_revision"] == SOURCES["current"]
    reduced = {r["episode_id"]: r for r in summary["episodes"]}
    home, paired, blocked = [], [], []
    with zipfile.ZipFile(old_path) as old, zipfile.ZipFile(current_path) as current:
        for arm in ("stateful", "no_memory"):
            case_id = f"sustained-pockets-4ly_trainer-s1701-t120-n1-{arm}"
            previous_case = previous_row = None
            for label, archive in (("old", old), ("current", current)):
                campaign, row, original = read_case(archive, case_id, SOURCES[label])
                metrics, interpretation = direct_metrics(row), home_readback(row)
                if label == "current":
                    for field in ("initial_materials", "initial_pose_sha256", "geometry", "seed", "seconds"):
                        assert campaign[field] == previous_case[field]
                    assert row["profile"] == previous_row["profile"]
                    check = reduced[row["episode_id"]]
                    for field, value in metrics.items():
                        assert math.isclose(value, check[field], abs_tol=1e-9)
                    assert interpretation["geometric_returns"] == check["home_returns_16_cells"]
                home.append({"source": SOURCES[label], "arm": arm, "original": original,
                             "independent_motion_metrics": metrics, **interpretation})
                previous_case, previous_row = campaign, row
        for model in ("runner", "monowheel", "4ly_trainer"):
            pairs = []
            for seed in (605, 1701, 2909):
                values, profiles, starts, originals = {}, {}, {}, {}
                for arm in ("stateful", "no_memory"):
                    campaign, row, original = read_case(current, f"main-pockets-{model}-s{seed}-t30-n1-{arm}", SOURCES["current"])
                    metrics = direct_metrics(row)
                    for field, value in metrics.items():
                        assert math.isclose(value, reduced[row["episode_id"]][field], abs_tol=1e-9)
                    values[arm], originals[arm] = metrics, original
                    profiles[arm] = copy.deepcopy(row["profile"])
                    assert profiles[arm]["memory"]["enabled"] == (arm == "stateful")
                    del profiles[arm]["memory"]["enabled"]
                    starts[arm] = [campaign[field] for field in ("initial_materials", "initial_pose_sha256", "geometry", "outcome_observer")]
                assert profiles["stateful"] == profiles["no_memory"] and starts["stateful"] == starts["no_memory"]
                pairs.append({"seed": seed, "originals": originals, "metrics": values,
                              "x_range_delta": values["stateful"]["x_range_cells"] - values["no_memory"]["x_range_cells"],
                              "active_stall_delta": values["stateful"]["stalled_active_fraction"] - values["no_memory"]["stalled_active_fraction"]})
            paired.append({"model": model, "paired_seed_results": pairs,
                           "median_paired_x_range_delta": median(p["x_range_delta"] for p in pairs),
                           "median_paired_active_stall_delta": median(p["active_stall_delta"] for p in pairs)})
        for seed in (605, 1701):
            campaign, row, original = read_case(current, f"adverse-blocked_route-runner-s{seed}-t30-n1-stateful", SOURCES["current"])
            event = next(e for e in campaign["events"] if e["kind"] == "block_familiar_route_with_native_stone")
            wall_second = event["tick"] / 60
            memory = row["final_memory"]
            assert memory["failure_events"] == 5 and len(memory["obstructions"]) == 1
            obstruction = memory["obstructions"][0]
            assert obstruction["attempts"] == 5 and obstruction["last_seen"] < wall_second == 15
            withdrawal = sum(s["selection"] == "withdraw_obstruction" for s in row["trace"]) * 0.1
            assert math.isclose(withdrawal, 9.1)
            blocked.append({"seed": seed, "original": original, "intervention": event,
                            "intervention_seconds": wall_second, "failure_events": memory["failure_events"],
                            "retained_obstruction": obstruction, "selected_withdrawal_seconds": withdrawal,
                            "interpretation": "All five retained failure events precede the introduced wall; later withdrawal reuses earlier evidence."})
    result = {"status": "PASS", "applications": SOURCES, "original_archive_sha256": ARCHIVES,
              "summary_sha256": sha_file(summary_path), "reader_sha256": sha_file(Path(__file__)),
              "scope": "Selected original shards: eighteen main memory-pair episodes, four old/new sustained flyer episodes and two final blocked-route episodes. Read-only analysis adds no physical episode credit and does not replace the full122-chain custody audit.",
              "main_memory_pairs": paired, "sustained_flyer_home": home, "blocked_route_timing": blocked,
              "limits": ["Primary traces carry selected module labels and phases, not unique goal keys; separated rest windows are not declared distinct goal instances.",
                         "Configured20-cell home-rest acceptance is separate from40-cell departure/16-cell geometric return counting. At-crossing selected intention is reported explicitly.",
                         "Forty intervening drive intervals span4.0seconds even when41 phase samples imply4.1seconds of sampled phase occupancy.",
                         "One sustained World per arm does not estimate a population home-return rate or a general memory advantage.",
                         "Ground stalls use horizontal progress and flight stalls Euclidean progress. Center path and neutral commands do not establish exploration or stillness."]}
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": "PASS", "paired_x_deltas": [p["median_paired_x_range_delta"] for p in paired],
                      "current_flyer_returns": [(h["arm"], h["geometric_returns"], h["geometric_returns_while_home_module_selected"]) for h in home if h["source"] == SOURCES["current"]],
                      "output": str(output_path)}))


if __name__ == "__main__":
    main()
