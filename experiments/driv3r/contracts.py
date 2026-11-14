"""Versioned host-owned records. Model answers select IDs, never executable data.

These validators are intentionally independent of llama.cpp and Godot. Native
authority remains the final admission boundary; validation here only narrows it.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
from typing import Any, Protocol

from . import PROTOCOL

TERMINAL_STATUSES = frozenset({"success", "stop", "budget_exhausted", "invalid_decision",
                              "model_failure", "native_refusal", "cancelled"})
ID = re.compile(r"[A-Za-z0-9_-]{1,80}\Z")
SHA = re.compile(r"[a-f0-9]{64}\Z")


class Refusal(ValueError):
    """Fail closed before admitting an operation."""


def canonical(value: Any) -> bytes:
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":"),
                          ensure_ascii=False, allow_nan=False).encode("utf-8")
    except (TypeError, ValueError, RecursionError) as exc:
        raise Refusal("Record is not finite JSON") from exc


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def integer(value: Any, low: int, high: int, label: str) -> int:
    if type(value) is not int or not low <= value <= high:
        raise Refusal(f"{label} must be an integer in [{low},{high}]")
    return value


def finite(value: Any, low: float, high: float, label: str) -> float:
    if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
        raise Refusal(f"{label} must be finite in [{low},{high}]")
    return float(value)


def exact(value: Any, keys: set[str], label: str) -> None:
    if type(value) is not dict or set(value) != keys:
        raise Refusal(f"{label} requires exactly {sorted(keys)}")


def identifier(value: Any, label: str) -> str:
    if type(value) is not str or ID.fullmatch(value) is None:
        raise Refusal(f"Invalid {label}")
    return value


def point(value: Any, label: str) -> list[int]:
    if type(value) is not list or len(value) != 2:
        raise Refusal(f"{label} must be an integer XY pair")
    return [integer(v, 0, 511, label) for v in value]


def validate_operations(operations: Any, focus: list[int], material: int,
                        max_cells: int = 1024) -> set[tuple[int, int]]:
    """Stage A intentionally supports a narrow existing Art rectangle subset."""
    if type(operations) is not list or not 1 <= len(operations) <= 16:
        raise Refusal("Expected 1..16 host-compiled Art rectangles")
    if type(focus) is not list or len(focus) != 4:
        raise Refusal("Invalid host focus")
    x, y, w, h = [integer(v, 0, 512, "focus") for v in focus]
    if not w or not h or x+w > 512 or y+h > 512:
        raise Refusal("Host focus exceeds World")
    integer(material, 0, 131, "material")
    integer(max_cells, 1, 1024, "cell budget")
    cells: set[tuple[int, int]] = set()
    visits = 0
    for op in operations:
        exact(op, {"shape", "material", "x0", "y0", "x1", "y1"}, "Art rectangle")
        if op["shape"] != "rectangle" or type(op["material"]) is not int or op["material"] != material:
            raise Refusal("Shape/material outside host authority")
        x0, y0, x1, y1 = [integer(op[k], 0, 511, k) for k in ("x0", "y0", "x1", "y1")]
        if not (x <= x0 <= x1 < x+w and y <= y0 <= y1 < y+h):
            raise Refusal("Action outside authorized focus")
        visits += (x1-x0+1)*(y1-y0+1)
        if visits > max_cells:
            raise Refusal("Action exceeds candidate-visit budget")
        cells.update((a, b) for b in range(y0, y1+1) for a in range(x0, x1+1))
    return cells


def validate_observation(value: Any) -> None:
    exact(value, {"protocol", "episode_id", "step", "mode", "objective", "subgoal", "world",
                  "permissions", "cursor", "target", "local", "geometry", "history", "budgets",
                  "previous_native_ack"}, "observation")
    if value["protocol"] != PROTOCOL or value["mode"] not in ("direct", "fuzzy"):
        raise Refusal("Unsupported observation protocol/mode")
    identifier(value["episode_id"], "episode ID")
    integer(value["step"], 0, 64, "step")
    for field in ("objective", "subgoal"):
        if type(value[field]) is not str or not 1 <= len(value[field]) <= 2048:
            raise Refusal("Invalid objective/subgoal")
    world = value["world"]
    exact(world, {"id", "generation", "revision", "tick", "material_sha256", "world_material_sha256"}, "World identity")
    if type(world["id"]) is not str or not 1 <= len(world["id"]) <= 128:
        raise Refusal("Invalid World ID")
    for field in ("generation", "revision", "tick"):
        integer(world[field], 0, 2**63-1, field)
    for field in ("material_sha256", "world_material_sha256"):
        if type(world[field]) is not str or SHA.fullmatch(world[field]) is None:
            raise Refusal("Missing source-qualified material hash")
    permissions = value["permissions"]
    exact(permissions, {"focus", "material", "protected_rectangles"}, "permissions")
    if permissions["focus"] != [0, 0, 96, 96] or permissions["material"] != 58:
        raise Refusal("Stage A host authority is frozen to focus96 and material58")
    if type(permissions["protected_rectangles"]) is not list or len(permissions["protected_rectangles"]) > 16:
        raise Refusal("Invalid protection set")
    for rect in permissions["protected_rectangles"]:
        if type(rect) is not list or len(rect) != 4:
            raise Refusal("Invalid protection rectangle")
        for n in rect:
            integer(n, 0, 512, "protection rectangle")
    point(value["cursor"], "cursor")
    point(value["target"], "target")
    local = value["local"]
    exact(local, {"origin", "width", "height", "materials"}, "bounded local crop")
    point(local["origin"], "crop origin")
    w, h = integer(local["width"], 1, 11, "crop width"), integer(local["height"], 1, 11, "crop height")
    if type(local["materials"]) is not list or len(local["materials"]) != w*h:
        raise Refusal("Crop material extent mismatch")
    for material in local["materials"]:
        integer(material, 0, 131, "crop material")
    if type(value["history"]) is not list or len(value["history"]) > 65:
        raise Refusal("History exceeds episode bound")
    for pos in value["history"]:
        point(pos, "visited position")
    budget = value["budgets"]
    exact(budget, {"decisions_remaining", "changed_cells_remaining", "wall_seconds_remaining"}, "budgets")
    integer(budget["decisions_remaining"], 0, 64, "decision budget")
    integer(budget["changed_cells_remaining"], 0, 4096, "changed-cell budget")
    finite(budget["wall_seconds_remaining"], 0, 3600, "wall budget")
    if type(value["geometry"]) is not dict or type(value["previous_native_ack"]) not in (dict, type(None)):
        raise Refusal("Invalid geometry/acknowledgement")
    if len(canonical(value)) > 32768:
        raise Refusal("Observation exceeds byte budget")


def validate_candidates(values: Any, observation: dict) -> None:
    validate_observation(observation)
    if type(values) is not list or not 1 <= len(values) <= 16:
        raise Refusal("Expected 1..16 finite candidate actions")
    seen = set()
    for candidate in values:
        exact(candidate, {"protocol", "id", "kind", "label", "operations", "destination", "profile",
                          "graph_node", "predicted"}, "candidate")
        cid = identifier(candidate["id"], "candidate ID")
        if cid in seen or candidate["protocol"] != PROTOCOL:
            raise Refusal("Duplicate candidate or unsupported protocol")
        seen.add(cid)
        if candidate["kind"] not in ("movement", "tool", "stop", "skip"):
            raise Refusal("Unknown action kind")
        if type(candidate["label"]) is not str or not 1 <= len(candidate["label"]) <= 512:
            raise Refusal("Invalid candidate label")
        if type(candidate["profile"]) is not str or type(candidate["graph_node"]) is not str:
            raise Refusal("Invalid discrete profile/node")
        if type(candidate["predicted"]) is not dict:
            raise Refusal("Invalid predicted effects")
        if candidate["kind"] in ("stop", "skip"):
            if candidate["operations"] != [] or candidate["destination"] is not None:
                raise Refusal("STOP/SKIP cannot contain a mutation")
        else:
            validate_operations(candidate["operations"], observation["permissions"]["focus"],
                                observation["permissions"]["material"])
            if candidate["kind"] == "movement":
                pos = point(candidate["destination"], "destination")
                old = observation["cursor"]
                if abs(pos[0]-old[0])+abs(pos[1]-old[1]) != 1 or candidate["id"] not in ("UP", "DOWN", "LEFT", "RIGHT"):
                    raise Refusal("Movement must be one cardinal cell")
                dx, dy = {"UP": (0, -1), "DOWN": (0, 1), "LEFT": (-1, 0), "RIGHT": (1, 0)}[candidate["id"]]
                if pos != [old[0]+dx, old[1]+dy]:
                    raise Refusal("Candidate ID differs from its cardinal movement")
                expected = {"shape": "rectangle", "material": 58, "x0": pos[0], "x1": pos[0], "y0": pos[1], "y1": pos[1]}
                if candidate["operations"] != [expected]:
                    raise Refusal("Movement footprint differs from destination")
            elif candidate["destination"] is not None:
                raise Refusal("Tool cannot teleport the vehicle")
    if not any(c["kind"] == "stop" for c in values):
        raise Refusal("An explicit STOP must always be available")
    if len(canonical(values)) > 65536:
        raise Refusal("Candidate set exceeds byte budget")


def validate_decision(decision: Any, observation: dict, candidates: list[dict]) -> dict:
    validate_candidates(candidates, observation)
    exact(decision, {"protocol", "question_id", "candidate_id", "probabilities", "confidence", "status",
                     "state_sha256", "candidate_set_sha256", "latency_seconds", "model_identity",
                     "backend_identity", "raw", "error"}, "decision")
    if decision["protocol"] != PROTOCOL or decision["question_id"] != "next_action" or decision["status"] != "ok":
        raise Refusal("Decision is not an admitted protocol answer")
    if decision["state_sha256"] != digest(observation) or decision["candidate_set_sha256"] != digest(candidates):
        raise Refusal("State/candidate identity mismatch")
    allowed = {c["id"]: c for c in candidates}
    cid = decision["candidate_id"]
    if type(cid) is not str or cid not in allowed:
        raise Refusal("Unknown candidate ID")
    probs = decision["probabilities"]
    if type(probs) is not dict or set(probs) != set(allowed):
        raise Refusal("Missing or unknown probability candidates")
    for probability in probs.values():
        finite(probability, 0, 1, "probability")
    if abs(sum(probs.values())-1) > 1e-4:
        raise Refusal("Choice distribution is not normalized")
    confidence = finite(decision["confidence"], 0, 1, "confidence")
    if abs(probs[cid]-confidence) > 1e-5 or probs[cid]+1e-6 < max(probs.values()):
        raise Refusal("Choice/confidence/distribution mismatch")
    finite(decision["latency_seconds"], 0, 3600, "latency")
    for identity in ("model_identity", "backend_identity"):
        if type(decision[identity]) is not dict or not decision[identity]:
            raise Refusal("Decision identity missing")
    if decision["error"] is not None:
        raise Refusal("Errored decision cannot be applied")
    return allowed[cid]


class DecisionProvider(Protocol):
    def decide(self, observation: dict, candidates: list[dict], *, timeout_seconds: float,
               cancel_event: Any) -> dict: ...


class NativeExecutor(Protocol):
    def observe(self) -> dict: ...
    def apply(self, operations: list[dict], *, expected_generation: int, expected_revision: int,
              expected_tick: int, action_id: str, cell_budget: int) -> dict: ...
    def stop(self, reason: str) -> dict: ...
