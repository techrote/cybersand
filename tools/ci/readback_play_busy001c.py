#!/usr/bin/env python3
"""Reduce PLAY-BUSY-001C graphical held-phase evidence without image libraries."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


PREFIX = "PLAY_BUSY001C_RENDER_RESULT "
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def png_identity(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != PNG_MAGIC or data[12:16] != b"IHDR":
        raise ValueError(f"not a canonical PNG with IHDR: {path}")
    width, height = struct.unpack(">II", data[16:24])
    if width < 1 or height < 1:
        raise ValueError(f"invalid PNG dimensions: {path}")
    return {
        "path": str(path),
        "sha256": hashlib.sha256(data).hexdigest(),
        "size": len(data),
        "width": width,
        "height": height,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--rapier", type=Path, required=True)
    parser.add_argument("--godot-version", required=True)
    parser.add_argument("--platform", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rows = [
        json.loads(line[len(PREFIX):])
        for line in args.log.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.startswith(PREFIX)
    ]
    if len(rows) != 1:
        raise SystemExit(f"expected exactly one {PREFIX.strip()} row, found {len(rows)}")
    row = rows[0]
    failures = []

    if row.get("failures") != 0:
        failures.append(f"fixture failures={row.get('failures')}")
    if row.get("display_server") == "headless":
        failures.append("headless DisplayServer cannot qualify rendered output")
    if row.get("rendered_frame_during_real_native_hold") is not True:
        failures.append("held real-phase framebuffer not observed")
    if row.get("actual_frame_post_draw") is not True:
        failures.append("RenderingServer frame_post_draw not observed")
    if int(row.get("native_phase_jobs_held", 0)) < 2:
        failures.append("fewer than two real native phase jobs held")
    if int(row.get("native_phase_tasks", 0)) < int(row.get("native_phase_jobs_held", 0)):
        failures.append("native phase task count smaller than held count")
    if int(row.get("main_callbacks_during_hold", 0)) < 2:
        failures.append("Main callbacks did not progress during held phase")
    if int(row.get("physics_callbacks_during_hold", 0)) < 30:
        failures.append("physics callbacks did not progress for required held window")
    if int(row.get("input_callbacks_during_hold", 0)) < 2:
        failures.append("Viewport key edges not observed during held phase")
    if int(row.get("rapier_steps_during_hold", 0)) < 30:
        failures.append("Rapier did not progress for required held window")
    if float(row.get("actor_motion_pixels", 0.0)) <= 0.25:
        failures.append("actual SetP actor did not move visibly in physics state")
    framebuffer = row.get("framebuffer", [0, 0])
    if not isinstance(framebuffer, list) or len(framebuffer) != 2 or int(framebuffer[0]) < 640 or int(framebuffer[1]) < 360:
        failures.append(f"invalid framebuffer dimensions: {framebuffer}")
    if int(row.get("first_colour_buckets", 0)) < 6 or int(row.get("second_colour_buckets", 0)) < 6:
        failures.append("captured gameplay frames are effectively blank")
    if int(row.get("changed_samples_4px_grid", 0)) <= 20:
        failures.append("held-phase submitted pixels did not visibly change")
    if row.get("source_snapshot_unchanged_during_hold") is not True:
        failures.append("new or partial native snapshot appeared during controlled hold")
    if row.get("retries") != 0:
        failures.append("fixture reported retries")
    for key in ("physical_gamepad_qualified", "human_feel_qualified"):
        if row.get(key) is not False:
            failures.append(f"scope flag {key} must remain false")

    gate = row.get("gate_receipt", {})
    if gate.get("timed_out") is not False:
        failures.append("positive render hold used safety timeout")
    if int(gate.get("completed", -1)) != int(gate.get("expected_tasks", -2)):
        failures.append("selected real phase did not drain exactly")
    if int(gate.get("dispatch_return_sequence", 0)) <= int(gate.get("drained_sequence", 0)):
        failures.append("production pool dispatch did not return after drain")

    images = {}
    try:
        for name in ("held-before.png", "held-after.png"):
            identity = png_identity(args.evidence_dir / name)
            images[name] = identity
            if isinstance(framebuffer, list) and len(framebuffer) == 2:
                if [identity["width"], identity["height"]] != [int(framebuffer[0]), int(framebuffer[1])]:
                    failures.append(f"{name} dimensions differ from reported framebuffer")
        if images["held-before.png"]["sha256"] == images["held-after.png"]["sha256"]:
            failures.append("before/after PNG bytes are identical")
    except (OSError, ValueError, KeyError) as error:
        failures.append(f"raw PNG verification failed: {type(error).__name__}: {error}")

    receipt = {
        "schema": "play-busy001c-rendered-held-phase-v1",
        "status": "failed" if failures else "passed",
        "source_sha": args.source_sha,
        "platform": args.platform,
        "godot_version": args.godot_version,
        "runtime": {
            "path": str(args.runtime),
            "sha256": sha256(args.runtime),
            "size": args.runtime.stat().st_size,
        },
        "rapier": {
            "path": str(args.rapier),
            "sha256": sha256(args.rapier),
            "size": args.rapier.stat().st_size,
        },
        "log": {
            "path": str(args.log),
            "sha256": sha256(args.log),
            "size": args.log.stat().st_size,
        },
        "images": images,
        "result": row,
        "errors": failures,
        "scope": {
            "real_world_phase_jobs": True,
            "actual_frame_post_draw": True,
            "raw_gameplay_pixels": True,
            "actual_main_input_and_rapier_progress": True,
            "test_only_native_hold": True,
            "physical_device_focus": False,
            "human_feel": False,
            "release_qualification": False,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"PLAY_BUSY001C_READBACK {receipt['status']} {args.platform}")
    for failure in failures:
        print(" -", failure)
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
