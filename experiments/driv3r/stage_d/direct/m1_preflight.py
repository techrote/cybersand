"""Source-pinned D-1A -> D-COMMON M1 *offline* preflight.

This module is a deliberately unprivileged analysis adapter. It audits host-like
candidate geometry and carries the frozen schema identity, but it never emits a
D-COMMON observation/action (those require *real* native World custody).
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
from typing import Any, Callable, Mapping, Sequence

M1_SOURCE_COMMIT = "8fa90de6be209ed0b7bd125039e6ec8b332fb1a6"
M1_SCHEMA_SHA256 = "ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d"
M1_PROTOCOL = "cybersand.driv3r.d-common/1"
VERSION = "d1a-m1-offline-preflight/1"
_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,95}$")


class PreflightError(ValueError):
    """Reject a non-source-bound or non-admissible synthetic candidate."""


def _require(ok: bool, message: str) -> None:
    if not ok:
        raise PreflightError(message)


def _canonical(value: Any) -> bytes:
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":"),
                          allow_nan=False).encode("utf-8")
    except (TypeError, ValueError, OverflowError) as exc:
        raise PreflightError("Non-canonical JSON in candidate/annotation") from exc


def _hash(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def assert_approved_schema(root: Path) -> str:
    """Verify actual schema bytes, not just a version label or an ancestor SHA."""
    schema = root / "experiments/driv3r/d_common/v1/interface.schema.json"
    try:
        actual = hashlib.sha256(schema.read_bytes()).hexdigest()
    except OSError as exc:
        raise PreflightError("Approved M1 schema source not accessible") from exc
    _require(actual == M1_SCHEMA_SHA256, "Approved M1 schema SHA-256 mismatch")
    return actual


def _point(value: Any, width: int, height: int) -> tuple[int, int]:
    _require(type(value) in (tuple, list) and len(value) == 2 and
             all(type(v) is int for v in value), "Point must contain two integers")
    x, y = value
    _require(0 <= x < width and 0 <= y < height,
             "Candidate coordinate outside explicit World bounds")
    return x, y


def legal_catalog(before: Sequence[int], options: Sequence[Any], *,
                  width: int, height: int,
                  legal_cell: Callable[[tuple[int, int]], bool]) -> dict[str, Any]:
    """Canonical ID-sorted *synthetic* legal menu independent of presentation.

    Each offered cursor_move must pass full-sweep cardinal adjacency and the
    authoritative fixture legality callback; a STOP is inert. This digest is
    NOT a real native host's action.legal_candidate_set_sha256 until a
    separately qualified native adapter constructs the same legal menu.
    """
    _require(type(width) is int and type(height) is int and
             1 <= width <= 65536 and 1 <= height <= 65536,
             "World dimensions invalid under frozen M1 schema")
    _require(callable(legal_cell), "Explicit legality authority required")
    origin = _point(before, width, height)
    _require(bool(legal_cell(origin)), "Pre-decision position blocked")
    _require(type(options) in (tuple, list) and 1 <= len(options) <= 33,
             "Invalid bounded candidate menu")
    canonical = []
    seen = set()
    stop_count = 0
    for raw in options:
        source = raw.source() if callable(getattr(raw, "source", None)) else raw
        _require(type(source) is dict and
                 set(source) == {"candidate_id", "path", "stop"},
                 "Candidate must contain exact offline ID/path/stop fields")
        cid, path, is_stop = source["candidate_id"], source["path"], source["stop"]
        _require(type(cid) is str and _ID.fullmatch(cid) is not None and
                 cid not in seen, "Invalid or duplicate candidate ID")
        _require(type(is_stop) is bool and type(path) in (tuple, list),
                 "Candidate path/stop type invalid")
        seen.add(cid)
        if is_stop:
            _require(cid == "STOP" and len(path) == 0,
                     "STOP must be the unique empty-path, inert candidate")
            stop_count += 1
            end, swept, mode = origin, [], "stop"
        else:
            _require(cid != "STOP" and 1 <= len(path) <= 8,
                     "Non-STOP action must have bounded swept path")
            cursor = origin
            swept = []
            for p in path:
                point = _point(p, width, height)
                _require(abs(point[0] - cursor[0]) + abs(point[1] - cursor[1]) == 1,
                         "Noncardinal, discontinuous or duplicate swept step")
                _require(bool(legal_cell(point)),
                         "Swept segment crosses forbidden, protected or material-Z cell")
                swept.append(list(point))
                cursor = point
            end, mode = cursor, "cursor_move"
        canonical.append({
            "id": cid, "mode": mode, "cursor_before": list(origin),
            "cursor_after": list(end), "swept_xy": swept,
            "brush_state": "up", "material_effect": "none",
            "swept_cell_limit": 8,
        })
    _require(stop_count == 1, "Exactly one STOP candidate required")
    canonical.sort(key=lambda item: item["id"])
    return {
        "version": VERSION, "world_size": [width, height],
        "source_kind": "offline_geometry_only",
        "catalog": canonical, "synthetic_legal_catalog_sha256": _hash(canonical),
        "native_legal_catalog_sha256": None,
    }


def model_presentation_hash(catalog: Mapping[str, Any],
                            annotations: Mapping[str, Any] | None = None,
                            order: Sequence[str] | None = None) -> str:
    """Hash model presentation separately without changing hard legal menu.

    Experimental scores/annotations/order cannot be used as admission data.
    """
    offered = {item["id"]: item for item in catalog["catalog"]}
    _require(len(offered) == len(catalog["catalog"]), "Duplicate host IDs")
    notes = dict(annotations or {})
    _require(all(type(k) is str and k in offered for k in notes),
             "Annotation must reference an admitted candidate")
    ordered = list(order) if order is not None else list(offered)
    _require(len(ordered) == len(offered) and
             all(type(v) is str for v in ordered) and
             set(ordered) == set(offered), "Presentation must be a permutation")
    return _hash([{"host_candidate": offered[cid],
                   "soft_annotation": notes.get(cid)} for cid in ordered])


def preflight_episode(fixture: Any, record: dict[str, Any],
                      repo_root: Path | None = None) -> dict[str, Any]:
    """Replay-qualified, DEVELOPMENT-only bridge for M2 admission planning.

    Emits no d-common action/observation record, no supposed native receipts,
    no manufactured World fences and no held-out outcome inspection.
    """
    from . import offline, paired

    _require(fixture.split == "development", "Held-out policy outcomes are sealed")
    verified = paired.verify_episode(fixture, record)
    if repo_root is not None:
        assert_approved_schema(repo_root)
    per_decision = []
    lengths = tuple(record["macro_lengths"])
    for event in record["events"]:
        source = event["observation"]
        position = tuple(source["position"])
        options = offline.candidates(fixture, position, lengths)
        host_shadow = legal_catalog(position, options, width=fixture.width,
                                    height=fixture.height, legal_cell=fixture.legal)
        _require(event["choice_id"] in {o["id"] for o in host_shadow["catalog"]},
                 "Selected action is not on admitted catalog")
        per_decision.append({
            "sequence": event["seq"],
            "cursor_before": list(position), "chosen_candidate_id": event["choice_id"],
            "offline_presentation_sha256": source["candidate_set_sha256"],
            "synthetic_legal_catalog_sha256": host_shadow["synthetic_legal_catalog_sha256"],
            "native_legal_catalog_sha256": None,
            "native_observation_ref": None, "native_receipt_ref": None,
            "synthetic_cursor_after": list(event["simulated_post_position"]),
        })
    return {
        "version": VERSION, "m1_contract_source_commit": M1_SOURCE_COMMIT,
        "m1_schema_sha256": M1_SCHEMA_SHA256, "m1_protocol_target": M1_PROTOCOL,
        "evidence_class": "synthetic_only", "d_common_record_emitted": False,
        "native_world_ref": None, "native_receipts": 0,
        "fixture": fixture.fixture_id, "fixture_sha256": fixture.sha256,
        "episode_sha256": _hash(record), "replay_sha256": _hash(verified),
        "decision_preflights": per_decision,
        "reason": "Native host fences, material bytes and receipts unavailable",
    }
