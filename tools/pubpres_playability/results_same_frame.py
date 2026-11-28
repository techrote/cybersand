#!/usr/bin/env python3
"""Prospective v3 continuation evidence, with the original v2 reducer preserved.

The native/actor/terrain/water/tape/framebuffer validation below is explicitly
copied from the ad7f4482 v2 definition. V3 adds actual callback-credit proofs,
keeps callback observations in reduced mode and uses honest execution clocks.
No old receipt is rewritten, upgraded or fed through a patched global function.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
from results import (SNAPSHOT_CAPABILITIES, WAVE_CORE_PARAMETERS, canonical,
    check_framebuffer, check_material_status, check_water_ledger, digest,
    distribution, expected_material, gameplay_parameters, integer, need,
    number, vector, wave_match, window as legacy_window)


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
    main_kinds={"main_callback","physics_callback","physics_continuation","rapier_step","texture_upload","framebuffer_draw"}
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
        need(all(counts[k]>0 for k in (main_kinds|worker_kinds)-{"physics_continuation"}),"Full observer is missing a real publication, draw, physics or worker channel")
    else:
        need(all(counts[k]==0 for k in (main_kinds|worker_kinds)-{"rapier_step","physics_callback","physics_continuation"}),"Reduced observer unexpectedly contains detailed channels")
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



def validate_continuations(data, campaign, events, letter):
    """Bind every real step to one scheduled callback, including deferred steps.

    This is an evidence admission rule, not authority to synthesize a step. The
    original native response, exact terrain, fixed-delta and body/move oracle
    checks in validate_measurement_trace/reduce_receipt are still mandatory.
    """
    selected = campaign["arms"][letter].get("same_frame_continuation")
    need((letter == "C" and type(selected) is bool) or (letter in ("M", "I") and selected is None),
         "Same-frame selection must explicitly name C and leave historical sources unavailable")
    for selectors in (data["selectors_before"], data["selectors_after"]):
        need(selectors["requested"].get("CYBERSAND_DIAG_SAME_FRAME_CONTINUATION", "") ==
             ("" if selected is None else "1" if selected else "0"), "Same-frame requested selector differs")
        status = selectors.get("same_frame_continuation")
        if selected is None:
            need(status is None, "Historical source acquired a continuation implementation")
        else:
            expected = {"version":1,"requested":selected,"enabled":selected,
                        "disabled_reason":"","mode":"same_frame_once" if selected else "off",
                        "maximum_attempts_per_process_frame":1,"maximum_mailbox_reads_per_attempt":1,
                        "wait_usec":0,"new_physics_callbacks":0,"carried_time_credit":False}
            need(status == expected, "Same-frame effective protocol differs from its registered bounds")
    owner = data.get("physical_owner_before")
    need(isinstance(owner, dict) and set(owner) == {"owner","bridge","worker","epoch","session"}
         and all(integer(owner.get(k),1) for k in ("epoch","session"))
         and all(isinstance(owner.get(k),str) and owner[k] == str(int(owner[k])) and int(owner[k]) != 0
                 and len(owner[k]) <= 20 for k in ("owner","bridge","worker"))
         and owner == data.get("physical_owner_after"),
         "Physical continuation owner identities are missing or changed")
    callbacks = sorted((r for r in events if r["event"] == "physics_callback"), key=lambda r:r["start_usec"])
    attempts = sorted((r for r in events if r["event"] == "physics_continuation"), key=lambda r:r["start_usec"])
    steps = sorted((r for r in events if r["event"] == "rapier_step"), key=lambda r:r["step"])
    need(callbacks, "No real scheduled callback evidence")
    need(all(integer(r.get("callback_id"),1) and integer(r.get("physics_frame"))
             and integer(r.get("process_frame")) and integer(r.get("before_step"))
             and r.get("after_step") in (r["before_step"],r["before_step"]+1)
             and integer(r.get("start_usec"),1) and integer(r.get("time_usec"),1)
             and r["start_usec"] <= r["time_usec"] for r in callbacks), "Malformed real callback receipt")
    need(all(b["callback_id"] == a["callback_id"]+1 and b["physics_frame"] == a["physics_frame"]+1
             and b["process_frame"] >= a["process_frame"] and b["start_usec"] >= a["time_usec"]
             for a,b in zip(callbacks,callbacks[1:])), "Missing, reordered or counterfeit physics callback")
    by_id = {r["callback_id"]:r for r in callbacks}
    need(len(by_id) == len(callbacks), "Repeated callback identity")
    need(selected or not attempts, "Disabled or unavailable source emitted a continuation")
    need(len({r.get("process_frame") for r in attempts}) == len(attempts), "More than one continuation attempt in a process frame")
    by_origin = {}
    for attempt in attempts:
        origin = attempt.get("origin_callback_id")
        need(origin in by_id and origin not in by_origin, "Continuation has no unique actual held callback")
        callback = by_id[origin]
        by_origin[origin] = attempt
        need(attempt.get("origin_callback_start_usec") == callback["start_usec"]
             and attempt.get("origin_process_frame") == callback["process_frame"]
             and attempt.get("origin_physics_frame") == callback["physics_frame"]
             and attempt.get("source_callback_serial") == origin
             and attempt.get("source_process_frame") == callback["process_frame"]
             and attempt.get("source_physics_frame") == callback["physics_frame"], "Continuation callback identity was forged")
        need(integer(attempt.get("source_callback_start_usec"),1) and integer(attempt.get("held_usec"),1)
             and callback["start_usec"] <= attempt["source_callback_start_usec"] <= attempt["held_usec"]
             <= callback["time_usec"] <= attempt["start_usec"] <= attempt["time_usec"], "Continuation did not follow its real hold")
        need(callback["before_step"] == callback["after_step"] == attempt.get("before_step"),
             "Continuation spends an already completed or different physical callback")
        need(attempt.get("polls") in (0,1) and type(attempt.get("polls")) is int
             and type(attempt.get("advanced")) is bool and attempt.get("after_step") == attempt["before_step"]+int(attempt["advanced"])
             and number(attempt.get("fixed_callback_delta")) and abs(attempt["fixed_callback_delta"]-1/60) <= 1e-12,
             "Continuation changed its callback credit, fixed delta or mailbox bound")
        need(attempt.get("status") in {"ready","owner_or_input_changed","frame_expired","frame_spent",
                                      "contended","transition","retired","failed","invalid","owner_changed",
                                      "native_refusal","native_sample","terrain_changed"}, "Unknown continuation outcome")
        need(integer(attempt.get("process_frame")) and attempt["process_frame"] >= callback["process_frame"]
             and (attempt["process_frame"] != callback["process_frame"] if attempt["status"] == "frame_expired"
                  else attempt["process_frame"] == callback["process_frame"]), "Attempt frame does not match its reported expiry")
        if attempt["status"] in ("frame_expired","frame_spent"):
            need(attempt["polls"] == 0, "Expired or spent callback polled a native mailbox")
        elif attempt["status"] != "owner_or_input_changed":
            need(attempt["polls"] == 1, "Native readiness outcome has no single mailbox observation")
        if data.get("observer_mode") == "full":
            containing = [r for r in events if r["event"] == "main_callback"
                          and r["process_frame"] == attempt["process_frame"]
                          and r["start_usec"] <= attempt["start_usec"] <= attempt["time_usec"] <= r["time_usec"]]
            need(len(containing) == 1, "Continuation is not inside exactly one actual Main callback")
        need(not any(c["callback_id"] > origin and c["start_usec"] < attempt["time_usec"] for c in callbacks),
             "A newer real callback invalidated this continuation")
        identity = attempt.get("expected_identity")
        scalar_keys = {"epoch","session","tick","manual_steps","sample",
                       "bridge_sample","installed_revision","accepted_commands"}
        array_keys = {"sequences","generations","deadlines"}
        need(isinstance(identity,dict) and set(identity) == scalar_keys|array_keys|{"owner","bridge","worker"}
             and all(integer(identity.get(k)) for k in scalar_keys)
             and all(identity.get(k) == v for k,v in owner.items())
             and identity["tick"] == callback["before_step"] and identity["sample"] == identity["bridge_sample"] == callback["waiting_body_sample"]
             and identity["installed_revision"] == attempt.get("expected_required_revision")
             and integer(attempt.get("expected_world_generation"),1), "Continuation native/body owner permit differs")
        need(all(isinstance(identity.get(k),list) and len(identity[k]) == 1
                 and integer(identity[k][0],-1) for k in array_keys), "Continuation actor lease identity differs")
        if attempt["advanced"]:
            need(attempt["status"] == "ready" and attempt["polls"] == 1
                 and attempt["process_frame"] == callback["process_frame"] == attempt.get("source_process_frame"),
                 "Advanced continuation carried credit across frames or skipped readiness")
        elif attempt["status"] == "ready":
            # A final main-thread/native failure can still withhold the step.
            # It is retained as an unsuccessful ready attempt, not fake work.
            need(attempt["polls"] == 1, "Ready attempt has no mailbox observation")
    used = set()
    continuation_steps = 0
    for step in steps:
        origin = step.get("origin_callback_id")
        need(origin in by_id and origin not in used, "A physical step has no callback credit or spends it twice")
        used.add(origin)
        callback = by_id[origin]
        need(step.get("origin_callback_start_usec") == callback["start_usec"]
             and step.get("origin_process_frame") == callback["process_frame"]
             and step.get("origin_physics_frame") == callback["physics_frame"]
             and step.get("process_frame") == callback["process_frame"]
             and step["step"] == callback["before_step"]+1, "Physical step callback identity differs")
        need(step["epoch"] == owner["epoch"] and step["session"] == owner["session"], "Physical step owner differs")
        need(isinstance(step.get("control_generations"),list) and len(step["control_generations"]) == 1
             and integer(step["control_generations"][0]) and integer(step.get("accepted_command_count")),
             "Physical step lacks bounded actor control-generation evidence")
        if step.get("execution_kind") == "physics_callback":
            need(callback["after_step"] == step["step"] and step["start_usec"] == callback["start_usec"]
                 and callback["start_usec"] <= step["time_usec"] <= callback["time_usec"]
                 and origin not in by_origin, "Ordinary step is not inside its real callback")
        else:
            need(step.get("execution_kind") == "physics_continuation" and origin in by_origin,
                 "Unknown physical execution phase or missing continuation")
            attempt = by_origin[origin]
            identity = attempt["expected_identity"]
            need(attempt["advanced"] and step["step"] == attempt["after_step"]
                 and step["start_usec"] == attempt["start_usec"] <= step["time_usec"] <= attempt["time_usec"],
                 "Deferred step does not belong to its real successful attempt")
            need(step["world_generation"] == attempt["expected_world_generation"]
                 and step["manual_steps"] == identity["manual_steps"]+1
                 and step["completed_body_sample"] == identity["sample"]
                 and step["required_hard_revision"] == identity["installed_revision"]
                 and step["accepted_command_count"] == identity["accepted_commands"]
                 and step["control_generations"] == identity["generations"]
                 and [step["command_sequence"]] == identity["sequences"]
                 and [step["command_deadline_tick"]] == identity["deadlines"],
                 "Deferred completion changed World, body sample, terrain or input authority")
            need(not any(r["event"] == "command_attempt" and callback["time_usec"] < r["time_usec"] <= step["time_usec"]
                         for r in events), "Continuation refreshed input outside its original callback")
            continuation_steps += 1
    need(sum(c["after_step"]-c["before_step"] for c in callbacks)+sum(a["advanced"] for a in attempts) == len(steps),
         "Callback/continuation completions do not exactly account for every physical step")
    need(continuation_steps == sum(a["advanced"] for a in attempts), "Successful continuation has no exact completed-step witness")
    return {"enabled":bool(selected),"available":selected is not None,"actual_physics_callbacks":len(callbacks),
            "attempts":len(attempts),"completed_continuations":continuation_steps,
            "completed_in_callbacks":len(steps)-continuation_steps,
            "outcomes":{k:sum(a["status"] == k for a in attempts) for k in sorted({a["status"] for a in attempts})},
            "every_step_has_unique_real_callback_credit":True,"maximum_attempts_per_process_frame":1,
            "scope":"Observed actual callback and immutable owner receipts; no modeled or extrapolated speedup."}


def window(events, data, end):
    # Native/publication/body windows use the unchanged common arithmetic.
    # V3 names physical execution separately because its start can now be a
    # continuation inside Main, rather than a new engine physics callback.
    result = legacy_window(events,data,end)
    result["rapier_execution_to_completion_ms"] = result.pop("rapier_callback_to_completion_ms")
    result["first_physics_handoff_to_execution_start_ms"] = result.pop("first_physics_handoff_to_callback_start_ms")
    rows = [r for r in events if data["capture_start_usec"] <= r["time_usec"] <= end]
    callbacks = [r for r in rows if r["event"] == "physics_callback"]
    attempts = [r for r in rows if r["event"] == "physics_continuation"]
    result["physics_callback_count"] = len(callbacks)
    result["physics_callback_ms"] = distribution((r["time_usec"]-r["start_usec"])/1000 for r in callbacks)
    result["physical_callbacks_without_step"] = sum(r["before_step"] == r["after_step"] for r in callbacks)
    result["physical_callbacks_with_pending_terrain"] = sum(r["pending_hard_chunks"] > 0 for r in callbacks)
    result["same_frame_attempts"] = len(attempts)
    # A completed Rapier step can precede its enclosing attempt-end observation.
    # Exact first-N and elapsed-time windows count the actual step timestamp,
    # while attempt-duration distributions require a completed observation.
    result["same_frame_completed_steps"] = sum(r["event"] == "rapier_step" and
        r.get("execution_kind") == "physics_continuation" for r in rows)
    result["same_frame_attempts_started"] = sum(r["event"] == "physics_continuation" and
        data["capture_start_usec"] <= r["start_usec"] <= end for r in events)
    result["same_frame_attempts_censored_at_end"] = sum(r["event"] == "physics_continuation" and
        data["capture_start_usec"] <= r["start_usec"] <= end < r["time_usec"] for r in events)
    result["same_frame_attempt_count_scope"] = "same_frame_attempts counts completed attempt observations; physical completions use Rapier step timestamps independently"
    result["same_frame_attempt_ms"] = distribution((r["time_usec"]-r["start_usec"])/1000 for r in attempts)
    result["same_frame_hold_to_attempt_ms"] = distribution((r["start_usec"]-r["held_usec"])/1000 for r in attempts)
    return result


def reduce_receipt(path, campaign, project=None, engine=None, arm_letter=None):
    need(campaign["schema"] == "pubpres-playability-campaign-v3", "Unknown same-frame campaign")
    path = Path(path)
    data = json.loads(path.read_text())
    need(data["schema"] == "pubpres-playability-gameplay-v3" and data["complete"] and not data["failures"], "Incomplete gameplay receipt")
    need(data["render_thread"]["runtime"] == data["render_thread"]["requested"] == "safe", "V3 requires the registered Safe rendering owner")
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
    continuation=validate_continuations(data,campaign,events,letter)
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
        "analysis_schema":"pubpres-playability-analysis-v3", "same_frame_continuation":continuation,
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
    need(campaign["schema"] == "pubpres-playability-campaign-v3", "Unknown source campaign")
    result = reduce_receipt(args.receipt, campaign, args.project, args.engine, args.arm)
    output = args.output or args.receipt.with_name("analysis.json")
    output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"analysis": str(output), "source": result["source"], "physical_acceptance": "HOLD", "frame_ms_first_144": result["windows"]["first_144_steps"]["frame_ms"], "physical_gap_ms_first_144": result["windows"]["first_144_steps"]["physical_gap_ms"]}))


if __name__ == "__main__":
    main()
