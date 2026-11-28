#!/usr/bin/env python3
"""Independent readback of bounded goblin evidence; never operates the game.

Godot owns binary/JSON observation fingerprints and replays application actions.
This reader independently validates the finite vocabulary, every attempt, native
receipts/source fences, core observable assertions and recomputed coverage. It
does not turn reference/unit data into actual gameplay or classify every refusal
as a product defect. The CLI reads a supplied evidence file and prints a report.
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import re
import struct
from typing import Any

SCHEMA = "cybersand-goblin-transcript-v1"
MAX_BYTES = 32 * 1024 * 1024
try:
    from .vocabulary import MAX_ACTIONS, FIXTURES, POLICIES, MATERIALS, MODELS, expanded_action_valid
    from .replay_identity import valid as valid_replay_identity
except ImportError:
    from vocabulary import MAX_ACTIONS, FIXTURES, POLICIES, MATERIALS, MODELS, expanded_action_valid
    from replay_identity import valid as valid_replay_identity
KINDS = {"unit_fixture", "headless_godot", "graphical_godot", "packaged_evaluator"}
STATUSES = {"proposed", "accepted", "refused", "partial", "completed"}
CLASSIFICATIONS = {"game_observation", "not_applicable", "invalid_action", "timeout", "cancelled", "native_failure", "adapter_failure"}
EMPTY_ACTIONS = {"pause", "copy", "undo", "redo", "save_layout", "reopen_layout", "reset_fixture", "actor_reset", "single_step"}
SHAPES = {"rectangle", "outline", "line", "select_region"}
EDITS = {"brush", "erase", "rectangle", "outline", "line", "fill", "paste"}
# Independent finite expectation from authored product data, not the constructor:
# physical_actor_catalog._biped/_crawl and reference_barrel, player_actor_catalog
# _vehicle, and retained Kestrel have zero root offset; monowheel's weighted_cab
# is (0,1.5), with its tumbling_rim at (0,0). Rig.configure adds these offsets to
# the authored origin, while workbench_actor_state reports the first body.
ACTOR_ROOT_OFFSETS = {"kestrel": (0.0, 0.0), "reference_barrel": (0.0, 0.0),
                      "runner": (0.0, 0.0), "crawler": (0.0, 0.0),
                      "monowheel": (0.0, 1.5), "stuntbuggy": (0.0, 0.0)}


def actor_origin_root(model: str, spawn: Any) -> list:
    if not isinstance(model, str) or model not in ACTOR_ROOT_OFFSETS or not isinstance(spawn, list) or len(spawn) != 2:
        return []
    if not all(type(v) in (int, float) for v in spawn):
        return []
    def real(value):
        return struct.unpack('<f', struct.pack('<f', value))[0]
    try:
        if not all(math.isfinite(v) for v in spawn):
            return []
        root = [real(real(value) + offset) for value, offset in zip(spawn, ACTOR_ROOT_OFFSETS[model])]
    except (OverflowError, struct.error):
        return []
    return root if all(math.isfinite(v) for v in root) else []


def actor_point_matches(actual: Any, expected: Any) -> bool:
    """Exact pinned Vector2 encodings, including Godot's rounded JSON spelling.

    JSON.stringify's default decimal output can spell one native float32 as a
    nearby Python float64. Decode both to the actual native representation; do
    not admit a geometric tolerance or a neighbouring representable position.
    """
    if not all(isinstance(v, list) and len(v) == 2 for v in (actual, expected)):
        return False
    if not all(type(v) in (int, float) for v in [*actual, *expected]):
        return False
    try:
        return all(math.isfinite(v) for v in [*actual, *expected]) and struct.pack('<2f', *actual) == struct.pack('<2f', *expected)
    except (OverflowError, struct.error):
        return False


def actor_origin_parts(actor: dict, model: str, spawn: Any) -> bool:
    expected = actor_origin_root(model, spawn)
    if not expected or actor.get('model') != model or actor.get('observed') is not True:
        return False
    body = actor.get('state')
    if not isinstance(body, dict) or not actor_point_matches(body.get('position'), expected):
        return False
    parts = body.get('retained_parts')
    if not isinstance(parts, list) or not parts or not isinstance(parts[0], dict) or not actor_point_matches(parts[0].get('position'), expected):
        return False
    if model == 'monowheel':
        origin = actor_origin_root('runner', spawn)
        if len(parts) < 2 or not isinstance(parts[1], dict) or not actor_point_matches(parts[1].get('position'), origin):
            return False
    return True


def integer(value: Any) -> bool:
    return type(value) is int or (type(value) is float and math.isfinite(value) and value.is_integer())


def bounded(value: Any, minimum: int, maximum: int) -> bool:
    return integer(value) and minimum <= value <= maximum


def adapter_version(observation: Any) -> int:
    """Absent/v1/v2 retain their historical oracle; only exact v3 adds lineage."""
    value = observation.get("adapter_version", 1) if isinstance(observation, dict) else None
    return int(value) if bounded(value, 1, 3) else 0


def lineage_source(observation: dict) -> dict:
    native = observation.get("native", {})
    if not isinstance(native, dict):
        native = {}
    return {key: native.get(key, -1) for key in ("generation", "revision", "tick")}


def lineage_native_valid(observation: Any) -> bool:
    if not isinstance(observation, dict) or not isinstance(observation.get("native"), dict):
        return False
    native = observation["native"]
    return (all(bounded(native.get(key), 0, 2**63 - 1) for key in ("generation", "revision", "tick"))
            and native.get("failed") is False)


def lineage_construction(receipt: Any, observation: dict) -> bool:
    """Independently bind a published construction receipt to its actual owner."""
    if not isinstance(receipt, dict) or not lineage_native_valid(observation):
        return False
    values = receipt.get("canonical_bytes")
    shape = (receipt.get("kind") == "applied_run" and bounded(receipt.get("schema_version"), 1, 1)
            and bounded(receipt.get("completed_tick"), 0, 0)
            and bounded(receipt.get("session_generation"), 0, 2**63 - 1)
            and receipt["session_generation"] == observation["native"]["generation"]
            and isinstance(values, list) and 52 <= len(values) <= 1048576
            and all(bounded(value, 0, 255) for value in values))
    if not shape:
        return False
    raw = bytes(int(value) for value in values)
    # Primary native contract: liquid_run_receipt.hpp build_applied_run_receipt
    # and prepared_setup_identity.hpp encoding::Writer use these exact LE
    # header fields. An old hashed payload with relabelled outer facts fails.
    return (raw[:28] == struct.pack("<I", 24) + b"cybersand-run-receipt-v1"
            and struct.unpack_from("<H", raw, 28)[0] == 1
            and struct.unpack_from("<Q", raw, 36)[0] == observation["native"]["generation"]
            and struct.unpack_from("<Q", raw, 44)[0] == 0
            and hashlib.sha256(raw).hexdigest() == receipt.get("receipt_hash"))


class MaterialLineageEvidence:
    """Reconstruct applicability from native tape evidence, never its boolean.

    The product contract preserves live cells across retaining replacements.
    Positive progression proves exposure, not necessarily changed inert cells.
    Only acknowledged ordinary fresh construction can re-establish the authored
    relationship. This reader does not call the adapter's implementation.
    """
    FRESH = frozenset({"reset_fixture", "replace_fixture", "restore_start", "reopen_layout"})
    RETAINING = frozenset({"actor_place", "actor_reset", "actor_remove", "actor_move", "actor_replace",
                          "actor_equipment", "response_mode", "actor_settings"})

    def __init__(self, initialization: Any):
        self.state, self.source, self.reset_witness = "unknown", {}, {}
        self.exposure_source = {}
        if not isinstance(initialization, dict):
            return
        observed, receipt = initialization.get("observation", {}), initialization.get("native_receipt", {})
        if (initialization.get("ok") is True and isinstance(observed, dict) and isinstance(observed.get("native"), dict)
                and observed.get("paused") is True and observed.get("native", {}).get("paused") is True
                and observed.get("native", {}).get("tick") == 0 and observed.get("scene_identity")
                and observed.get("authored_digest") == observed.get("scene_identity")
                and lineage_construction(receipt, observed)):
            self.state, self.source = "authored_compatible", lineage_source(observed)
            self.reset_witness = {"source": self.source.copy(), "receipt_hash": receipt["receipt_hash"]}

    def observe(self, observed: dict) -> None:
        current = lineage_source(observed)
        native = observed.get("native", {})
        if not lineage_native_valid(observed):
            self.state = "unknown"
        elif current["tick"] > 0:
            self.state = "simulation_exposed"
            self.exposure_source = current.copy()
        elif not self.source or current["generation"] != self.source.get("generation"):
            self.state = "unknown"
        elif self.state != "simulation_exposed" and (
                observed.get("paused") is not True or native.get("paused") is not True
                or current["tick"] < self.source.get("tick", 0) or current["revision"] < self.source.get("revision", 0)):
            self.state = "unknown"
        self.source = current

    def claimed(self, observed: dict) -> bool:
        claim, native = observed.get("material_lineage"), observed.get("native", {})
        if (not isinstance(native, dict) or not isinstance(claim, dict)
                or claim.get("schema") != "cybersand-goblin-material-lineage-v1"
                or claim.get("state") != self.state or not isinstance(claim.get("source"), dict)
                or set(claim["source"]) != {"generation", "revision", "tick"}
                or any(not bounded(value, 0, 2**63 - 1) for value in claim["source"].values())
                or claim["source"] != lineage_source(observed)):
            return False
        witness = claim.get("witness")
        if not isinstance(witness, dict) or not isinstance(witness.get("source"), dict):
            return False
        origin = witness["source"]
        if (set(origin) != {"generation", "revision", "tick"}
                or any(not bounded(origin.get(key), 0, 2**63 - 1) for key in ("generation", "revision", "tick"))
                or origin["generation"] > native.get("generation", -1)):
            return False
        if self.state == "authored_compatible":
            return (witness.get("kind") == "authored_construction" and origin["tick"] == 0
                    and witness.get("action") in self.FRESH | {"fixture_install"} and bool(self.reset_witness)
                    and origin == self.reset_witness["source"]
                    and witness.get("receipt_hash") == self.reset_witness["receipt_hash"])
        if self.state == "simulation_exposed":
            return (witness.get("kind") == "native_progress" and origin["tick"] > 0
                    and bool(self.exposure_source) and origin == self.exposure_source)
        return self.state == "unknown" and witness.get("kind") in {
            "invalid_source", "unobserved_generation", "unobserved_running", "nonmonotonic_source",
            "unproven_retained_lineage", "unacknowledged_replacement", "partial_native_effect"}

    def record(self, row: dict, check) -> None:
        before, after = row["before"], row["after"]
        self.observe(before)
        check(row, "material_lineage_before", self.claimed(before), "evidence")
        prior, name = self.state, row["action"]["id"]
        complete = row.get("status") == "completed" and row.get("admission", {}).get("accepted") is True
        replaced = (lineage_native_valid(before) and lineage_native_valid(after)
                    and after["native"]["generation"] > before["native"]["generation"])
        if replaced and complete and name in self.FRESH | self.RETAINING:
            receipt = row.get("native_receipt", {})
            acknowledged = lineage_construction(receipt, after)
            check(row, "material_lineage_replacement_evidence", acknowledged, "evidence")
            if (name in self.FRESH and acknowledged and after.get("paused") is True
                    and after["native"].get("paused") is True and after["native"]["tick"] == 0):
                self.state, self.source = "authored_compatible", lineage_source(after)
                self.reset_witness = {"source": self.source.copy(), "receipt_hash": receipt["receipt_hash"]}
            elif name in self.RETAINING and acknowledged:
                stable_start = (prior == "authored_compatible" and before.get("paused") is True
                                and before["native"].get("paused") is True and after.get("paused") is True
                                and after["native"].get("paused") is True
                                and before["native"]["tick"] == after["native"]["tick"] == 0)
                self.state = prior if prior == "simulation_exposed" or stable_start else "unknown"
                self.source = lineage_source(after)
            else:
                self.state = "unknown"
        elif replaced:
            self.state = "unknown"
        elif (not complete and lineage_native_valid(before) and lineage_native_valid(after)
              and before["native"]["revision"] != after["native"]["revision"] and prior != "simulation_exposed"):
            self.state = "unknown"
        self.observe(after)
        check(row, "material_lineage_after", self.claimed(after), "evidence")


def canonical(value: Any) -> str:
    """Local evidence digest, deliberately not a claim to Godot float formatting."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False)


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def keys(args: dict, required: set[str], optional: set[str] = frozenset()) -> bool:
    return required <= args.keys() <= required | optional


def action_error(action: Any) -> str | None:
    if not isinstance(action, dict) or not keys(action, {"id", "args"}, {"goal"}):
        return "unknown/missing action fields"
    name, args = action.get("id"), action.get("args")
    if not isinstance(name, str) or not isinstance(args, dict):
        return "action id/args type"
    if "goal" in action and (not isinstance(action["goal"], str) or len(action["goal"]) > 240):
        return "goal exceeds 240 characters"
    valid = False
    if name in EMPTY_ACTIONS:
        valid = not args
    elif name == "play":
        valid = keys(args, set(), {"ticks"}) and bounded(args.get("ticks", 4), 1, 32)
    elif name == "wait_ticks":
        valid = keys(args, {"ticks"}) and bounded(args.get("ticks"), 1, 32)
    elif name == "select_material":
        valid = keys(args, {"material"}) and integer(args.get("material")) and args["material"] in MATERIALS
    elif name in ("brush", "erase"):
        valid = keys(args, {"x", "y", "radius"}) and bounded(args.get("x"), 8, 503) and bounded(args.get("y"), 8, 503) and bounded(args.get("radius"), 0, 4)
    elif name in SHAPES:
        valid = keys(args, {"x0", "y0", "x1", "y1"}) and all(bounded(args.get(key), 8, 503) for key in ("x0", "y0", "x1", "y1"))
        valid = valid and abs(args["x1"] - args["x0"]) < 64 and abs(args["y1"] - args["y0"]) < 64
    elif name in ("fill", "paste"):
        valid = keys(args, {"x", "y"}) and bounded(args.get("x"), 8, 503) and bounded(args.get("y"), 8, 503)
    elif name == "camera":
        valid = keys(args, {"x", "y", "width", "height"}) and bounded(args.get("x"), 0, 256) and bounded(args.get("y"), 0, 256) and integer(args.get("width")) and integer(args.get("height")) and args["width"] in (240, 480) and args["height"] in (135, 270)
    elif name in ("actor_select", "actor_pilot"):
        valid = keys(args, {"actor_id"}) and bounded(args.get("actor_id"), 1, 64)
    elif name == "actor_place":
        valid = keys(args, {"model", "x", "y"}) and args.get("model") in MODELS and bounded(args.get("x"), 32, 448) and bounded(args.get("y"), 32, 224)
    elif name == "actor_drive":
        valid = keys(args, {"direction", "ticks"}) and args.get("direction") in ("left", "right", "up", "down") and bounded(args.get("ticks"), 1, 16)
    elif name == "panel":
        valid = keys(args, {"panel", "open"}) and args.get("panel") == "details" and type(args.get("open")) is bool
    else:
        valid = expanded_action_valid(name, args)
    return None if valid else "unknown action or out-of-range arguments"


def capture_errors(capture: Any, *, completed: bool = False) -> list[str]:
    if not isinstance(capture, dict):
        return ["capture is not an object"]
    if not capture:
        return ["completed action lacks native capture"] if completed else []
    if "error" in capture and not completed:
        return []  # Failed capture remains attempted evidence, never a full readback.
    region, values, receipt = capture.get("region"), capture.get("materials"), capture.get("native_receipt", {})
    if not isinstance(region, list) or len(region) != 4 or not all(integer(v) for v in region):
        return ["capture rectangle is not four integers"]
    if not isinstance(values, list):
        return ["capture materials absent"]
    x, y, width, height = map(int, region)
    errors = []
    if min(x, y) < 0 or min(width, height) <= 0 or x + width > 512 or y + height > 512 or width * height > 4096:
        errors.append("capture rectangle exceeds fixture budget")
    if len(values) != width * height:
        errors.append("capture material count differs from rectangle")
    if any(not bounded(value, 0, 131) or value == 10 for value in values):
        errors.append("capture contains invalid material IDs")
    if completed and (not isinstance(receipt, dict) or receipt.get("status") != "completed" or receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld"):
        errors.append("capture lacks completed native backend receipt")
    return errors


def source_matches(capture: dict, native: dict) -> bool:
    receipt = capture.get("native_receipt", {})
    return all(integer(receipt.get(key)) and receipt[key] == native.get(key) for key in ("generation", "revision", "tick")) and receipt.get("observed_generation") == native.get("generation") and receipt.get("region") == capture.get("region")


def persistence_capture_state(capture: dict, observation: dict) -> str:
    if any(not isinstance(capture.get(key, {}), dict) for key in ("native_receipt", "admission", "source_before", "source_after")) or not isinstance(observation.get("native", {}), dict):
        return "invalid"
    receipt, admission = capture.get("native_receipt", {}), capture.get("admission", {})
    native = observation.get("native", {})
    if capture.get("region") != [0, 0, 512, 512] or not source_matches(capture, native):
        return "invalid"
    if receipt.get("kind") != "capture" or receipt.get("backend") != "CyberNativeCellWorld":
        return "invalid"
    if admission.get("status") != "queued" or not integer(admission.get("operation_id")) or receipt.get("operation_id") != admission["operation_id"]:
        return "invalid"
    for source in (capture.get("source_before", {}), capture.get("source_after", {})):
        if source.get("paused") is not True or source.get("failed") is not False or any(not integer(source.get(k)) or source[k] != native.get(k) for k in ("generation", "revision", "tick")):
            return "invalid"
    if observation.get("paused") is not True or native.get("failed") is not False:
        return "invalid"
    if receipt.get("status") == "completed" and "error" not in capture and capture.get("count") == 512 * 512 and isinstance(capture.get("material_sha256"), str) and len(capture["material_sha256"]) == 64:
        return "completed"
    if receipt.get("status") != "refused" or receipt.get("reason") != "Move or remove the body before editing or copying its covered cells." or receipt.get("applied") != 0 or receipt.get("changed") != 0 or "error" not in capture:
        return "invalid"
    return "native_body_protection" if any(a.get("observed") is True and a.get("id") in observation.get("actor_ids", []) for a in observation.get("actors", [])) else "invalid"


def summarize(tape: dict) -> dict:
    states, classifications, attempts, completed, pairs, triples, assertions = (Counter() for _ in range(7))
    assertions.update({"pass": 0, "fail": 0, "not_applicable": 0})
    failures, previous = [], []
    duration = 0
    for row in tape["steps"]:
        name = row["action"]["id"]
        attempts[name] += 1
        states[row["status"]] += 1
        classifications[row["classification"]] += 1
        duration += int(row["duration_usec"])
        if row["status"] == "completed":
            completed[name] += 1
            if previous:
                pairs[previous[-1] + " -> " + name] += 1
            if len(previous) == 2:
                triples[" -> ".join((*previous, name))] += 1
            previous = (previous + [name])[-2:]
        else:
            previous = []
        for assertion in row["assertions"]:
            assertions[assertion["status"]] += 1
            if assertion["status"] == "fail":
                failures.append({"step": row["index"], "id": assertion["id"], "kind": assertion["kind"]})
    return {"termination": tape.get("summary", {}).get("termination", ""), "attempted_actions": len(tape["steps"]),
            "completed_actions": states["completed"], "status_counts": dict(states), "classification_counts": dict(classifications),
            "action_attempts": dict(attempts), "completed_features": dict(completed), "distinct_completed_features": len(completed),
            "completed_adjacent_pairs": dict(pairs), "completed_triples": dict(triples), "assertions": dict(assertions),
            "failures": failures, "duration_usec": duration}


def independent_failures(tape: dict) -> list[dict]:
    """Recheck raw observations without trusting the recorded assertion verdict."""
    failures = []
    saved = None
    saved_tick, saved_capture, saved_observation = -1, {}, {}
    saved_material_state, saved_material_lineage = "unknown", {}
    material_lineage = MaterialLineageEvidence(tape.get("initialization", {}))
    def check(row, name, condition, kind="gameplay"):
        if not condition:
            failures.append({"step": row["index"], "id": name, "kind": kind})
    for row in tape["steps"]:
        first_version, last_version = adapter_version(row["before"]), adapter_version(row["after"])
        modern_lineage = first_version == last_version == 3
        if not first_version or not last_version or (3 in (first_version, last_version) and not modern_lineage):
            check(row, "adapter_observation_version", False, "evidence")
            continue
        if modern_lineage:
            material_lineage.record(row, check)
        if row["classification"] in {"not_applicable", "invalid_action", "adapter_failure"}:
            continue
        name, args = row["action"]["id"], row["action"]["args"]
        before, after = row["before"], row["after"]
        start, end = before.get("native", {}), after.get("native", {})
        available = isinstance(start, dict) and isinstance(end, dict) and all(bounded(state.get(key), 0, 2**63 - 1) for state in (start, end) for key in ("generation", "revision", "tick"))
        check(row, "native_observation_available", available, "evidence")
        if not available:
            continue
        check(row, "native_world_healthy", end.get("failed") is False)
        if start["generation"] == end["generation"]:
            check(row, "native_tick_monotonic", end["tick"] >= start["tick"])
        if row["status"] != "completed":
            continue
        interval = row["interval"]
        if name == "pause":
            check(row, "pause_ui_state", after.get("paused") is True)
            valid_interval = bounded(interval.get("observed_frames"), 3, 2**63 - 1) and integer(interval.get("start_tick")) and integer(interval.get("end_tick"))
            check(row, "pause_interval_observed", valid_interval, "evidence")
            if valid_interval:
                check(row, "paused_native_inactivity", interval["start_tick"] == interval["end_tick"])
        elif name in {"play", "wait_ticks"}:
            check(row, "play_ui_state", after.get("paused") is False)
            valid_interval = integer(interval.get("start_tick")) and integer(interval.get("end_tick"))
            check(row, "play_interval_observed", valid_interval, "evidence")
            if valid_interval:
                check(row, "native_simulation_progress", interval["end_tick"] - interval["start_tick"] >= args.get("ticks", 4))
        elif name == "select_material":
            check(row, "selected_material", after.get("material") == args["material"])
        elif name in EDITS:
            first, last, receipt = row["capture_before"], row["capture_after"], row["native_receipt"]
            captures_ok = not capture_errors(first, completed=True) and not capture_errors(last, completed=True) and first.get("region") == last.get("region")
            check(row, "independent_material_readback", captures_ok, "evidence")
            check(row, "native_edit_completed", receipt.get("status") == "completed" and receipt.get("kind") == "edit" and receipt.get("backend") == "CyberNativeCellWorld", "evidence")
            check(row, "native_edit_source_identity", all(integer(receipt.get(key)) and receipt[key] == end.get(key) for key in ("generation", "revision", "tick")) and receipt.get("observed_generation") == end.get("generation"), "evidence")
            if captures_ok:
                check(row, "native_capture_source_identity", source_matches(first, start) and source_matches(last, end), "evidence")
                changed = sum(a != b for a, b in zip(first["materials"], last["materials"]))
                check(row, "native_changed_accounting", receipt.get("changed") == changed)
                check(row, "native_applied_accounting_bounds", bounded(receipt.get("applied"), changed, len(last["materials"])), "evidence")
        elif name == "camera":
            check(row, "camera_state", {k: after.get("camera", {}).get(k) for k in ("origin", "size")} == {"origin": [min(args["x"], 512 - args["width"]), min(args["y"], 512 - args["height"])], "size": [args["width"], args["height"]]})
        elif name == "panel":
            check(row, "panel_state", after.get("details_open") is args["open"])
        elif name == "actor_select":
            check(row, "actor_selection", after.get("selected_actor") == args["actor_id"])
            check(row, "inspection_preserves_pilot", after.get("pilot_actor") == before.get("pilot_actor"))
        elif name == "actor_drive":
            delivery = row.get("actor_delivery", {})
            initial, during = delivery.get("before", {}), delivery.get("during", {})
            check(row, "actor_input_ownership", before.get("pilot_actor", 0) > 0 and delivery.get("instance_id") == before["pilot_actor"] and during.get("instance_id") == before["pilot_actor"] and during.get("producer") == "human" and during.get("lease_remaining", 0) > 0 and initial.get("generation") == during.get("generation"))
            check(row, "actor_input_admission_observed", during.get("accepted", 0) > initial.get("accepted", 0) and during.get("last_sequence", 0) > initial.get("last_sequence", 0), "evidence")
            move = delivery.get("sampled_command", {}).get("move", [])
            direction = args["direction"]
            delivered = isinstance(move, list) and len(move) == 2 and all(type(value) in (int, float) for value in move)
            if delivered:
                delivered = {"left": move[0] < 0, "right": move[0] > 0, "up": move[1] < 0, "down": move[1] > 0}[direction]
                if direction == "down" and during.get("observation", {}).get("model") == "kestrel":
                    delivered = delivery.get("sampled_ports", {}).get("ports", {}).get("s") is True
            check(row, "actor_requested_input_sampled", delivered)
            check(row, "actor_input_released", delivery.get("released_command", {}).get("move") == [0, 0])
        elif name == "single_step":
            check(row, "single_step_remains_paused", after.get("paused") is True)
            check(row, "single_step_native_progress", end["tick"] == start["tick"] + 1)
        elif name == "actor_pilot":
            check(row, "explicit_pilot_identity", after.get("pilot_actor") == args["actor_id"])
            check(row, "pilot_retains_actor_roster", before.get("actor_ids") == after.get("actor_ids"))
        elif name == "actor_place":
            old_ids, new_ids = before.get("actor_ids", []), after.get("actor_ids", [])
            added = [value for value in new_ids if value not in old_ids]
            check(row, "actor_place_roster", len(added) == 1 and len(new_ids) == len(old_ids) + 1 and all(value in new_ids for value in old_ids))
            placed = next((actor for actor in after.get("actors", []) if actor.get("id") in added), {})
            check(row, "actor_place_model", placed.get("model") == args["model"])
            spawn = [args["x"], args["y"]]
            root = actor_origin_root(args["model"], spawn)
            strict = bounded(after.get("adapter_version", 1), 2, 2**31 - 1) or tape.get("header", {}).get("fixture_version", 1) >= 2
            authoring = row.get("actor_authoring", {})
            check(row, "actor_place_position", bool(root) and actor_point_matches(placed.get("position"), root)
                  and (not strict or actor_point_matches(authoring.get("body", {}).get("position"), root)))
            if strict:
                check(row, "actor_place_authored_spawn", placed.get("authored_spawn") == spawn
                      and authoring.get("spawn") == spawn and authoring.get("authored_after", {}).get("spawn") == spawn)
                check(row, "actor_place_part_origins", actor_origin_parts(placed, args["model"], spawn))
            check(row, "actor_place_native_publication", end["generation"] > start["generation"])
        elif name == "actor_reset":
            check(row, "actor_reset_roster", before.get("actor_ids") == after.get("actor_ids"))
            check(row, "actor_reset_native_publication", end["generation"] > start["generation"])
            if bounded(after.get("adapter_version", 1), 2, 2**31 - 1) or tape.get("header", {}).get("fixture_version", 1) >= 2:
                prior = next((a for a in before.get("actors", []) if a.get("id") == before.get("selected_actor")), {})
                actor = next((a for a in after.get("actors", []) if a.get("id") == before.get("selected_actor")), {})
                spawn, model = prior.get("authored_spawn"), prior.get("model", "")
                root, authoring = actor_origin_root(model, spawn), row.get("actor_authoring", {})
                check(row, "actor_reset_authored_position", bool(root) and authoring.get("spawn") == spawn
                      and actor.get("authored_spawn") == spawn and actor_point_matches(actor.get("position"), root)
                      and actor_point_matches(authoring.get("body", {}).get("position"), root))
                check(row, "actor_reset_part_origins", actor_origin_parts(actor, model, spawn))
        elif name == "actor_move":
            prior = next((a for a in before.get("actors", []) if a.get("id") == before.get("selected_actor")), {})
            actor = next((a for a in after.get("actors", []) if a.get("id") == before.get("selected_actor")), {})
            spawn, model = [args["x"], args["y"]], prior.get("model", "")
            root = actor_origin_root(model, spawn)
            check(row, "authored_reset_spawn_readback", actor.get("authored_spawn") == spawn)
            check(row, "actor_move_actual_position", bool(root) and actor_point_matches(actor.get("position"), root))
            check(row, "actor_move_part_origins", actor_origin_parts(actor, model, spawn))
        elif name == "actor_replace":
            prior = next((a for a in before.get("actors", []) if a.get("id") == before.get("selected_actor")), {})
            actor = next((a for a in after.get("actors", []) if a.get("id") == before.get("next_actor_id")), {})
            spawn, model = prior.get("authored_spawn"), args["model"]
            root = actor_origin_root(model, spawn)
            check(row, "actor_replacement_authored_spawn", bool(root) and actor.get("authored_spawn") == spawn)
            check(row, "actor_replacement_position", bool(root) and actor_point_matches(actor.get("position"), root))
            check(row, "actor_replacement_part_origins", actor_origin_parts(actor, model, spawn))
        elif name == "save_layout":
            saved = row.get("persistence", {}).get("read_authored_digest")
            check(row, "authored_save_readback", bool(saved) and saved == after.get("authored_digest"))
            saved_tick, saved_capture, saved_observation = end["tick"], row.get("persistence_capture", {}), after
            if modern_lineage:
                saved_material_state = material_lineage.state
                saved_material_lineage = deepcopy(after.get("material_lineage", {}))
                check(row, "save_material_lineage_identity", row.get("persistence", {}).get("saved_material_lineage") == saved_material_lineage, "evidence")
                if "persistence_capture" not in row:
                    check(row, "save_capture_evidence", False, "evidence")
            if "persistence_capture" in row:
                state = persistence_capture_state(saved_capture, after)
                persistence = row.get("persistence", {})
                check(row, "save_capture_evidence", state != "invalid", "evidence")
                check(row, "save_native_tick_identity", persistence.get("saved_native_tick") == saved_tick, "evidence")
                check(row, "save_material_capture_identity", persistence.get("material_sha256", "") == saved_capture.get("material_sha256", ""), "evidence")
                compatible = saved_material_state == "authored_compatible" if modern_lineage else saved_tick == 0
                expected = compatible and state == "completed"
                claimed = persistence.get("native_material_equality_applicable")
                check(row, "save_material_applicability", (claimed is expected) if modern_lineage else claimed == expected, "evidence")
        elif name == "reopen_layout":
            if saved:
                check(row, "authored_reopen_identity", after.get("authored_digest") == saved)
            persistence = row.get("persistence", {})
            if modern_lineage:
                check(row, "reopen_saved_material_lineage", bool(saved_material_lineage) and persistence.get("saved_material_lineage") == saved_material_lineage, "evidence")
            saved_state = persistence_capture_state(saved_capture, saved_observation) if saved_capture else "unrecorded"
            current_state = persistence_capture_state(row.get("persistence_capture", {}), after) if "persistence_capture" in row else "unrecorded"
            custody = not modern_lineage
            if "persistence_capture" in row:
                custody = saved_state in ("completed", "native_body_protection") and current_state in ("completed", "native_body_protection") and persistence.get("saved_capture") == saved_capture and persistence.get("saved_native_tick") == saved_tick
                check(row, "reopen_capture_evidence", custody, "evidence")
                check(row, "reopen_material_capture_identity", persistence.get("saved_material_sha256", "") == saved_capture.get("material_sha256", "") and persistence.get("reopened_material_sha256", "") == row["persistence_capture"].get("material_sha256", ""), "evidence")
            if modern_lineage:
                expected = saved_material_state == "authored_compatible" and custody and saved_state == current_state == "completed"
                check(row, "reopen_material_applicability", persistence.get("native_material_equality_applicable") is expected, "evidence")
            if persistence.get("native_material_equality_applicable"):
                if not modern_lineage:
                    check(row, "reopen_material_applicability", saved_tick == 0 and ("persistence_capture" not in row or custody and saved_state == current_state == "completed"), "evidence")
                expected_materials = saved_capture.get("material_sha256", "") if "persistence_capture" in row else persistence.get("saved_material_sha256", "")
                actual_materials = row["persistence_capture"].get("material_sha256", "") if "persistence_capture" in row else persistence.get("reopened_material_sha256", "")
                check(row, "authored_reopen_materials", bool(expected_materials) and expected_materials == actual_materials)
            else:
                reason = persistence.get("native_material_equality_reason", "")
                lineage_na = ((saved_material_state == "simulation_exposed" and reason == "simulation_exposed_lineage")
                              or (saved_material_state == "unknown" and reason == "unknown_material_lineage"))
                authored_na = lineage_na if modern_lineage else saved_tick > 0 and reason in ("", "evolved_native_tick")
                justified = (authored_na and custody) or (reason == "native_body_protection" and custody and "native_body_protection" in (saved_state, current_state))
                check(row, "reopen_material_na_evidence", justified, "evidence")
        elif name == "reset_fixture":
            check(row, "reset_authored_layout", bool(after.get("scene_identity")) and after.get("authored_digest") == after.get("scene_identity"))
            check(row, "reset_native_replacement", end["generation"] > start["generation"] and end["tick"] == 0)
            saved = None
            saved_tick, saved_capture, saved_observation = -1, {}, {}
            saved_material_state, saved_material_lineage = "unknown", {}
    return failures


def _verify(tape: Any) -> dict:
    errors = []
    def issue(condition: bool, message: str):
        if not condition:
            errors.append(message)
    if not isinstance(tape, dict) or tape.get("schema") != SCHEMA:
        return {"valid": False, "errors": ["unknown transcript schema"]}
    header, steps, summary = tape.get("header"), tape.get("steps"), tape.get("summary")
    if not isinstance(header, dict) or not isinstance(steps, list) or not isinstance(summary, dict):
        return {"valid": False, "errors": ["header/steps/summary type"]}
    issue(header.get("fixture_id") in FIXTURES, "unknown fixture")
    no_installed_scene = header.get("fixture_state") == "not_installed" and not steps and summary.get("termination") in {"stopped", "initialization_failure", "fixture_failure"}
    issue(no_installed_scene or (isinstance(header.get("initial_scene_identity"), str) and bool(header.get("initial_scene_identity"))), "missing initial scene identity")
    issue(integer(header.get("fixture_version")) and header.get("fixture_version") in (1, 2), "unknown fixture version")
    issue(header.get("policy") in POLICIES, "unknown policy")
    issue("pacing_ms" not in header or bounded(header["pacing_ms"], 0, 3000), "invalid recorded pacing")
    issue(bounded(header.get("seed"), -(2**31), 2**31 - 1), "seed outside signed int32")
    issue(bounded(header.get("budget"), 1, MAX_ACTIONS), "invalid action budget")
    issue(len(steps) <= MAX_ACTIONS and bounded(header.get("budget"), len(steps), MAX_ACTIONS), "too many attempted actions")
    issue(header.get("evidence_kind") in KINDS, "missing explicit evidence kind")
    provenance = header.get("provenance", {})
    if not isinstance(provenance, dict):
        provenance = {}
    for key, size in (("source_commit", 40), ("source_tree", 40), ("godot_sha256", 64), ("native_sha256", 64), ("rapier_sha256", 64)):
        issue(isinstance(provenance.get(key), str) and re.fullmatch("[0-9a-f]{%d}" % size, provenance[key]) is not None, "missing exact " + key)
    if "replay_identity" in provenance:
        issue(valid_replay_identity(provenance), "invalid portable replay identity")
    for index, row in enumerate(steps):
        if not isinstance(row, dict):
            errors.append(f"step {index}: not an object")
            continue
        issue(row.get("index") == index, f"step {index}: noncontiguous index")
        error = action_error(row.get("action"))
        issue(error is None, f"step {index}: {error}")
        issue(row.get("status") in STATUSES, f"step {index}: unknown status")
        issue(row.get("classification") in CLASSIFICATIONS, f"step {index}: unknown classification")
        issue(bounded(row.get("duration_usec"), 0, 3600000000), f"step {index}: duration outside bound")
        for key in ("before", "after", "admission", "native_receipt", "interval"):
            issue(isinstance(row.get(key), dict), f"step {index}: {key} type")
        for key in ("capture_before", "capture_after"):
            errors.extend(f"step {index}: {key}: {error}" for error in capture_errors(row.get(key)))
        optional_captures = []
        if "persistence_capture" in row:
            optional_captures.append(row["persistence_capture"])
        if "persistence" in row:
            issue(isinstance(row["persistence"], dict), f"step {index}: persistence type")
            if isinstance(row["persistence"], dict) and "saved_capture" in row["persistence"]:
                optional_captures.append(row["persistence"]["saved_capture"])
        for captured in optional_captures:
            issue(isinstance(captured, dict), f"step {index}: persistence capture type")
            if not isinstance(captured, dict):
                continue
            for key in ("native_receipt", "admission", "source_before", "source_after"):
                issue(key not in captured or isinstance(captured[key], dict), f"step {index}: persistence capture {key} type")
            if "region" in captured:
                issue(isinstance(captured["region"], list) and len(captured["region"]) == 4 and all(bounded(v, 0, 512) for v in captured["region"]), f"step {index}: persistence capture region")
            issue("error" not in captured or isinstance(captured["error"], str), f"step {index}: persistence capture error type")
        if not isinstance(row.get("assertions"), list):
            errors.append(f"step {index}: assertion list absent")
        else:
            issue(bool(row["assertions"]), f"step {index}: no independent assertion/applicability result")
            for item in row["assertions"]:
                issue(isinstance(item, dict) and isinstance(item.get("id"), str) and item.get("status") in {"pass", "fail", "not_applicable"} and item.get("kind") in {"gameplay", "evidence"}, f"step {index}: malformed assertion")
        for key in ("observation_sha256", "semantic_sha256"):
            issue(isinstance(row.get(key), str) and re.fullmatch("[0-9a-f]{64}", row[key]) is not None, f"step {index}: {key} missing")
    if errors:
        return {"valid": False, "errors": errors, "evidence_kind": header.get("evidence_kind")}
    reduced = summarize(tape)
    issue(summary == reduced, "summary does not account for every attempted step")
    try:
        independently_failed = independent_failures(tape)
    except (TypeError, ValueError, KeyError, IndexError, AttributeError):
        return {"valid": False, "errors": errors + ["nested observation evidence has invalid types"], "evidence_kind": header.get("evidence_kind")}
    recorded_failures = {(item["step"], item["id"]) for item in reduced["failures"]}
    uncovered = [item for item in independently_failed if (item["step"], item["id"]) not in recorded_failures]
    # Extra independent checks can reveal an unreported failure; never relabel it
    # as an owner-accepted defect or silently trust the first observer's PASS.
    issue(not uncovered, "independent raw readback found failures absent from recorded assertions")
    return {"valid": not errors, "errors": errors, "evidence_kind": header.get("evidence_kind"),
            "summary": reduced, "independent_failures": independently_failed, "unreported_failures": uncovered,
            "fingerprint_scope": "Godot in-process validator owns canonical observation/semantic hashes; this reader independently recomputes coverage and raw game invariants"}


def verify(tape: Any) -> dict:
    try:
        return _verify(tape)
    except (TypeError, ValueError, KeyError, IndexError, AttributeError, RecursionError) as error:
        return {"valid": False, "errors": ["malformed evidence: " + type(error).__name__]}


def load(path: Path) -> dict:
    with path.open("rb") as handle:
        raw = handle.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("transcript exceeds 32 MiB")
    return json.loads(raw, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("nonfinite JSON constant: " + value)))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("transcript", type=Path)
    args = parser.parse_args()
    try:
        result = verify(load(args.transcript))
    except (OSError, ValueError, RecursionError) as error:
        result = {"valid": False, "errors": [str(error)]}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
