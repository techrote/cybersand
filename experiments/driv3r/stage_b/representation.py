"""Auditable semantic view and reversible prompt encodings.

    Full observation/candidate records always stay in the episode journal.
    Opaque custody fields are separated identically in both semantic encodings.
    Only the explicitly named ablation removes host-computed geometry metrics.
"""
from __future__ import annotations

from copy import deepcopy

from ..contracts import Refusal, canonical, validate_candidates
from ..controller import D1Policy

ENCODINGS = ("canonical", "compact", "without-host-metrics")
PREFIX = "d1-q8-stage-b-"
AUDIT_EFFECTS = frozenset({"program", "compiler_sha256", "program_sha256", "operations_sha256", "path_sha256"})
HOST_METRICS = frozenset({"wall_clearance_cells", "goal_distance", "offset_error", "retrace",
    "changed_cells", "endpoint_error", "target_error", "target_manhattan", "length", "travelled_length",
    "travel_ratio", "unique_path_cells", "retrace_visits", "coverage_cells", "path_metrics"})


def semantic_view(observed: dict, candidates: list[dict], *, ablate: bool = False) -> dict:
    validate_candidates(candidates, observed)
    if ablate and observed["mode"] != "direct":
        raise Refusal("Host-metric ablation is frozen to the direct cohort")
    obs = deepcopy(observed)
    # These identifiers enforce source freshness in the host, not task semantics.
    # No material, geometry, permission, history, objective or budget is removed.
    for field in ("protocol", "episode_id", "world"):
        del obs[field]
    if obs["previous_native_ack"] is not None:
        obs["previous_native_ack"] = {k: v for k, v in obs["previous_native_ack"].items()
                                      if not k.endswith("sha256")}
    effects = [{"id": c["id"], "description": c["label"], "kind": c["kind"],
                "profile": c["profile"], "graph_node": c["graph_node"],
                "effects": {k: deepcopy(v) for k, v in c["predicted"].items()
                            if k not in AUDIT_EFFECTS}} for c in candidates]
    if ablate:
        obs.pop("geometry")
        for action in effects:
            action["effects"] = {k: v for k, v in action["effects"].items() if k not in HOST_METRICS}
    return {"observation": obs, "candidate_effects": effects}


def encode(value):
    """Lossless run-length materials and shared-key object tables; no rounding."""
    if isinstance(value, dict):
        if any(str(k).startswith("$") for k in value):
            raise Refusal("Reserved compaction key in semantic view")
        return {k: encode(v) for k, v in value.items()}
    if isinstance(value, list):
        if len(value) >= 3 and all(type(p) is list and len(p) == 2 and
                                  all(type(n) is int for n in p) for p in value):
            cardinal = {(0, -1): "U", (0, 1): "D", (-1, 0): "L", (1, 0): "R"}
            steps = [cardinal.get((b[0]-a[0], b[1]-a[1])) for a, b in zip(value, value[1:])]
            if all(steps):
                packed = {"$path_start": value[0], "$moves": "".join(steps)}
                if len(canonical(packed)) < len(canonical(value)):
                    return packed
        if len(value) >= 16 and all(type(x) is int for x in value):
            runs = []
            for number in value:
                if runs and runs[-1][0] == number:
                    runs[-1][1] += 1
                else:
                    runs.append([number, 1])
            packed = {"$rle": runs}
            if len(canonical(packed)) < len(canonical(value)):
                return packed
        if len(value) >= 2 and all(type(row) is dict and row.keys() == value[0].keys() for row in value):
            columns = sorted(value[0])
            packed = {"$columns": columns, "$rows": [[encode(row[k]) for k in columns] for row in value]}
            if len(canonical(packed)) < len(canonical(value)):
                return packed
        return [encode(v) for v in value]
    return value


def decode(value):
    if isinstance(value, dict):
        if set(value) == {"$path_start", "$moves"}:
            points = [value["$path_start"].copy()]
            for letter in value["$moves"]:
                dx, dy = {"U": (0, -1), "D": (0, 1), "L": (-1, 0), "R": (1, 0)}[letter]
                points.append([points[-1][0]+dx, points[-1][1]+dy])
            return points
        if set(value) == {"$rle"}:
            return [number for number, count in value["$rle"] for _ in range(count)]
        if set(value) == {"$columns", "$rows"}:
            return [{k: decode(v) for k, v in zip(value["$columns"], row, strict=True)} for row in value["$rows"]]
        return {k: decode(v) for k, v in value.items()}
    return [decode(v) for v in value] if isinstance(value, list) else value


def request(encoding: str, observed: dict, candidates: list[dict]) -> dict:
    if encoding not in ENCODINGS:
        raise Refusal("Unknown frozen model prompt encoding")
    view = semantic_view(observed, candidates, ablate=encoding == "without-host-metrics")
    packed = encode(view) if encoding != "canonical" else view
    if encoding != "canonical" and decode(packed) != view:
        raise Refusal("Prompt compaction lost semantic information")
    explanation = ("Data uses lossless tables: $columns names the fields in each $rows entry; "
                   "$rle entries [value,count] expand to repeated material values in row-major order; "
                   "$path_start is the first XY point and each $moves letter U/D/L/R adds one cardinal step. ")
    instructions = ("Choose the single candidate that best satisfies the objective and active subgoal. "
                    "Choose STOP when finished or when no useful legal action remains. "
                    "Candidate IDs are labels, and legal actions can still be unhelpful. "
                    + (explanation if encoding != "canonical" else ""))
    return {"state": canonical(packed).decode(), "questions": {"next_action": {"type": "choice",
            "instructions": instructions, "criteria": {c["id"]: c["label"] for c in candidates}}}}


def request_for_policy(name: str, observed: dict, candidates: list[dict]) -> dict:
    mapping = {PREFIX + encoding + "-v1": encoding for encoding in ENCODINGS}
    if name not in mapping:
        raise Refusal("Unknown model policy cannot validate original request custody")
    return request(mapping[name], observed, candidates)


class SemanticPolicy(D1Policy):
    def __init__(self, backend, encoding="compact"):
        super().__init__(backend)
        if encoding not in ENCODINGS:
            raise Refusal("Unknown model prompt encoding")
        self.encoding = encoding
        self.name = PREFIX + encoding + "-v1"

    def request(self, observed, candidates):
        return request(self.encoding, observed, candidates)
