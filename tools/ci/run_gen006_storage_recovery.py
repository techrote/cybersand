#!/usr/bin/env python3
"""Separate-process native area recovery and actual forced-termination checks.

This is a test orchestrator, not a persistence implementation. All profile I/O,
locking, continuation capture, restoration and publication execute in the shipped
Godot/native classes. Evidence is retained in the supplied fresh output directory.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import threading
import time


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    godot, project, output = args.godot.resolve(), args.project.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()):
        raise SystemExit("Evidence output must be a new empty directory; previous evidence is never overwritten")
    profile = output / "profile"
    suffix = "cybersand_native.windows.x86_64.dll" if os.name == "nt" else "libcybersand_native.linux.x86_64.so"
    native = project / "addons" / "cybersand_native" / "bin" / suffix
    report: dict = {
        "schema": 1, "platform": platform.platform(), "godot": str(godot),
        "godot_sha256": digest(godot), "native": str(native), "native_sha256": digest(native),
        "profile": str(profile), "claims": "actual process termination and native continuation; not hardware power-loss safety",
        "runs": [], "passed": False,
    }

    def command(mode: str) -> list[str]:
        return [str(godot), "--headless", "--path", str(project), "--script",
                "res://tests/test_persistent_area_store.gd", "--",
                f"--store-profile={profile}", f"--store-mode={mode}"]

    def run(mode: str, label: str) -> dict:
        start = time.monotonic()
        process = subprocess.Popen(command(mode), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, encoding="utf-8", errors="replace")
        item = {"mode": mode, "label": label, "pid": process.pid, "command": command(mode),
                "log": f"{label}.log"}
        report["runs"].append(item)
        try:
            stdout, _ = process.communicate(timeout=120)
        except subprocess.TimeoutExpired:
            process.kill()
            stdout, _ = process.communicate(timeout=15)
            item["timed_out"] = True
        item.update(returncode=process.returncode, wall_seconds=time.monotonic() - start)
        (output / f"{label}.log").write_text(stdout, encoding="utf-8")
        for line in stdout.splitlines():
            if line.startswith("GEN006_STORE_PROCESS "):
                item["receipt"] = json.loads(line.split(" ", 1)[1])
        if item.get("timed_out") or process.returncode != 0 or "ERROR:" in stdout or "GEN006_STORE checks=" not in stdout:
            raise RuntimeError(f"{label} failed; inspect {label}.log")
        return item.get("receipt", {})

    def kill_at(mode: str, label: str) -> None:
        start = time.monotonic()
        process = subprocess.Popen(command(mode), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, encoding="utf-8", errors="replace", bufsize=1)
        ready = threading.Event()
        lines: list[str] = []
        marker: list[dict] = []

        def consume() -> None:
            assert process.stdout is not None
            for line in process.stdout:
                lines.append(line)
                if line.startswith("GEN006_STORE_CRASH_READY "):
                    marker.append(json.loads(line.split(" ", 1)[1]))
                    ready.set()

        reader = threading.Thread(target=consume, daemon=True)
        reader.start()
        try:
            if not ready.wait(120):
                raise RuntimeError(f"{label} never reached the native publication boundary")
            run("lock-probe", label + "-concurrent-lock")
            process.kill()  # SIGKILL / TerminateProcess: no app exit or unlock handler.
            returncode = process.wait(timeout=15)
            reader.join(timeout=15)
            if returncode == 0:
                raise RuntimeError(f"{label} unexpectedly exited normally")
            report["runs"].append({"mode": mode, "label": label, "pid": process.pid, "returncode": returncode,
                "forced_termination": True, "boundary": marker[0], "wall_seconds": time.monotonic() - start,
                "log": f"{label}.log"})
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=15)
            reader.join(timeout=15)
            (output / f"{label}.log").write_text("".join(lines), encoding="utf-8")

    try:
        seed = run("seed", "01-seed-native")
        first = run("verify", "02-fresh-process-reopen")
        if (first.get("checkpoint_sha256"), first.get("game_ticks"), first.get("native_tick")) != (
                seed.get("checkpoint_sha256"), 10, 10):
            raise RuntimeError("Fresh process did not reconstruct the exact completed native authority")
        kill_at("crash-staged", "03-kill-after-immutable-stage")
        staged = run("verify", "04-recover-old-commit")
        if (staged.get("checkpoint_sha256"), staged.get("revision"), staged.get("game_ticks")) != (
                first.get("checkpoint_sha256"), first.get("revision"), 10):
            raise RuntimeError("Uncommitted staged work changed the prior authoritative manifest")
        kill_at("crash-published", "05-kill-after-manifest-publication")
        published = run("verify", "06-recover-new-commit")
        if (published.get("revision"), published.get("game_ticks"), published.get("native_tick")) != (
                first["revision"] + 1, 13, 13) or published.get("checkpoint_sha256") == first.get("checkpoint_sha256"):
            raise RuntimeError("Published native work was lost or the time interval was counted incorrectly")
        repeated = run("verify", "07-repeat-reopen-no-duplicate-progress")
        if repeated != {**published, "mode": "verify"}:
            raise RuntimeError("A repeated fresh-process restore duplicated progression or changed state")
        report["retained_files"] = [{"name": p.name, "bytes": p.stat().st_size, "sha256": digest(p)}
                                    for p in sorted(profile.iterdir()) if p.is_file()]
        if len(report["retained_files"]) > 9:
            raise RuntimeError("Recovery left unbounded checkpoint/stage generations")
        report["passed"] = True
    except Exception as error:
        report["error"] = str(error)
    finally:
        (output / "recovery-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "report": str(output / "recovery-report.json"),
                      "error": report.get("error", "")}))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
