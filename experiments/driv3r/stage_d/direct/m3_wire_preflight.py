"""D-1A read-only M1/M3 action-wire reconciliation; no native execution.

D-1A's offline candidate S1 means brush-up cursor motion with ZERO material
side effects. The M3 native smoke's MOVE_DOWN_ONE is an add_material action.
Identical cursor displacement must never be mistaken for equal native effect.
This preflight inspects already supplied records; it never emits native receipts,
changes an authority policy or evaluates held-out controller outcomes.
"""
from __future__ import annotations

import hashlib
import json
from typing import Any, Mapping

VERSION = "d1a-m3-wire-preflight/1"
PROTOCOL = "cybersand.driv3r.d-common/1"
M1_SOURCE = "8fa90de6be209ed0b7bd125039e6ec8b332fb1a6"
M1_SCHEMA_SHA256 = "ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d"


class WireMismatch(ValueError):
    """Proposed wire mapping cannot preserve the D-1A action semantics."""


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise WireMismatch(reason)


def point(p: Any) -> tuple[int, int]:
    require(type(p) in (list, tuple) and len(p) == 2 and
            all(type(v) is int and 0 <= v <= 65535 for v in p),
            "Invalid bounded point")
    return (p[0], p[1])


def canonical(value: Any) -> bytes:
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":"),
                          allow_nan=False).encode("utf-8")
    except (ValueError, TypeError, OverflowError) as exc:
        raise WireMismatch("Unserializable or nonfinite wire record") from exc


def cursor_wire_preflight(
    *, synthetic_action: Mapping[str, Any], observation: Mapping[str, Any],
    native_action: Mapping[str, Any], host_candidate: Mapping[str, Any],
    accepted_m1_schema_sha256: str,
) -> dict[str, Any]:
    """Audit a 1..8-cell cursor-only mapping; never certify native results.

    Requires a real host-offered candidate separately from the model-facing
    synthetic action. A real native adapter must additionally independently
    source/receipt-qualify the host, World bytes, admission and sequential
    observation. This check intentionally cannot supply any of those proofs.
    """
    require(accepted_m1_schema_sha256 == M1_SCHEMA_SHA256,
            "M1 exact accepted schema identity required")
    require(all(type(x) is dict for x in (
        synthetic_action, observation, native_action, host_candidate)),
        "Records and candidate must be objects")
    require(observation.get("protocol") == PROTOCOL and
            observation.get("type") == "observation" and
            native_action.get("protocol") == PROTOCOL and
            native_action.get("type") == "action", "Wrong M1 record protocol/type")
    require(native_action.get("episode_id") == observation.get("episode_id") and
            native_action.get("observation_ref") == observation.get("record_id") and
            type(native_action.get("sequence")) is int and
            type(observation.get("sequence")) is int and
            native_action["sequence"] > observation["sequence"],
            "Episode/observation/sequence continuity mismatch")
    budget = observation.get("budget")
    require(type(budget) is dict and
            type(budget.get("decisions_remaining")) is int and
            1 <= budget["decisions_remaining"] <= 36,
            "D-1A budget must be within 1..36 attempted forward decisions")
    world = observation.get("world")
    require(type(world) is dict and
            canonical(native_action.get("world_precondition")) == canonical(world),
            "Stale or substituted observation World")
    width, height = world.get("width_cells"), world.get("height_cells")
    require(type(width) is int and type(height) is int and
            1 <= width <= 65536 and 1 <= height <= 65536,
            "Native World dimensions not admitted")
    before = point(observation.get("cursor"))
    require(point(native_action.get("cursor_before")) == before and
            point(synthetic_action.get("cursor_before")) == before,
            "Cursor starting coordinates differ")
    cid = synthetic_action.get("id")
    require(type(cid) is str and cid in {f"{direction}{length}"
            for direction in "ENSW" for length in (1, 2, 4, 8)},
            "Synthetic action is not a D-1A movement")
    require(synthetic_action.get("mode") == "cursor_move" and
            synthetic_action.get("brush_state") == "up" and
            synthetic_action.get("material_effect") == "none",
            "D-1A movement's brush-up/no-material semantics changed")
    sweep = synthetic_action.get("swept_xy")
    require(type(sweep) is list and len(sweep) == int(cid[1:]),
            "Synthetic swept cardinal length mismatch")
    vectors = {"E": (1, 0), "N": (0, -1), "S": (0, 1), "W": (-1, 0)}
    dx, dy = vectors[cid[0]]
    required_sweep = [(before[0]+i*dx, before[1]+i*dy)
                      for i in range(1, len(sweep)+1)]
    require(all(point(p) == expected for p, expected in zip(sweep, required_sweep)) and
            all(0 <= x < width and 0 <= y < height for x, y in required_sweep),
            "D-1A sweep deviates from identified movement or World bounds")
    after = required_sweep[-1]
    require(point(synthetic_action.get("cursor_after")) == after and
            point(native_action.get("cursor_after")) == after,
            "Cursor endpoint does not match full swept segment")
    require(type(host_candidate.get("id")) is str and
            native_action.get("candidate_id") == host_candidate["id"],
            "Missing exact native host-offered ID")
    host_path = host_candidate.get("path")
    native_path = native_action.get("path")
    expected_path = [before, *required_sweep]
    require(type(host_path) is list and type(native_path) is list and
            [point(p) for p in host_path] == expected_path and
            [point(p) for p in native_path] == expected_path,
            "Host and native path do not match complete D-1A sweep")
    require(native_action.get("mode") == "cursor_move" and
            native_action.get("brush_state") == "up" and
            host_candidate.get("operations") == [] and
            host_candidate.get("cell_budget") == 0,
            "Native candidate paints/erases or is not brush-up cursor-only")
    post = native_action.get("world_postcondition")
    require(type(post) is dict and
            post.get("world_material_sha256") == world.get("world_material_sha256") and
            post.get("material_sha256") == world.get("material_sha256"),
            "Cursor-only operation changed material hashes")
    require(native_action.get("execution_status") in {"candidate", "selected"} and
            native_action.get("native_receipt_ref") is None and
            native_action.get("native_receipt_artifact") is None,
            "Offline mapping cannot claim committed native execution or a receipt")
    return {
        "version": VERSION, "m1_source": M1_SOURCE,
        "m1_schema_sha256": M1_SCHEMA_SHA256,
        "synthetic_candidate_id": cid, "host_candidate_id": host_candidate["id"],
        "catalog_binding_sha256": hashlib.sha256(canonical(host_candidate)).hexdigest(),
        "full_sweep_cells": len(required_sweep),
        "structural_cursor_semantics_compatible": True,
        "native_qualified": False, "sequential_native_receipts": 0,
        "native_campaign_authorized": False,
        "reason": "Wire-only check: no independent native admission/receipts/replay",
    }
