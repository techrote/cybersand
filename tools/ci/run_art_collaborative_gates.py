#!/usr/bin/env python3
"""Run the complete collaborative Art contract suite at one committed source.

These are deterministic loopback, copied-value and actual native fixtures, not
real-model creativity. The predecessor Art lifecycle matrix is a separate required
workflow stage. Each case uses a fresh process and a fresh package-local profile.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "art-collaborative-gates-v1"
TESTS = {
    "test_art_owned_transport": "ART_OWNED_TRANSPORT_RESULT",
    "test_art_authoring_proposal": "ART_PROPOSAL_RESULT",
    "test_art_collaborative_native": "ART_COLLABORATIVE_NATIVE_RESULT",
    "test_art_collaboration_authority": "ART_COLLABORATION_AUTHORITY_RESULT",
    "test_art_collaboration_session": "ART_COLLABORATION_SESSION_RESULT",
    "test_art_collaboration_workspace": "ART_COLLABORATION_UI_RESULT",
}
REQUIRED_TESTS = frozenset(TESTS)
RUNTIME_PATHS = {
    "linux": (
        "godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so",
        "godot/addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so",
    ),
    "windows": (
        "godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll",
        "godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll",
    ),
}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, timeout=60).strip()


def source_identity() -> dict:
    tracked = git("status", "--porcelain=v1", "--untracked-files=no")
    if tracked:
        raise ValueError("Commit tracked source changes before this qualification campaign")
    return {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "tracked_source_clean": True}


def parse_case_output(text: str, marker: str) -> dict:
    rows = [line.split(marker, 1)[1].strip() for line in text.splitlines() if line.startswith(marker + " ")]
    if len(rows) != 1:
        raise ValueError("Expected exactly one complete result marker: " + marker)
    result = json.loads(rows[0])
    if not isinstance(result, dict) or not isinstance(result.get("checks"), int) or result["checks"] <= 0:
        raise ValueError("Missing positive assertion count: " + marker)
    if not isinstance(result.get("failures"), list) or result["failures"]:
        raise ValueError("Reported test failure: " + marker)
    if result.get("model_calls", 0) != 0:
        raise ValueError("This fixture cohort cannot claim genuine model calls")
    return result


def validate_receipt(receipt: dict, *, commit: str, tree: str, platform_name: str,
                     graphical: bool) -> dict:
    if not isinstance(receipt, dict) or receipt.get("schema") != SCHEMA:
        raise ValueError("Unexpected collaborative qualification schema")
    if receipt.get("status") != "passed" or receipt.get("model_calls") != 0:
        raise ValueError("Collaborative qualification did not pass the fixture-only contract")
    if receipt.get("source") != {"commit": commit, "tree": tree, "tracked_source_clean": True}:
        raise ValueError("Collaborative evidence source differs from the package")
    if receipt.get("platform") != platform_name or receipt.get("graphical") is not graphical:
        raise ValueError("Collaborative evidence platform/display scope differs")
    cases = receipt.get("cases")
    if not isinstance(cases, list) or len(cases) != len(REQUIRED_TESTS):
        raise ValueError("Incomplete collaborative test matrix")
    names = [case.get("name") for case in cases if isinstance(case, dict)]
    if len(names) != len(cases) or len(set(names)) != len(names) or set(names) != REQUIRED_TESTS:
        raise ValueError("Missing, duplicate or unknown collaborative test case")
    for case in cases:
        if case.get("status") != "passed" or case.get("exit_code") != 0 or case.get("timed_out"):
            raise ValueError("Failed or unexecuted collaborative test: " + case["name"])
        if case.get("marker") != TESTS[case["name"]]:
            raise ValueError("Case marker identity differs")
        result = case.get("result")
        if not isinstance(result, dict) or not isinstance(result.get("checks"), int) or result["checks"] <= 0:
            raise ValueError("Case assertion proof is absent")
        if result.get("failures") != [] or result.get("model_calls", 0) != 0:
            raise ValueError("Case contains a failure or a model-call claim")
        if not re.fullmatch(r"[0-9a-f]{64}", str(case.get("log_sha256", ""))):
            raise ValueError("Case log identity is absent")
    runtime = receipt.get("runtime")
    if not isinstance(runtime, dict) or set(runtime.get("payloads", {})) != set(RUNTIME_PATHS[platform_name]):
        raise ValueError("Source-matched native and Rapier runtime identities are absent")
    if not all(re.fullmatch(r"[0-9a-f]{64}", str(value)) for value in runtime["payloads"].values()):
        raise ValueError("Invalid runtime digest")
    if not re.fullmatch(r"[0-9a-f]{64}", str(runtime.get("godot_sha256", ""))):
        raise ValueError("Godot executable identity is absent")
    if runtime.get("godot_version") != "4.7.stable.official.5b4e0cb0f":
        raise ValueError("Collaborative evidence uses a different Godot pin")
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=ROOT / "godot")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--graphical", action="store_true")
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError("Use a new output directory to retain prior attempts")
    output.mkdir(parents=True)
    platform_name = "windows" if os.name == "nt" else "linux"
    source = source_identity()
    godot = args.godot.resolve()
    project = args.project.resolve()
    if project != (ROOT / "godot").resolve():
        raise ValueError("This campaign must execute its own source tree")
    runtime = {"godot_sha256": digest(godot),
               "godot_version": subprocess.check_output([str(godot), "--version"], text=True, timeout=30).strip(),
               "payloads": {path: digest(ROOT / path) for path in RUNTIME_PATHS[platform_name]},
               "provenance_sha256": digest(ROOT / "godot/addons/cybersand_native/runtime-provenance.json")}
    receipt = {"schema": SCHEMA, "source": source, "platform": platform_name,
               "graphical": args.graphical, "runtime": runtime, "model_calls": 0,
               "evidence_kind": "deterministic loopback and native fixtures; not genuine model creativity",
               "host": {"platform": platform.platform(), "machine": platform.machine(),
                        "processor": platform.processor(), "logical_cpus": os.cpu_count()},
               "status": "running", "cases": []}
    receipt_path = output / "summary.json"
    def save() -> None:
        receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    save()
    for name, marker in TESTS.items():
        case_dir = output / name
        case_dir.mkdir()
        profile = case_dir / "profile"
        profile.mkdir()
        env = dict(os.environ, XDG_DATA_HOME=str(profile), APPDATA=str(profile),
                   LOCALAPPDATA=str(profile / "local"),
                   WB_ART_COLLAB_UI_EVIDENCE=str(case_dir),
                   WB_ART_COLLAB_EVIDENCE=str(case_dir),
                   CYBERSAND_TEST_ARTIFACT_DIR=str(case_dir),
                   CYBERSAND_SOURCE_REVISION=source["commit"])
        command = [str(godot), "--path", str(project), "--audio-driver", "Dummy"]
        if not args.graphical:
            command.append("--headless")
        else:
            command += ["--rendering-method", "gl_compatibility"]
            if os.name == "nt":
                command += ["--rendering-driver", "opengl3_angle"]
        command += ["--script", "res://tests/" + name + ".gd"]
        began = time.monotonic()
        timed_out = False
        exit_code = None
        log = case_dir / "process.log"
        error = ""
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
            try:
                exit_code = process.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   stdout=stream, stderr=subprocess.STDOUT, timeout=30, check=False)
                else:
                    process.kill()
                process.wait(timeout=30)
        text = log.read_text(encoding="utf-8", errors="replace")
        result = {}
        try:
            if timed_out or exit_code != 0 or "SCRIPT ERROR:" in text or "Parse Error:" in text:
                raise ValueError("Process failed, timed out or emitted a script error")
            result = parse_case_output(text, marker)
        except (ValueError, json.JSONDecodeError) as failure:
            error = str(failure)
        case = {"name": name, "marker": marker, "command": command,
                "exit_code": exit_code, "timed_out": timed_out, "timeout_seconds": args.timeout,
                "elapsed_seconds": round(time.monotonic() - began, 6),
                "log_sha256": digest(log), "result": result,
                "artifacts_sha256": {path.name: digest(path) for path in sorted(case_dir.iterdir())
                                    if path.is_file() and path.suffix in (".json", ".png")},
                "status": "failed" if error else "passed", "error": error}
        receipt["cases"].append(case)
        save()
        print(json.dumps({"case": name, "status": case["status"], "elapsed_seconds": case["elapsed_seconds"],
                          "checks": result.get("checks", 0), "error": error}), flush=True)
    receipt["status"] = "passed" if all(case["status"] == "passed" for case in receipt["cases"]) else "failed"
    # Detect any tracked mutation by the application before accepting source custody.
    try:
        if source_identity() != source:
            receipt["status"] = "failed"
            receipt["source_changed_during_run"] = True
    except ValueError as error:
        receipt["status"] = "failed"
        receipt["source_changed_during_run"] = True
        receipt["source_error"] = str(error)
    save()
    if receipt["status"] == "passed":
        validate_receipt(receipt, commit=source["commit"], tree=source["tree"],
                         platform_name=platform_name, graphical=args.graphical)
    print("ART_COLLABORATIVE_GATES " + json.dumps({"status": receipt["status"], "summary": str(receipt_path)}))
    return 0 if receipt["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
