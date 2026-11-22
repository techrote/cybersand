#!/usr/bin/env python3
"""Native-phase diagnosis under headless Godot, never graphical acceptance."""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

from run_focus import (ROOT, ENGINE_SHA256, FROZEN_REGISTRATION, selectors, source_identity,
                       stage_committed_project, validate_runtime, verify_driver, write_json)
from run_campaign import execute
from results import canonical, check_water_ledger, digest, gameplay_parameters, need, vector
from results_same_frame import reduce_receipt, validate_continuations, window


def native_oracles(data, events, campaign):
    """Explicit native-only checks; the original graphical refusal is retained."""
    validate_native_workload(data, campaign)
    need(data["display"]["server"] == "headless", "Native-only diagnostic requires explicit headless identity")
    need(data["complete"] and not data["failures"], "Native diagnostic script failed")
    credit = validate_continuations(data, campaign, events, "C")
    steps = sorted((r for r in events if r["event"] == "rapier_step"), key=lambda r: r["step"])
    need(len(steps) >= 144, "Fewer than 144 genuine completed steps")
    roster = data["actor_roster_before"]
    expected = campaign["measurement"]["required_actor"]
    need(len(roster) == 1 and roster == data["actor_roster_after"]
         and all(roster[0][key] == expected[key] for key in ("actor_slot", "instance_id", "model", "producer"))
         and len(roster[0]["bodies"]) == expected["body_count"] == 1, "Real Needle ownership differs")
    body = roster[0]["bodies"][0]
    need(body["body_rid"] == body["bridge_rid"] and body["node_class"] == "RigidBody2D", "Rapier body ownership differs")
    owner = {(r["world_generation"], r["session"], r["epoch"]) for r in steps}
    need(len(owner) == 1 and all(v > 0 for v in next(iter(owner))), "Physical owner changed")
    native = {(r["world_generation"], r["tick_index"]): r for r in events if r["event"] == "native_completion_observed"}
    commands = [r for r in events if r["event"] == "command_attempt"]
    need(len(commands) == data["command_counts"]["attempted"] == data["command_counts"]["accepted"]
         and data["command_counts"]["rejected"] == 0, "Command accounting differs")
    need(all(r["accepted"] and r["sequence_after"] == r["sequence_before"] + 1
             and r["deadline_tick"] == r["absolute_tick"] + 6 for r in commands), "Ordinary command lease changed")
    for index, step in enumerate(steps):
        need(abs(step["fixed_delta"] - 1 / 60) < 1e-12 and not step["packet_failed"] and not step["response_refusal"],
             "Physical step used failed native state or another timestep")
        need(step["pending_hard_chunks"] == 0 and step["required_hard_revision"] == step["packet_hard_revision"] == step["installed_hard_revision"],
             "Physical step used incomplete native terrain")
        need(step["body_ownership"] == [{"slot": 0, "body_rid": body["body_rid"]}]
             and len(step["bodies"]) == 1 and vector(step["bodies"][0]["xy"]) and vector(step["bodies"][0]["velocity"]),
             "Physical step lacks its real finite body")
        bootstrap = index == 0 and step["native_tick_used"] == data["capture_native_tick_start"] and step["completed_body_sample"] == -1
        if not bootstrap:
            completion = native.get((step["world_generation"], step["native_tick_used"]))
            need(step["response_accepted"] and step["accepted_samples"] == [step["completed_body_sample"]]
                 and completion and completion["body_sample"] == step["completed_body_sample"]
                 and completion["time_usec"] <= step["time_usec"], "Physical step has no matching accepted native response")
            need(step["native_completion_world_generation"] == step["world_generation"]
                 and step["native_completion_body_sample"] == step["completed_body_sample"], "Native clock owner differs")
        matches = [r for r in commands if r["absolute_tick"] == step["step"] - 1 and r["time_usec"] <= step["time_usec"]]
        need(matches, "Completed step lacks an admitted input")
        command = max(matches, key=lambda r: r["time_usec"])
        need(step["command_sequence"] == command["sequence_after"] and step["admitted_move"] == command["accepted_move"]
             and step["command_deadline_tick"] == command["deadline_tick"], "Physical step consumed another input/lease")
        if index:
            before = steps[index - 1]
            need(step["step"] == before["step"] + 1 and step["manual_steps"] == before["manual_steps"] + 1
                 and step["native_tick_used"] == before["native_tick_used"] + 1
                 and step["completed_body_sample"] > before["completed_body_sample"], "Duplicated or skipped physical/native credit")
    for row in [data["water_before"], data["water_after"], *[r for r in events if r["event"] == "worker_snapshot"]]:
        check_water_ledger(row, "Native-only diagnostic")
    for state in (data["water_before"]["wave_flow"], data["water_after"]["wave_flow"]):
        need(state["enabled"] and state["healthy"] and state["substeps"] == 2 and state["spill"]["enabled"]
             and state["spill"]["parcels"] and state["construction_options"]["workbench_ballistic"], "Current gameplay mechanics changed")
        need(all(state["parameters"].get(key) == value for key, value in gameplay_parameters().items()),
             "Current gameplay Wave parameters changed")
        spill = {"sheet_rate": 64, "coyote_ticks": 4, "full_face": True, "fall": 3,
                 "draw": 127, "draw_head": 255, "deep_draw": 64, "launch_budget": 128}
        need(all(state["spill"].get(key) == value for key, value in spill.items()), "Current gameplay spill parameters changed")
    before, after = data["water_before"], data["water_after"]
    a, b = before["wave_flow"], after["wave_flow"]
    need(a["session_generation"] == b["session_generation"] and b["ticks"] > a["ticks"]
         and b["rounds"] - a["rounds"] == 2 * (b["ticks"] - a["ticks"])
         and before["construction"]["receipt_hash"] == after["construction"]["receipt_hash"]
         and after["policy"]["effective_water_solver"] == "wave_flow_v1", "Native Wave source/rounds/policy changed")
    workers = [r["sample"] for r in events if r["event"] == "worker_participation"]
    need(workers and all(r["worker_capacity"] == 4 for r in workers) and max(r["workers_observed"] for r in workers) == 4,
         "Four native workers did not actually participate")
    return {"status": "PASS", "scope": "Explicit native/body/terrain/Water/input/callback checks; no framebuffer claim",
            "callback_credit": credit, "workers_observed": sorted({r["workers_observed"] for r in workers}),
            "first_144_body_trajectory_sha256": hashlib.sha256(canonical([r["bodies"] for r in steps[:144]]).encode()).hexdigest(),
            "first_144_admitted_moves_sha256": hashlib.sha256(canonical([r["admitted_move"] for r in steps[:144]]).encode()).hexdigest()}


def validate_native_workload(data, campaign):
    """Bind native diagnosis to its one declared active 2048² workload."""
    expected = {"camera": "follow", "workers": 4, "water_law": "wave_flow_v1",
                "water_profile": "gameplay_main846f", "water_variant": "reference", "input_mode": "tape",
                "command_mode": "repeated_callback", "observer_mode": "full",
                "render_thread": {"requested": "safe", "runtime": "safe"}}
    need(data["fixture"]["name"] == "reference2048", "Native diagnostic requested fixture differs")
    for key in ("json_sha256", "generated_sha256", "receipts"):
        need(data["fixture"][key] == campaign["fixtures"]["reference2048"][key], "Native diagnostic fixture identity differs: " + key)
    for key, wanted in expected.items():
        need(data[key] == wanted, "Native diagnostic requested apparatus differs: " + key)
    for relative, wanted in campaign["overlay_sha256"].items():
        need(data["source_identity"]["files"]["res://" + relative] == wanted,
             "Native diagnostic frozen observer differs: " + relative)
    need(data["input_tape"] == campaign["measurement"]["input_tape"], "Native diagnostic registered input tape differs")
    need(len(data["input_events"]) == len(data["input_tape"]) == 11, "Native diagnostic input tape incomplete")
    for index, (actual, wanted) in enumerate(zip(data["input_events"], data["input_tape"])):
        need(actual["input_index"] == index and actual["requested_physical_tick"] == actual["accepted_physical_tick"] == wanted["tick"]
             and actual["move"] == wanted["move"], "Native diagnostic input was not admitted at its declared step")
    requested = selectors({"same_frame_continuation": False, "wave_column_probe": True, "causal": False}, "unused")
    requested = {key: requested[key] for key in (
        "CYBERSAND_MATERIAL_PUBLICATION", "CYBERSAND_DIAG_PHYSICS_PUBLICATION", "CYBERSAND_DIAG_PRESENTATION",
        "CYBERSAND_DIAG_MATERIAL_TIMING", "CYBERSAND_DIAG_NATIVE_RENDEZVOUS", "CYBERSAND_DIAG_RENDER_CADENCE",
        "CYBERSAND_DIAG_MATERIAL_POOL_POLICY", "CYBERSAND_DIAG_SAME_FRAME_CONTINUATION",
        "CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES", "CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE")}
    for state in (data["selectors_before"], data["selectors_after"]):
        need(state["requested"] == requested, "Native diagnostic selector differs")
        need(state["physics"] == "early" and state["presentation"] == "coherent" and state["cadence"] == "repaired"
             and state["rendezvous"]["mode"] == "off", "Native diagnostic runtime treatment differs")
        need(state["wave_column_probe"]["schema"] == "PUBPRES-WAVE-COLUMNS-V1"
             and state["wave_column_probe"]["experimental_column_tiles"] is False, "Native diagnostic column treatment differs")


def analyze_native(path):
    data = json.loads(path.read_text())
    trace = path.with_name("receipt-events.jsonl")
    need(digest(trace) == data["trace_sha256"], "Native diagnostic trace changed")
    rows = [json.loads(s) for s in trace.read_text().splitlines()]
    need(rows[0]["source"] == data["source_identity"], "Native diagnostic source differs")
    events = rows[1:]
    campaign_path = ROOT / "tools/pubpres_playability/campaign.json"
    need(digest(campaign_path) == FROZEN_REGISTRATION, "Frozen predecessor registration changed")
    campaign = json.loads(campaign_path.read_text())
    campaign["arms"]["C"].update(same_frame_continuation=False, wave_column_probe=True)
    checks = native_oracles(data, events, campaign)
    try:
        reduce_receipt(path, campaign, arm_letter="C")
        graphical = {"status": "UNEXPECTED_PASS"}
    except (ValueError, KeyError) as error:
        graphical = {"status": "REFUSED", "reason": str(error)}
    need(graphical["status"] == "REFUSED", "Headless capture must never pass graphical qualification")
    steps = sorted((r for r in events if r["event"] == "rapier_step"), key=lambda r: r["step"])
    windows = {label: window(events, data, end) for label, end in (
        ("first_10s", data["capture_start_usec"] + 10_000_000),
        ("first_144_steps", steps[143]["time_usec"]), ("whole_capture", data["capture_end_usec"]))}
    phase = {}
    for label, stats in windows.items():
        counters = stats["wave_column_stage_counter_deltas"]
        need(counters and counters["ticks"] > 0, "No genuine native stage counter progression")
        phase[label] = {**counters, "per_tick_ms": {key: counters[key] / counters["ticks"] / 1e6
                       for key in ("prepare_ns", "column_ns", "flux_ns", "apply_ns", "merge_ns", "launch_ns")}}
    return {"schema": "pubpres003-headless-native-analysis-v1", "physical_acceptance": "HOLD",
            "scope": "Native-phase diagnostic only. Headless progression is not graphical playability evidence.",
            "source": data["source_identity"], "receipt_sha256": digest(path), "trace_sha256": digest(trace),
            "fixture": data["fixture"], "water_profile": data["water_profile"], "requested_water_options": data["requested_water_options"],
            "display": data["display"], "cpu": data["cpu"], "native_oracles": checks,
            "original_graphical_validation": graphical, "phases": phase, "windows": windows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analyze", type=Path, help="Reduce a retained native-only diagnostic without replay")
    for name in ("source", "runtime", "engine", "rapier-runtime", "output"):
        parser.add_argument("--" + name, type=Path)
    parser.add_argument("--allow-development-toolchain-drift", action="store_true")
    args = parser.parse_args()
    if args.analyze:
        print(json.dumps(analyze_native(args.analyze), indent=2))
        return 0
    driver_identity = verify_driver()
    need(all(getattr(args, k) for k in ("source", "runtime", "engine", "rapier_runtime", "output")), "Explicit source/runtime/engine/Rapier/output required")
    root, runtime, engine, output = (getattr(args, k).resolve() for k in ("source", "runtime", "engine", "output"))
    need(not output.exists(), "Retain original evidence; output must be new")
    source = source_identity(root)
    source["native_runtime"] = validate_runtime(root, source, runtime, args.allow_development_toolchain_drift)
    platform = "windows" if os.name == "nt" else "linux"
    need(digest(engine) == ENGINE_SHA256[platform], "Pinned engine hash differs")
    rapier_receipt = "godot/addons/godot-rapier2d/runtime-provenance." + platform + ".json"
    rapier = json.loads(subprocess.check_output(["git", "-C", str(root), "show", source["source_commit"] + ":" + rapier_receipt]))
    need(digest(args.rapier_runtime) == rapier["sha256"], "Rapier runtime differs")
    for relative, wanted in rapier.get("source_inputs", {}).items():
        need(hashlib.sha256(subprocess.check_output(["git", "-C", str(root), "show", source["source_commit"] + ":" + relative])).hexdigest()
             == wanted, "Rapier source closure differs: " + relative)
    output.mkdir(parents=True)
    project = stage_committed_project(root, source["source_commit"], output)
    shutil.copyfile(source["native_runtime"]["binary_path"], project / source["native_runtime"]["staged_relative_path"])
    shutil.copyfile(args.rapier_runtime, project / Path(rapier["artifact"]).relative_to("godot"))
    settings = selectors({"same_frame_continuation": False, "wave_column_probe": True, "causal": False}, uuid.uuid4().hex)
    settings["CYBERSAND_SHADER_CACHE_STATE"] = "headless-native-diagnostic-fresh-project-profile"
    receipt = output / "receipt.json"
    arguments = ["--headless", "--path", str(project), "--render-thread", "safe", "--audio-driver", "Dummy",
                 "--script", "res://tests/pubpres_same_frame_gameplay.gd", "--", "--receipt=" + str(receipt),
                 "--fixture=reference2048", "--camera=follow", "--workers=4", "--water-law=wave_flow_v1",
                 "--water-variant=reference", "--water-profile=gameplay_main846f", "--input-mode=tape",
                 "--command-mode=repeated_callback", "--observer-mode=full"]
    write_json(output / "request.json", {"schema": "pubpres003-headless-native-request-v1", "source": source,
               "engine_sha256": digest(engine), "rapier_sha256": digest(args.rapier_runtime), "arguments": arguments,
               "settings": settings, "runner_sha256": digest(__file__), "physical_acceptance": "HOLD"})
    request = json.loads((output / "request.json").read_text())
    request["measurement_driver"] = driver_identity
    write_json(output / "request.json", request)
    execute(engine, ["--headless", "--path", str(project), "--editor", "--import"], output / "import", source["source_commit"], {}, 300)
    execute(engine, arguments, output, source["source_commit"], settings, 420)
    data = json.loads(receipt.read_text())
    need(data["case_nonce"] == settings["CYBERSAND_SHADER_NONCE"], "Native diagnostic request nonce differs")
    need(data["source_identity"]["engine_sha256"] == digest(engine), "Executed native diagnostic engine differs")
    for relative, expected in data["source_identity"]["files"].items():
        local = project / relative.removeprefix("res://")
        need((digest(local) if local.is_file() else None) == expected, "Executed native diagnostic source/runtime differs: " + relative)
    analysis = analyze_native(receipt)
    need(analysis["source"]["source_sha"] == source["source_commit"], "Executed source differs")
    need(analysis["source"]["files"]["res://" + source["native_runtime"]["staged_relative_path"]]
         == source["native_runtime"]["binary_sha256"], "Executed native runtime differs")
    write_json(output / "native-phase-analysis.json", analysis)
    print(json.dumps({"output": str(output), "native_oracles": analysis["native_oracles"], "phases": analysis["phases"],
                      "graphical_validation": analysis["original_graphical_validation"], "physical_acceptance": "HOLD"}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
