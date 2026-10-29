#!/usr/bin/env python3
"""Reduce one PLAY-BUSY-001B real-host log into a source/runtime-bound receipt."""
import argparse
import hashlib
import json
from pathlib import Path


PREFIX = "PLAY_BUSY001B_RESULT "


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
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
    required_true = (
        "production_stop_fence_observed",
        "native_adapter_destroyed",
        "setp_rapier_retired_before_worker_stop",
        "test_only_controlled_native_phase_hold",
    )
    failures = []
    if row.get("failures") != 0:
        failures.append(f"fixture failures={row.get('failures')}")
    if int(row.get("native_phase_jobs_held", 0)) < 2:
        failures.append("fewer than two native phase jobs held")
    if int(row.get("native_phase_tasks", 0)) < int(row.get("native_phase_jobs_held", 0)):
        failures.append("phase task count smaller than held count")
    if int(row.get("main_callbacks_during_hold", 0)) < 1:
        failures.append("Main did not progress during hold")
    if int(row.get("physics_callbacks_during_hold", 0)) < 1:
        failures.append("physics callback did not progress during hold")
    if int(row.get("input_callbacks_during_hold", 0)) < 2:
        failures.append("input edges did not reach Main during hold")
    if int(row.get("rapier_steps_during_hold", 0)) < 1:
        failures.append("Rapier did not progress during hold")
    for key in required_true:
        if row.get(key) is not True:
            failures.append(f"{key} is not true")
    if row.get("workers_joined") != 1:
        failures.append("worker join not observed")
    if row.get("retries") != 0:
        failures.append("fixture reported retries")
    for key in ("rendered_fps_measured", "physical_gamepad_qualified", "human_feel_qualified"):
        if row.get(key) is not False:
            failures.append(f"scope flag {key} must remain false")

    gate = row.get("gate_receipt", {})
    sequence = [
        int(gate.get("dispatch_started_sequence", 0)),
        int(gate.get("first_arrival_sequence", 0)),
        int(gate.get("stop_sequence", 0)),
        int(gate.get("release_sequence", 0)),
        int(gate.get("drained_sequence", 0)),
        int(gate.get("dispatch_return_sequence", 0)),
    ]
    if not all(a < b for a, b in zip(sequence, sequence[1:])):
        failures.append(f"invalid phase/stop ordering: {sequence}")
    if gate.get("timed_out") is not False:
        failures.append("positive hold used the safety timeout")
    if int(gate.get("completed", -1)) != int(gate.get("expected_tasks", -2)):
        failures.append("selected dispatch did not drain exactly")

    receipt = {
        "schema": "play-busy001b-real-host-v1",
        "status": "failed" if failures else "passed",
        "source_sha": args.source_sha,
        "platform": args.platform,
        "godot_version": args.godot_version,
        "runtime": {"path": str(args.runtime), "sha256": sha256(args.runtime), "size": args.runtime.stat().st_size},
        "rapier": {"path": str(args.rapier), "sha256": sha256(args.rapier), "size": args.rapier.stat().st_size},
        "log": {"path": str(args.log), "sha256": sha256(args.log), "size": args.log.stat().st_size},
        "result": row,
        "errors": failures,
        "scope": {
            "real_world_phase_jobs": True,
            "actual_main_callbacks": True,
            "actual_production_stop_worker_fence": True,
            "actual_setp_rapier_retirement_before_worker_stop": True,
            "test_only_native_hold": True,
            "rendered_fps": False,
            "physical_device_focus": False,
            "human_feel": False,
            "release_qualification": False,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"PLAY_BUSY001B_READBACK {receipt['status']} {args.platform}")
    for failure in failures:
        print(" -", failure)
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
