"""Fail-closed BODY-V2 -> M3 action planner. NO native transport or model calls.

This module is *native-inert*: its observations and receipt fixtures are supplied
by a caller. Passing a synthetic transcript does NOT authenticate a Godot World.
Integration owners must bind every snapshot to source-pinned live Workbench
observations, one-cell PAINT receipts, cursor RPC and Stop/cleanup.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import re

from .body_v2 import BodyOptions
from .preflight import (
    BASELINE, HEADINGS, INK, HostView, Lease, Refusal,
    native_envelope, new_ink_from_readbacks,
)

SOURCE_RE = re.compile(r"^[0-9a-f]{40}$")
ACTION_RE = re.compile(r"^(INK|LIFT)_([NESW])_([1-4])$")
SCHEMA = "driv3r-body-lab-native-inert/1"


def _hash(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


@dataclass(frozen=True)
class ExternalSnapshot:
    """External-host shape. This structure alone is NEVER a native attestation."""
    lease_id: str
    runner: str
    world: str
    source_sha: str
    epoch: tuple
    cursor: tuple
    logical_moves: int
    material: HostView
    retired: bool = False

    def __post_init__(self):
        if any(not isinstance(v, str) or not v for v in
               (self.lease_id, self.runner, self.world)):
            raise Refusal("Missing snapshot ownership")
        if not SOURCE_RE.fullmatch(self.source_sha):
            raise Refusal("Unpinned source SHA")
        if (type(self.epoch) is not tuple or len(self.epoch) != 3
                or any(type(v) is not int or v < 0 for v in self.epoch)):
            raise Refusal("Expected native generation/revision/tick")
        if (type(self.cursor) is not tuple or len(self.cursor) != 2
                or any(type(v) is not int for v in self.cursor)):
            raise Refusal("Invalid external cursor")
        if not isinstance(self.material, HostView):
            raise Refusal("Invalid external full-focus material snapshot")
        if not (0 <= self.cursor[0] < self.material.width and
                0 <= self.cursor[1] < self.material.height):
            raise Refusal("External cursor outside focus")
        if type(self.logical_moves) is not int or not 0 <= self.logical_moves <= BASELINE[2]:
            raise Refusal("External cursor history outside admitted M3 budget")
        if type(self.retired) is not bool:
            raise Refusal("Invalid retirement flag")

    def fingerprint(self):
        return _hash({
            "lease": self.lease_id, "runner": self.runner, "world": self.world,
            "source": self.source_sha, "epoch": self.epoch, "cursor": self.cursor,
            "logical_moves": self.logical_moves, "retired": self.retired,
            "material": self.material.material, "protected": self.material.protected,
            "width": self.material.width, "height": self.material.height,
        })


def _validate(lease, original, snapshot, expected_source_sha, decisions):
    if not isinstance(lease, Lease) or not isinstance(snapshot, ExternalSnapshot):
        raise Refusal("Missing external lease/snapshot")
    if not SOURCE_RE.fullmatch(expected_source_sha):
        raise Refusal("Missing exact expected source")
    if ((lease.id, lease.runner, lease.world) !=
            (snapshot.lease_id, snapshot.runner, snapshot.world)):
        raise Refusal("Cross-worm lease/world/runner swap")
    if snapshot.source_sha != expected_source_sha or snapshot.retired:
        raise Refusal("Stale source or retired native host")
    if not isinstance(original, HostView):
        raise Refusal("Need original full-focus host snapshot")
    ink = new_ink_from_readbacks(original, snapshot.material)
    if type(decisions) is not int:
        raise Refusal("Invalid decision count")
    native_envelope(decisions, ink, snapshot.logical_moves, 0)
    return ink


def _available(lease, original, snapshot, opts, expected_source_sha, decisions,
               decision_ceiling, material_ceiling):
    if not isinstance(opts, BodyOptions):
        raise Refusal("Explicit movement options required")
    ink = _validate(lease, original, snapshot, expected_source_sha, decisions)
    if (type(decision_ceiling) is not int or not 1 <= decision_ceiling <= BASELINE[0]
            or type(material_ceiling) is not int or not 0 <= material_ceiling <= BASELINE[1]
            or ink > material_ceiling):
        raise Refusal("Commander episode ceiling invalid or already exceeded")
    available = {"STOP": ()}
    if decisions >= decision_ceiling:
        return available, ink
    owned = {
        (i % original.width, i // original.width)
        for i, (a, b) in enumerate(zip(original.material, snapshot.material.material))
        if a == 0 and b == INK
    }
    for name, (dx, dy) in HEADINGS.items():
        blank_prefix, walk_prefix = [], []
        for step in range(1, opts.span + 1):
            x = snapshot.cursor[0] + step * dx
            y = snapshot.cursor[1] + step * dy
            inside = 0 <= x < original.width and 0 <= y < original.height
            forbidden = (not inside or any(
                a <= x < a + w and b <= y < b + h
                for a, b, w, h in snapshot.material.protected))
            if forbidden:
                break
            cell = (x, y)
            if (len(walk_prefix) == step - 1
                    and (snapshot.material.material[y * original.width + x] == 0
                         or cell in owned)):
                walk_prefix.append(cell)
                if (opts.pen_up and
                        snapshot.logical_moves + step <= BASELINE[2]):
                    available[f"LIFT_{name}_{step}"] = tuple(walk_prefix)
            if (len(blank_prefix) == step - 1
                    and snapshot.material.material[y * original.width + x] == 0):
                blank_prefix.append(cell)
                if (snapshot.logical_moves + step <= BASELINE[2]
                        and ink + step <= material_ceiling):
                    available[f"INK_{name}_{step}"] = tuple(blank_prefix)
    return available, ink


def offered(lease, original, snapshot, *, options=BodyOptions(),
            expected_source_sha, decisions,
            decision_ceiling=BASELINE[0], material_ceiling=BASELINE[1]):
    """Bind a host-offered action catalog to one *exact* source/epoch/World."""
    actions, ink = _available(
        lease, original, snapshot, options, expected_source_sha, decisions,
        decision_ceiling, material_ceiling)
    token = _hash({
        "schema": SCHEMA, "lease": lease.id, "source": expected_source_sha,
        "snapshot": snapshot.fingerprint(), "decisions": decisions,
        "existing_ink": ink,
        "decision_ceiling": decision_ceiling, "material_ceiling": material_ceiling,
        "options": {
            "span": options.span, "pen_up": options.pen_up,
            "anchors": options.branch_anchors},
        "actions": actions,
    })
    return {"legal_ids": sorted(actions), "offer_token": token,
            "already_inked_cells_this_run": ink,
            "cursor_logical_moves": snapshot.logical_moves,
            "evidence_class": "external-snapshot-unverified",
            "native_receipts_authenticated": False}


def prepare(lease, original, snapshot, action, offer_token, *,
            options=BodyOptions(), expected_source_sha, decisions,
            decision_ceiling=BASELINE[0], material_ceiling=BASELINE[1]):
    """Plan one tiny action as ordered one-cell RPCs; NEVER execute them."""
    offered_now = offered(lease, original, snapshot, options=options,
                          expected_source_sha=expected_source_sha,
                          decisions=decisions, decision_ceiling=decision_ceiling,
                          material_ceiling=material_ceiling)
    if offer_token != offered_now["offer_token"]:
        raise Refusal("Stale or cross-worm offer token")
    actions, ink = _available(lease, original, snapshot, options,
                              expected_source_sha, decisions,
                              decision_ceiling, material_ceiling)
    if type(action) is not str or action not in actions:
        raise Refusal("Model may submit only current host-offered ID")
    path = actions[action]
    operations = []
    match = ACTION_RE.fullmatch(action)
    if action == "STOP":
        operations.append({"kind": "STOP", "target": list(snapshot.cursor)})
    elif match:
        mode = match.group(1)
        for x, y in path:
            if mode == "INK":
                operations.append({"kind": "PAINT_ONE", "target": [x, y]})
            operations.append({"kind": "CURSOR_ONE", "target": [x, y]})
    else:
        # SAVE_ANCHOR and RETRACE_1 are deliberately NOT mapped to M3
        # without a separately qualified source/receipt transaction.
        raise Refusal("Unqualified native operation")
    return {
        "schema": SCHEMA, "evidence_class": "external-snapshot-unverified",
        "native_execution": False, "model_execution": False,
        "lease_id": lease.id, "runner": lease.runner, "world": lease.world,
        "source_sha": expected_source_sha, "epoch": list(snapshot.epoch),
        "before_fingerprint": snapshot.fingerprint(),
        "offer_token": offer_token, "decision_index": decisions,
        "selected_action": action, "new_ink_before": ink,
        "logical_moves_before": snapshot.logical_moves,
        "operations": operations, "native_receipts_authenticated": False,
    }


def check_fixture_transcript(plan, initial_snapshot, steps):
    """Adversarial SOURCE-MATCHED FIXTURE check; NOT native receipt authentication.

    Each step is (kind, reported_changed_cells, after_snapshot), with each
    after_snapshot externally supplied. A live adapter must independently check
    actual Godot receipt identity, request_id/epoch, process and readback hashes.
    """
    if type(plan) is not dict or plan.get("schema") != SCHEMA:
        raise Refusal("Unknown inert-plan contract")
    if not isinstance(initial_snapshot, ExternalSnapshot):
        raise Refusal("Invalid fixture initial snapshot")
    if plan.get("before_fingerprint") != initial_snapshot.fingerprint():
        raise Refusal("Wrong starting snapshot")
    if type(steps) is not list or len(steps) != len(plan["operations"]):
        raise Refusal("Missing/extra partial source-host operation records")
    previous = initial_snapshot
    for op, row in zip(plan["operations"], steps):
        if type(row) is not tuple or len(row) != 3:
            raise Refusal("Malformed fixture receipt")
        kind, changed, after = row
        if kind != op["kind"] or type(changed) is not int or not isinstance(after, ExternalSnapshot):
            raise Refusal("Invalid operation or changed-count receipt")
        if (after.lease_id, after.runner, after.world, after.source_sha) != (
                previous.lease_id, previous.runner, previous.world, previous.source_sha):
            raise Refusal("Cross-world/source receipt")
        if any(a < b for a, b in zip(after.epoch, previous.epoch)):
            raise Refusal("Non-monotone source epoch")
        if (after.material.width, after.material.height, after.material.protected) != (
                previous.material.width, previous.material.height, previous.material.protected):
            raise Refusal("Protected/focus changed between operation receipts")
        before_mat = previous.material.material
        after_mat = after.material.material
        modifications = [i for i, (a, b) in enumerate(zip(before_mat, after_mat)) if a != b]
        target = tuple(op["target"])
        if kind == "PAINT_ONE":
            index = target[1] * previous.material.width + target[0]
            if (changed != 1 or modifications != [index] or
                    before_mat[index] != 0 or after_mat[index] != INK or
                    previous.cursor != after.cursor or
                    previous.logical_moves != after.logical_moves or after.retired):
                raise Refusal("Forged or incorrect single-cell PAINT effect")
        elif kind == "CURSOR_ONE":
            if (changed != 0 or modifications or after.cursor != target or
                    abs(target[0] - previous.cursor[0]) +
                    abs(target[1] - previous.cursor[1]) != 1 or
                    after.logical_moves != previous.logical_moves + 1 or after.retired):
                raise Refusal("Forged cursor move, material mutation or M3 history")
        elif kind == "STOP":
            if (changed != 0 or modifications or
                    after.cursor != previous.cursor or
                    after.logical_moves != previous.logical_moves or not after.retired):
                raise Refusal("Missing STOP or illegal late write")
        else:
            raise Refusal("Unknown operation")
        previous = after
    return {
        "evidence_class": "mock-external-transcript-checked",
        "native_authenticated": False,
        "operations_checked": len(steps),
        "terminal_fingerprint": previous.fingerprint(),
    }
