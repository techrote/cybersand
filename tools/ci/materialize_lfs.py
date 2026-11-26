#!/usr/bin/env python3
"""Materialize exact committed LFS objects with a bounded service-timeout retry.

This is acquisition only. Original source/runtime verification and all execution
gates remain mandatory. No fallback object, alternate source or cache is chosen.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time

import execution_policy
from godot_timeout_diagnostics import stop_process_tree

MAX_ATTEMPTS = 3
BACKOFF_SECONDS = (2.0, 4.0)
SERVICE_TIMEOUT = "we couldn't respond to your request in time"
POINTER = re.compile(rb"version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n")


def retryable(returncode: int, text: str) -> bool:
    """Retry only the observed server refusal, never an auth or integrity failure."""
    lower = text.lower()
    permanent = re.search(r"\b(?:401|403|404|authentication|authorization|quota|billing)\b|"
                          r"permission denied|hash mismatch|integrity|not found", lower)
    return returncode == 2 and permanent is None and "batch response:" in lower and SERVICE_TIMEOUT in lower


def run_logged(command: list[str], root: Path, log: Path, seconds: float) -> dict:
    """Join the owned command; keep full output in a file rather than a pipe."""
    started = time.monotonic()
    process = None
    timed_out = False
    with log.open("xb") as stream:
        try:
            options = ({"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
                       if sys.platform == "win32" else {"start_new_session": True})
            process = subprocess.Popen(command, cwd=root, stdout=stream, stderr=subprocess.STDOUT, **options)
            try:
                process.wait(timeout=max(0.0, seconds - (time.monotonic() - started)))
            except subprocess.TimeoutExpired:
                timed_out = True
            finally:
                if process.poll() is None:
                    # Existing owned-tree cleanup is bounded to at most six
                    # seconds; the enclosing allowance reserves ten seconds.
                    stop_process_tree(process, wait_seconds=2.0)
        except OSError as error:
            stream.write((f"{type(error).__name__}: {error}\n").encode("utf-8"))
    return {"pid": process.pid if process is not None else None,
            "returncode": process.returncode if process is not None else None,
            "timed_out": timed_out, "joined": process is None or process.poll() is not None,
            "seconds": time.monotonic() - started}


def materialize(root: Path, paths: list[str], expected_source: str, output: Path,
                allowance_seconds: float, *, execute=run_logged,
                clock=time.monotonic, sleep=time.sleep) -> dict:
    if not math.isfinite(allowance_seconds) or allowance_seconds <= 10:
        raise ValueError("LFS acquisition allowance must include bounded cleanup")
    if not re.fullmatch(r"[0-9a-f]{40}", expected_source):
        raise ValueError("Expected source must be an exact Git commit")
    if not paths or len(set(paths)) != len(paths):
        raise ValueError("LFS paths must be a nonempty unique literal inventory")
    for path in paths:
        name = PurePosixPath(path)
        if (not path or name.is_absolute() or ".." in name.parts
                or any(c in path for c in "\\,:\n\r*?[]") or name.as_posix() != path):
            raise ValueError("Unsafe or nonliteral LFS path")
    root, output = root.resolve(), output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    receipt_path = output / "receipt.json"
    if receipt_path.exists() or list(output.glob("*.log")):
        raise ValueError("Refusing to overwrite retained LFS acquisition evidence")
    started = clock()
    deadline = started + allowance_seconds
    cleanup = execution_policy.watchdog_seconds("terminate_grace_seconds")
    if cleanup < 6 or allowance_seconds <= cleanup:
        raise ValueError("LFS acquisition policy cannot contain the existing owned-tree cleanup")
    receipt = {"schema": "cybersand-lfs-acquisition-v1", "source_commit": expected_source,
               "allowance_seconds": allowance_seconds, "cleanup_reserve_seconds": cleanup,
               "max_attempts": MAX_ATTEMPTS, "retry_scope": "observed Git LFS batch service timeout only",
               "status": "running", "commands": [], "objects": [], "backoff_seconds": []}

    def save() -> None:
        receipt["seconds"] = clock() - started
        receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")

    def remaining() -> float:
        left = deadline - clock() - cleanup
        if left <= 0:
            raise TimeoutError("LFS acquisition shared deadline exhausted")
        return left

    def git(*args: str) -> bytes:
        return subprocess.check_output(["git", "-C", str(root), *args], timeout=remaining())

    def command(label: str, args: list[str]) -> tuple[dict, str]:
        log = output / (label + ".log")
        seconds = remaining()
        row = {"label": label, "command": args, "allowance_seconds": seconds, "log": log.name}
        receipt["commands"].append(row)
        save()
        seconds = remaining()
        row["allowance_seconds"] = seconds
        row.update(execute(args, root, log, seconds))
        data = log.read_bytes()
        row.update(log_bytes=len(data), log_sha256=hashlib.sha256(data).hexdigest())
        save()
        return row, data.decode("utf-8", errors="replace")

    try:
        if git("rev-parse", "HEAD").decode().strip() != expected_source:
            raise ValueError("LFS acquisition checkout differs from expected source")
        for path in paths:
            pointer = git("show", expected_source + ":" + path)
            match = POINTER.fullmatch(pointer)
            if match is None or (root / path).resolve() != root / path:
                raise ValueError("Expected a committed canonical LFS pointer: " + path)
            receipt["objects"].append({"path": path, "sha256": match[1].decode(), "bytes": int(match[2])})
        row, _ = command("lfs-setup", ["git", "lfs", "install", "--local"])
        if row["returncode"] != 0 or row["timed_out"] or not row["joined"]:
            raise RuntimeError("Git LFS setup failed; see retained original log")
        for attempt in range(1, MAX_ATTEMPTS + 1):
            row, text = command(f"lfs-pull-{attempt}", ["git", "lfs", "pull",
                                "--include=" + ",".join(paths), "--exclude="])
            row["retryable_service_timeout"] = retryable(row["returncode"], text) if row["returncode"] is not None else False
            save()
            if row["returncode"] == 0 and not row["timed_out"] and row["joined"]:
                break
            if row["timed_out"] or not row["joined"] or not row["retryable_service_timeout"]:
                raise RuntimeError("Git LFS acquisition failed without an admissible retry; see retained original log")
            if attempt == MAX_ATTEMPTS:
                raise RuntimeError("Git LFS service timeout persisted through the bounded attempt limit")
            delay = BACKOFF_SECONDS[attempt - 1]
            if remaining() <= delay:
                raise TimeoutError("LFS acquisition deadline cannot admit another backoff and attempt")
            receipt["backoff_seconds"].append(delay)
            save()
            sleep(delay)
        for obj in receipt["objects"]:
            remaining()
            path = root / obj["path"]
            if path.resolve() != path or not path.is_file():
                raise ValueError("LFS object is absent or a symlink: " + obj["path"])
            actual_size = path.stat().st_size
            if actual_size != obj["bytes"]:
                raise ValueError("Materialized LFS object size differs from exact committed pointer: " + obj["path"])
            digest = hashlib.sha256()
            with path.open("rb") as stream:
                while True:
                    remaining()
                    chunk = stream.read(1024 * 1024)
                    if not chunk:
                        break
                    digest.update(chunk)
            actual_sha = digest.hexdigest()
            obj.update(actual_sha256=actual_sha, actual_bytes=actual_size)
            if actual_sha != obj["sha256"] or actual_size != obj["bytes"]:
                raise ValueError("Materialized LFS object differs from exact committed pointer: " + obj["path"])
        if git("rev-parse", "HEAD").decode().strip() != expected_source:
            raise ValueError("LFS acquisition source moved during materialization")
        remaining()
        receipt["status"] = "passed"
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        receipt.update(status="failed", error=f"{type(error).__name__}: {error}")
        raise
    finally:
        save()
    return receipt


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--include", action="append", required=True)
    parser.add_argument("--expected-source", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--allowance-seconds", type=float,
                        default=execution_policy.watchdog_seconds("dependency_prepare_seconds"))
    args = parser.parse_args()
    try:
        result = materialize(args.root, args.include, args.expected_source, args.output, args.allowance_seconds)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"LFS acquisition failed: {type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
