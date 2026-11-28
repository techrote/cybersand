#!/usr/bin/env python3
"""Offline stdlib reducer for the identical source-gameplay observation overlay.

Windows users run Run-Source-Comparison.ps1, which does not require Python.
This companion reduces Linux/raw developer captures with the same window and
quantile definitions. It never interprets capture completion as acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


def need(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def distribution(values):
    values = sorted(float(x) for x in values if x is not None)
    if not values:
        return None
    need(all(math.isfinite(x) for x in values), "Nonfinite timing observation")
    result = {"count": len(values), "max": values[-1]}
    for q in (50, 95, 99):
        position = (len(values) - 1) * q / 100
        lo, hi = math.floor(position), math.ceil(position)
        result[f"p{q}"] = values[lo] + (values[hi] - values[lo]) * (position - lo)
    return result


def gaps(rows, clock="time_usec"):
    return [(b[clock] - a[clock]) / 1000 for a, b in zip(rows, rows[1:])]


def check_water_ledger(state, label):
    need(state.get("water_ledger_healthy") and state.get("water_ledger"), f"{label} native Water ledger unavailable or unhealthy")
    water = state["water_ledger"]
    need(water["total"] == water["expected"] == water["visible"] + water["overfill"] + water["ballistic"], f"{label} grid/ballistic Water differs from native source/sink ledger")


def expected_material(data, arm):
    expected = {"backend": arm.get("backend", arm["material"]), "policy": ""}
    for rule in arm.get("material_policy_overrides", []):
        need(arm["reference"] == "candidate", "Only the current candidate may select its registered renderer policy")
        if data.get("platform") == rule["platform"] and data["renderer"] == rule["driver"] and all(part in data["adapter"].lower() for part in rule["adapter_contains"]):
            expected = {"backend": rule["backend"], "policy": rule["policy"]}
    return expected


def check_material_status(status, arm, expected):
    need(status is not None and status["requested_mode"] == arm["material"] and status["backend"] == expected["backend"] and status.get("policy", "") == expected["policy"] and not status.get("fallback_reason", ""), "Material backend/policy differs from registered source and adapter treatment")


def window(events, data, end):
    start = data["capture_start_usec"]
    rows = [r for r in events if start <= r["time_usec"] <= end]

    def select(kind, key="time_usec"):
        return sorted((r for r in rows if r["event"] == kind), key=lambda r: r[key])

    main = select("main_callback", "start_usec")
    draws = select("framebuffer_draw")
    steps = select("rapier_step", "step")
    native = select("native_completion_observed", "tick_index")
    uploads = select("texture_upload")
    worker = select("worker_snapshot")
    physics = select("physics_callback")
    seconds = (end - start) / 1e6
    need(seconds > 0 and min(len(main), len(steps), len(native)) > 1, "Insufficient actual progression in window")
    native_by_tick = {r["tick_index"]: r for r in events if r["event"] == "native_completion_observed"}
    # Repeated status publications of one immutable completion must not reset
    # its queue age. Join the FIRST eligible packet to the actual consumed
    # native tick/sample/terrain identity. The original source has no exact
    # physics-mailbox clock, so retain a separate observation-bound metric.
    first_ready, first_handoff = {}, {}
    for row in events:
        if row["event"] != "worker_snapshot" or row["failed"] or row["hard_surface_revision"] != row["required_hard_revision"]:
            continue
        key = (row["world_generation"], row["tick_index"], row["completed_body_sample"], row["required_hard_revision"])
        first_ready[key] = min(first_ready.get(key, row["time_usec"]), row["time_usec"])
        stamp = row.get("physics_handoff_usec")
        if stamp is not None and stamp > 0:
            first_handoff[key] = min(first_handoff.get(key, stamp), stamp)
    first_ready_ages, first_handoff_ages, first_native_handoff = [], [], []
    for row in steps:
        observed = native_by_tick.get(row["native_tick_used"])
        if observed is None:
            continue
        key = (observed["world_generation"], row["native_tick_used"], row["completed_body_sample"], row["required_hard_revision"])
        if key in first_ready and first_ready[key] <= row["time_usec"]:
            first_ready_ages.append((row["time_usec"] - first_ready[key]) / 1000)
        if key in first_handoff and first_handoff[key] <= row["time_usec"]:
            first_handoff_ages.append((row["time_usec"] - first_handoff[key]) / 1000)
            if (row.get("native_completed_usec") or 0) > 0:
                first_native_handoff.append((first_handoff[key] - row["native_completed_usec"]) / 1000)
    unique_ticks, packets = {}, {}
    for row in worker:
        unique_ticks.setdefault(row["tick_index"], row)
        packets.setdefault(row["render_serial"], row)
    tick_rows = [r for tick, r in unique_ticks.items() if tick in native_by_tick and start <= native_by_tick[tick]["time_usec"] <= end]
    exact = sorted((r for r in tick_rows if r.get("native_completed_usec") and r["native_completed_usec"] >= start), key=lambda r: r["native_completed_usec"])
    submission = [r["material"] for r in uploads if r.get("material") is not None]
    modes = {}
    for row in submission:
        mode = row.get("mode", row.get("backend", "unknown"))
        modes[mode] = modes.get(mode, 0) + 1
    postdraw = []
    for upload in uploads:
        draw = next((r for r in draws if r["time_usec"] >= upload["time_usec"] and r["render_serial"] >= upload["render_serial"]), None)
        if draw:
            postdraw.append((draw["time_usec"] - upload["time_usec"]) / 1000)
    frame_gaps = gaps(main, "start_usec")
    worst = sorted(({"from_process_frame": a["process_frame"], "to_process_frame": b["process_frame"], "start_usec": a["start_usec"], "gap_ms": gap}
                    for a, b, gap in zip(main, main[1:], frame_gaps)), key=lambda r: r["gap_ms"], reverse=True)[:12]

    def elapsed(values):
        return distribution((r["time_usec"] - r["start_usec"]) / 1000 for r in values)

    result = {
        "start_usec": start, "end_usec": end, "duration_seconds": seconds,
        "completed_native_ticks": len(native), "completed_rapier_steps": len(steps),
        "completed_rapier_simulation_seconds": sum(r["fixed_delta"] for r in steps),
        "physical_simulation_seconds_per_wall_second": sum(r["fixed_delta"] for r in steps) / seconds,
        "first_step": steps[0]["step"], "last_step": steps[-1]["step"],
        "native_ticks_per_second": len(native) / seconds, "rapier_steps_per_second": len(steps) / seconds,
        "frame_ms": distribution(frame_gaps), "consecutive_two_frame_ms": distribution((b["start_usec"] - a["start_usec"]) / 1000 for a, b in zip(main, main[2:])),
        "worst_frame_intervals": worst, "post_draw_callback_gap_ms": distribution(gaps(draws)),
        "native_observed_gap_ms": distribution(gaps(native)), "native_exact_gap_ms": distribution(gaps(exact, "native_completed_usec")),
        "physical_gap_ms": distribution(gaps(steps)), "native_tick_ms": distribution(r["native_tick_ms"] for r in tick_rows),
        "main_callback_ms": elapsed(main), "worker_publication_ms": elapsed(worker),
        "snapshot_copy_ms": distribution(r["copy_ms"] for r in worker), "snapshot_publication_ms": distribution(r["publication_ms"] for r in worker),
        "rapier_solver_ms": distribution(r["solver_usec"] / 1000 for r in steps), "rapier_callback_to_completion_ms": elapsed(steps),
        "rapier_observer_ms": distribution(r.get("observer_usec", 0) / 1000 for r in steps),
        "native_observed_to_rapier_ms": distribution((r["time_usec"] - native_by_tick[r["native_tick_used"]]["time_usec"]) / 1000 for r in steps if r["native_tick_used"] in native_by_tick),
        "native_exact_to_rapier_ms": distribution((r["time_usec"] - r["native_completed_usec"]) / 1000 for r in steps if (r.get("native_completed_usec") or 0) > 0),
        "native_exact_to_physics_handoff_ms": distribution((r["physics_handoff_usec"] - r["native_completed_usec"]) / 1000 for r in steps if (r.get("native_completed_usec") or 0) > 0 and (r.get("physics_handoff_usec") or 0) > 0),
        "physics_handoff_to_rapier_ms": distribution((r["time_usec"] - r["physics_handoff_usec"]) / 1000 for r in steps if (r.get("physics_handoff_usec") or 0) > 0),
        "first_observed_eligible_snapshot_to_rapier_ms": distribution(first_ready_ages),
        "first_physics_handoff_to_rapier_ms": distribution(first_handoff_ages),
        "native_exact_to_first_physics_handoff_ms": distribution(first_native_handoff),
        "first_ready_scope": "First healthy matching world/native-tick/body-sample/terrain packet. Observation clock is full snapshot hook exit (queue lower bound); exact physics handoff remains unavailable on accepted main. Latest handoff metrics above remain separately reported.",
        "snapshot_generated_to_upload_ms": distribution((r["time_usec"] - r["generated_usec"]) / 1000 for r in uploads if r["generated_usec"] > 0),
        "material_age_at_main_end_ms": distribution((r["time_usec"] - r["uploaded_generated_usec"]) / 1000 for r in main if r.get("uploaded_generated_usec", 0) > 0),
        "material_submission_ms": elapsed(uploads), "upload_to_post_draw_callback_ms": distribution(postdraw),
        "submission_stages_usec": {key: distribution(r.get(key) for r in submission) for key in ("image_patch_usec", "content_cache_usec", "atlas_assembly_usec", "backend_submit_usec", "staging_upload_usec", "gpu_blit_submit_usec", "direct_upload_usec", "whole_storage_create_usec", "whole_storage_replace_usec", "initialization_usec")},
        "publication": {
            "accepted_uploads": len(uploads), "uploads_per_second": len(uploads) / seconds,
            "native_full_inputs": sum(bool(r["full_refresh"]) for r in uploads), "native_sparse_inputs": sum(not r["full_refresh"] for r in uploads),
            "input_payload_bytes": sum(r["patch_bytes"] for r in uploads), "input_patch_count": sum(r["patch_count"] for r in uploads),
            "unique_worker_render_serials": len(packets), "submission_modes": modes,
            "cpu_staging_submitted_bytes": sum(r.get("submitted_bytes", 0) for r in submission) if len(submission) == len(uploads) else None,
            "staging_residency_bytes": distribution(r.get("allocated_gpu_bytes") for r in submission),
            "dropped_publications": None, "expired_publications": None, "refused_publications": None,
            "unavailable_reason": "The common legacy seam cannot distinguish publication refusal/expiration from no-op consumption; original integrated diagnostics retain finer counters.",
            "byte_scope": "Input RG8 packet bytes and CPU staging upload bytes are distinct. Neither measures GPU bandwidth.",
        },
        "physical_callbacks_without_step": sum(r["before_step"] == r["after_step"] for r in physics),
        "physical_callbacks_with_pending_terrain": sum(r["pending_hard_chunks"] > 0 for r in physics),
        "contacts_observed": sum(b["contacts"] > 0 for r in steps for b in r["bodies"]),
    }
    refusals = {}
    for row in steps:
        if row["response_refusal"]:
            reason = row["response_refusal"]
            refusals[reason] = refusals.get(reason, 0) + 1
    result["response_refusals"] = [{"reason": k, "count": v} for k, v in refusals.items()]
    return result


def reduce_receipt(path, campaign, project=None, engine=None, arm_letter=None):
    path = Path(path)
    data = json.loads(path.read_text())
    need(data["schema"] == "pubpres-source-gameplay-v1" and data["complete"] and not data["failures"], "Incomplete gameplay receipt")
    need(data["gpu_history"]["current_matches_cpu"] and not data["gpu_history"]["previous_verified"], "GPU parity/history scope differs")
    need(data["display"]["server"] != "headless" and data["display"]["window"] == [1600, 900] and data["display"]["fps_cap"] == 60 and data["display"]["physics_callbacks_hz"] == 60 and data["display"]["vsync_mode"] == 0, "Registered graphical/VSync condition differs")
    for relative, expected in campaign["overlay_sha256"].items():
        need(data["source_identity"]["files"]["res://" + relative] == expected, f"Overlay hash differs: {relative}")
    if project:
        for resource, expected in data["source_identity"]["files"].items():
            local = Path(project) / resource.removeprefix("res://")
            need((digest(local) if local.is_file() else None) == expected, f"Project source/runtime changed: {resource}")
    if engine:
        need(digest(engine) == data["source_identity"]["engine_sha256"], "Pinned engine changed")
    fixture = campaign["fixtures"][data["fixture"]["name"]]
    for key in ("setup_sha256", "json_sha256", "generated_sha256", "receipts"):
        if key in fixture:
            need(data["fixture"].get(key) == fixture[key], f"Registered fixture {key} differs")
    need(hashlib.sha256(canonical(data["input_tape"]).encode()).hexdigest() == campaign["measurement"]["input_tape_sha256"], "Registered tape changed")
    need(len(data["input_events"]) == len(data["input_tape"]) == 11, "Input tape incomplete")
    for index, (actual, expected) in enumerate(zip(data["input_events"], data["input_tape"])):
        need(actual["input_index"] == index and actual["requested_physical_tick"] == actual["accepted_physical_tick"] == expected["tick"] and actual["move"] == expected["move"], "Input was not admitted at exact real step")
    letter = arm_letter or ("M" if data["source_identity"]["source_sha"] == campaign["source_commits"]["main"] else "I" if data["source_identity"]["source_sha"] == campaign["source_commits"]["integration"] else "C")
    arm = campaign["arms"][letter]
    material_expected = expected_material(data, arm)
    for selectors in (data["selectors_before"], data["selectors_after"]):
        for key, field in (("CYBERSAND_MATERIAL_PUBLICATION", "material"), ("CYBERSAND_DIAG_PHYSICS_PUBLICATION", "physics"), ("CYBERSAND_DIAG_PRESENTATION", "presentation"), ("CYBERSAND_DIAG_MATERIAL_TIMING", "timing")):
            need(selectors["requested"][key] == arm[field], f"Requested selector differs: {key}")
        if letter == "M":
            need(all(selectors[k] is None for k in ("material", "physics", "presentation")), "Accepted main acquired integrated diagnostic behavior")
        else:
            check_material_status(selectors["material"], arm, material_expected)
            need(selectors["physics"] == arm["physics"] and selectors["presentation"] == arm["presentation"] and selectors["material_timing"] not in (None, "legacy_requested") and selectors["cadence"] == arm["cadence"] and selectors["rendezvous"]["mode"] == "off", "Requested integration treatment did not reach runtime")
    trace = path.with_name(path.stem + "-events.jsonl")
    need(digest(trace) == data["trace_sha256"], "Original event trace changed")
    rows = [json.loads(line) for line in trace.read_text().splitlines()]
    need(rows[0]["event"] == "identity" and rows[0]["source"] == data["source_identity"], "Trace/receipt identity differs")
    events = rows[1:]
    for upload in (r for r in events if r["event"] == "texture_upload"):
        if letter == "M":
            need(upload.get("material") is None, "Accepted main acquired integrated material telemetry")
        else:
            check_material_status(upload.get("material"), arm, material_expected)
    steps = sorted((r for r in events if r["event"] == "rapier_step"), key=lambda r: r["step"])
    native = sorted((r for r in events if r["event"] == "native_completion_observed"), key=lambda r: r["tick_index"])
    need(len(steps) >= 144 and len(native) > 1 and steps[0]["step"] == data["capture_physical_tick_start"] + 1, "Missing actual progression")
    need(all(abs(r["fixed_delta"] - 1 / 60) <= 1e-12 for r in steps), "Rapier fixed simulation timestep changed")
    need(all(b["step"] == a["step"] + 1 and b["manual_steps"] == a["manual_steps"] + 1 and b["time_usec"] >= a["time_usec"] for a, b in zip(steps, steps[1:])), "Missing or reordered physical completion")
    need(all(b["tick_index"] == a["tick_index"] + 1 and b["time_usec"] >= a["time_usec"] for a, b in zip(native, native[1:])), "Missing native completion observation")
    need(len({r["world_generation"] for r in native}) == 1 and len({(r["session"], r["epoch"]) for r in steps}) == 1, "World or physical owner changed during registered capture")
    participation = [r["sample"] for r in events if r["event"] == "worker_participation"]
    need(any(r["workers_observed"] > 0 and r["worker_capacity"] > 0 for r in participation), "No actual native worker participation")
    need(all(r["worker_capacity"] == data["workers"] for r in participation), "Native worker capacity did not equal the registered request")
    need(len(data["framebuffers"]) == 2, "Missing original framebuffers")
    for image in data["framebuffers"]:
        need(image["outside_timing"] and digest(path.with_name(path.stem + "-" + image["label"] + ".png")) == image["sha256"], "Framebuffer evidence changed")
    before, after = data["water_before"], data["water_after"]
    check_water_ledger(before, "Initial")
    check_water_ledger(after, "Final")
    quantities = []
    for row in sorted((r for r in events if r["event"] == "worker_snapshot"), key=lambda r: r["time_usec"]):
        check_water_ledger(row, "Published")
        quantity = {"tick_index": row["tick_index"], "completed_body_sample": row["completed_body_sample"], "world_generation": row["world_generation"], "water": row["water_ledger"]}
        if not quantities or quantities[-1] != quantity:
            quantities.append(quantity)
    if data["water_law"] == "wave_flow_v1":
        a, b = before["wave_flow"], after["wave_flow"]
        need(a["enabled"] and b["enabled"] and b["healthy"] and a["session_generation"] == b["session_generation"], "Wave source or health differs")
        if data["fixture"]["name"] == "landscape2048x1024":
            need(a["water_quantity"] == b["water_quantity"], "Closed landscape Water quantity changed")
        need(b["ticks"] > a["ticks"] and b["rounds"] - a["rounds"] == (b["ticks"] - a["ticks"]) * b["substeps"], "Wave did not complete real rounds")
        need(before["construction"]["receipt_hash"] == after["construction"]["receipt_hash"] and after["policy"]["effective_water_solver"] == "wave_flow_v1", "Wave construction or policy changed")
    need(data["capture_end_usec"] >= data["capture_start_usec"] + 10000000, "Ten-second window shortened")
    return {
        "process_id": data["process_id"], "source": data["source_identity"]["source_sha"], "trace_sha256": data["trace_sha256"],
        "match": {"engine": data["source_identity"]["engine_sha256"], "platform": data.get("platform"), "renderer": data["renderer"], "adapter": data["adapter"], "cpu": data["cpu"],
                  "logical_processors": data["logical_processors"], "display": data["display"], "fixture": data["fixture"], "tape": data["input_tape"],
                  "workers_requested": data["workers"], "worker_capacities": sorted({r["worker_capacity"] for r in participation}),
                  "water_policy_hash": before["policy"]["policy_hash"], "wave_parameters": before["wave_flow"].get("parameters"),
                  "initial_body_state_sha256": before["construction"]["initial_body_state_sha256"], "prepared_payload_hash": before["construction"]["prepared_payload_hash"],
                  "prepared_setup_hash": before["construction"]["prepared_setup_hash"]},
        "windows": {"first_10s": window(events, data, data["capture_start_usec"] + 10000000), "first_144_steps": window(events, data, steps[143]["time_usec"]), "whole_capture": window(events, data, data["capture_end_usec"])},
        "actual_worker_participation": participation,
        "memory": {"godot_static_peak_bytes": data["static_memory_peak_bytes"], "reported_video_final_bytes": data["video_memory_bytes"]},
        "water_quantity_before": before["wave_flow"].get("water_quantity"), "water_quantity_after": after["wave_flow"].get("water_quantity"),
        "water_ledger_before": before["water_ledger"], "water_ledger_after": after["water_ledger"], "water_by_native_tick": quantities,
        "selectors_before": data["selectors_before"], "selectors_after": data["selectors_after"], "gpu_history": data["gpu_history"],
        "registered_material_treatment": material_expected,
        "first_144_body_trajectory_sha256": hashlib.sha256(canonical([r["bodies"] for r in steps[:144]]).encode()).hexdigest(),
        "observation_limits": campaign["measurement"]["limits"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--campaign", type=Path, default=Path(__file__).with_name("source_campaign.json"))
    parser.add_argument("--project", type=Path)
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--arm", choices=("M", "I", "C"))
    args = parser.parse_args()
    campaign = json.loads(args.campaign.read_text())
    need(campaign["schema"] == "pubpres-source-campaign-v1", "Unknown source campaign")
    result = reduce_receipt(args.receipt, campaign, args.project, args.engine, args.arm)
    output = args.output or args.receipt.with_name("analysis.json")
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"analysis": str(output), "source": result["source"], "physical_acceptance": "HOLD", "frame_ms_first_144": result["windows"]["first_144_steps"]["frame_ms"], "physical_gap_ms_first_144": result["windows"]["first_144_steps"]["physical_gap_ms"]}))


if __name__ == "__main__":
    main()
