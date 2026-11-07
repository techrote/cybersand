#!/usr/bin/env python3
"""Bounded, offline qualification of the actual composed WB-AGENT client.

Runs existing owner tests unchanged, retains original logs/images and records
actual source/runtime hashes. Never starts the paid Responses transport. A green
result is scoped automated engineering evidence, not live or human acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_SHA = "549a1db2520bcfb35f068f46b62320d7325d6297037ca2faf23c3b488d80347c"
CASES = [
    ("client", "test_workbench_agent_client.gd", True, []),
    ("geometry", "test_workbench_agent_footprint.gd", True, []),
    ("signed-frame", "test_workbench_agent_signed_frame.gd", True, []),
    ("envelope", "test_workbench_authoring_envelope.gd", True, []),
    ("failure-controls", "test_workbench_agent_failures.gd", True, []),
    ("step", "test_workbench_agent_step_sequence.gd", False, []),
    ("step-paused-boundary", "test_wb525_step_paused_boundary.gd", False, []),
    ("native-owner", "test_workbench_agent_owner.gd", False, []),
    ("four-tool-join", "test_workbench_agent_four_tool_join.gd", False, []),
    ("signed-join", "test_workbench_agent_signed_join.gd", False, []),
    ("hopper", "test_workbench_agent_hopper_godot.gd", False, []),
    ("mounted-hopper", "test_wb525_mounted_hopper.gd", False, []),
    ("mounted", "test_workbench_agent_mounted.gd", False, []),
    ("capacity-camera", "test_wb525_capacity_and_camera.gd", False, []),
    ("manual-input", "test_workbench_input.gd", False, []),
    ("render-bridge", "test_native_render_bridge_regression.gd", False, []),
    ("manual-save", "test_workbench_agent_disabled.gd", False, []),
    ("manual-reopen", "test_workbench_agent_disabled.gd", False, []),
]


def digest(path: Path) -> dict:
    data = path.read_bytes()
    return {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def identity(godot: Path) -> dict:
    paths = git("ls-files", "--cached", "--others", "--exclude-standard", "native", "godot/scripts", "godot/tests",
                "godot/native_extension", "third_party", "tools/wb_agent").splitlines()
    source = {p: digest(ROOT / p) for p in paths if (ROOT / p).is_file()
              and not p.endswith(".uid") and "__pycache__" not in p}
    libraries = [ROOT / "godot/addons/cybersand_native/bin" /
                 ("cybersand_native.windows.x86_64.dll" if os.name == "nt"
                  else "libcybersand_native.linux.x86_64.so"),
                 ROOT / "godot/addons/godot-rapier2d/bin" /
                 ("libgodot_rapier.windows.x86_64-pc-windows-msvc.dll" if os.name == "nt"
                  else "libgodot_rapier.linux.x86_64-unknown-linux-gnu.so")]
    for library in libraries:
        with library.open("rb") as stream:
            if library.stat().st_size < 1024 or stream.read(80).startswith(b"version https://git-lfs"):
                raise ValueError(f"Unmaterialized runtime: {library}")
    return {"head": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "tracked_delta": git("diff", "--name-status", "HEAD"),
            "platform": platform.platform(), "python": sys.version,
            "godot": {"path": str(godot), **digest(godot)},
            "runtimes": {str(p.relative_to(ROOT)): digest(p) for p in libraries},
            "source_files": source}


def validate_output(text: str, case: str) -> bool:
    summaries = {
        "client": r"WB_AGENT_528 fake-provider checks [1-9]\d*, failures 0",
        "geometry": r"WB_AGENT_FOOTPRINT: [1-9]\d* assertions, 0 failure",
        "signed-frame": r"WB_AGENT_SIGNED_FRAME: [1-9]\d* assertions, 0 failures",
        "envelope": r"WB_AGENT_ENVELOPE: [1-9]\d* assertions, 0 failures",
        "failure-controls": r"WB_AGENT_FAILURE: [1-9]\d* assertions, 0 failures",
        "step": r"WB_AGENT_527_STEP: [1-9]\d* assertions, 0 failures",
        "step-paused-boundary": r"WB_AGENT_527_STEP: [1-9]\d* assertions, 0 failures",
        "native-owner": r"WB_AGENT_OWNER: [1-9]\d* assertions, 0 failures",
        "four-tool-join": r"WB_AGENT_527_JOIN: [1-9]\d* assertions, 0 failures",
        "signed-join": r"WB_AGENT_527_SIGNED_JOIN: [1-9]\d* assertions, 0 failures",
        "hopper": r"WB_AGENT_527_HOPPER_GODOT: [1-9]\d* assertions, 0 failures",
        "mounted-hopper": r"WB_AGENT_527_HOPPER_GODOT: [1-9]\d* assertions, 0 failures",
        "mounted": r"WB_AGENT_528 mounted real-native checks [1-9]\d*, failures 0",
        "capacity-camera": r"WB_AGENT_528 mounted real-native checks [1-9]\d*, failures 0",
        "manual-save": r"WB_AGENT_DISABLED: [1-9]\d* assertions, 0 failures, second_process=false",
        "manual-reopen": r"WB_AGENT_DISABLED: [1-9]\d* assertions, 0 failures, second_process=true",
        "render-bridge": r"Native RenderBridge regression passed; full [1-9]\d* bytes, delta [1-9]\d* bytes/[1-9]\d* patches",
    }
    if case == "import":
        return "Godot Engine v4.7.stable.official.5b4e0cb0f" in text
    if case == "manual-input":
        records = [json.loads(line.removeprefix("WORKBENCH_INPUT ")) for line in text.splitlines()
                   if line.startswith("WORKBENCH_INPUT ")]
        return len(records) == 1 and records[0].get("checks", 0) > 0 and records[0].get("failures") == []
    return len(re.findall(summaries[case], text)) == 1


def run(command: list[str], log: Path, timeout: int, env: dict, case: str) -> dict:
    start = time.monotonic()
    with log.open("wb") as output:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output,
                                 stderr=subprocess.STDOUT,
                                 start_new_session=os.name != "nt")
        timed_out = False
        try:
            code = child.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(child.pid), "/T", "/F"],
                               stdout=output, stderr=subprocess.STDOUT, timeout=30)
            else:
                os.killpg(child.pid, signal.SIGKILL)
            code = child.wait(timeout=30)
    text = log.read_text(encoding="utf-8", errors="replace")
    # Godot may return zero after a script load failure; never accept that.
    script_error = any(marker in text for marker in
                       ("SCRIPT ERROR:", "Parse Error:", "Failed to load script"))
    diagnostic_error = bool(re.search(r"^ERROR:", text, re.MULTILINE))
    summary_present = validate_output(text, case)
    return {"command": command, "timeout_seconds": timeout, "exit_code": code,
            "timed_out": timed_out, "script_error": script_error,
            "elapsed_seconds": round(time.monotonic() - start, 3),
            "diagnostic_error": diagnostic_error, "positive_summary_present": summary_present,
            "passed": code == 0 and not timed_out and not script_error and not diagnostic_error and summary_present,
            "log": str(log), "log_identity": digest(log)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path,
                        help="New evidence directory; existing paths are refused")
    parser.add_argument("--cases", nargs="+", choices=[c[0] for c in CASES])
    parser.add_argument("--xvfb", action="store_true", help="Use xvfb-run for graphical Linux cases")
    args = parser.parse_args()
    godot = args.godot.resolve(strict=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = identity(godot)
    (output / "source-runtime-before.json").write_text(json.dumps(before, indent=2) + "\n")
    fixture = ROOT / "native/tests/fixtures/wb_agent_sand_hopper_v2.tsv"
    if digest(fixture)["sha256"] != FIXTURE_SHA:
        raise ValueError("Frozen v2 manifest changed")
    runtime_fixture = ROOT / "godot/tests/wb-agent-527-v2-runtime.tsv"
    created_fixture = not runtime_fixture.exists()
    if not created_fixture and runtime_fixture.read_bytes() != fixture.read_bytes():
        raise ValueError("Refusing to replace different existing runtime fixture")
    if created_fixture:
        runtime_fixture.write_bytes(fixture.read_bytes())
    env = dict(os.environ)
    # Fake transport is selected inside existing tests; never pass a paid key.
    env.pop("OPENAI_API_KEY", None)
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    env["WB_AGENT_EVIDENCE_DIR"] = str(output)
    env["WB_AGENT_527_IMAGE_DIR"] = str(output)
    results = []
    try:
        cases = [("import", None, True, [])] + [c for c in CASES if not args.cases or c[0] in args.cases]
        for label, script, headless, extra in cases:
            command = [str(godot)]
            if headless:
                command += ["--headless"]
            elif args.xvfb:
                command = ["xvfb-run", "--auto-servernum", "--server-args=-screen 0 1920x1080x24 -nolisten tcp", *command]
            command += ["--path", str(ROOT / "godot")]
            command += ["--editor", "--import", "--quit"] if script is None else [
                "--rendering-method", "gl_compatibility", "--script", "res://tests/" + script, *extra]
            case_env = dict(env)
            case_env["WB_AGENT_DISABLED_REOPEN"] = "1" if label == "manual-reopen" else "0"
            case_output = output / label
            case_output.mkdir()
            case_env["WB_AGENT_EVIDENCE_DIR"] = str(case_output)
            case_env["WB_AGENT_527_IMAGE_DIR"] = str(case_output)
            result = run(command, output / (label + ".log"), 240 if headless else 420, case_env, label)
            result["case"] = label
            results.append(result)
            print(f"{label}: {'PASS' if result['passed'] else 'FAIL'} ({result['elapsed_seconds']}s)", flush=True)
            (output / "process-results.json").write_text(json.dumps(results, indent=2) + "\n")
            if label == "import" and not result["passed"]:
                break
    finally:
        if created_fixture:
            runtime_fixture.unlink()
    after = identity(godot)
    unchanged = before["source_files"] == after["source_files"] and before["runtimes"] == after["runtimes"]
    summary = {"head": before["head"], "source_and_runtimes_unchanged": unchanged,
               "all_processes_passed": all(r["passed"] for r in results),
               "genuine_api_trials": 0, "human_acceptance": "not supplied by automation",
               "signed_hopper": "experimental translated control, not literal signed trajectory acceptance",
               "artifacts": {str(p.relative_to(output)): digest(p) for p in output.rglob("*") if p.is_file()}}
    (output / "qualification.json").write_text(json.dumps(summary, indent=2) + "\n")
    return 0 if summary["all_processes_passed"] and unchanged else 1


if __name__ == "__main__":
    raise SystemExit(main())
