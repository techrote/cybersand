#!/usr/bin/env python3
"""Diagnostic only: trace unchanged frozen Windows Lab/Workbench execution.

No publication entry point, source edits, relaxed assertions or timeout changes.
The external sitecustomize hook adds timing around original backend functions;
any result is diagnostic evidence and cannot qualify a release runtime.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

SOURCE = "4e41501a56b25de5defdaedbd990b34b13a41c13"
TREE = "16ebe643f92340a0ce3f75b74e32585c25ba779c"
NATIVE_SHA256 = "1d9b906ea1c3952de142d1e77aeea0e21974d02e7c462de839866e74da472e91"
FAILED_REQUEST_SHA256 = {
    1: "389d87df90fb4b2c11c938283a94d63b03d23774d238222db31c348d18f8e1ff",
    4: "4e7ad3f6582d7c782b0f3b96cc8ca0f1c8f50fdf5c0a3d297c4a63981e7c14ae",
}
ORIGINAL_RUN = "https://github.com/techrote/cybersand/actions/runs/43347141410"

SITECUSTOMIZE = r'''"""External diagnostic hook; does not modify candidate source files."""
import builtins
from datetime import datetime, timezone
import functools
import itertools
import json
import os
from pathlib import Path
import sys
import threading
import time

_root = Path(os.environ["MAT_WB_DIAGNOSTIC_SOURCE"]).resolve()
_target = _root / "tools/material_catalogue/lab.py"
_trace_root = Path(os.environ["MAT_WB_DIAGNOSTIC_TRACE"]).resolve()
_counter = itertools.count(1)
_lock = threading.Lock()

def _emit(event, **data):
    record = {"event": event, "utc": datetime.now(timezone.utc).isoformat(),
              "monotonic": time.monotonic(), "pid": os.getpid(), **data}
    with _lock:
        with (_trace_root / ("python-%d.jsonl" % os.getpid())).open("a", encoding="utf-8") as output:
            output.write(json.dumps(record, ensure_ascii=True, default=str) + "\n")

def _wrap(module, name):
    original = getattr(module, name, None)
    if original is None or getattr(original, "_mat_wb_traced", False):
        return
    @functools.wraps(original)
    def observed(*args, **kwargs):
        call = next(_counter)
        started = time.monotonic()
        details = {}
        if name == "_run":
            details = {"command": args[0], "cwd": str(args[1]), "timeout": args[2], "check": kwargs.get("check", True)}
        elif name == "_build_and_execute":
            details = {"cwd": str(args[0]), "compiler": args[1], "msvc": args[2],
                       "scenario": args[3], "material_id": args[4], "sanitize": args[5]}
        _emit("call", call=call, function=module.__name__ + "." + name, **details)
        try:
            result = original(*args, **kwargs)
        except BaseException as error:
            _emit("error", call=call, function=module.__name__ + "." + name,
                  elapsed_seconds=time.monotonic()-started,
                  error_type=type(error).__name__, error=str(error))
            raise
        else:
            details = {}
            if name == "_run":
                details = {"returncode": result.returncode,
                           "stdout": result.stdout[-8192:], "stderr": result.stderr[-8192:],
                           "stdout_chars": len(result.stdout), "stderr_chars": len(result.stderr)}
            elif name == "_source_snapshot":
                details = {"source_digest": result[0]["digest"], "git_head": result[0]["git_head"],
                           "input_count": len(result[0]["lf_sha256"])}
            elif name == "_build_and_execute":
                details = {"checks": result[0].get("checks"), "build": result[1]}
            _emit("return", call=call, function=module.__name__ + "." + name,
                  elapsed_seconds=time.monotonic()-started, **details)
            return result
    observed._mat_wb_traced = True
    setattr(module, name, observed)

def _patch_loaded():
    for module_name, names in (("lab", ("_run",)),
                               ("world_candidate", ("_build_and_execute", "_source_snapshot"))):
        module = sys.modules.get(module_name)
        if module is not None and Path(getattr(module, "__file__", "")).resolve().parent == _target.parent:
            for name in names:
                _wrap(module, name)

if Path(sys.argv[0]).resolve() == _target:
    _trace_root.mkdir(parents=True, exist_ok=True)
    _emit("loaded", argv=sys.argv, cwd=os.getcwd(), python=sys.executable,
          selected_compiler=os.environ.get("CYBERSAND_LAB_CXX", ""))
    _original_import = builtins.__import__
    def _observed_import(*args, **kwargs):
        result = _original_import(*args, **kwargs)
        _patch_loaded()
        return result
    builtins.__import__ = _observed_import
'''

SAMPLER = r'''param([int]$RootProcessId, [long]$RootCreatedFileTime, [string]$Output, [string]$StopFile, [switch]$Once)
$ErrorActionPreference = 'Stop'
# A PID alone is not an identity. Keep its creation FILETIME at CIM's microsecond
# precision, and discover children only through the currently live parent generation.
$known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$rootStamp = $RootCreatedFileTime - ($RootCreatedFileTime % 10)
$rootIdentity = ('{0}/{1}' -f $RootProcessId, $rootStamp)
[void]$known.Add($rootIdentity)
$logicalProcessors = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$previous = @{}
$previousUtc = $null
function Get-Identity($Process) {
  if ($null -eq $Process.CreationDate) { return $null }
  [long]$stamp = $Process.CreationDate.ToUniversalTime().ToFileTimeUtc()
  $stamp -= $stamp % 10
  return ('{0}/{1}' -f $Process.ProcessId, $stamp)
}
while (-not (Test-Path -LiteralPath $StopFile)) {
  try {
    $now = [DateTime]::UtcNow
    $all = @(Get-CimInstance Win32_Process)
    $byPid = @{}
    foreach ($row in $all) { $byPid[[string]$row.ProcessId] = $row }
    do {
      $added = $false
      foreach ($row in $all) {
        $identity = Get-Identity $row
        if ($null -eq $identity) { continue }
        if ($known.Contains($identity)) { continue }
        $parent = $byPid[[string]$row.ParentProcessId]
        if ($null -ne $parent -and $null -ne $parent.CreationDate -and $row.CreationDate -ge $parent.CreationDate -and
            $known.Contains((Get-Identity $parent))) {
          if ($known.Add($identity)) { $added = $true }
        }
      }
    } while ($added)
    $rows = @($all | Where-Object { $known.Contains((Get-Identity $_)) } | ForEach-Object {
      [ordered]@{
        identity = (Get-Identity $_); pid = $_.ProcessId; parent_pid = $_.ParentProcessId; name = $_.Name
        command = $_.CommandLine; executable = $_.ExecutablePath
        created = $_.CreationDate.ToUniversalTime().ToString('o')
        user_100ns = $_.UserModeTime; kernel_100ns = $_.KernelModeTime
        working_set_bytes = $_.WorkingSetSize; read_bytes = $_.ReadTransferCount
        write_bytes = $_.WriteTransferCount; threads = $_.ThreadCount; handles = $_.HandleCount
      }
    })
    # Host competitors are identified by name/generation only; do not collect
    # unrelated command lines or credentials. First sample has no CPU deltas.
    $current = @{}
    $deltas = @()
    foreach ($row in $all) {
      $identity = Get-Identity $row
      if ($null -eq $identity -or $null -eq $row.UserModeTime -or $null -eq $row.KernelModeTime) { continue }
      [ulong]$cpu = [ulong]$row.UserModeTime + [ulong]$row.KernelModeTime
      $current[$identity] = $cpu
      if ($previous.ContainsKey($identity) -and $cpu -ge $previous[$identity]) {
        $deltas += [ordered]@{identity=$identity; pid=$row.ProcessId; name=$row.Name
          cpu_delta_100ns=($cpu - $previous[$identity]); owned=$known.Contains($identity)}
      }
    }
    $hostRows = @($all | ForEach-Object {
      [ordered]@{identity=(Get-Identity $_); pid=$_.ProcessId; parent_pid=$_.ParentProcessId; name=$_.Name
        created=$(if ($null -eq $_.CreationDate) { $null } else { $_.CreationDate.ToUniversalTime().ToString('o') })
        user_100ns=$_.UserModeTime; kernel_100ns=$_.KernelModeTime
        working_set_bytes=$_.WorkingSetSize; threads=$_.ThreadCount; handles=$_.HandleCount}
    })
    $total = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
    [ordered]@{ utc = $now.ToString('o'); root_pid = $RootProcessId; root_identity = $rootIdentity
      logical_processors = $logicalProcessors; total_cpu_percent = $total.PercentProcessorTime
      interval_seconds = $(if ($null -eq $previousUtc) { $null } else { ($now-$previousUtc).TotalSeconds })
      top_cpu_deltas = @($deltas | Sort-Object { $_.cpu_delta_100ns } -Descending | Select-Object -First 12)
      host_processes = $hostRows
      processes = $rows
    } | ConvertTo-Json -Compress -Depth 7 | Add-Content -LiteralPath $Output -Encoding utf8
    $previous = $current
    $previousUtc = $now
  } catch {
    [ordered]@{utc = [DateTime]::UtcNow.ToString('o'); error = $_.Exception.Message} |
      ConvertTo-Json -Compress | Add-Content -LiteralPath $Output -Encoding utf8
  }
  if ($Once) { break }
  Start-Sleep -Milliseconds 1000
}
'''


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def process_creation_filetime(process) -> int:
    """Bind the sampler to the exact owned Windows handle, not a reused PID."""
    import ctypes
    from ctypes import wintypes
    created, exited, kernel, user = (wintypes.FILETIME() for _ in range(4))
    function = ctypes.WinDLL("kernel32", use_last_error=True).GetProcessTimes
    function.argtypes = [wintypes.HANDLE, *([ctypes.POINTER(wintypes.FILETIME)] * 4)]
    function.restype = wintypes.BOOL
    if not function(wintypes.HANDLE(int(process._handle)), ctypes.byref(created), ctypes.byref(exited),
                    ctypes.byref(kernel), ctypes.byref(user)):
        raise ctypes.WinError(ctypes.get_last_error())
    return (created.dwHighDateTime << 32) | created.dwLowDateTime


def host_snapshot(evidence: Path, case: Path, label: str) -> None:
    """Preserve all process identities/CPU before launch and after owned cleanup."""
    output = case / ("host-" + label + ".jsonl")
    result = subprocess.run(["pwsh", "-NoLogo", "-NoProfile", "-File", str(evidence / "sample-processes.ps1"),
        "-RootProcessId", "0", "-RootCreatedFileTime", "0", "-Output", str(output),
        "-StopFile", str(case / ("host-" + label + ".unused-stop")), "-Once"],
        text=True, capture_output=True, timeout=30)
    (case / ("host-" + label + ".log")).write_text(result.stdout + result.stderr, encoding="utf-8")
    rows = [json.loads(line) for line in output.read_text(encoding="utf-8-sig").splitlines()] if output.is_file() else []
    if result.returncode != 0 or len(rows) != 1 or not rows[0].get("host_processes"):
        raise RuntimeError("All-host CPU snapshot did not complete: " + label)


def run_case(evidence: Path, label: str, command: list[str], env: dict, *, userdata: Path | None = None,
             timeout: int = 600, cancel_file: Path | None = None, details: dict | None = None,
             fixture_layout: bool = False) -> dict:
    case = evidence / label
    case.mkdir()
    userdata = userdata if userdata is not None else case / "userdata"
    trace = case / "backend-trace"
    trace.mkdir()
    log_path = evidence / (label + ".log") if fixture_layout else case / "godot.log"
    frames = evidence / (label + "-frames") if fixture_layout else case / "frames"
    env = dict(env, APPDATA=str(userdata), XDG_DATA_HOME=str(userdata),
               MAT_WB_DIAGNOSTIC_TRACE=str(trace), MAT_WB_SCREENSHOTS=str(frames))
    host_snapshot(evidence, case, "before")
    started = time.monotonic()
    record = {"label": label, "command": command, "cwd": str(case), "userdata": str(userdata),
              "started_utc": datetime.now(timezone.utc).isoformat(), "scope": "diagnostic-only",
              "stdout_path": str(log_path), "frames_directory": str(frames),
              **(details or {})}
    stop = case / "sampler.stop"
    sampler = None
    with log_path.open("w", encoding="utf-8") as log, (case / "sampler.log").open("w", encoding="utf-8") as sampler_log:
        process = subprocess.Popen(command, cwd=case, env=env, stdout=log, stderr=subprocess.STDOUT)
        record["pid"] = process.pid
        try:
            record["created_filetime_100ns"] = process_creation_filetime(process)
            write_json(case / "case.json", record)
            sampler = subprocess.Popen(["pwsh", "-NoLogo", "-NoProfile", "-File", str(evidence / "sample-processes.ps1"),
                "-RootProcessId", str(process.pid), "-RootCreatedFileTime", str(record["created_filetime_100ns"]),
                "-Output", str(case / "processes.jsonl"), "-StopFile", str(stop)],
                stdout=sampler_log, stderr=subprocess.STDOUT)
            record["exit_code"] = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            record["outer_timeout_seconds"] = timeout
            if cancel_file is not None:
                cancel_file.write_text("cancelled\n", encoding="utf-8")
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    pass
            if process.poll() is None:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=30, check=False)
            record["exit_code"] = process.wait(timeout=30)
        finally:
            if process.poll() is None:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               capture_output=True, timeout=30, check=False)
                record["exit_code"] = process.wait(timeout=30)
            # Allow one final host snapshot to expose surviving predecessor
            # processes; the sampler never kills or modifies sampled processes.
            time.sleep(2)
            stop.write_text("finished\n", encoding="utf-8")
            if sampler is not None:
                try:
                    record["sampler_exit_code"] = sampler.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    sampler.kill()
                    record["sampler_exit_code"] = sampler.wait(timeout=10)
            record["elapsed_seconds"] = round(time.monotonic()-started, 3)
            record["finished_utc"] = datetime.now(timezone.utc).isoformat()
            write_json(case / "case.json", record)
    host_snapshot(evidence, case, "after")
    print(json.dumps(record), flush=True)
    return record


def fixture_pair(profile, evidence, project, base, env, *, fps: int, workers: int, summary: dict) -> dict:
    pair = f"combined-{fps}fps-workers-{workers}"
    userdata = evidence / "shared-userdata" / pair
    profile.engine.require(not userdata.resolve().is_relative_to(project.resolve().parent),
                           "Diagnostic userdata must remain outside source custody")
    graphical = base + ["--print-fps", "--max-fps", str(fps), "--rendering-method", "gl_compatibility",
                        "--rendering-driver", "opengl3_angle", "--script",
                        "res://tests/test_material_lab_workbench_integration.gd"]
    author = None
    for phase in ("author", "reopen"):
        label = pair + "-" + phase
        if phase == "reopen" and not author.get("fixture_complete", False):
            summary["not_run"].append({"label": label, "reason": "paired author did not complete",
                                       "scope": "diagnostic-only; no persistence result claimed"})
            break
        record = run_case(evidence, label, graphical, dict(env, ART_UNDO_WORKERS=str(workers),
                          MAT_WB_REOPEN="1" if phase == "reopen" else "0"), userdata=userdata,
                          details={"workers": workers, "phase": phase, "max_fps": fps}, fixture_layout=True)
        record["fixture_complete"] = False
        if record["exit_code"] == 0:
            try:
                receipt = profile.verify_combined_case(evidence, label, project, workers, phase,
                                                       platform="windows", native_sha=NATIVE_SHA256)
                record["fixture_complete"] = True
                record["fixture_checks"] = receipt["checks"]
            except Exception as error:
                record["fixture_validation_error"] = str(error)
        summary["cases"].append(record)
        write_json(evidence / label / "case.json", record)
        write_json(evidence / "diagnostic.json", summary)
        if phase == "author":
            author = record
    return author


def direct_replay(evidence, candidate, env, author, summary, workers):
    requests = sorted(Path(author["userdata"]).rglob("request.json"))
    matches = [path for path in requests if sha256(path) == FAILED_REQUEST_SHA256[workers]]
    if not matches:
        summary["not_run"].append({"label": f"direct-workers-{workers}-backend-control",
            "reason": f"The exact failing workers-{workers} request was not produced; direct replay refused",
            "observed_requests": [{"path": str(path), "sha256": sha256(path)} for path in requests]})
        return
    original = matches[0]
    payload = json.loads(original.read_text(encoding="utf-8-sig"))
    if payload.get("op") != "compile_world_test" or payload.get("scenario") != {
            "first": 2, "second": 3, "seed": 2, "ticks": 120, "workers": workers}:
        raise RuntimeError("The authenticated direct replay has an unexpected scenario")
    directory = evidence / f"direct-request-workers-{workers}"
    directory.mkdir()
    request, response, cancel = (directory / name for name in ("request.json", "response.json", "cancel"))
    shutil.copyfile(original, request)
    record = run_case(evidence, f"direct-workers-{workers}-backend-control", [sys.executable,
        str(candidate / "tools/material_catalogue/lab.py"), "--request", str(request),
        "--response", str(response), "--cancel-file", str(cancel)], env, timeout=300, cancel_file=cancel,
        details={"request_sha256": sha256(request), "original_request": str(original), "workers": workers,
                 "scope": "diagnostic-only; exact unchanged request without Godot"})
    if response.is_file():
        record["response_sha256"] = sha256(response)
        result = json.loads(response.read_text(encoding="utf-8-sig"))
        record["backend_ok"] = result.get("ok") is True
        record["backend_errors"] = result.get("errors", [])
    summary["cases"].append(record)
    write_json(evidence / record["label"] / "case.json", record)
    write_json(evidence / "diagnostic.json", summary)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--godot-archive", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != "win32":
        raise RuntimeError("This diagnostic requires the actual Windows host")
    candidate, bundle, evidence = (path.resolve() for path in (args.candidate, args.bundle, args.evidence))
    if evidence.is_relative_to(candidate) or evidence.exists():
        raise RuntimeError("Use a fresh evidence directory outside the frozen candidate")
    evidence.mkdir(parents=True)
    sys.path.insert(0, str(candidate / "tools/ci"))
    spec = importlib.util.spec_from_file_location("_frozen_mat_workbench", candidate / "tools/ci/mat_workbench_runtime_publication.py")
    profile = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(profile)
    engine = profile.engine
    require = engine.require
    require(engine.ROOT == candidate, "Verifier must resolve to the frozen candidate")
    require(engine.git("rev-parse", "HEAD").decode().strip() == SOURCE, "Wrong candidate source")
    require(engine.git("rev-parse", "HEAD^{tree}").decode().strip() == TREE, "Wrong candidate tree")
    require(engine.git("rev-parse", "--is-shallow-repository").decode().strip() == "false", "Full source history is required")
    manifest = json.loads(engine.manifest_path(bundle, "windows").read_text(encoding="utf-8"))
    original = {"source_commit": SOURCE, "build_commit": SOURCE, "source_tree": TREE,
                "workflow_run": ORIGINAL_RUN, "workflow_attempt": "1", "build_attempt": "1",
                "schema_version": 1, "platform": "windows", "status": "built-not-executed",
                "evidence": "docs/audits/2026-11-12-mat-auth-workbench-integration.md"}
    require(all(manifest.get(key) == value for key, value in original.items()), "Wrong original build provenance")
    before = engine.input_ledgers(SOURCE)
    require(len(before["source_inputs"]) == 89 and len(before["build_inputs"]) == 841, "Incomplete source inventory")
    require(before == {key: manifest[key] for key in ("source_inputs", "build_inputs")}, "Original build input hashes differ")
    native = bundle / Path(engine.RUNTIMES["windows"]).name
    identity = engine.runtime_identity(native, "windows")
    require(identity["sha256"] == NATIVE_SHA256 and all(manifest.get(k) == v for k, v in identity.items()), "Wrong original DLL")
    require(bool(manifest.get("toolchain")), "Missing original toolchain provenance")
    rapier, rapier_hash = engine.RAPIER["windows"]
    require(sha256(candidate / rapier) == rapier_hash, "Rapier bytes differ from the original pin")
    shutil.copyfile(native, candidate / engine.RUNTIMES["windows"])
    godot, godot_identity = engine.windows.prepare_godot(args.godot_archive.resolve())
    write_json(evidence / "source-before.json", before)
    shutil.copyfile(engine.manifest_path(bundle, "windows"), evidence / "original-build-provenance.json")
    hook = evidence / "trace-hook"
    hook.mkdir()
    (hook / "sitecustomize.py").write_text(SITECUSTOMIZE, encoding="utf-8")
    (evidence / "sample-processes.ps1").write_text(SAMPLER, encoding="utf-8")
    summary = {"schema": "mat-workbench-windows-diagnostic2-v1",
               "scope": "DIAGNOSTIC ONLY; instrumented process, not release qualification",
               "source_commit": SOURCE, "source_tree": TREE, "native": identity, "godot": godot_identity,
               "original_artifact_id": 14002083306, "original_workflow_run": ORIGINAL_RUN,
               "diagnostic_workflow_run": os.environ.get("GITHUB_RUN_ID"),
               "diagnostic_workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
               "host_logical_processors": os.cpu_count(), "candidate_compiler": os.environ.get("CYBERSAND_LAB_CXX"),
               "diagnostic_helper_sha256": sha256(Path(__file__)), "hook_sha256": sha256(hook / "sitecustomize.py"),
               "sampler_sha256": sha256(evidence / "sample-processes.ps1"),
               "cases": [], "not_run": [], "source_unchanged": False, "completed": False}
    write_json(evidence / "diagnostic.json", summary)
    env = dict(os.environ, PYTHONPATH=str(hook), MAT_WB_DIAGNOSTIC_SOURCE=str(candidate),
               ART_UNDO_WORKERS="4", MAT_WB_REOPEN="0", PYTHONDONTWRITEBYTECODE="1")
    base = [str(godot), "--audio-driver", "Dummy", "--path", str(candidate / "godot")]
    try:
        imported = run_case(evidence, "import", base + ["--headless", "--editor", "--quit"], env, timeout=180)
        summary["cases"].append(imported)
        require(imported["exit_code"] == 0, "Frozen Godot project could not import")
        for workers in (1, 4):
            original_author = fixture_pair(profile, evidence, candidate / "godot", base, env,
                                           fps=5, workers=workers, summary=summary)
            if not original_author.get("fixture_complete", False):
                direct_replay(evidence, candidate, env, original_author, summary, workers)
            else:
                summary["not_run"].append({"label": f"direct-workers-{workers}-backend-control",
                    "reason": "5 FPS author completed; failure-only native replay was unnecessary"})
        for workers in (1, 4):
            fixture_pair(profile, evidence, candidate / "godot", base, env, fps=1, workers=workers, summary=summary)
        summary["completed"] = True
    except Exception as error:
        summary["diagnostic_error"] = str(error)
        raise
    finally:
        after = engine.input_ledgers(SOURCE)
        write_json(evidence / "source-after.json", after)
        summary["source_unchanged"] = before == after
        summary["native_unchanged"] = engine.runtime_identity(candidate / engine.RUNTIMES["windows"], "windows") == identity
        summary["files_sha256"] = {path.relative_to(evidence).as_posix(): sha256(path)
                                    for path in sorted(evidence.rglob("*")) if path.is_file() and path.name != "diagnostic.json"}
        write_json(evidence / "diagnostic.json", summary)
    require(summary["source_unchanged"] and summary["native_unchanged"], "Candidate custody changed during diagnosis")
    return 0 if all(case["exit_code"] == 0 and case.get("fixture_complete", True)
                    and case.get("backend_ok", True) for case in summary["cases"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())


