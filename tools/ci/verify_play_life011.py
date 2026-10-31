#!/usr/bin/env python3
"""Independently read LIFE011 original process, policy and actual-host receipts.

No engine is executed. The eight source-registered policies are reconstructed
with the independent LCB byte contract. Native receipt SHA256 and its canonical
construction/native prefix are checked against those requested identities.
Full scientific receipt equivalence remains outside this exploratory fixture.
The ordinary runner owns source/runtime provenance; --source and --platform
must come from that external campaign identity, not the result being read.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/lcb"))
import policy_contract as policy_bytes
import inertial_parameter_contract as inertial_bytes

RIG_BODIES = {"stuntbuggy": 8, "trialsbike": 8, "acrobat": 6,
              "arcadelander": 4, "jetbarrel": 2}
MATERIALS = [3, 8, 12, 16, 20, 21, 24, 30, 32, 33, 36]
FAMILIES = {1: "freemass_v1", 2: "cellular_yield_v1",
            3: "pressure_flow_v1", 4: "inertial_cellular_v1"}
VARIANTS = {0: "reference", 1: "cached", 2: "cached_dormant"}
PRESETS = [[], [(3, 2, 0)], [(3, 3, 0)], [(3, 3, 1)], [(3, 3, 2)],
           [(3, 4, 0)], [(3, 3, 0), (24, 4, 0)], [(24, 4, 0)]]
LABELS = ["Current defaults", "Water: whole-cell", "Water: pressure reference",
          "Water: pressure cached", "Water: pressure dormant", "Water: inertial",
          "Mixed: pressure Water + inertial Brine", "Mixed: Current Water + inertial Brine"]
OPTIONS = {"controls": "keyboard", "rules": "lap", "camera": "follow"}
OWNER = ("worker", "session", "bridge", "run_id", "epoch", "world_generation", "session_generation")
COURSE_HASH = "9aa78894270cf4b2086315b5d7418a762900d6fe44249b95135749286481d474"
ERRORS = {
    "oil_pressure": "MicroScenario rejected; Liquid solver policy refused; running world preserved: "
                    "combination_rejected: oil x pressure_flow_v1",
    "inertial_radius_two": "MicroScenario rejected; Liquid solver policy refused; running world preserved: "
                           "malformed_policy: inertial_cellular_v1 requires complete execution radius three",
}


class EvidenceError(ValueError):
    pass


def need(condition: bool, reason: str) -> None:
    if not condition:
        raise EvidenceError(reason)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_owner(*states: dict, reason: str = "owner_changed") -> None:
    need(all(all(state[key] == states[0][key] for key in OWNER) for state in states[1:]), reason)


def expected_policy(preset: int) -> dict:
    assignments = {material: (1 if material == 3 else 2, 0) for material in MATERIALS}
    assignments.update({material: (family, variant) for material, family, variant in PRESETS[preset]})
    catalogue = policy_bytes.catalogue_digest(ROOT)
    capability = policy_bytes.capability_matrix_digest(
        (ROOT / "docs/reference/liquid-solver-capability-matrix.json").read_bytes())
    rows = [(material, *assignments[material]) for material in MATERIALS]
    canonical = b"lcb-liquid-policy\0" + struct.pack("<H", 1)
    canonical += bytes.fromhex(catalogue) + bytes.fromhex(capability)
    canonical += struct.pack("<H", len(rows)) + b"".join(struct.pack("<HBB", *row) for row in rows)
    canonical += struct.pack("<BH", 0, 0)
    envelope = [0x4C435057, 1, 1]
    for digest in (catalogue, capability):
        envelope.extend(value if value < 2**31 else value - 2**32
                        for value in struct.unpack(">8I", bytes.fromhex(digest)))
    envelope += [len(rows), *[number for row in rows for number in row], 0, 0]
    return {"rows": rows, "envelope": envelope, "catalogue": catalogue,
            "capability": capability, "hash": hashlib.sha256(canonical).hexdigest()}


class Reader:
    def __init__(self, data: bytes):
        self.data, self.offset = data, 0

    def take(self, length: int) -> bytes:
        need(0 <= length <= len(self.data) - self.offset, "canonical_receipt_truncated")
        result = self.data[self.offset:self.offset + length]
        self.offset += length
        return result

    def fields(self, fmt: str) -> tuple:
        return struct.unpack("<" + fmt, self.take(struct.calcsize("<" + fmt)))

    def words(self) -> list[int]:
        count, = self.fields("I")
        need(count == 55, "canonical_policy_length")
        return list(self.fields("i" * count))


def canonical_receipt(receipt: dict, wanted: dict, radius: int) -> None:
    data = bytes.fromhex(receipt["canonical_hex"])
    need(1024 <= len(data) <= 16384
         and hashlib.sha256(data).hexdigest() == receipt["receipt_hash"], "canonical_receipt_digest")
    reader = Reader(data)
    length, = reader.fields("I")
    need(length == 24 and reader.take(length) == b"cybersand-run-receipt-v1",
         "canonical_receipt_domain")
    schema, intent, activity, qualifications, generation, tick = reader.fields("HBBIQQ")
    need((schema, intent, activity, qualifications, generation, tick) ==
         (1, 2, 1, 15, receipt["session_generation"], 0),
         "canonical_receipt_header")
    need(reader.words() == wanted["envelope"], "canonical_requested_policy")
    present, = reader.fields("B")
    need(present == 1 and reader.take(32).hex() == wanted["hash"]
         and reader.take(32).hex() == wanted["catalogue"]
         and reader.take(32).hex() == wanted["capability"]
         and reader.words() == wanted["envelope"], "canonical_applied_policy")
    # Explicit v1 native-prefix layout from the independent receipt contract.
    # Preserve all remaining bytes under their actual native SHA256; do not
    # present this bounded prefix decoder as a complete scientific oracle.
    reader.take(struct.calcsize("<BBBB") + 32 + struct.calcsize("<IBBI"))
    chunk, active, hard, actual_radius, sleep, temperature, backend, workers = reader.fields("iiiiIhBI")
    need((chunk, active, hard, actual_radius, sleep, temperature, backend, workers) ==
         (128, 32, 64, radius, 3, 200, 1, receipt["worker_threads"]), "canonical_native_configuration")


def check_request(request: dict, preset: int, rig: str) -> dict:
    wanted = expected_policy(preset)
    need(request["preset"] == preset and request["label"] == LABELS[preset]
         and request["policy"] == wanted["envelope"], "requested_policy_identity")
    need(request["radius"] == (3 if preset >= 5 else 2)
         and request["normalize"] is (preset in (1, 5)), "requested_construction_setup")
    need(request["selection"] == dict(OPTIONS, actor=rig, map="playground/player-course"), "session_selection")
    return wanted


def check_state(state: dict, rig: str) -> None:
    need(state["backend"] == "native-phased" and state["fault"] == ""
         and state["body_count"] == RIG_BODIES[rig]
         and state["terrain_ready"] is True and state["terrain_shapes"] > 0
         and state["terrain_pending"] == 0, "actual_native_rapier_graph")
    need(all(type(state[key]) is int and state[key] != 0 for key in ("worker", "session", "bridge"))
         and bool(re.fullmatch(r"[0-9a-f]{32}", state["run_id"]))
         and state["epoch"] > 0 and state["world_generation"] == state["session_generation"] > 1,
         "actual_owner_identity")


def check_applied(value: dict, request: dict, platform: str, rig: str) -> None:
    preset = request["preset"]
    wanted = expected_policy(preset)
    policy, receipt, state = value["policy"], value["receipt"], value["identity"]
    check_state(state, rig)
    need(value["rig"] == rig and value["options"] == OPTIONS and value["recipe_hash"] == COURSE_HASH,
         "authored_session_identity")
    need(policy["envelope"] == wanted["envelope"] and policy["policy_hash"] == wanted["hash"]
         and policy["catalogue_digest"] == wanted["catalogue"]
         and policy["capability_matrix_digest"] == wanted["capability"], "applied_policy_identity")
    assignments = policy["assignments"]
    need([value["material"] for value in assignments] == MATERIALS, "material_inventory")
    for assignment, (material, family, variant) in zip(assignments, wanted["rows"]):
        need(assignment["material"] == material and assignment["requested_family"] == FAMILIES[family]
             and assignment["applied_family"] == FAMILIES[family]
             and assignment["applied_variant"] == VARIANTS[variant], "requested_applied_assignment")
    need(policy["version"] == policy["wire_version"] == 1 and policy["refusal"] is None
         and policy["admission"] == ("current_defaults_only" if preset == 0 else "qualified_candidate")
         and policy["platform"] == platform.lower()
         and policy["family_blocks"] == policy["material_blocks"] == [], "native_policy_admission")
    radius = 3 if preset >= 5 else 2
    need(policy["minimum_rule_radius"] == policy["maximum_rule_radius"] == radius
         and receipt["maximum_rule_radius"] == radius
         and value["setup"] == {"intent": "exploratory", "maximum_rule_radius": radius,
                                "normalization": "water-normalize-v1" if preset in (1, 5) else ""},
         "applied_construction_setup")
    need(policy["session_generation"] == receipt["session_generation"] == state["world_generation"],
         "applied_world_generation")
    version = 3 if preset >= 5 else 2
    need(policy["physical_state_hash_version"] == policy["physical_state_format_version"]
         == receipt["physical_state_hash_version"] == version, "instance_state_version")
    extensions = []
    if preset in (2, 3, 4, 6):
        optimization = None
        if preset in (3, 4):
            optimization = hashlib.sha256(b"cybersand-pressure-optimization-v1-identity-v1"
                + struct.pack("<6Q", 3, preset - 2, 4096, 4 << 20, 1 << 20, 4 << 20)).hexdigest()
        extensions.append({"extension_digest": optimization, "extension_identity_version": 1 if optimization else 0,
                           "family": 3, "state_contract_version": 1})
    if preset >= 5:
        inertial = {"block_version": 2, "damping_denominator": 16, "damping_numerator": 1,
                    "extension_identity": inertial_bytes.identity(1), "family_version": 1,
                    "minimum_rule_radius": 3, "readback_source": "applied_world"}
        need(policy["family_parameters"].get("inertial_cellular_v1") == inertial, "applied_inertial_parameters")
        extensions.append({"extension_digest": inertial["extension_identity"], "extension_identity_version": 1,
                           "family": 4, "state_contract_version": 1})
    need(receipt["solver_state_extensions"] == extensions, "native_state_extensions")
    need(receipt["kind"] == "applied_run" and receipt["schema_version"] == 1
         and receipt["policy_hash"] == wanted["hash"] and receipt["completed_tick"] == 0
         and receipt["initial_body_count"] == RIG_BODIES[rig]
         and receipt["region"] == [128, 128, 512, 256] and 1 <= receipt["worker_threads"] <= 32
         and receipt["run_intent"] == "exploratory" and receipt["qualifications"] == 15
         and receipt["eligible_for_full_matched_evidence"] is False
         and receipt["pacing"] == "host_paced", "construction_receipt_scope")
    for key in ("receipt_hash", "prepared_payload_hash", "prepared_setup_hash", "initial_body_state_sha256"):
        need(bool(re.fullmatch(r"[0-9a-f]{64}", receipt[key])), "construction_receipt_hash")
    normalization = receipt["normalization"]
    if preset in (1, 5):
        need(normalization["rule"] == "water-normalize-v1"
             and normalization["setup_after_hash"] == receipt["prepared_setup_hash"]
             and normalization["payload_after_hash"] == receipt["prepared_payload_hash"]
             and bool(re.fullmatch(r"[0-9a-f]{64}", normalization["receipt_hash"])), "normalization_binding")
    else:
        need(normalization == {}, "unexpected_normalization")
    canonical_receipt(receipt, wanted, radius)


def check_retirement(value: dict, rig: str, exists: bool = True) -> None:
    if not exists:
        need(value == {"prior_graph": False}, "unexpected_initial_graph")
        return
    need(value == {"prior_graph": True, "session_retired": True, "bodies_retired": True,
                   "body_count": RIG_BODIES[rig], "bridge_shutdown": True, "terrain_shapes": 0,
                   "terrain_pending": 0, "body_rids": 0, "viewport_retired": True,
                   "candidate_retired": True}, "incomplete_graph_retirement")


def check_reconstruction(before: dict, after: dict) -> None:
    need(before["worker"] == after["worker"] and after["epoch"] == before["epoch"] + 1
         and after["world_generation"] == before["world_generation"] + 1
         and after["request_serial"] == before["request_serial"] + 1
         and after["session"] != before["session"], "reconstruction_owner_transition")
    if before["session"]:
        need(after["run_id"] != before["run_id"] and after["bridge"] != before["bridge"],
             "reconstruction_graph_reused")


def check_progress(progress: dict, anchor: dict, rig: str, phase: str) -> None:
    before, started, after = (progress[key] for key in ("before", "started", "after"))
    exact_owner(anchor, before, started, after, reason="progress_owner_changed")
    need(progress["completed"] is True and before["time_usec"] <= started["time_usec"] <= after["time_usec"]
         and after["native_tick"] > started["native_tick"] >= 0
         and after["physics_tick"] >= started["physics_tick"] + 3
         and after["bridge_step"] - started["bridge_step"] == after["physics_tick"] - started["physics_tick"],
         "no_completed_native_rapier_progress")
    movement = [1, 0] if rig == "acrobat" else [0, -1]
    need(progress["expected_move"] == movement and len(progress["records"]) == 3, "physical_sample_inventory")
    previous = started
    for row in progress["records"]:
        first, last = row["before"], row["after"]
        check_state(first, rig)
        check_state(last, rig)
        exact_owner(anchor, first, last, reason="physical_sample_owner_changed")
        need(row["phase"] == phase and started["time_usec"] <= first["time_usec"]
             <= last["time_usec"] <= after["time_usec"]
             and first["time_usec"] >= previous["time_usec"]
             and first["physics_tick"] == previous["physics_tick"]
             and first["bridge_step"] == previous["bridge_step"], "physical_sample_order")
        need(last["physics_tick"] == first["physics_tick"] + 1
             and last["bridge_step"] == first["bridge_step"] + 1
             and last["physics_callbacks"] == first["physics_callbacks"] + 1,
             "physical_sample_not_completed")
        need(last["control_generation"] == first["control_generation"] == started["control_generation"]
             and last["request_serial"] == first["request_serial"] == anchor["request_serial"],
             "physical_sample_generation")
        need(last["move"] == movement and last["rearm"] is False and last["paused"] is False
             and last["suspended"] is False and last["accepted_commands"] > first["accepted_commands"]
             and last["sequence"] > first["sequence"] and last["fault"] == "",
             "nonneutral_input_not_applied")
        need(last["native_tick"] >= first["native_tick"] >= previous["native_tick"]
             and last["snapshot_serial"] >= first["snapshot_serial"] >= previous["snapshot_serial"],
             "native_publication_regressed")
        previous = last
    need(after["physics_tick"] >= previous["physics_tick"] and after["native_tick"] >= previous["native_tick"]
         and after["snapshot_serial"] >= previous["snapshot_serial"], "progress_tail_regressed")


def check_packet(packet: dict, observed: dict) -> None:
    need(packet["version"] == 2 and packet["kind"] == "physical_wire_action"
         and packet["actor_id"] == 0 and packet["run_id"] == observed["run_id"]
         and packet["epoch"] == observed["epoch"] and packet["observed_tick"] == observed["physics_tick"]
         and packet["sequence"] == observed["sequence"] + 1 and packet["lease_ticks"] == 12
         and packet["action"] == {"move": "(1.0, 0.0)"}
         and packet["observation_id"] == (f'{observed["run_id"]}:{observed["epoch"]}:0:'
                                          f'{observed["control_generation"]}:{observed["physics_tick"]}'),
         "packet_not_source_observation")


def check_rejection(value: dict, reason: str) -> None:
    first, last = value["before"], value["after"]
    need(value["accepted"] is False and value["reason"] == reason, "stale_packet_not_refused")
    need(last["rejected_commands"] == first["rejected_commands"] + 1
         and {key: val for key, val in last.items() if key not in ("rejected_commands", "time_usec")}
         == {key: val for key, val in first.items() if key not in ("rejected_commands", "time_usec")},
         "stale_packet_mutated_owner")


def validate(record: dict, source: str, fixture_hash: str, preset_hash: str, platform: str) -> dict:
    need(record["schema"] == "play-life011-v1" and record["rig"] in RIG_BODIES, "schema_or_rig")
    rig = record["rig"]
    need(bool(re.fullmatch(r"[0-9a-f]{40}", source)) and record["source_revision"] == source, "source_identity")
    need(record["fixture_sha256"] == fixture_hash and record["preset_source_sha256"] == preset_hash,
         "fixture_identity")
    need(platform in ("Linux", "Windows") and record["platform"] == platform
         and record["display_server"] == "headless", "platform_scope")
    engine = record["godot"]
    need(all(engine[key] == value for key, value in {
        "major": 4, "minor": 7, "patch": 0, "status": "stable", "build": "official",
        "hash": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88", "string": "4.7-stable (official)"}.items()),
        "engine_identity")
    need(record["failures"] == 0 and record["assertions"] > 0
         and record["retries"] == record["manual_physics_calls"] == 0
         and record["real_host"] is record["automatic_callbacks"] is record["focus_seam"] is True
         and record["physical_devices_qualified"] is record["rendered_fps_measured"] is False
         and record["host"] == "main.tscn+CyberSimulationWorker+main-thread-Rapier", "scope_or_failure")
    need(record["operation_limit_usec"] == 15_000_000 and record["fixture_limit_usec"] == 150_000_000
         and record["first_main_ack_limit_usec"] == 30_000_000
         and 0 < record["elapsed_usec"] == record["ended_usec"] - record["started_usec"] <= 150_000_000,
         "fixture_deadline")
    ack = record["first_main_ack"]
    need(ack["passed"] is True and ack["origin"] == "before-main-scene-load"
         and ack["event"] == "first-inherited-Main-process-return"
         and record["started_usec"] <= ack["origin_usec"] < ack["acknowledged_usec"]
         <= ack["observed_usec"] <= ack["deadline_usec"]
         and ack["deadline_usec"] - ack["origin_usec"] == 30_000_000, "first_main_deadline")
    labels = []
    for preset in range(8):
        for phase in ("build", "reset"):
            labels += [f"preset{preset} {phase} acknowledgement", f"preset{preset} {phase}: neutral rearm",
                       f"preset{preset} {phase}: completed native and nonneutral Rapier steps"]
        labels += ["oil_pressure: native terminal refusal"]
        if preset >= 5:
            labels += ["inertial_radius_two: native terminal refusal"]
        labels += [f"preset{preset} after refusal: neutral rearm",
                   f"preset{preset} after refusal: completed native and nonneutral Rapier steps"]
    need([wait["label"] for wait in record["waits"]] == labels, "wait_inventory")
    previous_time = ack["observed_usec"]
    for wait in record["waits"]:
        need(wait["passed"] is True and previous_time <= wait["begun"] <= wait["ended"] <= wait["deadline"]
             and wait["deadline"] == min(wait["begun"] + 15_000_000, record["started_usec"] + 150_000_000),
             "operation_deadline")
        previous_time = wait["ended"]
    cohorts = record["cohorts"]
    need([row["preset"] for row in cohorts] == list(range(8)), "preset_inventory")
    worker = cohorts[0]["before"]["worker"]
    need(cohorts[0]["before"]["epoch"] == 0 and cohorts[0]["before"]["session"] == 0, "initial_owner")
    previous = None
    for index, row in enumerate(cohorts):
        need(row["complete"] is True and row["retained_snapshot_unchanged"] is True, "incomplete_cohort")
        request = row["request"]
        wanted = check_request(request, index, rig)
        need(row["before"]["worker"] == worker, "exclusive_worker_changed")
        if previous is not None:
            exact_owner(previous, row["before"], reason="cohort_owner_discontinuity")
            need(previous["request_serial"] == row["before"]["request_serial"], "cohort_request_discontinuity")
        for phase in ("build", "reset"):
            value = row[phase]
            check_applied(value, request, platform, rig)
            check_retirement(row[phase + "_retirement"], rig, exists=index != 0 or phase == "reset")
            check_reconstruction(row["before"] if phase == "build" else row["before_reset"], value["identity"])
            check_progress(row[phase + "_progress"], value["identity"], rig,
                           f"{index * 3 + (1 if phase == 'build' else 2):02d}:preset{index} {phase}")
        exact_owner(row["build"]["identity"], row["before_reset"])
        need(row["before_reset"]["time_usec"] >= row["build_progress"]["after"]["time_usec"], "reset_order")
        pending = row["unsubmitted"]
        need(pending["preset"] == (6 if index == 0 else 0)
             and pending["policy"] == expected_policy(pending["preset"])["envelope"]
             and pending["radius"] == (2 if index >= 5 else 3)
             and pending["normalize"] is (not request["normalize"])
             and pending["policy"] != request["policy"], "unsubmitted_selection_control")
        need(row["build"]["policy"]["policy_hash"] == row["reset"]["policy"]["policy_hash"]
             and row["build"]["setup"] == row["reset"]["setup"], "reset_changed_applied_policy")
        old = row["old_owner"]
        check_packet(old["packet"], row["before_reset"])
        check_rejection(old, "run_or_epoch")
        exact_owner(row["reset"]["identity"], old["before"])
        need(old["packet"]["run_id"] != old["before"]["run_id"]
             and old["packet"]["epoch"] < old["before"]["epoch"], "old_owner_negative_not_stale")
        before, after = row["generation_before_cancel"], row["generation_after_cancel"]
        exact_owner(row["reset"]["identity"], before, after)
        need(after["control_generation"] == before["control_generation"] + 1
             and after["physics_tick"] == before["physics_tick"] and after["move"] == [0, 0]
             and after["pending_edges"] == 0 and after["rearm"] is True, "generation_not_revoked")
        stale = row["old_generation"]
        check_packet(stale["packet"], before)
        check_rejection(stale, "observation_not_issued")
        exact_owner(after, stale["before"])
        need(stale["before"]["control_generation"] == after["control_generation"]
             and stale["packet"]["observed_tick"] <= stale["before"]["physics_tick"]
             < stale["packet"]["observed_tick"] + stale["packet"]["lease_ticks"]
             and stale["packet"]["sequence"] > stale["before"]["sequence"], "stale_generation_wrong_cause")
        fresh = row["fresh_control"]
        check_packet(fresh["packet"], fresh["before"])
        exact_owner(after, fresh["before"], fresh["after"])
        need(fresh["accepted"] is True and fresh["before"]["control_generation"] == after["control_generation"]
             and fresh["after"]["accepted_commands"] == fresh["before"]["accepted_commands"] + 1
             and fresh["after"]["sequence"] == fresh["packet"]["sequence"]
             and fresh["after"]["physics_tick"] == fresh["before"]["physics_tick"]
             and fresh["after"]["rejected_commands"] == fresh["before"]["rejected_commands"], "fresh_control_not_admitted")
        kinds = ["oil_pressure"] + (["inertial_radius_two"] if index >= 5 else [])
        need([value["kind"] for value in row["refusals"]] == kinds, "refusal_inventory")
        for refused in row["refusals"]:
            kind = refused["kind"]
            expected_request = wanted["envelope"].copy()
            if kind == "oil_pressure":
                offset = 20 + MATERIALS.index(16) * 3
                expected_request[offset + 1:offset + 3] = [3, 0]
            need(refused["requested_policy"] == expected_request
                 and refused["radius"] == (2 if kind == "inertial_radius_two" else request["radius"])
                 and refused["normalize"] is request["normalize"], "refusal_request_identity")
            need(refused["queued"] is refused["finished"] is refused["candidate_retired"] is True
                 and refused["error"] == ERRORS[kind], "native_refusal_wrong_reason")
            first, last = refused["before"], refused["after"]
            exact_owner(row["reset"]["identity"], first["identity"], last["identity"], reason="refusal_replaced_valid_owner")
            need(last["identity"]["request_serial"] == first["identity"]["request_serial"] + 1,
                 "refusal_not_new_transaction")
            need(all(first[key] == last[key] == row["reset"][key]
                     for key in ("policy", "receipt", "setup", "options", "rig", "recipe_hash")),
                 "refusal_changed_valid_context")
        check_progress(row["retained_progress"], row["refusals"][-1]["after"]["identity"], rig,
                       f"{index * 3 + 3:02d}:preset{index} after refusal")
        previous = row["retained_progress"]["after"]
    exact_owner(previous, record["final_state"])
    teardown = record["teardown"]
    need(record["retired_graphs"] == 16 and teardown["worker_joined"] is True
         and teardown["worker_destroyed"] is True and teardown["adapter_destroyed"] is True,
         "incomplete_worker_teardown")
    check_retirement(teardown["retirement"], rig)
    need(record["final_state"]["time_usec"] <= teardown["started_usec"] <= teardown["ended_usec"]
         == record["ended_usec"] and 0 < teardown["ended_usec"] - teardown["started_usec"] <= 15_000_000,
         "teardown_deadline")
    return {"rig": rig, "source_revision": source, "platform": platform,
            "assertions": record["assertions"], "failures": 0, "presets": 8,
            "constructions": 8, "resets": 8, "retired_graphs": 16,
            "nonneutral_completed_physical_samples": 72, "old_owner_refusals": 8,
            "old_generation_refusals": 8, "fresh_observation_admissions": 8,
            "unsupported_oil_refusals": 8, "inertial_radius_refusals": 3,
            "waits": len(record["waits"]), "elapsed_usec": record["elapsed_usec"],
            "maximum_operation_usec": max(value["ended"] - value["begun"] for value in record["waits"]),
            "first_main_ack_usec": ack["acknowledged_usec"] - ack["origin_usec"],
            "teardown_usec": teardown["ended_usec"] - teardown["started_usec"],
            "graphical_qualification": False, "physical_device_qualification": False}


def adverse_controls(record: dict, source: str, fixture_hash: str, preset_hash: str, platform: str) -> list[dict]:
    # Mutations start from this original positive host record. The original
    # files are never rewritten, and a wrong rejection reason is itself a fail.
    def inactive_canonical_plane(value: dict) -> None:
        receipt = value["cohorts"][0]["build"]["receipt"]
        data = bytearray.fromhex(receipt["canonical_hex"])
        # u32 text length,24 domain bytes,u16 schema,u8 intent,u8 activity.
        data[31] = 2
        receipt["canonical_hex"] = data.hex()
        receipt["receipt_hash"] = hashlib.sha256(data).hexdigest()

    controls = [
        ("wrong_source", "source_identity", lambda r: r.update(source_revision="0" * 40)),
        ("wrong_fixture", "fixture_identity", lambda r: r.update(fixture_sha256="0" * 64)),
        ("wrong_platform", "platform_scope", lambda r: r.update(platform="other")),
        ("wrong_engine", "engine_identity", lambda r: r["godot"].update(hash="0" * 40)),
        ("late_main_ack", "first_main_deadline", lambda r: r["first_main_ack"].update(
            acknowledged_usec=r["first_main_ack"]["deadline_usec"] + 1)),
        ("late_fixture", "fixture_deadline", lambda r: r.update(elapsed_usec=150_000_001)),
        ("missing_wait", "wait_inventory", lambda r: r["waits"].pop()),
        ("timed_out_wait", "operation_deadline", lambda r: r["waits"][0].update(passed=False)),
        ("missing_preset", "preset_inventory", lambda r: r["cohorts"].pop()),
        ("relabeled_preset", "requested_policy_identity", lambda r: r["cohorts"][0]["request"].update(preset=2)),
        ("wrong_assignment", "requested_applied_assignment", lambda r: r["cohorts"][0]["build"]["policy"]["assignments"][0].update(applied_family="pressure_flow_v1")),
        ("missing_material", "material_inventory", lambda r: r["cohorts"][0]["build"]["policy"]["assignments"].pop()),
        ("wrong_variant", "requested_applied_assignment", lambda r: r["cohorts"][3]["build"]["policy"]["assignments"][0].update(applied_variant="reference")),
        ("wrong_generation", "applied_world_generation", lambda r: r["cohorts"][0]["build"]["receipt"].update(session_generation=999)),
        ("wrong_geometry", "applied_construction_setup", lambda r: r["cohorts"][5]["build"]["policy"].update(maximum_rule_radius=2)),
        ("caller_inertial_claim", "applied_inertial_parameters", lambda r: r["cohorts"][5]["build"]["policy"]["family_parameters"]["inertial_cellular_v1"].update(readback_source="caller")),
        ("altered_canonical", "canonical_receipt_digest", lambda r: r["cohorts"][0]["build"]["receipt"].update(canonical_hex="00" + r["cohorts"][0]["build"]["receipt"]["canonical_hex"][2:])),
        ("inactive_canonical_plane", "canonical_receipt_header", inactive_canonical_plane),
        ("wrong_workers", "canonical_native_configuration", lambda r: r["cohorts"][0]["build"]["receipt"].update(worker_threads=31)),
        ("no_native_progress", "no_completed_native_rapier_progress", lambda r: r["cohorts"][0]["build_progress"]["after"].update(native_tick=r["cohorts"][0]["build_progress"]["started"]["native_tick"])),
        ("no_rapier_step", "physical_sample_not_completed", lambda r: r["cohorts"][0]["build_progress"]["records"][0]["after"].update(bridge_step=0)),
        ("neutral_input", "nonneutral_input_not_applied", lambda r: r["cohorts"][0]["build_progress"]["records"][0]["after"].update(move=[0, 0])),
        ("unadmitted_input", "nonneutral_input_not_applied", lambda r: r["cohorts"][0]["build_progress"]["records"][0]["after"].update(accepted_commands=0)),
        ("stale_physics_generation", "physical_sample_generation", lambda r: r["cohorts"][0]["build_progress"]["records"][0]["after"].update(control_generation=999)),
        ("wrong_physics_owner", "physical_sample_owner_changed", lambda r: r["cohorts"][0]["build_progress"]["records"][0]["after"].update(bridge=999)),
        ("old_owner_accepted", "stale_packet_not_refused", lambda r: r["cohorts"][0]["old_owner"].update(accepted=True)),
        ("wrong_generation_reason", "stale_packet_not_refused", lambda r: r["cohorts"][0]["old_generation"].update(reason="expired")),
        ("stale_packet_mutation", "stale_packet_mutated_owner", lambda r: r["cohorts"][0]["old_generation"]["after"].update(sequence=999)),
        ("no_generation_change", "generation_not_revoked", lambda r: r["cohorts"][0]["generation_after_cancel"].update(control_generation=r["cohorts"][0]["generation_before_cancel"]["control_generation"])),
        ("fresh_refused", "fresh_control_not_admitted", lambda r: r["cohorts"][0]["fresh_control"].update(accepted=False)),
        ("missing_refusal", "refusal_inventory", lambda r: r["cohorts"][0]["refusals"].clear()),
        ("timeout_as_refusal", "native_refusal_wrong_reason", lambda r: r["cohorts"][0]["refusals"][0].update(error="timeout")),
        ("refusal_replaced_owner", "refusal_replaced_valid_owner", lambda r: r["cohorts"][0]["refusals"][0]["after"]["identity"].update(session=999)),
        ("refusal_changed_policy", "refusal_changed_valid_context", lambda r: r["cohorts"][0]["refusals"][0]["after"]["policy"].update(policy_hash="0" * 64)),
        ("old_bodies_live", "incomplete_graph_retirement", lambda r: r["cohorts"][0]["reset_retirement"].update(bodies_retired=False)),
        ("worker_unjoined", "incomplete_worker_teardown", lambda r: r["teardown"].update(worker_joined=False)),
        ("native_adapter_live", "incomplete_worker_teardown", lambda r: r["teardown"].update(adapter_destroyed=False)),
    ]
    outcomes = []
    for name, reason, mutation in controls:
        altered = deepcopy(record)
        mutation(altered)
        try:
            validate(altered, source, fixture_hash, preset_hash, platform)
        except EvidenceError as error:
            need(str(error) == reason, f"adverse_wrong_reason:{name}:{error}")
            outcomes.append({"name": name, "rejected_for": reason})
        else:
            raise EvidenceError("adverse_false_pass:" + name)
    return outcomes


def verify_files(result_path: Path, log_path: Path, process_path: Path, source: str,
                 platform: str, fixture: Path, preset_source: Path, self_test: bool) -> dict:
    record = json.loads(result_path.read_text(encoding="utf-8"))
    process = json.loads(process_path.read_text(encoding="utf-8"))
    need(process.get("source_revision", source) == source, "process_source_mismatch")
    name = "test_play_life011_" + record["rig"]
    if "results" in process:
        rows = [row for row in process["results"] if row["name"] == name]
        need(len(rows) == 1, "process_inventory")
        process = rows[0]
    need(process.get("source_revision", source) == source, "process_source_mismatch")
    need(process["name"] == name and process["status"] == "passed" and process["returncode"] == 0
         and process["timeout_seconds"] == 180 and 0 < process["seconds"] <= 180
         and process["requires_display"] is False and not process.get("timed_out", False)
         and not process.get("timeout_kind") and not process.get("launch_error")
         and not process.get("capture_error") and not process.get("diagnostic_error")
         and not process.get("skip_messages"), "process_failed_or_incomplete")
    command = process["command"]
    need(isinstance(command, list) and all(isinstance(item, str) for item in command)
         and command[1:] == ["--headless", "--path", command[3], "--script", "res://tests/" + name + ".gd"],
         "process_case_mismatch")
    log = log_path.read_text(encoding="utf-8")
    need("SCRIPT ERROR:" not in log and "ERROR:" not in log
         and not re.search(r"\bskipped\b|^\s*SKIP\b", log, re.I | re.M), "log_failed_or_skipped")
    markers = [json.loads(line.removeprefix("PLAY_LIFE011_RESULT ")) for line in log.splitlines()
               if line.startswith("PLAY_LIFE011_RESULT ")]
    need(markers == [{"schema": "play-life011-summary-v1", "rig": record["rig"],
                      "assertions": record["assertions"], "failures": 0, "source_revision": source,
                      "artifact": result_path.name, "sha256": sha256(result_path), "cohorts": 8,
                      "elapsed_usec": record["elapsed_usec"]}], "original_log_result_binding")
    progress = re.findall(r"^PLAY_LIFE011_PROGRESS preset=(\d+) complete=true assertions=(\d+) failures=0$", log, re.M)
    need([int(row[0]) for row in progress] == list(range(8)), "original_log_cohort_inventory")
    fixture_hash, preset_hash = sha256(fixture), sha256(preset_source)
    reduced = validate(record, source, fixture_hash, preset_hash, platform)
    if self_test:
        reduced["adverse_controls"] = adverse_controls(record, source, fixture_hash, preset_hash, platform)
    reduced.update(result_sha256=sha256(result_path), log_sha256=sha256(log_path),
                   process_sha256=sha256(process_path), fixture_sha256=fixture_hash, preset_source_sha256=preset_hash)
    return reduced


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--process-json", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--platform", choices=("Linux", "Windows"), required=True)
    parser.add_argument("--fixture", type=Path, default=ROOT / "godot/tests/play_life011_solver_case.gd")
    parser.add_argument("--preset-source", type=Path, default=ROOT / "godot/scripts/liquid_comparison_panel.gd")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        reduced = verify_files(args.result, args.log, args.process_json, args.source, args.platform,
                               args.fixture, args.preset_source, args.self_test)
        if args.output:
            need(not args.output.exists(), "output_already_exists")
            args.output.write_text(json.dumps(reduced, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(reduced, sort_keys=True))
        return 0
    except (EvidenceError, KeyError, IndexError, TypeError, ValueError, OSError, struct.error) as error:
        print(f"PLAY_LIFE011_VERIFICATION_FAILED: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
