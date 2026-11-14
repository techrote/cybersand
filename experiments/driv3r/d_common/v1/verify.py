#!/usr/bin/env python3
"""D-COMMON-001 schema + cross-record semantic checks.

This is a review-candidate conformance checker, not a native World simulator.
Synthetic examples skip evidence-byte custody; real campaigns MUST enable it.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent
SCHEMA = ROOT / "interface.schema.json"
EXAMPLES = ROOT / "examples.json"
PROTOCOL = "cybersand.driv3r.d-common/1"


class ContractError(ValueError):
    pass


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def records_from_examples() -> list[dict]:
    return _load(EXAMPLES)["fixtures"]


def _artifacts(record: dict) -> list[dict]:
    name = record["type"]
    if name == "observation":
        return [record["local_material"]] + [view["artifact"] for view in record["feedback_views"]]
    if name == "guidance":
        return [record["values"]] + ([record["display"]] if record["display"] is not None else [])
    if name == "provenance":
        return [record["native"]] + record["artifacts"]
    return []


def validate_bundle(records: list[dict], *, evidence_root: Path | None = None) -> dict[str, Any]:
    """Validate five record shapes, cross-links and selected native-authority rules.

    evidence_root=None is *synthetic shape-only mode*, not a source qualification.
    Supplying evidence_root requires real SHA-256/byte-perfect artifacts and the
    actual schema hash in provenance; this still does NOT prove native execution.
    """
    schema_bytes = SCHEMA.read_bytes()
    schema = json.loads(schema_bytes)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    _require(type(records) is list and records, "Expected a nonempty record list")
    indexed: dict[str, dict] = {}
    episodes: dict[str, list[int]] = {}
    for row in records:
        validator.validate(row)
        _require(row["protocol"] == PROTOCOL, "Wrong protocol")
        rid, eid = row["record_id"], row["episode_id"]
        _require(rid not in indexed, "Duplicate record identity")
        indexed[rid] = row
        episodes.setdefault(eid, []).append(row["sequence"])
    for eid, seq in episodes.items():
        _require(seq == sorted(set(seq)), f"Nonmonotonic or duplicate sequence in {eid}")
    for row in records:
        name = row["type"]
        eid = row["episode_id"]
        def resolve(ref: str | None, expected: str | None = None) -> dict | None:
            if ref is None:
                return None
            _require(ref in indexed, f"Missing referenced record {ref}")
            target = indexed[ref]
            _require(target["episode_id"] == eid, "Cross-episode reference")
            if expected is not None:
                _require(target["type"] == expected, f"Wrong referenced record type for {ref}")
            return target

        if name == "guidance":
            x, y, w, h = row["frame"]
            _require(x + w <= 512 and y + h <= 512, "Guidance frame out of World")
            _require(row["values"]["format"] == "u16le", "Guidance needs lossless u16le")
            _require(row["values"]["bytes"] == 2 * w * h, "Guidance raster size mismatch")
            _require(row["hysteresis"]["exit_below"] < row["hysteresis"]["reenter_at_or_above"],
                     "Guidance exit threshold must precede reentry threshold")
            _require(row["native_material_authority"] is False, "Guidance must not grant material authority")
            if row["display"] is not None:
                _require(row["display"]["format"] == "png", "Speckle display should be PNG")
        elif name == "observation":
            resolve(row["guidance_ref"], "guidance")
            resolve(row["last_action_ref"], "action")
            _, _, w, h = row["local_crop"]
            _require(row["local_material"]["format"] == "i32le", "Native crop must be signed i32le")
            _require(row["local_material"]["bytes"] == 4 * w * h, "Native crop byte extent mismatch")
            fx, fy, fw, fh = row["rules"]["focus"]
            x, y, cw, ch = row["local_crop"]
            _require(x >= fx and y >= fy and x + cw <= fx + fw and y + ch <= fy + fh,
                     "Native crop exceeds focus")
            _require(fx + fw <= 512 and fy + fh <= 512, "Focus exceeds World")
            _require(set(row["rules"]["allowed_materials"]).isdisjoint(
                row["rules"]["forbidden_materials"]), "Hard material sets overlap")
        elif name == "action":
            source = resolve(row["observation_ref"], "observation")
            resolve(row["guidance_ref"], "guidance")
            _require(source["world"] == row["world_precondition"], "Action has stale World fence")
            _require(source["guidance_ref"] == row["guidance_ref"], "Action guidance mismatch")
            if row["path"]:
                _require(row["path"][0] == row["cursor_before"] and
                         row["path"][-1] == row["cursor_after"], "Action path endpoints inconsistent")
            if row["mode"] in ("stop", "no_paint_plan"):
                _require(row["brush_state"] == "up" and row["operation_sha256"] is None,
                         "No-paint action carries material operation")
            if row["mode"] == "add_material":
                _require(row["brush_state"] == "add", "Add action requires add brush")
            if row["mode"] == "erase_material":
                _require(row["brush_state"] == "erase", "Erase action requires erase brush")
            if row["execution_status"] == "candidate":
                _require(row["native_receipt_ref"] is None, "Candidate cannot claim native completion")
            if row["execution_status"] == "committed" and row["brush_state"] != "up":
                _require(row["native_receipt_ref"] is not None, "Committed material action needs real native receipt")
            if row["brush_state"] != "up" and len(row["path"]) > 1:
                _require(all(abs(a[0]-b[0])+abs(a[1]-b[1]) == 1 for a,b in
                             zip(row["path"], row["path"][1:])), "Paint path is not cardinal-contiguous")
        elif name == "reversal":
            resolve(row["source_action_ref"], "action")
            resolve(row["history_anchor_ref"])
            _require(row["brush_lifted"] is True, "Reversal must lift brush")
            cursor_only = row["mechanism"] != "UNDO_MATERIAL_EDIT"
            _require(row["preserve_material_edits"] is cursor_only, "Wrong reversal persistence semantics")
            if row["status"] == "applied":
                _require(row["after_world"] is not None, "Applied reversal missing post-state")
                if cursor_only:
                    _require(row["before_world"]["world_material_sha256"] ==
                             row["after_world"]["world_material_sha256"] and
                             row["before_world"]["material_sha256"] ==
                             row["after_world"]["material_sha256"] and
                             row["actual_material_cells_changed"] == 0 and
                             row["native_undo_receipt_ref"] is None,
                             "Cursor-only reversal changed native materials or fabricated Undo")
                else:
                    _require(row["native_undo_receipt_ref"] is not None,
                             "Real Undo requires native receipt")
            if row["status"] in ("refused", "cancelled"):
                _require(row["actual_material_cells_changed"] == 0,
                         "Refused/cancelled reversal changed native material")
        elif name == "provenance":
            resolve(row["guidance_ref"], "guidance")
            for ref in row["episode_record_refs"]:
                resolve(ref)
            _require(len(row["episode_record_refs"]) == len(set(row["episode_record_refs"])),
                     "Repeated event in provenance")
            if evidence_root is not None:
                _require(row["interface_schema_sha256"] ==
                         hashlib.sha256(schema_bytes).hexdigest(),
                         "Provenance interface schema SHA mismatch")
    if evidence_root is not None:
        base = evidence_root.resolve(strict=True)
        seen: dict[Path, str] = {}
        for row in records:
            for artifact in _artifacts(row):
                candidate = (base / artifact["path"]).resolve(strict=True)
                _require(candidate.is_relative_to(base) and candidate.is_file(),
                         "Evidence path escapes checked root")
                data = candidate.read_bytes()
                _require(len(data) == artifact["bytes"] and
                         hashlib.sha256(data).hexdigest() == artifact["sha256"],
                         "Evidence artifact custody failure: " + artifact["path"])
                if candidate in seen:
                    _require(seen[candidate] == artifact["sha256"],
                             "Same path assigned conflicting SHA identities")
                seen[candidate] = artifact["sha256"]
    return {"validated":len(records),"types":sorted({r["type"] for r in records}),
            "evidence_bytes_verified":evidence_root is not None,
            "schema_sha256":hashlib.sha256(schema_bytes).hexdigest()}


if __name__ == "__main__":
    print(json.dumps(validate_bundle(records_from_examples()), sort_keys=True))
