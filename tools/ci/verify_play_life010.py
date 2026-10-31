#!/usr/bin/env python3
"""Independently reduce retained LIFE010 results, process logs and packet bytes.

This does not execute Godot or treat a result's success flag as evidence. The
caller supplies the exact source revision, original process receipt and raw log.
The ordinary repository runner remains responsible for source/runtime provenance.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
RIGS = {"stuntbuggy", "trialsbike", "acrobat", "arcadelander", "jetbarrel"}
DELIVERIES = ["duplicate-current", "delayed-A", "out-of-order-B",
              "duplicate-receipt-packet", "old-epoch-world-body-terrain"]
GATES = ["uncancelled-positive", "lease-valid-cancellation", "fresh-generation-recovery"]


class EvidenceError(ValueError):
    pass


def need(condition: bool, reason: str) -> None:
    if not condition:
        raise EvidenceError(reason)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_artifact(directory: Path, name: str) -> Path:
    path = directory / name
    need(Path(name).name == name and path.is_file(), "packet_artifact_missing")
    return path


def matching_receipts(gate: dict, request: dict) -> list[dict]:
    return [receipt for receipt in gate["runtime_after"]["receipts"]
            if receipt["request_id"] == request["request_id"]
            and receipt["accepted"] is True and receipt["consumed"] is True]


def validate(record: dict, directory: Path, source: str,
             fixture_hash: str, worker_hash: str) -> dict:
    need(record["schema"] == "play-life010-v1" and record["rig"] in RIGS, "schema_or_rig")
    need(record["source_revision"] == source and bool(re.fullmatch(r"[0-9a-f]{40}", source)),
         "source_identity")
    need(record["fixture_sha256"] == fixture_hash and record["worker_sha256"] == worker_hash,
         "fixture_identity")
    need(record["failures"] == 0 and not record["errors"]
         and record["negative_control_passed"] is True
         and record["positive_controls_passed"] is True, "reported_failure")
    need(record["graphical_qualification"] is False, "graphical_claim")
    need(record["operation_limit_usec"] == 15_000_000
         and record["fixture_limit_usec"] == 150_000_000
         and 0 < record["elapsed_usec"] <= 150_000_000, "fixture_deadline")
    need(record["first_main_ack_limit_usec"] == 30_000_000
         and len(record["first_main_acks"]) == 2, "first_main_inventory")
    for ack in record["first_main_acks"]:
        need(ack["origin"] == "before-main-scene-load"
             and ack["event"] == "first-inherited-Main-process-return"
             and ack["passed"] is True and ack["deadline_usec"] - ack["origin_usec"] == 30_000_000
             and ack["origin_usec"] < ack["acknowledged_usec"] <= ack["deadline_usec"]
             and ack["acknowledged_usec"] <= ack["observed_usec"], "first_main_deadline")
    waits = record["waits"]
    need(len(waits) == 42 and len({wait["name"] for wait in waits}) == 39,
         "wait_inventory")
    for wait in waits:
        need(wait["passed"] is True
             and wait["started_usec"] <= wait["ended_usec"] <= wait["deadline_usec"]
             and 0 < wait["deadline_usec"] - wait["started_usec"] <= 15_000_000,
             "operation_deadline")
    lifetimes = record["lifetimes"]
    need([value["name"] for value in lifetimes] == ["negative", "guarded"], "lifetime_inventory")
    acks = record["first_main_acks"]
    need(len({(ack["origin_usec"], ack["acknowledged_usec"]) for ack in acks}) == 2,
         "first_main_lifetime_binding")
    for index, life in enumerate(lifetimes):
        need(bool(life["packets"]) and bool(life["deliveries"]), "lifetime_evidence_missing")
        need(acks[index]["observed_usec"] <= min(packet["captured_usec"] for packet in life["packets"]),
             "first_main_lifetime_binding")
        if index:
            need(acks[index]["origin_usec"] > max(
                event["delivery"]["delivered_usec"] for event in lifetimes[index - 1]["deliveries"]),
                "first_main_lifetime_binding")
    need(sum(len(value["packets"]) for value in lifetimes) <= 8, "packet_capacity")
    payloads: dict[tuple[str, int], dict] = {}
    packet_count = 0
    for life in lifetimes:
        need(life["worker_joined"] is True and life["session_retired"] is True
             and life["host_freed"] is True and 0 < life["teardown_usec"] <= 15_000_000,
             "incomplete_teardown")
        need(life["normal_handoffs"] > len(life["packets"]), "no_normal_live_delivery")
        for index, packet in enumerate(life["packets"]):
            binary = safe_artifact(directory, packet["artifact"])
            readable = safe_artifact(directory, packet["json_artifact"])
            need(packet["artifact_written"] is True
                 and binary.stat().st_size == packet["size"]
                 and sha256(binary) == packet["sha256"] == packet["retired_sha256"],
                 "packet_digest")
            need(sha256(readable) == packet["json_sha256"] == packet["retired_json_sha256"],
                 "readable_packet_digest")
            payload = json.loads(readable.read_text(encoding="utf-8"))
            need(payload["serial"] == packet["serial"] and payload["tick_index"] == packet["native_tick"]
                 and payload["rigid_body_epoch"] == packet["epoch"]
                 and payload["render_world_generation"] == packet["world_generation"]
                 and payload["published_usec"] == packet["published_usec"], "packet_identity")
            need(packet["owner_running"] is True and packet["owner"] == life["final"]["worker"]
                 and packet["published_usec"] <= packet["captured_usec"]
                 and "native" in payload["backend_name"]
                 and payload["simulation_failed"] is False, "packet_owner_or_backend")
            payloads[(life["name"], index)] = payload
            packet_count += 1
        for event in life["deliveries"]:
            delivery, before, after = event["delivery"], event["before"], event["after"]
            need(0 <= delivery["slot"] < len(life["packets"]), "delivery_slot")
            packet = life["packets"][delivery["slot"]]
            need(delivery["captured_sha256"] == delivery["delivery_sha256"] == packet["sha256"]
                 and delivery["serial"] == packet["serial"] and delivery["epoch"] == packet["epoch"]
                 and delivery["world_generation"] == packet["world_generation"], "delivery_identity")
            need(delivery["owner_running"] is True and delivery["owner"] == before["worker"]
                 and before["worker"] == after["worker"] == packet["owner"], "live_delivery_owner")
            need(delivery["after_serial"] == before["consumed_serial"]
                 and delivery["serial"] <= before["consumed_serial"], "not_stale_delivery")
            if life["name"] == "negative":
                need(event["oracle_error"] == "consumer_serial_regressed"
                     and after["consumed_serial"] == after["latest_serial"] == delivery["serial"]
                     and after["consumed_serial"] < before["consumed_serial"], "negative_wrong_reason")
            else:
                need(event["oracle_error"] == "" and after["rejected"] == before["rejected"] + 1,
                     "stale_not_rejected")
                need({key: value for key, value in before.items() if key != "rejected"}
                     == {key: value for key, value in after.items() if key != "rejected"},
                     "stale_consumer_mutation")
    negative, guarded = lifetimes
    need([event["delivery"]["name"] for event in negative["deliveries"]] == ["counter-bypass"],
         "negative_inventory")
    need([event["delivery"]["name"] for event in guarded["deliveries"]] == DELIVERIES,
         "delivery_inventory")
    duplicate, delayed, reordered, receipt_event, old_epoch = guarded["deliveries"]
    need(duplicate["delivery"]["serial"] == duplicate["before"]["consumed_serial"]
         and delayed["delivery"]["serial"] < delayed["before"]["consumed_serial"]
         and reordered["delivery"]["serial"] < reordered["before"]["consumed_serial"],
         "delivery_order")
    need(old_epoch["delivery"]["epoch"] < old_epoch["before"]["epoch"]
         and old_epoch["delivery"]["world_generation"] < old_epoch["before"]["world_generation"],
         "old_epoch_not_exercised")
    receipt_packet = payloads[("guarded", receipt_event["delivery"]["slot"])]
    need(any(receipt["accepted"] is True and receipt["consumed"] is True
             for receipt in receipt_packet["physical_usables"]["receipts"]), "no_real_receipt_packet")
    need(len(record["progress"]) == 7, "progress_inventory")
    for progress in record["progress"]:
        before, after = progress["before"], progress["after"]
        need(all(before[key] == after[key] for key in
                 ["worker", "session", "bridge", "run_id", "epoch", "world_generation"]),
             "progress_owner")
        need(after["native_tick"] > before["native_tick"]
             and after["physics_tick"] - before["physics_tick"] >= progress["minimum_steps"] >= 3
             and after["bridge_step"] - before["bridge_step"] == after["physics_tick"] - before["physics_tick"]
             and after["completed_steps"] - before["completed_steps"]
             == after["physics_tick"] - before["physics_tick"], "no_completed_progress")
    controls = record["equipment"]
    gates = guarded["gates"]
    need([control["name"] for control in controls] == GATES
         and [gate["name"] for gate in gates] == GATES and not negative["gates"], "equipment_inventory")
    need(not negative["receipt_steps"] and len(guarded["receipt_steps"]) == 2, "receipt_step_inventory")
    for index, (control, gate) in enumerate(zip(controls, gates, strict=True)):
        request = control["request"]
        need(gate["requests"] == [request] and gate["allowed"] is True
             and gate["extracted"] is True and gate["released"] is True and gate["returned"] is True
             and gate["timed_out"] is False and gate["release_from_stop"] is False,
             "gate_not_completed")
        need(gate["extracted_usec"] <= gate["released_usec"] <= gate["returned_usec"]
             and gate["returned_usec"] - gate["extracted_usec"] <= 15_000_000, "gate_deadline")
        need(control["lease_valid"] is True and control["lease_frame_tick"] < control["lease_deadline"]
             and control["lease_frame_tick"] < control["extracted_lease_deadline"],
             "cancel_lease_expired")
        need(control["queued_edges"] == [
            {"button":"equipment_trigger", "pressed":True},
            {"button":"equipment_trigger", "pressed":False}]
             and control["input_sequence_after"] >= control["before"]["last_sequence"] + 2,
             "input_edges")
        need(request["epoch"] == gate["body_epoch"] == control["before"]["epoch"]
             and request["run_id"] == control["before"]["run_id"]
             and request["generation"] == control["before"]["control_generation"], "request_identity")
        before, after = control["before"], control["after"]
        need(all(before[key] == after[key] for key in
                 ["worker", "session", "bridge", "run_id", "epoch", "world_generation"]),
             "equipment_owner_changed")
        held_before, held_after = control["held_before"], control["held_after"]
        need(control["held_before_release"] is True
             and gate["extracted_usec"] <= control["held_observed_usec"] <= gate["released_usec"]
             and held_after["main_callbacks"] > held_before["main_callbacks"]
             and held_after["physics_tick"] > held_before["physics_tick"]
             and held_after["bridge_step"] - held_before["bridge_step"]
             == held_after["physics_tick"] - held_before["physics_tick"]
             and held_after["completed_steps"] - held_before["completed_steps"]
             == held_after["physics_tick"] - held_before["physics_tick"], "pending_request_no_physics")
        native_matches = matching_receipts(gate, request)
        need(control["native_matching_accepts"] == len(native_matches), "native_receipt_count")
        if index == 1:
            need(control["cancelled"] is True and not native_matches
                 and after["accepted_uses"] == before["accepted_uses"]
                 and after["recoil"] == before["recoil"], "cancelled_effect_applied")
            cancelled = control["after_cancel"]
            need(cancelled["paused"] is True
                 and cancelled["control_generation"] > request["generation"]
                 and cancelled["physics_tick"] == control["lease_frame_tick"], "cancel_boundary")
            need(control["old_generation_admission"]["status"] == "refused"
                 and control["old_generation_admission"]["reason"] == "generation",
                 "old_generation_admitted")
        else:
            need(control["cancelled"] is False and len(native_matches) == 1
                 and after["accepted_uses"] == before["accepted_uses"] + 1
                 and after["receipt"]["request_id"] == request["request_id"]
                 and after["receipt"]["accepted"] is True and after["receipt"]["consumed"] is True,
                 "positive_effect_missing")
            recoil = re.fullmatch(r"\((-?[0-9]+(?:\.[0-9]+)?), (-?[0-9]+(?:\.[0-9]+)?)\)",
                                 after["recoil"])
            need(recoil is not None and any(float(value) != 0.0 for value in recoil.groups()),
                 "positive_recoil_missing")
            step = control["receipt_step"]
            need(step in guarded["receipt_steps"] and step["request_id"] == request["request_id"]
                 and step["admitted_usec"] <= step["completed_usec"], "receipt_step_identity")
            admitted, completed = step["admitted"], step["completed"]
            need(admitted["receipt"]["request_id"] == request["request_id"]
                 and admitted["accepted_uses"] == completed["accepted_uses"] == after["accepted_uses"]
                 and all(admitted[key] == completed[key] == after[key] for key in
                         ["worker", "session", "bridge", "run_id", "epoch", "control_generation"]),
                 "receipt_step_owner")
            need(completed["physics_tick"] > admitted["physics_tick"]
                 and completed["bridge_step"] - admitted["bridge_step"]
                 == completed["physics_tick"] - admitted["physics_tick"]
                 and completed["completed_steps"] - admitted["completed_steps"]
                 == completed["physics_tick"] - admitted["physics_tick"], "receipt_without_completed_step")
    requests = [control["request"] for control in controls]
    need(len({request["request_id"] for request in requests}) == 3
         and requests[0]["sequence"] < requests[1]["sequence"] < requests[2]["sequence"]
         and requests[2]["generation"] > requests[1]["generation"], "equipment_order")
    rebuild = record["reconstruction"]
    need(rebuild["after"]["epoch"] > rebuild["before"]["epoch"]
         and rebuild["after"]["world_generation"] > rebuild["before"]["world_generation"]
         and rebuild["after"]["run_id"] != rebuild["before"]["run_id"]
         and rebuild["after"]["worker"] == rebuild["before"]["worker"]
         and rebuild["old_request_admission"]["status"] == "refused"
         and rebuild["old_request_admission"]["reason"] == "epoch", "reconstruction_fence")
    return {"rig":record["rig"], "assertions":record["assertions"], "failures":0,
            "real_lifetimes":2, "packets":packet_count, "rejected_deliveries":len(DELIVERIES),
            "native_commits":2, "lease_valid_cancellations":1,
            "serial_bypass_negative":"consumer_serial_regressed", "elapsed_usec":record["elapsed_usec"]}


def adverse_controls(record: dict, directory: Path, source: str,
                     fixture_hash: str, worker_hash: str) -> list[dict]:
    mutations = [
        ("source", "source_identity", lambda r: r.update(source_revision="0" * 40)),
        ("late_main_ack", "first_main_deadline", lambda r: r["first_main_acks"][0].update(
            acknowledged_usec=r["first_main_acks"][0]["deadline_usec"] + 1)),
        ("duplicate_main_ack", "first_main_lifetime_binding",
         lambda r: r["first_main_acks"].__setitem__(1, deepcopy(r["first_main_acks"][0]))),
        ("swapped_main_acks", "first_main_lifetime_binding", lambda r: r["first_main_acks"].reverse()),
        ("expired_lease", "cancel_lease_expired",
         lambda r: r["equipment"][1].update(lease_deadline=r["equipment"][1]["lease_frame_tick"])),
        ("timeout", "operation_deadline", lambda r: r["waits"][0].update(passed=False)),
        ("missing_delivery", "delivery_inventory", lambda r: r["lifetimes"][1]["deliveries"].pop(1)),
        ("stale_body", "stale_consumer_mutation",
         lambda r: r["lifetimes"][1]["deliveries"][0]["after"].update(body_result_serial=-99)),
        ("stale_terrain", "stale_consumer_mutation",
         lambda r: r["lifetimes"][1]["deliveries"][0]["after"].update(terrain_revision=-99)),
        ("stale_lap", "stale_consumer_mutation",
         lambda r: r["lifetimes"][1]["deliveries"][0]["after"].update(lap_target=99)),
        ("missing_physics", "no_completed_progress", lambda r: r["progress"][0]["after"].update(
            physics_tick=r["progress"][0]["before"]["physics_tick"])),
        ("neutral_equipment", "input_edges", lambda r: r["equipment"][0].update(queued_edges=[])),
        ("blocked_physics", "pending_request_no_physics", lambda r: r["equipment"][0]["held_after"].update(
            physics_tick=r["equipment"][0]["held_before"]["physics_tick"])),
        ("extracted_lease_expired", "cancel_lease_expired", lambda r: r["equipment"][1].update(
            extracted_lease_deadline=r["equipment"][1]["lease_frame_tick"])),
        ("native_counter_only", "native_receipt_count",
         lambda r: r["lifetimes"][1]["gates"][0]["runtime_after"].update(receipts=[])),
        ("cancelled_effect", "cancelled_effect_applied", lambda r: r["equipment"][1]["after"].update(
            accepted_uses=r["equipment"][1]["before"]["accepted_uses"] + 1)),
        ("worker_unjoined", "incomplete_teardown", lambda r: r["lifetimes"][1].update(worker_joined=False)),
        ("wrong_negative", "negative_wrong_reason",
         lambda r: r["lifetimes"][0]["deliveries"][0].update(oracle_error="timeout")),
        ("altered_packet", "packet_digest",
         lambda r: r["lifetimes"][1]["packets"][0].update(retired_sha256="0" * 64)),
    ]
    outcomes = []
    for name, expected, mutation in mutations:
        altered = deepcopy(record)
        mutation(altered)
        try:
            validate(altered, directory, source, fixture_hash, worker_hash)
        except EvidenceError as error:
            need(str(error) == expected, f"adverse_wrong_reason:{name}:{error}")
            outcomes.append({"name":name, "rejected_for":str(error)})
        else:
            raise EvidenceError("adverse_false_pass:" + name)
    for name, expected, key, value in [
        ("receipt_without_step", "receipt_without_completed_step", "physics_tick",
         record["equipment"][0]["receipt_step"]["admitted"]["physics_tick"]),
        ("receipt_stale_generation", "receipt_step_owner", "control_generation", -1),
    ]:
        altered = deepcopy(record)
        altered["equipment"][0]["receipt_step"]["completed"][key] = value
        altered["lifetimes"][1]["receipt_steps"][0]["completed"][key] = value
        try:
            validate(altered, directory, source, fixture_hash, worker_hash)
        except EvidenceError as error:
            need(str(error) == expected, f"adverse_wrong_reason:{name}:{error}")
            outcomes.append({"name":name, "rejected_for":str(error)})
        else:
            raise EvidenceError("adverse_false_pass:" + name)
    return outcomes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--process-json", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--local-process-receipt", action="store_true", help=(
        "Explicit local v1 receipt schema: exactly command, timeout_seconds, "
        "returncode, timed_out and elapsed_seconds. Ordinary receipts require status."))
    parser.add_argument("--fixture", type=Path,
                        default=ROOT / "godot/tests/play_life010_live_delivery_case.gd")
    parser.add_argument("--worker", type=Path,
                        default=ROOT / "godot/tests/play_life010_live_delivery_worker.gd")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        record = json.loads(args.result.read_text(encoding="utf-8"))
        process = json.loads(args.process_json.read_text(encoding="utf-8"))
        if "results" in process: # Unmodified ordinary Linux/Windows timing receipt.
            rows = [row for row in process["results"] if row["name"] == "test_play_life010_" + record["rig"]]
            need(len(rows) == 1, "process_inventory")
            process = rows[0]
        if args.local_process_receipt:
            need(set(process) == {"command", "timeout_seconds", "returncode", "timed_out", "elapsed_seconds"}
                 and isinstance(process["timed_out"], bool), "local_process_schema")
        else:
            need("status" in process, "ordinary_process_status_missing")
            need(process["status"] == "passed", "process_failed_or_incomplete")
        need(type(process["returncode"]) is int and process["returncode"] == 0
             and process["timeout_seconds"] == 180
             and not process.get("timed_out", False) and not process.get("timeout_kind")
             and not process.get("diagnostic_error") and not process.get("launch_error")
             and not process.get("capture_error") and not process.get("skip_messages"),
             "process_failed_or_incomplete")
        elapsed = process.get("seconds", process.get("elapsed_seconds"))
        need(isinstance(elapsed, (int, float)) and 0 < elapsed <= 180, "process_deadline")
        command = process["command"]
        need(isinstance(command, list) and all(isinstance(value, str) for value in command)
             and "res://tests/test_play_life010_" + record["rig"] + ".gd" in command, "process_case_mismatch")
        log = args.log.read_text(encoding="utf-8")
        need("SCRIPT ERROR:" not in log and "ERROR:" not in log
             and not re.search(r"\bskipped\b|^\s*SKIP\b", log, re.IGNORECASE | re.MULTILINE),
             "log_failed_or_skipped")
        markers = [line.removeprefix("PLAY_LIFE010_RESULT ") for line in log.splitlines()
                   if line.startswith("PLAY_LIFE010_RESULT ")]
        need(len(markers) == 1 and json.loads(markers[0]) == record, "log_result_mismatch")
        summaries = re.findall(r"^PLAY_LIFE010_SUMMARY assertions=(\d+) failures=(\d+)$", log, re.MULTILINE)
        need(summaries == [(str(record["assertions"]), "0")], "summary_mismatch")
        fixture_hash, worker_hash = sha256(args.fixture), sha256(args.worker)
        reduced = validate(record, args.result.parent, args.source, fixture_hash, worker_hash)
        if args.self_test:
            reduced["adverse_controls"] = adverse_controls(record, args.result.parent, args.source,
                                                           fixture_hash, worker_hash)
        reduced.update(source_revision=args.source, result_sha256=sha256(args.result),
                       process_sha256=sha256(args.process_json), log_sha256=sha256(args.log),
                       fixture_sha256=fixture_hash, worker_sha256=worker_hash)
        if args.output:
            args.output.write_text(json.dumps(reduced, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(reduced, sort_keys=True))
        return 0
    except (EvidenceError, KeyError, TypeError, ValueError, OSError) as error:
        print(f"PLAY_LIFE010_VERIFICATION_FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
