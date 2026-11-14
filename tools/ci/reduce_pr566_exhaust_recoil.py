#!/usr/bin/env python3
"""Reduction of actual source-built Godot/Rapier PR566 exhaust-recoil arms.

No invented certainty: output has a discriminating observation and an explicit
INCONCLUSIVE verdict when the authored scene did not generate unresolved exhaust.
"""
import json
import math
import pathlib
import statistics
import sys

ARM_NAMES = ("nofire_normal", "nofire_suppressed", "fire_normal", "fire_suppressed")
SCHEMA = "PR566_REAL_RAPIER_EXHAUST_RECOIL"


def magnitude(pair):
    return math.hypot(float(pair[0]), float(pair[1]))


def percentile(values, fraction):
    if not values:
        return None
    values = sorted(values)
    at = (len(values) - 1) * fraction
    lower = int(at)
    upper = min(lower + 1, len(values) - 1)
    return values[lower] + (values[upper] - values[lower]) * (at - lower)


def dot(a, b):
    return float(a[0]) * float(b[0]) + float(a[1]) * float(b[1])


def native_rows(samples):
    # Each worker response may be presented for multiple rendered frames.
    # Count once per accepted native sample, not once per displayed copy.
    distinct = {}
    for s in samples:
        if not s["native_valid"] or s["native_sample"] < 0:
            continue
        identity = (s["native_sample"], s["world_revision"])
        distinct[identity] = s
    return list(distinct.values())


def phase(row):
    t = int(row["tick"])
    if t < 40:
        return "before"
    if t < 100:
        return "fire_window"
    return "after_off"


def summarize_phase(samples):
    positions = [r["position"] for r in samples]
    velocity = [r["velocity"] for r in samples]
    speed = [magnitude(v) for v in velocity]
    accel = [[velocity[i][0]-velocity[i-1][0], velocity[i][1]-velocity[i-1][1]]
             for i in range(1,len(velocity))]
    accel_size = [magnitude(v) for v in accel]
    jerk = [magnitude([accel[i][0]-accel[i-1][0],
                       accel[i][1]-accel[i-1][1]]) for i in range(1,len(accel))]
    reversing = sum(dot(accel[i],samples[i+1]["controller_force"]) < -1e-6
                    for i in range(len(accel)))
    rows = native_rows(samples)
    fire = sum(int(r["native_exhaust_fire_unresolved"]) for r in rows)
    smoke = sum(int(r["native_exhaust_smoke_unresolved"]) for r in rows)
    recoil = sum(magnitude(r["native_exhaust_unresolved_raw_impulse"]) for r in rows)
    applied = sum(magnitude(r["applied_impulse"]) for r in samples)
    return {
        "observations":len(samples),"native_distinct_responses":len(rows),
        "fire_unresolved":fire,"smoke_unresolved":smoke,
        "candidate_exhaust_recoil_magnitude_sum_pre_cap":recoil,
        "applied_impulse_observed_sum_magnitude":applied,
        "start_position":positions[0] if positions else None,
        "end_position":positions[-1] if positions else None,
        "speed_p95":percentile(speed,.95),
        "absolute_delta_v_p95":percentile(accel_size,.95),
        "absolute_delta_delta_v_p95":percentile(jerk,.95),
        "negative_delta_v_along_controller_force":reversing,
        "display_sample_gap_count":sum(r["display_frame_sample"] >= 0 and
                                         r["display_frame_sample"] != r["native_sample"]
                                         for r in samples),
        "render_upload_serial_unique":len({r["render_serial"] for r in samples}),
    }


def summarize(path, name):
    data = json.loads(path.read_text(encoding="utf-8"))
    if data["case"] != SCHEMA:
        raise ValueError(f"{name}: wrong fixture case")
    if data["failures"]:
        raise ValueError(f"{name}: failed actual-host assertions: {data['failures']}")
    intended_fire = name.startswith("fire_")
    intended_suppression = name.endswith("_suppressed")
    if (data["trial"] == "fire") != intended_fire:
        raise ValueError(f"{name}: trial label mismatched")
    if bool(data["diagnostic_suppression"]) != intended_suppression:
        raise ValueError(f"{name}: diagnostic mode mismatched")
    if intended_fire and int(data["actual_fire_inserts"]) <= 0:
        raise ValueError(f"{name}: no actual World Fire emission occurred")
    if not intended_fire and int(data["actual_fire_inserts"]) != 0:
        raise ValueError(f"{name}: nofire control emitted Fire")
    samples = data["samples"]
    if len(samples) < 170 or not data["native_frames"]:
        raise ValueError(f"{name}: incomplete physical telemetry")
    if not all(samples[i]["tick"] <= samples[i+1]["tick"]
               for i in range(len(samples)-1)):
        raise ValueError(f"{name}: nonmonotonic tick observations")
    fields = [r for r in samples if r["native_exhaust_fire_unresolved"] >= 0]
    if len(fields) < 10 or any(
        bool(r["native_exhaust_recoil_suppressed"]) != intended_suppression for r in fields
    ):
        raise ValueError(f"{name}: variant/native diagnostic readback mismatch")
    segments = {label:summarize_phase([r for r in samples if phase(r)==label])
                for label in ("before","fire_window","after_off")}
    return {
        "filename":str(path),"godot":data["godot"],"os":data["os"],
        "source_parent":data["source_parent"],
        "actual_fire_inserts":data["actual_fire_inserts"],
        "native_frames":data["native_frames"],
        "emission_receipts":data["emitters"],
        "segments":segments,
    }


def main(argv):
    if len(argv) != 3:
        raise SystemExit("usage: reduce_pr566_exhaust_recoil.py <evidence-dir> <output-json>")
    source = pathlib.Path(argv[1])
    report = {name:summarize(source / (name+".json"),name) for name in ARM_NAMES}
    identities = {(r["godot"],r["os"],r["source_parent"]) for r in report.values()}
    if len(identities) != 1:
        raise ValueError("arms are not on matching Godot/OS/source-parent identities")
    normal = report["fire_normal"]["segments"]
    suppressed = report["fire_suppressed"]["segments"]
    trapped = sum(normal[p]["fire_unresolved"]+normal[p]["smoke_unresolved"]+
                  suppressed[p]["fire_unresolved"]+suppressed[p]["smoke_unresolved"]
                  for p in ("fire_window","after_off"))
    controls = ["before","fire_window","after_off"]
    control_phase_differences = {
        p: {
            metric: report["nofire_suppressed"]["segments"][p][metric] -
                    report["nofire_normal"]["segments"][p][metric]
            for metric in ("absolute_delta_v_p95","absolute_delta_delta_v_p95")
            if (report["nofire_suppressed"]["segments"][p][metric] is not None
                and report["nofire_normal"]["segments"][p][metric] is not None)
        } for p in controls
    }
    if trapped == 0:
        verdict = "INCONCLUSIVE: no unresolved Fire/Smoke mask overlaps observed"
    else:
        verdict = "EXHAUST_OVERLAP_REPRODUCED: compare Rapier jitter and actual applied impulse; GPU double-image still requires visual correlation"
    result = {
        "experiment":"PR566 real Rapier flight, ordinary Fire nozzle and selective unresolved-exhaust recoil A/B",
        "verdict":verdict,
        "total_distinct_exhaust_unresolved_observations":trapped,
        "no_fire_control_differences":control_phase_differences,
        "arms":report,
        "limits":[
            "Headless real Rapier/native testing does not prove the physical Windows GPU visual symptom.",
            "The suppressed variant changes physical trajectory; aggregate A/B differences alone cannot prove an isolated pixel cause.",
            "Uploaded material/actor clocks may differ; per-frame GPU capture remains required for render attribution.",
            "No production physics behavior was changed on PR #566."
        ],
    }
    output = pathlib.Path(argv[2])
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2,allow_nan=False)+"\n",encoding="utf-8")
    print("PR566_RECOIL_VERDICT:",verdict)
    for name in ARM_NAMES:
        x=report[name]
        print(name,"real_fire_inserts",x["actual_fire_inserts"],
              "fire_window",json.dumps(x["segments"]["fire_window"],sort_keys=True),
              "after_off",json.dumps(x["segments"]["after_off"],sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
