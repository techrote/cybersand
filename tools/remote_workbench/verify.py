#!/usr/bin/env python3
"""Verify native/renderer identity, original PNG pixels and late-Stop refusal.

No mock results are manufactured here. --roundtrip enforces the committed
eight-command real-Godot acceptance sequence; generic sessions retain their
own receipts, frames and manifest without pretending to pass that control.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

PNG_HEADER = b"\x89PNG\r\n\x1a\n"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode_png(path: Path) -> tuple[int, int, bytes]:
    """Decode original non-interlaced 8-bit RGB/RGBA PNG pixels using stdlib."""
    data = path.read_bytes()
    require(data.startswith(PNG_HEADER), f"PNG signature: {path}")
    i = 8
    width = height = 0
    depth = color_type = interlace = -1
    compressed = bytearray()
    seen_end = False
    while i + 12 <= len(data):
        length = struct.unpack_from(">I", data, i)[0]
        chunk = data[i + 4 : i + 8]
        body = data[i + 8 : i + 8 + length]
        require(i + length + 12 <= len(data), f"Truncated PNG: {path}")
        checksum = struct.unpack_from(">I", data, i + 8 + length)[0]
        require(zlib.crc32(chunk + body) & 0xFFFFFFFF == checksum, f"PNG CRC: {path}")
        i += length + 12
        if chunk == b"IHDR":
            width, height, depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", body
            )
        elif chunk == b"IDAT":
            compressed.extend(body)
        elif chunk == b"IEND":
            seen_end = True
            break
    require(seen_end and width > 0 and height > 0 and width <= 4096 and height <= 4096,
            f"Invalid original PNG dimensions/end marker: {path}")
    require(depth == 8 and color_type in (2, 6) and interlace == 0,
            f"Original PNG is not RGB/RGBA8 non-interlaced: {path}")
    bpp = 3 if color_type == 2 else 4
    stride = width * bpp
    raw = zlib.decompress(bytes(compressed))
    require(len(raw) == (stride + 1) * height, f"Unexpected PNG scanline bytes: {path}")
    output = bytearray(width * height * bpp)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        filtering = raw[pos]
        pos += 1
        scanline = bytearray(raw[pos : pos + stride])
        pos += stride
        require(filtering in range(5), f"Unknown PNG filter: {path}")
        for x in range(stride):
            left = scanline[x - bpp] if x >= bpp else 0
            above = prev[x]
            upper_left = prev[x - bpp] if x >= bpp else 0
            if filtering == 1:
                scanline[x] = (scanline[x] + left) & 0xFF
            elif filtering == 2:
                scanline[x] = (scanline[x] + above) & 0xFF
            elif filtering == 3:
                scanline[x] = (scanline[x] + (left + above) // 2) & 0xFF
            elif filtering == 4:
                predictor = left + above - upper_left
                distances = (abs(predictor - left),
                             abs(predictor - above),
                             abs(predictor - upper_left))
                if distances[0] <= distances[1] and distances[0] <= distances[2]:
                    paeth = left
                elif distances[1] <= distances[2]:
                    paeth = above
                else:
                    paeth = upper_left
                scanline[x] = (scanline[x] + paeth) & 0xFF
        output[y * stride : (y + 1) * stride] = scanline
        prev = scanline
    return width, height, bytes(output)


def load_evidence(folder: Path) -> tuple[dict, dict, list[dict]]:
    launcher = json.loads((folder / "launcher-identity.json").read_text())
    manifest = json.loads((folder / "manifest.json").read_text())
    events = [
        json.loads(line)
        for line in (folder / "results.jsonl").read_text().splitlines()
        if line.strip()
    ]
    return launcher, manifest, events


def inspect(folder: Path, roundtrip: bool) -> dict:
    launcher, manifest, events = load_evidence(folder)
    require(manifest.get("version") == 1, "Unsupported manifest version")
    require(manifest.get("source_commit") == launcher.get("source_commit"), "Source HEAD drift")
    require(manifest.get("source_tree") == launcher.get("source_tree"), "Source tree drift")
    for key, library in (
        ("native_runtime_sha256", "native"),
        ("rapier_runtime_sha256", "rapier"),
        ("godot_runtime_sha256", "godot"),
    ):
        require(manifest.get(key) == launcher["runtime_hashes"][library],
                f"Runtime provenance mismatch: {library}")
    require(manifest.get("task", {}).get("authorization_sha256") ==
            digest(folder / "host-authorization.json"), "Authorization custody mismatch")
    require(manifest.get("stopped") is True, "Explicit Stop not acknowledged")
    require(manifest.get("result") == "passed" and not manifest.get("failures"),
            "Godot has failures; do not relabel successful process exit as acceptance")
    require(any(e.get("type") == "authorization" and e.get("status") == "authorized"
                for e in events), "No actual host/native authorization receipt")
    receipts = [e for e in events if e.get("type") == "tool_result"]
    require(len(receipts) == manifest.get("command_count"), "Missing or duplicate JSONL receipts")
    require(len(receipts) <= 96, "Command budget exceeded")
    require(all(x.get("version") == 1 for x in events), "Mixed protocol versions")
    frames: dict[str, tuple[int, int, bytes]] = {}
    for record in manifest.get("frames", []):
        name = record.get("path", "")
        require(name.startswith("frames/") and name.endswith(".png") and ".." not in name,
                "Unexpected framebuffer path")
        path = folder / name
        require(path.is_file() and path.stat().st_size == record["bytes"] and
                digest(path) == record["sha256"], f"Original PNG custody failed: {name}")
        width, height, pixels = decode_png(path)
        require(width == record["width"] and height == record["height"],
                f"PNG dimensions changed: {name}")
        frames[name] = (width, height, pixels)
    require(len(frames) == len(manifest.get("frames", [])), "Duplicate original frame paths")
    for event in receipts:
        frame = event.get("frame", {})
        if frame.get("status") != "original_post_draw":
            continue
        require(frame["path"] in frames, "Receipt frame not retained in manifest")
        observation = event["result"]
        if event["tool"] == "step":
            observation = observation.get("observation", {})
        native = observation.get("identity", {})
        rendered = observation.get("render_identity", {})
        require(observation.get("status") == "observed" and
                observation.get("image_status") == "matched_post_draw",
                "Accepted frame did not originate in matched owner render join")
        require(native.get("world_generation") == rendered.get("world_generation") and
                native.get("world_revision") == rendered.get("world_revision") and
                native.get("completed_tick") == rendered.get("tick"),
                "Native/real-pixel generation, revision or tick mismatch")
        require(int(rendered.get("render_snapshot_serial", 0)) > 0,
                "No actual render upload acknowledgment")
        require(event.get("completed_native_ticks_total", 999) <= 480,
                "Exceeded bounded native tick allowance")
    result: dict = {
        "status": "verified", "source_commit": manifest["source_commit"],
        "source_tree": manifest["source_tree"], "command_receipts": len(receipts),
        "original_pngs": len(frames),
        "completed_native_ticks_total": manifest["completed_native_ticks_total"],
        "roundtrip": roundtrip,
    }
    if roundtrip:
        require(len(receipts) == 8, "Roundtrip must retain all eight commands")
        expected = [
            ("observe", "observed"), ("prepare_edit", "proposed"),
            ("apply_edit", "applied"), ("observe", "observed"),
            ("step", "completed"), ("observe", "observed"),
            ("stop", "stopped"), ("apply_edit", "refused"),
        ]
        require([(e["tool"], e["status"]) for e in receipts] == expected,
                "Required full lifecycle/late-mutation status mismatch")
        before, prepared, applied, edited, stepped, later, stopped, refused = receipts
        assert before["result"]["identity"]["completed_tick"] == 0
        assert before["result"]["native_counts"].get("58", 0) == 0
        assert edited["result"]["native_counts"].get("58") == 9
        assert applied["result"].get("changed_cells") == 9
        assert applied["result"].get("confirmed_writes") == 9
        cells = applied["result"].get("readback", [])
        require(len(cells) == 9 and all(
            c["before"] == 0 and c["after"] == 58 and c["actual"] == 58 for c in cells
        ), "Native writer did not verify all nine changed cells")
        require(applied["result"].get("authored_start", {}).get("status") == "recorded",
                "Constructed authored start was not recorded")
        before_image = frames[before["frame"]["path"]]
        after_image = frames[edited["frame"]["path"]]
        require(before_image[:2] == after_image[:2] and
                before_image[2] != after_image[2], "Decoded original framebuffer pixels did not change")
        require(edited["frame"].get("pixels_changed_from_previous_frame") is True,
                "Godot decoded original framebuffer pixels did not change")
        step = stepped["result"]
        require(step.get("requested") == 4 and step.get("completed") == 4 and
                step.get("before_tick") == 0 and step.get("after_tick") == 4 and
                step.get("still_paused") is True, "Step did not complete exactly four native ticks")
        require(step.get("observation", {}).get("identity", {}).get("completed_tick") == 4,
                "Post-Step native identity did not match four completed ticks")
        require(step.get("observation", {}).get("render_identity", {}).get("tick") == 4,
                "Post-Step original PNG did not match four native ticks")
        require(stopped["result"].get("no_further_agent_mutations") is True,
                "Stop had no native retirement acknowledgment")
        require(refused["result"].get("status") == "refused" and
                refused["result"].get("reason") == "task_not_authorized_or_stopping",
                "Late apply was not refused by the retired native bridge")
        require(manifest["completed_native_ticks_total"] == 4, "Unexpected ticks outside Step")
        require(len(frames) >= 4, "Initial/post-edit/step/post-step original PNGs not retained")
        result["pixel_changes_verified"] = True
        result["native_cells_changed"] = 9
        result["stop_refused_late_edit"] = True
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--roundtrip", action="store_true")
    args = parser.parse_args()
    answer = inspect(args.evidence.resolve(), args.roundtrip)
    (args.evidence / "verification.json").write_text(
        json.dumps(answer, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(answer, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
