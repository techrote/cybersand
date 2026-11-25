#!/usr/bin/env python3
"""Version 2 stdlib reducer for the frozen playability observation overlay.

The portable runner and this reader use the same window and quantile definitions
on Linux and Windows. It never interprets capture completion as acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import zlib


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


WAVE_CORE_PARAMETERS = {"active_rows":32,"gain":32,"gain_confined":4,"stiffness":256,"damp_shift":7,
    "coast":16,"level_shift":3,"sleep_after":30,"wake_peak":1,"rest_head":1,"stick":512,"calm":512,
    "calm_damp_shift":3,"maximum_mass":32000,"empty_pour_shift":2,"flow_share_shift":1,"adhesion_shift":1,
    "body_push":256,"body_push_by_mass":1}
SNAPSHOT_CAPABILITIES=("physics_world_generation","last_native_tick_completed_usec","physics_handoff_usec",
    "last_native_tick_world_generation","last_native_tick_body_sample")


def wave_match(state):
    value = state["wave_flow"]
    parameters = value.get("parameters",{})
    return {"core_parameters":{k:parameters.get(k) for k in WAVE_CORE_PARAMETERS},
            "substeps":value.get("substeps"),"spill_enabled":value.get("spill",{}).get("enabled"),
            "construction_options":value.get("construction_options"),"transport_configured":value.get("transport_configured")}


def gameplay_parameters():
    return {**WAVE_CORE_PARAMETERS,"deep_gain":32,"floor_gain":1024,"flux_smoothing":16,
            "coast":32,"damp_shift":16,"calm_damp_shift":8,"calm":128,"stick":128,"sleep_after":90}


def number(value):
    return isinstance(value,(int,float)) and not isinstance(value,bool) and math.isfinite(value)


def integer(value, minimum=0):
    return number(value) and value>=minimum and value==int(value)


def vector(value):
    return isinstance(value,list) and len(value)==2 and all(number(v) for v in value)


def check_framebuffer(path, metadata, dimensions):
    """Check actual PNG framing/dimensions, not a hash of arbitrary bytes."""
    raw=Path(path).read_bytes()
    need(len(raw)>=45 and raw[:8]==b"\x89PNG\r\n\x1a\n","Framebuffer is not a PNG")
    position=8;types=[];image_bytes=0
    while position<len(raw):
        need(position+12<=len(raw),"Truncated framebuffer PNG chunk")
        size=struct.unpack(">I",raw[position:position+4])[0]
        kind=raw[position+4:position+8];end=position+12+size
        need(end<=len(raw),"Truncated framebuffer PNG data")
        payload=raw[position+8:position+8+size]
        need((zlib.crc32(kind+payload)&0xffffffff)==struct.unpack(">I",raw[end-4:end])[0],"Framebuffer PNG CRC differs")
        if not types:
            need(kind==b"IHDR" and size==13,"Framebuffer PNG header missing")
            width,height=struct.unpack(">II",payload[:8])
            need([width,height]==dimensions==[metadata["width"],metadata["height"]],"Framebuffer dimensions differ")
        if kind==b"IDAT":image_bytes+=size
        types.append(kind);position=end
        if kind==b"IEND":
            need(size==0 and position==len(raw),"Framebuffer PNG has trailing or malformed data")
            break
    need(types[-1:]==[b"IEND"] and image_bytes>0,"Framebuffer PNG has no image data or ending")


def validate_measurement_trace(data, campaign, events):
    limits=campaign["measurement"]
    start,end=data["capture_start_usec"],data["capture_end_usec"]
    need(integer(start) and integer(end) and limits["minimum_capture_usec"]<=end-start<=limits["maximum_capture_usec"],"Capture duration outside registered 10-to-90-second bounds")
    for field,key in (("minimum_capture_usec","minimum_capture_usec"),("maximum_capture_usec","maximum_capture_usec"),
                      ("target_physical_steps","minimum_real_steps"),("setup_timeout_msec","setup_timeout_msec"),
                      ("maximum_events_per_owner","maximum_events_per_owner")):
        need(data.get(field)==limits[key],"Receipt measurement limit differs: "+field)
    expected=limits["required_actor"]
    roster=data.get("actor_roster_before")
    need(isinstance(roster,list) and len(roster)==1 and roster==data.get("actor_roster_after"),"Real actor roster missing or changed")
    actor=roster[0]
    need(all(actor.get(k)==expected[k] for k in ("actor_slot","instance_id","model","producer")),"Registered Needle actor ownership differs")
    owned=actor.get("bodies",[])
    need(len(owned)==expected["body_count"]==1,"Real actor body ownership missing")
    body=owned[0]
    need(body.get("body_slot")==0 and body.get("node_class")=="RigidBody2D" and integer(body.get("node_instance_id"),1)
         and integer(body.get("body_rid"),1) and body["body_rid"]==body.get("bridge_rid"),"Actor node and Rapier bridge ownership disagree")
    main_kinds={"main_callback","physics_callback","rapier_step","texture_upload","framebuffer_draw"}
    worker_kinds={"native_completion_observed","worker_snapshot","worker_participation","native_render_capture"}
    kinds=main_kinds|worker_kinds|{"command_attempt"}
    need(events and all(r.get("event") in kinds and integer(r.get("time_usec")) for r in events),"Unknown event or invalid observation clock")
    maximum=limits["maximum_events_per_owner"]
    for owner in (main_kinds,worker_kinds,{"command_attempt"}):
        need(sum(r["event"] in owner for r in events)<=maximum,"Registered event capacity exceeded")
    need(all(start<=r["time_usec"]<=end for r in events if r["event"] in main_kinds|{"command_attempt"}),"Main/step/input observation outside capture bounds")
    need(all(integer(r["start_usec"]) and r["start_usec"]<=r["time_usec"] for r in events if "start_usec" in r),"Observation clock chronology is invalid")
    inside=[r for r in events if start<=r["time_usec"]<=end]
    counts={kind:sum(r["event"]==kind for r in inside) for kind in kinds}
    if data["observer_mode"]=="full":
        need(all(counts[k]>0 for k in main_kinds|worker_kinds),"Full observer is missing a real publication, draw, physics or worker channel")
    else:
        need(all(counts[k]==0 for k in (main_kinds|worker_kinds)-{"rapier_step"}),"Reduced observer unexpectedly contains detailed channels")
    steps=sorted((r for r in inside if r["event"]=="rapier_step"),key=lambda r:r["step"])
    need(len(steps)>=limits["minimum_real_steps"],"Missing actual progression within capture bounds")
    need(integer(data["capture_physical_tick_start"]) and integer(data["capture_native_tick_start"]),"Initial physical/native tick missing")
    capabilities=data.get("snapshot_capabilities",{})
    need(set(capabilities)==set(SNAPSHOT_CAPABILITIES) and all(type(v) is bool for v in capabilities.values()),"Source snapshot capabilities missing or invalid")
    owner_field="physics_world_generation" if capabilities["physics_world_generation"] else "render_world_generation"
    need(all(integer(r.get("world_generation"),1) and integer(r.get("session"),1) and integer(r.get("epoch"),1)
             and r.get("packet_failed") is False and r.get("response_refusal")=="" for r in steps),"Physical step has an invalid or failed native/actor owner")
    need(len({(r["world_generation"],r["session"],r["epoch"]) for r in steps})==1,"Physical native/actor ownership changed")
    generation=steps[0]["world_generation"];epoch=steps[0]["epoch"]
    need(all(b["native_tick_used"]==a["native_tick_used"]+1 and b["completed_body_sample"]>a["completed_body_sample"]
             for a,b in zip(steps,steps[1:])),"Physical progression reused or skipped its native completion/body sample")
    initial=[]
    for index,row in enumerate(steps):
        need(integer(row.get("step"),1) and integer(row.get("manual_steps"),1) and integer(row.get("native_tick_used")),"Invalid completed-step counters")
        need(row.get("world_generation_field")==owner_field and integer(row.get("render_world_generation")),"Physical packet generation source differs")
        if owner_field=="render_world_generation":
            need(row["world_generation"]==row["render_world_generation"],"Legacy packet generation differs")
        need(isinstance(row.get("bodies"),list) and len(row["bodies"])==1,"Completed step has no real actor body")
        physical=row["bodies"][0]
        need(physical.get("slot")==0 and physical.get("instance_id")==1 and vector(physical.get("xy")) and vector(physical.get("velocity"))
             and number(physical.get("angle")) and integer(physical.get("contacts")),"Completed actor pose, velocity or contacts are missing/nonfinite")
        need(row.get("body_ownership")==[{"slot":0,"body_rid":body["body_rid"]}],"Completed step belongs to another physical body")
        need(number(row.get("observer_usec")) and row["observer_usec"]>=0 and number(row.get("solver_usec")) and row["solver_usec"]>=0,"Required observer/solver duration missing or invalid")
        bootstrap=index==0 and row["native_tick_used"]==data["capture_native_tick_start"] and row.get("completed_body_sample")==-1
        if bootstrap:
            need(row.get("response_accepted") is False and row.get("accepted_samples")==[-1],"Initial pre-capture native packet identity differs")
            initial.append(row["step"])
        else:
            need(row.get("response_accepted") is True and integer(row.get("completed_body_sample"),1)
                 and row.get("accepted_samples")==[row["completed_body_sample"]],"Completed step lacks an accepted matching native body response")
        for key,capability in (("native_completed_usec","last_native_tick_completed_usec"),("physics_handoff_usec","physics_handoff_usec")):
            raw_key=key.replace("_usec","_source_usec")
            need(key in row and raw_key in row,"Copied source clock field missing")
            value,raw=row[key],row[raw_key]
            if not capabilities[capability]:
                need(raw is None and value is None,"Unavailable legacy clock was invented")
            elif bootstrap and key=="native_completed_usec":
                need(raw==-1 and value is None,"Initial no-completion sentinel must remain explicit and normalize to null")
            else:
                need(integer(raw,1) and value==raw and value<=row["time_usec"],"Native/physics clock missing, negative or later than its consumed step")
        for field,capability,expected_value in (
            ("native_completion_world_generation","last_native_tick_world_generation",generation),
            ("native_completion_body_sample","last_native_tick_body_sample",row["completed_body_sample"])):
            need(field in row,"Native completion ownership field missing")
            need(row[field]==(-1 if bootstrap else expected_value) if capabilities[capability] else row[field] is None,"Native completion clock belongs to another World/body sample")
        if (row.get("native_completed_usec") or 0)>0 and (row.get("physics_handoff_usec") or 0)>0:
            need(row["native_completed_usec"]<=row["physics_handoff_usec"],"Native completion follows its physics mailbox")
    commands=sorted((r for r in inside if r["event"]=="command_attempt"),key=lambda r:(r["time_usec"],r["sequence_after"]))
    by_tick={}
    for row in commands:
        tick=row["physical_tick"]
        need(integer(tick) and row["absolute_tick"]==data["capture_physical_tick_start"]+tick and tick<=steps[-1]["step"]-data["capture_physical_tick_start"],"Command physical tick is invalid")
        selected=max(i for i,item in enumerate(data["input_tape"]) if item["tick"]<=tick)
        need(row["input_index"]==selected and row["move"]==data["input_tape"][selected]["move"],"Command used the wrong tick-addressed tape segment")
        need(row.get("actor_slot")==0 and row.get("instance_id")==1 and row.get("epoch")==epoch and row.get("producer")=="human"
             and row.get("ports")=={"q":False,"e":False,"s":False,"boost":False} and row.get("fire") is False,"Command actor/action identity differs")
        admitted=row.get("accepted_move")
        need(vector(admitted) and all(abs(v)<=1 for v in admitted),"Accepted Vector2 action missing or invalid")
        # Compare float32 representations, preserving the raw decimal tape and
        # avoiding a new numerical/performance tolerance for Vector2 admission.
        need(all(struct.pack("!f",a)==struct.pack("!f",b) for a,b in zip(admitted,row["move"])),"Accepted action differs from the submitted Vector2 tape")
        by_tick.setdefault(row["absolute_tick"],[]).append(row)
    matched_commands=[]
    for row in steps:
        candidates=[c for c in by_tick.get(row["step"]-1,[]) if c["time_usec"]<=row["time_usec"]]
        need(candidates,"Completed step lacks its actual admitted command")
        command=candidates[-1]
        need(row.get("command_sequence")==command["sequence_after"] and row.get("command_deadline_tick")==command["deadline_tick"]
             and row.get("admitted_move")==command["accepted_move"],"Completed step consumed a different action/sequence/lease")
        matched_commands.append(command["sequence_after"])
    for transition in data["input_events"]:
        matches=[c for c in commands if c["input_index"]==transition["input_index"]]
        need(matches and matches[0]["physical_tick"]==transition["requested_physical_tick"]
             and integer(transition.get("time_usec")) and matches[0]["time_usec"]<=transition["time_usec"]<=end,"Transition receipt has no matching actual admission")
    native=[r for r in events if r["event"]=="native_completion_observed"]
    worker=[r for r in events if r["event"]=="worker_snapshot"]
    completion_keys={(r["world_generation"],r["tick_index"]):r for r in native}
    packet_keys={(r["world_generation"],r["tick_index"],r["completed_body_sample"],r["required_hard_revision"])
                 for r in worker if not r["failed"] and r["hard_surface_revision"]==r["required_hard_revision"]}
    missing_full=[]
    if data["observer_mode"]=="full":
        for row in steps:
            if row["step"] in initial:continue
            completed=completion_keys.get((generation,row["native_tick_used"]))
            need(completed is not None and completed["time_usec"]<=row["time_usec"] and completed.get("body_sample")==row["completed_body_sample"],"Consumed native completion observation missing, late or from another body sample")
            key=(generation,row["native_tick_used"],row["completed_body_sample"],row["required_hard_revision"])
            if key not in packet_keys:missing_full.append(row["step"])
        # The final early-mailbox step can complete before its full publication
        # hook returns. All earlier consumed packets must be present; the one
        # possible trailing observation gap is disclosed, never treated as age0.
        need(not missing_full or missing_full==[steps[-1]["step"]] and (steps[-1].get("physics_handoff_usec") or 0)>0,"Consumed healthy native packet observations are incomplete")
        need(all(r["world_generation"]==generation for r in native+worker),"Worker trace contains another World")
        for row in (r for r in inside if r["event"]=="texture_upload"):
            need(row["world_generation"]==generation and integer(row.get("patch_bytes"),1) and integer(row.get("patch_count"),1)
                 and integer(row.get("render_serial"),1) and integer(row.get("generated_usec"),1) and row["generated_usec"]<=row["time_usec"],"Material upload has no real native payload or valid identity")
    return {"channel_counts_in_capture":counts,"source_snapshot_capabilities":capabilities,"physical_generation_field":owner_field,
        "initial_pre_capture_native_steps":initial,
        "initial_scope":"At most the first real Rapier step may consume the recorded pre-capture native tick/sample−1; all later native responses must be observed and accepted.",
        "trailing_full_snapshot_hook_missing_steps":missing_full,
        "trailing_scope":"A final early-mailbox step may precede its full-snapshot hook completion; its unavailable age remains null.",
        "matched_step_command_count":len(matched_commands),"actor_roster":roster,
        "worker_events_outside_capture":sum(r["event"] in worker_kinds and not start<=r["time_usec"]<=end for r in events)}


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
    # Whole-capture completeness is validated before reduction. A diagnostic
    # prefix may contain zero steps/callbacks during a real severe stall; keep
    # that negative result instead of imposing an unregistered prefix minimum.
    need(seconds > 0, "Invalid observation window duration")
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
    observed_pre_mailbox, post_mailbox_to_callback = [], []
    for row in steps:
        observed = native_by_tick.get(row["native_tick_used"])
        if observed is None:
            continue
        key = (observed["world_generation"], row["native_tick_used"], row["completed_body_sample"], row["required_hard_revision"])
        if key in first_ready and first_ready[key] <= row["time_usec"]:
            first_ready_ages.append((row["time_usec"] - first_ready[key]) / 1000)
        if key in first_handoff and first_handoff[key] <= row["time_usec"]:
            first_handoff_ages.append((row["time_usec"] - first_handoff[key]) / 1000)
            need(first_handoff[key] >= observed["time_usec"], "Native observation follows its healthy mailbox")
            observed_pre_mailbox.append((first_handoff[key] - observed["time_usec"]) / 1000)
            if first_handoff[key] <= row["start_usec"]:
                post_mailbox_to_callback.append((row["start_usec"] - first_handoff[key]) / 1000)
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
        draw = next((r for r in draws if r["time_usec"] >= upload["time_usec"]), None)
        if draw:
            postdraw.append((draw["time_usec"] - upload["time_usec"]) / 1000)
    frame_gaps = gaps(main, "start_usec")
    worst = sorted(({"from_process_frame": a["process_frame"], "to_process_frame": b["process_frame"], "start_usec": a["start_usec"], "gap_ms": gap}
                    for a, b, gap in zip(main, main[1:], frame_gaps)), key=lambda r: r["gap_ms"], reverse=True)[:12]

    def elapsed(values):
        return distribution((r["time_usec"] - r["start_usec"]) / 1000 for r in values)

    result = {
        "start_usec": start, "end_usec": end, "duration_seconds": seconds,
        "completed_native_ticks": len(native) if data["observer_mode"] == "full" else None, "completed_rapier_steps": len(steps),
        "completed_rapier_simulation_seconds": sum(r["fixed_delta"] for r in steps),
        "physical_simulation_seconds_per_wall_second": sum(r["fixed_delta"] for r in steps) / seconds,
        "first_step": steps[0]["step"] if steps else None, "last_step": steps[-1]["step"] if steps else None,
        "physical_no_step_prefix_ms": (steps[0]["time_usec"] - start) / 1000 if steps else seconds * 1000,
        "physical_no_step_suffix_ms": (end - steps[-1]["time_usec"]) / 1000 if steps else seconds * 1000,
        "physical_boundary_scope": "Observed window boundaries, including censored no-step prefixes/suffixes; separate from between-completion gap distributions.",
        "native_ticks_per_second": len(native) / seconds if data["observer_mode"] == "full" else None, "rapier_steps_per_second": len(steps) / seconds,
        "frame_ms": distribution(frame_gaps), "consecutive_two_frame_ms": distribution((b["start_usec"] - a["start_usec"]) / 1000 for a, b in zip(main, main[2:])),
        "worst_frame_intervals": worst, "post_draw_callback_gap_ms": distribution(gaps(draws)),
        "native_observed_gap_ms": distribution(gaps(native)), "native_exact_gap_ms": distribution(gaps(exact, "native_completed_usec")),
        "physical_gap_ms": distribution(gaps(steps)), "native_tick_ms": distribution(r["native_tick_ms"] for r in tick_rows),
        "main_callback_ms": elapsed(main), "worker_publication_ms": elapsed(worker),
        "snapshot_copy_ms": distribution(r["copy_ms"] for r in worker), "snapshot_publication_ms": distribution(r["publication_ms"] for r in worker),
        "rapier_solver_ms": distribution(r["solver_usec"] / 1000 for r in steps), "rapier_callback_to_completion_ms": elapsed(steps),
        "rapier_observer_ms": distribution(r["observer_usec"] / 1000 if r.get("observer_usec") is not None else None for r in steps),
        "native_observed_to_rapier_ms": distribution((r["time_usec"] - native_by_tick[r["native_tick_used"]]["time_usec"]) / 1000 for r in steps if r["native_tick_used"] in native_by_tick),
        "native_exact_to_rapier_ms": distribution((r["time_usec"] - r["native_completed_usec"]) / 1000 for r in steps if (r.get("native_completed_usec") or 0) > 0),
        "native_exact_to_physics_handoff_ms": distribution((r["physics_handoff_usec"] - r["native_completed_usec"]) / 1000 for r in steps if (r.get("native_completed_usec") or 0) > 0 and (r.get("physics_handoff_usec") or 0) > 0),
        "physics_handoff_to_rapier_ms": distribution((r["time_usec"] - r["physics_handoff_usec"]) / 1000 for r in steps if (r.get("physics_handoff_usec") or 0) > 0),
        "first_observed_eligible_snapshot_to_rapier_ms": distribution(first_ready_ages),
        "first_physics_handoff_to_rapier_ms": distribution(first_handoff_ages),
        "native_exact_to_first_physics_handoff_ms": distribution(first_native_handoff),
        "native_observed_to_first_physics_handoff_ms": distribution(observed_pre_mailbox),
        "first_physics_handoff_to_callback_start_ms": distribution(post_mailbox_to_callback),
        "first_ready_scope": "First healthy matching world/native-tick/body-sample/terrain packet. Observation clock is full snapshot hook exit (queue lower bound); exact physics handoff remains unavailable on accepted main. Latest handoff metrics above remain separately reported.",
        "snapshot_generated_to_upload_ms": distribution((r["time_usec"] - r["generated_usec"]) / 1000 for r in uploads if r["generated_usec"] > 0),
        "material_age_at_main_end_ms": distribution((r["time_usec"] - r["uploaded_generated_usec"]) / 1000 for r in main if r.get("uploaded_generated_usec", 0) > 0),
        "material_submission_ms": elapsed(uploads), "upload_return_to_next_delivered_draw_callback_ms": distribution(postdraw),
        "draw_clock_scope": "Next delivered frame_post_draw callback only; no upload-specific draw identity, GPU completion or scanout assertion, especially under Separate rendering.",
        "submission_stages_usec": {key: distribution(r.get(key) for r in submission) for key in ("image_patch_usec", "content_cache_usec", "atlas_assembly_usec", "backend_submit_usec", "staging_upload_usec", "gpu_blit_submit_usec", "direct_upload_usec", "whole_storage_create_usec", "whole_storage_replace_usec", "initialization_usec")},
        "publication": {
            "accepted_uploads": len(uploads), "uploads_per_second": len(uploads) / seconds,
            "native_full_inputs": sum(bool(r["full_refresh"]) for r in uploads), "native_sparse_inputs": sum(not r["full_refresh"] for r in uploads),
            "input_payload_bytes": sum(r["patch_bytes"] for r in uploads), "input_patch_count": sum(r["patch_count"] for r in uploads),
            "unique_worker_render_serials": len(packets), "submission_modes": modes,
            "cpu_staging_submitted_bytes": sum(r["submitted_bytes"] for r in submission) if uploads and len(submission) == len(uploads)
                and all(integer(r.get("submitted_bytes")) for r in submission) else None,
            "staging_residency_bytes": distribution(r.get("allocated_gpu_bytes") for r in submission),
            "dropped_publications": None, "expired_publications": None, "refused_publications": None,
            "unavailable_reason": "The common legacy seam cannot distinguish publication refusal/expiration from no-op consumption; original integrated diagnostics retain finer counters.",
            "byte_scope": "Input RG8 packet bytes and CPU staging upload bytes are distinct. Neither measures GPU bandwidth.",
        },
        "native_capture": {"count": sum(r["event"] == "native_render_capture" for r in rows),
            "forced_count": sum(r.get("force_full_requested",False) for r in rows if r["event"] == "native_render_capture"),
            "full_return_count": sum(bool(r.get("full_refresh",False)) for r in rows if r["event"] == "native_render_capture"),
            "status_counts": {str(k):sum(r.get("status") == k for r in rows if r["event"] == "native_render_capture") for k in {r.get("status") for r in rows if r["event"] == "native_render_capture"}},
            "wall_ms": elapsed([r for r in rows if r["event"] == "native_render_capture"])},
        "command_attempts": sum(r["event"] == "command_attempt" for r in rows),
        "command_acceptances": sum(bool(r.get("accepted")) for r in rows if r["event"] == "command_attempt"),
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
    if data["observer_mode"] == "reduced":
        # A disabled observer did not observe zero publications or callbacks.
        # Keep these unavailable counts distinct from a real zero measurement.
        result["publication"] = None
        result["native_capture"] = None
        result["physical_callbacks_without_step"] = None
        result["physical_callbacks_with_pending_terrain"] = None
    initial_probe = data["water_before"]["wave_flow"].get("column_probe")
    probes = [r.get("wave_column_probe") for r in worker if r.get("wave_column_probe") is not None]
    result["wave_column_stage_counter_deltas"] = None
    if initial_probe is not None and probes:
        latest = max(probes,key=lambda p:p["ticks"])
        fields = ("ticks","prepare_ns","column_ns","flux_ns","apply_ns","merge_ns","launch_ns")
        deltas = {k:latest[k]-initial_probe[k] for k in fields}
        need(all(v >= 0 for v in deltas.values()), "Native stage counters regressed")
        result["wave_column_stage_counter_deltas"] = {**deltas,"storage_bytes":latest["storage_bytes"],
            "column_slots":latest["column_slots"],"scope":"Existing cumulative native stage counters, initial probe to last observed snapshot in window. Missing legacy probes are null, not zero."}
    return result


def reduce_receipt(path, campaign, project=None, engine=None, arm_letter=None):
    path = Path(path)
    data = json.loads(path.read_text())
    need(data["schema"] == "pubpres-playability-gameplay-v2" and data["complete"] and not data["failures"], "Incomplete gameplay receipt")
    need(data["render_thread"]["runtime"] == data["render_thread"]["requested"] and data["render_thread"]["runtime"] in ("safe","separate"), "Rendering owner differs from requested mode")
    need(data["command_mode"] in ("repeated_callback","once_per_step") and data["observer_mode"] in ("full","reduced"), "Unknown apparatus mode")
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
    expected_tape = campaign["measurement"]["input_tape"]
    if data["input_mode"] == "neutral":
        expected_tape = [{"tick":r["tick"],"move":[0.0,0.0]} for r in expected_tape]
    need(data["input_tape"] == expected_tape, "Registered tape changed")
    need(len(data["input_events"]) == len(data["input_tape"]) == 11, "Input tape incomplete")
    for index, (actual, expected) in enumerate(zip(data["input_events"], data["input_tape"])):
        need(actual["input_index"] == index and actual["requested_physical_tick"] == actual["accepted_physical_tick"] == expected["tick"] and actual["move"] == expected["move"], "Input was not admitted at exact real step")
    letter = arm_letter or ("M" if data["source_identity"]["source_sha"] == campaign["source_commits"]["main"] else "I" if data["source_identity"]["source_sha"] == campaign["source_commits"]["integration"] else "C")
    if letter in ("M","I"):
        need(data["source_identity"]["source_sha"]==campaign["source_commits"]["main" if letter=="M" else "integration"],"Receipt source differs from selected historical arm")
    need(data.get("snapshot_capabilities")=={k:letter!="M" for k in SNAPSHOT_CAPABILITIES},"Snapshot capabilities differ from frozen source protocol")
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
        expected_pool = arm.get("material_pool_policy")
        need(selectors["requested"].get("CYBERSAND_DIAG_MATERIAL_POOL_POLICY","") == (expected_pool or ""), "Requested staging pool experiment differs")
        if expected_pool is not None:
            need(selectors["material"].get("staging_pool_policy") == expected_pool, "Staging pool experiment did not reach runtime")
        expected_columns = arm.get("wave_column_tiles")
        expected_probe = arm.get("wave_column_probe")
        for field, expected in (("CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES",expected_columns),("CYBERSAND_PLAYABILITY_WAVE_COLUMN_PROBE",expected_probe)):
            need(selectors["requested"].get(field,"") == ("" if expected is None else "1" if expected else "0"), "Requested Wave experiment differs")
        probe = selectors.get("wave_column_probe")
        if data["water_law"] == "wave_flow_v1" and expected_probe:
            need(probe is not None and probe["schema"] == "PUBPRES-WAVE-COLUMNS-V1" and probe["experimental_column_tiles"] == expected_columns, "Wave column experiment did not reach native runtime")
        elif not expected_probe:
            need(probe is None, "Disabled or historical source acquired candidate Wave probe")
    trace = path.with_name(path.stem + "-events.jsonl")
    need(digest(trace) == data["trace_sha256"], "Original event trace changed")
    rows = [json.loads(line) for line in trace.read_text().splitlines()]
    need(rows[0]["event"] == "identity" and rows[0]["source"] == data["source_identity"], "Trace/receipt identity differs")
    events = rows[1:]
    coverage=validate_measurement_trace(data,campaign,events)
    commands = sorted((r for r in events if r["event"] == "command_attempt"), key=lambda r:r["time_usec"])
    counts = data["command_counts"]
    need(len(commands) == counts["attempted"] == counts["accepted"] and counts["rejected"] == 0, "Actual attempted/admitted command accounting differs")
    need(commands and all(r["accepted"] and r["accepted_after"] == r["accepted_before"]+1 and r["rejected_after"] == r["rejected_before"] and r["sequence_after"] == r["sequence_before"]+1 and r["deadline_tick"] == r["absolute_tick"]+6 for r in commands), "Ordinary command admission or six-tick lease changed")
    need(all(b["accepted_before"] == a["accepted_after"] and b["sequence_before"] == a["sequence_after"] for a,b in zip(commands,commands[1:])), "Unrecorded or reordered commands")
    need(all(0 <= r["input_index"] < len(data["input_tape"]) and r["move"] == data["input_tape"][r["input_index"]]["move"] for r in commands), "Command differs from registered tape")
    if data["command_mode"] == "once_per_step":
        need(len({r["physical_tick"] for r in commands}) == len(commands), "Repeated command in once-per-step diagnostic")
    for upload in (r for r in events if r["event"] == "texture_upload"):
        if letter == "M":
            need(upload.get("material") is None, "Accepted main acquired integrated material telemetry")
        else:
            check_material_status(upload.get("material"), arm, material_expected)
    steps = sorted((r for r in events if r["event"] == "rapier_step"), key=lambda r: r["step"])
    native = sorted((r for r in events if r["event"] == "native_completion_observed"), key=lambda r: r["tick_index"])
    need(len(steps) >= 144 and steps[0]["step"] == data["capture_physical_tick_start"] + 1, "Missing actual progression")
    need(all(abs(r["fixed_delta"] - 1 / 60) <= 1e-12 for r in steps), "Rapier fixed simulation timestep changed")
    need(all(r["pending_hard_chunks"] == 0 and r["required_hard_revision"] == r["packet_hard_revision"] == r["installed_hard_revision"] for r in steps), "Physical step used incomplete native terrain")
    need(all(b["step"] == a["step"] + 1 and b["manual_steps"] == a["manual_steps"] + 1 and b["time_usec"] >= a["time_usec"] for a, b in zip(steps, steps[1:])), "Missing or reordered physical completion")
    need(all(b["tick_index"] == a["tick_index"] + 1 and b["time_usec"] >= a["time_usec"] for a, b in zip(native, native[1:])), "Missing native completion observation")
    need((data["observer_mode"] == "reduced" or len({r["world_generation"] for r in native}) == 1) and len({(r["session"], r["epoch"]) for r in steps}) == 1, "World or physical owner changed during registered capture")
    participation = [r["sample"] for r in events if r["event"] == "worker_participation"]
    if data["observer_mode"] == "full":
        need(any(r["workers_observed"] > 0 and r["worker_capacity"] > 0 for r in participation), "No actual native worker participation")
    need(all(r["worker_capacity"] == data["workers"] for r in participation), "Native worker capacity did not equal the registered request")
    need(len(data["framebuffers"]) == 2 and {r["label"] for r in data["framebuffers"]}=={"before","after"}, "Missing original before/after framebuffers")
    for image in data["framebuffers"]:
        framebuffer=path.with_name(path.stem + "-" + image["label"] + ".png")
        need(image["outside_timing"] and digest(framebuffer) == image["sha256"], "Framebuffer evidence changed")
        check_framebuffer(framebuffer,image,data["display"]["window"])
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
        need(data["water_profile"] in (campaign["measurement"]["water_profile"],"gameplay_main846f"), "Water workload profile changed")
        gameplay = data["water_profile"] == "gameplay_main846f"
        for state in (a,b):
            need(state["substeps"] == (2 if gameplay else 1) and state["spill"]["enabled"] == gameplay and state["spill"]["parcels"] == gameplay and state["construction_options"]["workbench_ballistic"] == gameplay, "Wave profile acquired different rounds/spill/ballistic semantics")
            need(all(state["parameters"].get(k) == v for k,v in (gameplay_parameters() if gameplay else WAVE_CORE_PARAMETERS).items()), "Native Wave profile parameters changed or unsupported")
            if gameplay:
                spill = {"sheet_rate":64,"coyote_ticks":4,"full_face":True,"fall":3,"draw":127,"draw_head":255,"deep_draw":64,"launch_budget":128}
                need(all(state["spill"].get(k) == v for k,v in spill.items()), "Current owner gameplay spill settings changed or unsupported")
            else:
                need(all(state["parameters"].get(k,0) == 0 for k in ("deep_gain","floor_gain","flux_smoothing")), "Later Wave additions were enabled in historical reference cohort")
        if data["fixture"]["name"] in ("landscape2048x1024","basin512"):
            need(a["water_quantity"] == b["water_quantity"], "Closed landscape Water quantity changed")
        need(b["ticks"] > a["ticks"] and b["rounds"] - a["rounds"] == (b["ticks"] - a["ticks"]) * b["substeps"], "Wave did not complete real rounds")
        need(before["construction"]["receipt_hash"] == after["construction"]["receipt_hash"] and after["policy"]["effective_water_solver"] == "wave_flow_v1", "Wave construction or policy changed")
    else:
        for state in (before,after):
            assignments = [r for r in state["policy"]["assignments"] if r["material"] == 3]
            need(len(assignments) == 1 and assignments[0]["applied_family"] == data["water_law"] and assignments[0]["applied_variant"] == data["water_variant"], "Native Water family/variant did not match request")
    if data["fixture"]["name"] in ("landscape2048x1024","basin512"):
        need(before["water_ledger"]["total"] == after["water_ledger"]["total"], "Closed authored basin lost Water")
    return {
        "process_id": data["process_id"], "source": data["source_identity"]["source_sha"], "trace_sha256": data["trace_sha256"],
        "match": {"engine": data["source_identity"]["engine_sha256"], "platform": data.get("platform"), "renderer": data["renderer"], "adapter": data["adapter"], "cpu": data["cpu"],
                  "logical_processors": data["logical_processors"], "display": data["display"], "fixture": data["fixture"], "tape": data["input_tape"],
                  "render_thread":data["render_thread"],"water_law":data["water_law"],"water_variant":data["water_variant"],"water_profile":data["water_profile"],"command_mode":data["command_mode"],
                  "workers_requested": data["workers"], "worker_capacities": sorted({r["worker_capacity"] for r in participation}),
                  "water_policy_hash": before["policy"]["policy_hash"], "wave_reference": wave_match(before) if data["water_law"] == "wave_flow_v1" else None,
                  "initial_body_state_sha256": before["construction"]["initial_body_state_sha256"], "prepared_payload_hash": before["construction"]["prepared_payload_hash"],
                  "prepared_setup_hash": before["construction"]["prepared_setup_hash"]},
        "windows": {"first_10s": window(events, data, data["capture_start_usec"] + 10000000), "first_144_steps": window(events, data, steps[143]["time_usec"]), "whole_capture": window(events, data, data["capture_end_usec"])},
        "actual_worker_participation": participation,
        "measurement_coverage":coverage,
        "memory": {"godot_static_peak_bytes": data["static_memory_peak_bytes"], "reported_video_final_bytes": data["video_memory_bytes"]},
        "water_quantity_before": before["wave_flow"].get("water_quantity"), "water_quantity_after": after["wave_flow"].get("water_quantity"),
        "water_ledger_before": before["water_ledger"], "water_ledger_after": after["water_ledger"], "water_by_native_tick": quantities,
        "selectors_before": data["selectors_before"], "selectors_after": data["selectors_after"], "gpu_history": data["gpu_history"],
        "registered_material_treatment": material_expected,
        "first_144_body_trajectory_sha256": hashlib.sha256(canonical([r["bodies"] for r in steps[:144]]).encode()).hexdigest(),
        "first_144_admitted_moves_sha256": hashlib.sha256(canonical([r["admitted_move"] for r in steps[:144]]).encode()).hexdigest(),
        "command_counts":counts,"command_mode":data["command_mode"],"observer_mode":data["observer_mode"],
        "command_repeat_count":len(commands)-len({r["physical_tick"] for r in commands}),
        "complete_native_water_configuration":{"before":before,"after":after},
        "observation_limits": campaign["measurement"]["limits"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--campaign", type=Path, default=Path(__file__).with_name("campaign.json"))
    parser.add_argument("--project", type=Path)
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--arm", choices=("M", "I", "C"))
    args = parser.parse_args()
    campaign = json.loads(args.campaign.read_text())
    need(campaign["schema"] == "pubpres-playability-campaign-v2", "Unknown source campaign")
    result = reduce_receipt(args.receipt, campaign, args.project, args.engine, args.arm)
    output = args.output or args.receipt.with_name("analysis.json")
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"analysis": str(output), "source": result["source"], "physical_acceptance": "HOLD", "frame_ms_first_144": result["windows"]["first_144_steps"]["frame_ms"], "physical_gap_ms_first_144": result["windows"]["first_144_steps"]["physical_gap_ms"]}))


if __name__ == "__main__":
    main()
