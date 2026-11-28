#!/usr/bin/env python3
"""RENDER-ACK-001 narrow CI: source-bound native handoff and ACK-starvation tests."""
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

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_GODOT = "4.7.stable.official.5b4e0cb0f"
BAD_LOG = re.compile(r"(?m)^(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script)")
TESTS = [
    ("handoff", "res://tests/test_render_patch_handoff_regression.gd", "Render patch handoff regression passed"),
    ("ack_feedback", "res://tests/test_render_ack_feedback.gd", "RENDER_ACK_FEEDBACK:"),
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], output: Path, limit: int, marker: str = "") -> dict:
    started = time.monotonic()
    result: dict = {"command": command, "timeout_seconds": limit, "ok": False}
    try:
        process = subprocess.run(command, cwd=ROOT, capture_output=True,
                                 text=True, errors="replace", timeout=limit,
                                 env={**os.environ, "GODOT_SILENCE_ROOT_WARNING": "1"})
        log = process.stdout + "\n--- stderr ---\n" + process.stderr
        result["exit_code"] = process.returncode
        result["ok"] = (process.returncode == 0 and not BAD_LOG.search(log)
                        and (not marker or marker in log)
                        and (marker != "RENDER_ACK_FEEDBACK:" or
                             bool(re.search(r"RENDER_ACK_FEEDBACK: \d+ assertions, 0 failures", log))))
    except subprocess.TimeoutExpired as error:
        log = str(error) + "\n" + str(error.stdout) + "\n" + str(error.stderr)
        result["failure"] = "timeout"
    output.write_text(log, encoding="utf-8")
    result["elapsed_seconds"] = round(time.monotonic() - started, 3)
    result["log_sha256"] = sha256(output)
    result["log_bytes"] = output.stat().st_size
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--expected-sha", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if (out / "receipt.json").exists():
        parser.error("Evidence already exists; refusing overwrite")
    receipt = {"schema": "render-ack-qualification-v1", "ok": False,
               "source": None, "engine": None, "cases": {},
               "scope": "Native worker ACK/capacity regression; headless; not a GPU benchmark"}
    try:
        source = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                                         text=True, timeout=30).strip()
        if source != args.expected_sha:
            raise ValueError(f"Source mismatch: {source} != {args.expected_sha}")
        receipt["source"] = source
        if subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"],
                                   text=True, timeout=30).strip():
            raise ValueError("Source checkout must be clean before import")
        engine = args.godot.resolve(strict=True)
        version = subprocess.check_output([str(engine), "--version"],
                                          text=True, timeout=30).strip()
        if version != EXPECTED_GODOT:
            raise ValueError(f"Pinned Godot mismatch: {version}")
        receipt["engine"] = {"path": str(engine), "sha256": sha256(engine),
                             "version": version}
        platform = "windows" if sys.platform == "win32" else "linux"
        runtime = ROOT / ("godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
                          if platform == "windows"
                          else "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so")
        if runtime.stat().st_size < 1024:
            raise ValueError(f"Native runtime not materialized: {runtime}")
        receipt["native"] = {"sha256": sha256(runtime), "bytes": runtime.stat().st_size}
        project = str(ROOT / "godot")
        steps = [("import", [str(engine), "--headless", "--path", project, "--editor", "--quit"], 240, "")]
        steps += [(name, [str(engine), "--headless", "--path", project, "--script", script],
                   240, marker) for name, script, marker in TESTS]
        for name, cmd, limit, marker in steps:
            case = run(cmd, out / f"{name}.log", limit, marker)
            receipt["cases"][name] = case
            print(f"{name}: {'PASS' if case['ok'] else 'FAIL'} {case['elapsed_seconds']}s", flush=True)
            if not case["ok"]:
                raise RuntimeError(f"{name} failed, see retained {name}.log")
        receipt["ok"] = True
    except Exception as error:
        receipt["error"] = type(error).__name__ + ": " + str(error)
        print(receipt["error"], file=sys.stderr)
    finally:
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True)
                                          + "\n", encoding="utf-8")
    return 0 if receipt["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
