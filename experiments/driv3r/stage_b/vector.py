"""Bounded vector-intent and path-modulation fixture for the Stage B cohort.

Two successive controller calls are necessary: a no-paint planning transition
selects direction/distance, and a later tool choice paints a host-owned path.
No target correction occurs after the intent choice. Native execution paints
the path's unique cell mask in one Art pixels operation; the ordered traversal
is an audited host construction, not a simulated physical vehicle trajectory.

HILBERT_MOTIF stitches alternating order-1 Hilbert U motifs. It is deliberately
described as a motif, not a full Hilbert curve or a continuous space-filling map.
"""
from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import time

from ..contracts import Refusal, digest, integer, point, validate_candidates
from ..controller import decision_record
from ..providers import candidate, permitted

CATALOG = Path(__file__).with_name("vector_cases.json")
ALGORITHMS = ("STRAIGHT", "BOUNDED_SERPENTINE", "HILBERT_MOTIF", "SEEDED_BRIDGE")
DIRECTIONS = {"UP": (0, -1), "DOWN": (0, 1), "LEFT": (-1, 0), "RIGHT": (1, 0)}
MAX_DISTANCE = 10
MAX_TRAVEL_RATIO = 3
MAX_TRANSVERSE_EXCURSION = 2


def load_cases(split: str | None = None) -> list[dict]:
    document = json.loads(CATALOG.read_text(encoding="utf-8"))
    if document.get("schema") != "driv3r-stage-b-vector-cases-v1":
        raise Refusal("Unsupported vector fixture catalog")
    cases = document["cases"]
    if len({c["id"] for c in cases}) != len(cases):
        raise Refusal("Duplicate vector case IDs")
    for case in cases:
        validate_case(case)
    if split not in (None, "development", "held_out"):
        raise Refusal("Unknown vector cohort split")
    return [deepcopy(case) for case in cases if split is None or case["split"] == split]


def validate_case(case: dict) -> None:
    if not isinstance(case, dict) or case.get("split") not in ("development", "held_out"):
        raise Refusal("Invalid vector case/split")
    for name in ("id", "objective", "paraphrase"):
        if type(case.get(name)) is not str or not case[name] or len(case[name]) > 2048:
            raise Refusal(f"Invalid vector {name}")
    for name in ("start", "target"):
        if any(v >= 96 for v in point(case.get(name), name)):
            raise Refusal("Vector start/target exceeds authorized focus")
    distances = case.get("distances")
    if type(distances) is not list or not 1 <= len(distances) <= 2:
        raise Refusal("Expected one or two discrete vector distances")
    for distance in distances:
        integer(distance, 1, MAX_DISTANCE, "vector distance")
    if len(set(distances)) != len(distances):
        raise Refusal("Duplicate vector distances")
    integer(case.get("seed"), 0, 2**32-1, "path seed")
    preference = case.get("preference", {})
    region = preference.get("coverage_region")
    if type(region) is not list or len(region) != 4:
        raise Refusal("Expected bounded vector coverage region")
    x, y, w, h = [integer(v, 0, 96, "coverage region") for v in region]
    if not w or not h or x+w > 96 or y+h > 96:
        raise Refusal("Vector coverage region exceeds focus")
    integer(preference.get("minimum_coverage"), 0, 31, "minimum coverage")
    ratio = preference.get("maximum_travel_ratio")
    if type(ratio) not in (int, float) or not 1 <= ratio <= MAX_TRAVEL_RATIO:
        raise Refusal("Vector preferred travel ratio exceeds declared bound")
    fixture = case.get("fixture", {})
    if type(fixture.get("id")) is not str or not fixture["id"]:
        raise Refusal("Vector native fixture ID missing")
    edits = fixture.get("edits")
    if type(edits) is not list or not len(edits) <= 16:
        raise Refusal("Invalid vector native fixture edits")
    for edit in edits:
        if type(edit) is not list or len(edit) != 5:
            raise Refusal("Expected [x,y,w,h,material] native fixture edit")
        ex, ey, ew, eh, material = edit
        for value in edit:
            integer(value, 0, 96, "fixture edit")
        if not ew or not eh or ex+ew > 96 or ey+eh > 96 or material not in (28, 58):
            raise Refusal("Vector fixture edit exceeds host limits")


def _sample(seed: int, column: int) -> int:
    """Version-independent deterministic discrete jitter, values -1, 0, +1."""
    value = hashlib.sha256(f"driv3r-vector-path-v1:{seed}:{column}".encode()).digest()
    return int.from_bytes(value[:8], "big") % 3 - 1


def generate_path(start: list[int], direction: str, distance: int, algorithm: str,
                  *, seed: int = 0) -> list[list[int]]:
    """Generate a cardinal cell walk with an exact selected displacement.

    Coordinates use a local longitudinal axis u and its clockwise normal v.
    Every algorithm stays in 0<=u<=distance, |v|<=2 and travels <=3*distance.
    Bounds against the actual native focus/materials are checked separately.
    """
    point(start, "path start")
    integer(distance, 1, MAX_DISTANCE, "path distance")
    integer(seed, 0, 2**32-1, "path seed")
    if direction not in DIRECTIONS or algorithm not in ALGORITHMS:
        raise Refusal("Unknown vector direction or path algorithm")
    local = [[0, 0]]

    def step(u: int, v: int) -> None:
        if abs(u-local[-1][0])+abs(v-local[-1][1]) != 1:
            raise Refusal("Path generator emitted a non-cardinal step")
        local.append([u, v])

    if algorithm == "STRAIGHT":
        for u in range(1, distance+1):
            step(u, 0)
    elif algorithm == "BOUNDED_SERPENTINE":
        # Alternating width-two U excursions consume six edges per two forward.
        for u in range(0, distance-1, 2):
            side = 1 if (u//2) % 2 == 0 else -1
            for a, b in ((u, side), (u, 2*side), (u+1, 2*side),
                         (u+1, side), (u+1, 0), (u+2, 0)):
                step(a, b)
        if distance % 2:
            step(distance, 0)
    elif algorithm == "HILBERT_MOTIF":
        # The order-1 Hilbert traversal is a four-cell U, rotated alternately.
        for u in range(distance):
            side = 1 if u % 2 == 0 else -1
            for a, b in ((u, side), (u+1, side), (u+1, 0)):
                step(a, b)
    else:
        # Sample a bounded bridge profile whose first and last offsets are zero.
        # At each new column, complete the vertical change using unit steps.
        for u in range(1, distance+1):
            old = local[-1][1]
            step(u, old)
            desired = 0 if u == distance else _sample(seed, u)
            while local[-1][1] != desired:
                step(u, local[-1][1]+(1 if desired > local[-1][1] else -1))
    dx, dy = DIRECTIONS[direction]
    result = [[start[0]+u*dx-v*dy, start[1]+u*dy+v*dx] for u, v in local]
    path_metrics(result, start, direction, distance)
    return result


def path_metrics(path: list[list[int]], start: list[int], direction: str,
                 distance: int, coverage_region: list[int] | None = None) -> dict:
    """Validate path geometry and return measurements, not a quality assertion."""
    point(start, "path start")
    integer(distance, 1, MAX_DISTANCE, "path distance")
    if direction not in DIRECTIONS or type(path) is not list or not 2 <= len(path) <= 3*distance+1:
        raise Refusal("Invalid or overlong vector path")
    if any(type(p) is not list or len(p) != 2 or any(type(v) is not int for v in p) for p in path):
        raise Refusal("Path coordinates must be integer XY pairs")
    dx, dy = DIRECTIONS[direction]
    endpoint = [start[0]+distance*dx, start[1]+distance*dy]
    if path[0] != start or path[-1] != endpoint:
        raise Refusal("Path does not preserve the selected displacement")
    if any(abs(a[0]-b[0])+abs(a[1]-b[1]) != 1 for a, b in zip(path, path[1:])):
        raise Refusal("Path contains a non-cardinal step")
    longitudinal = [(p[0]-start[0])*dx+(p[1]-start[1])*dy for p in path]
    transverse = [-(p[0]-start[0])*dy+(p[1]-start[1])*dx for p in path]
    if min(longitudinal) < 0 or max(longitudinal) > distance or max(map(abs, transverse)) > MAX_TRANSVERSE_EXCURSION:
        raise Refusal("Path exceeds the finite displacement corridor")
    unique = {tuple(p) for p in path}
    edges = {tuple(sorted((tuple(a), tuple(b)))) for a, b in zip(path, path[1:])}
    result = {"start": start.copy(), "endpoint": endpoint, "vector": [distance*dx, distance*dy],
              "straight_distance": distance, "travelled_length": len(path)-1,
              "travel_ratio": (len(path)-1)/distance, "unique_path_cells": len(unique),
              "retrace_visits": len(path)-len(unique), "retraced_edges": len(path)-1-len(edges),
              "max_transverse_excursion": max(map(abs, transverse)), "endpoint_error": 0}
    if coverage_region is not None:
        x, y, w, h = coverage_region
        result["coverage_cells"] = sum(x <= a < x+w and y <= b < y+h for a, b in unique)
    return result


def _pixels(path: list[list[int]]) -> dict:
    # The start cell is included. Native painting counts unique visits; travel
    # length/retraces remain in the separate, complete ordered path record.
    unique = list(dict.fromkeys(tuple(p) for p in path))
    return {"shape": "pixels", "material": 58, "points": [list(p) for p in unique]}


def _legal(native: dict, path: list[list[int]]) -> bool:
    return all(permitted(native, *p) for p in path)


class VectorProvider:
    """Two-node graph; cursor advances only after the path tool acknowledgement."""
    mode = "fuzzy"

    def __init__(self, case: dict, *, reverse_order: bool = False, paraphrase: bool = False):
        validate_case(case)
        self.case = deepcopy(case)
        self.fixture = case["fixture"]["id"]
        self.objective = case["paraphrase" if paraphrase else "objective"]
        self.cursor, self.target = case["start"].copy(), case["target"].copy()
        self.history = [self.cursor.copy()]
        self.reverse_order = reverse_order
        self.phase = 0
        self.intent: dict | None = None
        self.selected_algorithm: str | None = None
        self.selected_path: list[list[int]] | None = None
        self._offered: dict[str, str] = {}

    @property
    def subgoal(self) -> str:
        if self.phase == 0:
            return (f"PLAN ONLY: choose direction/distance from {self.cursor} toward target {self.target}. "
                    "This transition neither moves nor paints. A separate next decision chooses the path.")
        if self.phase == 1:
            return (f"Selected intent {self.intent['id']} ends at {self.intent['endpoint']}. "
                    f"Choose one legal path preserving that exact vector {self.intent['vector']}; do not redirect it. "
                    f"Desired coverage/length: {self.case['preference']}.")
        return "The selected path tool was acknowledged. Score its target error and geometry separately."

    def complete(self) -> bool:
        return self.phase == 2

    def _paths(self, native: dict, direction: str, distance: int) -> dict[str, list[list[int]]]:
        result = {}
        for algorithm in ALGORITHMS:
            path = generate_path(self.cursor, direction, distance, algorithm, seed=self.case["seed"])
            if _legal(native, path):
                result[algorithm] = path
        return result

    def candidates(self, native: dict, observation: dict) -> list[dict]:
        if observation["cursor"] != self.cursor or observation["target"] != self.target:
            raise Refusal("Vector provider observation differs from current phase state")
        result = []
        if self.phase == 0:
            for direction, (dx, dy) in DIRECTIONS.items():
                for distance in self.case["distances"]:
                    paths = self._paths(native, direction, distance)
                    if not paths:
                        continue
                    endpoint = [self.cursor[0]+dx*distance, self.cursor[1]+dy*distance]
                    effect = {"effect_type": "plan_only_no_native_mutation", "direction": direction,
                              "distance": distance, "start": self.cursor.copy(), "endpoint": endpoint,
                              "vector": [dx*distance, dy*distance], "legal_algorithms": list(paths),
                              "goal_distance": abs(endpoint[0]-self.target[0])+abs(endpoint[1]-self.target[1]),
                              "changed_cells": 0, "cursor_moves": False}
                    cid = f"INTENT_{direction}_{distance}"
                    result.append(candidate(cid, "skip", f"PLAN ONLY {direction} {distance} cells to {endpoint}; no movement or paint yet",
                                            profile="direction_distance", graph_node="vector_intent", predicted=effect))
        elif self.phase == 1:
            direction, distance = self.intent["direction"], self.intent["distance"]
            for algorithm, path in self._paths(native, direction, distance).items():
                measurements = path_metrics(path, self.cursor, direction, distance, self.case["preference"]["coverage_region"])
                operation = _pixels(path)
                changed = sum(native["materials"][(y-native["focus"][1])*native["width"]+x-native["focus"][0]] != 58
                              for x, y in operation["points"])
                effect = {"effect_type": "paint_vector_path_mask", "selected_intent": deepcopy(self.intent),
                          "algorithm": algorithm, "path_seed": self.case["seed"], "path": path,
                          "path_sha256": digest(path), "metrics": measurements,
                          "preference": deepcopy(self.case["preference"]), "changed_cells": changed,
                          "start_cell_is_painted": True, "vehicle_motion_kind": "host_path_tool_cursor_after_ack"}
                result.append(candidate(algorithm, "tool",
                                        f"{algorithm}: endpoint {measurements['endpoint']}; travel {measurements['travelled_length']} cells "
                                        f"({measurements['travel_ratio']:.2f}x); {measurements['coverage_cells']} cells in requested region",
                                        [operation], profile=algorithm.lower(), graph_node="vector_modulation", predicted=effect))
        result.append(candidate("STOP", "stop", "Stop immediately without moving or painting"))
        if self.reverse_order:
            result.reverse()
        validate_candidates(result, observation)
        self._offered = {c["id"]: digest(c) for c in result}
        return result

    def accept(self, action: dict) -> None:
        if self._offered.get(action.get("id")) != digest(action):
            raise Refusal("Vector action was not one of the exact host-offered candidates")
        if self.phase == 0 and action["kind"] == "skip" and action["graph_node"] == "vector_intent":
            self.intent = {"id": action["id"], **deepcopy(action["predicted"])}
            self.phase = 1
        elif self.phase == 1 and action["kind"] == "tool" and action["graph_node"] == "vector_modulation":
            path = action["predicted"]["path"]
            path_metrics(path, self.cursor, self.intent["direction"], self.intent["distance"])
            self.cursor = path[-1].copy()
            self.history.extend(deepcopy(path[1:]))
            self.selected_algorithm = action["id"]
            self.selected_path = deepcopy(path)
            self.phase = 2
        else:
            raise Refusal("Vector action does not match the pending graph phase")
        self._offered = {}


class VectorGeometricBaseline:
    """Nearest legal cardinal endpoint followed by the shortest available path."""
    name = "vector-geometric-straight-baseline-v1"

    def choose(self, candidates: list[dict]) -> str:
        intents = [c for c in candidates if c["kind"] == "skip"]
        paths = [c for c in candidates if c["kind"] == "tool"]
        if intents:
            return min(intents, key=lambda c: (c["predicted"]["goal_distance"], c["id"]))["id"]
        if paths:
            return min(paths, key=lambda c: (c["predicted"]["metrics"]["travelled_length"], c["id"] != "STRAIGHT", c["id"]))["id"]
        return "STOP"

    def decide(self, observed: dict, candidates: list[dict], *, timeout_seconds: float, cancel_event) -> dict:
        started = time.monotonic()
        validate_candidates(candidates, observed)
        choice = self.choose(candidates)
        return decision_record(observed, candidates, choice=choice,
                               probabilities={c["id"]: float(c["id"] == choice) for c in candidates}, confidence=1.0,
                               latency_seconds=time.monotonic()-started,
                               model_identity={"kind": "deterministic_non_model_baseline"},
                               backend_identity={"implementation": self.name}, raw={"baseline_choice": choice})


class VectorRandomBaseline(VectorGeometricBaseline):
    """Seeded, order-independent draw from legal intents/tools, optionally STOP."""
    name = "vector-seeded-random-baseline-v1"

    def __init__(self, seed: int, *, include_stop: bool = False):
        integer(seed, 0, 2**32-1, "baseline seed")
        self.seed, self.include_stop, self.calls = seed, include_stop, 0

    def choose(self, candidates: list[dict]) -> str:
        ids = sorted(c["id"] for c in candidates if self.include_stop or c["kind"] != "stop") or ["STOP"]
        draw = hashlib.sha256(f"driv3r-vector-baseline-v1:{self.seed}:{self.calls}".encode()).digest()
        self.calls += 1
        return ids[int.from_bytes(draw[:8], "big") % len(ids)]

    def decide(self, observed: dict, candidates: list[dict], *, timeout_seconds: float, cancel_event) -> dict:
        record = super().decide(observed, candidates, timeout_seconds=timeout_seconds, cancel_event=cancel_event)
        record["model_identity"] = {"kind": "seeded_random_non_model_baseline", "seed": self.seed}
        record["raw"].update(seed=self.seed, draw_index=self.calls-1, include_stop=self.include_stop,
                             sampling="hash_modulo_sorted_legal_candidates")
        return record


class VectorGeometryPreferenceBaseline(VectorGeometricBaseline):
    """Ordinary-code selector using only the geometry visible to every policy.

    Intent selection minimizes offered endpoint error. Modulation selects a
    candidate meeting its visible coverage/length preferences, then minimizes
    travelled length, breaking remaining ties by stable candidate ID. With no
    feasible tool it chooses STOP. It has no case/evaluator access, and never
    edits another policy's decisions or repairs a selected intent.
    """
    name = "vector-visible-geometry-preference-baseline-v1"

    def choose(self, candidates: list[dict]) -> str:
        if any(c["kind"] == "skip" for c in candidates):
            return super().choose(candidates)
        feasible = []
        for action in candidates:
            if action["kind"] != "tool":
                continue
            metrics = action["predicted"]["metrics"]
            preference = action["predicted"]["preference"]
            if (metrics["coverage_cells"] >= preference["minimum_coverage"] and
                    metrics["travel_ratio"] <= preference["maximum_travel_ratio"]):
                feasible.append(action)
        return min(feasible, key=lambda c: (c["predicted"]["metrics"]["travelled_length"], c["id"]))["id"] if feasible else "STOP"

    def decide(self, observed: dict, candidates: list[dict], *, timeout_seconds: float, cancel_event) -> dict:
        record = super().decide(observed, candidates, timeout_seconds=timeout_seconds, cancel_event=cancel_event)
        record["raw"].update(selector="ordinary_code_visible_finite_geometry",
                             inputs="candidate_endpoint_error_coverage_length_and_preferences",
                             no_feasible_tool="STOP", tie_break="least_travelled_length_then_candidate_id")
        return record


def score_episode(case: dict, record: dict) -> dict:
    """Score original native materials plus the recorded ordered path.

    Endpoint/path invariants and target/preference quality are separate. Failed
    requests, early STOP, and native refusal remain visible incomplete outcomes.
    Hash-chain/decision replay validation is the caller's separate custody gate.
    """
    validate_case(case)
    if record.get("fixture") != case["fixture"]["id"]:
        raise Refusal("Vector score fixture differs from episode source")
    intents = [s for s in record["steps"] if s.get("selected_action") and
               s["selected_action"]["graph_node"] == "vector_intent"]
    tools = [s for s in record["steps"] if s.get("selected_action") and
             s["selected_action"]["graph_node"] == "vector_modulation"]
    intent_row, tool_row = (intents[0] if intents else None), (tools[0] if tools else None)
    result = {"case_id": case["id"], "split": case["split"], "case_sha256": digest(case),
              "terminal_status": record["terminal_status"], "decision_count": record["decisions"],
              "elapsed_seconds": record["elapsed_seconds"], "selected_intent": None,
              "selected_algorithm": None, "intent_optimal": False, "intent_target_error": None,
              "target_reached": False, "planning_transition_only": False, "path_applied": False,
              "path_geometry_valid": False, "path_invariants_pass": False, "native_materials_match": False, "preference_met": False,
              "task_success": False, "expected_changed_cells": None, "observed_changed_cells": 0,
              "travelled_length": None, "straight_distance": None, "travel_ratio": None,
              "unique_path_cells": 0, "retrace_visits": 0, "retraced_edges": 0, "coverage_cells": 0,
              "endpoint_error": None, "failures": []}
    if intent_row is None:
        result["failures"].append("No direction/distance planning transition selected")
        return result
    intent = intent_row["selected_action"]
    effect = intent["predicted"]
    result["selected_intent"] = intent["id"]
    result["intent_target_error"] = abs(effect["endpoint"][0]-case["target"][0])+abs(effect["endpoint"][1]-case["target"][1])
    errors = [abs(c["predicted"]["endpoint"][0]-case["target"][0])+abs(c["predicted"]["endpoint"][1]-case["target"][1])
              for c in intent_row["candidates"] if c["graph_node"] == "vector_intent"]
    result["intent_optimal"] = bool(errors) and result["intent_target_error"] == min(errors)
    result["planning_transition_only"] = intent_row["host_status"] == "skipped" and intent_row["native_response"] is None
    if tool_row is None:
        result["failures"].append("No path tool selected after planning transition")
        return result
    action, payload = tool_row["selected_action"], tool_row["selected_action"]["predicted"]
    result["selected_algorithm"] = action["id"]
    result["path_applied"] = tool_row["host_status"] == "applied"
    try:
        path = payload["path"]
        measurements = path_metrics(path, case["start"], effect["direction"], effect["distance"], case["preference"]["coverage_region"])
        expected_path = generate_path(case["start"], effect["direction"], effect["distance"], action["id"], seed=case["seed"])
        result.update(measurements)
        bound_intent = (payload["selected_intent"] == {"id": intent["id"], **effect} and
                        effect["start"] == case["start"] and effect["endpoint"] == measurements["endpoint"] and
                        effect["vector"] == measurements["vector"] and
                        effect["distance"] in case["distances"] and payload["path_seed"] == case["seed"] and
                        payload["algorithm"] == action["id"])
        sequential = (intent_row["step"] < tool_row["step"] and
                      tool_row["observation"]["cursor"] == case["start"] and
                      tool_row["before_native"]["observation"]["materials"] == intent_row["before_native"]["observation"]["materials"])
        result["path_geometry_valid"] = (bound_intent and path == expected_path and
                                          payload["path_sha256"] == digest(path) and payload["metrics"] == measurements and
                                          action["operations"] == [_pixels(path)])
        result["path_invariants_pass"] = (result["path_geometry_valid"] and result["planning_transition_only"] and
                                          sequential and result["path_applied"] and record["final_cursor"] == path[-1])
        before = tool_row["before_native"]["observation"]
        after = tool_row["native_response"]["observation"] if tool_row["native_response"] else before
        width, fx, fy = before["width"], before["focus"][0], before["focus"][1]
        indices = {(y-fy)*width+x-fx for x, y in _pixels(path)["points"]}
        legal = _legal(before, path)
        expected_changed = sum(before["materials"][i] != 58 for i in indices) if legal else None
        observed_changed = sum(a != b for a, b in zip(before["materials"], after["materials"], strict=True))
        result["expected_changed_cells"] = expected_changed
        result["observed_changed_cells"] = observed_changed
        receipt = tool_row["native_response"]["receipt"] if tool_row["native_response"] else {}
        result["native_materials_match"] = (result["path_applied"] and legal and
            all(after["materials"][i] == 58 for i in indices) and
            all(a == b or (i in indices and b == 58) for i, (a, b) in enumerate(zip(before["materials"], after["materials"], strict=True))) and
            observed_changed == expected_changed == receipt.get("actual_changed_cells") and receipt.get("readback_matches") is True and
            record["final_native"]["materials"] == after["materials"])
        # Coverage is measured from actual acknowledged material, never merely
        # copied from the candidate's host prediction. The full path is retained.
        if result["path_applied"] and legal:
            x, y, w, h = case["preference"]["coverage_region"]
            result["coverage_cells"] = sum(x <= px < x+w and y <= py < y+h and
                                           after["materials"][(py-fy)*width+px-fx] == 58
                                           for px, py in set(map(tuple, path)))
        else:
            result["coverage_cells"] = 0
        result["target_reached"] = result["path_applied"] and record["final_cursor"] == case["target"]
        result["preference_met"] = (result["coverage_cells"] >= case["preference"]["minimum_coverage"] and
                                     result["travel_ratio"] <= case["preference"]["maximum_travel_ratio"])
    except (Refusal, KeyError, TypeError, ValueError, IndexError) as exc:
        result["failures"].append(f"Invalid original vector/path evidence: {type(exc).__name__}: {exc}")
    result["task_success"] = all(result[k] for k in ("target_reached", "planning_transition_only", "path_applied",
                                                      "path_invariants_pass", "native_materials_match", "preference_met"))
    if not result["task_success"]:
        result["failures"].extend(k for k in ("target_reached", "planning_transition_only", "path_applied",
                                              "path_invariants_pass", "native_materials_match", "preference_met") if not result[k])
    return result
