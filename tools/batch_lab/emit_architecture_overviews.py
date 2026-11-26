#!/usr/bin/env python3
"""Transport at most four already-generated native overview PNGs through CI logs.

This is read-only byte transport, not rendering, image editing or qualification.
Only fixed whole-view names in successful same-source native/render reports are
eligible. Oversized captures remain in the normal artifact and are not altered.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
import zlib

FAMILIES = {"orbital-fabrication": (1024, 1024), "terraced-arcology": (1024, 1024),
            "monumental-viaduct": (1536, 768), "biomechanical-vault": (1024, 768)}
MAX_IMAGE_BYTES = 512 * 1024
MAX_TOTAL_IMAGE_BYTES = 2 * 1024 * 1024
MAX_REPORT_BYTES = 1024 * 1024
CHUNK_CHARACTERS = 16 * 1024
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def read_fixed(root: Path, name: str, limit: int) -> bytes:
    require(isinstance(name, str) and Path(name).name == name, "Only a fixed local evidence basename is permitted")
    path = root / name
    require(not path.is_symlink() and path.is_file() and path.resolve().parent == root,
            "Missing, linked or out-of-directory evidence: " + name)
    require(path.stat().st_size <= limit, "Evidence exceeds its read bound: " + name)
    raw = path.read_bytes()
    require(len(raw) <= limit, "Evidence grew beyond its read bound: " + name)
    return raw


def document(root: Path, name: str, source: str, schema: str) -> tuple[dict, str]:
    raw = read_fixed(root, name, MAX_REPORT_BYTES)
    value = json.loads(raw)
    require(isinstance(value, dict) and value.get("format") == schema
            and value.get("source_revision") == source, "Report source or schema mismatch: " + name)
    require(type(value.get("checks")) is int and value["checks"] > 0
            and type(value.get("failures")) is int and value["failures"] == 0
            and value.get("passed", True) is True, "Report is not a completed successful capture source: " + name)
    return value, digest(raw)


def png_dimensions(raw: bytes) -> tuple[int, int]:
    require(raw.startswith(PNG_SIGNATURE), "Reported capture is not a PNG")
    cursor, dimensions, idat, ended = 8, None, False, False
    while cursor + 12 <= len(raw):
        size = struct.unpack(">I", raw[cursor:cursor + 4])[0]
        end = cursor + 12 + size
        require(end <= len(raw), "PNG chunk exceeds retained file bytes")
        kind = raw[cursor + 4:cursor + 8]
        body = raw[cursor + 8:cursor + 8 + size]
        checksum = struct.unpack(">I", raw[cursor + 8 + size:end])[0]
        require(zlib.crc32(kind + body) & 0xffffffff == checksum, "PNG chunk CRC differs")
        if cursor == 8:
            require(kind == b"IHDR" and size == 13, "PNG must start with its exact IHDR")
            dimensions = struct.unpack(">II", body[:8])
        elif kind == b"IHDR":
            raise ValueError("Repeated PNG header")
        if kind == b"IDAT":
            idat = True
        if kind == b"IEND":
            require(size == 0 and end == len(raw), "PNG end chunk or trailing bytes differ")
            ended = True
            break
        cursor = end
    require(dimensions is not None and idat and ended, "PNG lacks a complete image stream")
    return dimensions


def collect(root: Path, source: str) -> tuple[list[tuple[dict, bytes]], dict]:
    require(bool(re.fullmatch(r"[0-9a-f]{40}", source)), "Exact forty-character source revision required")
    root = root.resolve()
    require(root.is_dir(), "Existing flagship evidence directory required")
    native, native_report_sha = document(root, "flagships-native.json", source,
                                         "cybersand-native-flagship-campaign-v1")
    rendered, render_report_sha = document(root, "flagships-render.json", source,
                                           "cybersand-native-flagship-renders-v1")
    require(rendered.get("native_source_revision") == source
            and rendered.get("display") not in (None, "", "headless"), "Actual same-source graphical report required")
    examples, rows = native.get("examples"), rendered.get("renders")
    require(isinstance(examples, list) and len(examples) == 4
            and all(isinstance(row, dict) for row in examples)
            and {row.get("id") for row in examples} == set(FAMILIES), "Exact four-family native manifest required")
    require(isinstance(rows, list) and len(rows) == 12 and all(isinstance(row, dict) for row in rows),
            "Complete generated render cohort required")
    whole = [row for row in rows if row.get("view") == "whole"]
    require(len(whole) == 4 and {row.get("id") for row in whole} == set(FAMILIES),
            "Exactly one report-listed whole view per family is required")
    images, omissions, total = [], [], 0
    for family, extent in FAMILIES.items():
        native_row = next(row for row in examples if row["id"] == family)
        row = next(row for row in whole if row["id"] == family)
        name = family + "-whole-godot.png"
        require(native_row.get("plane") == family + ".u16le" and native_row.get("extent") == list(extent)
                and native_row.get("all_tasks_completed") is True, "Native family identity or completion differs")
        plane = read_fixed(root, family + ".u16le", extent[0] * extent[1] * 2)
        require(len(plane) == extent[0] * extent[1] * 2 and digest(plane) == native_row.get("sha256"),
                "Actual native plane differs from its reported identity")
        require(row.get("image") == name and row.get("kind") == "godot-rendered-native-material-plane"
                and row.get("native_source_revision") == source and row.get("native_material_sha256") == native_row["sha256"]
                and row.get("pixels") == list(extent) and row.get("region") == [0, 0, *extent],
                "Overview is not the exact whole-frame native report entry")
        expected = row.get("image_sha256")
        require(isinstance(expected, str) and bool(re.fullmatch(r"[0-9a-f]{64}", expected)), "Capture lacks its exact PNG digest")
        path = root / name
        require(path.is_file() and not path.is_symlink() and path.resolve().parent == root, "Missing or linked overview capture")
        size = path.stat().st_size
        if size > MAX_IMAGE_BYTES or total + size > MAX_TOTAL_IMAGE_BYTES:
            omissions.append({"id": family, "image": name, "bytes": size, "reported_image_sha256": expected,
                              "reason": "Unmodified capture exceeds bounded log transport; use the original artifact."})
            continue
        raw = read_fixed(root, name, MAX_IMAGE_BYTES)
        require(digest(raw) == expected and png_dimensions(raw) == extent, "Actual PNG identity or dimensions differ")
        total += len(raw)
        metadata = {"format": "cybersand-native-overview-log-v1", "id": family, "view": "whole",
                    "source_revision": source, "native_source_revision": source, "image": name,
                    "image_sha256": expected, "native_material_sha256": native_row["sha256"],
                    "render_report_sha256": render_report_sha, "native_report_sha256": native_report_sha,
                    "pixels": list(extent), "bytes": len(raw), "mime_type": "image/png",
                    "scope": "Original source-bound Godot framebuffer bytes; no physical or owner acceptance inferred."}
        images.append((metadata, raw))
    return images, {"passed": True, "checks": 4, "failures": [], "source_revision": source,
                    "emitted_images": len(images), "emitted_image_bytes": total,
                    "image_byte_limit": MAX_IMAGE_BYTES, "total_image_byte_limit": MAX_TOTAL_IMAGE_BYTES,
                    "omitted": omissions, "scope": "Bounded read-only log transport; omitted images remain in normal artifacts."}


def emit(root: Path, source: str, stream=None) -> dict:
    stream = sys.stdout if stream is None else stream
    # Validate every eligible file before emitting any image bytes.
    images, report = collect(root, source)
    for metadata, raw in images:
        encoded = base64.b64encode(raw).decode("ascii")
        count = (len(encoded) + CHUNK_CHARACTERS - 1) // CHUNK_CHARACTERS
        header = dict(metadata, chunks=count)
        print("ARCHITECTURE_OVERVIEW_PNG " + json.dumps(header, separators=(",", ":"), sort_keys=True), file=stream)
        for index in range(count):
            chunk = {"id": metadata["id"], "image_sha256": metadata["image_sha256"], "index": index, "count": count,
                     "base64": encoded[index * CHUNK_CHARACTERS:(index + 1) * CHUNK_CHARACTERS]}
            print("ARCHITECTURE_OVERVIEW_PNG_CHUNK " + json.dumps(chunk, separators=(",", ":"), sort_keys=True), file=stream)
    print("ARCHITECTURE_OVERVIEW_TRANSPORT " + json.dumps(report, separators=(",", ":"), sort_keys=True), file=stream, flush=True)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--source", required=True)
    args = parser.parse_args()
    emit(args.evidence, args.source)


if __name__ == "__main__":
    main()
