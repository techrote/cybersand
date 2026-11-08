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
import re
import signal
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
MIN_SESSION_TIMEOUT = 60
# The Godot deadline includes startup; this much wall time remains for Stop,
# manifest flush, termination and process-tree escalation.
SESSION_CLEANUP_RESERVE_SECONDS = 30
TERM_GRACE_SECONDS = 5
KILL_GRACE_SECONDS = 3
MAX_INPUT_BYTES = 262144
DEFAULT_EVIDENCE_LIMIT_BYTES = 128 * 1024 * 1024
MIN_EVIDENCE_LIMIT_BYTES = 16 * 1024 * 1024
MAX_EVIDENCE_LIMIT_BYTES = 512 * 1024 * 1024
TERMINAL_EVIDENCE_RESERVE_BYTES = 65536


class SessionInterrupted(Exception):
    pass


def atomic_json(path: Path, value: dict) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def validate_canvas_extent(value: object) -> None:
    """Fail closed against the *current* Setup.validate source, not a stale fork.

    The Godot side independently invokes Setup.validate on a fresh setup too.
    A changed/removed Setup rule requires an explicit adapter review.
    """
    source = (GODOT_PROJECT / "scripts/workbench_setup.gd").read_text(encoding="utf-8")
    validate = source.split("static func validate(", 1)
    if len(validate) != 2:
        raise ValueError("Cannot locate authoritative Setup.validate canvas policy")
    policy = re.search(
        r"if not _integer\(side,\s*(\d+),\s*(\d+)\) or int\(side\) % (\d+) != 0:",
        validate[1].split("static func ", 1)[0],
    )
    if policy is None:
        raise ValueError("Authoritative Setup.validate extent rule changed; review required")
    low, high, alignment = (int(x) for x in policy.groups())
    if (not isinstance(value, list) or len(value) != 2 or
            any(type(side) is not int or side < low or side > high or
                side % alignment != 0 for side in value)):
        raise ValueError(
            f"Canvas extent violates Setup.validate: each side {low}-{high}, multiple of {alignment}"
        )


def evidence_size(folder: Path) -> int:
    total = 0
    for root, _, filenames in os.walk(folder):
        for filename in filenames:
            try:
                total += (Path(root) / filename).stat().st_size
            except FileNotFoundError:
                pass
    return total


def group_exists(pgid: int) -> bool:
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def cleanup_process_tree(proc: subprocess.Popen, reason: str) -> dict:
    """Only signal the session group created by Popen(start_new_session=True)."""
    pgid = proc.pid
    initially_alive = group_exists(pgid)
    sent_term = sent_kill = False
    if initially_alive:
        try:
            os.killpg(pgid, signal.SIGTERM)
            sent_term = True
        except ProcessLookupError:
            pass
        until = time.monotonic() + TERM_GRACE_SECONDS
        while time.monotonic() < until and group_exists(pgid):
            time.sleep(0.05)
        if group_exists(pgid):
            try:
                os.killpg(pgid, signal.SIGKILL)
                sent_kill = True
            except ProcessLookupError:
                pass
            until = time.monotonic() + KILL_GRACE_SECONDS
            while time.monotonic() < until and group_exists(pgid):
                time.sleep(0.05)
    try:
        proc.wait(timeout=1)
    except subprocess.TimeoutExpired:
        pass
    return {
        "session_process_group": pgid,
        "reason": reason,
        "group_present_before_cleanup": initially_alive,
        "sent_sigterm": sent_term,
        "sent_sigkill": sent_kill,
        "owned_processes_exited": not group_exists(pgid),
        "launcher_child_reaped": proc.poll() is not None,
        "launcher_child_returncode": proc.poll(),
    }


def supervise(invocation: list[str], env: dict, log, evidence: Path,
              timeout: int, limit: int) -> tuple[int, str, dict]:
    process = None
    started = time.monotonic()
    reason = "spawn_failed"
    previous_handlers = {}
    def interrupted(signum, _frame):
        raise SessionInterrupted(f"signal_{signal.Signals(signum).name.lower()}")
    for signum in (signal.SIGINT, signal.SIGTERM):
        previous_handlers[signum] = signal.signal(signum, interrupted)
    try:
        process = subprocess.Popen(
            invocation, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
        )
        while True:
            remaining = timeout - (time.monotonic() - started)
            if remaining <= 0:
                reason = "timeout"
                break
            if evidence_size(evidence) > limit - TERMINAL_EVIDENCE_RESERVE_BYTES:
                reason = "evidence_budget_exhausted"
                break
            try:
                code = process.wait(timeout=min(remaining, 0.25))
                reason = "normal_exit" if code == 0 else "engine_failure"
                break
            except subprocess.TimeoutExpired:
                continue
    except SessionInterrupted as exc:
        reason = str(exc)
    finally:
        # No SIGTERM handler may interrupt the controlled shutdown itself.
        for signum in previous_handlers:
            signal.signal(signum, signal.SIG_IGN)
        cleanup = (cleanup_process_tree(process, reason) if process is not None else
                   {"reason": reason, "owned_processes_exited": False,
                    "launcher_child_reaped": False})
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)
    return (process.returncode if reason == "normal_exit" and
            cleanup["owned_processes_exited"] else
            124 if reason == "timeout" else
            125 if reason.startswith("signal_") else
            126 if reason == "evidence_budget_exhausted" else 3), reason, cleanup



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
    validate_canvas_extent(obj["extent"])
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
                  live: bool, xvfb: bool, deadline_seconds: int = 450) -> list[str]:
    command = [
        str(godot), "--path", str(GODOT_PROJECT),
        "--audio-driver", "Dummy", "--rendering-method", "gl_compatibility",
        "--script", GODOT_SCRIPT, "--",
        f"--authorization={authorization}", f"--commands={commands}",
        f"--output={evidence}", f"--deadline-seconds={deadline_seconds}",
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
    parser.add_argument("--timeout", type=int, default=480,
                        help="Total hard wall deadline including 30s native/cleanup reserve")
    parser.add_argument("--evidence-limit-bytes", type=int,
                        default=DEFAULT_EVIDENCE_LIMIT_BYTES,
                        help="Host-only cumulative evidence cap, including log and PNGs")
    args = parser.parse_args(argv)
    if not MIN_SESSION_TIMEOUT <= args.timeout <= SESSION_TIMEOUT_MAX:
        parser.error("--timeout must be in [60,1840] seconds including cleanup reserve")
    if not MIN_EVIDENCE_LIMIT_BYTES <= args.evidence_limit_bytes <= MAX_EVIDENCE_LIMIT_BYTES:
        parser.error("--evidence-limit-bytes must be in [16MiB,512MiB]")
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
                   "timeout_seconds": args.timeout,
                   "internal_deadline_seconds": args.timeout - SESSION_CLEANUP_RESERVE_SECONDS,
                   "cleanup_reserve_seconds": SESSION_CLEANUP_RESERVE_SECONDS,
                   "total_evidence_bytes": args.evidence_limit_bytes},
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
        "CYBERSAND_EVIDENCE_LIMIT_BYTES": str(args.evidence_limit_bytes),
    })
    invocation = build_command(
        godot, auth, cmd_path, evidence, args.live, args.xvfb,
        args.timeout - SESSION_CLEANUP_RESERVE_SECONDS,
    )
    (evidence / "invocation.json").write_text(
        json.dumps({"argv": invocation, "cwd": str(ROOT), "live_session": args.live},
                   indent=2) + "\n", encoding="utf-8"
    )
    started = time.monotonic()
    with (evidence / "godot.log").open("wb") as log:
        exit_code, reason, cleanup = supervise(
            invocation, env, log, evidence, args.timeout, args.evidence_limit_bytes
        )
    timed_out = reason == "timeout"
    atomic_json(evidence / "cleanup-result.json", cleanup)
    try:
        health = json.loads((evidence / "session-health.json").read_text())
    except (OSError, ValueError, TypeError):
        health = {}
    health.update({
        "launcher_alive": False, "state": "exited" if exit_code == 0 else "failed",
        "shutdown_reason": reason, "process_group_exited": cleanup["owned_processes_exited"],
        "launcher_child_reaped": cleanup["launcher_child_reaped"],
    })
    atomic_json(evidence / "session-health.json", health)
    if not cleanup["owned_processes_exited"]:
        exit_code = 3
    # An uncaught engine/runtime exception can abort a GDScript coroutine
    # before it records a native receipt. The outer launcher must fail closed
    # even when Godot itself exits zero.
    if exit_code == 0:
        try:
            manifest = json.loads((evidence / "manifest.json").read_text(encoding="utf-8"))
            if (manifest.get("result") != "passed"
                    or manifest.get("stopped") is not True
                    or manifest.get("command_count", 0) < 1
                    or not manifest.get("frames", [])
                    or manifest.get("failures")):
                exit_code = 3
        except (OSError, ValueError, TypeError):
            exit_code = 3
    outcome = {
        "exit_code": exit_code, "timed_out": timed_out,
        "elapsed_seconds": time.monotonic() - started,
        "retained_original_log": "godot.log",
        "shutdown_reason": reason,
        "process_group_exited": cleanup["owned_processes_exited"],
        "evidence_bytes": evidence_size(evidence),
    }
    (evidence / "process-result.json").write_text(
        json.dumps(outcome, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"evidence": str(evidence), **outcome}, sort_keys=True))
    return 0 if exit_code == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
