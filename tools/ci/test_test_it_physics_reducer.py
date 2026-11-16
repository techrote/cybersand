#!/usr/bin/env python3
"""Cross-check the real Test It PowerShell reducer without launching Godot.

Use --require-windows-powershell51 on Windows qualification. Optional retained
Test It evidence is read only; replay reports are written to a separate output
directory. Python is a CI dependency, not a requirement of the owner runner.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys

from analyze_pose_trace import analyze_physics_progress, read_trace


POWERSHELL = r"""
param([string]$TestIt,[string]$Inputs,[string]$Output)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Tokens=$null;$Errors=$null
$Ast=[System.Management.Automation.Language.Parser]::ParseFile($TestIt,[ref]$Tokens,[ref]$Errors)
if($Errors.Count -gt 0){throw ($Errors|Out-String)}
$Names=@('Require','Sha','Field','Gap','Distribution','Physics-Distribution',
         'Event-Time','Read-PhysicsProgress','Read-PoseStatistics')
$Loaded=@()
foreach($Node in $Ast.FindAll({param($Node)
    $Node -is [System.Management.Automation.Language.FunctionDefinitionAst]},$false)) {
    if($Names -contains $Node.Name){
        . ([scriptblock]::Create($Node.Extent.Text));$Loaded+=$Node.Name
    }
}
Require ($Loaded.Count -eq $Names.Count) 'Missing production reducer functions'
$Data=Get-Content -LiteralPath $Inputs -Raw -Encoding UTF8|ConvertFrom-Json
$Result=@{powershell=@{version=[string]$PSVersionTable.PSVersion
    edition=[string]$PSVersionTable.PSEdition;home=$PSHOME}
    runner_sha256=(Sha $TestIt);fixtures=@{};traces=@{}}
foreach($Fixture in $Data.fixtures){
    $Result.fixtures[$Fixture.name]=Read-PhysicsProgress $Fixture.frames $Fixture.events
}
foreach($Trace in $Data.traces){
    $Analysis=Read-PoseStatistics $Trace.path
    $Result.traces[$Trace.name]=@{trace_sha256=(Sha $Trace.path);statistics=$Analysis.statistics}
}
[IO.File]::WriteAllText($Output,(($Result|ConvertTo-Json -Depth 50)+[Environment]::NewLine),
    [Text.UTF8Encoding]::new($false))
Write-Host ('TEST_IT_REDUCER_REPLAY '+$Result.fixtures.Count+' fixtures, '+$Result.traces.Count+' traces')
"""


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True)+"\n", encoding="utf-8")


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def step(number, when):
    return {"event": "rapier_step", "step": number, "time_usec": when,
            "start_usec": when-100, "solver_usec": 60, "flush_usec": 10}


def fixtures():
    # More than ten intervals, nonmonotonic gap magnitudes, four equal maxima,
    # and shuffled completion input expose key lookup, numeric sorting and ties.
    gaps = [9, 1200, 90, 250, 1200, 2, 100, 900, 1200, 20, 250, 5, 1200, 100, 9]
    now = 1_000_000
    events = [step(0, now)]
    for number, gap in enumerate(gaps, 1):
        now += gap*1000
        events.append(step(number, now))
    shuffled = list(reversed(events[::2]))+events[1::2]
    result = [{"name": "unsorted_hashtable_gaps_ties_top10", "frames": [], "events": shuffled}]
    now = 1_000_000
    fractional = [step(0, now)]
    for number, gap in enumerate([125, 1000, 10, 125, 1000, 125], 1):
        now += gap
        fractional.append(step(number, now))
    result.append({"name": "fractional_milliseconds_equal_gaps", "frames": [],
                   "events": list(reversed(fractional))})
    result.append({"name": "pause_and_missing_completions", "frames": [
        {"time_usec": 20_000, "rapier_step": 1, "paused": False},
        {"time_usec": 30_000, "rapier_step": 1, "paused": True},
        {"time_usec": 2_100_000, "rapier_step": 5, "paused": False},
        {"time_usec": 2_200_000, "rapier_step": 5, "paused": False}], "events": [
            step(1, 10_000), step(2, 1_010_000), step(5, 2_010_000), step(6, 2_260_000),
            {"event": "rapier_hold", "time_usec": 500_000, "reason": "paused"},
            {"event": "rapier_hold", "time_usec": 1_500_000, "reason": "native_sample"},
            {"event": "rapier_hold", "time_usec": 2_210_000, "reason": "terrain_installation"}]})
    result.append({"name": "frames_without_completions", "frames": [
        {"time_usec": 1000, "rapier_step": 1}, {"time_usec": 2000, "rapier_step": 1}],
        "events": []})
    return result


def differences(expected, actual, path=""):
    if isinstance(expected, dict) and isinstance(actual, dict):
        if expected.keys() != actual.keys():
            yield {"path": path, "expected_keys": sorted(expected), "actual_keys": sorted(actual)}
        for key in sorted(expected.keys() & actual.keys()):
            yield from differences(expected[key], actual[key], path+"."+key)
    elif isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            yield {"path": path, "expected_length": len(expected), "actual_length": len(actual)}
        for i, (left, right) in enumerate(zip(expected, actual)):
            yield from differences(left, right, f"{path}[{i}]")
    elif (isinstance(expected, (int, float)) and not isinstance(expected, bool)
          and isinstance(actual, (int, float)) and not isinstance(actual, bool)):
        if not math.isclose(expected, actual, rel_tol=1e-10, abs_tol=1e-6):
            yield {"path": path, "expected": expected, "actual": actual}
    elif expected != actual:
        yield {"path": path, "expected": expected, "actual": actual}


def without_witnesses(statistics):
    result = dict(statistics)
    result["physics_progress"] = {key: value for key, value in result["physics_progress"].items()
                                  if key != "largest_active_gaps"}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--powershell", default="powershell.exe")
    parser.add_argument("--test-it", type=Path, default=Path(__file__).resolve().parents[2]/"Run-Test-It.ps1")
    parser.add_argument("--evidence-root", type=Path,
                        help="Retained timestamped Test It directory containing summary.json and cases/.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-windows-powershell51", action="store_true")
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    report = {"schema": "test-it-physics-reducer-replay-v1", "complete": False, "passed": False,
              "runner": str(args.test_it.resolve()), "runner_sha256": sha(args.test_it),
              "analyzer_sha256": sha(Path(__file__).with_name("analyze_pose_trace.py")),
              "fixtures": [], "traces": [], "failures": []}
    try:
        samples = fixtures()
        expected_fixtures = {sample["name"]: analyze_physics_progress(sample["frames"], sample["events"])
                             for sample in samples}
        known = expected_fixtures["unsorted_hashtable_gaps_ties_top10"]
        assert [row["step"] for row in known["largest_active_gaps"]] == [2, 5, 9, 13, 8, 4, 11, 7, 14, 3]
        assert known["active_completed_step_gap_ms"]["maximum"] == 1200
        traces, prior = [], {}
        if args.evidence_root:
            summary_file = args.evidence_root/"summary.json"
            summary = read_json(summary_file)
            report["original_summary_sha256"] = sha(summary_file)
            report["original_source"] = summary["source"]
            for row in summary["cases"]:
                path = (args.evidence_root/"cases"/row["name"]/"receipt-poses.jsonl").resolve()
                if sha(path) != row["trace_sha256"]:
                    raise ValueError("Original trace checksum mismatch: "+row["name"])
                traces.append({"name": row["name"], "path": str(path)})
                prior[row["name"]] = row
        write_json(args.output/"inputs.json", {"fixtures": samples, "traces": traces})
        write_json(args.output/"expected-fixtures.json", expected_fixtures)
        script = args.output/"replay.ps1"
        script.write_text(POWERSHELL, encoding="utf-8")
        command = [args.powershell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                   "-File", str(script), "-TestIt", str(args.test_it.resolve()),
                   "-Inputs", str(args.output/"inputs.json"), "-Output", str(args.output/"powershell.json")]
        report["command"] = command
        # Match Test It.cmd: a powershell.exe child must not inherit PowerShell
        # 7 module paths from a pwsh-hosted workflow. Let the child initialize
        # its own in-box paths; retain every other environment setting.
        environment = {key: value for key, value in os.environ.items() if key.upper() != "PSMODULEPATH"}
        report["module_path_initialization"] = "clear_inherited_PSModulePath_case_insensitive"
        execution = subprocess.run(command, capture_output=True, text=True, timeout=600, env=environment)
        (args.output/"stdout.log").write_text(execution.stdout, encoding="utf-8")
        (args.output/"stderr.log").write_text(execution.stderr, encoding="utf-8")
        report["exit_code"] = execution.returncode
        if execution.returncode:
            raise RuntimeError("PowerShell reducer failed; see retained stdout.log/stderr.log")
        actual = read_json(args.output/"powershell.json")
        report["powershell"] = actual["powershell"]
        if args.require_windows_powershell51:
            if not (actual["powershell"]["version"].startswith("5.1.")
                    and actual["powershell"]["edition"] == "Desktop"):
                raise ValueError("Qualification requires Windows PowerShell5.1 Desktop")
        if actual["runner_sha256"] != report["runner_sha256"]:
            raise ValueError("Reducer source changed during replay")
        for name, expected in expected_fixtures.items():
            failures = list(differences(expected, actual["fixtures"][name], "fixtures."+name))
            report["failures"].extend(failures)
            report["fixtures"].append({"name": name, "passed": not failures})
        for trace in traces:
            name, path = trace["name"], Path(trace["path"])
            _, frames, footer = read_trace(path)
            expected = analyze_physics_progress(frames, footer["_events"])
            reduced = actual["traces"][name]
            if reduced["trace_sha256"] != prior[name]["trace_sha256"]:
                raise ValueError("Trace changed during replay: "+name)
            failures = list(differences(expected, reduced["statistics"]["physics_progress"], name+".physics_progress"))
            # Only ranked witnesses should change from the original PS5.1
            # reduction. Check all other original statistics, not just gaps.
            failures += list(differences(without_witnesses(prior[name]["statistics"]),
                                         without_witnesses(reduced["statistics"]), name+".unchanged_statistics"))
            report["failures"].extend(failures)
            report["traces"].append({"name": name, "trace_sha256": reduced["trace_sha256"], "passed": not failures,
                "original_witnesses_differ": prior[name]["statistics"]["physics_progress"]["largest_active_gaps"] != expected["largest_active_gaps"],
                "physics_progress": expected})
        report["complete"] = True
        report["passed"] = not report["failures"]
    except Exception as error:
        report["failures"].append({"error": repr(error)})
    write_json(args.output/"summary.json", report)
    print("TEST_IT_PHYSICS_REDUCER_RESULT "+json.dumps({
        "passed": report["passed"], "complete": report["complete"],
        "fixtures": len(report["fixtures"]), "traces": len(report["traces"]),
        "failures": len(report["failures"]), "report": str(args.output/"summary.json")}))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
