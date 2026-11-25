#!/usr/bin/env python3
"""Real desktop recorder storage faults on fresh disposable subprocess directories."""
from __future__ import annotations

import argparse
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import signal
import subprocess
import sys
import threading
import time


ENGINE_ERRORS = re.compile(r"SCRIPT ERROR|(?:^|\n)ERROR:|Parse Error|Failed to load script|Error loading extension|GDExtension dynamic library not found")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_case(engine: Path, project: Path, directory: Path, fault: str) -> dict:
    directory.mkdir(parents=True)
    marker = directory / "continue"
    env = dict(os.environ, RECORDER_TEST_OUTPUT=str(directory / "output"),
               RECORDER_TEST_CONTINUE=str(marker), XDG_DATA_HOME=str(directory / "data"),
               APPDATA=str(directory / "data"),
               XDG_CONFIG_HOME=str(directory / "config"), XDG_CACHE_HOME=str(directory / "cache"))
    command = [str(engine), "--headless", "--audio-driver", "Dummy", "--path", str(project),
               "--script", "res://tests/gameplay_recorder_fault_child.gd"]

    def ignore_file_signal() -> None:
        signal.signal(signal.SIGXFSZ, signal.SIG_IGN)

    process = subprocess.Popen(command, env=env, text=True, encoding="utf-8", errors="replace",
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=1,
                               preexec_fn=ignore_file_signal if sys.platform.startswith("linux") else None)
    output: list[str] = []
    ready = None
    result = None
    lock = None
    killed = False
    deadline = time.monotonic() + 40
    assert process.stdout is not None
    lines: queue.Queue[str | None] = queue.Queue()

    def read_output() -> None:
        for line in process.stdout:
            lines.put(line)
        lines.put(None)

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    handles = ExitStack()
    try:
        while time.monotonic() < deadline:
            try:
                line = lines.get(timeout=0.25)
            except queue.Empty:
                continue
            if line is None:
                break
            output.append(line)
            if line.startswith("RECORDER_TEST_READY "):
                ready = json.loads(line.partition(" ")[2])
                if fault == "short-write":
                    import resource
                    resource.prlimit(process.pid, resource.RLIMIT_FSIZE, (128, 128))
                elif fault == "locked-manifest":
                    from run_workbench_save_qualification import windows_lock
                    lock = handles.enter_context(windows_lock(Path(ready["manifest"])))
                marker.write_text("continue\n", encoding="utf-8")
            elif line.startswith("RECORDER_TEST_RESULT "):
                result = json.loads(line.partition(" ")[2])
        if process.poll() is None:
            process.wait(timeout=5)
    finally:
        if process.poll() is None:
            killed = True
            process.kill()
            process.wait()
        reader.join(timeout=2)
        while not lines.empty():
            line = lines.get_nowait()
            if line is not None:
                output.append(line)
        handles.close()
        (directory / "child.log").write_text("".join(output), encoding="utf-8")
    log = "".join(output)
    (directory / "child.log").write_text(log, encoding="utf-8")
    # A completion line may have reached the reader while the process exited.
    if result is None:
        for line in log.splitlines():
            if line.startswith("RECORDER_TEST_RESULT "):
                result = json.loads(line.partition(" ")[2])
    status = result.get("status", {}) if result else {}
    natural_completion = not killed and process.returncode == 0
    engine_error = bool(ENGINE_ERRORS.search(log))
    passed = bool(ready and result and natural_completion and not engine_error)
    if fault == "none":
        passed = passed and not status.get("failed", True) and status.get("written_frames") == 1 \
            and result["frame_bytes"] == 1024 and result["manifest_disposition"] == "complete"
    elif fault == "short-write":
        passed = passed and status.get("failed") and status.get("written_frames") == 0 \
            and result["frame_bytes"] == 128 and result["prior_manifest_preserved"] \
            and result["manifest_disposition"] == "recording"
    else:
        passed = passed and status.get("failed") and status.get("written_frames") == 1 \
            and result["frame_bytes"] == 1024 and result["prior_manifest_preserved"] \
            and result["manifest_disposition"] == "recording" and lock is not None
    return {"passed":bool(passed),"command":command,"exit_code":process.returncode,
            "natural_completion":natural_completion,"engine_error_detected":engine_error,
            "fault":fault,"limit_bytes":128 if fault == "short-write" else None,
            "windows_lock":lock,"ready":ready,"result":result,"log_sha256":digest(directory / "child.log")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path("godot"))
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if not sys.platform.startswith("linux") and sys.platform != "win32":
        parser.error("this OS-fault runner supports only Linux and Windows")
    engine, project, evidence = args.godot.resolve(), args.project.resolve(), args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    paths = ["scripts/gameplay_recorder.gd", "scripts/workbench_file_transaction.gd",
             "tests/gameplay_recorder_fault_child.gd"]
    version = subprocess.check_output([str(engine), "--version"], text=True, timeout=15).strip()
    if version != "4.7.stable.official.5b4e0cb0f":
        parser.error("pinned Godot 4.7 is required")
    report = {"schema":1,"scope":"actual disposable storage faults; no GPU, power-loss or physical acceptance",
              "platform":sys.platform,"engine_version":version,
              "source_head":subprocess.check_output(["git","-C",str(project.parent),"rev-parse","HEAD"],text=True).strip(),
              "engine_sha256":digest(engine),"inputs":{p:digest(project / p) for p in paths},
              "runner_sha256":digest(Path(__file__)),"cases":[],"passed":False,
              "status":"running","completed":False}
    lock_helper = Path(__file__).with_name("run_workbench_save_qualification.py")
    if sys.platform == "win32":
        report["windows_lock_helper_sha256"] = digest(lock_helper)
    try:
        report["cases"].append(run_case(engine,project,evidence / "normal","none"))
        fault = "locked-manifest" if sys.platform == "win32" else "short-write"
        report["cases"].append(run_case(engine,project,evidence / fault,fault))
        report["passed"] = all(case["passed"] for case in report["cases"])
        report["completed"] = True
        report["status"] = "passed" if report["passed"] else "failed"
    except Exception as error:
        report["error"] = str(error)
        report["status"] = "failed"
    finally:
        (evidence / "report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"passed":report["passed"],"cases":len(report["cases"]),"report":str(evidence / "report.json")}))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
