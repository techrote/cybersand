#!/usr/bin/env python3
"""Independently verify the original PLAY-BUSY-001C process and decoded pixels.

The v1 reader trusted fixture counters and the first 24 PNG bytes. This reader
retains every original oracle, recomputes the same RGB sampling from complete
CRC-checked PNGs, and binds both held gates to the original observed process.
It uses only the standard library and never relies on Python assert statements.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import zlib

PREFIX = "PLAY_BUSY001C_RENDER_RESULT "
PROGRESS_PREFIX = "PLAY_BUSY001C_PROGRESS "
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
MAX_PNG_BYTES = 64 * 1024 * 1024
MAX_PIXELS = 4096 * 4096
STAGES = (
    "display_ready", "worker_started", "course_queued", "course_installed",
    "actor_ready", "parallel_render_host_ready", "native_phase_wake_queued",
    "native_phase_held", "first_capture_begin", "first_capture_end",
    "second_capture_begin", "second_capture_end", "manual_gate_release_begin",
    "native_dispatch_returned",
)
BUDGETS = {"absolute_seconds": 120, "progress_snapshot_seconds": 30,
           "progress_fail_seconds": 45}
DISPATCH_KEYS = ("generation", "tick", "phase", "expected_tasks",
                 "minimum_claims", "dispatch_started_sequence",
                 "first_arrival_sequence")


def require(value: bool, message: str) -> None:
    if not value:
        raise ValueError(message)


def integer(value: object, name: str, minimum: int = 0,
            maximum: int | None = None) -> int:
    require(type(value) is int and value >= minimum
            and (maximum is None or value <= maximum),
            f"{name} must be an integer in the required range")
    return value


def finite_number(value: object, name: str, minimum: float = 0.) -> float:
    require(type(value) in (int, float) and math.isfinite(value) and value >= minimum,
            f"{name} must be a finite number >= {minimum}")
    return float(value)


def strict_json(text: str) -> object:
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"duplicate JSON key: {key}")
            result[key] = value
        return result

    def constant(value):
        raise ValueError(f"nonfinite JSON constant: {value}")

    return json.loads(text, object_pairs_hook=pairs, parse_constant=constant)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def file_identity(path: Path) -> dict:
    require(path.is_file() and path.stat().st_size > 0, f"missing or empty file: {path}")
    return {"path": str(path), "sha256": sha256(path), "size": path.stat().st_size}


def _paeth(a: int, b: int, c: int) -> int:
    value = a + b - c
    distances = abs(value - a), abs(value - b), abs(value - c)
    return a if distances[0] <= min(distances[1:]) else (b if distances[1] <= distances[2] else c)


def decode_png(data: bytes) -> tuple[int, int, bytes]:
    """Decode the noninterlaced 8-bit RGB/RGBA PNGs emitted by Image.save_png.

    Dimensions and decompression have explicit capacity bounds. Every chunk CRC,
    complete zlib stream, filter, terminal IEND and exact scanline count is checked;
    differing metadata or compressed bytes cannot impersonate changed pixels.
    """
    require(8 < len(data) <= MAX_PNG_BYTES and data[:8] == PNG_MAGIC, "invalid PNG signature or capacity")
    offset, header, ended, idat_closed = 8, None, False, False
    compressed = bytearray()
    seen_idat = False
    while offset < len(data):
        require(offset + 12 <= len(data), "truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        require(re.fullmatch(rb"[A-Za-z]{4}", kind) is not None,
                "invalid PNG chunk type")
        require(offset + length + 12 <= len(data), "truncated PNG chunk payload")
        payload = data[offset + 8:offset + 8 + length]
        expected_crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == expected_crc,
                "PNG chunk CRC mismatch")
        offset += length + 12
        require(header is not None or kind == b"IHDR", "PNG IHDR is not first")
        if kind == b"IHDR":
            require(header is None and length == 13, "duplicate or malformed PNG IHDR")
            header = struct.unpack(">IIBBBBB", payload)
            width, height, depth, colour, compression, filtering, interlace = header
            require(0 < width <= 4096 and 0 < height <= 4096 and width * height <= MAX_PIXELS,
                    "PNG dimensions exceed decoder capacity")
            require(depth == 8 and colour in (2, 6) and (compression, filtering, interlace) == (0, 0, 0),
                    "PNG must use noninterlaced 8-bit RGB or RGBA")
        elif kind == b"IDAT":
            require(not idat_closed, "nonconsecutive PNG IDAT chunks")
            seen_idat = True
            compressed.extend(payload)
        elif kind == b"IEND":
            require(length == 0 and seen_idat and offset == len(data),
                    "missing PNG data, malformed IEND or trailing bytes")
            ended = True
            break
        else:
            if seen_idat:
                idat_closed = True
            # PLTE is optional for truecolour. Unknown critical chunks cannot be
            # ignored without changing the meaning of the retained pixels.
            require(kind == b"PLTE" or bool(kind[0] & 32), "unknown critical PNG chunk")
            if kind == b"PLTE":
                require(not seen_idat and 0 < length <= 768 and length % 3 == 0,
                        "malformed PNG PLTE")
            require(kind != b"tRNS", "unexpected PNG transparency conversion")
    require(header is not None and ended and compressed, "incomplete PNG")
    width, height, _, colour, *_ = header
    channels = 4 if colour == 6 else 3
    stride = width * channels
    expected = height * (stride + 1)
    inflater = zlib.decompressobj()
    try:
        scanlines = inflater.decompress(bytes(compressed), expected + 1)
    except zlib.error as error:
        raise ValueError(f"invalid PNG zlib stream: {error}") from error
    require(inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail
            and len(scanlines) == expected,
            "PNG decompressed length, stream completion or trailing data differs")
    decoded = bytearray(height * stride)
    previous = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        method = scanlines[start]
        require(method <= 4, "unknown PNG row filter")
        row = bytearray(scanlines[start + 1:start + 1 + stride])
        if method:
            for x in range(stride):
                a = row[x - channels] if x >= channels else 0
                b = previous[x]
                c = previous[x - channels] if x >= channels else 0
                prediction = (a if method == 1 else b if method == 2 else
                              (a + b) // 2 if method == 3 else _paeth(a, b, c))
                row[x] = (row[x] + prediction) & 255
        decoded[y * stride:(y + 1) * stride] = row
        previous = row
    if channels == 4:
        return width, height, bytes(decoded)
    rgba = bytearray(width * height * 4)
    for index in range(width * height):
        rgba[index * 4:index * 4 + 3] = decoded[index * 3:index * 3 + 3]
        rgba[index * 4 + 3] = 255
    return width, height, bytes(rgba)


def load_png(path: Path) -> tuple[dict, bytes]:
    require(path.is_file() and path.stat().st_size <= MAX_PNG_BYTES, f"missing or oversized PNG: {path}")
    data = path.read_bytes()
    width, height, pixels = decode_png(data)
    return {"path": str(path), "sha256": hashlib.sha256(data).hexdigest(),
            "size": len(data), "width": width, "height": height,
            "rgba_sha256": hashlib.sha256(pixels).hexdigest()}, pixels


def png_identity(path: Path) -> dict:
    return load_png(path)[0]


def sampled_colour_buckets(width: int, height: int, rgba: bytes) -> int:
    buckets = set()
    for iy in range(18):
        for ix in range(32):
            x = min(width - 1, (ix * 2 + 1) * width // 64)
            y = min(height - 1, (iy * 2 + 1) * height // 36)
            start = (y * width + x) * 4
            # Exact roundi(channel / 255 * 31) for positive 8-bit channels;
            # 31*n/255 never lies exactly on a half-integer.
            buckets.add(tuple((channel * 31 + 127) // 255 for channel in rgba[start:start + 3]))
    return len(buckets)


def changed_samples(width: int, height: int, first: bytes, second: bytes) -> int:
    changed = 0
    for y in range(0, height, 4):
        for x in range(0, width, 4):
            offset = (y * width + x) * 4
            # The fixture uses sum(abs(RGB differences)) > 0.04. For RGBA8
            # this is exactly an integer RGB-channel difference sum >= 11.
            changed += sum(abs(first[offset + c] - second[offset + c]) for c in range(3)) >= 11
    return changed


def read_log(path: Path) -> tuple[dict, dict]:
    results, events = [], []
    for line in path.read_text(encoding="utf-8").splitlines():
        require(not line.startswith(("SCRIPT ERROR:", "ERROR:", "PLAY_BUSY001C_EXTERNAL_TIMEOUT")),
                "original engine log contains an error or timeout")
        if line.startswith(PREFIX):
            results.append(strict_json(line[len(PREFIX):]))
        elif line.startswith(PROGRESS_PREFIX):
            events.append(strict_json(line[len(PROGRESS_PREFIX):]))
    require(len(results) == 1 and isinstance(results[0], dict),
            f"expected exactly one original {PREFIX.strip()} row")
    require(all(isinstance(event, dict) for event in events), "invalid progress event")
    require([event.get("stage") for event in events] == list(STAGES),
            "required progress stages are missing, repeated, unexpected or out of order")
    last = 0
    for event in events:
        clock = integer(event.get("elapsed_ms"), "progress elapsed_ms")
        require(clock >= last, "nonmonotonic progress clocks")
        last = clock
    return results[0], {event["stage"]: event for event in events}


def validate_result(row: dict, platform: str) -> None:
    require(type(row.get("failures")) is int and row["failures"] == 0, "fixture failures or missing failure count")
    integer(row.get("assertions"), "completed assertions", 32)
    integer(row.get("elapsed_ms"), "fixture elapsed_ms")
    require(row.get("display_server", "").casefold() == {"linux": "x11", "windows": "windows"}[platform],
            "actual graphical DisplayServer does not match the host")
    require(row.get("rendering_driver") in ("opengl3", "opengl3_angle"),
            "actual graphical rendering driver missing or unsupported")
    require(row.get("rig") == "jetbarrel", "authored Jet Barrel rig not observed")
    for key in ("rendered_frame_during_real_native_hold", "actual_frame_post_draw",
                "source_snapshot_unchanged_during_hold"):
        require(row.get(key) is True, f"required real held-frame observation absent: {key}")
    for key, minimum in (("native_phase_jobs_held", 2), ("native_phase_tasks", 2),
                         ("main_callbacks_during_hold", 2), ("physics_callbacks_during_hold", 30),
                         ("input_callbacks_during_hold", 2), ("rapier_steps_during_hold", 30)):
        integer(row.get(key), key, minimum)
    require(row["native_phase_tasks"] >= row["native_phase_jobs_held"], "phase tasks fewer than held jobs")
    require(finite_number(row.get("actor_motion_pixels"), "actor motion") > .25,
            "actual SetP actor did not move visibly")
    integer(row.get("native_phase_tick"), "phase tick", 1)
    integer(row.get("native_phase"), "phase", 0, 3)
    framebuffer = row.get("framebuffer")
    require(isinstance(framebuffer, list) and len(framebuffer) == 2, "invalid framebuffer dimensions")
    integer(framebuffer[0], "framebuffer width", 640, 4096)
    integer(framebuffer[1], "framebuffer height", 360, 4096)
    for key in ("first_colour_buckets", "second_colour_buckets"):
        integer(row.get(key), key, 6, 576)
    integer(row.get("changed_samples_4px_grid"), "changed RGB samples", 21)
    require(type(row.get("retries")) is int and row["retries"] == 0, "fixture retry field is missing or nonzero")
    for key in ("physical_gamepad_qualified", "human_feel_qualified"):
        require(row.get(key) is False, f"scope flag must be false: {key}")
    retired = row.get("retirement")
    require(isinstance(retired, dict) and all(retired.get(key) is True for key in
            ("worker_joined", "session_retired", "main_freed")), "ordered owner retirement incomplete")


def validate_held_gate(gate: dict) -> None:
    require(isinstance(gate, dict), "missing held gate snapshot")
    integer(gate.get("generation"), "held generation", 1)
    integer(gate.get("tick"), "held tick", 1)
    integer(gate.get("phase"), "held phase", 0, 3)
    expected = integer(gate.get("expected_tasks"), "expected native tasks", 2, 4096)
    require(type(gate.get("minimum_claims")) is int and gate["minimum_claims"] == 2,
            "native gate minimum claims changed")
    for key in ("waiting", "active", "entered", "distinct_threads"):
        integer(gate.get(key), "held " + key, 2, expected)
    require(gate["waiting"] <= gate["active"] <= gate["entered"], "inconsistent held task counts")
    for key in ("completed", "release_sequence", "drained_sequence", "dispatch_return_sequence"):
        require(type(gate.get(key)) is int and gate[key] == 0, "premature native completion/release: " + key)
    for key, value in (("armed", True), ("selected", True), ("released", False),
                       ("timed_out", False), ("thread_identity_overflow", False)):
        require(gate.get(key) is value, "invalid held gate flag: " + key)
    started = integer(gate.get("dispatch_started_sequence"), "dispatch start", 1)
    require(integer(gate.get("first_arrival_sequence"), "first arrival", 1) > started,
            "native job arrival must follow dispatch start")


def validate_stages(row: dict, events: dict) -> None:
    display = events["display_ready"]
    require(display.get("display_server") == row["display_server"]
            and display.get("driver") == row["rendering_driver"], "renderer identity changes within original process")
    require(all(display.get(key) == row.get(key) for key in
                ("process_pid", "process_nonce", "source_sha")), "display/result process identity differs")
    require(display.get("content_scale_pixels") == [960, 540], "registered canvas scale differs")
    wake = events["native_phase_wake_queued"]
    require(wake.get("paint_requested") == 4 and wake.get("paint_admitted") == 4,
            "all four original brush wake sites must be admitted")
    held = events["native_phase_held"]
    validate_held_gate(held)
    identity = {key: held[key] for key in DISPATCH_KEYS}
    for stage in ("first_capture_end", "second_capture_end"):
        event = events[stage]
        require(event.get("ok") is True, "capture was refused: " + stage)
        begin = events[stage.replace("_end", "_begin")]["elapsed_ms"]
        require(0 <= event["elapsed_ms"] - begin <= 2500,
                "frame capture exceeded original 2500ms wall budget")
        gate = event.get("gate")
        validate_held_gate(gate)
        require({key: gate[key] for key in DISPATCH_KEYS} == identity,
                "captures belong to different native dispatches")
    require(row["native_phase_tick"] == held["tick"] and row["native_phase"] == held["phase"]
            and row["native_phase_jobs_held"] == held["waiting"]
            and row["native_phase_tasks"] == held["expected_tasks"], "result/held native identity differs")
    final = row.get("gate_receipt")
    require(isinstance(final, dict), "missing final native gate")
    require({key: final.get(key) for key in DISPATCH_KEYS} == identity,
            "manual release/drain belongs to a different dispatch")
    returned = events["native_dispatch_returned"]
    require({key: value for key, value in returned.items() if key not in ("stage", "elapsed_ms")} == final,
            "final result/dispatch-return event differs")
    for key in ("waiting", "active"):
        require(type(final.get(key)) is int and final[key] == 0, "native tasks remain active after release")
    require(final.get("completed") == held["expected_tasks"]
            and final.get("entered") == held["expected_tasks"], "native dispatch did not drain every task")
    require(final.get("released") is True and final.get("armed") is False
            and final.get("selected") is True and final.get("timed_out") is False
            and final.get("thread_identity_overflow") is False,
            "final gate is not a manual fully drained release")
    sequence = [integer(final.get(key), key, 1) for key in
                ("dispatch_started_sequence", "first_arrival_sequence", "release_sequence",
                 "drained_sequence", "dispatch_return_sequence")]
    require(all(a < b for a, b in zip(sequence, sequence[1:])), "native manual release/drain/return order differs")


def _identity_matches(record: object, actual: dict, name: str) -> None:
    require(isinstance(record, dict) and isinstance(record.get("path"), str) and record["path"],
            f"missing original {name} identity")
    require(record.get("sha256") == actual["sha256"] and type(record.get("size")) is int
            and record["size"] == actual["size"], f"original {name} bytes differ")


def validate_process(process: object, row: dict, args: argparse.Namespace,
                     identities: dict) -> None:
    require(isinstance(process, dict) and process.get("schema") == "play-busy001c-process-v1",
            "missing original process receipt schema")
    require(process.get("source_sha") == args.source_sha == row.get("source_sha"),
            "original process/fixture/source SHA differs")
    require(process.get("platform") == args.platform, "original host platform differs")
    require(process.get("status") == "completed" and process.get("error") is None
            and process.get("qualification") == "original-host-process",
            "original process receipt is not completed qualification")
    require(isinstance(process.get("source_tree"), str)
            and re.fullmatch(r"[0-9a-f]{40}", process["source_tree"]) is not None,
            "original source tree identity missing")
    pid = integer(process.get("pid"), "original engine PID", 1)
    launcher = integer(process.get("launcher_pid"), "original launcher PID", 1)
    require(type(row.get("process_pid")) is int and row["process_pid"] == pid,
            "fixture result came from a different engine process")
    nonce = process.get("nonce")
    require(isinstance(nonce, str) and re.fullmatch(r"[0-9a-f]{32,64}", nonce) is not None
            and row.get("process_nonce") == nonce, "original process nonce missing or mismatched")
    require(type(process.get("returncode")) is int and process["returncode"] == 0,
            "original launcher did not exit successfully")
    for key, value in (("timed_out", False), ("cleanup_complete", True), ("forced_cleanup", False)):
        require(process.get(key) is value, "original process retirement refused: " + key)
    require(process.get("budgets") == BUDGETS, "original execution budgets differ")
    command = process.get("argv")
    require(isinstance(command, list) and command and all(isinstance(arg, str) and arg for arg in command),
            "missing original command line")
    require("--headless" not in command, "headless command cannot qualify")
    require(command[-2:] == ["--script", "res://tests/play_busy001c_render.gd"],
            "original command differs: exact fixture suffix absent")
    for option, value in (("--script", "res://tests/play_busy001c_render.gd"),
                          ("--rendering-method", "gl_compatibility"), ("--resolution", "960x540")):
        require(command.count(option) == 1 and command.index(option) + 1 < len(command)
                and command[command.index(option) + 1] == value, "original command differs: " + option)
    require(command.count("--windowed") == 1, "original graphical window flag missing")
    if "--rendering-driver" in command:
        index = command.index("--rendering-driver")
        require(command.count("--rendering-driver") == 1 and index + 1 < len(command)
                and command[index + 1] == row["rendering_driver"], "requested/actual renderer differs")
    observations = process.get("observed_processes")
    require(isinstance(observations, dict) and str(pid) in observations and str(launcher) in observations,
            "original engine/launcher observation absent")
    visited, current = set(), pid
    while current not in visited:
        visited.add(current)
        observed = observations.get(str(current))
        require(isinstance(observed, dict) and observed.get("pid") == current,
                "original process lineage observation missing")
        require(observed.get("role") == "host",
                "diagnostic or unattributed process cannot supply original host evidence")
        integer(observed.get("parent_pid"), "observed parent PID")
        created = observed.get("creation_time")
        require((isinstance(created, str) and bool(created.strip()))
                or (type(created) in (int, float) and math.isfinite(created) and created > 0),
                "original process creation identity absent")
        if current == launcher:
            break
        current = observed["parent_pid"]
    require(current == launcher, "observed engine is not a descendant of the original launcher")
    if args.platform == "linux":
        require(pid == launcher, "Linux original engine PID differs from spawned child")
    recorded = process.get("identities")
    require(isinstance(recorded, dict), "nested original file identities absent")
    for name in ("runtime", "rapier", "log"):
        _identity_matches(recorded.get(name), identities[name], name)
    engine = recorded.get("engine")
    require(isinstance(engine, dict) and isinstance(engine.get("path"), str), "missing original engine identity")
    # Original runner paths are unavailable after downloading an archive. An
    # explicit relocated file must match the untouched original identity; never
    # rewrite the custody receipt merely to make local paths usable.
    selected_engine = getattr(args, "engine", None) or Path(engine["path"])
    _identity_matches(engine, file_identity(selected_engine), "engine")


def readback(args: argparse.Namespace) -> dict:
    require(re.fullmatch(r"[0-9a-f]{40}", args.source_sha) is not None, "source SHA must be a full commit identity")
    require(args.platform in ("linux", "windows"), "unknown qualification platform")
    require(isinstance(args.godot_version, str) and args.godot_version, "missing Godot identity")
    row, events = read_log(args.log)
    validate_result(row, args.platform)
    validate_stages(row, events)
    identities = {"runtime": file_identity(args.runtime), "rapier": file_identity(args.rapier),
                  "log": file_identity(args.log)}
    process = strict_json(args.process_receipt.read_text(encoding="utf-8"))
    validate_process(process, row, args, identities)
    images, pixels = {}, []
    for name in ("held-before.png", "held-after.png"):
        identity, rgba = load_png(args.evidence_dir / name)
        require([identity["width"], identity["height"]] == row["framebuffer"],
                f"{name} dimensions differ from reported framebuffer")
        images[name] = identity
        pixels.append(rgba)
    width, height = row["framebuffer"]
    buckets = [sampled_colour_buckets(width, height, image) for image in pixels]
    changed = changed_samples(width, height, *pixels)
    require(buckets == [row["first_colour_buckets"], row["second_colour_buckets"]],
            "decoded PNG colour buckets differ from original capture")
    require(min(buckets) >= 6, "decoded gameplay PNG is blank by the original oracle")
    require(changed == row["changed_samples_4px_grid"] and changed > 20,
            "decoded held RGB pixel differences differ from original capture")
    require(images["held-before.png"]["rgba_sha256"] != images["held-after.png"]["rgba_sha256"],
            "decoded before/after gameplay pixels are identical")
    return {"schema": "play-busy001c-rendered-held-phase-v2", "status": "passed",
            "source_sha": args.source_sha, "platform": args.platform,
            "godot_version": args.godot_version, **identities,
            "process_receipt": file_identity(args.process_receipt), "process": process,
            "images": images, "result": row, "stages": events,
            "independent_pixels": {"colour_buckets": buckets, "changed_samples_4px_grid": changed,
                                   "oracle": "original 32x18 RGB buckets and 4px RGB L1 >0.04"},
            "errors": [], "scope": {"real_world_phase_jobs": True, "actual_frame_post_draw": True,
                "raw_gameplay_pixels": True, "actual_main_input_and_rapier_progress": True,
                "test_only_native_hold": True, "original_host_process": True,
                "physical_device_focus": False, "human_feel": False, "release_qualification": False}}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument("--process-receipt", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--engine", type=Path, help="Relocated original engine; must match its recorded SHA-256 and size")
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--rapier", type=Path, required=True)
    parser.add_argument("--godot-version", required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        receipt = readback(args)
    except (OSError, ValueError, TypeError, KeyError, AttributeError, OverflowError) as error:
        receipt = {"schema": "play-busy001c-rendered-held-phase-v2", "status": "failed",
                   "source_sha": args.source_sha, "platform": args.platform,
                   "errors": [f"{type(error).__name__}: {error}"]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    print(f"PLAY_BUSY001C_READBACK {receipt['status']} {args.platform}")
    for error in receipt["errors"]:
        print(" -", error)
    return int(receipt["status"] != "passed")


if __name__ == "__main__":
    raise SystemExit(main())
