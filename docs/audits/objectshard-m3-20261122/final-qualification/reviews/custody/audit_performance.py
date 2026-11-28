"""Independent raw-sample review; no new thresholds, trials, or product writes."""
import argparse
from collections import Counter
import datetime
import hashlib
import json
import math
from pathlib import Path
import subprocess
import zipfile

SOURCE = "e034f2294663e0485cfb9adcc8ada46a6e977cee"
TREE = "246e7324ca618d98c43a0ed54fe19bc86a155877"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {"count": 0}
    return {"count": len(ordered), "p50": ordered[math.ceil(len(ordered) * .5) - 1],
            "p95": ordered[math.ceil(len(ordered) * .95) - 1], "p99": ordered[math.ceil(len(ordered) * .99) - 1], "maximum": ordered[-1]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--prefix", default="")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    archive = zipfile.ZipFile(args.archive) if args.archive else None
    report = {"schema": "objectshard-independent-final-performance-custody-v1", "source_commit": SOURCE, "source_tree": TREE,
              "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "failures": [], "source_bound_evidence_sha256": {}}
    def expect(condition, message):
        if not condition:
            report["failures"].append(message)
    def read(name):
        data = archive.read(args.prefix.rstrip("/") + "/" + name) if archive else (args.evidence / name).read_bytes()
        report["source_bound_evidence_sha256"][name] = sha(data)
        return data
    def document(name):
        return json.loads(read(name))
    def committed(path):
        return subprocess.check_output(["git", "-C", str(args.repo), "show", SOURCE + ":" + path])
    q = document("qualification.json")
    expect(q.get("source_commit") == SOURCE and q.get("source_tree") == TREE and q.get("status") == "passed", "Exact current qualification source/status")
    report["runtime"] = q["runtime"]
    budget = json.loads(committed("tools/objectshard/lab_budgets.json"))
    report["lab_budget_sha256"] = sha(committed("tools/objectshard/lab_budgets.json"))
    limits = budget["limits"]
    report["lab_profiles"] = {}
    for rendered in [False, True]:
        name = "objectshard_profile_" + ("rendered" if rendered else "headless")
        raw = document(name + ".json")
        expect(raw.get("schema") == "objectshard-lab-profile-v1" and raw.get("source_revision") == SOURCE and raw.get("failures") == 0 and raw.get("rendered") is rendered, name + " exact complete report")
        cases = raw["cases"]
        expect(len(cases) == len(budget["required_workloads"]) and {case["name"] for case in cases} == set(budget["required_workloads"]), name + " unchanged complete workload inventory")
        checks = 0
        def maximum(actual, limit_key, label):
            nonlocal checks
            checks += 1
            expect(type(actual) in [int, float] and math.isfinite(actual) and 0 <= actual <= limits[limit_key], name + ": " + label + " exceeds " + limit_key)
        summary = {"budget_checks": 0, "rendered": rendered, "workloads": []}
        for case in cases:
            samples = case["profile_samples"]
            expect(case.get("failed") is False and len(samples) == raw["requested_samples"] == 1200 and len(samples) >= budget["minimum_samples_per_workload"], name + ": " + case["name"] + " complete sample count")
            row = {"name": case["name"], "samples": len(samples)}
            for metric, prefix in [("frame_usec", "frame"), ("present_interval_usec", "rendered_present_interval")]:
                if metric != "frame_usec" and not rendered:
                    continue
                values = [sample[metric] for sample in samples if metric in sample]
                expect(len(values) == len(samples) - int(metric == "present_interval_usec") and all(type(v) in [int, float] and math.isfinite(v) and v >= 0 for v in values), name + " complete finite " + metric)
                stats = distribution(values)
                row[metric] = stats
                for key, actualkey in [("p95", "p95"), ("p99", "p99"), ("max", "maximum")]:
                    expect(case["timings"][metric][key] == stats[actualkey], name + " declared statistics differ from all raw observations")
                    maximum(stats[actualkey], prefix + "_" + key + "_usec", case["name"] + "." + metric + "." + key)
            extra = [(case["promotion_max_usec"], "promotion_pause_max_usec"),
                     (case["physics_metrics"]["geometry_install_max_usec"], "geometry_install_max_usec"),
                     (case["native_metrics"]["maximum_geometry_age"], "geometry_age_max_ticks"),
                     (case["native_metrics"]["maximum_geometry_wait_ns"] / 1000, "geometry_wait_max_usec")]
            for actual, key in extra:
                maximum(actual, key, case["name"] + "." + key)
                row[key] = actual
            summary["workloads"].append(row)
        summary["budget_checks"] = checks
        declared = next(case for case in q["cases"] if case["name"] == name)["budget_qualification"]
        expect(declared["status"] == "passed" and declared["limits_checked"] == checks and not declared["failures"], name + " qualification agrees with independent raw reduction")
        report["lab_profiles"][name] = summary
    control = document("objectshard_worker_profile_0.json")
    candidate = document("objectshard_worker_profile_4000.json")
    for label, value, pump in [("control", control, 0), ("candidate", candidate, 4000)]:
        expect(value.get("schema") == "objectshard-worker-scheduling-profile-v1" and value.get("failures") == 0
               and value.get("notifications") is False and value.get("pump_budget_usec") == pump, label + " correct profile mode")
        expect(value["identity"]["revision"] == SOURCE and value["completed_intervals"] == 240 and value["actual_live_inputs"] == 60 and value["actual_physics_steps"] == 954 and len(value["publication_digests"]) == 240, label + " complete exact-source physical workload")
        for path, digest in value["identity"]["files"].items():
            gitpath = path.replace("res://", "godot/")
            if q["runtime"]["platform"] == "win32" and gitpath.endswith("cybersand_native.windows.x86_64.dll"):
                expected = q["runtime"]["native_sha256"]
            elif q["runtime"]["platform"].startswith("linux") and gitpath.endswith("libcybersand_native.linux.x86_64.so"):
                expected = q["runtime"]["native_sha256"]
            elif q["runtime"]["platform"] == "win32" and gitpath.endswith("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"):
                expected = q["runtime"]["rapier_sha256"]
            elif q["runtime"]["platform"].startswith("linux") and gitpath.endswith("libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"):
                expected = q["runtime"]["rapier_sha256"]
            else:
                expected = sha(committed(gitpath))
            expect(digest == expected, label + " profile input bytes " + path)
        expected_engine = "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8" if q["runtime"]["platform"] == "win32" else q["runtime"]["godot_sha256"]
        expect(value["identity"]["engine_sha256"] == expected_engine, label + " actual engine hash")
        expect(len(value["contact_owners"]) == len(value["sleeping_owners"]) == 3 and all(v > 1 for v in value["maximum_displacements"].values()), label + " real nonempty moving/contact/settled fixture")
    matched = ["identity", "engine", "platform", "publication_digests", "native_accounting", "completed_intervals", "actual_live_inputs", "actual_physics_steps"]
    expect(all(control[k] == candidate[k] for k in matched), "Control/candidate canonical publication/material ledgers differ")
    pair = {"matched_fields": matched, "publication_count": 240, "actual_live_inputs": 60, "actual_physics_steps": 954,
            "control_wall_usec": control["play_elapsed_usec"], "candidate_wall_usec": candidate["play_elapsed_usec"],
            "control_semantic_ticks_per_wall_second": 240e6 / control["play_elapsed_usec"],
            "candidate_semantic_ticks_per_wall_second": 240e6 / candidate["play_elapsed_usec"],
            "wall_progression_ratio": control["play_elapsed_usec"] / candidate["play_elapsed_usec"],
            "candidate_soft_pump_budget_usec": 4000, "candidate_actual_pump_call_usec": candidate["pump_call_usec"],
            "control_admission_to_publication_usec": control["host_stages_usec"]["host_admission_to_publication_usec"],
            "candidate_admission_to_publication_usec": candidate["host_stages_usec"]["host_admission_to_publication_usec"],
            "scope": "One source/runtime-matched same-platform pair; 240 canonical published World materials and shard material/state/temperature/pose/geometry digests plus quantity ledgers match. Not hidden full World state or a cross-platform Rapier identity proof. Pump budget includes a possibly-overrunning current handler."}
    declared = q["worker_scheduling_comparison"]
    expect(declared["status"] == "passed" and math.isclose(declared["wall_progression_ratio"], pair["wall_progression_ratio"], rel_tol=1e-12), "Declared paired rate matches retained elapsed intervals")
    report["worker_scheduling_pair"] = pair
    live = document("continuous-play-rendered.json")
    expect(live.get("source_revision") == SOURCE and live.get("failed") is False and live.get("state") == "Idle", "Rendered live report exact source and clean interval completion")
    actions = live["action_results"]
    expect(len(actions) == 153 and len({row["action_id"] for row in actions}) == 153, "Complete unique153 live action records")
    expect(all(row["input_observation"] == "scene_intent" and 0 < row["captured_usec"] <= row["admitted_usec"] <= row["completed_usec"] for row in actions), "Original scene capture survives action admission/completion")
    computed_result = distribution([row["completed_usec"] - row["captured_usec"] for row in actions])
    computed_admission = distribution([row["completed_usec"] - row["admitted_usec"] for row in actions])
    for key, computed in [("input_to_result_usec", computed_result), ("host_admission_to_result_usec", computed_admission)]:
        expect(all(live["timings_usec"][key][k] == v for k,v in computed.items()), "Rendered " + key + " agrees with per-action monotonic ledger")
    ui = {}
    for metric, values in live["presentation_timing"]["stages"].items():
        actual = distribution(values["retained_values_usec"])
        expect(actual["count"] == values["count"] and all(actual[k] == values[k + "_usec"] for k in ["p50", "p95", "p99", "maximum"]), "UI raw timing reduction " + metric)
        expect(actual["count"] <= live["presentation_timing"]["retention_capacity_each"], "Bounded UI timing retention")
        ui[metric] = actual
    expect(live["timings_usec"]["input_to_presented_usec"]["count"] == 153 and ui["input_to_host_usec"]["count"] == 153, "Actual rendered presentation and UI admission samples")
    expect(live["maximum_actions"] <= 32 and live["action_capacity"] == 32 and live["actions_per_tick"] == 4 and live["timing_sample_capacity"] == 2048 and live["presentation_timing"]["retention_capacity_each"] == 4096, "Bounded current action/timing capacities unchanged")
    report["rendered_live_burst"] = {"actions": len(actions), "outcomes": dict(Counter(row["outcome"] for row in actions)),
        "pointer_input": live["pointer_input"], "host_timings_usec": live["timings_usec"], "ui_timings_usec": ui,
        "action_ledger_verified": True, "maximum_host_actions": live["maximum_actions"],
        "worker_maximum_snapshot_value_bytes": live["worker"]["maximum_snapshot_value_bytes"],
        "worker_maximum_reply_value_bytes": live["worker"]["maximum_reply_value_bytes"],
        "process_wide_maximum_godot_static_bytes": live["worker"]["maximum_godot_static_bytes"],
        "scope": "Maintained rendered153-action workload includes96-point burst. All original UI queue latency is included; slowp95/p99/max must remain visible. Frame callback is nested CPU work, not end-to-end responsiveness. Presentation summary is actual frame_post_draw, not raw per-present timestamp ledger or scanout."}
    longrun = document("continuous-physics.json")
    expect(longrun.get("source_revision") == SOURCE and longrun.get("failures") == 0 and longrun.get("checks") >= 22513,
           "Actual sustained physical report source/completeness")
    expect(longrun["tick"] == 3600 and longrun["completed_ticks"] == 3599 and longrun["physics_steps"] == 14390 and longrun["actions_queued"] == 540
           and longrun["moving_owners"] == longrun["sleeping_owners"] == 3 and longrun["real_contacts"] is True and longrun["fire_seen"] is True and longrun["smoke_seen"] is True, "Nonempty sustained motion/chemistry/edit workload")
    sparse = {k: {str(i):n for i,n in enumerate(v) if n} if isinstance(v,list) else v for k,v in longrun["native_accounting"].items()}
    report["sustained_actual_physics"] = {k:v for k,v in longrun.items() if k not in ["report", "worker", "native_accounting", "engine", "timing"]}
    report["sustained_actual_physics"].update(native_accounting_sparse=sparse,
        post_erosion_rotation_degrees=math.degrees(longrun["post_erosion_maximum_rotation"]),
        scope="Actual3600 semantic tick state,3599 host interval completions after initial fixture,540 queued actions and14390 real substeps. Longrun authored Sand/Water and accepted exposure do not alone prove ingestion or extinction; inspect separate fixtures.")
    report["methodology_limits"] = ["Lab limits are unchanged; headless56 and rendered80 constraints independently recomputed from complete1200-sample workloads",
        "Native6MiB allocator bound and14,176B margin exclude Godot/Rapier/GPU/mailbox container overhead; no universal canvas scalability claim",
        "Stage counters overlap; enclosing result/publication/presentation and frame callbacks must not be summed",
        "Hosted software-renderer timing is not owner Windows11/NVIDIA gameplay or a60FPS claim",
        "Same-source pair is a single controlled workload observation, not statistical or cross-platform bit-identical proof"]
    report["status"] = "passed" if not report["failures"] else "failed"
    args.output.write_text(json.dumps(report,indent=2) + "\n")
    print(json.dumps({"status": report["status"], "failures": report["failures"], "runtime": q["runtime"],
                      "pair": pair, "input_to_presented_usec": live["timings_usec"]["input_to_presented_usec"], "ui": ui}, indent=2))
    if archive:
        archive.close()
    raise SystemExit(bool(report["failures"]))


if __name__ == "__main__":
    main()
