"""Executable original PressureFlow failure control; never a performance arm."""
from __future__ import annotations

import copy
import json
from pathlib import Path

from run_campaign import (BENCHMARK, ROOT, child_environment, execute, sha,
                          verify_native_health, verify_runtime_result)

HEALTH_ERROR = "native owner failed or stopped; see native_health.first_failure"
NATIVE_ERROR = "pressure gas compartment capacity exhausted"


def verify_failure_control(data: dict) -> None:
    """The original bounded native refusal must survive the collector boundary."""
    if data.get("ok") is not False or data.get("failures") != [HEALTH_ERROR]:
        raise ValueError("Negative control did not retain exactly its native-health failure")
    health = data.get("native_health", {})
    first = health.get("first_failure", {})
    terminal = health.get("final", {})
    if (health.get("schema") != "render-upload-577-native-health-v1"
            or health.get("applicable") is not True or health.get("failure_observations", 0) < 1
            or first.get("stage") != "frame" or first.get("healthy") is not False
            or type(first.get("worker_has_failed")) is not bool or terminal.get("worker_has_failed") is not True
            or not data.get("frames") or len(data["frames"]) >= data.get("config", {}).get("frames", 0)):
        raise ValueError("Negative native failure was not captured at its original timed transition")
    for row in (first, terminal):
        snapshot = row.get("worker_snapshot", {})
        if (snapshot.get("simulation_failed") is not True or snapshot.get("failed_tick_index") != 24
                or snapshot.get("tick_failure_count") != 1 or snapshot.get("last_tick_error") != NATIVE_ERROR
                or snapshot.get("tick_index") != 23):
            raise ValueError("Legacy PressureFlow negative changed its original native failure identity")
    # Both the original receipt and an outer ok:true forgery must be rejected.
    # Then erase the final summary to prove the earlier failed frame is binding.
    for erase_summary in (False, True):
        forged = copy.deepcopy(data)
        forged.update(ok=True, failures=[])
        if erase_summary:
            forged["native_health"].update(first_failure={}, failure_observations=0)
        try:
            verify_native_health(forged)
        except ValueError:
            pass
        else:
            raise ValueError("Native health validator accepted a forged successful failure receipt")


def run_failure_control(engine: dict, source: dict, folder: Path, userdata: Path,
                        rendering_driver: str, timeout: float) -> dict:
    """One original full-strategy arm, exact failure diagnostics, no ABBA claim."""
    config = {"workload": "active", "size": 2048, "workers": 4, "family": "pressure_flow_v1",
              "fixture": "legacy_scatter_v1", "channels": 2, "ack": "normal", "strategy": "full",
              "frames": 400, "warmup": 30}
    command = [engine["launcher"]["path"], "--audio-driver", "Dummy", "--path", str(ROOT / "godot"),
               "--rendering-method", "gl_compatibility", "--rendering-driver", rendering_driver,
               "--script", BENCHMARK, "--", "--render-upload=full"]
    command += [f"--{key}={value}" for key, value in config.items()]
    command += ["--output=" + str(folder / "runtime.json")]
    env = child_environment(userdata, "native-failure-control", source["commit"])
    process = execute(command, env, folder, timeout, expected_exit_code=1,
                      expected_error_lines=("ERROR: RENDER_UPLOAD_BENCH: " + HEALTH_ERROR,))
    data = json.loads((folder / "runtime.json").read_text(encoding="utf-8"))
    verify_failure_control(data)
    if any(data.get("config", {}).get(key) != value for key, value in config.items()):
        raise ValueError("Legacy negative-control work or failure horizon changed")
    # Generic identity validation is deliberately separate from successful arm
    # admission. The unmodified failed runtime.json is retained beside this row.
    identity_only = dict(data, ok=True, failures=[])
    graphics = verify_runtime_result(identity_only, engine, source, process=process, rendering_driver=rendering_driver,
                                     config=None, frames=None, strategy=None,
                                     fixture_sha256=sha(ROOT / "godot/tests/run_render_upload_577_benchmark.gd"))
    return {"label": "legacy-pressure-native-failure-control", "passed": True, "performance_arm": False,
            "scope": "Original unchanged heavy scatter must fail at attempted native tick24 and be refused by the collector",
            "legacy_case_id": "active_2048_w4_pressure_flow_v1", "config": config,
            "fixture_sha256": data["fixture_sha256"], "initial_image_sha256": data["initial_image_sha256"],
            "first_failure": data["native_health"]["first_failure"], "process": process, "graphics": graphics}
