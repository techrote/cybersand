#!/usr/bin/env python3
"""RENDER-ACK-002: real 2048² Workbench/Rapier under baseline/gated policy.

Use independent fresh processes. This is an application and exact-state
correctness control, not a GPU hardware benchmark or merged acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from run_graphical import command, sha, GODOT_PIN

ROOT = Path(__file__).resolve().parents[2]
MARKER = re.compile(r"^WORKBENCH_INTEREST\s+({.*})\s*$", re.M)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--rendering-driver",
                        default="opengl3_angle" if sys.platform == "win32" else "opengl3")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=420)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    summary = out / "summary.json"
    if summary.exists():
        parser.error("Refusing to overwrite existing Workbench evidence")
    report = {"schema": "render-ack-workbench-v1", "source_sha": None,
              "complete": False, "cases": [],
              "scope": "Real 2048² Main/Workbench/Rapier, separate terrain-collider and presentation ownership"}
    try:
        source = command("git", "rev-parse", "HEAD")
        if source != args.expected_sha:
            raise ValueError("exact source mismatch")
        report["source_sha"] = source
        engine = args.godot.resolve(strict=True)
        version = command(str(engine), "--version")
        if version != GODOT_PIN:
            raise ValueError("pinned Godot identity mismatch")
        report["engine"] = {"sha256": sha(engine), "version": version}
        platform = "windows" if sys.platform == "win32" else "linux"
        extension = "cybersand_native.windows.x86_64.dll" if platform == "windows" else "libcybersand_native.linux.x86_64.so"
        native = ROOT / "godot/addons/cybersand_native/bin" / extension
        provenance = ROOT / "godot/addons/cybersand_native" / (
            "runtime-provenance.json" if platform == "windows" else "runtime-provenance.linux.json")
        manifest = json.loads(provenance.read_text(encoding="utf-8"))
        if native.stat().st_size < 1024 or sha(native) != manifest.get("sha256"):
            raise ValueError("source-matched native runtime/provenance mismatch")
        report["native"] = {"sha256": sha(native), "source_commit": manifest.get("source_commit")}
        # One fresh control and one gated run per worker count. Separate data
        # folders prevent old authoring/autosave state contaminating either arm.
        for workers in (1, 4):
            for policy in ("baseline", "gated"):
                name = f"wb{workers}-{policy}"
                userdata = out / (name + "-userdata")
                userdata.mkdir(exist_ok=True)
                cmd = [str(engine), "--audio-driver", "Dummy",
                       "--rendering-driver", args.rendering_driver,
                       "--path", str(ROOT / "godot"),
                       "--script", "res://tests/test_render_ack_workbench_policy.gd",
                       "--", "--worker-count=" + str(workers),
                       "--render-ack-policy=" + policy]
                env = dict(os.environ, GODOT_SILENCE_ROOT_WARNING="1",
                           XDG_DATA_HOME=str(userdata), APPDATA=str(userdata))
                begin = time.monotonic()
                try:
                    process = subprocess.run(cmd, cwd=ROOT, capture_output=True,
                                             text=True, errors="replace",
                                             timeout=args.timeout, env=env)
                    log = process.stdout + "\n--- stderr ---\n" + process.stderr
                except subprocess.TimeoutExpired as error:
                    log = str(error) + "\n" + str(error.stdout) + "\n" + str(error.stderr)
                    process = None
                log_path = out / (name + ".log")
                log_path.write_text(log, encoding="utf-8")
                matches = MARKER.findall(log)
                row = {"id":name, "workers":workers, "policy":policy,
                       "seconds":round(time.monotonic()-begin,3),
                       "exit_code":process.returncode if process else None,
                       "log_sha256":sha(log_path)}
                report["cases"].append(row)
                if process is None or process.returncode or len(matches) != 1:
                    raise RuntimeError(f"{name}: missing/failing real Workbench result; see {log_path}")
                data = json.loads(matches[0])
                if data.get("failures") != []:
                    raise RuntimeError(f"{name}: Workbench correctness failures: {data.get('failures')}")
                obs = data.get("observations",{})
                # A paused/replaced Workbench can finish at tick zero. The
                # independent simulation and Rapier receipts, plus observed
                # physical material insertion, prove real earlier progress.
                source_receipt = obs.get("source", {})
                if (int(source_receipt.get("inserted", 0)) <= 0
                        or len(obs.get("body_rows", [])) < 3
                        or not obs.get("near_actor")
                        or not obs.get("distant_actor")):
                    raise RuntimeError(f"{name}: missing actual Workbench material/actor progress")
                row.update({"world_extent": "2048x2048", "completed_tick":obs.get("native_tick"),
                            "worker_step_ms":obs.get("worker_step_ms"),
                            "native_simulation_ms":obs.get("last_native_ms"),
                            "godot_peak_static_bytes":obs.get("godot_peak_static_bytes"),
                            "status":obs.get("status"),"failure_count":0})
                print(name, json.dumps(row, sort_keys=True), flush=True)
        report["complete"] = True
    except Exception as exc:
        report["error"] = type(exc).__name__ + ": " + str(exc)
        print(report["error"], file=sys.stderr, flush=True)
    finally:
        summary.write_text(json.dumps(report, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    return 0 if report["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
