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
$paths=@($env:CYBERSAND_LAUNCHER_PATHS | ConvertFrom-Json)
$rows=@(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -and $paths -contains $_.ExecutablePath.ToLowerInvariant() } | ForEach-Object {
 $p=Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
 [pscustomobject]@{ProcessId=[int]$_.ProcessId;ParentProcessId=[int]$_.ParentProcessId;ExecutablePath=$_.ExecutablePath;
 CreationDate=$_.CreationDate.ToUniversalTime().ToString('o');CommandLine=$_.CommandLine;MainWindowHandle=if($p){$p.MainWindowHandle.ToInt64()}else{0}}
})
ConvertTo-Json -InputObject $rows -Compress
'''


def processes(env: dict) -> list[dict]:
    value = json.loads(powershell(QUERY, env) or "[]")
    return value if isinstance(value, list) else [value]


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
    if processes(env): raise ValueError("Packaged engine is already running; pristine launch cannot be isolated")
    report = {"format": "cybersand-extracted-windows-launcher-v1", "source_revision": source,
              "launcher_sha256": digest(launcher), "gui_sha256": digest(gui), "console_sha256": digest(console),
              "native_binary_sha256": manifest["native_sha256"], "pristine_payload_verified": True, "manifest_sha256":digest(package / "candidate-manifest.json"),
              "checks": 1, "failures": [], "physical_owner_acceptance": "pending",
              "scope": "Actual unchanged delivered CMD, visible child process and accepted Workbench route. Native functionality is qualified separately."}
    process = None; seen = {}; error = None; begun = time.monotonic()
    try:
        with (evidence / "launcher-process.log").open("w", encoding="utf-8") as output:
            process = subprocess.Popen([os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", str(launcher)],
                                       cwd=package, env=env, stdout=output, stderr=subprocess.STDOUT)
            while time.monotonic() - begun < 150:
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
                if visible and routed and process.poll() == 0 and time.monotonic() - begun >= 5:
                    path, text = routed[-1]
                    if any(token in text for token in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script")):
                        raise RuntimeError("Actual launcher route produced script errors")
                    report.update(observed_process=visible[0], launcher_exit_code=0,
                                  route_log=path.relative_to(evidence).as_posix(), route_log_sha256=digest(path),
                                  accepted_route_marker="SHARED_WORKBENCH_LAUNCH_READY", checks=5)
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
            error = error or caught
        report["elapsed_seconds"] = round(time.monotonic() - begun, 3)
        report["passed"] = error is None
        if error: report["failures"].append(str(error))
        (evidence / "launcher.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if error: raise error
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--source", required=True)
    args = parser.parse_args()
    result = run(args.package, args.evidence, args.source)
    print("WINDOWS_EVALUATOR_LAUNCHER_RESULT " + json.dumps({"checks": result["checks"], "failures": [], "passed": True}))


if __name__ == "__main__": main()
