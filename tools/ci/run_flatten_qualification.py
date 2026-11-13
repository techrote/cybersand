#!/usr/bin/env python3
"""Run native-backed Flatten and fresh-process reopen with original RSS evidence.

Reuses the installed Workbench runner's process/completion and package contracts.
RSS is sampled from the real Godot process at 20 ms, with OS peak RSS separately
recorded. Phase samples are process resident memory, not incremental allocations.
No model service is contacted and no generator is needed for saved baseline Load.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

from run_workbench_qualification import Runner, ERRORS, completion, verify_package


def storage_faults(args, env):
    """Exercise the unchanged writer against actual OS faults, retaining old bytes."""
    directory = args.evidence.resolve() / "storage-faults"
    directory.mkdir(parents=True, exist_ok=True)
    user_data = directory / "userdata"
    environment = dict(env, XDG_DATA_HOME=str(user_data), APPDATA=str(user_data))
    command = [str(args.godot.resolve()), "--audio-driver", "Dummy", "--headless", "--path",
               str(args.project.resolve()), "--script", "res://tests/flatten_save_fault_child.gd"]
    report = {"schema": "gen008-flatten-storage-faults-v1", "platform": "windows" if sys.platform == "win32" else "linux",
              "status": "running", "completed": False, "cases": []}

    def run(phase, label, before_exec=None, terminated=False):
        process = subprocess.run(command, env=dict(environment, FLATTEN_STORAGE_PHASE=phase),
                                 cwd=directory, text=True, encoding="utf-8", errors="replace",
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90,
                                 preexec_fn=before_exec)
        (directory / (label + ".log")).write_text(process.stdout, encoding="utf-8")
        if ERRORS.search(process.stdout):
            raise RuntimeError("Storage fixture contains a script error: " + label)
        if terminated:
            import signal
            if process.returncode != -signal.SIGXFSZ or "FLATTEN_STORAGE_WRITING " not in process.stdout:
                raise RuntimeError("Real partial-write child did not terminate at SIGXFSZ: " + label)
            return {"exit_code": process.returncode}
        if process.returncode != 0:
            raise RuntimeError("Storage fixture failed: " + label + "\n" + process.stdout)
        return completion(process.stdout, "FLATTEN_STORAGE_RESULT") | {"exit_code": process.returncode}

    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    try:
        cases = ["locked-target"] if sys.platform == "win32" else ["partial-write", "process-termination"]
        for kind in cases:
            prepared = run("prepare", kind + "-prepare")
            target = Path(prepared["path"])
            prior = sha(target)
            old_temporaries = set(target.parent.glob(target.name + ".*.tmp"))
            if sys.platform == "win32":
                from ctypes import wintypes
                create = ctypes.windll.kernel32.CreateFileW
                create.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p,
                                   wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
                create.restype = wintypes.HANDLE
                close = ctypes.windll.kernel32.CloseHandle
                close.argtypes = [wintypes.HANDLE]
                close.restype = wintypes.BOOL
                handle = create(str(target), 0x80000000, 1, None, 3, 0x80, None)
                if handle == wintypes.HANDLE(-1).value:
                    raise RuntimeError("Could not lock the existing valid Windows named start")
                try:
                    refused = run("refusal", kind + "-refusal")
                finally:
                    close(handle)
            else:
                import resource
                import signal
                def limit():
                    resource.setrlimit(resource.RLIMIT_FSIZE, (65536, 65536))
                    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
                    signal.signal(signal.SIGXFSZ, signal.SIG_DFL if kind == "process-termination" else signal.SIG_IGN)
                refused = run("process_fault" if kind == "process-termination" else "refusal",
                              kind + "-refusal", limit, kind == "process-termination")
            after = sha(target)
            if prior != after or prior != prepared["after_sha256"]:
                raise RuntimeError("A failed same-target save changed the previous valid named file")
            new_temporaries = set(target.parent.glob(target.name + ".*.tmp")) - old_temporaries
            sizes = [path.stat().st_size for path in sorted(new_temporaries)]
            if kind == "process-termination" and (not sizes or max(sizes) != 65536):
                raise RuntimeError("Process-fault fixture lacks a genuinely partial 64 KiB temporary write")
            if kind != "process-termination" and new_temporaries:
                raise RuntimeError("Recoverable write refusal leaked its temporary file")
            recovered = run("recover", kind + "-recover")
            row = {"kind": kind, "prior_sha256": prior, "after_sha256": after,
                   "exit_code": refused["exit_code"], "explicit_refusal": bool(refused.get("error")),
                   "attempted_plane_bytes": 524288, "partial_temporary_bytes": sizes,
                   "retry_ok": recovered["exit_code"] == 0 and recovered["after_sha256"] != prior,
                   "retry_sha256": recovered["after_sha256"]}
            if kind != "locked-target": row["file_size_limit_bytes"] = 65536
            if kind == "process-termination": row["signal"] = int(signal.SIGXFSZ)
            report["cases"].append(row)
        report.update(status="passed", completed=True)
        return report
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        path = args.evidence.resolve() / "storage-faults.json"
        path.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")


class ProcessMemory:
    def __init__(self, process):
        self.process = process
        if sys.platform == "win32":
            from ctypes import wintypes
            class Counters(ctypes.Structure):
                _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                            *[(name, ctypes.c_size_t) for name in (
                                "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage",
                                "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage",
                                "PagefileUsage", "PeakPagefileUsage")]]
            self.counters = Counters()
            self.counters.cb = ctypes.sizeof(Counters)
            self.get_memory = ctypes.windll.psapi.GetProcessMemoryInfo
            self.get_memory.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
            self.get_memory.restype = wintypes.BOOL

    def sample(self):
        if sys.platform == "win32":
            if self.get_memory(int(self.process._handle), ctypes.byref(self.counters), self.counters.cb):
                return int(self.counters.WorkingSetSize), int(self.counters.PeakWorkingSetSize)
        else:
            try:
                values = {}
                for line in Path(f"/proc/{self.process.pid}/status").read_text().splitlines():
                    key, _, value = line.partition(":")
                    if key in ("VmRSS", "VmHWM"):
                        values[key] = int(value.split()[0]) * 1024
                if "VmRSS" in values:
                    return values["VmRSS"], values.get("VmHWM", values["VmRSS"])
            except (FileNotFoundError, ProcessLookupError):
                pass
        return None


class MeasuredRunner(Runner):
    def execute(self, label, command, *, env=None, marker=None, timeout=1800, validate=None):
        log = self.evidence / f"{label}.log"
        effective_env = dict(self.env, **(env or {}))
        receipt = {"label": label, "command": command, "memory_sample_interval_ms": 20,
                   "memory_semantics": "process RSS/working set; phase peaks are sampled, OS peak is process lifetime"}
        self.results.append(receipt)
        started = time.monotonic()
        phases = {"startup": {"start_seconds": 0.0, "sampled_peak_rss_bytes": 0, "samples": 0}}
        current = ["startup"]
        lock = threading.Lock()
        process = None
        try:
            with log.open("w", encoding="utf-8") as output:
                process = subprocess.Popen(command, cwd=self.evidence, env=effective_env,
                                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                           text=True, encoding="utf-8", errors="replace")
                receipt["pid"] = process.pid
                memory = ProcessMemory(process)

                def consume():
                    for line in process.stdout:
                        output.write(line)
                        output.flush()
                        if line.startswith("FLATTEN_PHASE "):
                            event = json.loads(line[len("FLATTEN_PHASE "):])
                            with lock:
                                now = time.monotonic() - started
                                phases[current[0]]["end_seconds"] = now
                                current[0] = event["phase"]
                                phases[current[0]] = {"start_seconds": now,
                                                      "sampled_peak_rss_bytes": 0, "samples": 0}

                reader = threading.Thread(target=consume, daemon=True)
                reader.start()
                os_peak = 0
                sampled_peak = 0
                while process.poll() is None:
                    if time.monotonic() - started > timeout:
                        process.terminate()
                        try:
                            process.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=10)
                        raise TimeoutError(f"{label} exceeded {timeout}s; Godot was terminated")
                    sample = memory.sample()
                    if sample is not None:
                        rss, peak = sample
                        os_peak = max(os_peak, peak)
                        sampled_peak = max(sampled_peak, rss)
                        with lock:
                            row = phases[current[0]]
                            row["sampled_peak_rss_bytes"] = max(row["sampled_peak_rss_bytes"], rss)
                            row["samples"] += 1
                    time.sleep(0.02)
                sample = memory.sample()
                if sample is not None:
                    os_peak = max(os_peak, sample[1])
                reader.join(timeout=10)
                if reader.is_alive():
                    raise RuntimeError("Godot stdout did not close after process exit")
                phases[current[0]]["end_seconds"] = time.monotonic() - started
                receipt.update(exit_code=process.returncode, sampled_peak_rss_bytes=sampled_peak,
                               os_peak_rss_bytes=os_peak, phases=phases)
            text = log.read_text(encoding="utf-8", errors="replace")
            if process.returncode or ERRORS.search(text):
                print(text[-18000:])
                raise RuntimeError(f"{label} failed; retained original log: {log}")
            if marker:
                receipt["completion"] = completion(text, marker)
            if validate:
                receipt["completion"] = validate()
            if sampled_peak <= 0:
                raise RuntimeError("No process resident-memory samples were collected")
            receipt["status"] = "passed"
            print(f"PASS {label}: {receipt.get('completion', {}).get('checks', 'import')} checks; "
                  f"peak RSS {os_peak / 1048576:.2f} MiB", flush=True)
            return text
        except Exception as error:
            receipt.update(status="failed", error=str(error))
            raise
        finally:
            if process is not None and process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            receipt["elapsed_seconds"] = time.monotonic() - started
            (self.evidence / "results.json").write_text(json.dumps(self.results, indent=2)+"\n", encoding="utf-8")


def flatten(args):
    if args.package is not None:
        manifest = verify_package(args.package.resolve())
        if args.project.resolve() != args.package.resolve() / "godot":
            raise ValueError("Installed test must use the verified package's own Godot project")
        if sys.platform == "win32" and args.godot.resolve().parent != args.package.resolve():
            raise ValueError("Windows installed test must execute the packaged Godot runtime")
    else:
        manifest = None
    runner = MeasuredRunner(args)
    runner.env.pop("FLATTEN_REOPEN", None)
    if manifest:
        runner.env["CYBERSAND_SOURCE_REVISION"] = manifest["source_commit"]
    project = args.project.resolve()
    runner.godot(project, "flatten-import")
    runner.godot(project, "standalone-format-adversarial", "test_workbench_material_baseline", "WORKBENCH_MATERIAL_BASELINE")
    storage_faults(args, runner.env)
    for side, workers in args.cases:
        user_data = runner.evidence / f"side-{side}-workers-{workers}-userdata"
        author = None
        for phase in ("author", "reopen"):
            case = f"side-{side}-workers-{workers}-{phase}"
            frames = runner.evidence / f"{case}-frames"
            env = {"FLATTEN_SIDE": str(side), "FLATTEN_WORKERS": str(workers),
                   "FLATTEN_REOPEN": "1" if phase == "reopen" else "0",
                   "FLATTEN_SCREENSHOTS": str(frames),
                   "FLATTEN_REQUIRE_GRAPHICS": "0" if args.headless else "1",
                   "XDG_DATA_HOME": str(user_data), "APPDATA": str(user_data)}
            text = runner.godot(project, case, "test_workbench_flatten", "FLATTEN_RESULT",
                                graphical=not args.headless, env=env, max_fps=60)
            result = completion(text, "FLATTEN_RESULT")
            if (result.get("completed") is not True or result.get("phase") != phase
                    or result.get("side") != side or result.get("workers") != workers
                    or result.get("canonical_bytes") != side * side * 2):
                raise RuntimeError("Flatten fixture did not complete its exact requested scenario: " + case)
            if not args.headless:
                if result.get("source_identity", {}).get("display") == "headless":
                    raise RuntimeError("Requested installed graphical run was headless")
                required = ({"flatten-identical-live-world.png", "flatten-explicitly-saved.png"}
                            if phase == "author" else {"flatten-reopened-and-continued.png"})
                actual = {p.name for p in frames.glob("*.png") if p.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")}
                if not required.issubset(actual):
                    raise RuntimeError("Flatten fixture lacks actual framebuffer evidence: " + case)
            if phase == "author":
                author = result
            elif (author["process_instance"] == result["process_instance"]
                  or author["source_identity"] != result["source_identity"]):
                raise RuntimeError("Reopen was not a new process with identical source/runtime bytes")
    path = args.evidence.resolve() / "storage-faults.json"
    return {"status": "passed", "report_sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def parse_cases(value):
    cases = []
    for item in value.split(","):
        side, workers = map(int, item.split("x"))
        if side not in (512, 1024, 2048) or workers not in (1, 4):
            raise argparse.ArgumentTypeError("Cases must be SIDE x WORKERS from 512/1024/2048 and 1/4")
        cases.append((side, workers))
    if not cases or len(cases) != len(set(cases)):
        raise argparse.ArgumentTypeError("At least one unique case is required")
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--package", type=Path, help="Require exact-source installed package verification")
    parser.add_argument("--headless", action="store_true", help="Local diagnostic only; hosted acceptance remains graphical")
    parser.add_argument("--cases", type=parse_cases, default=parse_cases("512x1,1024x1,2048x1,512x4"))
    args = parser.parse_args()
    outcome = {"status": "running", "cases": args.cases, "graphical": not args.headless}
    try:
        outcome["storage_faults"] = flatten(args)
        outcome["status"] = "passed"
    except Exception as error:
        outcome.update(status="failed", error=str(error))
        raise
    finally:
        args.evidence.mkdir(parents=True, exist_ok=True)
        (args.evidence / "qualification.json").write_text(json.dumps(outcome, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
