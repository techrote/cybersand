#!/usr/bin/env python3
"""Run the original PLAY-BUSY-001C host once and retain process custody."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import time

import execution_policy
import godot_process_monitor as monitor
import godot_timeout_diagnostics as diagnostics
from play_busy001c_process import ProcessCustody


CASE = "play_busy001c_render"
ABSOLUTE_TIMEOUT_SECONDS = 120
PROTOCOL_BUDGETS = {
    "absolute_seconds": ABSOLUTE_TIMEOUT_SECONDS,
    "progress_snapshot_seconds": 30,
    "progress_fail_seconds": 45,
}


def parent_seconds() -> int:
    """The parent reserves cleanup; the child's original 120s never changes."""
    return int(ABSOLUTE_TIMEOUT_SECONDS + execution_policy.godot_process_cleanup_seconds())


def identity(path: Path) -> dict:
    path = path.resolve(strict=True)
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return {"path": str(path), "size": path.stat().st_size, "sha256": digest.hexdigest()}


def write_receipt(path: Path, value: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def cache_inventory() -> dict:
    # Observe only: no prewarming, cache deletion or retry. Driver-internal and
    # global caches are deliberately unknown rather than inferred to be cold.
    root = Path("godot/.godot/shader_cache")
    files = [identity(path) for path in sorted(root.rglob("*")) if path.is_file()] if root.exists() else []
    return {"project_shader_cache_present": root.exists(), "project_shader_cache": files,
            "driver_cache_state": "unknown", "policy": "observed-not-modified"}


def _spawn_render_child(command: list[str], log, environment=None):
    """Keep timeout cleanup separate from the runner/Xvfb process group."""
    return subprocess.Popen(
        command, stdout=log, stderr=subprocess.STDOUT,
        env=os.environ.copy() if environment is None else environment,
        start_new_session=(sys.platform != "win32"),
    )


def reported_engine_pid(path: Path, nonce: str, source_sha: str, *, final: bool = False) -> int | None:
    rows = []
    output = path.read_text(encoding="utf-8", errors="replace")
    # A concurrent file-backed read can end in a partially written JSON line.
    # It is not evidence until terminated; after process exit it must be whole.
    lines = output.splitlines()
    if not final and output and not output.endswith(("\n", "\r")):
        lines = lines[:-1]
    for line in lines:
        if line.startswith("PLAY_BUSY001C_PROGRESS "):
            row = json.loads(line.split(" ", 1)[1])
            if row.get("stage") == "display_ready":
                rows.append(row)
    if not rows:
        return None
    if len(rows) != 1:
        raise ValueError("duplicated original display/process identity")
    row = rows[0]
    pid = row.get("process_pid")
    if (type(pid) is not int or pid <= 0 or row.get("process_nonce") != nonce
            or row.get("source_sha") != source_sha):
        raise ValueError("original display/process identity mismatch")
    return pid


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--rapier", type=Path, required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha):
        raise ValueError("source-sha must identify an exact Git commit")
    actual_source = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True, timeout=10).strip()
    if actual_source != args.source_sha:
        raise ValueError("checkout differs from requested exact source")
    source_tree = subprocess.check_output(["git", "rev-parse", "HEAD^{tree}"], text=True, timeout=10).strip()
    if (sys.platform == "win32") != (args.platform == "windows"):
        raise ValueError("requested platform is not the executing host")
    args.output.mkdir(parents=True, exist_ok=True)
    log_path = args.output / "render-execution.log"
    receipt_path = args.output / "render-process.json"
    diagnostic_path = args.output / "render-diagnostics"
    evidence = Path(os.environ["CYBERSAND_PLAY_BUSY_RENDER_EVIDENCE"])
    evidence.mkdir(parents=True, exist_ok=True)
    if log_path.exists() or receipt_path.exists() or any(evidence.iterdir()):
        raise ValueError("refusing to overwrite/retry an existing original execution")

    # Keep the exact historical graphical invocation, including the Windows
    # console wrapper. The external observer records its real engine descendant.
    command = [str(args.godot.resolve()), "--windowed", "--resolution", "960x540",
               "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"]
    if args.platform == "linux":
        command += ["--display-driver", "x11"]
    command += ["--path", "godot", "--script", "res://tests/play_busy001c_render.gd"]
    engine = args.godot
    if args.platform == "windows":
        if not engine.name.endswith("_console.exe"):
            raise ValueError("expected the pinned Windows console owner")
        engine = engine.with_name(engine.name.replace("_console.exe", ".exe"))
    nonce = secrets.token_hex(16)
    environment = os.environ.copy()
    environment.update(CYBERSAND_PLAY_BUSY_NONCE=nonce, CYBERSAND_PLAY_BUSY_SOURCE_SHA=args.source_sha)
    runtime_paths = {"engine": engine, "launcher": args.godot, "runtime": args.runtime, "rapier": args.rapier}
    receipt = {
        "schema": "play-busy001c-process-v1", "source_sha": args.source_sha,
        "source_tree": source_tree, "platform": args.platform, "nonce": nonce,
        "argv": command, "cwd": str(Path.cwd().resolve()), "budgets": PROTOCOL_BUDGETS,
        "parent_seconds": parent_seconds(), "pid": None, "launcher_pid": None,
        "returncode": None, "timed_out": False, "timeout_kind": None,
        "forced_cleanup": False, "cleanup_complete": False, "status": "incomplete",
        "observed_processes": {}, "identities": {key: identity(path) for key, path in runtime_paths.items()},
        "render_environment": {key: environment.get(key) for key in (
            "LIBGL_ALWAYS_SOFTWARE", "LP_NUM_THREADS", "GALLIVM_PERF", "DISPLAY",
            "MESA_SHADER_CACHE_DISABLE", "MESA_SHADER_CACHE_DIR", "XDG_CACHE_HOME")},
        "cache_before": cache_inventory(), "qualification": "original-host-process",
    }
    write_receipt(receipt_path, receipt)
    child, custody, error = None, None, None
    started = time.perf_counter()
    try:
        custody = ProcessCustody(args.platform)
        with log_path.open("x", encoding="utf-8") as log:
            child = _spawn_render_child(command, log, environment)
            receipt["launcher_pid"] = child.pid
            write_receipt(receipt_path, receipt)

            def sample(pid):
                custody.observe(pid)
                reported = reported_engine_pid(log_path, nonce, args.source_sha)
                if reported is not None:
                    receipt["pid"] = reported

            sample(child.pid)

            def capture_factory(pid, output, context):
                capture = monitor._Capture(pid, output, context)
                # This child is explicitly created by our diagnostic owner, not
                # an unexplained orphan and never the qualifying engine.
                try:
                    custody.register_auxiliary(capture.child.pid)
                except Exception:
                    capture.close("diagnostic process custody registration failed")
                    raise
                return capture

            timed_out, timeout_kind, capture_error = monitor.wait(
                child, CASE, ABSOLUTE_TIMEOUT_SECONDS, started, log_path, diagnostic_path,
                on_sample=sample, capture_factory=capture_factory,
            )
            receipt.update(timed_out=timed_out, timeout_kind=timeout_kind, capture_error=capture_error)
            if timed_out:
                log.write(f"\nPLAY_BUSY001C_EXTERNAL_TIMEOUT kind={timeout_kind} absolute_seconds=120\n")
                log.flush()
                receipt["forced_cleanup"] = True
                diagnostics.stop_process_tree(child)
            receipt["returncode"] = child.wait(timeout=5)
            sample(child.pid)
            receipt["pid"] = reported_engine_pid(log_path, nonce, args.source_sha, final=True)
            receipt["observed_processes"] = custody.observed_processes
            if str(receipt["pid"]) not in custody.observed_processes:
                raise ValueError("original graphical engine was not observed in the owned process tree")
            if args.platform == "linux" and receipt["pid"] != child.pid:
                raise ValueError("Linux graphical PID is not the original direct child")
    except Exception as caught:
        error = f"{type(caught).__name__}: {caught}"
    finally:
        if child is not None and child.poll() is None:
            receipt["forced_cleanup"] = True
            diagnostics.stop_process_tree(child)
        if custody is not None:
            try:
                remaining = custody.remaining()
                if remaining:
                    receipt["surviving_processes"] = remaining
                    receipt["forced_cleanup"] = True
                    custody.stop_remaining()
                receipt["cleanup_complete"] = child is not None and child.poll() is not None and not custody.remaining()
                receipt["observed_processes"] = custody.observed_processes
            except Exception as caught:
                receipt["cleanup_complete"] = False
                error = error or f"cleanup: {type(caught).__name__}: {caught}"
                try:
                    receipt["forced_cleanup"] = True
                    custody.stop_remaining()
                except Exception as cleanup_error:
                    receipt["cleanup_error"] = f"{type(cleanup_error).__name__}: {cleanup_error}"
            finally:
                receipt["observation_errors"] = list(custody.observation_errors)
                if custody.observation_errors:
                    error = error or "process custody observation failed: " + "; ".join(custody.observation_errors)
                try:
                    custody.close()
                except Exception as close_error:
                    receipt["cleanup_complete"] = False
                    error = error or f"custody close: {type(close_error).__name__}: {close_error}"
        if child is not None:
            receipt["returncode"] = child.poll()
        if log_path.is_file():
            receipt["identities"]["log"] = identity(log_path)
        for key, path in runtime_paths.items():
            if identity(path) != receipt["identities"][key]:
                error = error or f"{key} bytes changed during execution"
        receipt["cache_after"] = cache_inventory()
        receipt["elapsed_seconds"] = time.perf_counter() - started
        receipt["error"] = error
        passed = (error is None and receipt["returncode"] == 0 and not receipt["timed_out"]
                  and receipt["cleanup_complete"] and not receipt["forced_cleanup"])
        receipt["status"] = "completed" if passed else "failed"
        write_receipt(receipt_path, receipt)
    print("PLAY_BUSY001C_RUNNER", receipt["status"], f"elapsed_seconds={receipt['elapsed_seconds']:.3f}",
          f"error={error!r}", flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
