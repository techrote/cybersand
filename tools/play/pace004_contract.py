#!/usr/bin/env python3
"""Reconstruct PACE004 input custody and measurements from original engine rows.

No fixture outcome counter can substitute for the chronological admission,
button-queue, copied applied-action and completed Rapier-step observations.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import struct
from typing import Any
import zlib

RIGS = ("stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel")
MARKER = "PLAY_PACE004_RESULT "
BUTTONS = ("primary", "secondary", "auxiliary")
INPUT_OWNER = ("session", "run_id", "epoch")
OWNER = ("worker", "session", "bridge", "run_id", "epoch", "world_generation")
GODOT_HASH = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
PUBLICATION = ("serial", "tick", "epoch", "generation", "published_usec", "render_usec",
               "render_serial", "render_tick", "render_revision", "simulation_revision", "failed")
EXPECTED = (
    ("forward", True, "applied"), ("forward", False, "applied"),
    ("trim_left", True, "applied"), ("trim_left", False, "applied"),
    ("primary", True, "applied"), ("primary", False, "applied"),
    ("secondary", True, "applied"), ("secondary", False, "applied"),
    ("auxiliary", True, "applied"), ("auxiliary", False, "applied"),
    ("back", True, "applied"), ("back", False, "applied"),
    ("trim_right", True, "applied"), ("trim_right", False, "applied"),
    ("primary", True, "applied"), ("primary", False, "applied"),
    ("primary", True, "cancelled"), ("primary", False, "cancelled"),
    ("forward", True, "refused"), ("forward", False, "applied"),
    ("forward", True, "applied"), ("forward", False, "applied"),
    ("primary", True, "cancelled"), ("primary", False, "cancelled"),
    ("forward", True, "refused"), ("forward", False, "refused"),
    ("forward", True, "applied"), ("forward", False, "applied"),
    ("primary", True, "cancelled"), ("primary", False, "cancelled"),
    ("forward", True, "refused"), ("forward", False, "refused"),
    ("forward", True, "applied"), ("forward", False, "applied"),
    ("primary", True, "applied"), ("primary", False, "applied"),
    ("secondary", True, "applied"), ("secondary", False, "applied"),
    ("auxiliary", True, "applied"), ("auxiliary", False, "applied"),
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def numeric(value: Any, name: str, minimum: float = 0) -> int | float:
    require(type(value) in (int, float) and math.isfinite(value) and value >= minimum,
            "Invalid number: " + name)
    return value


def integer(value: Any, name: str, minimum: int = 0) -> int:
    require(type(value) is int and value >= minimum, "Invalid integer: " + name)
    return value


def vector(value: Any, name: str) -> None:
    require(type(value) is list and len(value) == 2, "Invalid vector: " + name)
    for item in value:
        numeric(item, name, -1e12)


def same(a: dict, b: dict, fields=OWNER) -> bool:
    return all(k in a and k in b and a[k] == b[k] for k in fields)


def action_valid(value: Any) -> None:
    require(type(value) is dict and set(value) == {"move", "trim", *BUTTONS}, "Incomplete action")
    vector(value["move"], "action.move")
    require(sum(x*x for x in value["move"]) <= 1.00001, "Movement exceeds admitted range")
    require(abs(numeric(value["trim"], "trim", -1)) <= 1, "Trim exceeds admitted range")
    require(all(type(value[k]) is bool for k in BUTTONS), "Nonboolean action")


def neutral_action() -> dict:
    return {"move":[0,0], "trim":0, **{key:False for key in BUTTONS}}


def state_valid(state: Any) -> None:
    require(type(state) is dict, "Missing state")
    for key in ("worker", "session", "bridge"):
        value = state.get(key)
        require(type(value) is int and -(1 << 63) <= value < (1 << 63) and value != 0,
                "Invalid exact signed identity: " + key)
    require(type(state.get("run_id")) is str and state["run_id"], "Missing run ID")
    require(state.get("backend") == "native-phased" and state.get("fault") == "", "Invalid/faulted host")
    for key in ("time_usec", "epoch", "generation", "world_generation", "tick", "step",
                "native_tick", "serial", "accepted", "rejected", "lap_ticks", "render_rejections"):
        integer(state.get(key), key)
    integer(state.get("sequence"), "sequence", -1)
    for key in ("native_paused", "paused", "suspended", "focus", "rearm", "pending"):
        require(type(state.get(key)) is bool, "Missing state flag: " + key)
    vector(state.get("position"), "position")
    vector(state.get("impulse"), "impulse")
    numeric(state.get("torque_impulse"), "torque_impulse", -1e12)
    action_valid(state.get("action"))
    require(type(state.get("edges")) is list, "Missing edge queue")
    for edge in state["edges"]:
        require(type(edge) is dict and set(edge) == {"button", "pressed"}
                and edge["button"] in BUTTONS and type(edge["pressed"]) is bool, "Invalid queued edge")


def completed(row: dict) -> bool:
    a, b = row["before"], row["after"]
    return same(a, b) and b["tick"] == a["tick"] + 1 and b["step"] == a["step"] + 1


def extract(log: str) -> dict:
    require(not re.search(r"SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b", log, re.I | re.M),
            "Original process log contains a failure or skip")
    records = [line[len(MARKER):] for line in log.splitlines() if line.startswith(MARKER)]
    require(len(records) == 1, "Expected exactly one PACE004 marker")
    result = json.loads(records[0])
    require(type(result) is dict, "Result is not an object")
    return result


def stats(values: list[int | float]) -> dict:
    require(bool(values), "Empty measurement distribution")
    for value in values:
        numeric(value, "measurement")
    ordered = sorted(values)
    return {"count": len(values), "mean": sum(values)/len(values),
            **{f"p{p}": ordered[math.ceil(len(values)*p/100)-1] for p in (50,95,99)},
            "max": ordered[-1]}


def expected_component(event: dict, rig: str) -> tuple[str, object]:
    key, pressed = event["key"], event["pressed"]
    if key in BUTTONS:
        return key, pressed
    if key.startswith("trim_"):
        return "trim", (-1 if key == "trim_left" else 1) if pressed else 0
    if not pressed:
        return "move", [0, 0]
    sign = 1 if key == "forward" else -1
    return "move", [sign, 0] if rig == "acrobat" else [0, -sign]


def verify_trace(trace: list, rig: str) -> dict:
    require(type(trace) is list and 40 < len(trace) <= 8192, "Invalid trace inventory")
    events: dict[int, dict] = {}
    outcomes: dict[int, dict] = {}
    # Each tuple retains a particular admitted source event, not just an edge
    # value. A same-looking later press cannot satisfy a dropped earlier one.
    queue: list[tuple[dict, int]] = []
    analogues: list[int] = []
    authority: dict | None = None
    last_usec = 0
    reset_requested = False
    reset_replacement_seen = False
    transitions: dict[str, dict] = {}
    physical_rows: list[dict] = []
    expected_command = neutral_action()
    expected_applied = neutral_action()

    def conclude(event_id: int, outcome: str, state: dict, ordinal: int) -> None:
        require(event_id not in outcomes, "Input event received duplicate outcomes")
        event = events[event_id]
        require(outcome == event["expected"], f"Event {event_id}: expected {event['expected']}, observed {outcome}")
        admitted = event["admissions"][0]["after"]
        outcomes[event_id] = {"id":event_id, "outcome":outcome, "ordinal":ordinal,
            "admitted_sequence":admitted["sequence"], "admitted_generation":admitted["generation"],
            "completed_tick":state["tick"] if outcome == "applied" else None,
            "completed_step":state["step"] if outcome == "applied" else None,
            "completed_generation":state["generation"],
            "admission_to_completion_usec":state["time_usec"]-admitted["time_usec"] if outcome == "applied" else None}
        if outcome == "applied":
            require(same(admitted, state) and admitted["generation"] == state["generation"],
                    "Applied input crossed authority generation")
            require(state["tick"] > admitted["tick"] and state["step"] > admitted["step"],
                    "Input outcome has no later completed physical step")
            require(state["sequence"] >= admitted["sequence"], "Applied input predates admission")
            numeric(outcomes[event_id]["admission_to_completion_usec"], "input latency")

    def reconcile(state: dict, ordinal: int, *, allow_clear: bool) -> None:
        nonlocal authority, queue, analogues, reset_replacement_seen, expected_command, expected_applied
        if authority is not None and (not same(authority, state)
                                      or authority["generation"] != state["generation"]):
            require(allow_clear, "Authority changed outside observed cancellation/reset")
            if not same(authority, state):
                require(authority["worker"] == state["worker"], "Exclusive native worker was replaced")
                require(reset_requested and not reset_replacement_seen, "Unrequested complete owner replacement")
                require(all(authority[k] != state[k] for k in ("session","bridge","run_id"))
                        and state["epoch"] > authority["epoch"]
                        and state["world_generation"] > authority["world_generation"],
                        "Reset replacement did not retire the complete old owner")
                reset_replacement_seen = True
            else:
                require(state["generation"] > authority["generation"], "Control generation regressed")
            require(state["edges"] == [], "Retired generation retained queued edges")
            for _, event_id in queue:
                conclude(event_id, "cancelled", state, ordinal)
            for event_id in analogues:
                conclude(event_id, "cancelled", state, ordinal)
            queue, analogues = [], []
            expected_command, expected_applied = neutral_action(), neutral_action()
        authority = state

    for ordinal, row in enumerate(trace, 1):
        require(type(row) is dict and row.get("ordinal") == ordinal, "Missing/duplicate/reordered trace ordinal")
        kind = row.get("kind")
        require(kind in ("event", "physics", "transition"), "Unknown trace row")
        a, b = row.get("before"), row.get("after")
        state_valid(a); state_valid(b)
        require(a["time_usec"] <= b["time_usec"] and b["time_usec"] >= last_usec, "Reordered trace time")
        # transition.before intentionally retains the actual pre-operation
        # state while intermediate callbacks run; event/physics are atomic.
        if kind != "transition":
            require(a["time_usec"] >= last_usec, "Overlapping Main operations")
        last_usec = b["time_usec"]
        if kind != "transition":
            reconcile(a, ordinal, allow_clear=reset_requested or not a["focus"] or a["paused"] or a["rearm"])
        if kind == "event":
            event_id = len(events)+1
            require(event_id <= 40 and row.get("id") == event_id, "Incorrect individual-event inventory")
            require((row.get("key"), row.get("pressed"), row.get("expected")) == EXPECTED[event_id-1],
                    "Registered input tape changed")
            require(type(row.get("pressed")) is bool and row.get("handler_calls") == 1
                    and type(row.get("admissions")) is list and len(row["admissions"]) == 1,
                    "Event did not reach exactly one production admission attempt")
            events[event_id] = row
            admission = row["admissions"][0]
            aa, ab = admission.get("before"), admission.get("after")
            state_valid(aa); state_valid(ab); action_valid(admission.get("command"))
            require(same(a, aa) and same(a, ab) and same(a, b)
                    and a["time_usec"] <= aa["time_usec"] <= ab["time_usec"] <= b["time_usec"],
                    "Input admission is not bound to its dispatch")
            require(a["tick"] == b["tick"] and a["step"] == b["step"], "Physics advanced inside event dispatch")
            accepted = ab["accepted"]-aa["accepted"]
            require(accepted in (0,1), "Unexpected number of event admissions")
            if accepted == 0:
                require(row["expected"] == "refused" and (aa["rearm"] or aa["paused"] or not aa["focus"]),
                        "Unexplained missing event admission")
                require(ab["sequence"] == aa["sequence"], "Refused input changed command sequence")
                reconcile(ab, ordinal, allow_clear=True)
                require(admission["command"] == neutral_action(), "Refused input retained a nonneutral command")
                conclude(event_id, "refused", b, ordinal)
            else:
                require(row["expected"] != "refused" and ab["sequence"] > aa["sequence"]
                        and ab["generation"] == aa["generation"], "Invalid event authority")
                component, expected = expected_component(row, rig)
                require(admission["command"][component] == expected, "Intended nonneutral event was not admitted")
                expected_command[component] = expected
                require(admission["command"] == expected_command, "Event admission changed an unrelated control")
                require(aa["edges"] == [edge for edge,_ in queue], "Event sees an unaccounted queue")
                if row["key"] in BUTTONS:
                    edge = {"button":row["key"], "pressed":row["pressed"]}
                    require(ab["edges"] == aa["edges"] + [edge], "Button event did not append its exact FIFO edge")
                    queue.append((edge,event_id))
                else:
                    require(ab["edges"] == aa["edges"], "Analogue input fabricated a button edge")
                    # This tape holds each analogue state through completion;
                    # it does not incorrectly promise discrete movement edges.
                    require(not analogues, "Analogue input superseded before a completed step")
                    analogues.append(event_id)
                    expected_applied[component] = expected
                authority = ab
        elif kind == "physics":
            require(same(a,b), "Complete owner changed inside a physical callback")
            dt, ds = b["tick"]-a["tick"], b["step"]-a["step"]
            require(dt in (0,1) and ds == dt, "Unbound or duplicate Rapier completion")
            require(row.get("started_usec") <= a["time_usec"] <= b["time_usec"]
                    and row.get("ended_usec") <= b["time_usec"], "Invalid callback timing")
            numeric(row.get("rapier_ms"), "Rapier duration")
            require(type(row.get("sampling")) is bool, "Missing callback sampling flag")
            admission = row.get("admission")
            require(type(admission) is dict, "Missing callback admission")
            if admission:
                aa,ab = admission.get("before"),admission.get("after")
                state_valid(aa);state_valid(ab);action_valid(admission.get("command"))
                require(same(a,aa) and same(a,ab)
                        and a["time_usec"] <= aa["time_usec"] <= ab["time_usec"] <= b["time_usec"]
                        and a["tick"] == aa["tick"] == ab["tick"]
                        and a["step"] == aa["step"] == ab["step"],
                        "Automatic admission is not bound to its physical callback")
                require(ab["accepted"]-aa["accepted"] in (0,1)
                        and (ab["sequence"]>aa["sequence"]) == (ab["accepted"]>aa["accepted"]),
                        "Automatic admission sequence/counter mismatch")
            else:
                require(a["pending"] and not completed(row), "Completed step lacks an automatic admission observation")
            if b["generation"] != a["generation"]:
                require(not a["focus"] or a["paused"] or a["rearm"] or a["pending"],
                        "Unexplained automatic cancellation")
                reconcile(b, ordinal, allow_clear=True)
                require(b["action"] == neutral_action(),
                        "Cancelled input reached a completed physical action")
            else:
                require(a["edges"] == [edge for edge,_ in queue], "Callback sees an unaccounted FIFO queue")
                remaining = b["edges"]
                require(len(remaining) <= len(queue), "Unobserved edge appeared during callback")
                consumed = len(queue)-len(remaining)
                require(remaining == [edge for edge,_ in queue[consumed:]], "FIFO order changed")
                if consumed:
                    require(completed(row), "Edges disappeared without a completed physical step")
                    changed: set[str] = set()
                    for edge,event_id in queue[:consumed]:
                        require(edge["button"] not in changed, "Two changes of one button in one physical step")
                        require(b["action"][edge["button"]] is edge["pressed"], "Consumed edge was not actually applied")
                        expected_applied[edge["button"]] = edge["pressed"]
                        conclude(event_id,"applied",b,ordinal)
                        changed.add(edge["button"])
                    queue = queue[consumed:]
                if completed(row):
                    require(not b["paused"] and not b["suspended"] and not b["pending"], "Completed an inadmissible step")
                    for event_id in list(analogues):
                        component, expected = expected_component(events[event_id],rig)
                        require(b["action"][component] == expected, "Admitted analogue input not applied by next completed step")
                        require(admission and admission["after"]["generation"] == b["generation"]
                                and admission["after"]["sequence"] == b["sequence"]
                                and admission["command"][component] == expected,
                                "Applied analogue input lacks its automatic sample receipt")
                        conclude(event_id,"applied",b,ordinal)
                        analogues.remove(event_id)
                authority = b
            if completed(row):
                require(not b["paused"] and not b["suspended"] and not b["pending"], "Completed an inadmissible step")
                if a["rearm"] or b["rearm"] or not a["focus"] or not b["focus"]:
                    require(b["action"] == neutral_action(), "Refused or unowned input reached a nonneutral completed step")
                require(b["action"] == expected_applied, "Completed action differs from the admitted held/edge controls")
                require(admission["command"] == expected_command,
                        "Automatic sample substituted an unobserved control")
                physical_rows.append(row)
        else:
            name = row.get("name")
            require(name in {"pause_acknowledged", "paused_window", "resume_completed", "rapid_pause",
                             "focus_lost", "focus_regained", "reset_requested", "reset_completed"}
                    and name not in transitions, "Unknown/duplicate transition")
            transitions[name] = row
            if name == "reset_requested":
                require(not reset_requested and not reset_replacement_seen and same(a,b)
                        and b["pending"] and b["paused"], "Invalid reset authority request")
                reset_requested = True
            elif name != "reset_completed":
                require(same(a,b), "Complete owner changed outside reset transition")
            if name == "rapid_pause":
                require(same(a,b) and b["generation"] > a["generation"] and b["edges"] == []
                        and b["tick"] == a["tick"] and b["step"] == a["step"] and b["rearm"] and not b["paused"],
                        "Rapid pause did not synchronously revoke pending input")
            elif name == "pause_acknowledged":
                require(same(a,b) and b["paused"] and b["native_paused"] and b["suspended"]
                        and b["serial"] > a["serial"] and b["generation"] > a["generation"], "Pause not acknowledged")
            elif name == "paused_window":
                require(same(a,b) and b["time_usec"]-a["time_usec"] >= 350000
                        and all(a[k]==b[k] for k in ("tick","step","native_tick","position","lap_ticks")),
                        "Acknowledged pause drifted")
            elif name == "resume_completed":
                require(same(a,b) and b["tick"] > a["tick"] and b["native_tick"] > a["native_tick"]
                        and not b["paused"] and not b["rearm"], "Resume did not advance real owners")
            elif name == "focus_lost":
                require(a["focus"] and not b["focus"], "Focus seam not exercised")
            elif name == "focus_regained":
                require(b["focus"] and not b["rearm"], "Focus recovery not neutral")
            elif name == "reset_completed":
                require(reset_requested and not same(a,b,INPUT_OWNER) and b["epoch"] > a["epoch"]
                        and b["world_generation"] > a["world_generation"] and b["paused"] and b["edges"] == []
                        and row.get("details",{}).get("old_session_retired") is True, "Reset did not retire old authority")
            reconcile(b,ordinal,allow_clear=True)
            if name == "reset_completed":
                require(reset_replacement_seen, "Reset completed without an observed replacement")
                reset_requested = False
    require(len(events) == 40 and set(outcomes) == set(range(1,41)), "Incomplete 40-event outcome inventory")
    require(not queue and not analogues, "Unresolved admitted input")
    require(len(transitions) == 8, "Missing lifecycle transition")
    return {"outcomes":[outcomes[i] for i in range(1,41)],
            "counts":dict(Counter(o["outcome"] for o in outcomes.values())),
            "input_latency_usec":stats([o["admission_to_completion_usec"] for o in outcomes.values()
                                         if o["outcome"] == "applied"]),
            "completed_rapier_steps":len(physical_rows),
            "physical_rows":physical_rows, "transitions":transitions}


def verify_environment(result: dict, graphical: bool, platform_name: str) -> None:
    require(platform_name in ("linux","win32"), "Unregistered process OS")
    require(result.get("platform") == ("Windows" if platform_name == "win32" else "Linux"),
            "Actual process OS differs from campaign")
    expected={"major":4,"minor":7,"patch":0,"status":"stable","build":"official","hash":GODOT_HASH}
    require(type(result.get("godot")) is dict and all(result["godot"].get(k)==v for k,v in expected.items()),
            "Actual engine build/hash differs from pinned engine")
    require(result.get("rendering_method")=="gl_compatibility" and result.get("rendering_driver")=="opengl3",
            "Actual renderer differs from registered compatibility renderer")
    require(result.get("display_server")==("X11" if graphical else "headless")
            and (not graphical or platform_name=="linux"), "Actual display differs from campaign scope")
    require(type(result.get("engine_sha256")) is str and re.fullmatch(r"[0-9a-f]{64}",result["engine_sha256"]),
            "Missing actual process executable digest")


def verify_policy(applied: dict, receipt: dict, preset: int, generation: int,
                  workers: int, platform_name: str) -> int:
    materials=(3,8,12,16,20,21,24,30,32,33,36)
    water="freemass_v1" if preset==0 else "pressure_flow_v1"
    assignments=applied.get("assignments")
    require(type(assignments) is list and len(assignments)==len(materials), "Incomplete applied policy assignments")
    for row,material in zip(assignments,materials):
        family=water if material==3 else "cellular_yield_v1"
        require(row.get("material")==material and row.get("requested_family")==family
                and row.get("applied_family")==family and row.get("applied_variant")=="reference",
                "Requested preset differs from actual applied assignments")
    require(applied.get("admission")==("current_defaults_only" if preset==0 else "qualified_candidate")
            and applied.get("refusal") is None and applied.get("normalization") is None,
            "Policy was refused, normalized, or admitted under a different contract")
    require(applied.get("platform")==("windows" if platform_name=="win32" else "linux")
            and applied.get("session_generation")==generation
            and receipt.get("session_generation")==generation, "Policy receipt belongs to another owner/platform")
    for key in ("policy_hash","catalogue_digest","capability_matrix_digest"):
        require(type(applied.get(key)) is str and re.fullmatch(r"[0-9a-f]{64}",applied[key]),"Invalid applied policy digest")
    require(applied.get("version")==applied.get("wire_version")==1
            and applied.get("family_blocks")==[] and applied.get("material_blocks")==[],
            "Registered preset acquired an unrequested parameter block")
    # Independently encode the accepted v1 policy identity (all integer fields
    # little endian). The two registered presets have no parameter blocks.
    canonical=(b"lcb-liquid-policy\0"+struct.pack("<H",1)
               +bytes.fromhex(applied["catalogue_digest"])+bytes.fromhex(applied["capability_matrix_digest"])
               +struct.pack("<H",len(materials)))
    canonical+=b"".join(struct.pack("<HBB",material,(1 if preset==0 else 3) if material==3 else 2,0)
                         for material in materials)+b"\0\0\0"
    require(hashlib.sha256(canonical).hexdigest()==applied["policy_hash"],
            "Applied policy hash differs from exact assignment bytes")
    require(receipt.get("kind")=="applied_run" and receipt.get("schema_version")==1
            and receipt.get("policy_hash")==applied["policy_hash"]
            and receipt.get("completed_tick")==0 and receipt.get("run_intent")=="exploratory"
            and receipt.get("region")==[128,128,512,256]
            and receipt.get("maximum_rule_radius")==applied.get("maximum_rule_radius")==2
            and type(receipt.get("receipt_hash")) is str and re.fullmatch(r"[0-9a-f]{64}",receipt["receipt_hash"]),
            "Missing/mismatched applied construction receipt")
    capacity=integer(receipt.get("worker_threads"),"construction capacity",1)
    require(workers==0 or capacity==1,"Construction ignored requested worker capacity")
    raw=receipt.get("canonical_bytes")
    require(type(raw) is str and len(raw)<2*1024*1024,"Missing bounded canonical construction receipt")
    values=json.loads(raw)
    require(type(values) is list and all(type(v) is int and 0<=v<=255 for v in values),"Malformed canonical construction bytes")
    require(hashlib.sha256(bytes(values)).hexdigest()==receipt["receipt_hash"],"Construction receipt digest differs from canonical bytes")
    return capacity


def measured_physics(trace: list, measurement: dict) -> list[dict]:
    begun,ended=measurement["started_usec"],measurement["ended_usec"]
    initial,final=measurement["initial"],measurement["final"]
    rows=[]
    for row in trace:
        if row["kind"]!="physics":continue
        in_window=begun<=row["started_usec"] and row["after"]["time_usec"]<=ended
        expected=in_window and same(initial,row["before"]) and same(initial,row["after"])
        require(row["sampling"] is expected,"Sampling flag differs from actual time window/owner")
        if expected and completed(row):rows.append(row)
    require(bool(rows) and len(rows)==final["tick"]-initial["tick"]==final["step"]-initial["step"],
            "Incomplete measured Rapier tick/step inventory")
    return rows


def verify_native_inventory(packets: list, native: list, begun: int, ended: int) -> None:
    expected={(row["tick"],row["serial"],row["completed_usec"]) for row in packets
              if row["native_completed"] and begun<=row["completed_usec"]<ended}
    observed={(row["tick"],row["serial"],row["completed_usec"]) for row in native}
    require(bool(expected) and len(observed)==len(native) and observed==expected,
            "Native statistics omit/duplicate actual measured owner completions")


def monotonic_counter_delta(values: list, initial: int, final: int) -> int:
    previous=integer(initial,"initial cumulative counter")
    for value in values:
        current=integer(value,"cumulative counter")
        require(current>=previous,"Cumulative counter regressed")
        previous=current
    require(integer(final,"final cumulative counter")==previous,"Final cumulative counter omits an observation")
    return final-initial


def verify_result(result: dict, rig: str, workers: int, policy: int, source: str, graphical: bool,
                  platform_name: str = "linux") -> dict:
    require(rig in RIGS and workers in (0,1) and policy in (0,2), "Unregistered configuration")
    require(result.get("schema") == "play-pace004-v1" and result.get("source_revision") == source
            and re.fullmatch(r"[0-9a-f]{40}",source) is not None, "Mismatched process source")
    require((result.get("rig"),result.get("workers_requested"),result.get("policy_preset")) == (rig,workers,policy),
            "Mismatched process configuration")
    verify_environment(result,graphical,platform_name)
    require(result.get("physics_engine") == "Rapier2D"
            and (result.get("display_server") != "headless") is graphical, "Mismatched renderer/physics scope")
    require(result.get("completed") is True and result.get("events") == 40 and result.get("failures") == 0
            and integer(result.get("assertions"),"assertions") > 0, "Incomplete/failed fixture")
    require(result.get("capture_overflow") is False and result.get("native_overflow") is False
            and result.get("worker_joined") is True and result.get("sessions_retired") == 1, "Incomplete capture/retirement")
    require(numeric(result.get("elapsed_usec"),"elapsed") <= 150000000
            and numeric(result.get("shutdown_usec"),"shutdown") <= 15000000
            and numeric(result.get("stop_join_usec"),"join") <= 15000000, "Fixture/operation deadline exceeded")
    scope=result.get("scope",{})
    for field in ("real_host","automatic_callbacks","synthetic_focus","native_samples_read_after_join","test_only_observer"):
        require(scope.get(field) is True,"Missing scope boundary: "+field)
    for field in ("physical_devices","human_feel","scanout_fps","pose_injection"):
        require(scope.get(field) is False,"Unsupported acceptance claim: "+field)
    require(scope.get("manual_physics_calls") == 0 and scope.get("retries") == 0,"Manual physics/retry")
    setup=result.get("setup",{})
    start=integer(setup.get("started_usec"),"setup start")
    ack=integer(setup.get("acknowledged_usec"),"setup ack")
    require(setup.get("deadline_usec") == start+30000000 and start <= ack <= setup["deadline_usec"],"Late Main acknowledgement")
    for wait in result.get("waits",[]):
        limit=wait.get("limit_usec")
        expected_limit=30000000 if wait.get("name") == "Main construction acknowledgement" else 15000000
        completed_at=wait.get("acknowledged_usec") if expected_limit==30000000 else wait.get("ended_usec")
        require(limit == expected_limit and wait.get("passed") is True
                and wait["started_usec"] <= completed_at <= wait["deadline_usec"]
                and wait["ended_usec"] >= completed_at
                and wait["deadline_usec"]-wait["started_usec"] <= limit,"Failed/late operation")
    require(len(result.get("waits",[])) >= 40,"Missing operation inventory")
    require(type(result.get("recipe_hash")) is str and bool(result["recipe_hash"]),"Missing course identity")
    applied=result.get("policy",{})
    receipt=result.get("receipt",{})
    reduced=verify_trace(result.get("trace"),rig)
    measurement=result.get("measurement",{})
    begun=integer(measurement.get("started_usec"),"measurement start")
    ended=integer(measurement.get("ended_usec"),"measurement end")
    require(15000000 <= ended-begun <= 30000000,"Incomplete gameplay sample")
    initial,final=measurement.get("initial"),measurement.get("final")
    state_valid(initial);state_valid(final)
    require(same(initial,final) and final["native_tick"]>initial["native_tick"]
            and final["tick"]>initial["tick"],"No actual source-bound native/physical progress")
    capacity=verify_policy(applied,receipt,policy,initial["world_generation"],workers,platform_name)
    native=result.get("native_rows",[])
    require(type(native) is list and native,"No original native completions")
    previous=None
    for row in native:
        require(row.get("statistics_ok") is True and row.get("statistics_tick") == row.get("tick")
                and row.get("generation") == initial["world_generation"] and row.get("epoch") == initial["epoch"],
                "Unbound native statistics")
        require(begun <= row.get("completed_usec",-1) < ended,"Native sample outside measurement interval")
        observed_capacity=integer(row.get("capacity"),"capacity",1)
        participants=integer(row.get("participants"),"participants")
        require(observed_capacity==capacity and participants<=observed_capacity,"Capacity substituted for participation")
        for key in ("tick","jobs","parallel_phases","visited_cells","moved_cells","overruns","serial"):
            integer(row.get(key),key)
        for key in ("native_ms","worker_step_ms","observer_usec"):
            numeric(row.get(key),key)
        require(type(row.get("phase_jobs")) is list and row["phase_jobs"],"Missing phase task inventory")
        for jobs in row["phase_jobs"]: integer(jobs,"phase jobs")
        if previous:
            require(row["tick"] == previous["tick"]+1 and row["completed_usec"] >= previous["completed_usec"],
                    "Missing/reordered native completion")
        previous=row
    packets=result.get("publication_rows")
    require(type(packets) is list and 0<len(packets)<=12000,"Missing bounded owner publication receipts")
    publications={};previous=None
    for row in packets:
        require(row.get("worker")==initial["worker"] and row.get("generation")==initial["world_generation"]
                and row.get("epoch")==initial["epoch"] and row.get("failed") is False,
                "Publication receipt belongs to another owner")
        require(type(row.get("native_completed")) is bool
                and type(row.get("paused")) is bool,"Missing actual native completion observation")
        integer(row.get("completed_usec"),"native completion time")
        require((row["native_completed"] and not row["paused"]
                 and 0<row["completed_usec"]<=row["published_usec"])
                or (not row["native_completed"] and row["completed_usec"]==0),
                "Native completion timestamp is not bound to its publication")
        for key in PUBLICATION:
            if key!="failed":integer(row.get(key),"publication "+key)
        require(0<row["render_usec"]<=row["published_usec"]<=result["trace"][-1]["after"]["time_usec"]
                and row["render_tick"]<=row["tick"] and row["render_revision"]<=row["simulation_revision"],
                "Invalid owner publication timestamp/revision")
        if previous:
            require(row["serial"]==previous["serial"]+1 and row["tick"]>=previous["tick"]
                    and row["published_usec"]>=previous["published_usec"],"Missing/reordered owner publication")
            require(row["native_completed"] is (row["tick"]>previous["tick"]),
                    "Native tick progress differs from completion observation")
        publications[row["serial"]]=row;previous=row
    for row in native:
        packet=publications.get(row["serial"],{})
        require(packet.get("tick")==row["tick"] and packet.get("paused") is False
                and row["completed_usec"]<=packet.get("published_usec",-1),
                "Native completion lacks its actual owner publication")
    verify_native_inventory(packets,native,begun,ended)
    main=result.get("main_rows",[])
    require(type(main) is list and len(main)>2,"No Main samples")
    last=initial["serial"]
    coalesced=0
    previous=None
    for row in main:
        require(row.get("failed") is False and row.get("epoch") == initial["epoch"]
                and row.get("generation") == initial["world_generation"],"Mismatched/faulted publication")
        require(begun <= row["started_usec"] <= row["ended_usec"] <= ended
                and 0 < row["published_usec"] <= row["ended_usec"]
                and 0 < row["render_usec"] <= row["ended_usec"],"Fabricated/invalid snapshot timestamp")
        require(row["serial"]>=last and row["render_revision"]<=row["simulation_revision"],"Regressed source publication")
        require(same(row,publications.get(row["serial"],{}),PUBLICATION),
                "Main snapshot has no matching actual owner publication")
        integer(row.get("rejected_render_snapshots"),"render rejection count")
        coalesced+=max(0,row["serial"]-last-1);last=row["serial"]
        if previous: require(row["started_usec"]>=previous["ended_usec"],"Reordered Main callback")
        previous=row
    waits=result.get("snapshot_mutex_wait_usec",[])
    critical=result.get("snapshot_mutex_critical_usec",[])
    require(len(waits)==len(main)==len(critical)
            and result.get("snapshot_returns_new",-1)+result.get("snapshot_returns_none",-1)==len(main),
            "Snapshot acquisition inventory differs from Main callbacks")
    draws=result.get("draw_usec",[])
    require((type(draws) is list and len(draws)>1) if graphical else draws==[],"False graphical/headless submission claim")
    require(all(begun<=t<=ended for t in draws) and all(a<=b for a,b in zip(draws,draws[1:])),"Invalid draw ordering")
    visual=result.get("visual",{})
    require(visual.get("executed") is graphical,"Missing/unexpected visual control")
    reduced.pop("physical_rows")
    sample_physics=measured_physics(result["trace"],measurement)
    render_rejections=monotonic_counter_delta([r["rejected_render_snapshots"] for r in main],
                                              initial["render_rejections"],final["render_rejections"])
    result_summary={"rig":rig,"requested_workers":workers,"policy_preset":policy,
        "scope":"graphical submissions and actor/terrain controls" if graphical else "headless native/Rapier only",
        "events":reduced["counts"],"input_outcomes":reduced["outcomes"],"input_latency_usec":reduced["input_latency_usec"],
        "native_completed_hz":len(native)*1e6/(ended-begun),
        "native_completed_ticks":len(native),"native_ms":stats([r["native_ms"] for r in native]),
        "native_observer_usec":stats([r["observer_usec"] for r in native]),
        "configured_capacity":sorted({r["capacity"] for r in native}),
        "actual_participants":stats([r["participants"] for r in native]),
        "parallel_phases":stats([r["parallel_phases"] for r in native]),
        "scheduler_jobs":stats([r["jobs"] for r in native]),
        "rapier_completed_hz":len(sample_physics)*1e6/(ended-begun),
        "rapier_step_ms":stats([r["rapier_ms"] for r in sample_physics]),
        "main_callback_usec":stats([r["ended_usec"]-r["started_usec"] for r in main]),
        "main_interval_usec":stats([b["started_usec"]-a["started_usec"] for a,b in zip(main,main[1:])]),
        "snapshot_age_usec":stats([r["ended_usec"]-r["published_usec"] for r in main]),
        "retained_render_age_usec":stats([r["ended_usec"]-r["render_usec"] for r in main]),
        "render_revision_lag":stats([r["simulation_revision"]-r["render_revision"] for r in main]),
        "snapshot_acquisition_wait_usec":stats(waits),"snapshot_critical_usec":stats(critical),
        "coalesced_publication_serials":coalesced,"no_new_snapshot_returns":result["snapshot_returns_none"],
        "owner_publications_in_window":sum(begun<=r["published_usec"]<ended for r in packets),
        "retained_boundary_publications":sum(r["published_usec"]<begun for r in packets),
        "render_snapshot_rejections":render_rejections,
        "draw_submissions":len(draws),"displayed_fps":None,
        "construction_ack_usec":ack-start,"shutdown_usec":result["shutdown_usec"],"join_usec":result["stop_join_usec"],
        "lifecycle_usec":{k:r["after"]["time_usec"]-r["before"]["time_usec"] for k,r in reduced["transitions"].items()}}
    if draws:
        result_summary["draw_submission_interval_usec"]=stats([b-a for a,b in zip(draws,draws[1:])])
    return result_summary


def png_rgb(path: Path) -> tuple[int,int,list[bytes]]:
    """Decode Godot's bounded, noninterlaced 8-bit RGB/RGBA PNG for offline QA."""
    data=path.read_bytes()
    require(len(data)<=8*1024*1024 and data.startswith(b"\x89PNG\r\n\x1a\n"),"Invalid bounded PNG")
    offset=8;payload=bytearray();header=None;ended=False
    while offset<len(data):
        require(offset+12<=len(data),"Truncated PNG")
        size=struct.unpack_from(">I",data,offset)[0];kind=data[offset+4:offset+8]
        body=data[offset+8:offset+8+size]
        require(len(body)==size and offset+12+size<=len(data),"Truncated PNG chunk")
        require(zlib.crc32(kind+body)&0xffffffff==struct.unpack_from(">I",data,offset+8+size)[0],"PNG CRC failed")
        if kind==b"IHDR":
            require(header is None and size==13,"Duplicate/malformed PNG header")
            header=struct.unpack(">IIBBBBB",body)
        elif kind==b"IDAT":payload.extend(body)
        elif kind==b"IEND":ended=True;offset+=size+12;break
        offset+=size+12
    require(header is not None and ended and offset==len(data),"Incomplete PNG")
    width,height,depth,color,compression,filtering,interlace=header
    require((width,height)==(960,540) and depth==8 and color in (2,6)
            and compression==filtering==interlace==0,"Unsupported or wrong-size PNG")
    channels=3 if color==2 else 4;stride=width*channels
    raw=zlib.decompress(bytes(payload),bufsize=(stride+1)*height)
    require(len(raw)==(stride+1)*height,"PNG scanline size mismatch")
    rows=[];prior=bytearray(stride)
    for y in range(height):
        mode=raw[y*(stride+1)];scan=bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)])
        require(mode in range(5),"Invalid PNG filter")
        for x in range(stride) if mode else ():
            a=scan[x-channels] if x>=channels else 0;b=prior[x];c=prior[x-channels] if x>=channels else 0
            if mode==1:predict=a
            elif mode==2:predict=b
            elif mode==3:predict=(a+b)//2
            elif mode==4:
                p=a+b-c;pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
                predict=a if pa<=pb and pa<=pc else b if pb<=pc else c
            else:predict=0
            scan[x]=(scan[x]+predict)&255
        rows.append(bytes(scan) if channels==3 else b"".join(scan[x:x+3] for x in range(0,stride,4)))
        prior=scan
    return width,height,rows


def inside(x: float,y: float,vertices: list) -> bool:
    result=False
    previous=vertices[-1]
    for current in vertices:
        if (current[1]>y)!=(previous[1]>y) and x<(previous[0]-current[0])*(y-current[1])/(previous[1]-current[1])+current[0]:
            result=not result
        previous=current
    return result


def verify_visual(result: dict, directory: Path) -> dict:
    visual=result["visual"]
    if not visual["executed"]:
        require(visual=={"executed":False,"reason":"headless"},"False visual evidence")
        return {"executed":False}
    require(visual.get("physics_pose_injected") is False and visual.get("layer_removal_after_measurement") is True,
            "Wrong visual control scope")
    frames=visual.get("frames",{})
    names=("baseline","unchanged","without_actor","without_terrain","restored")
    require(set(frames)==set(names),"Incomplete visual-control inventory")
    images={};lastdraw=-1
    for name in names:
        receipt=frames[name]
        require(receipt.get("file")==name+".png" and receipt.get("saved") is True,"Wrong visual artifact")
        path=directory/receipt["file"]
        require(path.is_file() and not path.is_symlink() and hashlib.sha256(path.read_bytes()).hexdigest()==receipt["sha256"],
                "Original visual artifact missing/changed")
        require(integer(receipt.get("draw_count"),"draw count")>lastdraw,"Reused/fabricated draw")
        lastdraw=receipt["draw_count"]
        images[name]=png_rgb(path)[2]
    polygons=visual.get("actor_polygons",[])
    require(type(polygons) is list and polygons,"No actual actor geometry")
    actor_pixels=set()
    for polygon in polygons:
        vertices=polygon.get("vertices",[])
        require(len(vertices)>=3,"Missing actual actor polygon")
        for vertex in vertices:vector(vertex,"screen vertex")
        minx=max(0,math.floor(min(v[0] for v in vertices)));maxx=min(960,math.ceil(max(v[0] for v in vertices)))
        miny=max(0,math.floor(min(v[1] for v in vertices)));maxy=min(540,math.ceil(max(v[1] for v in vertices)))
        for y in range(miny,maxy):
            for x in range(minx,maxx):
                if inside(x+.5,y+.5,vertices):actor_pixels.add((x,y))
    require(len(actor_pixels)>=8,"Actual actor not visibly in viewport")
    def changed(first,second,pixels):
        return sum(sum(abs(first[y][x*3+c]-second[y][x*3+c]) for c in range(3))>24 for x,y in pixels)
    actor_noise=changed(images["baseline"],images["unchanged"],actor_pixels)
    actor_delta=changed(images["baseline"],images["without_actor"],actor_pixels)
    restored_noise=changed(images["baseline"],images["restored"],actor_pixels)
    require(actor_delta>=5 and actor_delta>2*actor_noise and restored_noise<actor_delta,
            "Actor pixels not distinguished from unchanged/removed controls")
    rect=visual.get("world_rect")
    require(type(rect) is list and len(rect)==4,"Missing actual world viewport")
    x0,y0,w,h=rect
    terrain_pixels={(x,y) for y in range(max(0,math.ceil(y0)),min(540,math.floor(y0+h)),3)
                         for x in range(max(0,math.ceil(x0)),min(960,math.floor(x0+w)),3)
                         if (x,y) not in actor_pixels}
    terrain_noise=changed(images["baseline"],images["unchanged"],terrain_pixels)
    terrain_delta=changed(images["baseline"],images["without_terrain"],terrain_pixels)
    require(terrain_delta>=100 and terrain_delta>2*terrain_noise,"Terrain pixels absent or indistinguishable from animation noise")
    return {"executed":True,"actor_pixels":len(actor_pixels),"actor_removed_changed":actor_delta,
            "unchanged_actor_noise":actor_noise,"restored_actor_noise":restored_noise,
            "terrain_removed_changed":terrain_delta,"unchanged_terrain_noise":terrain_noise,
            "qualification":"actual rendered actor/terrain controls; software submissions, not physical scanout or human feel"}
