#!/usr/bin/env python3
"""Join additive causal observations to separately proven real Rapier steps.

Transaction entry is a gate observation, never step credit. The focused runner
must first pass the unchanged v3 validation. This reducer also verifies the
sidecar's hashes, ownership, boundedness and one-to-one completion joins.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

from audit_traces import distribution, require, sha256


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def main_key(row):
    return (row["world_generation"], row["packet_session"], row["rigid_body_epoch"],
            row["tick_index"], row["completed_body_sample"], row["required_hard_revision"])


def worker_key(row):
    return (row["world_generation"], row["session"], row["rigid_body_epoch"],
            row["tick_index"], row["body_sample"], row["required_hard_revision"])


def step_key(row):
    return (row["world_generation"], row["session"], row["epoch"],
            row["native_tick_used"], row["completed_body_sample"], row["required_hard_revision"])


def healthy_packet(row):
    return (row.get("packet_present") is True and row.get("simulation_failed") is False
            and row.get("native_refusal") == ""
            and row.get("packet_hard_revision") == row.get("required_hard_revision"))


LEGACY_MAIN_EVENTS = {"mailbox_observation", "terrain_install", "transaction_entry"}
COMPLETION_MAIN_EVENTS = {"main_process_entry", "main_process_exit", "material_consumption",
                          "physics_callback_entry", "native_response_application", "transaction_exit"}


def validate_main_event(row):
    event = row.get("event")
    require(event in LEGACY_MAIN_EVENTS | COMPLETION_MAIN_EVENTS, "Unknown Main causal event")
    require(type(row.get("trace_version", 1)) is int and row.get("trace_version", 1) in (1, 2),
            "Unknown Main causal version")
    if event not in COMPLETION_MAIN_EVENTS:
        return
    require(row.get("trace_version") == 2, "Completion event needs explicit version 2")
    if event in {"main_process_entry", "main_process_exit", "physics_callback_entry"}:
        require(row.get("packet_present") is False, "Callback boundary cannot claim a packet read")
    if event == "physics_callback_entry":
        require(integer(row.get("manual_steps")) and type(row.get("paused")) is bool,
                "Invalid callback counters")
    if event == "material_consumption":
        require(integer(row.get("uploaded_serial")) and integer(row.get("ack_serial"))
                and row["ack_serial"] <= row["uploaded_serial"], "ACK exceeds accepted material upload")
    if event == "native_response_application":
        require(type(row.get("accepted")) is bool and isinstance(row.get("refusal"), str)
                and integer(row.get("application_snapshot"), -1), "Invalid native application result")
        if row["accepted"]:
            require(integer(row.get("snapshot_serial"), 1)
                    and row["application_snapshot"] == row["snapshot_serial"],
                    "Accepted response belongs to another snapshot")
    if event == "transaction_exit":
        require(integer(row.get("manual_steps_after")) and integer(row.get("next_requested_sample"), -1),
                "Invalid transaction exit counters")


def validate_completion_joins(main, steps, entries):
    """Additional observations never replace the independent real-step oracle."""
    applications = [row for row in main if row["event"] == "native_response_application"]
    exits = [row for row in main if row["event"] == "transaction_exit"]
    joined = {}
    for step in steps:
        entry = entries[step["step"]]
        if entry.get("trace_version", 1) == 1:
            continue  # Historical evidence did not capture these boundaries.
        common = lambda row: (healthy_packet(row) and main_key(row) == step_key(step)
                              and integer(row.get("snapshot_serial"), 1)
                              and row["snapshot_serial"] == step["native_snapshot_serial"]
                              and row["origin_callback_id"] == step["origin_callback_id"])
        matches = [row for row in applications if common(row)
                   and row["physical_tick"] == step["step"] - 1
                   and entry["time_usec"] <= row["time_usec"] <= step["time_usec"]]
        require(len(matches) == 1, "Completion lacks one exact native application observation")
        ends = [row for row in exits if common(row) and row["physical_tick"] == step["step"]
                and row["manual_steps_after"] == step["manual_steps"]
                and row["time_usec"] >= step["time_usec"]]
        require(len(ends) == 1, "Completion lacks one exact transaction exit")
        application = matches[0]
        require(type(step.get("response_accepted")) is bool
                and isinstance(step.get("response_refusal"), str)
                and application["accepted"] == step["response_accepted"]
                and application["refusal"] == step["response_refusal"],
                "Native application result differs from actual completed step")
        joined[step["step"]] = {"accepted": application["accepted"],
            "refusal": application["refusal"],
            "snapshot_matches": application["application_snapshot"] == application["snapshot_serial"],
            "application_usec": application["time_usec"], "exit_usec": ends[0]["time_usec"]}
    return joined


def validate_transaction_joins(main, steps):
    entries = [r for r in main if r["event"] == "transaction_entry"]
    for row in entries:
        require("admitted" not in row and "completed_step" not in row,
                "Transaction entry cannot claim admission/completion authority")
        require(row.get("native_and_terrain_gate_passed") is True and healthy_packet(row)
                and row.get("pending_hard_chunks") == 0,
                "Transaction entry has an unhealthy native/terrain gate")
    matched, used = {}, set()
    for step in steps:
        candidates = [(i, row) for i, row in enumerate(entries)
                      if main_key(row) == step_key(step)
                      and row["origin_callback_id"] == step["origin_callback_id"]
                      and row["physical_tick"] == step["step"] - 1
                      and row["manual_steps_before"] == step["manual_steps"] - 1
                      and row["time_usec"] <= step["time_usec"]]
        require(len(candidates) == 1, "Real Rapier completion lacks one exact transaction-entry observation")
        index, entry = candidates[0]
        if entry.get("trace_version", 1) == 2:
            require(integer(entry.get("snapshot_serial"), 1)
                    and integer(step.get("native_snapshot_serial"), 1)
                    and entry["snapshot_serial"] == step["native_snapshot_serial"],
                    "Transaction entry snapshot differs from actual completed step")
        require(index not in used, "Transaction entry reused for multiple completed steps")
        used.add(index)
        matched[step["step"]] = entry
    return matched, len(entries) - len(used)


def analyze(identity, events, receipt, base_events):
    enabled = identity["enabled"]
    require(type(enabled) is bool, "Causal enablement must be explicit")
    require(identity.get("main_overflow") is False and identity.get("worker_dropped") == 0,
            "Causal trace overflow is not an admissible sample")
    main = [r for r in events if r.get("observer_owner") == "main"]
    worker = [r for r in events if r.get("observer_owner") == "worker"]
    require(len(main) + len(worker) == len(events), "Unknown causal event owner")
    require(len(main) <= identity["main_capacity"] and len(worker) <= identity["worker_capacity"],
            "Causal trace exceeds recorded bounds")
    if not enabled:
        require(not events, "Disabled causal observer emitted events")
        return {"schema": "pubpres003-causal-analysis-v1", "enabled": False,
                "physical_acceptance": "HOLD", "causal_events": 0}
    require(main and worker, "Enabled causal capture is missing an owner channel")
    versions = [row.get("trace_version", 1) for row in main]
    require(all(type(version) is int and version in (1, 2) for version in versions),
            "Unknown Main causal version")
    require(len(set(versions)) == 1,
            "Mixed Main causal versions cannot omit completion evidence")
    owner = receipt["physical_owner_before"]
    for row in main:
        validate_main_event(row)
        require(integer(row.get("start_usec"), 1) and integer(row.get("time_usec"), 1)
                and row["start_usec"] <= row["time_usec"], "Invalid Main causal chronology")
        require(row["current_epoch"] == owner["epoch"] and row["current_session"] == owner["session"],
                "Main causal owner changed")
    for row in worker:
        require(isinstance(row.get("kind"), str), "Missing worker event kind")
        if "start_usec" in row and "completed_usec" in row:
            require(integer(row["start_usec"], 1) and integer(row["completed_usec"], 1)
                    and row["start_usec"] <= row["completed_usec"], "Invalid worker causal chronology")
    steps = sorted((r for r in base_events if r["event"] == "rapier_step"), key=lambda r: r["step"])
    require(steps, "Causal observations cannot substitute for real Rapier completions")
    entries, uncompleted_entries = validate_transaction_joins(main, steps)
    completion_joins = validate_completion_joins(main, steps, entries)
    publications, observations, native_ticks, terrain = defaultdict(list), defaultdict(list), {}, defaultdict(list)
    for row in worker:
        if row["kind"] == "physics_publication":
            require(row["packet_hard_revision"] == row["required_hard_revision"], "Published physics terrain differs")
            publications[worker_key(row)].append(row)
        if row["kind"] == "native_tick":
            key = (row["world_generation"], row["session"], row["rigid_body_epoch"], row["tick_index"], row["body_sample"])
            require(key not in native_ticks, "Repeated native completion identity")
            native_ticks[key] = row
    for row in main:
        if not healthy_packet(row):
            continue
        key = main_key(row)
        if row["event"] == "mailbox_observation":
            observations[key].append(row)
        if row["event"] == "terrain_install" and row["operation"] == "check" and row["ready"]:
            require(row["pending_after"] == 0 and row["queued_revision_after"] == row["required_hard_revision"],
                    "Terrain ready check lacks a completed matching install")
            terrain[key[:3] + (key[-1],)].append(row)
    joined, unavailable = [], []
    for step in steps:
        key = step_key(step)
        entry = entries[step["step"]]
        native = native_ticks.get(key[:5])
        available = [r for r in publications[key] if r["completed_usec"] <= entry["time_usec"]]
        observed = [r for r in observations[key] if r["time_usec"] <= entry["time_usec"]]
        if not native or not available or not observed:
            # Capture boundaries may omit a pre-capture bootstrap/retained
            # packet. This is disclosed, not a zero-age producer claim.
            unavailable.append({"step": step["step"], "key": list(key),
                                "missing": [label for label, value in (("native_tick", native),
                                    ("physics_publication", available), ("mailbox_observation", observed)) if not value]})
            continue
        publication = min(available, key=lambda r: r["completed_usec"])
        observation = min(observed, key=lambda r: r["time_usec"])
        complete, publish, observe = native["completed_usec"], publication["completed_usec"], observation["time_usec"]
        require(complete == step["native_completed_usec"] and complete <= publish <= observe <= entry["time_usec"] <= step["time_usec"],
                "Matched native/mailbox/transaction/completion chronology differs")
        ready = [r for r in terrain[key[:3] + (key[-1],)] if r["time_usec"] <= entry["time_usec"]]
        ready_usec = min((r["time_usec"] for r in ready), default=None)
        joined.append({"step": step["step"], "key": list(key), "native_started_usec": native["start_usec"],
            "native_completed_usec": complete, "first_healthy_publication_usec": publish,
            "first_matching_observation_usec": observe, "first_matching_terrain_ready_usec": ready_usec,
            "transaction_entry_usec": entry["time_usec"], "rapier_completed_usec": step["time_usec"],
            "native_response_application": completion_joins.get(step["step"]),
            "origin_callback_id": step["origin_callback_id"], "process_frame": step["process_frame"],
            "native_compute_ms": (complete - native["start_usec"]) / 1000,
            "native_complete_to_publish_ms": (publish - complete) / 1000,
            "published_to_observed_ms": (observe - publish) / 1000,
            "observed_to_transaction_ms": (entry["time_usec"] - observe) / 1000,
            "observed_until_terrain_ready_ms": max(0, ready_usec - observe) / 1000 if ready_usec is not None else None,
            "terrain_already_ready_at_observation": ready_usec <= observe if ready_usec is not None else None,
            "transaction_to_completion_ms": (step["time_usec"] - entry["time_usec"]) / 1000})
    # The ordinary complete capture must have real interior causal joins.
    # Missing edge observations stay explicit; a wholly unrelated sidecar fails.
    require(joined, "No exact native-to-Rapier transaction could be joined")
    phase_spans = defaultdict(list)
    for row in worker:
        if "start_usec" in row and "completed_usec" in row:
            phase_spans[row["kind"]].append((row["completed_usec"] - row["start_usec"]) / 1000)
    main_spans = defaultdict(list)
    for row in main:
        if row["event"] in {"main_process_exit", "material_consumption"}:
            main_spans[row["event"]].append((row["time_usec"] - row["start_usec"]) / 1000)
    mailbox = [r for r in main if r["event"] == "mailbox_observation"]
    outcomes = Counter()
    for row in mailbox:
        if not row["packet_present"]:
            outcomes["no_packet:" + row["status"]] += 1
        elif row["simulation_failed"] or row["native_refusal"]:
            outcomes["native_failed_or_refused"] += 1
        elif row["completed_body_sample"] != row["requested_sample"]:
            outcomes["observed_other_body_sample"] += 1
        elif row["packet_hard_revision"] != row["required_hard_revision"]:
            outcomes["observed_incomplete_terrain_packet"] += 1
        elif row["rigid_body_epoch"] != row["current_epoch"] or row["packet_session"] != row["current_session"]:
            outcomes["observed_other_owner"] += 1
        else:
            outcomes["matching_healthy_packet_observed"] += 1
    return {"schema": "pubpres003-causal-analysis-v1", "enabled": True, "physical_acceptance": "HOLD",
        "actual_completed_rapier_steps": len(steps), "transaction_entries_without_completion": uncompleted_entries,
        "matched_native_to_rapier_transactions": len(joined), "unavailable_producer_joins": unavailable,
        "main_event_counts": dict(Counter(r["event"] for r in main)),
        "worker_event_counts": dict(Counter(r["kind"] for r in worker)),
        "mailbox_observation_outcomes": dict(outcomes),
        "worker_phase_wall_ms": {k: distribution(v) for k, v in phase_spans.items()},
        "main_phase_wall_ms": {k: distribution(v) for k, v in main_spans.items()},
        "exact_application_and_exit_joins": len(completion_joins),
        "native_response_application_outcomes": dict(Counter(
            "accepted" if row["accepted"] else "refused:" + row["refusal"]
            for row in completion_joins.values())),
        "transaction_latency_ms": {key: distribution(r[key] for r in joined if r[key] is not None)
            for key in ("native_compute_ms", "native_complete_to_publish_ms", "published_to_observed_ms",
                        "observed_to_transaction_ms", "observed_until_terrain_ready_ms", "transaction_to_completion_ms")},
        "transactions": joined,
        "scope": "Exact joined scalar observations. Native gates/transaction entry are not completion credit. CPU draw callbacks are not GPU completion. Missing boundary observations remain unavailable."}


def reduce_causal(receipt_path, expected_enabled):
    path = Path(receipt_path)
    receipt = json.loads(path.read_text())
    extension = receipt.get("observer_extension", {})
    require(extension.get("schema") == "pubpres003-causal-sidecar-v1"
            and extension.get("enabled") is expected_enabled, "Causal sidecar selection differs")
    sidecar = path.with_name(path.stem + "-causal-events.jsonl")
    require(sha256(sidecar) == extension["sha256"], "Causal sidecar hash differs")
    rows = [json.loads(line) for line in sidecar.read_text().splitlines()]
    require(rows and rows[0].get("event") == "causal_identity", "Missing causal identity")
    identity, events = rows[0], rows[1:]
    base = path.with_name(path.stem + "-events.jsonl")
    require(sha256(base) == identity["base_trace_sha256"] == receipt["trace_sha256"], "Causal/base trace binding differs")
    require(identity["source"] == receipt["source_identity"] and identity["fixture"] == receipt["fixture"]
            and identity["enabled"] is expected_enabled, "Causal source/fixture differs")
    for key in ("capture_start_usec", "capture_end_usec"):
        require(identity[key] == receipt[key], "Causal capture bounds differ")
    base_rows = [json.loads(line) for line in base.read_text().splitlines()]
    result = analyze(identity, events, receipt, base_rows[1:])
    result.update(source=receipt["source_identity"], trace_sha256=sha256(sidecar), base_trace_sha256=sha256(base))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--enabled", choices=("0", "1"), required=True)
    args = parser.parse_args()
    print(json.dumps(reduce_causal(args.receipt, args.enabled == "1"), indent=2))
