#!/usr/bin/env python3
"""Local/GitHub-hosted CyberSand remote-workbench session launcher.

This is a trusted process launcher, NOT an agent tool. Agent-visible requests
remain limited to the five JSONL verbs; authorization is loaded once separately.
No OpenAI client, API key, network server, or extra World is created here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT_PROJECT = ROOT / "godot"
GODOT_SCRIPT = "res://tools/remote_workbench_batch.gd"
NATIVE = GODOT_PROJECT / "addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
RAPIER = GODOT_PROJECT / "addons/godot-rapier2d/bin/libgodot_rapier.linux.x86_64-unknown-linux-gnu.so"
SESSION_TIMEOUT_MAX = 1840
MAX_INPUT_BYTES = 262144


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def verify_file(path: Path, *, binary: bool = False) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Missing required input: {path}")
    if binary and (path.stat().st_size < 1024 or
                   path.read_bytes()[:80].startswith(b"version https://git-lfs")):
        raise ValueError(f"Unmaterialized runtime, not executable binary: {path}")


def validate_authorization(path: Path) -> dict:
    verify_file(path)
    if path.stat().st_size > MAX_INPUT_BYTES:
        raise ValueError("Host authorization file is over the session input limit")
    obj = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict) or obj.get("version") != 1:
        raise ValueError("Host authorization must be a version-1 object")
    if not isinstance(obj.get("task_id"), str) or not (1 <= len(obj["task_id"]) <= 128):
        raise ValueError("Host task_id is required and bounded")
    for key in ("extent", "scope", "protected", "allowed_materials"):
        if key not in obj:
            raise ValueError(f"Missing host-only authorization field: {key}")
    if not isinstance(obj["allowed_materials"], list) or not obj["allowed_materials"] or any(
        type(i) is not int or i not in (0, 58) for i in obj["allowed_materials"]
    ):
        raise ValueError("Agent outputs may only be Empty(0)/Hard Wall(58)")
    return obj


def validate_commands(path: Path, live: bool) -> None:
    if live and not path.exists():
        path.touch()
    verify_file(path) if not live else None
    if path.stat().st_size > MAX_INPUT_BYTES:
        raise ValueError("Command stream is too large")
    if live:
        return  # A running session validates each newly appended complete line.
    raw = path.read_text(encoding="utf-8")
    if not raw.endswith("\n"):
        raise ValueError("Batch JSONL must terminate with a newline")
    seen = 0
    for line in raw.splitlines():
        if not line.strip():
            continue
        seen += 1
        command = json.loads(line)
        if not isinstance(command, dict) or command.get("version") != 1:
            raise ValueError(f"Invalid versioned command {seen}")
        if type(command.get("seq")) is not int or command["seq"] <= 0:
            raise ValueError(f"Invalid monotonic sequence {seen}")
        if command.get("tool") not in ("observe", "prepare_edit", "apply_edit", "step", "stop"):
            raise ValueError(f"Unsupported tool in command {seen}")
        if not isinstance(command.get("args", {}), dict):
            raise ValueError(f"Invalid tool argument object {seen}")
    if not 1 <= seen <= 96:
        raise ValueError("Must supply 1-96 bounded batch commands")


def build_command(godot: Path, authorization: Path, commands: Path, evidence: Path,
                  live: bool, xvfb: bool) -> list[str]:
    command = [
        str(godot), "--path", str(GODOT_PROJECT),
        "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
        "--script", GODOT_SCRIPT, "--",
        f"--authorization={authorization}", f"--commands={commands}",
        f"--output={evidence}",
    ]
    if live:
        command.append("--live")
    if xvfb:
        if not shutil.which("xvfb-run"):
            raise ValueError("--xvfb requested but xvfb-run is unavailable")
        command = [
            "xvfb-run", "--auto-servernum",
            "--server-args=-screen 0 1920x1080x24 -nolisten tcp", *command,
        ]
    return command


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True,
                        help="Official Godot 4.7 editor executable, never --headless")
    parser.add_argument("--authorization", type=Path, required=True,
                        help="Host-owned task, protection and initial construction JSON")
    parser.add_argument("--commands", type=Path, required=True,
                        help="Append-only command JSONL; not an authorization source")
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--live", action="store_true",
                        help="Keep one Godot/World alive for appended commands")
    parser.add_argument("--xvfb", action="store_true",
                        help="Run actual display-backed OpenGL on hosted Linux")
    parser.add_argument("--timeout", type=int, default=480)
    args = parser.parse_args(argv)
    if not 10 <= args.timeout <= SESSION_TIMEOUT_MAX:
        parser.error("--timeout must be in [10,1840] seconds")
    godot = args.godot.resolve(strict=True)
    auth = args.authorization.resolve(strict=True)
    cmd_path = args.commands.resolve(strict=not args.live)
    evidence = args.evidence.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        parser.error("evidence directory must be empty; prior evidence is immutable")
    for path in (godot, auth):
        verify_file(path)
    if os.name != "posix":
        parser.error("this first-stage launcher currently targets Linux; use the Windows owner bundle separately")
    verify_file(NATIVE, binary=True)
    verify_file(RAPIER, binary=True)
    authorization = validate_authorization(auth)
    validate_commands(cmd_path, args.live)
    evidence.mkdir(parents=True, exist_ok=True)
    run_id = {
        "source_commit": git("rev-parse", "HEAD"),
        "source_tree": git("rev-parse", "HEAD^{tree}"),
        "source_status": git("status", "--porcelain=v1"),
        "platform": platform.platform(),
        "python": sys.version,
        "host_authorization_sha256": sha256(auth),
        "commands_initial_sha256": sha256(cmd_path),
        "runtime_hashes": {
            "native": sha256(NATIVE), "rapier": sha256(RAPIER),
            "godot": sha256(godot),
        },
        "mode": "live" if args.live else "batch",
        "task_id": authorization["task_id"],
        "budget": {"maximum_commands": 96, "maximum_completed_native_ticks": 480,
                   "timeout_seconds": args.timeout},
        "paid_api_calls": 0,
    }
    (evidence / "launcher-identity.json").write_text(
        json.dumps(run_id, indent=2) + "\n", encoding="utf-8"
    )
    # Retain the exact bytes supplied at launch, including refusal controls.
    shutil.copyfile(auth, evidence / "host-authorization.json")
    shutil.copyfile(cmd_path, evidence / "commands-at-launch.jsonl")
    env = os.environ.copy()
    for key in list(env):
        if key.upper() in ("OPENAI_API_KEY", "OPENAI_ADMIN_KEY"):
            env.pop(key)
    env.update({
        "CYBERSAND_SOURCE_SHA": run_id["source_commit"],
        "CYBERSAND_SOURCE_TREE": run_id["source_tree"],
        "CYBERSAND_NATIVE_SHA256": run_id["runtime_hashes"]["native"],
        "CYBERSAND_RAPIER_SHA256": run_id["runtime_hashes"]["rapier"],
        "CYBERSAND_GODOT_SHA256": run_id["runtime_hashes"]["godot"],
        "GODOT_SILENCE_ROOT_WARNING": "1",
    })
    invocation = build_command(godot, auth, cmd_path, evidence, args.live, args.xvfb)
    (evidence / "invocation.json").write_text(
        json.dumps({"argv": invocation, "cwd": str(ROOT), "live_session": args.live},
                   indent=2) + "\n", encoding="utf-8"
    )
    started = time.monotonic()
    timed_out = False
    with (evidence / "godot.log").open("wb") as log:
        try:
            proc = subprocess.run(invocation, cwd=ROOT, env=env,
                                  stdout=log, stderr=subprocess.STDOUT,
                                  timeout=args.timeout, check=False)
            exit_code = proc.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
            exit_code = 124
    outcome = {
        "exit_code": exit_code, "timed_out": timed_out,
        "elapsed_seconds": time.monotonic() - started,
        "retained_original_log": "godot.log",
    }
    (evidence / "process-result.json").write_text(
        json.dumps(outcome, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"evidence": str(evidence), **outcome}, sort_keys=True))
    return 0 if exit_code == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
