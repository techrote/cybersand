#!/usr/bin/env python3
"""Reduce frozen native detail controls without assigning architectural quality.

Native acknowledgement validation is shared with the original Batch reducer.
Geometry, scope, component anchoring and edit replay below are independently
calculated from the complete retained uint16 planes. A self-consistent artifact
is evidence to audit, not a cryptographic attestation of native execution.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from typing import Any

from evaluate import checked_readback

FORMAT = "cybersand-native-detail-comparison-evidence-v1"
REGISTRATION_SHA256 = "4e69cbdbca9a908ed2062cfc60b7bf448c4a44a73c1a5cd90b8640daabb16852"
JOBS = ("contextual_ribs", "surface_trim", "anchored_clutter", "service_panel",
        "mechanical_infill", "short_pipe", "framed_opening", "edge_wear")
ARMS = ("deterministic", "seeded", "random_valid")
SHA = re.compile(r"^[0-9a-f]{64}$")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def integer(value: Any, low: int, high: int, label: str) -> int:
    if type(value) is not int or not low <= value <= high:
        raise ValueError(f"{label} must be an integer in {low}..{high}")
    return value


def digest(value: Any, label: str) -> str:
    if not isinstance(value, str) or not SHA.fullmatch(value):
        raise ValueError(f"{label} must be a lowercase SHA-256")
    return value


def read_bound(base: Path, descriptor: Any, limit: int) -> bytes:
    if not isinstance(descriptor, dict) or not isinstance(descriptor.get("path"), str):
        raise ValueError("Artifact descriptor must name a relative file")
    relative = Path(descriptor["path"])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Artifact path leaves its evidence directory")
    path = (base / relative).resolve()
    if not path.is_relative_to(base.resolve()) or not path.is_file():
        raise ValueError("Artifact is missing or escapes through a symlink")
    if path.stat().st_size > limit:
        raise ValueError("Artifact exceeds the declared finite read bound")
    raw = path.read_bytes()
    if sha(raw) != digest(descriptor.get("sha256"), "artifact hash"):
        raise ValueError("Artifact SHA-256 mismatch")
    return raw


def rectangle(value: Any, width: int, height: int) -> tuple[int, int, int, int]:
    if not isinstance(value, list) or len(value) != 4:
        raise ValueError("Expected a four-integer context rectangle")
    x = integer(value[0], 0, width - 1, "rectangle x")
    y = integer(value[1], 0, height - 1, "rectangle y")
    w = integer(value[2], 1, width, "rectangle width")
    h = integer(value[3], 1, height, "rectangle height")
    if x + w > width or y + h > height:
        raise ValueError("Context rectangle exceeds the observed material plane")
    return x, y, w, h


def mask(values: Any, width: int, height: int) -> set[int]:
    if not isinstance(values, list) or len(values) > 256:
        raise ValueError("Context rectangle list is malformed or oversized")
    result: set[int] = set()
    for value in values:
        x, y, w, h = rectangle(value, width, height)
        result.update(yy * width + xx for yy in range(y, y + h) for xx in range(x, x + w))
    return result


def neighbors(index: int, width: int, height: int):
    x, y = index % width, index // width
    if x: yield index - 1
    if x + 1 < width: yield index + 1
    if y: yield index - width
    if y + 1 < height: yield index + width


def components(indices: set[int], width: int, height: int) -> list[set[int]]:
    remaining = set(indices)
    result = []
    while remaining:
        first = remaining.pop()
        component, pending = {first}, [first]
        for index in pending:
            for adjacent in neighbors(index, width, height):
                if adjacent in remaining:
                    remaining.remove(adjacent)
                    component.add(adjacent)
                    pending.append(adjacent)
        result.append(component)
    return result


def geometry_metrics(before: list[int], after: list[int], context: dict,
                     job: str, width: int, height: int) -> dict:
    if len(before) != width * height or len(after) != len(before) or not isinstance(context, dict):
        raise ValueError("Metric input is not a complete declared material plane")
    region = mask([context.get("job_region")], width, height)
    protected = mask(context.get("protected", []), width, height)
    fixed = mask(context.get("fixed_regions", []), width, height)
    variable = mask(context.get("variable_regions", []), width, height)
    clearance = mask(context.get("clearances", []), width, height)
    points = context.get("attachment_cells", [])
    if not isinstance(points, list) or len(points) > 8192:
        raise ValueError("Attachment cell list is malformed or oversized")
    attachments = set()
    for point in points:
        if not isinstance(point, list) or len(point) != 2:
            raise ValueError("Attachment must be a two-integer material cell")
        x = integer(point[0], 0, width - 1, "attachment x")
        y = integer(point[1], 0, height - 1, "attachment y")
        attachments.add(y * width + x)
    changed = {i for i, (a, b) in enumerate(zip(before, after)) if a != b}
    added = {i for i in changed if before[i] == 0 and after[i] != 0}
    removed = {i for i in changed if before[i] != 0 and after[i] == 0}
    support = {i for i, material in enumerate(before) if material in (7, 13, 28, 58)}
    added_components = components(added, width, height)
    grounded = [any(n in support for i in part for n in neighbors(i, width, height))
                for part in added_components]
    violations = {
        "outside_job_changed_cells": len(changed - region),
        "protected_changed_cells": len(changed & protected),
        "fixed_changed_cells": len(changed & fixed),
        "attachment_changed_cells": len(changed & attachments),
        "clearance_occupied_cells": sum(after[i] != 0 for i in clearance),
        "source_clearance_occupied_cells": sum(before[i] != 0 for i in clearance),
        "invalid_source_write_cells": sum(
            not (i in variable and before[i] == 58 and after[i] == 0)
            if job == "edge_wear" else not (before[i] == 0 and after[i] != 0)
            for i in changed),
    }
    return {
        **violations, "constraints_preserved": not any(violations.values()),
        "changed_cells": len(changed), "added_cells": len(added), "removed_cells": len(removed),
        "added_components": len(added_components), "source_anchored_components": sum(grounded),
        "unanchored_added_cells": sum(len(part) for part, anchored in zip(added_components, grounded) if not anchored),
        "occupied_face_components_before": len(components({i for i, m in enumerate(before) if m}, width, height)),
        "occupied_face_components_after": len(components({i for i, m in enumerate(after) if m}, width, height)),
        "scope": "Four-neighbor material contact and explicit cell scopes; no physics, traversal or aesthetic quality inference.",
    }


def accepted_edit_replay(native: dict, before: list[int], after: list[int], width: int, height: int) -> None:
    edits = native.get("accepted_edits")
    if not isinstance(edits, list) or len(edits) > 4096:
        raise ValueError("Accepted native edit history is missing or oversized")
    replay = before.copy()
    painted = 0
    for edit in edits:
        if not isinstance(edit, list) or len(edit) != 5:
            raise ValueError("Accepted native edit is malformed")
        x, y, w, h = rectangle(edit[:4], width, height)
        material = integer(edit[4], 0, 65535, "accepted material")
        painted += w * h
        if painted > 512:
            raise ValueError("Accepted detail history exceeds the registered cell ceiling")
        for yy in range(y, y + h):
            for xx in range(x, x + w): replay[yy * width + xx] = material
    if replay != after:
        raise ValueError("Accepted native edit history does not reproduce the retained full result")


def evaluate_case(row: Any, base: Path, source: str) -> dict:
    item = {"id": str(row.get("id", "missing")) if isinstance(row, dict) else "malformed",
            "evaluable": False, "status": str(row.get("status", "unknown")) if isinstance(row, dict) else "malformed"}
    try:
        if not isinstance(row, dict) or row.get("job") not in JOBS or row.get("arm") not in ARMS:
            raise ValueError("Case has no registered job and arm")
        item.update(job=row["job"], arm=row["arm"], seed=row.get("seed"))
        expected_id = row["job"].replace("_", "-") + "-" + row["arm"].replace("_", "-")
        expected_seed = 0 if row["arm"] == "deterministic" else 47017
        if row.get("id") != expected_id or type(row.get("seed")) is not int or row["seed"] != expected_seed or row.get("extent") != [64, 64]:
            raise ValueError("Case identity, seed or extent differs from the frozen apparatus")
        native = json.loads(read_bound(base, row.get("native_record"), 2 * 1024 * 1024))
        if not isinstance(native, dict): raise ValueError("Native record is not an object")
        config, before, after, before_raw, after_raw, acknowledged = checked_readback(native)
        if config.get("extent") != [64, 64] or native.get("state") != row.get("status"):
            raise ValueError("Native extent or terminal state differs from the retained case")
        provenance = native["provenance"]
        if provenance.get("source_revision") != source:
            raise ValueError("Native record and manifest tested source differ")
        binary = digest(provenance.get("native_binary_sha256"), "native binary identity")
        for key, raw in (("before", before_raw), ("after", after_raw)):
            descriptor = row.get(key)
            if not isinstance(descriptor, dict) or descriptor.get("encoding") != "u16le" or read_bound(base, descriptor, 8192) != raw:
                raise ValueError("Standalone and retained native planes differ")
        if row.get("source_sha256") != sha(before_raw):
            raise ValueError("Proposed source and actual native source differ")
        recipe = json.loads(read_bound(base, row.get("recipe"), 2 * 1024 * 1024))
        if not isinstance(recipe, dict) or recipe.get("input_snapshot_sha256") != sha(before_raw):
            raise ValueError("Native stage does not pin the retained source")
        program = json.dumps(recipe.get("operations"), ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
        if sha(program) != row.get("program_sha256"):
            raise ValueError("Program identity differs from the retained approved stage")
        receipts = native["receipts"]
        if not receipts: raise ValueError("No native receipt was retained")
        checked = sum(receipt["checked"] for receipt in receipts)
        excluded = sum(receipt["excluded"] for receipt in receipts)
        refused = sum(receipt["refused"] for receipt in receipts)
        if checked > 512 or excluded or refused:
            raise ValueError("Detail acknowledgement exceeds its ceiling or contains excluded/refused writes")
        accepted_edit_replay(native, before, after, 64, 64)
        metrics = geometry_metrics(before, after, row.get("context"), row["job"], 64, 64)
        item.update(evaluable=True, metrics=metrics, native_checked_cells=checked,
                    native_changed_acknowledgements=acknowledged, native_receipts=len(receipts),
                    source_sha256=sha(before_raw), result_sha256=sha(after_raw), native_binary_sha256=binary,
                    exact_compiled_projection_match=sha(after_raw) == row.get("projection_sha256"),
                    source_pin_refusal_reported=row.get("source_pin_refusal_verified") is True,
                    timings=row.get("timings", {}))
    except (ValueError, KeyError, TypeError, IndexError, OSError) as exc:
        item["reason"] = str(exc)
    return item


def evaluate(document: dict, base: Path, registration: bytes) -> dict:
    if not isinstance(document, dict) or document.get("format") != FORMAT:
        raise ValueError("Unsupported native detail evidence format")
    if sha(registration) != REGISTRATION_SHA256 or document.get("registration_sha256") != REGISTRATION_SHA256:
        raise ValueError("Frozen detail registration identity differs")
    source = document.get("source_revision")
    if not isinstance(source, str) or not re.fullmatch(r"[0-9a-f]{40}", source):
        raise ValueError("Manifest lacks an exact source revision")
    rows = document.get("cases")
    if not isinstance(rows, list) or len(rows) > 128:
        raise ValueError("Case list is missing or oversized")
    outcomes, seen = [], set()
    for row in rows:
        item = evaluate_case(row, base, source)
        if item["id"] in seen:
            item.update(evaluable=False, reason="Duplicate registered case identity")
        seen.add(item["id"])
        outcomes.append(item)
    for job in JOBS:
        for arm in ARMS:
            identity = job.replace("_", "-") + "-" + arm.replace("_", "-")
            if identity not in seen:
                outcomes.append({"id": identity, "job": job, "arm": arm, "status": "missing-registered-case", "evaluable": False,
                                 "reason": "No outcome retained for this frozen case; preserved in denominator."})
    good = [item for item in outcomes if item["evaluable"]]
    blocks = []
    for job in JOBS:
        entries = [item for item in good if item.get("job") == job]
        by_arm = {item["arm"]: item for item in entries}
        complete = len(entries) == 3 and len(by_arm) == 3
        blocks.append({"job": job, "three_arms_evaluable": complete,
                       "distinct_output_hashes": len({item["result_sha256"] for item in entries}),
                       "shared_source": complete and len({item["source_sha256"] for item in entries}) == 1,
                       "seeded_random_changed_count_matched": complete and by_arm["seeded"]["metrics"]["changed_cells"] == by_arm["random_valid"]["metrics"]["changed_cells"],
                       "deterministic_seeded_identical": complete and by_arm["deterministic"]["result_sha256"] == by_arm["seeded"]["result_sha256"]})
    return {"format": "cybersand-native-detail-analysis-v1", "source_revision": source,
            "registration_sha256": REGISTRATION_SHA256,
            "fixture_source_sha256": document.get("fixture_source_sha256"), "worker_source_sha256": document.get("worker_source_sha256"),
            "model_calls": 0 if type(document.get("model_calls")) is int and document["model_calls"] == 0 else None,
            "native_active_core_capacity": document.get("native_active_core_capacity"),
            "development_core_capacity_override": document.get("development_core_capacity_override"),
            "registered_cases": 24, "retained_rows": len(rows), "evaluable_cases": len(good),
            "status_counts": dict(Counter(item["status"] for item in outcomes)),
            "constraints_preserved_cases": sum(item["metrics"]["constraints_preserved"] for item in good),
            "exact_projection_cases": sum(item["exact_compiled_projection_match"] for item in good),
            "native_binary_sha256": sorted({item["native_binary_sha256"] for item in good}),
            "blocks": blocks, "cases": outcomes,
            "scope": "Independent retained-plane/counter/accepted-edit and geometric constraint diagnostics. No physical support, gameplay, aesthetic preference, human blindness or inference-quality claim."}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--registration", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.manifest.stat().st_size > 16 * 1024 * 1024: raise ValueError("Manifest exceeds finite bound")
    raw = args.manifest.read_bytes()
    result = evaluate(json.loads(raw), args.manifest.parent, args.registration.read_bytes())
    result["manifest_sha256"] = sha(raw)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({key: result[key] for key in ("registered_cases", "retained_rows", "evaluable_cases", "constraints_preserved_cases", "exact_projection_cases")}))


if __name__ == "__main__":
    main()
