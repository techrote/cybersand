"""Frozen direct-drive cohort, observation-only baselines, and native scoring.

Neither baseline receives a case, fixture, full native material array, or oracle
path. The geometric policy uses precisely the local crop, target, history and
candidate effects also available to the decision model. Its conventional local
search is a deliberately strong baseline, not a model repair. Full native
materials are consulted only by candidate admission and retrospective scoring.

The provider deliberately never auto-completes. A successful Stage B episode
must contain an actual STOP decision, including the already-at-target fixture.
The generic controller's ``task_complete`` field therefore remains false; use
``score_episode(...)["task_success"]`` for this cohort's geometric outcome.
"""
from __future__ import annotations

from collections import deque
from copy import deepcopy
import heapq
import json
from pathlib import Path
import random
import threading
import time

from ..contracts import Refusal, digest, validate_candidates, validate_observation
from ..controller import decision_record, validate_episode
from ..providers import candidate, clearance, permitted


CATALOG = Path(__file__).with_name("direct_cases.json")
CASE_SCHEMA = "driv3r-stage-b-direct-cases-v1"
SCORE_SCHEMA = "driv3r-stage-b-direct-score-v1"
DIRECTIONS = (("UP", 0, -1), ("DOWN", 0, 1), ("LEFT", -1, 0), ("RIGHT", 1, 0))
BASELINE_INFORMATION = (
    "Only the model-visible local material crop, cursor, target, path history, permissions, "
    "budgets and candidate effects; no fixture catalog, full-world map or oracle action."
)


def load_cases(split: str | None = None) -> list[dict]:
    """Read the immutable versioned catalog, never a response-dependent scenario."""
    document = json.loads(CATALOG.read_text(encoding="utf-8"))
    if document.get("schema") != CASE_SCHEMA:
        raise Refusal("Unknown direct cohort schema")
    cases = document["cases"]
    if len(cases) > 6 or len({c["id"] for c in cases}) != len(cases):
        raise Refusal("Direct cohort size or identity mismatch")
    for case in cases:
        if (not case["id"].startswith("b-direct-") or case["fixture"]["id"] != case["id"]
                or case["split"] not in ("development", "held_out")
                or type(case["max_decisions"]) is not int or not 1 <= case["max_decisions"] <= 8):
            raise Refusal("Invalid direct case identity/split/budget")
        for point in (case["start"], case["target"]):
            if len(point) != 2 or any(type(v) is not int or not 0 <= v < 96 for v in point):
                raise Refusal("Direct case point outside native focus")
        for edit in case["fixture"]["edits"]:
            if len(edit) != 5 or any(type(v) is not int for v in edit):
                raise Refusal("Malformed direct native fixture edit")
            x, y, width, height, material = edit
            if (min(x, y) < 0 or min(width, height) < 1 or x+width > 96 or y+height > 96
                    or material not in (28, 58)):
                raise Refusal("Direct fixture edit outside bounded material contract")
        if not case["success"]["require_explicit_stop"]:
            raise Refusal("Direct Stage B cases require a genuine STOP decision")
    if sum(c["split"] == "development" for c in cases) > 2 or sum(c["split"] == "held_out" for c in cases) > 4:
        raise Refusal("Frozen development/held-out allocation exceeded")
    if split is not None and split not in ("development", "held_out"):
        raise ValueError("split must be development, held_out, or None")
    return [deepcopy(c) for c in cases if split is None or c["split"] == split]


def _case(value: dict | str) -> dict:
    ident = value if isinstance(value, str) else value["id"]
    selected = next((c for c in load_cases() if c["id"] == ident), None)
    if selected is None or (isinstance(value, dict) and value != selected):
        raise Refusal("Unknown or modified frozen direct case")
    return selected


def _distance(a, b) -> int:
    return abs(a[0]-b[0])+abs(a[1]-b[1])


def _clearance_requirement(case: dict) -> dict:
    criteria = case["success"]
    return {"desired_cells": criteria["desired_clearance_cells"],
            "minimum_cells": criteria["min_clearance_cells"],
            "maximum_cells": criteria["max_clearance_cells"],
            "nonincreasing_error": criteria["nonincreasing_offset_error"]}


class DirectCaseProvider:
    """Host-owned one-cell controls; poor but legal model actions stay unaltered."""

    mode = "direct"

    def __init__(self, case: dict | str, *, reverse_order: bool = False, paraphrase: bool = False):
        self.case = _case(case)
        self.fixture = self.case["fixture"]["id"]
        self.objective = self.case["paraphrase" if paraphrase else "objective"]
        self.cursor = self.case["start"].copy()
        self.target = self.case["target"].copy()
        self.history = [self.cursor.copy()]
        self.reverse_order = reverse_order

    @property
    def subgoal(self) -> str:
        requirement = _clearance_requirement(self.case)
        return (f"Reach target {self.target}, then explicitly choose STOP; current position {self.cursor}. "
                f"Wall clearance requirement: {json.dumps(requirement, sort_keys=True)}. "
                "Avoid revisiting positions. A candidate is legally paintable, not necessarily useful.")

    def complete(self) -> bool:
        return False

    def candidates(self, native: dict, observed: dict) -> list[dict]:
        if observed["cursor"] != self.cursor or observed["target"] != self.target:
            raise Refusal("Direct provider observation cursor/target mismatch")
        result = []
        requirement = _clearance_requirement(self.case)
        desired = requirement["desired_cells"]
        for ident, dx, dy in DIRECTIONS:
            x, y = self.cursor[0]+dx, self.cursor[1]+dy
            if not permitted(native, x, y):
                continue
            wall_distance = clearance(native, [x, y])
            fx, fy, _, _ = native["focus"]
            material = native["materials"][(y-fy)*native["width"]+x-fx]
            effects = {"destination": [x, y], "wall_clearance_cells": wall_distance,
                       "goal_distance": _distance([x, y], self.target),
                       "offset_error": None if desired is None else abs(wall_distance-desired),
                       "clearance_requirement": deepcopy(requirement),
                       "retrace": [x, y] in self.history, "changed_cells": int(material != 58)}
            operation = {"shape": "rectangle", "material": 58, "x0": x, "x1": x, "y0": y, "y1": y}
            result.append(candidate(ident, "movement", f"{ident}: move to ({x},{y}) and draw one cell",
                                    [operation], [x, y], "one_cell", "vehicle", effects))
        result.append(candidate("STOP", "stop", "Stop immediately without further movement or painting"))
        if self.reverse_order:
            result.reverse()
        validate_candidates(result, observed)
        return result

    def accept(self, action: dict) -> None:
        if action["kind"] != "movement" or _distance(action["destination"], self.cursor) != 1:
            raise Refusal("Direct provider advances only on an acknowledged cardinal movement")
        self.cursor = action["destination"].copy()
        self.history.append(self.cursor.copy())


def _local_geometry(observed: dict) -> tuple[set[tuple[int, int]], list[tuple[int, int]]]:
    crop = observed["local"]
    ox, oy = crop["origin"]
    width = crop["width"]
    focus = observed["permissions"]["focus"]
    fx, fy, fw, fh = focus
    guards = observed["permissions"]["protected_rectangles"]
    walkable, obstacles = set(), []
    for i, material in enumerate(crop["materials"]):
        point = (ox+i % width, oy+i//width)
        x, y = point
        guarded = any(gx <= x < gx+gw and gy <= y < gy+gh for gx, gy, gw, gh in guards)
        if material not in (0, 58):
            obstacles.append(point)
        if material in (0, 58) and not guarded and fx <= x < fx+fw and fy <= y < fy+fh:
            walkable.add(point)
    return walkable, obstacles


def _violation(wall_distance: int | None, previous_distance: int | None, requirement: dict) -> int:
    if wall_distance is None:
        return 0
    minimum, maximum, desired = (requirement["minimum_cells"], requirement["maximum_cells"],
                                  requirement["desired_cells"])
    invalid = minimum is not None and wall_distance < minimum
    invalid |= maximum is not None and wall_distance > maximum
    if requirement["nonincreasing_error"] and desired is not None and previous_distance is not None:
        invalid |= abs(wall_distance-desired) > abs(previous_distance-desired)
    return int(invalid)


def _geometric_choice(observed: dict, candidates: list[dict]) -> tuple[str, dict]:
    movement = [c for c in candidates if c["kind"] == "movement"]
    if observed["cursor"] == observed["target"] or not movement:
        return "STOP", {"reason": "target reached" if movement else "no legal movement"}
    walkable, obstacles = _local_geometry(observed)
    cursor, target = tuple(observed["cursor"]), tuple(observed["target"])
    history = {tuple(p) for p in observed["history"]}
    requirement = movement[0]["predicted"]["clearance_requirement"]
    desired = requirement["desired_cells"]
    # Only observed cells contribute to planning geometry. Exact first-step
    # distances are the same host effects supplied to the model. A future cell's
    # crop distance is an estimate when unseen obstacles could be nearer.
    distances = {p: min((_distance(p, q) for q in obstacles), default=None) for p in walkable}
    distances[cursor] = observed["geometry"]["wall_clearance_cells"]
    for action in movement:
        distances[tuple(action["destination"])] = action["predicted"]["wall_clearance_cells"]

    ranks = {}
    for action in sorted(movement, key=lambda c: c["id"]):
        first = tuple(action["destination"])
        initial = (_violation(distances[first], distances[cursor], requirement), 1,
                   0 if desired is None or distances[first] is None else abs(distances[first]-desired),
                   int(first in history))
        best = {first: initial}
        queue = [(initial, first)]
        while queue:
            cost, point = heapq.heappop(queue)
            if best.get(point) != cost:
                continue
            for _, dx, dy in DIRECTIONS:
                nxt = point[0]+dx, point[1]+dy
                if nxt not in walkable or nxt == cursor:
                    continue
                distance = distances[nxt]
                new = (cost[0]+_violation(distance, distances[point], requirement), cost[1]+1,
                       cost[2]+(0 if desired is None or distance is None else abs(distance-desired)),
                       cost[3]+int(nxt in history))
                if nxt not in best or new < best[nxt]:
                    best[nxt] = new
                    heapq.heappush(queue, (new, nxt))
        if target in best:
            rank = (0, *best[target])
        else:
            # Outside the crop, minimize observable remaining distance after a
            # local route. This is a bounded local planner, not a world oracle.
            endpoint, cost = min(best.items(), key=lambda item: (
                item[1][0], _distance(item[0], target), item[1][1], item[1][2], item[1][3], item[0]))
            rank = (1, cost[0], _distance(endpoint, target)+cost[1], cost[2], cost[3])
        ranks[action["id"]] = rank
    choice = min(ranks, key=lambda ident: (ranks[ident], ident))
    return choice, {"candidate_route_ranks": ranks, "target_in_local_crop": target in walkable,
                    "rank_order": ["target_unreachable_in_crop", "clearance_violations", "moves", "offset_error_sum", "retrace_count"]}


class GeometricPolicy:
    """Lexicographic local-grid route search using model-visible inputs only."""

    name = "stage-b-local-geometric-v1"

    def decide(self, observed: dict, candidates: list[dict], *, timeout_seconds: float,
               cancel_event: threading.Event) -> dict:
        started = time.monotonic()
        validate_observation(observed)
        validate_candidates(candidates, observed)
        choice, details = _geometric_choice(observed, candidates)
        return _baseline_record(self.name, observed, candidates, choice, started,
                                {"information": BASELINE_INFORMATION, **details})


class RandomLegalPolicy:
    """Seeded uniform legal action baseline, explicitly including STOP.

    IDs are sorted before sampling, so reversing presentation order does not
    change the random baseline. Instantiate once per episode with a logged seed.
    """

    name = "stage-b-seeded-random-legal-v1"

    def __init__(self, seed: int):
        if type(seed) is not int:
            raise ValueError("Random baseline seed must be an integer")
        self.seed, self.random, self.draws = seed, random.Random(seed), 0

    def decide(self, observed: dict, candidates: list[dict], *, timeout_seconds: float,
               cancel_event: threading.Event) -> dict:
        started = time.monotonic()
        validate_observation(observed)
        validate_candidates(candidates, observed)
        ids = sorted(c["id"] for c in candidates)
        choice = self.random.choice(ids)
        self.draws += 1
        return _baseline_record(self.name, observed, candidates, choice, started,
                                {"seed": self.seed, "draw": self.draws, "sampling_ids": ids,
                                 "sampling_probability": 1/len(ids), "includes_stop": True,
                                 "information": "Legal candidate IDs only; geometry is available but deliberately unused."},
                                probabilities={ident: 1/len(ids) for ident in ids})


def _baseline_record(name, observed, candidates, choice, started, raw, probabilities=None):
    # A deterministic planner has a one-hot distribution; the seeded random
    # baseline records its uniform sampling distribution. Neither is a neural
    # confidence claim, and equal maxima admit any selected random candidate.
    probabilities = probabilities or {c["id"]: float(c["id"] == choice) for c in candidates}
    return decision_record(observed, candidates, choice=choice,
                           probabilities=probabilities, confidence=probabilities[choice],
                           latency_seconds=time.monotonic()-started,
                           model_identity={"kind": "non_model_baseline"},
                           backend_identity={"implementation": name}, raw=raw)


def _shortest_legal_moves(native: dict, start: list[int], target: list[int]) -> int | None:
    """Retrospective full-readback oracle, never used by a decision policy."""
    target_point = tuple(target)
    queue = deque([(tuple(start), 0)])
    seen = {tuple(start)}
    while queue:
        point, distance = queue.popleft()
        if point == target_point:
            return distance
        for _, dx, dy in DIRECTIONS:
            nxt = point[0]+dx, point[1]+dy
            if nxt not in seen and permitted(native, *nxt):
                seen.add(nxt)
                queue.append((nxt, distance+1))
    return None


def score_episode(case: dict | str, record: dict) -> dict:
    """Score every original outcome from acknowledged path and actual materials.

    A model failure, invalid decision, refusal, timeout, premature STOP, extra
    movement after arrival, or corrupt record is a failure, never an omitted row.
    Oracle path length is an evaluation metric only. It excludes the mandatory
    STOP decision and does not claim an artistic or learned-policy advantage.
    """
    case = _case(case)
    criteria = case["success"]
    reasons = []
    custody_valid = True
    try:
        validate_episode(record)
    except (Refusal, ValueError, KeyError, TypeError, IndexError) as exc:
        custody_valid = False
        reasons.append(f"invalid_record: {type(exc).__name__}: {exc}")
    initial, final = record.get("initial_native"), record.get("final_native")
    if record.get("fixture") != case["fixture"]["id"] or record.get("mode") != "direct":
        reasons.append("case_or_mode_mismatch")
    available = bool(initial and final and len(initial.get("materials", [])) == 9216
                     and len(final.get("materials", [])) == 9216
                     and initial.get("width") == final.get("width") == 96
                     and initial.get("height") == final.get("height") == 96)
    path = [case["start"].copy()]
    explicit_stop = False
    path_bound_to_readback = available
    for row in record.get("steps", []):
        if row.get("observation", {}).get("cursor") != path[-1]:
            path_bound_to_readback = False
        action = row.get("selected_action") or {}
        if row.get("host_status") == "applied":
            destination = action.get("destination")
            response = row.get("native_response") or {}
            material = response.get("observation", {}).get("materials", [])
            valid = (action.get("kind") == "movement" and isinstance(destination, list)
                     and len(destination) == 2 and all(type(x) is int and 0 <= x < 96 for x in destination)
                     and _distance(path[-1], destination) == 1 and len(material) == 9216
                     and material[destination[1]*96+destination[0]] == 58
                     and response.get("receipt", {}).get("readback_matches") is True)
            path_bound_to_readback &= valid
            if valid:
                path.append(destination.copy())
        elif row.get("host_status") == "stopped":
            explicit_stop = (action.get("id") == "STOP" and action.get("kind") == "stop"
                             and row.get("decision_requested") is True
                             and row.get("decision", {}).get("candidate_id") == "STOP")
    path_bound_to_readback &= record.get("final_cursor") == path[-1]
    goal_reached = path[-1] == case["target"]
    first_goal = next((i for i, point in enumerate(path) if point == case["target"]), None)
    movements_after_goal = 0 if first_goal is None else len(path)-1-first_goal
    retraces = len(path)-len({tuple(p) for p in path})
    clearances = [clearance(initial, point) for point in path] if available else []
    desired = criteria["desired_clearance_cells"]
    errors = [abs(v-desired) for v in clearances] if desired is not None else []
    requirement = _clearance_requirement(case)
    violations = sum(_violation(value, clearances[i-1] if i else None, requirement)
                     for i, value in enumerate(clearances))
    changed_indices = ([i for i, (before, after) in enumerate(zip(initial["materials"], final["materials"]))
                        if before != after] if available else [])
    guards = initial.get("protected_rectangles", []) if available else []
    protected_changes = sum(initial["materials"][i] not in (0, 58) or any(
        x <= i % 96 < x+w and y <= i//96 < y+h for x, y, w, h in guards) for i in changed_indices)
    acknowledged_cells = {point[1]*96+point[0] for point in path[1:]}
    unexpected_changes = sum(i not in acknowledged_cells or final["materials"][i] != 58 for i in changed_indices)
    readback_changed = len(changed_indices) if available else None
    counts_match = available and readback_changed == record.get("actual_changed_cells")
    target_material = final["materials"][case["target"][1]*96+case["target"][0]] if available else None
    oracle_moves = _shortest_legal_moves(initial, case["start"], case["target"]) if available else None
    if not available:
        reasons.append("missing_native_readback")
    if not path_bound_to_readback:
        reasons.append("cursor_path_not_bound_to_acknowledged_native_materials")
    if not goal_reached:
        reasons.append("target_not_reached")
    if target_material != 58:
        reasons.append("target_not_painted_in_final_readback")
    if record.get("terminal_status") != "stop" or not explicit_stop:
        reasons.append("missing_explicit_policy_STOP")
    if movements_after_goal:
        reasons.append("movement_after_target_was_already_reached")
    if len(path)-1 > criteria["max_movements"]:
        reasons.append("movement_budget_exceeded")
    if not isinstance(record.get("decisions"), int) or record["decisions"] > case["max_decisions"]:
        reasons.append("frozen_decision_budget_exceeded")
    if retraces > criteria["max_retraces"]:
        reasons.append("retrace_limit_exceeded")
    if violations:
        reasons.append("clearance_requirement_violated")
    if protected_changes or unexpected_changes or not counts_match:
        reasons.append("native_material_change_inconsistency")
    if oracle_moves != criteria["expected_shortest_legal_moves"]:
        reasons.append("fixture_geometry_differs_from_frozen_oracle")
    return {"schema": SCORE_SCHEMA, "case_id": case["id"], "split": case["split"],
            "category": case["category"], "case_sha256": digest(case), "episode_sha256": digest(record),
            "task_success": not reasons, "failure_reasons": reasons, "custody_valid": custody_valid,
            "terminal_status": record.get("terminal_status"), "controller_task_complete": record.get("task_complete"),
            "explicit_policy_stop": explicit_stop, "premature_stop": explicit_stop and not goal_reached,
            "goal_reached": goal_reached, "final_goal_distance": _distance(path[-1], case["target"]),
            "path": path, "path_bound_to_native_readback": path_bound_to_readback,
            "movements": len(path)-1, "movements_after_first_goal": movements_after_goal,
            "retrace_count": retraces, "clearances": clearances, "offset_errors": errors,
            "mean_offset_error": sum(errors)/len(errors) if errors else None,
            "max_offset_error": max(errors) if errors else None, "clearance_violation_count": violations,
            "actual_changed_cells": record.get("actual_changed_cells"), "readback_changed_cells": readback_changed,
            "protected_changed_cells": protected_changes, "unexpected_changed_cells": unexpected_changes,
            "target_material": target_material, "oracle_shortest_legal_moves": oracle_moves,
            "excess_movements": len(path)-1-oracle_moves if oracle_moves is not None and goal_reached else None,
            "decisions": record.get("decisions"), "elapsed_seconds": record.get("elapsed_seconds"),
            "claim": "Geometric outcome from original native receipts/readbacks; all terminal outcomes retained. "
                     "Oracle length is retrospective evaluation, never supplied to either policy."}
