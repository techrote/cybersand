#!/usr/bin/env python3
"""Execute the pristine delivered Windows CMD, retaining exact process/route proof.

This is a launcher witness, not physical owner acceptance or general playability.
The separate native/UI/actor suites qualify functionality after this bounded run.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audit_payload(package: Path, manifest: dict, *, after_import: bool = False) -> list[dict]:
    """Only generated Godot import sidecars may change after the actual CMD import."""
    changed = []
    root = package.resolve()
    files = manifest.get("files_sha256")
    if not isinstance(files, dict) or not files:
        raise ValueError("Nonempty payload manifest required")
    # A pristine extraction must contain exactly the manifested payload plus
    # its manifest. An unlisted script/config could otherwise change execution.
    for path in sorted(root.rglob("*")):
        if path.is_symlink() or not path.resolve().is_relative_to(root):
            raise ValueError("Unsafe extra packaged path: " + str(path))
        if not path.is_file(): continue
        name = path.relative_to(root).as_posix()
        if name in files or name == "candidate-manifest.json": continue
        generated = (name.startswith("godot/.godot/")
                     or (name.startswith("godot/") and name.endswith(".import") and name[:-7] in files)
                     or (name.startswith("godot/") and name.endswith(".uid") and name[:-4] in files))
        if not after_import or not generated:
            raise ValueError("Unlisted packaged file: " + name)
        changed.append({"path":name, "after_sha256":digest(path), "classification":"New Godot generated cache or source sidecar"})
    for name, expected in files.items():
        path = root / name
        if Path(name).is_absolute() or path.is_symlink() or not path.resolve().is_relative_to(root) or not path.is_file():
            raise ValueError("Unsafe or missing packaged file: " + name)
        actual = digest(path)
        if actual != expected:
            if after_import and name.startswith("godot/") and name.endswith(".import"):
                changed.append({"path": name, "before_sha256": expected, "after_sha256": actual,
                                "classification": "Godot generated import sidecar"})
            else:
                raise ValueError("Packaged file changed: " + name)
    return changed


def owned(row: dict, parent_pid: int, paths: set[str]) -> bool:
    return (row.get("ParentProcessId") == parent_pid
            and str(row.get("ExecutablePath", "")).lower() in paths)


def powershell(script: str, env: dict, timeout: int = 20) -> str:
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    process = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
                             env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if process.returncode:
        raise RuntimeError("Launcher process inspection failed: " + process.stderr[-2000:])
    return process.stdout.strip()


QUERY = r'''$ErrorActionPreference='Stop'
# Windows PowerShell 5.1 emits a JSON array as ONE pipeline object. Wrapping
# ConvertFrom-Json in @() nests it, causing every string membership check to fail.
# Assign first, then explicitly enumerate scalar strings into a typed list.
$parsed=ConvertFrom-Json -InputObject $env:CYBERSAND_LAUNCHER_PATHS
$paths=New-Object 'System.Collections.Generic.List[string]'
foreach($item in $parsed){
 if(-not ($item -is [string]) -or -not [System.IO.Path]::IsPathRooted($item)){throw 'Expected absolute scalar executable paths'}
 $paths.Add($item.ToLowerInvariant())
}
if($paths.Count -ne 2){throw 'Expected exactly two executable paths'}
$rows=@(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $paths.Contains($_.ExecutablePath.ToLowerInvariant()) } | ForEach-Object {
 $p=Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
 [pscustomobject]@{ProcessId=[int]$_.ProcessId;ParentProcessId=[int]$_.ParentProcessId;ExecutablePath=$_.ExecutablePath;
 CreationDate=$_.CreationDate.ToUniversalTime().ToString('o');CommandLine=$_.CommandLine;MainWindowHandle=if($p){$p.MainWindowHandle.ToInt64()}else{0}}
})
[pscustomobject]@{powershell_version=$PSVersionTable.PSVersion.ToString();paths=$paths.ToArray();processes=$rows} | ConvertTo-Json -Depth 4 -Compress
'''


def process_inventory(env: dict) -> dict:
    value = json.loads(powershell(QUERY, env) or "null")
    expected = json.loads(env["CYBERSAND_LAUNCHER_PATHS"])
    if (not isinstance(value, dict) or value.get("paths") != expected
            or not isinstance(value.get("processes"), list)
            or not isinstance(value.get("powershell_version"), str)
            or any(not isinstance(row, dict) for row in value["processes"])):
        raise ValueError("Windows process query did not retain two scalar path filters and typed process rows")
    return value


def processes(env: dict) -> list[dict]:
    return process_inventory(env)["processes"]


def query_self_test(env: dict | None = None) -> dict:
    """A real Windows query must find this caller before trusting an empty list."""
    executable = str(Path(sys.executable).resolve()).lower()
    paths = [executable, executable + ".nonexistent-query-control"]
    effective = dict(os.environ if env is None else env, CYBERSAND_LAUNCHER_PATHS=json.dumps(paths))
    inventory = process_inventory(effective)
    matches = [row for row in inventory["processes"]
               if row.get("ProcessId") == os.getpid()
               and str(row.get("ExecutablePath", "")).lower() == executable
               and isinstance(row.get("CreationDate"), str) and row["CreationDate"]]
    if len(matches) != 1:
        raise RuntimeError("Windows process query failed to observe its exact caller PID/executable/creation identity")
    return {"passed": True, "checks": 3, "failures": [], "powershell_version": inventory["powershell_version"],
            "paths": inventory["paths"], "observed_self": matches[0]}


def close_owned(row: dict, env: dict) -> None:
    effective = dict(env, CYBERSAND_LAUNCHER_PROCESS=json.dumps(row))
    powershell(r'''$ErrorActionPreference='Stop'
$r=$env:CYBERSAND_LAUNCHER_PROCESS | ConvertFrom-Json
$p=Get-CimInstance Win32_Process -Filter ("ProcessId="+[int]$r.ProcessId)
if($p -and $p.ExecutablePath -eq $r.ExecutablePath -and $p.CreationDate.ToUniversalTime().ToString('o') -eq $r.CreationDate){
 $g=Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
 if($g){[void]$g.CloseMainWindow()}
 if($g -and -not $g.WaitForExit(8000)){
  $p2=Get-CimInstance Win32_Process -Filter ("ProcessId="+[int]$r.ProcessId)
  if($p2 -and $p2.ExecutablePath -eq $r.ExecutablePath -and $p2.CreationDate.ToUniversalTime().ToString('o') -eq $r.CreationDate){Stop-Process -Id $p2.ProcessId -Force}
 }
}
''', effective)


def run(package: Path, evidence: Path, source: str) -> dict:
    if sys.platform != "win32":
        raise ValueError("Actual delivered CMD qualification requires Windows")
    package = package.resolve(); evidence.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((package / "candidate-manifest.json").read_bytes())
    if manifest.get("source_commit") != source:
        raise ValueError("Launcher package source differs")
    if (package / "godot/.godot").exists():
        raise ValueError("Delivered CMD must start in a pristine extraction before Godot import")
    audit_payload(package, manifest)
    launcher = package / "Open Workbench.cmd"
    gui = package / "Godot_v4.7-stable_win64.exe"
    console = package / "Godot_v4.7-stable_win64_console.exe"
    paths = {str(gui).lower(), str(console).lower()}
    for path in (launcher, gui, console):
        if not path.is_file(): raise ValueError("Missing exact delivered launcher/runtime: " + path.name)
    profile = evidence / "fresh-userdata"
    if profile.exists(): raise ValueError("Launcher profile must be fresh")
    profile.mkdir()
    env = dict(os.environ, APPDATA=str(profile), XDG_DATA_HOME=str(profile), CYBERSAND_LAUNCHER_PATHS=json.dumps(sorted(paths)))
    report = {"format": "cybersand-extracted-windows-launcher-v1", "source_revision": source,
              "launcher_sha256": digest(launcher), "gui_sha256": digest(gui), "console_sha256": digest(console),
              "native_binary_sha256": manifest["native_sha256"], "pristine_payload_verified": True, "manifest_sha256":digest(package / "candidate-manifest.json"),
              "checks": 1, "failures": [], "physical_owner_acceptance": "pending",
              "scope": "Actual unchanged delivered CMD, visible child process and accepted Workbench route. Native functionality is qualified separately."}
    process = None; seen = {}; error = None; begun = time.monotonic()
    report["monitor_samples"] = []
    try:
        report["query_self_test"] = query_self_test(env)
        before = processes(env)
        report["preexisting_processes"] = before
        if before: raise ValueError("Packaged engine is already running; pristine launch cannot be isolated")
        with (evidence / "launcher-process.log").open("w", encoding="utf-8") as output:
            process = subprocess.Popen([os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", str(launcher)],
                                       cwd=package, env=env, stdout=output, stderr=subprocess.STDOUT)
            report["launcher_pid"] = process.pid
            report["launcher_command"] = process.args
            launch_begun = time.monotonic()
            while time.monotonic() - launch_begun < 150:
                rows = processes(env)
                for row in rows:
                    if owned(row, process.pid, paths): seen[(row["ProcessId"], row["CreationDate"])] = row
                visible = [row for row in rows if owned(row, process.pid, paths)
                           and str(row["ExecutablePath"]).lower() == str(gui).lower()
                           and int(row.get("MainWindowHandle", 0)) != 0
                           and "--workbench" in str(row.get("CommandLine", ""))]
                logs = sorted(profile.rglob("godot.log"))
                ready = [(path, path.read_text(encoding="utf-8", errors="replace")) for path in logs]
                routed = [(path, text) for path, text in ready if "SHARED_WORKBENCH_LAUNCH_READY" in text]
                sample = {"elapsed_seconds": round(time.monotonic() - launch_begun, 3),
                          "cmd_exit_code": process.poll(), "matching_processes": rows[:16],
                          "owned_processes": [row for row in rows if owned(row, process.pid, paths)][:16],
                          "visible_owned_gui": visible[:16],
                          "route_logs": [{"path": path.relative_to(evidence).as_posix(), "sha256": digest(path),
                                          "ready": "SHARED_WORKBENCH_LAUNCH_READY" in text} for path, text in ready[:4]]}
                report["monitor_samples"].append(sample)
                if len(report["monitor_samples"]) > 160: report["monitor_samples"].pop(0)
                if visible and routed and process.poll() == 0 and time.monotonic() - launch_begun >= 5:
                    path, text = routed[-1]
                    if any(token in text for token in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script")):
                        raise RuntimeError("Actual launcher route produced script errors")
                    report.update(observed_process=visible[0], launcher_exit_code=0,
                                  route_log=path.relative_to(evidence).as_posix(), route_log_sha256=digest(path),
                                  accepted_route_marker="SHARED_WORKBENCH_LAUNCH_READY", checks=8)
                    break
                if process.poll() not in (None, 0): raise RuntimeError("Delivered CMD failed: " + str(process.returncode))
                time.sleep(1)
            else: raise TimeoutError("Delivered CMD did not produce a visible Workbench-routed child within 150 seconds")
    except Exception as caught:
        error = caught
    finally:
        try:
            for row in processes(env):
                if process is not None and owned(row, process.pid, paths): seen[(row["ProcessId"], row["CreationDate"])] = row
            for row in seen.values(): close_owned(row, env)
            if process is not None and process.poll() is None:
                process.terminate(); process.wait(timeout=10)
            remaining = [row for row in processes(env) if (row["ProcessId"], row["CreationDate"]) in seen]
            if remaining: raise RuntimeError("Exact launcher children remained alive after bounded cleanup")
            report["cleanup"] = "Only exact observed child image/PID/creation identities closed; none remain"
            report["generated_import_changes"] = audit_payload(package, manifest, after_import=True)
            if digest(package / "candidate-manifest.json") != report["manifest_sha256"]:
                raise ValueError("Package manifest changed during delivered launcher execution")
            report["checks"] += 2
        except Exception as caught:
            report.setdefault("cleanup_failures", []).append(str(caught))
            error = error or caught
        report["elapsed_seconds"] = round(time.monotonic() - begun, 3)
        report["passed"] = error is None
        if error: report["failures"].append(str(error))
        (evidence / "launcher.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if error: raise error
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--query-self-test", action="store_true", help="Read-only Windows query probe; no package or app launch")
    parser.add_argument("--package", type=Path)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--source")
    args = parser.parse_args()
    if args.query_self_test:
        print("WINDOWS_PROCESS_QUERY_SELF_TEST " + json.dumps(query_self_test()))
        return
    if args.package is None or args.evidence is None or args.source is None:
        parser.error("--package, --evidence and --source are required for actual delivered CMD qualification")
    result = run(args.package, args.evidence, args.source)
    print("WINDOWS_EVALUATOR_LAUNCHER_RESULT " + json.dumps({"checks": result["checks"], "failures": [], "passed": True}))


if __name__ == "__main__": main()
