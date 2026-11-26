#!/usr/bin/env python3
"""Independently reduce the final, source-bound M7 native hierarchy witness.

This is a deliberately narrow verifier for the 512-square workshop demonstration,
including its separately approved eight-piece attachment recovery stage. It does
not certify arbitrary Session JSON, restore live authority, infer a Stop prefix
from timing, or replace extracted-runtime, reopen, graphics or gameplay gates.
Only Python's standard library is used. Inputs are never modified.

Example:
  python tools/batch_lab/verify_hierarchy_native.py evidence/hierarchy-native.json \
    --expected-source <40-hex-commit> --require-default-capacity \
    --output evidence/independent-hierarchy-verification.json
"""
from __future__ import annotations

import argparse
import base64
import binascii
import copy
import hashlib
import json
import math
from pathlib import Path, PurePosixPath, PureWindowsPath
import re
import sys
from typing import Any

FORMAT = "cybersand-independent-hierarchy-verification-v1"
WITNESS_FORMAT = "cybersand-native-hierarchy-witness-v1"
PLAN_FORMAT = "cybersand-architecture-plan-v1"
CAMPAIGN_FORMAT = "cybersand-architecture-campaign-v1"
HISTORY_FORMAT = "cybersand-architecture-campaign-history-v1"
WORLD = (0, 0, 512, 512)
RECOVERY = (64, 160, 384, 160)
PASSAGE = (208, 336, 96, 80)
ATTACHMENT_REGION = (32, 128, 448, 192)
WORLD_BYTES = 512 * 512 * 2
MAX_JSON_BYTES = 64 * 1024 * 1024
MAX_TOTAL_BYTES = 192 * 1024 * 1024
MAX_RECORDS = 128
MAX_RECEIPTS = 512
MAX_RECEIPT_ROWS = 4096
MAX_TOTAL_ROWS = 1048576
MAX_RASTER = 1048576
NATIVE_ORDER = [
    "workshop-frame", "service-parts", "access-gallery", "mounted-ribs",
    "service-connection", "controlled-wear", "cladding-trial",
    "clear-stopped-prefix", "open-workshop-bays", "attach-workshop-bays",
]
WORKER_IDS = ["mounted-ribs", "service-connection", "controlled-wear"]
WORKER_KINDS = ["contextual_ribs", "short_pipe", "edge_wear"]
MODULE_INSTANCES = {
    "workshop-transition": ("fractured-wall-transition", (32, 352)),
    "workshop-valve": ("valve-chamber", (352, 352)),
    "workshop-tee": ("pipe-tee", (416, 356)),
}
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
HEX40 = re.compile(r"[0-9a-f]{40}\Z")


class Violation(ValueError):
    def __init__(self, reason: str, code: str = "invalid-evidence") -> None:
        super().__init__(reason)
        self.code = code


def require(condition: bool, reason: str, code: str = "invalid-evidence") -> None:
    if not condition:
        raise Violation(reason, code)


def integer(value: Any, low: int, high: int, label: str) -> int:
    require(type(value) is int and low <= value <= high,
            f"{label}: expected integer in [{low}, {high}]", "integer")
    return value


def obj(value: Any, label: str) -> dict:
    require(type(value) is dict, f"{label}: expected object", "shape")
    return value


def seq(value: Any, maximum: int, label: str) -> list:
    require(type(value) is list and len(value) <= maximum,
            f"{label}: expected bounded array (maximum {maximum})", "shape")
    return value


def text(value: Any, maximum: int, label: str, empty: bool = False) -> str:
    require(type(value) is str and len(value) <= maximum and (empty or bool(value)),
            f"{label}: expected bounded text", "shape")
    return value


def identity(value: Any, label: str, length: int = 64) -> str:
    pattern = HEX40 if length == 40 else HEX64
    require(type(value) is str and pattern.fullmatch(value) is not None,
            f"{label}: expected lowercase SHA-{length * 4} hex", "identity")
    return value


def sha(data: bytes | bytearray) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_numbers(value: Any, module: bool = False) -> Any:
    # Godot parses JSON integers as floating point, then normalizes integral
    # values before hashing. Module metadata additionally preserves large i64s.
    limit = 9007199254740991 if module else 2147483647
    if type(value) is int and module and abs(value) > 9007199254740991:
        return "i64:" + str(value)
    if type(value) is float:
        require(math.isfinite(value), "Nonfinite JSON number", "json-number")
        if value.is_integer() and abs(value) <= limit:
            return int(value)
        # Full-precision Godot decimal formatting has not been independently
        # qualified here. Raw artifact hashes bind those metadata fields.
        raise Violation("Inner checksum contains an unqualified nonintegral "
                        "decimal; raw-file custody alone cannot replace this "
                        "specific integer-valued stage/module identity check.",
                        "decimal-canonicalization")
    if type(value) is list:
        return [canonical_numbers(item, module) for item in value]
    if type(value) is dict:
        require(all(type(key) is str for key in value), "JSON object key is not text")
        return {key: canonical_numbers(item, module) for key, item in value.items()}
    return value


def canonical_bytes(value: Any, module: bool = False) -> bytes:
    return json.dumps(canonical_numbers(value, module), sort_keys=True,
                      ensure_ascii=False, separators=(",", ":"),
                      allow_nan=False).encode("utf-8")


def inner_hash(value: Any, module: bool = False) -> str:
    return sha(canonical_bytes(value, module))


def _pairs(pairs: list[tuple[str, Any]]) -> dict:
    result: dict = {}
    for key, value in pairs:
        require(key not in result, f"Duplicate JSON key: {key}", "duplicate-key")
        result[key] = value
    return result


def strict_json(data: bytes, label: str) -> Any:
    require(len(data) <= MAX_JSON_BYTES, f"{label}: JSON exceeds file bound", "file-size")
    def nonfinite(value: str) -> None:
        raise Violation(f"{label}: nonfinite JSON token {value}", "json-number")
    try:
        value = json.loads(data.decode("utf-8"), object_pairs_hook=_pairs,
                           parse_constant=nonfinite)
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as error:
        raise Violation(f"{label}: malformed or too deeply nested JSON: {error}", "json") from error
    # A breadth-first finite walk bounds nested metadata before recursive hashes.
    pending = [(value, 0)]
    count = 0
    while pending:
        item, depth = pending.pop()
        count += 1
        require(depth <= 48 and count <= 8 * MAX_TOTAL_ROWS,
                f"{label}: JSON depth/node capacity exceeded", "json-bound")
        if type(item) is dict:
            pending.extend((child, depth + 1) for child in item.values())
        elif type(item) is list:
            pending.extend((child, depth + 1) for child in item)
        elif type(item) is float:
            require(math.isfinite(item), f"{label}: nonfinite number", "json-number")
    return value


class Custody:
    """Read only bounded regular artifacts contained by the manifest directory."""
    def __init__(self, directory: Path) -> None:
        self.root = directory.resolve(strict=True)
        require(self.root.is_dir(), "Evidence root is not a directory", "path")
        self.files: list[dict] = []
        self.total = 0

    def read(self, name: Any, maximum: int, expected: str | None = None) -> bytes:
        text(name, 240, "artifact path")
        path = PurePosixPath(name)
        require(not path.is_absolute() and not PureWindowsPath(name).is_absolute()
                and "\\" not in name and ":" not in name
                and all(part not in ("", ".", "..") for part in path.parts),
                "Artifact path is not a confined relative path", "path")
        candidate = (self.root / path).resolve(strict=True)
        require(candidate.is_relative_to(self.root) and candidate.is_file(),
                "Artifact resolves outside evidence root or is not a file", "path")
        size = candidate.stat().st_size
        require(0 <= size <= maximum and self.total + size <= MAX_TOTAL_BYTES,
                "Artifact or combined input exceeds byte bound", "file-size")
        with candidate.open("rb") as handle:
            data = handle.read(maximum + 1)
        require(len(data) == size and len(data) <= maximum,
                "Artifact size changed while reading", "file-size")
        digest = sha(data)
        if expected is not None:
            require(digest == identity(expected, name + " SHA"),
                    f"{name}: byte SHA-256 differs", "file-hash")
        self.total += len(data)
        self.files.append({"path":name, "bytes":len(data), "sha256":digest})
        return data

    def json(self, name: str) -> dict:
        return obj(strict_json(self.read(name, MAX_JSON_BYTES), name), name)


def rect(value: Any, label: str, bounds: tuple[int, int, int, int] = WORLD) -> tuple[int, int, int, int]:
    values = seq(value, 4, label)
    require(len(values) == 4, f"{label}: rectangle needs four integers", "rectangle")
    x, y = integer(values[0], 0, 511, label), integer(values[1], 0, 511, label)
    w, h = integer(values[2], 1, 512, label), integer(values[3], 1, 512, label)
    bx, by, bw, bh = bounds
    require(bx <= x and by <= y and x + w <= bx + bw and y + h <= by + bh,
            f"{label}: rectangle escapes its declared bounds", "rectangle")
    return x, y, w, h


def point(value: Any, label: str) -> tuple[int, int]:
    pair = seq(value, 2, label)
    require(len(pair) == 2, f"{label}: point needs two integers", "point")
    return integer(pair[0], 0, 511, label), integer(pair[1], 0, 511, label)


def points(box: tuple[int, int, int, int]):
    x, y, width, height = box
    for py in range(y, y + height):
        for px in range(x, x + width):
            yield px, py


def inside(p: tuple[int, int], box: tuple[int, int, int, int]) -> bool:
    x, y, width, height = box
    return x <= p[0] < x + width and y <= p[1] < y + height


def cell(plane: bytes | bytearray, p: tuple[int, int]) -> int:
    offset = (p[1] * 512 + p[0]) * 2
    return plane[offset] | (plane[offset + 1] << 8)


def put(plane: bytearray, p: tuple[int, int], material: int) -> None:
    offset = (p[1] * 512 + p[0]) * 2
    plane[offset] = material & 255
    plane[offset + 1] = material >> 8


def crop(plane: bytes | bytearray, box: tuple[int, int, int, int]) -> bytes:
    x, y, width, height = box
    return b"".join(plane[(row * 512 + x)*2:(row * 512 + x + width)*2]
                    for row in range(y, y + height))


def decoded_plane(value: Any, expected_bytes: int, label: str) -> bytes:
    text(value, ((expected_bytes + 2)//3)*4, label, empty=True)
    try:
        result = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as error:
        raise Violation(f"{label}: malformed base64", "plane") from error
    require(len(result) == expected_bytes
            and base64.b64encode(result).decode("ascii") == value,
            f"{label}: plane size or canonical base64 differs", "plane")
    return result


def module_library(document: dict) -> dict[str, dict]:
    require(document.get("format") == "cybersand-native-module-library-v1",
            "Wrong module library format", "module")
    raw = seq(document.get("modules"), 128, "module library")
    identity(document.get("content_sha256"), "stored library identity")
    modules: dict[str, dict] = {}
    geometry_bytes = 0
    for entry in raw:
        module = obj(entry, "module")
        module_id = text(module.get("id"), 64, "module id")
        require(module_id not in modules, "Duplicate module id", "module")
        require(module.get("format") in ("cybersand-native-module-v1", "cybersand-native-module-v2"),
                "Unsupported module format", "module")
        extent = seq(module.get("extent"), 2, "module extent")
        require(len(extent) == 2, "Module extent needs two dimensions", "module")
        width = integer(extent[0], 1, 512, "module width")
        height = integer(extent[1], 1, 512, "module height")
        geometry = obj(module.get("geometry"), "module geometry")
        require(geometry.get("encoding") == "uint16-le-row-major", "Wrong module encoding", "module")
        data = decoded_plane(geometry.get("cells_base64"), width*height*2, "module geometry")
        geometry_bytes += len(data)
        require(geometry_bytes <= 16*1024*1024, "Module decoded geometry capacity exceeded", "module")
        require(sha(data) == identity(geometry.get("sha256"), "module geometry SHA"),
                "Module geometry checksum differs", "module")
        identity(module.get("content_sha256"), "stored module content identity")
        # Only the three selected documents require inner checksum proof below.
        # Other catalogue metadata (including decimal recipes) is bound as raw
        # library bytes, without pretending a foreign float renderer is exact.
        modules[module_id] = {"document":module, "cells":data, "extent":(width, height)}
    require(set(item[0] for item in MODULE_INSTANCES.values()) <= modules.keys(),
            "Required curated native parts are missing", "module")
    for module_id, _ in MODULE_INSTANCES.values():
        module = modules[module_id]["document"]
        unhashed = {key:value for key, value in module.items() if key != "content_sha256"}
        require(inner_hash(unhashed, module=True) == module["content_sha256"],
                "Selected module content checksum differs: " + module_id, "module")
    return modules


def shifted_boxes(module: dict, field: str, origin: tuple[int, int],
                  extent: tuple[int, int]) -> list[tuple[int, int, int, int]]:
    result = []
    for raw in seq(module.get(field, []), 128, field):
        local = rect(raw, field, (0, 0, extent[0], extent[1]))
        result.append((origin[0]+local[0], origin[1]+local[1], local[2], local[3]))
    return result


def project_stage(stage: dict, before: bytes | bytearray, modules: dict,
                  retained_guards: list[tuple[int, int, int, int]] = ()) -> dict:
    """Independent bounded raster projection for this witness's exact operations."""
    region = rect(stage.get("region"), "stage region")
    materials = seq(stage.get("materials"), 256, "stage materials")
    require(materials and len(set(materials)) == len(materials), "Empty or duplicate permissions")
    for material in materials:
        integer(material, 0, 65535, "stage material")
        require(material in (0, 7, 28, 58), "Unexpected witness material", "material")
    guards = [rect(item, "protected") for item in seq(stage.get("protected", []), 64, "protected")]
    require(len(guards) + len(retained_guards) <= 64, "Combined protected limit exceeded", "guard")
    guards += list(retained_guards)
    clearances = [rect(item, "clearance", region)
                  for item in seq(stage.get("clearances", []), 128, "clearances")]
    projected = bytearray(before)
    seen: set[tuple[int, int]] = set()
    emitted = 0
    new_guards: list[tuple[int, int, int, int]] = []
    selected_summaries = []
    def emit(p: tuple[int, int], material: int) -> None:
        nonlocal emitted
        emitted += 1
        require(emitted <= MAX_RASTER, "Independent raster bound exceeded", "budget")
        require(inside(p, region), "Proposed operation escapes stage", "region")
        require(not any(inside(p, guard) for guard in guards),
                "Proposed operation intersects protection", "guard")
        require(material in materials, "Operation uses undeclared material", "material")
        seen.add(p)
        put(projected, p, material)
    selected = seq(stage.get("modules", []), 64, "stage modules")
    for selection in selected:
        selection = obj(selection, "selected module")
        module_id = selection.get("module_id")
        require(module_id in modules, "Missing selected module", "module")
        known = modules[module_id]
        document, data, extent = known["document"], known["cells"], known["extent"]
        require(selection.get("module_sha256") == document["content_sha256"],
                "Selected module source identity changed", "module")
        placement = obj(selection.get("placement"), "placement")
        require(placement.get("transform", "identity") == "identity"
                and not placement.get("palette", {})
                and placement.get("variation", {}).get("keep_fraction", 1) == 1,
                "This hierarchy witness qualifies identity placement only", "module")
        origin = point(placement.get("origin"), "placement origin")
        rect([origin[0], origin[1], *extent], "complete module footprint", region)
        require("identity" in document.get("allowed_transforms", []),
                "Identity placement is not allowed", "module")
        new_guards += shifted_boxes(document, "protected_regions", origin, extent)
        clearances += shifted_boxes(document, "clearances", origin, extent)
        for ly in range(extent[1]):
            for lx in range(extent[0]):
                index = (ly*extent[0]+lx)*2
                material = data[index] | (data[index+1] << 8)
                if material:
                    emit((origin[0]+lx, origin[1]+ly), material)
        selected_summaries.append({"id":module_id, "sha256":document["content_sha256"],
            "instance_id":selection.get("instance_id"), "placement":placement})
    operations = seq(stage.get("operations", []), 2048, "stage operations")
    require(operations or selected, "Stage contains no finite construction", "stage")
    for raw in operations:
        operation = obj(raw, "operation")
        material = integer(operation.get("material"), 0, 65535, "operation material")
        shape = operation.get("shape")
        if shape == "rectangle":
            x0 = integer(operation.get("x0"), 0, 511, "rectangle x0")
            y0 = integer(operation.get("y0"), 0, 511, "rectangle y0")
            x1 = integer(operation.get("x1"), x0, 511, "rectangle x1")
            y1 = integer(operation.get("y1"), y0, 511, "rectangle y1")
            for p in points((x0, y0, x1-x0+1, y1-y0+1)):
                emit(p, material)
        elif shape == "pixels":
            for raw_point in seq(operation.get("points"), MAX_RASTER, "pixel points"):
                emit(point(raw_point, "pixel"), material)
        else:
            raise Violation("Unsupported shape in this independently bounded witness: " + str(shape), "shape")
    for guard in new_guards:
        rect(list(guard), "new module protection", region)
        require(all(cell(projected, p) == cell(before, p) for p in points(guard)),
                "Placed module protection changed", "guard")
    require(len(clearances) <= 256, "Combined clearance capacity exceeded", "clearance")
    for box in clearances:
        rect(list(box), "complete clearance", region)
        require(all(cell(projected, p) == 0 for p in points(box)),
                "Projected construction blocks required empty clearance", "clearance")
    validate_connections(stage.get("connections", []), projected, region)
    changes = []
    for p in seen:
        old, new = cell(before, p), cell(projected, p)
        if old != new:
            require(old in (0, 58), "Native Art would replace an unsupported source material", "material")
            changes.append([p[0], p[1], old, new])
    changes.sort(key=lambda row:(row[3], row[1], row[0]))
    ceiling = integer(obj(stage.get("budget"), "stage budget").get("max_checked_cells"),
                      1, 262144, "stage cell ceiling")
    require(len(changes) <= ceiling, "Projected native cell cost exceeds ceiling", "budget")
    return {"plane":projected, "changes":changes, "emitted":emitted, "unique":len(seen),
            "region":region, "guards":guards, "new_guards":new_guards,
            "clearances":clearances, "resolved_modules":selected_summaries}


def validate_connections(raw: Any, plane: bytes | bytearray,
                         region: tuple[int, int, int, int]) -> set:
    contacts = set()
    for item in seq(raw, 128, "connection requirements"):
        item = obj(item, "connection requirement")
        kind = item.get("kind")
        require(kind in ("solid-contact", "empty-contact"), "Unknown connection kind", "connection")
        a, b = point(item.get("a"), "contact a"), point(item.get("b"), "contact b")
        require(inside(a, region) and inside(b, region)
                and abs(a[0]-b[0])+abs(a[1]-b[1]) == 1,
                "Contact is out of scope or not face adjacent", "connection")
        require((cell(plane, a) == 0) == (kind == "empty-contact")
                and (cell(plane, b) == 0) == (kind == "empty-contact"),
                "Contact lacks actual projected occupancy", "connection")
        contacts.add((kind, tuple(sorted((a, b)))))
    return contacts


def replay_receipts(receipts: Any, before: bytes | bytearray, region: tuple,
                    generation: int, expected_rows: list[list[int]]) -> tuple[bytearray, list, int]:
    plane = bytearray(before)
    rows = []
    chunks = seq(receipts, MAX_RECEIPTS, "native receipts")
    previous_revision = None
    for chunk_index, raw in enumerate(chunks):
        receipt = obj(raw, "native receipt")
        require(receipt.get("backend") == "CyberNativeCellWorld"
                and receipt.get("status") == "completed",
                "Receipt is not a completed native receipt", "receipt-status")
        values = {key:integer(receipt.get(key), 0, MAX_RECEIPT_ROWS, "receipt "+key)
                  for key in ("requested", "checked", "changed", "unchanged",
                              "confirmed", "excluded", "refused")}
        require(values["requested"] == values["checked"]
                == values["changed"] + values["unchanged"] + values["excluded"] + values["refused"]
                and values["confirmed"] == values["changed"] + values["unchanged"],
                "Receipt counter algebra differs", "receipt-counters")
        require(values["excluded"] == values["refused"] == values["unchanged"] == 0
                and values["checked"] == values["changed"] > 0,
                "This native witness requires changed-only successful receipts", "receipt-counters")
        require(integer(receipt.get("generation"), 1, 2147483647, "receipt generation") == generation,
                "Native receipt belongs to a different World generation", "generation")
        native_before = obj(receipt.get("before_source"), "receipt source")
        require(integer(native_before.get("generation"), 1, 2147483647, "receipt before generation") == generation,
                "Native receipt source generation differs", "generation")
        authoring = integer(receipt.get("authoring_generation"), 1, 2147483647, "native authoring generation")
        require(integer(native_before.get("authoring_generation"), 1, 2147483647,
                        "before authoring generation") == authoring,
                "Authoring generation changed inside a native receipt", "generation")
        before_revision = integer(native_before.get("revision"), 0, 9223372036854775807, "before revision")
        after_revision = integer(receipt.get("revision"), before_revision, 9223372036854775807, "after revision")
        if previous_revision is not None:
            require(before_revision == previous_revision, "Native receipt revision chain broke", "receipt-chain")
        previous_revision = after_revision
        require(integer(receipt.get("tick"), 0, 9223372036854775807, "native tick") == 0
                and integer(native_before.get("tick"), 0, 9223372036854775807, "before tick") == 0,
                "Paused static witness contains a simulation tick", "scope")
        readback = seq(receipt.get("readback"), MAX_RECEIPT_ROWS, "native readback rows")
        require(len(readback) == values["confirmed"], "Receipt readback denominator differs", "receipt-counters")
        for raw_row in readback:
            row = seq(raw_row, 4, "readback row")
            require(len(row) == 4, "Readback row needs x,y,old,new", "row")
            p = point(row[:2], "readback point")
            old = integer(row[2], 0, 65535, "old material")
            new = integer(row[3], 0, 65535, "new material")
            require(inside(p, region), "Native write escaped approved region", "region")
            require(cell(plane, p) == old, "Native old material differs from reconstructed World", "receipt-chain")
            require(len(rows) < len(expected_rows) and row == expected_rows[len(rows)],
                    "Native rows are not the exact approved change prefix", "receipt-prefix")
            put(plane, p, new)
            rows.append(row)
    return plane, rows, len(chunks)


def verify_stage(record: dict, before: bytes | bytearray, modules: dict,
                 retained_guards: list, expected_source: str,
                 generation: int | None = None) -> dict:
    require(record.get("kind") == "native-stage", "Wrong native record kind")
    stage = obj(record.get("stage"), "native stage")
    stage_id = text(record.get("stage_id"), 128, "stage id")
    require(stage.get("id") == stage_id, "Record/stage identity differs", "identity")
    require(record.get("source_revision") == expected_source,
            "Native record source revision differs", "source")
    current_generation = integer(record.get("generation"), 1, 2147483647, "stage generation")
    if generation is not None:
        require(current_generation == generation, "World changed during the witness", "generation")
    require(record.get("stage_sha256") == inner_hash(stage), "Stage checksum differs", "stage-hash")
    for key in ("preview_sha256", "plan_sha256", "source_sha256", "expected_sha256",
                "result_sha256", "native_receipts_sha256"):
        identity(record.get(key), key)
    integer(record.get("native_submission"), 1, 9223372036854775807, "native submission")
    require(record.get("final_readback_available") is True, "Missing authoritative final native readback", "plane")
    region = rect(stage.get("region"), "stage region")
    require(sha(crop(before, region)) == record["source_sha256"],
            "Stage source hash differs from prior actual native World", "source")
    if "input_snapshot_sha256" in stage:
        require(stage["input_snapshot_sha256"] == record["source_sha256"],
                "Worker/recovery source pin is stale", "source-pin")
    if "input_generation" in stage:
        require("input_snapshot_sha256" in stage
                and integer(stage["input_generation"], 1, 2147483647, "pinned generation") == current_generation,
                "Worker/recovery generation pin is stale", "source-pin")
    projection = project_stage(stage, before, modules, retained_guards)
    require(sha(crop(projection["plane"], region)) == record["expected_sha256"],
            "Approved result does not match independent stage projection", "projection")
    require(record.get("resolved_modules", []) == projection["resolved_modules"],
            "Resolved native module identities differ", "module")
    budget = obj(record.get("budget"), "host budget")
    total = len(projection["changes"])
    for key, expected in (("checked_cells", total), ("changed_cells", total),
                          ("emitted_input_points", projection["emitted"]),
                          ("unique_cells", projection["unique"]),
                          ("conservative_scan_bound", projection["emitted"]),
                          ("limit", stage["budget"]["max_checked_cells"])):
        require(integer(budget.get(key), 0, MAX_RASTER, "host budget "+key) == expected,
                "Independent host resource count differs: "+key, "budget")
    receipts = seq(record.get("native_receipts"), MAX_RECEIPTS, "native receipts")
    require(inner_hash(receipts) == record["native_receipts_sha256"],
            "Native receipt checksum differs", "receipt-hash")
    after, rows, chunks = replay_receipts(receipts, before, region, current_generation,
                                         projection["changes"])
    count = len(rows)
    require(integer(record.get("checked_cells"), 0, 262144, "record checked") == count
            and integer(record.get("changed_cells"), 0, 262144, "record changed") == count,
            "Record counters differ from raw native rows", "record-counters")
    status = record.get("status")
    require(status in ("completed", "partial"), "Queued/refused/stopped claim is not final native evidence", "record-status")
    if status == "completed":
        require(count == total and record["result_sha256"] == record["expected_sha256"],
                "Completed record lacks every approved native change", "record-status")
    else:
        require(0 < count < total and record["result_sha256"] != record["expected_sha256"],
                "Partial record lacks a real, incomplete native prefix", "record-status")
    actual_bytes = decoded_plane(record.get("result_materials_base64"), region[2]*region[3]*2,
                                 "retained native plane")
    require(actual_bytes == crop(after, region) and sha(actual_bytes) == record["result_sha256"],
            "Retained final readback differs from receipt replay", "plane")
    for box in projection["clearances"]:
        require(all(cell(after, p) == 0 for p in points(box)), "Actual native clearance is blocked", "clearance")
    return {"record":record, "before":bytes(before), "after":after,
            "projection":projection, "rows":rows, "chunks":chunks,
            "generation":current_generation,
            "summary":{"stage_id":stage_id, "status":status, "region":list(region),
                "checked_cells":count, "receipt_chunks":chunks,
                "source_sha256":record["source_sha256"], "result_sha256":record["result_sha256"],
                "native_receipts_sha256":record["native_receipts_sha256"]}}


def flatten_campaign(campaign: dict) -> dict:
    require(campaign.get("format") == CAMPAIGN_FORMAT, "Wrong campaign format", "campaign")
    require(rect(campaign.get("region"), "campaign region") == WORLD, "Wrong campaign World", "campaign")
    nodes: dict[str, dict] = {}
    for raw in seq(campaign.get("nodes"), 64, "campaign nodes"):
        node = obj(raw, "campaign node")
        node_id = text(node.get("id"), 128, "node id")
        require(node_id not in nodes, "Duplicate campaign node", "campaign")
        rect(node.get("region"), "node region")
        nodes[node_id] = node
    leaves = [key for key, node in nodes.items() if node.get("kind") != "group"]
    require(1 <= len(leaves) <= 32, "Campaign has no bounded executable leaves", "campaign")
    ancestry = {}
    for key in nodes:
        chain, cursor = [], key
        while cursor:
            require(cursor in nodes and cursor not in chain and len(chain) < 4,
                    "Campaign ancestry invalid or cyclic", "campaign")
            chain.append(cursor)
            cursor = nodes[cursor].get("parent_id", "")
            text(cursor, 128, "parent id", empty=True)
        ancestry[key] = chain
    dependencies = {}
    for key in leaves:
        stage = obj(nodes[key].get("stage"), "campaign stage")
        require(stage.get("id") == key and stage.get("region") == nodes[key].get("region"),
                "Campaign/stage scope identity differs", "campaign")
        requested = list(seq(stage.get("depends_on", []), 32, "stage dependencies"))
        for ancestor in ancestry[key]:
            requested += seq(nodes[ancestor].get("depends_on", []), 64, "node dependencies")
        resolved = []
        for target in requested:
            require(type(target) is str and target in nodes, "Unknown dependency", "campaign")
            for leaf in leaves:
                if target in ancestry[leaf] and leaf not in resolved:
                    resolved.append(leaf)
        require(key not in resolved, "Self-dependent campaign", "campaign")
        dependencies[key] = resolved
    order = []
    while len(order) < len(leaves):
        previous = len(order)
        for key in leaves:
            if key not in order and all(dep in order for dep in dependencies[key]):
                order.append(key)
        require(len(order) > previous, "Campaign dependency cycle", "campaign")
    stages = []
    for key in order:
        stage = copy.deepcopy(nodes[key]["stage"])
        stage["depends_on"] = dependencies[key]
        stages.append(stage)
    return {"format":PLAN_FORMAT, "id":campaign["id"], "intent":campaign["intent"], "stages":stages}


def stage_map(plan: dict) -> dict:
    return {stage["id"]:stage for stage in plan["stages"]}


def campaign_contract(campaign: dict) -> dict:
    """Compare resolved contracts without inventing a different graph identity.

    Session revisions retain flattened stage dependencies. Campaign history
    retains the original node/ancestor dependencies and may leave the redundant
    stage-level list empty. Both must resolve to the exact same native plan.
    Every other campaign and node field remains byte-value equivalent here.
    """
    resolved = stage_map(flatten_campaign(campaign))
    result = copy.deepcopy(campaign)
    for node in result["nodes"]:
        if node.get("kind") != "group":
            node["stage"]["depends_on"] = resolved[node["id"]]["depends_on"]
    return result


def anchored_components(rows: list, before: bytes | bytearray) -> dict:
    remaining = {(row[0], row[1]) for row in rows if row[3] != 0 and row[2] == 0}
    component_count = 0
    unanchored = 0
    while remaining:
        component_count += 1
        start = remaining.pop()
        stack = [start]
        size, anchored = 0, False
        while stack:
            x, y = stack.pop()
            size += 1
            for p in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if not inside(p, WORLD):
                    continue
                anchored = anchored or cell(before, p) != 0
                if p in remaining:
                    remaining.remove(p)
                    stack.append(p)
        if not anchored:
            unanchored += size
    return {"new_components":component_count, "unanchored_new_cells":unanchored}


def attachment_cells(module: dict, origin: tuple[int, int]) -> set:
    result = set()
    for raw in seq(module.get("attachments", []), 128, "module attachments"):
        item = obj(raw, "module attachment")
        a = point(item.get("point"), "local attachment point")
        b = point(item.get("end", item.get("point")), "local attachment end")
        require(a[0] == b[0] or a[1] == b[1], "Non-axis attachment span", "module")
        for y in range(min(a[1],b[1]), max(a[1],b[1])+1):
            for x in range(min(a[0],b[0]), max(a[0],b[0])+1):
                result.add((origin[0]+x, origin[1]+y))
    require(len(result) <= 8192, "Module attachment capacity exceeded", "module")
    return result


def verify_workers(result: dict, views: dict, original: dict, modules: dict) -> list:
    workers = seq(result.get("delegated_workers"), 3, "delegated workers")
    require(len(workers) == 3, "Exactly three real code-owned workers are required", "workers")
    nodes = {node["id"]:node for node in original["nodes"]}
    output = []
    for worker, stage_id, kind, expected_count in zip(workers, WORKER_IDS, WORKER_KINDS, (144,64,8)):
        worker = obj(worker, "worker evidence")
        view = views[stage_id]
        record, stage, rows = view["record"], view["record"]["stage"], view["rows"]
        descriptor = obj(nodes[stage_id].get("delegation"), "original worker descriptor")
        require(descriptor.get("worker") == "procedural" and descriptor.get("job_kind") == kind,
                "Worker executor/kind differs from original finite contract", "workers")
        for worker_key, stage_key in (("descriptor_sha256", "delegation_descriptor_sha256"),
                                      ("worker_proposal_sha256", "delegation_worker_proposal_sha256")):
            require(identity(worker.get(worker_key), worker_key) == stage.get(stage_key),
                    "Retained worker identity differs from approved native stage", "workers")
        require(worker.get("stage_sha256") == record["stage_sha256"]
                and worker.get("source_sha256") == record["source_sha256"]
                and stage.get("input_snapshot_sha256") == record["source_sha256"]
                and stage.get("input_generation") == record["generation"],
                "Worker output is not pinned to its actual native source", "workers")
        require(integer(worker.get("native_cells"), 1, 16384, "worker native cells") == len(rows) == expected_count,
                "Worker native count differs", "workers")
        scan = integer(worker.get("scan_cells"), 1, MAX_RASTER, "worker reported scan cells")
        params = obj(descriptor.get("params"), "worker params")
        local = rect(params.get("region"), "worker local region", rect(stage["region"], "worker region"))
        require(len(rows) <= integer(params.get("max_cells"), 1, 16384, "worker declared cell ceiling")
                and all(inside((row[0],row[1]), local) and row[3] == params.get("material") for row in rows),
                "Worker changed cells escape its declared region/material/budget", "workers")
        metric = anchored_components(rows, view["before"])
        if stage_id != "controlled-wear":
            require(metric["unanchored_new_cells"] == 0 and all(row[2] == 0 for row in rows),
                    "Additive worker is not Empty-only and source-anchored", "workers")
        if stage_id == "service-connection":
            exact = {(x,y,0,28) for y in range(370,374) for x in range(400,416)}
            require(set(map(tuple, rows)) == exact, "Full-width service pipe differs", "workers")
            for x in (399,416):
                require(all(cell(view["before"], (x,y)) == cell(view["after"], (x,y)) == 28
                            for y in range(370,374)), "Pipe terminal faces changed or are unsupported", "workers")
            require(len(validate_connections(stage.get("connections", []), view["after"],
                                             rect(stage["region"], "pipe region"))) == 8,
                    "Full-width pipe lacks eight explicit terminal face contacts", "workers")
        if stage_id == "controlled-wear":
            known = modules["fractured-wall-transition"]
            document, origin = known["document"], (32,352)
            variable = shifted_boxes(document, "variation_regions", origin, known["extent"])
            fixed = shifted_boxes(document, "fixed_regions", origin, known["extent"])
            contacts = attachment_cells(document, origin)
            require(all(row[2:] == [58,0] and any(inside((row[0],row[1]), box) for box in variable)
                        and not any(inside((row[0],row[1]), box) for box in fixed)
                        and (row[0],row[1]) not in contacts for row in rows),
                    "Wear escaped authored expendable Hardwall or damaged fixed/contact material", "workers")
            require(crop(view["before"], (origin[0],origin[1],*known["extent"])) == known["cells"],
                    "Wear source is not the complete currently placed native part", "workers")
        output.append({"stage_id":stage_id, "kind":kind, "native_cells":len(rows),
                       "reported_worker_scan_cells":scan, **metric})
    return output


def attachment_contract() -> tuple[dict, set]:
    changes: dict[tuple[int,int], int] = {}
    contacts = set()
    pieces = [(64,144,8,16,58), (440,144,8,16,58)]
    pieces += [(x,168,8,16,28) for x in (88,112,136,360,384,408)]
    for x, y, width, height, material in pieces:
        for p in points((x,y,width,height)):
            changes[p] = material
        for px in range(x, x+width):
            contacts.add(("solid-contact", tuple(sorted(((px,y-1),(px,y))))))
            contacts.add(("solid-contact", tuple(sorted(((px,y+height-1),(px,y+height))))))
    return changes, contacts


def verify_recovery(views: dict, stopped: bytes, final: bytes, result: dict) -> dict:
    partial, cleanup = views["cladding-trial"], views["clear-stopped-prefix"]
    opening, attachment = views["open-workshop-bays"], views["attach-workshop-bays"]
    amount = len(partial["rows"])
    require(0 < amount < 61440
            and integer(result.get("partial_checked_cells"), 1, 61439, "reported Stop prefix") == amount,
            "Stop count is not the observed incomplete native prefix", "recovery")
    require(partial["record"]["status"] == "partial"
            and rect(partial["record"]["stage"]["region"], "trial region") == RECOVERY
            and len(partial["projection"]["changes"]) == 61440
            and all(row[2:] == [0,58] for row in partial["rows"]),
            "Stopped trial contract differs", "recovery")
    require(bytes(partial["after"]) == stopped, "Stopped full-World plane differs from native prefix", "recovery")
    expected_clear = sorted(([row[0],row[1],58,0] for row in partial["rows"]), key=lambda row:(row[1],row[0]))
    require(cleanup["rows"] == expected_clear and bytes(cleanup["before"]) == stopped
            and cleanup["record"]["stage"].get("input_snapshot_sha256") == sha(crop(stopped, RECOVERY))
            and all(cell(cleanup["after"], p) == 0 for p in points(RECOVERY)),
            "Fresh recovery did not clear exactly the actual stopped prefix", "recovery")
    require(opening["record"]["status"] == "completed"
            and rect(opening["record"]["stage"]["region"], "open-bays region") == RECOVERY,
            "Open-bay recovery changed scope or lacks completion", "recovery")
    expected, expected_contacts = attachment_contract()
    stage = attachment["record"]["stage"]
    require(stage.get("id") == "attach-workshop-bays"
            and rect(stage.get("region"), "attachment region") == ATTACHMENT_REGION
            and stage.get("depends_on") == ["open-workshop-bays"]
            and set(stage.get("materials", [])) == {28,58}
            and stage.get("budget", {}).get("max_checked_cells") == 1024
            and len(stage.get("operations", [])) == 8,
            "Final approved attachment stage does not have its exact finite contract", "attachment")
    require(len(attachment["rows"]) == 1024
            and {(row[0],row[1]):row[3] for row in attachment["rows"]} == expected
            and all(row[2] == 0 for row in attachment["rows"]),
            "Attachment native rows differ from the eight approved Empty-only pieces", "attachment")
    actual_contacts = validate_connections(stage.get("connections"), attachment["after"], ATTACHMENT_REGION)
    require(len(stage["connections"]) == 128 and actual_contacts == expected_contacts,
            "Attachment stage lacks the exact 128 full-face solid-contact requirements", "attachment")
    for _, endpoints in expected_contacts:
        outside_piece = [p for p in endpoints if p not in expected]
        require(len(outside_piece) == 1 and cell(attachment["before"], outside_piece[0]) != 0,
                "Attachment contact has no prior actual native face", "attachment")
    allowed_outside = {p:material for p, material in expected.items() if not inside(p, RECOVERY)}
    require(len(allowed_outside) == 256 and set(allowed_outside.values()) == {58},
            "Outside-recovery allowance is not exactly the two hangers", "attachment")
    changed_outside = {}
    for p in points(WORLD):
        if not inside(p, RECOVERY) and cell(stopped,p) != cell(final,p):
            changed_outside[p] = cell(final,p)
    require(changed_outside == allowed_outside
            and all(cell(stopped,p) == 0 for p in allowed_outside),
            "Recovery altered cells outside the exact declared 256-cell exception", "recovery")
    require(result.get("preserved_outside_recovery_except_declared_attachments") is True
            and integer(result.get("approved_outside_recovery_cells"), 0, 262144,
                        "approved outside-recovery cells") == 256,
            "Legacy or incomplete recovery preservation claim cannot qualify the final contract", "recovery")
    require(all(cell(final,p) == 0 for p in points(PASSAGE))
            and result.get("protected_passage_empty") is True,
            "Protected passage is not actually Empty", "clearance")
    return {"partial_checked_cells":amount, "cleared_exact_native_prefix":True,
            "attachment_cells":1024, "solid_contact_requirements":128,
            "approved_outside_recovery_cells":256,
            "all_other_outside_cells_preserved":True, "protected_passage_empty":True,
            "prefix_authority":"Actual changed-only native rows in approved order; elapsed timing unused."}


def verify_campaign_history(history: dict, campaign: dict, records: list[dict],
                            completed: bool) -> None:
    require(history.get("format") == HISTORY_FORMAT
            and campaign_contract(obj(history.get("campaign"), "historical campaign"))
            == campaign_contract(campaign),
            "Retained campaign differs from the actual revised contract", "history")
    decisions = seq(history.get("decisions"), 256, "campaign decisions")
    admissions = [row for row in decisions if type(row) is dict and row.get("kind") == "owner-approved-native-admission"]
    terminals = [row for row in decisions if type(row) is dict and row.get("kind") == "native-terminal"]
    expected_ids = [record["stage_id"] for record in records]
    require([row.get("job_id") for row in admissions] == expected_ids
            and [row.get("job_id") for row in terminals] == expected_ids,
            "Campaign admissions/terminals omit, duplicate or invent native stages", "history")
    saved = obj(history.get("evidence_at_save"), "saved campaign evidence")
    require(set(saved) == set(expected_ids), "Saved campaign native evidence denominator differs", "history")
    for record, admission, terminal in zip(records, admissions, terminals):
        require(decisions.index(admission) < decisions.index(terminal),
                "Campaign terminal precedes admission", "history")
        evidence = obj(terminal.get("evidence"), "native terminal evidence")
        require(evidence == saved[record["stage_id"]], "Terminal and saved evidence differ", "history")
        for field in ("status","generation","preview_sha256","source_sha256","result_sha256","native_receipts_sha256"):
            require(evidence.get(field) == record.get(field), "Campaign terminal does not match native "+field, "history")
        require(evidence.get("native_checked_cells") == record["checked_cells"]
                and evidence.get("native_receipt_chunks") == len(record["native_receipts"])
                and admission.get("preview_sha256") == record["preview_sha256"],
                "Campaign receipt/preview accounting differs", "history")
        submitted = obj(admission.get("submission"), "native admission submission")
        require(type(submitted.get("sequence")) is int and submitted["sequence"] == record["native_submission"]
                and evidence.get("submission") == submitted,
                "Campaign submission identity differs from native record", "history")
    native = sum(record["checked_cells"] for record in records)
    raster = sum(record["budget"]["conservative_scan_bound"] for record in records)
    require(integer(history.get("used_native_checks"), 0, 4194304, "campaign native cost") == native
            and integer(history.get("used_raster_candidates"), 0, 16777216, "campaign raster cost") == raster
            and native <= campaign["budget"]["native_checks"]
            and raster <= campaign["budget"]["raster_candidates"],
            "Campaign cumulative resource accounting differs", "history")
    if completed:
        states = obj(history.get("states_at_save"), "saved campaign states")
        require(set(states) == set(expected_ids) and all(state == "completed" for state in states.values()),
                "Recovery campaign retains an incomplete leaf", "history")
    else:
        require(any(row.get("kind") == "owner-skip" and row.get("job_id") == "optional-screen"
                    for row in decisions if type(row) is dict)
                and any(row.get("kind") == "host-preview-refusal" and row.get("job_id") == "access-gallery"
                        for row in decisions if type(row) is dict),
                "Original campaign lost explicit Skip/refusal decisions", "history")


def verify_owner_decisions(result: dict, views: dict) -> None:
    decisions = seq(result.get("owner_decisions"), 32, "harness owner decisions")
    approvals = [row for row in decisions if type(row) is dict and row.get("kind") == "harness-owner-approve"]
    expected = [key for key in NATIVE_ORDER if key != "cladding-trial"]
    require([row.get("stage_id") for row in approvals] == expected,
            "Harness approval list does not identify every completed native stage", "decision")
    for row in approvals:
        require(row.get("preview_sha256") == views[row["stage_id"]]["record"]["preview_sha256"],
                "Harness approval refers to a different projection", "decision")
    skips = [row for row in decisions if type(row) is dict and row.get("kind") == "harness-owner-skip"]
    refusals = [row for row in decisions if type(row) is dict and row.get("kind") == "native-preview-refusal"]
    stops = [row for row in decisions if type(row) is dict and row.get("kind") == "harness-owner-stop"]
    require(len(skips) == len(refusals) == len(stops) == 1
            and skips[0].get("stage_id") == "optional-screen"
            and refusals[0].get("stage_id") == "access-gallery"
            and stops[0].get("stage_id") == "cladding-trial"
            and stops[0].get("checked_cells") == len(views["cladding-trial"]["rows"])
            and stops[0].get("result_sha256") == views["cladding-trial"]["record"]["result_sha256"],
            "Retained Skip, refusal or actual Stop identity differs", "decision")
    require(len(decisions) == len(approvals)+3, "Unexpected unaccounted owner decision", "decision")


def verify(manifest_path: Path, expected_source: str, require_default_capacity: bool = False) -> dict:
    expected_source = identity(expected_source, "externally expected source", 40)
    manifest_path = manifest_path.resolve(strict=True)
    custody = Custody(manifest_path.parent)
    manifest = custody.json(manifest_path.name)
    require(manifest.get("format") == WITNESS_FORMAT, "Wrong native hierarchy witness format", "manifest")
    require(manifest.get("source_revision") == expected_source, "Manifest source revision differs", "source")
    require(integer(manifest.get("failures"), 0, 100000, "harness failures") == 0
            and integer(manifest.get("checks"), 1, 100000, "harness checks") > 0,
            "Harness did not complete its native assertions", "manifest")
    capacity = integer(manifest.get("core_capacity"), 1, 1024, "native active core capacity")
    require(not require_default_capacity or capacity == 1024,
            "Default1024 qualification requires an unset development override", "runtime")
    require(integer(manifest.get("real_model_calls"), 0, 0, "real model calls") == 0,
            "This witness does not establish model-dependent results", "scope")
    require(manifest.get("platform") in ("Linux","Windows")
            and text(manifest.get("godot"), 128, "Godot runtime").startswith("4.7"),
            "Witness runtime/platform differs from pinned qualification", "runtime")
    result = obj(manifest.get("result"), "native result")
    require(result.get("extent") == [512,512] and result.get("final_campaign_state") == "completed",
            "Incomplete or incorrectly sized final hierarchy result", "manifest")
    # Refuse the old development witness before inspecting costly receipt data.
    require(result.get("preserved_outside_recovery_except_declared_attachments") is True
            and type(result.get("approved_outside_recovery_cells")) is int
            and result["approved_outside_recovery_cells"] == 256,
            "Final eight-piece attachment recovery contract is absent; the earlier development run is not this final witness.",
            "legacy-final-contract")
    for field, required_name in (("plane","workshop.u16le"),("stopped_plane","stopped-workshop.u16le"),
                                 ("start","workshop-start.json")):
        require(result.get(field) == required_name, "Unexpected canonical "+field+" artifact", "path")
    final = custody.read(result["plane"], WORLD_BYTES, result.get("plane_sha256"))
    stopped_plane = custody.read(result["stopped_plane"], WORLD_BYTES, result.get("stopped_plane_sha256"))
    require(len(final) == len(stopped_plane) == WORLD_BYTES, "Full-World native plane length differs", "plane")
    strict_json(custody.read(result["start"], MAX_JSON_BYTES, result.get("start_sha256")), "ordinary start")
    original = custody.json("original-campaign.json")
    recovery = custody.json("recovery-campaign.json")
    stopped = custody.json("stopped-session.json")
    session = custody.json("workshop-session.json")
    workflow = custody.json("workshop-workflow.json")
    modules = module_library(custody.json("workshop-modules.json"))
    require(session.get("format") == "cybersand-architecture-session-v1",
            "Unsupported native session envelope", "session")
    require(not session.get("imported_history", []), "Current witness contains imported session authority", "session")
    records = seq(session.get("records"), MAX_RECORDS, "session records")
    initial = seq(stopped.get("records"), MAX_RECORDS, "stopped records")
    require(records[:len(initial)] == initial
            and len(initial) == integer(result.get("original_records"), 1, MAX_RECORDS, "original record count")
            and len(records) == integer(result.get("all_records"), 1, MAX_RECORDS, "all record count"),
            "Stopped history was altered or record denominator changed", "session")
    native = [row for row in records if type(row) is dict and row.get("kind") == "native-stage"]
    require([row.get("stage_id") for row in native] == NATIVE_ORDER,
            "Exact native-stage denominator/order differs, including final attachments", "session")
    require([row.get("stage_id") for row in initial if row.get("kind") == "native-stage"] == NATIVE_ORDER[:7],
            "Stopped history does not end at the actual partial native stage", "session")
    current = copy.deepcopy(original)
    initial_revised = None
    plan = flatten_campaign(current)
    world = bytearray(WORLD_BYTES)
    guards: list = []
    generation = None
    views: dict = {}
    seen_revisions: list[str] = []
    seen_skip = seen_refusal = False
    total_rows = total_chunks = 0
    completed: set[str] = set()
    for index, raw in enumerate(records):
        record = obj(raw, "session record")
        if index == len(initial):
            initial_revised = copy.deepcopy(current)
            current = copy.deepcopy(recovery)
            plan = flatten_campaign(current)
            completed.clear()
        stage_id = record.get("stage_id")
        active_stages = stage_map(plan)
        require(stage_id in active_stages, "Record names a stage outside current campaign", "session")
        kind = record.get("kind")
        if kind == "native-stage":
            require(record["stage"] == active_stages[stage_id]
                    and record.get("plan_id") == plan["id"]
                    and record.get("plan_sha256") == inner_hash(plan),
                    "Native record differs from actual campaign revision/plan", "plan-hash")
            require(all(dep in completed for dep in record["stage"].get("depends_on", [])),
                    "Native stage ran before a completed prerequisite", "dependency")
            view = verify_stage(record, world, modules, guards, expected_source, generation)
            if generation is None:
                generation = view["generation"]
            total_rows += len(view["rows"])
            total_chunks += view["chunks"]
            require(total_rows <= MAX_TOTAL_ROWS and total_chunks <= 1024,
                    "Aggregate native evidence capacity exceeded", "receipt-bound")
            views[stage_id] = view
            world = view["after"]
            if record["status"] == "completed":
                completed.add(stage_id)
                for box in view["projection"]["new_guards"]:
                    if box not in guards:
                        guards.append(box)
            else:
                require(stage_id == "cladding-trial" and index == len(initial)-1,
                        "An unexpected task was partial", "record-status")
        elif kind == "revision":
            require(stage_id in ("access-gallery",*WORKER_IDS) and stage_id not in seen_revisions
                    and record.get("previous_stage") == active_stages[stage_id],
                    "Revision lost its actual preceding contract", "decision")
            replacement = obj(record.get("replacement"), "replacement stage")
            require(replacement.get("id") == stage_id
                    and replacement.get("region") == active_stages[stage_id]["region"],
                    "Revision changed task identity/scope", "decision")
            for node in current["nodes"]:
                if node["id"] == stage_id:
                    node["stage"] = copy.deepcopy(replacement)
            plan = flatten_campaign(current)
            seen_revisions.append(stage_id)
        elif kind == "decision":
            require(not seen_skip and stage_id == "optional-screen"
                    and record.get("status") == "skipped" and record.get("zero_writes") is True,
                    "Unexpected or falsely native Skip decision", "decision")
            seen_skip = True
        elif kind == "preview-refusal":
            require(not seen_refusal and stage_id == "access-gallery"
                    and record.get("zero_writes") is True, "Unexpected preview refusal", "decision")
            try:
                project_stage(active_stages[stage_id], world, modules, guards)
            except Violation as refusal:
                require(refusal.code == "clearance", "Initial gallery refused for an unexpected independent reason", "decision")
            else:
                raise Violation("Recorded gallery refusal was not reproduced by clearance geometry", "decision")
            seen_refusal = True
        else:
            raise Violation("Unknown session record kind", "session")
    require(seen_revisions == ["access-gallery",*WORKER_IDS] and seen_skip and seen_refusal
            and initial_revised is not None, "Decision/revision history is incomplete", "decision")
    require(bytes(world) == final, "Final whole-World readback differs from every retained native row", "plane")
    require(session.get("plan") == plan and session.get("plan_sha256") == inner_hash(plan),
            "Saved final plan differs", "plan-hash")
    require(session.get("states") == {key:"completed" for key in NATIVE_ORDER[7:]},
            "Saved final session states are not all completed", "session")
    selected = views["service-parts"]["record"]["stage"]["modules"]
    require(len(selected) == 3, "Service assembly does not use exactly three curated parts", "module")
    for selection in selected:
        instance = selection.get("instance_id")
        require(instance in MODULE_INSTANCES, "Unexpected service part instance", "module")
        module_id, origin = MODULE_INSTANCES[instance]
        require(selection.get("module_id") == module_id
                and selection["placement"].get("origin") == list(origin),
                "Native module assembly changed identity or placement", "module")
        known = modules[module_id]
        require(crop(views["service-parts"]["after"], (*origin,*known["extent"])) == known["cells"],
                "Native identity placement is not byte-exact for "+module_id, "module")
    worker_summary = verify_workers(result, views, original, modules)
    recovery_summary = verify_recovery(views, stopped_plane, final, result)
    verify_owner_decisions(result, views)
    priors = seq(workflow.get("prior_campaigns"), 8, "prior campaigns")
    require(len(priors) == integer(result.get("prior_campaigns"), 1, 1, "prior campaign count") == 1,
            "Earlier decisions were not retained exactly once", "history")
    prior = obj(priors[0], "prior campaign")
    require(prior.get("source_revision") == expected_source, "Prior history source differs", "source")
    identity(prior.get("sha256"), "producer archive checksum")
    original_history = obj(prior.get("history"), "prior history")
    stopped_workflow = obj(stopped.get("workflow"), "stopped workflow")
    require(stopped_workflow.get("campaign") == original_history,
            "Archived original campaign differs from retained stopped history", "history")
    verify_campaign_history(original_history, initial_revised, native[:7], False)
    verify_campaign_history(obj(workflow.get("campaign"), "final campaign history"), current, native[7:], True)
    return {
        "format":FORMAT, "status":"PASS", "errors":[],
        "source_revision":expected_source, "manifest_sha256":custody.files[0]["sha256"],
        "runtime":{"godot":manifest["godot"], "platform":manifest["platform"],
                   "native_active_core_capacity":capacity, "default_capacity_required":require_default_capacity},
        "counts":{"session_records":len(records), "original_records":len(initial),
                  "native_stages":len(native), "native_receipt_chunks":total_chunks,
                  "checked_native_cells":total_rows, "workers":3, "model_calls":0},
        "stages":[views[key]["summary"] for key in NATIVE_ORDER],
        "workers":worker_summary, "recovery":recovery_summary,
        "native_modules":{"identity_placements":3, "complete_crop_equality":True,
                          "imported_documents_grant_current_authority":False},
        "final_plane_sha256":sha(final), "stopped_plane_sha256":sha(stopped_plane),
        "files":custody.files,
        "scope":{
            "actual_static_native_receipts_and_material_readback":True,
            "independent_approved_projection_and_receipt_replay":True,
            "owner_decisions":"Harness choices; physical owner acceptance remains separate.",
            "current_session_authority":False, "owner_acceptance":False,
            "gameplay_or_physical_stability":False, "fresh_process_reopen":False,
            "graphical_qualification":False,
            "inner_hashes":"Integer-valued stage, plan, receipt and selected-module identities verified. "
                           "Decimal-containing archive/worker metadata is bound by complete raw file SHA-256 "
                           "and cross-record values; its producer canonical checksum is not independently recomputed.",
            "custody":"External qualification must bind these exact artifacts to the source and native runtime. "
                      "Self-consistent JSON/hashes are not cryptographic runtime attestation."
        }
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--require-default-capacity", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        report = verify(args.manifest, args.expected_source, args.require_default_capacity)
    except (Violation, OSError, ValueError, TypeError, KeyError, RecursionError) as error:
        report = {"format":FORMAT, "status":"FAIL", "source_revision":args.expected_source,
                  "errors":[{"code":getattr(error, "code", "input-error"), "reason":str(error)}],
                  "scope":{"current_session_authority":False, "owner_acceptance":False}}
    if args.output:
        destination = args.output.resolve()
        # Do not let a mistaken output path overwrite any retained input artifact.
        protected_names = {"hierarchy-native.json","original-campaign.json","recovery-campaign.json",
                           "stopped-session.json","workshop-session.json","workshop-workflow.json",
                           "workshop-modules.json","workshop-start.json","workshop.u16le","stopped-workshop.u16le"}
        require(destination != args.manifest.resolve()
                and not (destination.parent == args.manifest.resolve().parent
                         and destination.name in protected_names),
                "Output would overwrite retained native evidence", "output-path")
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(report, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("HIERARCHY_NATIVE_VERIFICATION_RESULT " + json.dumps(report, sort_keys=True, separators=(",",":")))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
