"""Host-generated finite controls and a three-node graph of existing Art tools."""
from __future__ import annotations

from copy import deepcopy

from experiments.agent_painter.compiler import compile_program

from . import PROTOCOL
from .contracts import Refusal, digest, validate_candidates, validate_observation

DIRECT_OBJECTIVE = ("Paint a connected vertical trace from (12,24) to (12,30), moving one cell per decision. "
                    "Keep four cells of horizontal distance from the protected wall at x=8. "
                    "Avoid revisiting cells. Coordinates increase right and down. Stop once the target is reached.")
FUZZY_OBJECTIVE = ("Create a small horizontal platform at the lower right, extend it to the right, then add one "
                   "vertical supporting column. Prefer the thin/short parameter profiles. Preserve the wall, "
                   "obstacle and protected rectangle. Use the finite host tools or finish.")


def world_identity(native: dict) -> dict:
    return {"id": native["world_id"], "generation": native["generation"], "revision": native["revision"],
            "tick": native["tick"], "material_sha256": native["material_sha256"],
            "world_material_sha256": native["world_material_sha256"]}


def clearance(native: dict, position: list[int]) -> int:
    """Exact Manhattan distance to stored protected/nonpaintable material."""
    width = native["width"]
    distances = [abs(i % width-position[0])+abs(i//width-position[1])
                 for i, material in enumerate(native["materials"]) if material not in (0, 58)]
    return min(distances, default=width+native["height"])


def permitted(native: dict, x: int, y: int) -> bool:
    fx, fy, fw, fh = native["focus"]
    if not (fx <= x < fx+fw and fy <= y < fy+fh):
        return False
    if native["materials"][(y-fy)*native["width"]+x-fx] not in (0, 58):
        return False
    return not any(px <= x < px+pw and py <= y < py+ph for px, py, pw, ph in native["protected_rectangles"])


def candidate(cid: str, kind: str, label: str, operations=None, destination=None,
              profile="none", graph_node="none", predicted=None) -> dict:
    return {"protocol": PROTOCOL, "id": cid, "kind": kind, "label": label,
            "operations": operations or [], "destination": destination,
            "profile": profile, "graph_node": graph_node, "predicted": predicted or {}}


class DirectProvider:
    mode = "direct"
    fixture = "wall-v1"
    objective = DIRECT_OBJECTIVE

    def __init__(self, *, reverse_order: bool = False):
        self.cursor = [12, 24]
        self.target = [12, 30]
        self.history = [self.cursor.copy()]
        self.reverse_order = reverse_order

    @property
    def subgoal(self) -> str:
        return f"Reach {self.target} with x=12 and no retracing; current position is {self.cursor}."

    def complete(self) -> bool:
        return self.cursor == self.target

    def candidates(self, native: dict, observation: dict) -> list[dict]:
        result = []
        for cid, dx, dy in (("UP", 0, -1), ("DOWN", 0, 1), ("LEFT", -1, 0), ("RIGHT", 1, 0)):
            x, y = self.cursor[0]+dx, self.cursor[1]+dy
            if not permitted(native, x, y):
                continue
            distance = clearance(native, [x, y])
            operation = {"shape": "rectangle", "material": 58, "x0": x, "x1": x, "y0": y, "y1": y}
            predicted = {"destination": [x, y], "wall_clearance_cells": distance,
                         "offset_error": abs(distance-4), "goal_distance": abs(x-self.target[0])+abs(y-self.target[1]),
                         "retrace": [x, y] in self.history,
                         "changed_cells": int(native["materials"][y*96+x] != 58)}
            result.append(candidate(cid, "movement", f"{cid}: move to ({x},{y}) and draw one cell", [operation],
                                    [x, y], "one_cell", "vehicle", predicted))
        result.append(candidate("STOP", "stop", "Stop the episode without moving or painting"))
        if self.reverse_order:
            result.reverse()
        validate_candidates(result, observation)
        return result

    def accept(self, action: dict) -> None:
        if action["kind"] != "movement":
            raise Refusal("Direct provider only advances on acknowledged movement")
        self.cursor = action["destination"].copy()
        self.history.append(self.cursor.copy())


class FuzzyProvider:
    mode = "fuzzy"
    fixture = "fuzzy-v1"
    objective = FUZZY_OBJECTIVE
    # Each option is a complete host-owned operation/profile, not model coordinates.
    NODES = (
        (("ADD_PLATFORM_THIN", "platform", [52, 60, 16, 2], "thin"),
         ("ADD_PLATFORM_THICK", "platform", [52, 60, 16, 4], "thick")),
        (("EXTEND_SHORT", "platform", [68, 60, 8, 2], "short"),
         ("EXTEND_LONG", "platform", [68, 60, 16, 2], "long")),
        (("SUPPORT_THIN", "support", [58, 62, 2, 12], "thin"),
         ("SUPPORT_THICK", "support", [58, 62, 4, 12], "thick")),
    )

    def __init__(self, *, reverse_order: bool = False):
        self.cursor, self.target = [52, 60], [76, 60]
        self.history = []
        self.node = 0
        self.reverse_order = reverse_order

    @property
    def subgoal(self) -> str:
        return ("Add the base platform", "Extend the platform", "Add a supporting column", "Finished")[self.node]

    def complete(self) -> bool:
        return self.node >= len(self.NODES)

    def candidates(self, native: dict, observation: dict) -> list[dict]:
        result = []
        if not self.complete():
            for cid, kind, box, profile in self.NODES[self.node]:
                program = {"version": 2, "family": "architecture", "variation": 0,
                           "components": [{"kind": kind, "box": box}],
                           "requirements": {"route": [], "clearance": 3, "region": [0, 0, 96, 96]}}
                compiled = compile_program(program, seed=570, focus=(0, 0, 96, 96), material=58,
                                           allowed_materials=(58,), max_operations=16, max_cell_work=1024)
                # Current native state, not a hypothetical blank canvas, determines legality.
                if not all(permitted(native, x, y) for op in compiled["operations"]
                           for y in range(op["y0"], op["y1"]+1) for x in range(op["x0"], op["x1"]+1)):
                    continue
                predicted = {"program": program, "program_sha256": compiled["program_sha256"],
                             "compiler_sha256": compiled["compiler_sha256"],
                             "operations_sha256": compiled["operations_sha256"],
                             "cell_visits": compiled["estimated_cell_work"]}
                result.append(candidate(cid, "tool", f"{cid}: {kind} at {box}, {profile} profile",
                                        compiled["operations"], profile=profile, graph_node=f"node{self.node}", predicted=predicted))
        result += [candidate("SKIP", "skip", "Skip this graph node without painting", graph_node=f"node{self.node}"),
                   candidate("STOP", "stop", "Finish the episode now without painting")]
        if self.reverse_order:
            result.reverse()
        validate_candidates(result, observation)
        return result

    def accept(self, action: dict) -> None:
        if action["kind"] not in ("tool", "skip"):
            raise Refusal("Fuzzy graph only advances on acknowledged tool or explicit skip")
        self.node += 1


def observation(native: dict, provider, *, episode_id: str, step: int, decisions_remaining: int,
                changed_cells_remaining: int, wall_seconds_remaining: float, previous_ack=None) -> dict:
    if native.get("retired"):
        raise Refusal("Retired native World cannot supply a live observation")
    cx, cy = provider.cursor
    x0, y0 = max(0, cx-4), max(0, cy-4)
    x1, y1 = min(native["width"], cx+5), min(native["height"], cy+5)
    materials = native["materials"]
    if len(materials) != native["width"]*native["height"]:
        raise Refusal("Native material extent mismatch")
    value = {"protocol": PROTOCOL, "episode_id": episode_id, "step": step, "mode": provider.mode,
             "objective": provider.objective, "subgoal": provider.subgoal, "world": world_identity(native),
             "permissions": {"focus": native["focus"], "material": 58,
                             "protected_rectangles": native["protected_rectangles"]},
             "cursor": provider.cursor.copy(), "target": provider.target.copy(),
             "local": {"origin": [x0, y0], "width": x1-x0, "height": y1-y0,
                       "materials": [materials[y*native["width"]+x] for y in range(y0, y1) for x in range(x0, x1)]},
             "geometry": {"wall_clearance_cells": clearance(native, provider.cursor),
                          "goal_distance": abs(cx-provider.target[0])+abs(cy-provider.target[1])},
             "history": deepcopy(provider.history),
             "budgets": {"decisions_remaining": decisions_remaining,
                         "changed_cells_remaining": changed_cells_remaining,
                         "wall_seconds_remaining": round(max(0, wall_seconds_remaining), 6)},
             "previous_native_ack": previous_ack}
    validate_observation(value)
    return value
