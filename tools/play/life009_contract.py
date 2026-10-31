#!/usr/bin/env python3
"""Strict, engine-independent reduction of original PLAY-LIFE-009 observations."""
from __future__ import annotations

import json
import math
import re
from collections import Counter
from typing import Any

RIGS = ("stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel")
MARKER = "PLAY_LIFE009_RESULT "
OWNERS = ("worker", "session", "bridge", "run_id", "epoch", "world_generation")
PHASES = ("dropped", "neutral_before", "active", "pausing", "paused", "held", "neutral_after", "fresh")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def number(value: Any, label: str, *, minimum: float = 0) -> float:
    require(type(value) in (int, float) and math.isfinite(value) and value >= minimum,
            "Invalid numeric field: " + label)
    return value


def vector(value: Any, label: str) -> list:
    require(isinstance(value, list) and len(value) == 2, "Invalid vector: " + label)
    for component in value:
        number(component, label, minimum=-1e12)
    return value


def same_owner(reference: dict, state: dict) -> None:
    require(all(k in state and state[k] == reference[k] for k in OWNERS), "Owner identity changed")


def state_valid(reference: dict, state: dict) -> None:
    require(isinstance(state, dict), "Missing state")
    same_owner(reference, state)
    require(state.get("native_backend") == "native-phased", "Fallback/non-native backend refused")
    for name in ("time_usec", "physics_tick", "bridge_step", "native_tick", "snapshot_serial",
                 "control_generation", "pending_edges", "main_callbacks", "physics_callbacks",
                 "accepted_commands", "lap_ticks"):
        number(state.get(name), name)
    number(state.get("sequence"), "sequence", minimum=-1)
    for name in ("paused", "native_paused", "suspended", "rearm"):
        require(type(state.get(name)) is bool, "Missing boolean: " + name)
    require(state.get("fault") == "", "Physical owner faulted")
    vector(state.get("position"), "position")
    vector(state.get("move"), "move")


def completed(record: dict) -> bool:
    before, after = record["before"], record["after"]
    return (after["physics_tick"] == before["physics_tick"] + 1
            and after["bridge_step"] == before["bridge_step"] + 1)


def extract(log: str) -> dict:
    require(not re.search(r"SCRIPT ERROR:|ERROR:|\bskipped\b|^\s*SKIP\b", log, re.M | re.I),
            "Original log contains a failure or skip")
    lines = [line[len(MARKER):] for line in log.splitlines() if line.startswith(MARKER)]
    require(len(lines) == 1, "Expected exactly one LIFE009 result marker")
    result = json.loads(lines[0])
    require(isinstance(result, dict), "Result is not an object")
    return result


def verify_process(process: dict, limit: int) -> None:
    require(process.get("status") == "passed" and type(process.get("returncode")) is int
            and process["returncode"] == 0, "Process did not pass")
    require(process.get("timeout_seconds") == limit, "Process deadline changed")
    require(number(process.get("seconds"), "process.seconds") <= limit, "Late process exit")
    require(not process.get("skip_messages") and not process.get("diagnostic_error")
            and not process.get("launch_error") and not process.get("capture_error"),
            "Process evidence contains an error")


def verify_result(result: dict, rig: str, source: str) -> dict:
    require(rig in RIGS and result.get("rig") == rig, "Wrong rig")
    require(result.get("schema") == "play-life009-v2" and result.get("source_revision") == source,
            "Wrong schema/source")
    require(result.get("display_server") == "headless" and result.get("physics_engine") == "Rapier2D",
            "Wrong display or physics engine")
    for field in ("real_host", "automatic_callbacks", "headless_focus_seam",
                  "input_suppression_is_negative_control", "worker_joined", "session_retired"):
        require(result.get(field) is True, "Required evidence absent: " + field)
    for field in ("rendered_fps_measured", "physical_devices_qualified", "human_feel_qualified",
                  "shader_startup_qualified"):
        require(result.get(field) is False, "Unsupported qualification: " + field)
    require(result.get("failures") == 0 and number(result.get("assertions"), "assertions") > 0,
            "Fixture assertions failed")
    require(result.get("manual_physics_calls") == 0 and result.get("retries") == 0, "Manual step/retry")
    require(number(result.get("elapsed_usec"), "elapsed_usec") <= 150_000_000, "Fixture exceeded 150s")
    require(number(result.get("teardown_usec"), "teardown_usec") <= 15_000_000, "Teardown exceeded 15s")
    row = result.get("row", {})
    require(row.get("rig") == rig and row.get("completed") is True
            and row.get("capture_overflow") is False, "Incomplete bounded fixture")
    reference = row.get("identity", {})
    require(all(k in reference for k in OWNERS), "Incomplete owner identity")
    require(isinstance(reference["run_id"], str) and bool(reference["run_id"]), "Empty run identity")
    # ObjectID reserves bit63 for RefCounted; Variant exposes signed int64.
    # Preserve exact signed identities, never abs(), floats or a positivity test.
    for key in ("worker", "session", "bridge"):
        value = reference[key]
        require(type(value) is int and -(1 << 63) <= value < (1 << 63) and value != 0,
                "Invalid signed object identity: " + key)
    require(number(reference["epoch"], "epoch") > 0, "Invalid actor epoch")
    require(isinstance(row.get("recipe_hash"), str) and bool(row["recipe_hash"]), "No course identity")
    require(number(row.get("worker_capacity"), "worker_capacity") >= 1, "No native capacity")
    move = [1, 0] if rig == "acrobat" else [0, -1]
    require(row.get("expected_move") == move, "Wrong registered input")
    waits = row.get("waits", [])
    require(len(waits) >= 10, "Missing operations")
    for wait in waits:
        start, end, deadline = (number(wait.get(k), k) for k in
                                ("started_usec", "ended_usec", "deadline_usec"))
        require(wait.get("passed") is True and start <= end <= deadline
                and 0 < deadline - start <= 15_000_000, "Late/absent operation")
    records = row.get("records", [])
    require(20 <= len(records) <= 512, "Invalid observation count")
    grouped: dict[str, list] = {p: [] for p in PHASES}
    phase_index, last = 0, None
    for record in records:
        phase = record.get("phase")
        require(phase in PHASES and PHASES.index(phase) >= phase_index, "Invalid phase ordering")
        phase_index = PHASES.index(phase)
        before, after = record.get("before", {}), record.get("after", {})
        state_valid(reference, before)
        state_valid(reference, after)
        require(before["time_usec"] <= after["time_usec"], "Reversed callback")
        if last:
            require(before["time_usec"] >= last["time_usec"], "Reordered observations")
            for field in ("physics_tick", "bridge_step", "native_tick", "control_generation",
                          "main_callbacks", "physics_callbacks", "accepted_commands"):
                require(before[field] >= last[field], "Regressed observation: " + field)
        require(after["physics_tick"] - before["physics_tick"] in (0, 1)
                and after["bridge_step"] - before["bridge_step"]
                == after["physics_tick"] - before["physics_tick"], "Unbound physical completion")
        require(record.get("dropped_input_control") is (phase == "dropped"), "Incorrect negative-control label")
        require(isinstance(record.get("prepared"), dict), "Missing admission record")
        last = after
        grouped[phase].append(record)
    for phase in ("dropped", "active", "held", "fresh"):
        rows = [r for r in grouped[phase] if completed(r)]
        require(len(rows) >= 4, "Missing automatic completed steps: " + phase)
        for record in rows:
            after, prep = record["after"], record["prepared"]
            require(not after["paused"] and not after["suspended"], "Completed a suspended step")
            if phase in ("dropped", "held"):
                require(not prep and after["move"] == [0, 0], "Suppressed/held input actuated")
                if phase == "held":
                    require(after["rearm"] and after["pending_edges"] == 0, "Held input bypassed rearm")
            else:
                require(prep.get("move") == move and after["move"] == move,
                        "Nonneutral input not actually applied")
                require(prep.get("sequence") == after["sequence"]
                        and prep.get("control_generation") == after["control_generation"]
                        and prep.get("admitted_tick") == record["before"]["physics_tick"],
                        "Admission not bound to completed step")
                require(after["accepted_commands"] > record["before"]["accepted_commands"],
                        "No admission in observed callback")
    edges = row.get("queued_edges_before_pause")
    require(edges == [{"button": "primary", "pressed": True},
                      {"button": "primary", "pressed": False}], "No real queued quick tap")
    pre, ack, end, final = (row.get(k, {}) for k in ("pre_pause", "pause_ack", "pause_end", "final"))
    for state in (pre, ack, end, final):
        state_valid(reference, state)
    require(ack["snapshot_serial"] > pre["snapshot_serial"]
            and ack["control_generation"] > pre["control_generation"], "Pause not acknowledged/revoked")
    require(end["time_usec"] - ack["time_usec"] >= 350_000
            and end["main_callbacks"] > ack["main_callbacks"], "Pause observation/callback window absent")
    require(len(grouped["paused"]) >= 8, "Insufficient automatic paused observations")
    stable = ("physics_tick", "bridge_step", "native_tick", "position", "lap_ticks")
    for state in [ack, end] + [r["after"] for r in grouped["paused"]]:
        require(state["paused"] and state["native_paused"] and state["suspended"]
                and state["rearm"] and state["pending_edges"] == 0, "Pause fence absent")
        require(all(state[k] == ack[k] for k in stable), "Owner advanced while paused")
    denied = row.get("stale_refusal", {})
    require(denied.get("accepted") is False and denied.get("reason") == "observation_not_issued"
            and denied.get("accepted_delta") == 0 and denied.get("rejected_delta") == 1
            and denied.get("sequence_before") == denied.get("sequence_after"), "Stale authority not refused")
    observed, actual = (number(denied.get(k), k) for k in ("observed_tick", "actual_tick"))
    require(0 <= actual - observed < 18, "Expired command cannot prove generation refusal")
    require(final["native_tick"] > end["native_tick"], "Native did not resume")
    require(all(r["after"]["control_generation"] > pre["control_generation"] for r in grouped["fresh"]),
            "Fresh input reused pre-pause generation")
    return {"rig": rig, "observed_callbacks": len(records), "paused_callbacks": len(grouped["paused"]),
            "completed_steps_by_phase": {p: sum(completed(r) for r in grouped[p]) for p in PHASES},
            "pause_observed_usec": end["time_usec"] - ack["time_usec"],
            "same_owner": True, "stale_observation_refused": True,
            "scope": "headless automatic callbacks; no graphical/device/human-feel qualification"}


def verify_inventory(rigs: list[str]) -> None:
    require(Counter(rigs) == Counter(RIGS), "Every mechanical rig must execute exactly once")
