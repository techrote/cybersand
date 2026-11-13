#!/usr/bin/env python3
"""Diagnostic only: compare original Windows Lab captures at 15 and 4 FPS.

No publication entry point, source edits, relaxed assertions or timeout changes.
Original controls execute the exact frozen scripts. Two additional controls
inherit the original UI fixture and observe copied state while delegating its
unchanged waits. Neither control group constitutes release qualification.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

SOURCE = "d66499ec3409fb657875fca7dbd0f234cf28ca49"
TREE = "016a2c058eaa8e21f8e039da5cae49753ddaeb0e"
NATIVE_SHA256 = "cc87121b6b77a75a4b58f70c0f74562c0f40bcf4e322f78b12ce3c944176b35d"
ORIGINAL_ARTIFACT = 14007501336
ORIGINAL_RUN = "https://github.com/techrote/cybersand/actions/runs/43358127824"
CASE_TIMEOUT = 1200
# Import and all five controls retain their complete original 1200 s limits.
# Expected wall time is much shorter; host admission must not assume that.
CAMPAIGN_SECONDS = 135 * 60

OBSERVER = r'''extends "res://tests/test_material_lab_ui.gd"
# Diagnostic-only observer outside res://. All assertions and waits belong to
# the unchanged parent fixture. Never call the native World or consume a snapshot.
var _diagnostic_wait: String = ""
var _diagnostic_wait_started: int = 0
var _diagnostic_last_sample: int = -1000

func _initialize() -> void:
	process_frame.connect(_diagnostic_process)
	print("MAT_WB_DIAGNOSTIC_OBSERVER " + JSON.stringify({
		"scope":"diagnostic-only external inherited observer",
		"original_test":"res://tests/test_material_lab_ui.gd",
		"original_test_sha256":FileAccess.get_sha256("res://tests/test_material_lab_ui.gd"),
		"observer_path":get_script().resource_path,
		"observer_sha256":FileAccess.get_sha256(get_script().resource_path)}))
	super._initialize()

func wait_for(predicate: Callable, message: String, deadline_ms: int = DEADLINE_MS) -> bool:
	_diagnostic_wait = message
	_diagnostic_wait_started = Time.get_ticks_msec()
	_diagnostic_emit("wait_start", {"deadline_ms":deadline_ms})
	var result: bool = await super.wait_for(predicate,message,deadline_ms)
	_diagnostic_emit("wait_end", {"result":result,"deadline_ms":deadline_ms})
	_diagnostic_wait = ""
	return result

func _diagnostic_process() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _diagnostic_last_sample < 1000: return
	_diagnostic_last_sample = now
	_diagnostic_emit("sample")

func _diagnostic_emit(event: String, extra: Dictionary = {}) -> void:
	var record := {"event":event,"unix_seconds":Time.get_unix_time_from_system(),
		"ticks_msec":Time.get_ticks_msec(),"process_frames":Engine.get_process_frames(),
		"frames_drawn":Engine.get_frames_drawn(),"reported_fps":Engine.get_frames_per_second(),
		"wait":_diagnostic_wait,"wait_elapsed_ms":Time.get_ticks_msec()-_diagnostic_wait_started}
	if is_instance_valid(panel):
		var experiment: Variant = panel.experiment
		record["lab"] = {"running":panel._running,"cached_readback_tick":experiment._readback_tick,
			"reference_target":experiment._reference_target,
			"cached_reference_tick":experiment._reference_current.get("completed_tick",-1)}
		if is_instance_valid(experiment._reference):
			record.lab["reference_cached_readback_tick"] = experiment._reference._readback_tick
	for child: Node in root.get_children():
		if not child.has_method("workbench_apply"): continue
		var main: Variant = child
		var pending: Dictionary = main.pending_microscenario_apply
		var context: Dictionary = main.tower_context
		var workbench: Variant = main.shared_workbench
		var snapshot: Variant = main.latest_snapshot
		record["owner"] = {"pending_serial":pending.get("serial",0),"pending_hash":pending.get("hash",""),
			"pending_empty":pending.is_empty(),"paused":main.paused,
			"microscenario_error":main.microscenario_error,"worker_start_error":main.worker_start_error,
			"world_extent":str(main.world_extent),"consumed_snapshot_serial":main.consumed_snapshot_serial,
			"published_serial":context.get("scenario_request_serial",0),
			"published_applied":context.get("scenario_request_applied",false),
			"micro_active":context.get("micro_active",false),"status":context.get("status",""),
			"workbench_refusal":context.get("workbench_refusal",""),
			"policy_present":not context.get("liquid_solver_policy",{}).is_empty()}
		if is_instance_valid(workbench):
			record.owner["applied_empty"] = workbench.applied.is_empty()
			record.owner["message"] = workbench.message
			record.owner["step_pending"] = workbench.step_pending
		if is_instance_valid(snapshot):
			record.owner["snapshot_serial"] = snapshot.serial
			record.owner["snapshot_tick"] = snapshot.tick_index
			record.owner["simulation_failed"] = snapshot.simulation_failed
		break
	record.merge(extra)
	print("MAT_WB_DIAGNOSTIC_OWNER " + JSON.stringify(record))
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


def host_snapshot(evidence: Path, case: Path, label: str) -> dict:
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
    return rows[0]


def run_case(evidence: Path, label: str, command: list[str], env: dict, *, userdata: Path | None = None,
             timeout: int = CASE_TIMEOUT, details: dict | None = None) -> dict:
    case = evidence / label
    case.mkdir()
    userdata = userdata if userdata is not None else case / "userdata"
    log_path = case / "godot.log"
    frames = case / "frames"
    env = dict(env, APPDATA=str(userdata), XDG_DATA_HOME=str(userdata))
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
    after = host_snapshot(evidence, case, "after")
    samples_path = case / "processes.jsonl"
    samples = [json.loads(line) for line in samples_path.read_text(encoding="utf-8-sig").splitlines()] if samples_path.is_file() else []
    record["sampler_errors"] = [row["error"] for row in samples if "error" in row]
    known = {row["identity"] for sample in samples for row in sample.get("processes", [])}
    record["owned_survivors"] = [row for row in after["host_processes"] if row.get("identity") in known]
    record["root_identity_observed"] = any(
        row.get("pid") == process.pid and row.get("identity") == sample.get("root_identity")
        for sample in samples for row in sample.get("processes", []))
    record["process_observation_complete"] = bool(samples) and record.get("sampler_exit_code") == 0 and not record["sampler_errors"]
    write_json(case / "case.json", record)
    print(json.dumps(record), flush=True)
    return record


# Original and instrumented runs are separate evidence. At 1 FPS the original UI
# cannot finish its 120 frame-driven native ticks within its unchanged 45 s wait;
# 4 FPS preserves that bound while reducing the software renderer's CPU demand.
CASE_PLAN = (
    ("original-ui-15fps", "test_material_lab_ui", 15, False),
    ("observed-ui-15fps", "test_material_lab_ui", 15, True),
    ("observed-ui-4fps", "test_material_lab_ui", 4, True),
    ("original-ui-4fps", "test_material_lab_ui", 4, False),
    ("original-world-4fps", "test_material_lab_world", 4, False),
)


def load_profile(candidate: Path):
    sys.path.insert(0, str(candidate / "tools/ci"))
    spec = importlib.util.spec_from_file_location("_frozen_mat_workbench", candidate / "tools/ci/mat_workbench_runtime_publication.py")
    profile = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(profile)
    engine = profile.engine
    engine.require(engine.ROOT == candidate, "Verifier must resolve to the frozen candidate")
    engine.require(engine.git("rev-parse", "HEAD").decode().strip() == SOURCE, "Wrong candidate source")
    engine.require(engine.git("rev-parse", "HEAD^{tree}").decode().strip() == TREE, "Wrong candidate tree")
    engine.require(engine.git("rev-parse", "--is-shallow-repository").decode().strip() == "false", "Full source history is required")
    return profile


def clean_environment() -> dict:
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    # The original controls do not load any Python/GDScript diagnostic hook.
    env.pop("PYTHONPATH", None)
    return env


def prepare(args, candidate: Path, evidence: Path, profile) -> int:
    engine, bundle = profile.engine, args.bundle.resolve()
    require = engine.require
    require(not evidence.exists(), "Use a fresh external diagnostic evidence directory")
    evidence.mkdir(parents=True)
    manifest = json.loads(engine.manifest_path(bundle, "windows").read_text(encoding="utf-8"))
    original = {"source_commit": SOURCE, "build_commit": SOURCE, "source_tree": TREE,
                "workflow_run": ORIGINAL_RUN, "workflow_attempt": "1", "build_attempt": "1",
                "schema_version": 1, "platform": "windows", "status": "built-not-executed",
                "evidence": "docs/audits/2026-11-12-mat-auth-workbench-integration.md"}
    require(all(manifest.get(key) == value for key, value in original.items()), "Wrong original build provenance")
    before = engine.input_ledgers(SOURCE)
    require(len(before["source_inputs"]) == 89 and len(before["build_inputs"]) == 841, "Incomplete source inventory")
    require(before == {key: manifest[key] for key in ("source_inputs", "build_inputs")}, "Original build inputs differ")
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
    (evidence / "observe-original-ui.gd").write_text(OBSERVER, encoding="utf-8", newline="\n")
    (evidence / "sample-processes.ps1").write_text(SAMPLER, encoding="utf-8", newline="\n")
    summary = {"schema": "mat-workbench-windows-diagnostic3-v1",
               "scope": "DIAGNOSTIC ONLY; original and observed controls are not release qualification",
               "source_commit": SOURCE, "source_tree": TREE, "native": identity, "godot": godot_identity,
               "godot_executable": str(godot), "original_artifact_id": ORIGINAL_ARTIFACT,
               "original_workflow_run": ORIGINAL_RUN,
               "diagnostic_workflow_run": os.environ.get("GITHUB_RUN_ID"),
               "diagnostic_workflow_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
               "diagnostic_commit": os.environ.get("GITHUB_SHA"),
               "host_logical_processors": os.cpu_count(), "candidate_compiler": os.environ.get("CYBERSAND_LAB_CXX"),
               "diagnostic_helper_sha256": sha256(Path(__file__)),
               "observer_sha256": sha256(evidence / "observe-original-ui.gd"),
               "sampler_sha256": sha256(evidence / "sample-processes.ps1"),
               "case_plan": [row[0] for row in CASE_PLAN], "cases": [], "completed": False,
               "campaign_started_monotonic": time.monotonic(), "campaign_budget_seconds": CAMPAIGN_SECONDS,
               "unchanged_graphical_watchdog_seconds": CASE_TIMEOUT,
               "unchanged_original_ui_native_tick_wait_ms": 45000,
               "unchanged_original_ui_installation_wait_ms": 60000}
    write_json(evidence / "diagnostic.json", summary)
    base = [str(godot), "--audio-driver", "Dummy", "--path", str(candidate / "godot")]
    imported = run_case(evidence, "import", base + ["--headless", "--editor", "--quit"], clean_environment())
    summary["import"] = imported
    summary["prepared"] = imported["exit_code"] == 0 and not imported["owned_survivors"]
    write_json(evidence / "diagnostic.json", summary)
    require(summary["prepared"], "Frozen Godot project could not import or retained an owned child")
    return 0


def verify_graphical_case(profile, candidate: Path, case: Path, name: str, observed: bool, summary: dict) -> dict:
    """Read original receipts without fabricating a publisher acceptance report."""
    require = profile.engine.require
    log = (case / "godot.log").read_text(encoding="utf-8")
    require(len(re.findall(profile.engine.CASE_MARKERS[name], log)) == 1, "Original assertion completion marker is absent")
    require("SCRIPT ERROR" not in log and "Parse Error" not in log, "Godot script diagnostics were emitted")
    manifest_name, image_name, receipt_name = profile.lab.GRAPHICAL_CASES[name]
    frames = case / "frames"
    manifest = json.loads((frames / manifest_name).read_text(encoding="utf-8"))
    receipt = json.loads((frames / receipt_name).read_text(encoding="utf-8"))
    require(manifest.get("platform") == "Windows" and manifest.get("display") == "Windows" and
            manifest.get("engine", {}).get("string") == "4.7-stable (official)" and
            manifest.get("failures") == 0 and manifest.get("runtime_active") is False,
            "Original capture did not complete on the pinned graphical Windows runtime")
    image_path = frames / image_name
    require(image_path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n") and
            sha256(image_path) == manifest.get("image_sha256"), "Original capture image differs")
    current = profile.lab.current_world_source()
    require(receipt.get("source_identity") == manifest.get("native_source_identity") and
            receipt["source_identity"].get("git_head") == SOURCE and
            receipt["source_identity"].get("digest") == current["digest"] and
            receipt["source_identity"].get("lf_sha256") == current["lf_sha256"], "Original native source differs")
    require(receipt.get("runtime_active") is False and receipt.get("candidate", {}).get("world_simulation") is True and
            all(receipt.get("checks", {}).get(key) is True for key in
                ("source_unchanged", "candidate_qualification", "reference_qualification")), "Original native receipt is incomplete")
    for side in ("candidate", "reference"):
        checks = receipt.get(side, {}).get("checks", {})
        require(profile.lab.WORLD_CHECKS.issubset(checks) and all(value is True for value in checks.values()),
                "Native World checks did not complete: " + side)
    source_map = manifest.get("source_sha256", {})
    require("tests/" + name + ".gd" in source_map, "Original fixture source identity is missing")
    for relative, digest in source_map.items():
        path = Path(relative)
        require(not path.is_absolute() and ".." not in path.parts and
                sha256(candidate / "godot" / path) == digest, "Captured source changed: " + relative)
    if name == "test_material_lab_ui":
        require(manifest.get("native_library_sha256") == NATIVE_SHA256, "Original UI used a different native DLL")
    prefix = "MAT_WB_DIAGNOSTIC_OBSERVER "
    observer_headers = [json.loads(line[len(prefix):]) for line in log.splitlines() if line.startswith(prefix)]
    if observed:
        require(len(observer_headers) == 1 and
                observer_headers[0].get("observer_sha256") == summary["observer_sha256"] and
                observer_headers[0].get("original_test_sha256") == source_map["tests/test_material_lab_ui.gd"],
                "External observer identity differs")
    else:
        require(not observer_headers, "An original control unexpectedly loaded the observer")
    return {"capture_assertions": manifest.get("assertions", manifest.get("checks")),
            "manifest_sha256": sha256(frames / manifest_name), "receipt_sha256": sha256(frames / receipt_name),
            "image_sha256": sha256(image_path), "observed": observed}


def execute_one(args, candidate: Path, evidence: Path, profile, summary: dict) -> int:
    require = profile.engine.require
    require(summary.get("prepared") is True, "Diagnostic preparation did not complete")
    expected = {row[0]: row for row in CASE_PLAN}
    label, name, fps, observed = expected[args.case]
    require(label not in [row["label"] for row in summary["cases"]], "A diagnostic case cannot overwrite original evidence")
    before = json.loads((evidence / "source-before.json").read_text(encoding="utf-8"))
    require(profile.engine.input_ledgers(SOURCE) == before, "Source changed before the next control")
    require(sha256(candidate / profile.engine.RUNTIMES["windows"]) == NATIVE_SHA256, "Native DLL changed")
    require(sha256(evidence / "observe-original-ui.gd") == summary["observer_sha256"] and
            sha256(evidence / "sample-processes.ps1") == summary["sampler_sha256"], "Diagnostic apparatus changed")
    godot = Path(summary["godot_executable"])
    require(sha256(godot) == summary["godot"]["console_sha256"], "Pinned Godot executable changed")
    require(sha256(godot.with_name(godot.name.replace("_console", ""))) == summary["godot"]["runtime_sha256"],
            "Pinned Godot graphical runtime changed")
    rapier, rapier_hash = profile.engine.RAPIER["windows"]
    require(sha256(candidate / rapier) == rapier_hash, "Pinned Rapier runtime changed")
    elapsed = time.monotonic() - summary["campaign_started_monotonic"]
    if elapsed + CASE_TIMEOUT + 90 > CAMPAIGN_SECONDS:
        record = {"label": label, "status": "not_run", "fixture_complete": False,
                  "reason": "Insufficient remaining host budget for the complete unchanged1200s watchdog",
                  "elapsed_campaign_seconds": elapsed}
        (evidence / label).mkdir()
        write_json(evidence / label / "case.json", record)
        summary["cases"].append(record)
        write_json(evidence / "diagnostic.json", summary)
        print(json.dumps(record), flush=True)
        return 1
    selected_script = str(evidence / "observe-original-ui.gd") if observed else "res://tests/" + name + ".gd"
    command = [str(godot), "--audio-driver", "Dummy", "--path", str(candidate / "godot"),
               "--print-fps", "--max-fps", str(fps), "--rendering-method", "gl_compatibility",
               "--rendering-driver", "opengl3_angle", "--script", selected_script, "--",
               "--capture-output=" + str(evidence / label / "frames")]
    record = run_case(evidence, label, command, clean_environment(), details={
        "max_fps": fps, "original_fixture": name, "observed": observed, "source_commit": SOURCE,
        "source_tree": TREE, "native_sha256": NATIVE_SHA256,
        "original_fixture_sha256": sha256(candidate / "godot/tests" / (name + ".gd")),
        "observer_sha256": summary["observer_sha256"] if observed else None})
    record["fixture_complete"] = False
    try:
        require(record["exit_code"] == 0 and "outer_timeout_seconds" not in record, "Original fixture failed or exceeded its watchdog")
        require(record["process_observation_complete"] and record["root_identity_observed"] and not record["owned_survivors"],
                "Process identity observation or owned cleanup is incomplete")
        record["capture"] = verify_graphical_case(profile, candidate, evidence / label, name, observed, summary)
        record["fixture_complete"] = True
    except Exception as error:
        record["fixture_validation_error"] = str(error)
    log = (evidence / label / "godot.log").read_text(encoding="utf-8")
    pattern = (r"(?m)^MATERIAL_LAB_UI: ([0-9]+) assertions; ([0-9]+) failures" if name == "test_material_lab_ui" else
               r"(?m)^Materials Lab World UI: ([0-9]+) checks, ([0-9]+) failures")
    terminals = re.findall(pattern, log)
    record["original_terminal_markers"] = [{"assertions": int(count), "failures": int(failed)} for count, failed in terminals]
    prefix = "MAT_WB_DIAGNOSTIC_OWNER "
    owner_lines = [line[len(prefix):] for line in log.splitlines() if line.startswith(prefix)]
    (evidence / label / "owner-observations.jsonl").write_text("\n".join(owner_lines) + ("\n" if owner_lines else ""), encoding="utf-8")
    record["source_unchanged"] = profile.engine.input_ledgers(SOURCE) == before
    record["native_unchanged"] = sha256(candidate / profile.engine.RUNTIMES["windows"]) == NATIVE_SHA256
    record["status"] = "passed" if record["fixture_complete"] and record["source_unchanged"] and record["native_unchanged"] else "failed"
    write_json(evidence / label / "case.json", record)
    summary["cases"].append(record)
    write_json(evidence / "diagnostic.json", summary)
    print("DIAGNOSTIC3_CONTROL_COMPLETE " + json.dumps(record), flush=True)
    return 0 if record["status"] == "passed" else 1


def finish(candidate: Path, evidence: Path, profile, summary: dict) -> int:
    before = json.loads((evidence / "source-before.json").read_text(encoding="utf-8"))
    after = profile.engine.input_ledgers(SOURCE)
    write_json(evidence / "source-after.json", after)
    summary["source_unchanged"] = before == after
    summary["native_unchanged"] = sha256(candidate / profile.engine.RUNTIMES["windows"]) == NATIVE_SHA256
    summary["completed"] = [row["label"] for row in summary["cases"]] == [row[0] for row in CASE_PLAN] and all(
        row.get("status") in ("passed", "failed") for row in summary["cases"])
    summary["all_controls_passed"] = summary["completed"] and all(row["status"] == "passed" for row in summary["cases"])
    summary["files_sha256"] = {path.relative_to(evidence).as_posix(): sha256(path)
        for path in sorted(evidence.rglob("*")) if path.is_file() and path != evidence / "diagnostic.json"}
    write_json(evidence / "diagnostic.json", summary)
    print("DIAGNOSTIC3_SUMMARY " + json.dumps({key: summary[key] for key in
          ("source_commit", "source_tree", "completed", "all_controls_passed", "source_unchanged", "native_unchanged")}), flush=True)
    return 0 if summary["all_controls_passed"] and summary["source_unchanged"] and summary["native_unchanged"] else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--godot-archive", type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--prepare", action="store_true")
    mode.add_argument("--case", choices=[row[0] for row in CASE_PLAN])
    mode.add_argument("--finish", action="store_true")
    args = parser.parse_args()
    if sys.platform != "win32": raise RuntimeError("This diagnostic requires the actual Windows host")
    candidate, evidence = args.candidate.resolve(), args.evidence.resolve()
    if evidence.is_relative_to(candidate): raise RuntimeError("Evidence and userdata must remain outside source custody")
    profile = load_profile(candidate)
    if args.prepare:
        if args.bundle is None or args.godot_archive is None: parser.error("Preparation needs the original bundle and pinned Godot archive")
        return prepare(args, candidate, evidence, profile)
    summary = json.loads((evidence / "diagnostic.json").read_text(encoding="utf-8"))
    profile.engine.require(summary.get("source_commit") == SOURCE and summary.get("source_tree") == TREE and
        summary.get("diagnostic_helper_sha256") == sha256(Path(__file__)) and
        summary.get("diagnostic_workflow_run") == os.environ.get("GITHUB_RUN_ID") and
        summary.get("diagnostic_workflow_attempt") == os.environ.get("GITHUB_RUN_ATTEMPT"), "Diagnostic custody changed between steps")
    return execute_one(args, candidate, evidence, profile, summary) if args.case else finish(candidate, evidence, profile, summary)


if __name__ == "__main__":
    raise SystemExit(main())
