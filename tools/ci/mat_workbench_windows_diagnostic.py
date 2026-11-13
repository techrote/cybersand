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

SOURCE = "90719c72b9fcf90593fb7878354051ad601b47fd"
TREE = "1e22d3ac57efc43fa5ba1b37f1dbc5d62121b1f7"
NATIVE_SHA256 = "cced96c05bd159ee39dd15b959f722653f20d65952b95b0ad913a20a57a0d7ca"
FAILED_REQUEST_SHA256 = "389d87df90fb4b2c11c938283a94d63b03d23774d238222db31c348d18f8e1ff"
ORIGINAL_RUN = "https://github.com/techrote/cybersand/actions/runs/43334477644"

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

SAMPLER = r'''param([int]$RootProcessId, [string]$Output, [string]$StopFile)
$ErrorActionPreference = 'Stop'
$seen = [System.Collections.Generic.HashSet[uint32]]::new()
[void]$seen.Add([uint32]$RootProcessId)
while (-not (Test-Path -LiteralPath $StopFile)) {
  try {
    $all = @(Get-CimInstance Win32_Process)
    do {
      $added = $false
      foreach ($row in $all) {
        if ($seen.Contains([uint32]$row.ParentProcessId)) {
          if ($seen.Add([uint32]$row.ProcessId)) { $added = $true }
        }
      }
    } while ($added)
    $rows = @($all | Where-Object { $seen.Contains([uint32]$_.ProcessId) } | ForEach-Object {
      [ordered]@{
        pid = $_.ProcessId; parent_pid = $_.ParentProcessId; name = $_.Name
        command = $_.CommandLine; executable = $_.ExecutablePath
        created = $_.CreationDate; user_100ns = $_.UserModeTime; kernel_100ns = $_.KernelModeTime
        working_set_bytes = $_.WorkingSetSize; read_bytes = $_.ReadTransferCount
        write_bytes = $_.WriteTransferCount; threads = $_.ThreadCount; handles = $_.HandleCount
      }
    })
    $total = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
    [ordered]@{ utc = [DateTime]::UtcNow.ToString('o'); root_pid = $RootProcessId
      total_cpu_percent = $total.PercentProcessorTime; processes = $rows
    } | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $Output -Encoding utf8
  } catch {
    [ordered]@{utc = [DateTime]::UtcNow.ToString('o'); error = $_.Exception.Message} |
      ConvertTo-Json -Compress | Add-Content -LiteralPath $Output -Encoding utf8
  }
  Start-Sleep -Milliseconds 1000
}
'''


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_case(evidence: Path, label: str, command: list[str], env: dict, *, timeout: int = 480,
             cancel_file: Path | None = None) -> dict:
    case = evidence / label
    case.mkdir()
    userdata = case / "userdata"
    trace = case / "backend-trace"
    trace.mkdir()
    env = dict(env, APPDATA=str(userdata), XDG_DATA_HOME=str(userdata),
               MAT_WB_DIAGNOSTIC_TRACE=str(trace), MAT_WB_SCREENSHOTS=str(case / "frames"))
    started = time.monotonic()
    record = {"label": label, "command": command, "cwd": str(case), "userdata": str(userdata),
              "started_utc": datetime.now(timezone.utc).isoformat(), "scope": "diagnostic-only"}
    stop = case / "sampler.stop"
    sampler = None
    with (case / "godot.log").open("w", encoding="utf-8") as log, (case / "sampler.log").open("w", encoding="utf-8") as sampler_log:
        process = subprocess.Popen(command, cwd=case, env=env, stdout=log, stderr=subprocess.STDOUT)
        record["pid"] = process.pid
        write_json(case / "case.json", record)
        try:
            sampler = subprocess.Popen(["pwsh", "-NoLogo", "-NoProfile", "-File", str(evidence / "sample-processes.ps1"),
                "-RootProcessId", str(process.pid), "-Output", str(case / "processes.jsonl"), "-StopFile", str(stop)],
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
    print(json.dumps(record), flush=True)
    return record


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
    require(len(before["source_inputs"]) == 88 and len(before["build_inputs"]) == 832, "Incomplete source inventory")
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
    summary = {"scope": "DIAGNOSTIC ONLY; instrumented process, not release qualification",
               "source_commit": SOURCE, "source_tree": TREE, "native": identity, "godot": godot_identity,
               "original_artifact_id": 13996438401, "original_workflow_run": ORIGINAL_RUN,
               "diagnostic_workflow_run": os.environ.get("GITHUB_RUN_ID"),
               "diagnostic_helper_sha256": sha256(Path(__file__)), "hook_sha256": sha256(hook / "sitecustomize.py"),
               "cases": [], "source_unchanged": False}
    write_json(evidence / "diagnostic.json", summary)
    env = dict(os.environ, PYTHONPATH=str(hook), MAT_WB_DIAGNOSTIC_SOURCE=str(candidate),
               ART_UNDO_WORKERS="1", MAT_WB_REOPEN="0", PYTHONDONTWRITEBYTECODE="1")
    base = [str(godot), "--audio-driver", "Dummy", "--path", str(candidate / "godot")]
    try:
        imported = run_case(evidence, "import", base + ["--headless", "--editor", "--quit"], env, timeout=180)
        summary["cases"].append(imported)
        require(imported["exit_code"] == 0, "Frozen Godot project could not import")
        graphical = base + ["--print-fps", "--max-fps", "15", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3_angle"]
        summary["cases"].append(run_case(evidence, "combined-workers-1-author", graphical +
            ["--script", "res://tests/test_material_lab_workbench_integration.gd"], env))
        # Replay the exact byte-identical failing request without Godot. This
        # separates backend work from two-window presentation on the same host.
        requests = sorted((evidence / "combined-workers-1-author" / "userdata").rglob("request.json"))
        matching = [path for path in requests if sha256(path) == FAILED_REQUEST_SHA256]
        require(bool(matching), "The original failing request was not produced; direct replay refused")
        direct = evidence / "direct-request"
        direct.mkdir()
        request, response, cancel = (direct / name for name in ("request.json", "response.json", "cancel"))
        shutil.copyfile(matching[0], request)
        summary["direct_request_sha256"] = sha256(request)
        summary["cases"].append(run_case(evidence, "direct-backend-control", [sys.executable,
            str(candidate / "tools/material_catalogue/lab.py"), "--request", str(request),
            "--response", str(response), "--cancel-file", str(cancel)], env, timeout=300, cancel_file=cancel))
        # Retain the failed combined attempt and still execute the source-matched
        # original one-window World UI on this exact same Windows host.
        summary["cases"].append(run_case(evidence, "world-ui-control", graphical +
            ["--script", "res://tests/test_material_lab_world.gd", "--",
             "--capture-output=" + str(evidence / "world-ui-control" / "frames")], env))
        # Diagnostic capture-load experiment only. Product/test source and the
        # original 300s inner deadline are identical; it is not qualification.
        reduced = list(graphical)
        reduced[reduced.index("--max-fps") + 1] = "5"
        summary["cases"].append(run_case(evidence, "combined-5fps-capture-load-experiment", reduced +
            ["--script", "res://tests/test_material_lab_workbench_integration.gd"], env, timeout=600))
    finally:
        after = engine.input_ledgers(SOURCE)
        write_json(evidence / "source-after.json", after)
        summary["source_unchanged"] = before == after
        summary["native_unchanged"] = engine.runtime_identity(candidate / engine.RUNTIMES["windows"], "windows") == identity
        summary["files_sha256"] = {path.relative_to(evidence).as_posix(): sha256(path)
                                    for path in sorted(evidence.rglob("*")) if path.is_file() and path.name != "diagnostic.json"}
        write_json(evidence / "diagnostic.json", summary)
    require(summary["source_unchanged"] and summary["native_unchanged"], "Candidate custody changed during diagnosis")
    return 0 if all(case["exit_code"] == 0 for case in summary["cases"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
