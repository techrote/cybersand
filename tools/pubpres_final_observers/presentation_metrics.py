#!/usr/bin/env python3
"""Independent joins for submitted presentation and process CPU sidecars.

The original complete physical oracle is mandatory before this supplement.
This records Main's submitted state, not physical display scanout.
"""
from __future__ import annotations

import bisect
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/pubpres_playability"))
from results import distribution, need
from execution_contract import FROZEN_RUNNER_SHA256, verify_execution_derivation
from resource_sampler import summarize_cpu
from process_discovery import validate_discovery

PROBE = "tests/pubpres_final_presentation_probe.gd"
GEOMETRY_SOURCES = ("scripts/physical_actor_session.gd", "scripts/physical_actor_rig.gd",
                    "scripts/physical_actor_overlay.gd")


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def vector(value):
    return isinstance(value, list) and len(value) == 2 and all(number(part) for part in value)


def pose(value):
    return isinstance(value, dict) and set(value) == {"xy", "angle"} and vector(value["xy"]) and number(value["angle"])


def same_float32(a, b):
    try:
        return struct.pack("!f", a) == struct.pack("!f", b)
    except (OverflowError, struct.error):
        return False


def transform(value):
    return isinstance(value, list) and len(value) == 6 and all(number(part) and abs(part) <= 3.4028234663852886e38 for part in value)


def object_id(value, *, node=False):
    # RefCounted shape resources use bit 63 and therefore signed-negative IDs.
    if not isinstance(value, str): return False
    try: parsed = int(value)
    except ValueError: return False
    return value == str(parsed) and (1 if node else -(2**63)) <= parsed < 2**63 and parsed != 0


def float32(value):
    return struct.unpack("!f", struct.pack("!f", value))[0]


def transform_product(a, b):
    def dot(x, y, z, w): return float32(float32(x*y) + float32(z*w))
    return [dot(a[0],b[0],a[2],b[1]), dot(a[1],b[0],a[3],b[1]),
            dot(a[0],b[2],a[2],b[3]), dot(a[1],b[2],a[3],b[3]),
            float32(dot(a[0],b[4],a[2],b[5])+a[4]),
            float32(dot(a[1],b[4],a[3],b[5])+a[5])]


def transform_product_magnitudes(a, b):
    # Bound roundoff by the absolute operands, including translation. A nearly
    # cancelled result can be tiny even though its products are much larger.
    return [abs(a[0]*b[0])+abs(a[2]*b[1]), abs(a[1]*b[0])+abs(a[3]*b[1]),
            abs(a[0]*b[2])+abs(a[2]*b[3]), abs(a[1]*b[2])+abs(a[3]*b[3]),
            abs(a[0]*b[4])+abs(a[2]*b[5])+abs(a[4]),
            abs(a[1]*b[4])+abs(a[3]*b[5])+abs(a[5])]


def composition_equal(a, b, operand_magnitude):
    # The engine may contract float32 multiply/adds. Permit four float32 ULPs
    # or four epsilons of absolute operand magnitudes under cancellation,
    # and 1e-7 near zero. This is an arithmetic bound, not a position budget.
    def ulp32(value):
        bits = struct.unpack("!I", struct.pack("!f", abs(value)))[0]
        if bits >= 0x7f7fffff: return 2.0**104
        return struct.unpack("!f", struct.pack("!I",bits+1))[0]-abs(float32(value))
    return abs(a-b) <= max(1e-7,4*max(ulp32(a),ulp32(b)),4*(2.0**-23)*operand_magnitude)


def validate_transform_pose(value, reported_pose, *, rigid=False):
    need(transform(value) and pose(reported_pose)
         and all(same_float32(a,b) for a,b in zip(value[4:],reported_pose["xy"])),
         "Submitted matrix and reported pose origin differ")
    angle = math.atan2(value[1],value[0])
    delta = math.remainder(angle-reported_pose["angle"],2*math.pi)
    need(abs(delta) <= 2e-6, "Submitted matrix and pose rotation differ")
    if rigid:
        expected = [math.cos(reported_pose["angle"]),math.sin(reported_pose["angle"]),
                    -math.sin(reported_pose["angle"]),math.cos(reported_pose["angle"])]
        need(all(abs(a-b) <= 2e-6 for a,b in zip(value[:4],expected)),
             "Selected physical pose gained unobserved scale or shear")


def validate_geometry(body, roster_body, actor_slot):
    selected, submitted = body.get("selected_transform"), body.get("first_overlay_transform")
    validate_transform_pose(selected,body["selected_pose"],rigid=True)
    validate_transform_pose(submitted,body["first_overlay_part"])
    geometry = body.get("geometry")
    need(isinstance(geometry,dict) and type(geometry.get("available")) is bool,
         "Actual collision geometry availability is not explicit")
    if not geometry["available"]:
        need(set(geometry)=={"available","reason"} and geometry.get("reason") in
             ("actor_bound","collider_bound","unsupported_collision_geometry","body_not_in_session"),
             "Unavailable collision geometry has an invented fallback")
        return False, None
    need(geometry.get("reason")=="actual_collision_node" and geometry.get("actor_slot")==actor_slot
         and geometry.get("overlay_actor_slot")==actor_slot and geometry.get("part_index")==0
         and geometry.get("body_node_id")==str(roster_body["node_instance_id"])
         and geometry.get("body_rid")==str(roster_body["body_rid"])
         and geometry.get("child_parent_id")==geometry["body_node_id"]
         and object_id(geometry.get("child_node_id"),node=True)
         and geometry["child_node_id"]!=geometry["body_node_id"]
         and object_id(geometry.get("shape_instance_id"))
         and geometry.get("child_class")=="CollisionShape2D"
         and integer(geometry.get("child_index")) and geometry["child_index"]<512,
         "Submitted geometry is not bound to the actual roster body and collider")
    need(vector(geometry.get("shape_size")) and all(value>0 for value in geometry["shape_size"])
         and vector(geometry.get("overlay_size"))
         and all(same_float32(a,b) for a,b in zip(geometry["shape_size"],geometry["overlay_size"]))
         and transform(geometry.get("collision_local_transform"))
         and isinstance(geometry.get("declared_part_id"),str) and bool(geometry["declared_part_id"])
         and geometry.get("overlay_part_id")==geometry["declared_part_id"],
         "Submitted part dimensions, collider transform or part identity differ")
    shape = geometry.get("declared_shape")
    if shape=="rectangle_union":
        need(geometry.get("composition")=="selected_times_collision_local"
             and geometry.get("shape_class")=="RectangleShape2D" and geometry.get("overlay_shape")=="rectangle"
             and geometry.get("overlay_body_slot")==body["slot"]
             and geometry.get("overlay_physical_part_id")==geometry["declared_part_id"],
             "Compound submitted geometry lost its physical part/shape identity")
        try: expected = transform_product(selected,geometry["collision_local_transform"])
        except (OverflowError,struct.error): raise ValueError("Submitted geometry composition overflows float32")
        magnitudes = transform_product_magnitudes(selected,geometry["collision_local_transform"])
        need(all(composition_equal(a,b,magnitude) for a,b,magnitude in zip(submitted,expected,magnitudes)),
             "Actual submitted compound part differs from completed pose times actual collider-local transform")
    else:
        need(shape in ("rectangle","rect","circle") and geometry.get("composition")=="selected_direct"
             and geometry.get("child_index")==0 and geometry.get("overlay_body_slot")==-1
             and geometry.get("overlay_physical_part_id")==""
             and geometry.get("shape_class")==("CircleShape2D" if shape=="circle" else "RectangleShape2D")
             and geometry.get("overlay_shape")==("circle" if shape=="circle" else "rectangle"),
             "Direct submitted geometry differs from its source branch")
        need(all(same_float32(a,b) for a,b in zip(submitted,selected)),
             "Actual submitted direct part differs from its completed selected pose")
    return True, tuple((key,json.dumps(value,sort_keys=True)) for key,value in sorted(geometry.items()))


def validate_cpu_trace(path: Path, process: dict, receipt: dict, root: Path = ROOT) -> dict:
    raw = path.read_bytes()
    data = json.loads(raw)
    need(data.get("schema") == "pubpres-final-process-cpu-v1"
         and data.get("source_commit") == receipt["source_identity"]["source_sha"]
         and process.get("source_commit") == data["source_commit"]
         and process.get("observed_application_pid") == receipt["process_id"], "CPU sidecar source or owned application differs")
    identity = verify_execution_derivation(root)
    need(data.get("frozen_runner_sha256") == FROZEN_RUNNER_SHA256
         and data.get("runner_sha256") == identity["runner_sha256"], "CPU sidecar runner derivation differs")
    need(isinstance(data.get("samples"), list) and len(data["samples"]) <= 4096
         and isinstance(data.get("errors"), list) and len(data["errors"]) <= 4096, "CPU sidecar is not bounded")
    summary = summarize_cpu(data["samples"], expected_pid=receipt["process_id"],
                            errors=data["errors"], dropped=data.get("summary", {}).get("dropped", -1))
    need(summary["complete"] and summary == data.get("summary"), "CPU accounting summary does not reconstruct")
    if summary["creation_identity"].startswith("linux-start-ticks:"):
        discovery = process.get("application_discovery")
        need(isinstance(discovery, dict) and isinstance(discovery.get("executable"), str),
             "Linux process has no actual executable/ancestry discovery receipt")
        executable = Path(discovery["executable"])
        need(str(executable) in process.get("command", [])
             and hashlib.sha256(executable.read_bytes()).hexdigest() == receipt["source_identity"]["engine_sha256"],
             "Discovered executable differs from actual command or engine receipt")
        validate_discovery(discovery, owner_pid=process["wrapper_pid"], pid=receipt["process_id"],
                           creation_identity=summary["creation_identity"], executable=executable)
    need(process.get("process_cpu", {}).get("sha256") == hashlib.sha256(raw).hexdigest()
         and process["process_cpu"].get("summary") == summary, "CPU sidecar is not bound to actual process result")
    return summary


def validate_presentation(path: Path, receipt_path: Path, project: Path) -> dict:
    receipt = json.loads(receipt_path.read_bytes())
    data = json.loads(path.read_bytes())
    trace_path = receipt_path.with_name(receipt_path.stem + "-events.jsonl")
    trace = trace_path.read_bytes()
    need(hashlib.sha256(trace).hexdigest() == receipt["trace_sha256"], "Presentation base trace hash differs")
    events = [json.loads(line) for line in trace.splitlines()]
    need(events[0].get("event") == "identity" and events[0].get("source") == receipt["source_identity"], "Presentation base identity differs")
    need(receipt.get("complete") is True and receipt.get("failures") == [], "Presentation supplement requires a complete base receipt")
    need(data.get("schema") == "pubpres-final-presentation-observer-v1" and data.get("complete") is True
         and data.get("source_identity") == receipt["source_identity"]
         and data.get("process_id") == receipt["process_id"]
         and data.get("engine_sha256") == receipt["source_identity"]["engine_sha256"]
         and data.get("platform") == receipt["platform"] and data.get("renderer") == receipt["renderer"], "Presentation source, process, engine or graphics identity differs")
    probe_sha = hashlib.sha256((project / PROBE).read_bytes()).hexdigest()
    need(data.get("probe_sha256") == probe_sha and receipt["source_identity"]["files"].get("res://" + PROBE) == probe_sha,
         "Presentation observer source is not in the executed identity")
    need(all(receipt["source_identity"]["files"].get("res://"+name)==hashlib.sha256((project/name).read_bytes()).hexdigest()
             for name in GEOMETRY_SOURCES), "Actual submitted-geometry source is not bound to executed bytes")
    need(data.get("selector") == "1" and all(receipt[phase]["requested"].get("CYBERSAND_DIAG_PRESENTATION_OBSERVER") == "1"
                                             for phase in ("selectors_before", "selectors_after")), "Presentation instrumentation was not explicitly registered throughout capture")
    start, end = receipt["capture_start_usec"], receipt["capture_end_usec"]
    need(data.get("capture_start_usec") == start and data.get("capture_end_usec") == end,
         "Presentation sidecar uses different capture bounds")
    need(all(data.get(key) == value for key, value in {"max_submissions": 6000, "max_notifications": 6000,
             "max_bodies": 8, "max_parts": 512, "dropped_submissions": 0, "dropped_notifications": 0,
             "invalid_samples": 0}.items()), "Presentation bounds or loss counters differ")
    rows, draws = data.get("submissions"), data.get("notifications")
    need(isinstance(rows, list) and 1 <= len(rows) <= 6000 and isinstance(draws, list) and 1 <= len(draws) <= 6000,
         "Presentation observations are empty or unbounded")
    steps = sorted((row for row in events if row.get("event") == "rapier_step"), key=lambda row: row["step"])
    need(len(steps) >= 144, "No independently completed physical sequence to join")
    by_step = {row["step"]: row for row in steps}
    times = [row["time_usec"] for row in steps]
    uploads = sorted((row for row in events if row.get("event") == "texture_upload"), key=lambda row:row["time_usec"])
    upload_times = [row["time_usec"] for row in uploads]
    owner = (steps[0]["session"], steps[0]["epoch"], steps[0]["world_generation"])
    roster = [body for actor in receipt["actor_roster_before"] for body in actor["bodies"]]
    need(1 <= len(roster) <= 8, "Unregistered presentation body count")
    rids = {body["body_slot"]: str(body["body_rid"]) for body in roster}
    instances = {body["body_slot"]: actor["instance_id"] for actor in receipt["actor_roster_before"] for body in actor["bodies"]}
    actors = {body["body_slot"]: actor["actor_slot"] for actor in receipt["actor_roster_before"] for body in actor["bodies"]}
    need(all(len(actor["bodies"])==1 for actor in receipt["actor_roster_before"]),
         "Submitted geometry supplement requires the registered one-body-per-actor roster")
    inline = receipt["render_thread"]["runtime"] == "safe"
    joined_poses, pre_capture_poses, joined_follow, pre_capture_follow = 0, 0, 0, 0
    identities = None
    geometry_identities = {}
    verified_geometry, unavailable_geometry = 0, 0
    previous_time, previous_frame = -1, -1
    for index, row in enumerate(rows):
        need(row.get("event") == "main_presentation_submission" and row.get("index") == index
             and integer(row.get("time_usec"), 1) and start <= row["time_usec"] <= end
             and row["time_usec"] >= previous_time and integer(row.get("process_frame"))
             and row["process_frame"] >= previous_frame and row.get("main_thread") is True
             and row.get("render_thread_inline") is inline, "Presentation boundary is reordered or from the wrong owner")
        previous_time, previous_frame = row["time_usec"], row["process_frame"]
        need((row.get("session"), row.get("epoch"), row.get("world_generation")) == owner
             and (row.get("frame_session"), row.get("frame_epoch")) == owner[:2]
             and integer(row.get("presentation_resolved_usec"), 1) and row["presentation_resolved_usec"] <= row["time_usec"]
             and type(row.get("frame_valid")) is bool and isinstance(row.get("frame_reason"), str), "Submitted presentation has a different identity or future resolution")
        preceding = bisect.bisect_right(times, row["time_usec"])-1
        physical_tick = steps[preceding]["step"] if preceding >= 0 else receipt["capture_physical_tick_start"]
        need(row.get("physical_tick") == physical_tick, "Submitted-pose probe invented physical completion")
        need(row.get("truncated_bodies") == 0 and row.get("truncated_parts") == 0
             and row.get("body_count") == len(roster) and isinstance(row.get("bodies"), list)
             and len(row["bodies"]) == len(roster) and integer(row.get("visible_part_count"))
             and row["visible_part_count"] <= 512, "Submitted presentation omits a body or truncates parts")
        need(integer(row.get("render_serial"), 1) and integer(row.get("material_revision"))
             and integer(row.get("observer_usec")) and integer(row.get("material_generated_usec"), -1)
             and row["material_generated_usec"] <= row["time_usec"], "Invalid presentation material or observer clock")
        upload_position = bisect.bisect_right(upload_times,row["time_usec"])-1
        if upload_position >= 0:
            upload = uploads[upload_position]
            need(row["render_serial"] == upload["render_serial"] and row["world_generation"] == upload["world_generation"]
                 and row["material_generated_usec"] == upload["generated_usec"], "Submitted material is not the latest independently observed upload")
            row["_joined_material_generated_usec"] = upload["generated_usec"]
        else:
            row["_joined_material_generated_usec"] = None
        need(all(vector(row.get(key)) for key in ("camera_requested", "camera_submitted", "view_size", "content_position", "content_size"))
             and row.get("camera_mode") == (1 if receipt["camera"] == "follow" else 0), "Submitted camera mode or geometry differs")
        current_identity = []
        for slot, body in enumerate(row["bodies"]):
            need(body.get("slot") == slot and body.get("body_rid") == rids[slot]
                 and body.get("instance_id") == instances[slot] and integer(body.get("generation")), "Submitted body RID/instance ownership differs")
            current_identity.append((slot, body["instance_id"], body["generation"], body["body_rid"]))
            need(all(type(body.get(key)) is bool for key in ("selected_visible", "overlay_visible", "intentional_hold", "explicit_reentry", "timeline_reset"))
                 and body["selected_visible"] == body["overlay_visible"]
                 and integer(body.get("selected_step"), -1) and body["selected_step"] <= physical_tick
                 and integer(body.get("desired_step")) and body["desired_step"] <= physical_tick
                 and integer(body.get("selected_completed_usec")) and body["selected_completed_usec"] <= row["time_usec"]
                 and integer(body.get("selected_sampled_usec")) and body["selected_sampled_usec"] <= row["time_usec"]
                 and integer(body.get("hold_age_usec")), "Submitted visibility, step or age is invalid")
            if body["overlay_visible"]:
                need(pose(body.get("selected_pose")) and pose(body.get("first_overlay_part"))
                     and body["selected_step"] >= 0, "Visible overlay lacks its actual pose and source step")
                verified, geometry_identity = validate_geometry(body,roster[slot],actors[slot])
                body["_geometry_verified"] = verified
                if verified:
                    verified_geometry += 1
                    if slot not in geometry_identities: geometry_identities[slot] = geometry_identity
                    need(geometry_identities[slot]==geometry_identity,
                         "Actual collider/part identity or local geometry changed during registered capture")
                else: unavailable_geometry += 1
                selected_step = by_step.get(body["selected_step"])
                if selected_step is None:
                    need(body["selected_step"] <= receipt["capture_physical_tick_start"], "Visible pose comes from an unobserved in-capture step")
                    pre_capture_poses += 1
                else:
                    physical = selected_step["bodies"][slot]
                    need(physical["instance_id"] == body["instance_id"]
                         and all(same_float32(a,b) for a,b in zip(body["selected_pose"]["xy"],physical["xy"]))
                         and same_float32(body["selected_pose"]["angle"],physical["angle"]), "Selected pose is not its independently witnessed completed physical state")
                    need(selected_step["start_usec"] <= body["selected_completed_usec"] <= selected_step["time_usec"],
                         "Main selected-pose completion clock is outside its real Rapier execution")
                    body["_joined_completed_usec"] = selected_step["time_usec"]
                    joined_poses += 1
                projection = body.get("projection")
                need(isinstance(projection, dict) and vector(projection.get("overlay_px")) and vector(projection.get("shader_px"))
                     and number(projection.get("residual_px")) and projection["residual_px"] >= 0, "Visible pose lacks bounded projection observations")
            else:
                need(body.get("selected_pose") is None and body.get("first_overlay_part") is None
                     and body.get("selected_transform") is None and body.get("first_overlay_transform") is None
                     and body.get("geometry") is None
                     and body["selected_step"] == -1 and body.get("projection") is None, "Withheld overlay has a fabricated visible pose")
        if identities is None: identities = current_identity
        need(current_identity == identities, "Presentation actor identity changed during capture")
        follow = row.get("follow", {})
        need(follow.get("instance_id") in [body["instance_id"] for body in row["bodies"]]
             and type(follow.get("held")) is bool and integer(follow.get("source_step"), -1)
             and follow["source_step"] <= physical_tick, "Follow target identity or step is invalid")
        if follow.get("target") is not None:
            need(vector(follow["target"]) and follow["source_step"] >= 0, "Follow target coordinates are invalid")
            selected_step = by_step.get(follow["source_step"])
            if selected_step is None:
                need(follow["source_step"] <= receipt["capture_physical_tick_start"], "Follow uses an unobserved in-capture step")
                pre_capture_follow += 1
            else:
                target = next((body for body in selected_step["bodies"] if body["instance_id"] == follow["instance_id"]), None)
                need(target is not None and all(same_float32(a,b) for a,b in zip(follow["target"],target["xy"])), "Follow target differs from its independently witnessed physical state")
                joined_follow += 1
    previous_time = -1
    base_draws = sorted((event for event in events if event.get("event") == "framebuffer_draw"
                         and start <= event["time_usec"] <= end), key=lambda event:event["time_usec"])
    need(len(base_draws) == len(draws), "Presentation sidecar lost or invented a base draw notification")
    for position, draw in enumerate(draws):
        need(draw.get("event") == "draw_notification" and integer(draw.get("time_usec"), 1)
             and start <= draw["time_usec"] <= end and draw["time_usec"] >= previous_time
             and draw.get("render_thread_inline") is inline and integer(draw.get("observer_usec")), "Draw notification identity or clock differs")
        previous_time = draw["time_usec"]
        base_draw = base_draws[position]
        need(base_draw.get("inline_main") is inline and base_draw["time_usec"] <= draw["time_usec"]
             and base_draw.get("process_frame") == draw.get("callback_process_frame")
             and (position+1 == len(draws) or draw["time_usec"] <= base_draws[position+1]["time_usec"]),
             "Presentation notification does not follow its actual base observer callback")
        if inline:
            index = draw.get("submission_index")
            need(integer(index) and index < len(rows) and rows[index]["time_usec"] <= draw["time_usec"]
                 and draw.get("callback_process_frame") == rows[index]["process_frame"], "Inline draw lacks its actual preceding Main submission")
        else:
            need(draw.get("submission_index") == -1, "Deferred Separate notification was relabelled as a known submission")
    if inline:
        need([draw["submission_index"] for draw in draws] == list(range(len(rows))),
             "Inline notifications do not retain every actual pre-draw submission exactly once")
    costs = [row["observer_usec"] for row in rows + draws]
    need(data.get("observer_total_usec") == sum(costs) and data.get("observer_max_usec") == max(costs), "Presentation observer cost does not include every recorded callback")
    return {"schema": "pubpres-final-presentation-analysis-v1", "sidecar_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "base_receipt_sha256": hashlib.sha256(receipt_path.read_bytes()).hexdigest(), "source_identity": receipt["source_identity"],
            "joined_selected_physical_poses": joined_poses, "pre_capture_selected_poses_without_trace_join": pre_capture_poses,
            "joined_follow_targets": joined_follow, "pre_capture_follow_targets_without_trace_join": pre_capture_follow,
            "verified_first_part_submissions":verified_geometry,
            "unverified_first_part_submissions":unavailable_geometry,
            "all_visible_first_parts_verified":verified_geometry>0 and unavailable_geometry==0,
            "observer_total_usec": sum(costs), "observer_call_ms": distribution(value/1000 for value in costs),
            "windows": {"first_144_steps": measure_window(rows, start, steps[143]["time_usec"]),
                        "whole_capture": measure_window(rows, start, end)},
            "scope": "Actual Main submitted overlay state at pre-draw. The first visible part is joined to the real roster node/RID and actual collider-local transform; compound composition uses a float32 roundoff bound including absolute operand magnitudes under cancellation. Additional parts are not individually checked. Unsupported geometry and pre-capture physical poses remain explicitly unverified. Withholding, pose age and Follow lag are submitted-state observations, not scanout, display refresh or input-device latency. Separate draw notifications remain unassociated."}


def measure_window(rows: list[dict], start: int, end: int) -> dict:
    chosen = [row for row in rows if start <= row["time_usec"] <= end]
    bodies = [(row, body) for row in chosen for body in row["bodies"]]
    visible = [(row, body) for row, body in bodies if body["overlay_visible"]]
    completed_age = [(row["time_usec"]-body["_joined_completed_usec"])/1000 for row, body in visible if body.get("_joined_completed_usec") is not None]
    geometry_age = [(row["time_usec"]-body["_joined_completed_usec"])/1000 for row,body in visible
                    if body.get("_geometry_verified") and body.get("_joined_completed_usec") is not None]
    following = [row for row in chosen if row["follow"]["target"] is not None]
    episodes = []
    for slot in range(chosen[0]["body_count"] if chosen else 0):
        began = None
        for row in chosen:
            if not row["bodies"][slot]["overlay_visible"] and began is None: began = row["time_usec"]
            elif row["bodies"][slot]["overlay_visible"] and began is not None:
                episodes.append({"slot":slot,"duration_ms":(row["time_usec"]-began)/1000,"right_censored":False})
                began = None
        if began is not None: episodes.append({"slot":slot,"duration_ms":(end-began)/1000,"right_censored":True})
    return {"submissions":len(chosen),"body_submissions":len(bodies),"visible_body_submissions":len(visible),
            "withheld_body_submissions":len(bodies)-len(visible),
            "intentional_holds":sum(body["intentional_hold"] for _,body in bodies),
            "explicit_reentries":sum(body["explicit_reentry"] for _,body in bodies),
            "selected_physical_steps_behind":distribution(row["physical_tick"]-body["selected_step"] for row,body in visible),
            "selected_completion_age_ms":distribution(completed_age),
            "verified_first_part_completion_age_ms":distribution(geometry_age),
            "unverified_visible_first_parts":sum(not body.get("_geometry_verified",False) for _,body in visible),
            "source_reported_completion_age_ms":distribution((row["time_usec"]-body["selected_completed_usec"])/1000 for row,body in visible if body["selected_completed_usec"] > 0),
            "pre_capture_unjoined_completion_age_ms":distribution((row["time_usec"]-body["selected_completed_usec"])/1000 for row,body in visible if body.get("_joined_completed_usec") is None and body["selected_completed_usec"] > 0),
            "unknown_selected_completion_times":sum(body["selected_completed_usec"] <= 0 for _,body in visible),
            "intentional_hold_age_ms":distribution(body["hold_age_usec"]/1000 for _,body in bodies if body["intentional_hold"]),
            "follow_held_submissions":sum(row["follow"]["held"] for row in chosen),
            "follow_unknown_targets":len(chosen)-len(following),
            "follow_physical_steps_behind":distribution(row["physical_tick"]-row["follow"]["source_step"] for row in following),
            "submission_gap_ms":distribution((b["time_usec"]-a["time_usec"])/1000 for a,b in zip(chosen,chosen[1:])),
            "material_generation_age_at_submission_ms":distribution((row["time_usec"]-row["_joined_material_generated_usec"])/1000 for row in chosen if (row.get("_joined_material_generated_usec") or 0) > 0),
            "pre_capture_unjoined_material_submissions":sum(row.get("_joined_material_generated_usec") is None for row in chosen),
            "projection_residual_px":distribution(math.hypot(*(a-b for a,b in zip(body["projection"]["overlay_px"],body["projection"]["shader_px"]))) for _,body in visible),
            "withholding_episodes":episodes,"withholding_observation_duration_ms":distribution(item["duration_ms"] for item in episodes),
            "withholding_censored_episodes":sum(item["right_censored"] for item in episodes)}
