"""Frozen one-choice fuzzy tools, with outcomes scored from material readback.

The programs are proposals for the unchanged shared Art compiler.  This module
does not execute them, implement a World, or decide native authority.  The
catalog's evaluation masks never enter candidate effects or policy questions.
"""
from __future__ import annotations

from collections import deque
from copy import deepcopy
import json
from pathlib import Path
import random

from experiments.agent_painter.compiler import compile_program
from experiments.driv3r.contracts import Refusal, digest, identifier, validate_candidates, validate_operations
from experiments.driv3r.controller import decision_record
from experiments.driv3r.providers import candidate, permitted

SCHEMA = "driv3r-stage-b-fuzzy-cases-v1"
CATALOG = Path(__file__).with_name("fuzzy_cases.json")
FOCUS = [0, 0, 96, 96]
GUARD = [40, 40, 8, 8]
SPLITS = ("development", "held_out")


def _rectangle_cells(rectangle: list[int]) -> set[tuple[int, int]]:
    if (type(rectangle) is not list or len(rectangle) != 4 or
            any(type(v) is not int for v in rectangle)):
        raise Refusal("Fuzzy rectangles must be integer XYWH lists")
    x, y, w, h = rectangle
    if x < 0 or y < 0 or w < 1 or h < 1 or x+w > 96 or y+h > 96:
        raise Refusal("Fuzzy rectangle exceeds the frozen focus")
    return {(a, b) for b in range(y, y+h) for a in range(x, x+w)}


def _mask(rectangles: list[list[int]]) -> set[tuple[int, int]]:
    if type(rectangles) is not list:
        raise Refusal("Fuzzy rectangle collection must be a list")
    return set().union(*(_rectangle_cells(rect) for rect in rectangles)) if rectangles else set()


def _point(value: list[int]) -> tuple[int, int]:
    if (type(value) is not list or len(value) != 2 or
            any(type(v) is not int or not 0 <= v < 96 for v in value)):
        raise Refusal("Fuzzy coordinate exceeds the frozen focus")
    return tuple(value)


def _fixture_materials(case: dict) -> list[int]:
    """Expected fixture bytes for custody checks, never a native observation."""
    cells = [0]*(96*96)
    fixture = case["fixture"]
    if type(fixture) is not dict or set(fixture) != {"id", "edits"} or fixture["id"] != case["id"]:
        raise Refusal("Fuzzy fixture identity must match its case")
    if type(fixture["edits"]) is not list or len(fixture["edits"]) > 16:
        raise Refusal("Fuzzy fixture edit count exceeds the bound")
    for edit in fixture["edits"]:
        if type(edit) is not list or len(edit) != 5 or type(edit[4]) is not int or edit[4] not in (28, 58):
            raise Refusal("Fuzzy fixtures use only protected28 and paint58 rectangles")
        for x, y in _rectangle_cells(edit[:4]):
            cells[y*96+x] = edit[4]
    return cells


def _compile(program: dict) -> dict:
    return compile_program(program, seed=570, focus=tuple(FOCUS), material=58,
                           allowed_materials=(58,), max_operations=16, max_cell_work=1024)


def validate_case(case: dict) -> None:
    expected = {"id", "split", "fixture", "cursor", "target", "objective", "paraphrase",
                "subgoal", "candidates", "evaluation"}
    if type(case) is not dict or set(case) != expected:
        raise Refusal("Invalid frozen fuzzy case fields")
    identifier(case["id"], "fuzzy case ID")
    if not case["id"].startswith("b-fuzzy-") or case["split"] not in SPLITS:
        raise Refusal("Invalid fuzzy case identity/split")
    _point(case["cursor"])
    _point(case["target"])
    for name in ("objective", "paraphrase", "subgoal"):
        if type(case[name]) is not str or not 1 <= len(case[name]) <= 2048:
            raise Refusal("Fuzzy objective and subgoal must be bounded text")
    cells = _fixture_materials(case)
    native = {"materials": cells, "width": 96, "height": 96, "focus": FOCUS,
              "protected_rectangles": [GUARD]}
    options = case["candidates"]
    if type(options) is not list or len(options) != 3:
        raise Refusal("Frozen fuzzy cases require three distinct tools")
    ids, footprints = set(), set()
    for option in options:
        if type(option) is not dict or set(option) != {"id", "profile", "label", "program"}:
            raise Refusal("Invalid fuzzy host tool fields")
        identifier(option["id"], "fuzzy tool ID")
        if option["id"] in ids or option["id"] in ("SKIP", "STOP"):
            raise Refusal("Duplicate/reserved fuzzy tool ID")
        ids.add(option["id"])
        if any(type(option[k]) is not str or not 1 <= len(option[k]) <= 512 for k in ("profile", "label")):
            raise Refusal("Invalid fuzzy profile/label")
        compiled = _compile(option["program"])
        footprint = validate_operations(compiled["operations"], FOCUS, 58)
        if not all(permitted(native, x, y) for x, y in footprint):
            raise Refusal("Frozen fuzzy option violates fixture protection")
        footprint_hash = digest(sorted(footprint))
        if footprint_hash in footprints:
            raise Refusal("Fuzzy alternatives must have different geometry")
        footprints.add(footprint_hash)
    evaluation = case["evaluation"]
    if (type(evaluation) is not dict or set(evaluation) !=
            {"kind", "required_rectangles", "allowed_new_rectangles", "connectivity", "support_columns"}):
        raise Refusal("Invalid fuzzy evaluation fields")
    if evaluation["kind"] not in ("connection", "support", "coverage"):
        raise Refusal("Unknown fuzzy geometry objective")
    required = _mask(evaluation["required_rectangles"])
    allowed = _mask(evaluation["allowed_new_rectangles"])
    if not required or not required <= allowed or not all(permitted(native, x, y) for x, y in allowed):
        raise Refusal("Fuzzy evaluation target must be nonempty and legal")
    for name in ("connectivity", "support_columns"):
        if type(evaluation[name]) is not list or len(evaluation[name]) > 8:
            raise Refusal("Fuzzy objective predicates must be bounded lists")
    for pair in evaluation["connectivity"]:
        if type(pair) is not dict or set(pair) != {"from", "to"}:
            raise Refusal("Invalid connectivity predicate")
        for key in ("from", "to"):
            x, y = _point(pair[key])
            if cells[y*96+x] != 58:
                raise Refusal("Connectivity anchors must be existing paint58")
    for column in evaluation["support_columns"]:
        if (type(column) is not dict or set(column) != {"x", "top_y", "bottom_y"} or
                any(type(v) is not int or not 0 <= v < 96 for v in column.values()) or
                column["top_y"] >= column["bottom_y"]):
            raise Refusal("Invalid continuous support predicate")
        for y in (column["top_y"], column["bottom_y"]):
            if cells[y*96+column["x"]] != 58:
                raise Refusal("Support endpoints must be existing paint58")


def load_cases(split: str | None = None) -> list[dict]:
    """Load the committed development/held-out catalog without model tuning."""
    if split is not None and split not in SPLITS:
        raise Refusal("Unknown fuzzy cohort split")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    if type(catalog) is not dict or set(catalog) != {"schema", "cases"} or catalog["schema"] != SCHEMA:
        raise Refusal("Invalid fuzzy catalog schema")
    cases = catalog["cases"]
    if type(cases) is not list or len(cases) != 6:
        raise Refusal("Frozen fuzzy catalog must contain two development and four held-out cases")
    for case in cases:
        validate_case(case)
    if (len({case["id"] for case in cases}) != len(cases) or
            sum(case["split"] == "development" for case in cases) != 2):
        raise Refusal("Fuzzy catalog IDs/split counts differ from the freeze")
    return deepcopy([case for case in cases if split is None or case["split"] == split])


class FuzzyCaseProvider:
    """One finite tool/profile selection; graph completion is not task success."""

    mode = "fuzzy"

    def __init__(self, case: dict, *, reverse_order: bool = False, paraphrase: bool = False):
        validate_case(case)
        self.case = deepcopy(case)
        self.fixture = case["fixture"]["id"]
        self.cursor = case["cursor"].copy()
        self.target = case["target"].copy()
        self.objective = case["paraphrase" if paraphrase else "objective"]
        self.history: list[list[int]] = []
        self.reverse_order = reverse_order
        self.node = 0
        self._issued: dict[str, str] = {}

    @property
    def subgoal(self) -> str:
        return self.case["subgoal"] if not self.complete() else "One tool choice completed; score actual final geometry."

    def complete(self) -> bool:
        return self.node >= 1

    def candidates(self, native: dict, observation: dict) -> list[dict]:
        result = []
        if not self.complete():
            for option in self.case["candidates"]:
                compiled = _compile(option["program"])
                footprint = validate_operations(compiled["operations"], FOCUS, 58)
                if not all(permitted(native, x, y) for x, y in footprint):
                    continue
                effects = {
                    "program": deepcopy(option["program"]),
                    "program_sha256": compiled["program_sha256"],
                    "compiler_sha256": compiled["compiler_sha256"],
                    "operations_sha256": compiled["operations_sha256"],
                    "proposed_boxes": [deepcopy(c["box"]) for c in option["program"]["components"]],
                    "cell_visits": compiled["estimated_cell_work"],
                }
                result.append(candidate(option["id"], "tool", option["label"], compiled["operations"],
                                        profile=option["profile"], graph_node="one_tool", predicted=effects))
            result.append(candidate("SKIP", "skip", "Skip the available tool choice without painting", graph_node="one_tool"))
        result.append(candidate("STOP", "stop", "Stop now without painting"))
        if self.reverse_order:
            result.reverse()
        validate_candidates(result, observation)
        self._issued = {action["id"]: digest(action) for action in result}
        return result

    def accept(self, action: dict) -> None:
        if (self.complete() or action.get("kind") not in ("tool", "skip") or
                self._issued.get(action.get("id")) != digest(action)):
            raise Refusal("Fuzzy provider advances only one issued acknowledged tool or SKIP")
        self.node += 1
        self._issued = {}


def _materials(native: dict) -> list[int]:
    if (type(native) is not dict or native.get("width") != 96 or native.get("height") != 96 or
            native.get("focus") != FOCUS or type(native.get("materials")) is not list or
            len(native["materials"]) != 96*96 or
            any(type(v) is not int or not 0 <= v <= 131 for v in native["materials"])):
        raise Refusal("Fuzzy scoring requires complete original focus96 material readbacks")
    return native["materials"]


def _connected(cells: list[int], start: list[int], target: list[int]) -> bool:
    first, last = tuple(start), tuple(target)
    if cells[first[1]*96+first[0]] != 58 or cells[last[1]*96+last[0]] != 58:
        return False
    seen, queue = {first}, deque([first])
    while queue:
        x, y = queue.popleft()
        if (x, y) == last:
            return True
        for pos in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
            a, b = pos
            if 0 <= a < 96 and 0 <= b < 96 and pos not in seen and cells[b*96+a] == 58:
                seen.add(pos)
                queue.append(pos)
    return False


def score_episode(case: dict, record: dict) -> dict:
    """Score original before/after cells, never the selected ID or graph status.

    Quality is mean(target coverage, applicable connection/support fractions)
    times new-paint precision.  Full success requires every target predicate,
    zero new paint outside the requested region, preserved protected cells, and
    consistent native receipts.  Overdraw is measured separately: touching an
    existing anchor can be legitimate.  This is focus geometry scoring; the
    controller/replay remains responsible for full-World native authorization.
    """
    validate_case(case)
    base = {"schema": "driv3r-stage-b-fuzzy-score-v1", "case_id": case["id"], "split": case["split"],
            "case_sha256": digest(case), "evaluable": False, "task_success": False,
            "claim": "Geometry from recorded material readbacks; graph completion is not objective success"}
    try:
        before = _materials(record["initial_native"])
        after = _materials(record["final_native"])
    except (Refusal, KeyError, TypeError) as exc:
        return {**base, "reason": str(exc), "quality_score": 0.0}
    required = _mask(case["evaluation"]["required_rectangles"])
    allowed = _mask(case["evaluation"]["allowed_new_rectangles"])
    changed = {(i % 96, i//96) for i, (a, b) in enumerate(zip(before, after, strict=True)) if a != b}
    newly_painted = {(x, y) for x, y in changed if after[y*96+x] == 58}
    target_painted = sum(after[y*96+x] == 58 for x, y in required)
    coverage = target_painted/len(required)
    spill = newly_painted-allowed
    precision = (len(newly_painted)-len(spill))/len(newly_painted) if newly_painted else 1.0
    connections = [{**deepcopy(pair), "connected": _connected(after, pair["from"], pair["to"])}
                   for pair in case["evaluation"]["connectivity"]]
    supports = [{**deepcopy(column), "supported": all(after[y*96+column["x"]] == 58
                 for y in range(column["top_y"], column["bottom_y"]+1))}
                for column in case["evaluation"]["support_columns"]]
    factors = [coverage]
    if connections:
        factors.append(sum(c["connected"] for c in connections)/len(connections))
    if supports:
        factors.append(sum(c["supported"] for c in supports)/len(supports))
    protected = {(i % 96, i//96) for i, value in enumerate(before) if value not in (0, 58)} | _rectangle_cells(GUARD)
    protected_changed = len(changed & protected)
    invalid_material_writes = sum(after[y*96+x] != 58 for x, y in changed)
    fixture_matches = before == _fixture_materials(case)
    identity_matches = all(record["initial_native"].get(k) == record["final_native"].get(k)
                           for k in ("world_id", "generation"))
    receipt_total, cell_visits, overdraw = 0, 0, 0
    receipts_consistent, running = True, before
    receipt_errors = []
    try:
        for step in record["steps"]:
            response = step.get("native_response")
            if response is None:
                continue
            step_before = _materials(step["before_native"]["observation"])
            step_after = _materials(response["observation"])
            actual = sum(a != b for a, b in zip(step_before, step_after, strict=True))
            receipt = response["receipt"]
            if (step_before != running or actual != receipt["actual_changed_cells"] or
                    receipt.get("readback_matches") is not True):
                receipts_consistent = False
                receipt_errors.append("Native before/after readback or changed-cell receipt mismatch")
            receipt_total += actual
            running = step_after
            if step.get("host_status") == "applied":
                for op in step["selected_action"]["operations"]:
                    for y in range(op["y0"], op["y1"]+1):
                        for x in range(op["x0"], op["x1"]+1):
                            cell_visits += 1
                            overdraw += step_before[y*96+x] == 58
        if (running != after or receipt_total != record["actual_changed_cells"] or
                receipt_total != len(changed)):
            receipts_consistent = False
            receipt_errors.append("Episode total/final readback differs from native receipt chain")
    except (Refusal, KeyError, TypeError, IndexError, ValueError) as exc:
        receipts_consistent = False
        receipt_errors.append(str(exc))
    geometry_success = (coverage == 1.0 and all(c["connected"] for c in connections) and
                        all(c["supported"] for c in supports) and not spill and
                        protected_changed == 0 and invalid_material_writes == 0)
    execution_valid = (fixture_matches and identity_matches and receipts_consistent and
                       protected_changed == 0 and invalid_material_writes == 0 and
                       record.get("terminal_status") in ("success", "stop", "budget_exhausted"))
    return {**base, "evaluable": True, "objective_kind": case["evaluation"]["kind"],
            "task_success": geometry_success and execution_valid, "geometry_success": geometry_success,
            "quality_score": sum(factors)/len(factors)*precision if execution_valid else 0.0,
            "target_cells": len(required), "target_painted_cells": target_painted,
            "target_coverage": coverage, "new_paint_precision": precision,
            "newly_painted_cells": len(newly_painted), "actual_changed_cells": len(changed),
            "spill_cells": len(spill), "connections": connections, "supports": supports,
            "protected_changed_cells": protected_changed, "invalid_material_writes": invalid_material_writes,
            "acknowledged_full_action_cell_visits": cell_visits,
            "acknowledged_full_action_overdraw_visits": overdraw,
            "fixture_matches": fixture_matches, "world_identity_matches": identity_matches,
            "native_receipts_consistent": receipts_consistent, "receipt_errors": receipt_errors,
            "initial_material_sha256": record["initial_native"].get("material_sha256"),
            "final_material_sha256": record["final_native"].get("material_sha256"),
            "graph_terminal": bool(record.get("task_complete")),
            "terminal_status": record.get("terminal_status")}


class FixedOrderFuzzyBaseline:
    """Choose the first legal tool in presentation order; never consult scoring."""

    name = "stage-b-fuzzy-first-legal-tool-v1"

    def decide(self, observed: dict, candidates: list[dict], **_) -> dict:
        validate_candidates(candidates, observed)
        choice = next((c for c in candidates if c["kind"] == "tool"),
                      next(c for c in candidates if c["kind"] == "stop"))
        return decision_record(observed, candidates, choice=choice["id"],
                               probabilities={c["id"]: float(c["id"] == choice["id"]) for c in candidates},
                               confidence=1.0, model_identity={"kind": "non_model_fixed_order_baseline"},
                               backend_identity={"implementation": self.name},
                               raw={"rule": "first legal tool in presentation order, otherwise STOP"})


class SeededRandomFuzzyBaseline:
    """Uniform legal action sampling, including SKIP/STOP, with frozen seed.

    Sorting IDs before sampling makes the seed independent of presentation
    order.  The reported one-hot distribution is this deterministic seeded
    controller's output, not model confidence or the uniform sampling law.
    """

    name = "stage-b-fuzzy-seeded-random-legal-v1"

    def __init__(self, seed: int):
        if type(seed) is not int or not 0 <= seed < 2**32:
            raise Refusal("Baseline seed must be an unsigned32 integer")
        self.seed = seed
        self._random = random.Random(seed)

    def decide(self, observed: dict, candidates: list[dict], **_) -> dict:
        validate_candidates(candidates, observed)
        choice = self._random.choice(sorted(candidates, key=lambda c: c["id"]))
        return decision_record(observed, candidates, choice=choice["id"],
                               probabilities={c["id"]: float(c["id"] == choice["id"]) for c in candidates},
                               confidence=1.0, model_identity={"kind": "non_model_seeded_random_legal_baseline"},
                               backend_identity={"implementation": self.name, "seed": self.seed},
                               raw={"sampling": "uniform over all legal IDs including SKIP and STOP",
                                    "sampling_probability": 1/len(candidates), "seed": self.seed})
