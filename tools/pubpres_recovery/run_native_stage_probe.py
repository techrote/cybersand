#!/usr/bin/env python3
"""Read existing native Wave stage clocks on one retained exact gameplay source.

This is causal attribution, not a new performance treatment. The application,
native payload, observer and ordinary real-step gates come from a completed
source-exact comparison. Only the existing cumulative stage readback is enabled.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import uuid

STAGES = ("prepare_ns", "column_ns", "flux_ns", "apply_ns", "merge_ns", "launch_ns")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(value, label):
    if not value:
        raise ValueError(label)


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def validate_probe(value):
    require(isinstance(value, dict) and value.get("schema") == "PUBPRES-WAVE-COLUMNS-V1"
            and value.get("experimental_column_tiles") is False
            and type(value.get("column_slots")) is int and value["column_slots"] == 1,
            "Native readback is not the existing reference column implementation")
    require(all(type(value.get(key)) is int and value[key] >= 0 for key in ("ticks", *STAGES)),
            "Native stage counters have invalid scalar domains")


def joined_stages(data, rows):
    """Join cumulative stages to real steps; never infer a native start clock."""
    previous = data["water_before"]["wave_flow"].get("column_probe")
    require(isinstance(previous, dict), "Initial actual native stage readback missing")
    validate_probe(previous)
    physical = sorted((r for r in rows if r.get("event") == "rapier_step"), key=lambda r: r["step"])
    result = []
    for step in physical:
        matches = [r for r in rows if r.get("event") == "worker_snapshot"
                   and r.get("world_generation") == step["world_generation"]
                   and r.get("tick_index") == step["native_tick_used"]
                   and r.get("completed_body_sample") == step["completed_body_sample"]
                   and r.get("failed") is False and r.get("time_usec", float("inf")) <= step["time_usec"]]
        require(matches, "Real physical step lacks matching healthy native packet")
        values = {(json.dumps(r.get("wave_column_probe"), sort_keys=True), r.get("native_tick_ms")) for r in matches}
        require(len(values) == 1, "Native stage/tick elapsed differs for one native completion")
        probe = matches[0].get("wave_column_probe")
        validate_probe(probe)
        require(probe["ticks"] == previous["ticks"] + 1, "Stage delta skips or repeats a native Wave turn")
        deltas = {key: probe[key] - previous[key] for key in STAGES}
        require(all(type(v) is int and v >= 0 for v in deltas.values()), "Native cumulative stage clock regressed")
        total = matches[0]["native_tick_ms"]
        require(type(total) in (float, int) and math.isfinite(total) and total >= 0,
                "Native tick bracket has an invalid elapsed domain")
        stage_ms = sum(deltas.values()) / 1e6
        # These existing sequential brackets are nested within world_->tick().
        # Residual includes all remaining work and scheduling, never CPU time.
        require(total + 1e-6 >= stage_ms, "Sequential Wave stage sum exceeds actual native tick bracket")
        result.append({"physical_step": step["step"], "native_tick": step["native_tick_used"],
                       "body_sample": step["completed_body_sample"], "native_tick_ms": total,
                       "stages_ns": deltas, "wave_stages_ms": stage_ms,
                       "native_outside_wave_stage_brackets_ms": total - stage_ms,
                       "native_completed_usec": step["native_completed_usec"],
                       "physical_completed_usec": step["time_usec"]})
        previous = probe
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-directory", type=Path, required=True)
    parser.add_argument("--driver-source", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--case", default="wave_gameplay_2048_follow")
    parser.add_argument("--host-state", required=True, choices=("quiet", "contended-development"))
    args = parser.parse_args()
    reference, driver, engine, output = (p.resolve() for p in
        (args.reference_directory, args.driver_source, args.engine, args.output))
    require(not output.exists(), "Preserve an existing probe attempt")
    summary = json.loads((reference / "SUMMARY.json").read_bytes())
    require(summary["complete"] and not summary["failures"], "Reference comparison is incomplete")
    require(sha(engine) == summary["engine_sha256"], "Probe engine differs from exact reference")
    for relative, expected in summary["driver"]["files_sha256"].items():
        require(sha(driver / relative) == expected, "Reference measurement driver differs: " + relative)
    require(subprocess.check_output(["git", "-C", str(driver), "rev-parse", "HEAD"], text=True).strip()
            == summary["driver"]["source_commit"], "Driver checkout differs from retained source")
    sys.path.insert(0, str(driver / "tools/pubpres_final"))
    from run_comparison import (copy_project, execute_with_resources, validate_requested_capture,
                                reduce_receipt, validate_observers, validate_sample_idle)
    from results import distribution
    template = reference / "template-C/project"
    custody = json.loads((reference / "template-C/source-custody.json").read_bytes())
    for relative, expected in custody["imported_files_sha256"].items():
        require(sha(template / relative) == expected, "Retained imported source differs: " + relative)
    original_arm = json.loads((reference / args.case / "0-C-slots2/arm.json").read_bytes())
    original = json.loads((reference / args.case / "0-C-slots2/receipt.json").read_bytes())
    campaign = copy.deepcopy(json.loads((reference / "campaign.json").read_bytes()))
    campaign["arms"]["C"].update(wave_column_tiles=False, wave_column_probe=True)
    output.mkdir(parents=True)
    project = output / "project"
    copy_project(template, project, imported=True)
    folder = output / "capture"
    folder.mkdir()
    receipt = folder / "receipt.json"
    settings = copy.deepcopy(original_arm["selectors"])
    settings["CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE"] = "1"
    settings["CYBERSAND_SHADER_NONCE"] = uuid.uuid4().hex
    arguments = copy.deepcopy(original_arm["arguments"])
    arguments[arguments.index("--path") + 1] = str(project)
    arguments[arguments.index("--log-file") + 1] = str(folder / "godot.log")
    arguments = ["--receipt=" + str(receipt) if a.startswith("--receipt=") else a for a in arguments]
    report = {"schema": "pubpres-recovery-native-stage-probe-v1", "complete": False,
              "failures": [], "application": original_arm["source"], "engine_sha256": sha(engine),
              "probe_driver_sha256": sha(__file__), "reference_summary_sha256": sha(reference / "SUMMARY.json"),
              "host_state": args.host_state, "selectors": settings, "arguments": arguments,
              "environment": {key: os.environ.get(key) for key in ("DISPLAY", "DBUS_SESSION_BUS_ADDRESS")},
              "scope": "Existing cumulative native stage readback only; no simulation/worker/render treatment. "
                       "All original frozenV3 physical gates remain required. Stage brackets measure elapsed wall time, "
                       "including waits/descheduling. The remainder is native tick elapsed outside sequential Wave "
                       "brackets, not proven non-Water CPU. No native start, GPU, scanout or owner acceptance claim."}
    write(output / "registration.json", report)
    write(output / "campaign.json", campaign)
    try:
        source = original_arm["source"]["source_commit"]
        process = execute_with_resources(engine, arguments, folder, source, settings, 420)
        data = json.loads(receipt.read_bytes())
        validate_requested_capture(data, original_arm["scenario"], campaign, source,
                                   settings["CYBERSAND_SHADER_NONCE"], "opengl3")
        analysis = reduce_receipt(receipt, campaign, project=project, engine=engine, arm_letter="C")
        observers = validate_observers(receipt, process, project, True)
        validate_sample_idle(data, False)
        require(data["fixture"] == original["fixture"], "Native probe changed authored workload identity")
        reference_analysis = json.loads((reference / args.case / "0-C-slots2/analysis.json").read_bytes())
        for key in ("first_144_body_trajectory_sha256", "first_144_admitted_moves_sha256"):
            require(analysis[key] == reference_analysis[key], "Probe changed exact physical work: " + key)
        rows = [json.loads(line) for line in receipt.with_name("receipt-events.jsonl").read_text().splitlines()]
        stages = joined_stages(data, rows)
        require(len(stages) >= 144, "Probe did not observe registered physical work")
        selected = stages[:144]
        report.update(complete=True, process=process, analysis=analysis, observers=observers, stages=stages,
                      first_144_stage_ms={key: distribution(r["stages_ns"][key] / 1e6 for r in selected) for key in STAGES},
                      first_144_native_outside_wave_ms=distribution(r["native_outside_wave_stage_brackets_ms"] for r in selected),
                      first_144_native_tick_ms=distribution(r["native_tick_ms"] for r in selected))
    except Exception as error:
        report["failures"].append(str(error))
    write(output / "RESULT.json", report)
    print(json.dumps({"complete": report["complete"], "failures": report["failures"], "output": str(output)}), flush=True)
    return int(not report["complete"])


if __name__ == "__main__":
    raise SystemExit(main())
