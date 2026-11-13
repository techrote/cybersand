#!/usr/bin/env python3
"""Independent source-bound Win32 Job Object attachment/lifetime diagnostic.

Evaluation-owned; never changes the integration bridge. The Windows runtime
probe deliberately widens the Popen -> AssignProcessToJobObject race by waiting
until a fake inference wrapper has spawned a descendant, then attaches its
parent to the real Job Object. This is a synthetic FILE side-effect probe, NOT
a native Art or model inference validation.

Usage from a checkout of combined PR #567 on Windows:
  py -3 experiments/wb-art-slm-001/evaluation/audit_windows_job_boundary.py \\
    --bridge experiments/wb-art-slm-001/integration/local_art_bridge.py \\
    --expected-blob e9df6e22a279868fd5e99e62650725fba5756fbe \\
    --out C:\\temp\\windows-job-independent.json

A deliberate orphan or an unverified Win32 execution yields status HOLD.
"""
from __future__ import annotations

import argparse
import ast
import ctypes
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def git_blob(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def inspect_source(path: Path, expected_blob: str) -> dict:
    data = path.read_bytes()
    actual = git_blob(data)
    if actual != expected_blob:
        raise ValueError("Source changed: expected Git blob %s, found %s" % (expected_blob, actual))
    tree = ast.parse(data.decode("utf-8"), filename=str(path))
    functions = {node.name: node for node in tree.body if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    classes = {node.name: node for node in tree.body if isinstance(node, ast.ClassDef)}
    run = functions.get("_run_owned_inference")
    job = classes.get("_WindowsOwnedProcessJob")
    if run is None or job is None:
        raise ValueError("Required owned-inference/Job Object source missing")
    calls = [(node.lineno, ast.unparse(node.func)) for node in ast.walk(run) if isinstance(node, ast.Call)]
    popen = [line for line, target in calls if target == "subprocess.Popen"]
    attach = [line for line, target in calls if target == "_WindowsOwnedProcessJob"]
    if len(popen) != 1 or len(attach) != 1:
        raise ValueError("Expected single Popen and Job attachment in source")
    factory = next(n for n in ast.walk(job) if isinstance(n, ast.FunctionDef) and n.name == "__init__")
    job_calls = [ast.unparse(n.func) for n in ast.walk(factory) if isinstance(n, ast.Call)]
    close = next(n for n in ast.walk(job) if isinstance(n, ast.FunctionDef) and n.name == "close")
    close_calls = [ast.unparse(n.func) for n in ast.walk(close) if isinstance(n, ast.Call)]
    return {
        "git_blob": actual, "popen_line": popen[0], "job_attach_line": attach[0],
        "popen_before_attachment": popen[0] < attach[0],
        "creation_suspended_requested": "CREATE_SUSPENDED" in ast.unparse(run),
        "assign_process_api_present": "api.AssignProcessToJobObject" in job_calls,
        "kill_on_job_close_bit_present": "0x00002000" in data.decode("utf-8"),
        "terminate_on_close": "self._api.TerminateJobObject" in close_calls,
        "close_handle_in_finally": "self._api.CloseHandle" in close_calls,
        "source_bound": True,
    }


def _terminate_by_pid(pid: int) -> None:
    """Best-effort teardown for synthetic orphan; no native/game process involved."""
    if os.name != "nt":
        return
    from ctypes import wintypes
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    k.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    k.OpenProcess.restype = wintypes.HANDLE
    k.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    k.TerminateProcess.restype = wintypes.BOOL
    k.CloseHandle.argtypes = [wintypes.HANDLE]
    k.CloseHandle.restype = wintypes.BOOL
    handle = k.OpenProcess(1, False, pid)  # PROCESS_TERMINATE
    if handle:
        try:
            k.TerminateProcess(handle, 1)
        finally:
            k.CloseHandle(handle)


def _windows_probe(bridge_file: Path) -> dict:
    """Run REAL source via fake inference children; no LoRA, Godot or native calls."""
    if os.name != "nt":
        return {"executed": False, "reason": "Windows-only: no Win32 Job Object execution on this host"}
    spec = importlib.util.spec_from_file_location("wb_art_bridge_under_review", bridge_file)
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load bridge source")
    bridge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bridge)
    from ctypes import wintypes
    layout = {"pointer_bits": ctypes.sizeof(ctypes.c_void_p) * 8,
              "DWORD_bytes": ctypes.sizeof(wintypes.DWORD),
              "HANDLE_bytes": ctypes.sizeof(wintypes.HANDLE)}
    if layout["DWORD_bytes"] != 4 or layout["HANDLE_bytes"] != ctypes.sizeof(ctypes.c_void_p):
        raise RuntimeError("Unexpected Windows ABI types for Job Object source")

    results = {}
    with tempfile.TemporaryDirectory(prefix="wb-art-winjob-independent-") as td:
        root = Path(td)
        child = root / "grandchild.py"
        child.write_text(
            "import os,pathlib,sys,time\n"
            "ready,late,pid = map(pathlib.Path,sys.argv[1:4])\n"
            "pid.write_text(str(os.getpid()))\n"
            "ready.write_text('child running before parent job assignment')\n"
            "time.sleep(2.0)\n"
            "late.write_text('descendant survived cancellation')\n",
            encoding="utf-8")
        parent = root / "wrapper.py"
        parent.write_text(
            "import subprocess,sys,time\n"
            "child,ready,late,pid = sys.argv[1:5]\n"
            "subprocess.Popen([sys.executable,child,ready,late,pid], "
            "stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
            "time.sleep(8)\n", encoding="utf-8")

        real_job = bridge._WindowsOwnedProcessJob
        for case in ("forced_preassignment", "assignment_refusal"):
            ready, late, pidfile = (root / (case + n) for n in ("-ready", "-late", "-pid"))
            childpid = None
            attachment_count = [0]
            closure_count = [0]
            class CountedJob:
                def __init__(self, process):
                    attachment_count[0] += 1
                    end = time.monotonic() + 5
                    while not ready.is_file() and time.monotonic() < end:
                        time.sleep(0.02)
                    if not ready.is_file():
                        raise RuntimeError("descendant did not start before forced attachment")
                    if case == "assignment_refusal":
                        raise OSError("independently injected Job assignment refusal")
                    self.job = real_job(process)
                def close(self):
                    closure_count[0] += 1
                    self.job.close()
            bridge._WindowsOwnedProcessJob = CountedJob
            command = [sys.executable, str(parent), str(child), str(ready), str(late), str(pidfile)]
            refusal, code = None, None
            try:
                with (root / (case + ".log")).open("wb") as log:
                    try:
                        code = bridge._run_owned_inference(
                            command, log, 7, cancellation_probe=lambda: True)
                    except bridge.BridgeRefusal as exc:
                        refusal = str(exc)
                time.sleep(2.4)
                if pidfile.is_file():
                    childpid = int(pidfile.read_text().strip())
                results[case] = {
                    "descendant_started_before_attachment": ready.is_file(),
                    "late_file_side_effect": late.is_file(),
                    "refused_art_response": refusal is not None,
                    "refusal_message": refusal,
                    "unexpected_success_code": code,
                    "job_factory_invocations": attachment_count[0],
                    "job_close_invocations": closure_count[0],
                }
            finally:
                bridge._WindowsOwnedProcessJob = real_job
                if childpid:
                    _terminate_by_pid(childpid)
    return {"executed": True, "abi": layout, "cases": results}


def evaluate(bridge_file: Path, expected_blob: str) -> dict:
    source = inspect_source(bridge_file, expected_blob)
    execution = _windows_probe(bridge_file)
    cases = execution.get("cases", {})
    violations = [name for name, result in cases.items() if result.get("late_file_side_effect")]
    return {
        "scope": "synthetic Windows inference descendant lifetime only; no real model, Art operation or native World",
        "source": source, "windows": execution,
        "escaped_descendant_cases": violations,
        "decision": "HOLD" if not execution.get("executed") or violations else "GO for tested Windows synthetic cases only",
        "raw_model_improvement": False,
        "native_world_qualified": False,
        "human_acceptance": False,
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bridge", required=True, type=Path)
    ap.add_argument("--expected-blob", required=True)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args(argv)
    result = evaluate(args.bridge, args.expected_blob)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["decision"].startswith("GO") else 1


if __name__ == "__main__":
    raise SystemExit(main())