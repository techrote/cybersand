#!/usr/bin/env python3
"""Read-only independent custody/replay check of recorded Art native evidence.

Uses only Python's standard library. It does not run Godot, issue model/network
requests, execute a proposal, or extract an archive to disk. It replays ORIGINAL
native readback rows onto the captured native material PNG plane, then compares
every stage and final plane. No Art rasterizer or fixture generator is imported.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import tarfile
import zlib

IDS = (
    "industrial_repair", "structural_facade", "scifi_interior", "revised_arcology",
    "protected_courtyard", "palette_foundry", "stopped_workshop", "staged_megaframe", "xeno_vault",
)
SOURCE_KEYS = ("generation", "revision", "tick", "authoring_generation")
COUNTERS = ("requested", "checked", "changed", "unchanged", "excluded", "refused", "confirmed")
CASE = "test_art_collaborative_native"
MAX_FILE_BYTES = 16 * 1024 * 1024
MAX_CELLS = 262144


def require(value: bool, label: str) -> None:
    if not value:
        raise ValueError(label)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def source(value: dict) -> dict:
    require(isinstance(value, dict), "Native source is not an object")
    result = {key: value.get(key) for key in SOURCE_KEYS}
    require(all(type(v) is int and v >= 0 for v in result.values()) and result["authoring_generation"] >= 1,
            "Incomplete native source identity")
    return result


def plane_digest(plane: bytes | bytearray) -> str:
    # Captured PackedInt32Array.to_byte_array() on the qualified x86_64 runtimes.
    # Each material byte becomes an explicit little-endian uint32 without
    # depending on this verification machine's native integer byte order.
    encoded = bytearray(len(plane) * 4)
    encoded[::4] = plane
    return digest(encoded)


def native_png(data: bytes, width: int, height: int) -> bytearray:
    """Decode bounded, noninterlaced 8-bit native material PNG bytes.

    Godot R8 diagnostics may use grayscale or RGB containers. The material is
    the unchanged first/red channel; full native plane hashes prove its identity.
    This function is never used to infer materials from a rendered framebuffer.
    """
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), "Invalid native PNG signature")
    pos, header, palette, packed, ended = 8, None, b"", bytearray(), False
    while pos < len(data):
        require(pos + 12 <= len(data), "Truncated PNG chunk")
        length = int.from_bytes(data[pos:pos+4], "big")
        kind = data[pos+4:pos+8]
        end = pos + 8 + length
        require(end + 4 <= len(data), "PNG chunk exceeds original file")
        payload = data[pos+8:end]
        crc = int.from_bytes(data[end:end+4], "big")
        require((zlib.crc32(kind + payload) & 0xFFFFFFFF) == crc, "PNG chunk CRC mismatch")
        pos = end + 4
        if kind == b"IHDR":
            require(header is None and length == 13, "Invalid duplicate PNG header")
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"PLTE":
            palette = payload
        elif kind == b"IDAT":
            packed.extend(payload)
        elif kind == b"IEND":
            require(length == 0, "Invalid PNG end")
            ended = True
            break
    require(ended and pos == len(data) and header is not None, "Incomplete PNG custody")
    w, h, depth, color, compression, filtering, interlace = header
    require((w, h) == (width, height) and 0 < w*h <= MAX_CELLS, "Native PNG dimensions differ from capture")
    require(depth == 8 and compression == 0 and filtering == 0 and interlace == 0,
            "Native diagnostic must be noninterlaced 8-bit PNG")
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color)
    require(channels is not None, "Unsupported native PNG color container")
    stride = w * channels
    expected = h * (stride + 1)
    decompressor = zlib.decompressobj()
    raw = decompressor.decompress(bytes(packed), expected + 1)
    require(len(raw) == expected and decompressor.eof and not decompressor.unconsumed_tail
            and not decompressor.unused_data, "PNG inflation differs from bounded image dimensions")
    result = bytearray(w*h)
    previous = bytearray(stride)
    offset = 0
    for y in range(h):
        mode = raw[offset]
        current = bytearray(raw[offset+1:offset+1+stride])
        offset += stride + 1
        require(mode in (0, 1, 2, 3, 4), "Invalid PNG row filter")
        for x in range(stride):
            left = current[x-channels] if x >= channels else 0
            up = previous[x]
            upper_left = previous[x-channels] if x >= channels else 0
            if mode == 1:
                predictor = left
            elif mode == 2:
                predictor = up
            elif mode == 3:
                predictor = (left + up) // 2
            elif mode == 4:
                estimate = left + up - upper_left
                a, b, c = abs(estimate-left), abs(estimate-up), abs(estimate-upper_left)
                predictor = left if a <= b and a <= c else up if b <= c else upper_left
            else:
                predictor = 0
            current[x] = (current[x] + predictor) & 255
        for x in range(w):
            value = current[x*channels]
            if color == 3:
                require(value*3+2 < len(palette), "Native PNG palette index is absent")
                value = palette[value*3]
            result[y*w+x] = value
        previous = current
    return result


class Evidence:
    def __init__(self, location: Path):
        self.location = location
        self.archive = None
        self.members = {}
        self.prefix = ""
        if not location.is_dir():
            self.archive = tarfile.open(location, "r:gz")
            for member in self.archive.getmembers():
                normalized = PurePosixPath(member.name)
                require(not normalized.is_absolute() and ".." not in normalized.parts
                        and "\\" not in member.name, "Unsafe archive member name")
                name = str(normalized)
                require(name not in self.members, "Duplicate archive member name")
                self.members[name] = member
            roots = []
            for name in self.members:
                if name == "summary.json" or name.endswith("/summary.json"):
                    prefix = name[:-len("summary.json")]
                    if prefix + CASE + "/process.log" in self.members:
                        roots.append(prefix)
            require(len(roots) == 1, "Archive does not contain one complete native campaign root")
            self.prefix = roots[0]

    def read(self, relative: str) -> bytes:
        parts = PurePosixPath(relative)
        require(not parts.is_absolute() and ".." not in parts.parts, "Unsafe evidence path")
        if self.archive is None:
            path = self.location / relative
            require(path.is_file() and not path.is_symlink(), "Missing or aliased original file: " + relative)
            require(path.stat().st_size <= MAX_FILE_BYTES, "Original file exceeds bounded verifier capacity")
            value = path.read_bytes()
        else:
            member = self.members.get(self.prefix + relative)
            require(member is not None and member.isfile() and member.size <= MAX_FILE_BYTES,
                    "Missing, linked or oversized archive original: " + relative)
            handle = self.archive.extractfile(member)
            require(handle is not None, "Archive original cannot be read")
            value = handle.read(MAX_FILE_BYTES+1)
        require(len(value) <= MAX_FILE_BYTES, "Original file exceeds bounded verifier capacity")
        return value

    def json(self, relative: str):
        return json.loads(self.read(relative).decode("utf-8"))


def replay(receipts: list, initial: bytearray, region: list, expected: dict,
           stage_predictions: list | None, index_record: dict | None) -> tuple[bytearray, dict]:
    require(isinstance(receipts, list) and receipts, "Original native receipts are missing")
    x0, y0, width, height = region
    require(all(type(v) is int for v in region) and len(initial) == width*height,
            "Receipt scope does not match native plane")
    plane = bytearray(initial)
    totals = {key: 0 for key in COUNTERS}
    previous = None
    stage_index = 0
    stage_requested = 0
    stage_changed = 0
    verified_rows = 0
    require(stage_predictions is None or bool(stage_predictions), "Missing stage predictions")
    if stage_predictions is not None:
        require(plane_digest(plane) == stage_predictions[0]["before_materials_sha256"], "First stage source plane differs")
    for number, receipt in enumerate(receipts):
        require(isinstance(receipt, dict) and receipt.get("backend") == "CyberNativeCellWorld"
                and receipt.get("status") == "completed" and receipt.get("reason", "") == "",
                "Original receipt is not completed native work")
        require(all(type(receipt.get(key)) is int and receipt[key] >= 0 for key in COUNTERS),
                "Original receipt has invalid counters")
        before_source, after_source = source(receipt["before_source"]), source(receipt)
        if previous is not None:
            require(before_source == previous, "Native receipt source chain is discontinuous")
        require(all(before_source[key] == after_source[key] for key in ("generation", "tick", "authoring_generation"))
                and after_source["revision"] - before_source["revision"] == receipt["changed"],
                "Native source advanced inconsistently with actual changed cells")
        previous = after_source
        rows = receipt.get("readback")
        require(isinstance(rows, list) and len(rows) == receipt["confirmed"] == receipt["checked"] == receipt["requested"]
                and receipt["excluded"] == 0 and receipt["refused"] == 0,
                "Original exact readback and counters disagree")
        if index_record is not None:
            compact = index_record["receipts"][number]
            require({key: value for key, value in receipt.items() if key != "readback"}
                    == {key: value for key, value in compact.items() if key != "readback_review"},
                    "Derived index changed an original receipt field")
            canonical = json.dumps(rows, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            require(compact["readback_review"]["count"] == len(rows)
                    and compact["readback_review"]["canonical_json_sha256"] == digest(canonical),
                    "Derived index readback identity differs from original native rows")
        changed = unchanged = 0
        for row in rows:
            require(isinstance(row, list) and len(row) == 4 and all(type(v) is int for v in row),
                    "Invalid native cell readback tuple")
            x, y, before, after = row
            require(x0 <= x < x0+width and y0 <= y < y0+height and before in (0, 58) and 0 <= after <= 255,
                    "Native readback violates its region/source-byte authority")
            position = (y-y0)*width + x-x0
            require(plane[position] == before, "Native cell before-value differs from prior captured/replayed state")
            if before == after:
                unchanged += 1
            else:
                changed += 1
            plane[position] = after
            verified_rows += 1
        require(changed == receipt["changed"] and unchanged == receipt["unchanged"]
                and changed+unchanged == receipt["confirmed"], "Native readback material changes do not reproduce counters")
        for key in COUNTERS:
            totals[key] += receipt[key]
        if stage_predictions is not None:
            require(stage_index < len(stage_predictions), "Extra native work after the final predicted stage")
            prediction = stage_predictions[stage_index]
            stage_requested += receipt["requested"]
            stage_changed += changed
            require(stage_requested <= prediction["requested"], "Native chunk crosses a declared stage boundary")
            if stage_requested == prediction["requested"]:
                require(stage_changed == prediction["predicted_changed"]
                        and plane_digest(plane) == prediction["after_materials_sha256"],
                        "Actual native stage plane differs from the zero-write prediction")
                stage_index += 1
                stage_requested = stage_changed = 0
                if stage_index < len(stage_predictions):
                    require(plane_digest(plane) == stage_predictions[stage_index]["before_materials_sha256"],
                            "Next predicted stage has a discontinuous material source")
    require(totals["changed"] == expected["native_changed"] and totals["checked"] == expected["native_checked"]
            and len(receipts) == expected["native_chunks"], "Original native totals differ from scenario summary")
    if stage_predictions is not None:
        require(stage_index == len(stage_predictions) and stage_requested == 0, "Not all native stages were reconstructed")
        require(source(receipts[0]["before_source"]) == expected["source_before"] and previous == expected["source_after"],
                "Scenario source endpoints differ from original native receipts")
    return plane, {"chunks": len(receipts), "verified_readback_rows": verified_rows, **totals}


def verify(args: argparse.Namespace) -> dict:
    location = Path(args.evidence)
    archive_sha = digest(location.read_bytes()) if location.is_file() else None
    if args.archive_sha256:
        require(archive_sha == args.archive_sha256, "Original compressed archive checksum mismatch")
    evidence = Evidence(location)
    campaign = evidence.json("summary.json")
    require(campaign.get("schema") == "art-collaborative-gates-v1" and campaign.get("status") == "passed"
            and campaign.get("source", {}).get("commit") == args.expected_source
            and campaign.get("source", {}).get("tracked_source_clean") is True,
            "Campaign does not qualify the explicitly requested committed source")
    require(campaign.get("model_calls") == 0, "Fixture campaign claims genuine model inference")
    cases = [case for case in campaign["cases"] if case.get("name") == CASE]
    require(len(cases) == 1, "Campaign does not contain exactly one native case")
    case = cases[0]
    require(case.get("status") == "passed" and case.get("exit_code") == 0 and not case.get("timed_out"),
            "Native campaign did not finish successfully")
    log = evidence.read(CASE + "/process.log")
    require(digest(log) == case["log_sha256"], "Original native log checksum mismatch")
    text = log.decode("utf-8")
    require(not any(marker in text for marker in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script",
                                                  "Failed loading resource:", "Error loading resource:")),
            "Original native log contains an execution/resource error")
    marker = "ART_COLLABORATIVE_NATIVE_RESULT "
    rows = [json.loads(line[len(marker):]) for line in text.splitlines() if line.startswith(marker)]
    require(len(rows) == 1 and rows[0] == case["result"] and rows[0].get("failures") == 0
            and rows[0].get("scenarios") == 9, "Native terminal marker differs from the campaign receipt")
    hashes = case.get("artifacts_sha256", {})
    verified_files = {}
    def original(name: str) -> bytes:
        data = evidence.read(CASE + "/" + name)
        actual = digest(data)
        require(re.fullmatch(r"[0-9a-f]{64}", str(hashes.get(name, ""))) is not None
                and actual == hashes[name], "Original artifact checksum mismatch: " + name)
        verified_files[name] = actual
        return data
    summary = json.loads(original("creative-native-summary.json"))
    require(summary.get("scenarios") == 9 and summary.get("failures") == 0 and summary.get("model_requests") == 0
            and [item.get("id") for item in summary.get("outcomes", [])] == list(IDS),
            "Native scenario cohort differs from its expected nine retained cases")
    indexes = {}
    if args.review_index:
        index = json.loads(Path(args.review_index).read_text(encoding="utf-8"))
        require(index.get("source") == args.expected_source, "Derived index belongs to a different source")
        indexes = {item["name"]: item for item in index["files"]}
        require(len(indexes) == 18, "Derived original-receipt index is incomplete")
    reports = []
    for number, outcome in enumerate(summary["outcomes"]):
        prefix = f"{number:02d}-{outcome['id']}"
        require(json.loads(original(prefix + "-result.json")) == outcome, "Per-scene result differs from native summary")
        region = outcome["region"]
        require(isinstance(region, list) and len(region) == 4 and all(type(v) is int for v in region),
                "Invalid native region declaration")
        width, height = region[2:]
        before = native_png(original(prefix + "-before-native.png"), width, height)
        after = native_png(original(prefix + "-after-native.png"), width, height)
        require(plane_digest(before) == outcome["before_materials_sha256"]
                and plane_digest(after) == outcome["after_materials_sha256"], "Native PNG bytes do not reproduce recorded material-plane hashes")
        staged_name = prefix + "-original-native-receipts.json"
        staged_data = original(staged_name)
        direct_name = prefix + "-direct-original-native-receipts.json"
        direct_data = original(direct_name)
        for name, data in ((staged_name, staged_data), (direct_name, direct_data)):
            if indexes:
                require(indexes[name]["original_sha256"] == digest(data)
                        and indexes[name]["original_bytes"] == len(data), "Derived original-file identity differs")
        staged_plane, staged_totals = replay(json.loads(staged_data), before, region, outcome,
                                            outcome["preview"]["stages"], indexes.get(staged_name))
        require(staged_plane == after, "Replayed staged native rows do not reproduce the complete after PNG plane")
        direct = next(item for item in outcome["comparisons"] if item["arm"] == "existing_direct_matched_geometry")
        require(direct["region"] == [region[0], region[1]+1024, width, height],
                "Direct control does not use the declared translated native scope")
        direct_plane, direct_totals = replay(json.loads(direct_data), before, direct["region"], direct,
                                            None, indexes.get(direct_name))
        require(direct_plane == after and plane_digest(direct_plane) == direct["material_sha256"],
                "Translated direct readbacks do not reproduce the matched captured material result")
        require(staged_totals["changed"] == direct_totals["changed"]
                and staged_totals["checked"] == direct_totals["checked"],
                "Matched direct and staged actual work differs")
        # Verify custody of remaining declared products, without inferring geometry
        # from rendered screenshots or confusing saved starts with live approvals.
        for suffix in ("before-workbench.png", "after-workbench.png", "editable-setup.json"):
            name = prefix + "-" + suffix
            if name in hashes:
                original(name)
        reports.append({"id": outcome["id"], "stages": outcome["stages"],
                        "captured_cells": len(before), "material_sha256": plane_digest(after),
                        "staged": staged_totals, "direct": direct_totals})
    return {"schema": "art-native-raw-evidence-review-v1", "status": "passed",
            "source": campaign["source"], "platform": campaign["platform"], "graphical": campaign["graphical"],
            "runtime_identity_from_campaign": campaign["runtime"], "original_process_log_sha256": digest(log),
            "archive_sha256": archive_sha, "model_calls": 0, "scenarios": len(reports),
            "stages": sum(row["stages"] for row in reports),
            "verified_original_files": verified_files,
            "verified_readback_rows": sum(row["staged"]["verified_readback_rows"] + row["direct"]["verified_readback_rows"] for row in reports),
            "native_changed_per_arm": sum(row["staged"]["changed"] for row in reports),
            "derived_index_verified": bool(indexes), "outcomes": reports,
            "limits": ["Read-only evidence replay, not a new native execution or model experiment.",
                       "Stage planes use actual captured native PNG bytes and original exact cell readbacks.",
                       "Direct replay starts from the fixture's declared matched translated baseline; its actual final capture hash must agree.",
                       "Rendered screenshots are checksum-bound but are never used to infer material identities.",
                       "No causal retrieval, performance, actor-traversal or genuine-model creativity claim."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", help="Original campaign directory or lossless .tar.gz archive")
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--archive-sha256")
    parser.add_argument("--review-index", help="Optional separately retained derived receipt index")
    args = parser.parse_args()
    try:
        report = verify(args)
    except Exception as error:
        report = {"schema": "art-native-raw-evidence-review-v1", "status": "failed",
                  "source": args.expected_source, "error": str(error), "error_type": type(error).__name__}
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
