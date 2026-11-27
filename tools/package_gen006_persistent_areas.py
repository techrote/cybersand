#!/usr/bin/env python3
"""Package a graphically qualified, source-matched Windows GEN-006 evaluator."""
from __future__ import annotations

import argparse
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent / "ci"))
import gen006_persistent_runtime_publication as publication
import reciprocal_windows_package as reciprocal
from package_explore001_candidate import verify_vc_runtime, stage_generator_profiles
from package_wave_flow_candidate import omit_regenerated_imports

engine = publication.engine
ROOT = engine.ROOT
require, sha = engine.require, engine.runner.sha256
DEPENDENCIES = {
    "Godot_v4.7-stable_win64.exe": "b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8",
    "Godot_v4.7-stable_win64_console.exe": "d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c",
    "Godot-LICENSE.txt": "b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
    "Godot-COPYRIGHT.txt": "cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d",
    "Microsoft-Visual-C-Runtime-LICENSE.docx": "f1e3d56ceb2ad68aae0711b910375009e651ac5530fa0760f0dea6e81e54fae1",
    "Microsoft-Visual-Studio-2022-LICENSE.docx": "9c0cd52b20db9d081854c75bd1b50c75514b8f8cb09c8cad15e89d90b97b5bf3",
}


def payload_files(folder: Path) -> dict:
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob("*"))
            if p.is_file() and p != folder / "evaluation-manifest.json"}


def verify_package(folder: Path) -> dict:
    manifest = json.loads((folder / "evaluation-manifest.json").read_text(encoding="utf-8"))
    require(manifest.get("schema") == "gen006-persistent-areas-owner-evaluation-v1"
            and manifest.get("disposition") == "Draft/HOLD", "Wrong owner evaluator manifest")
    publication.verify_files(folder, manifest.get("files_sha256"))
    files = manifest["files_sha256"]
    built = json.loads((folder / engine.MANIFESTS["windows"]).read_bytes())["build_inputs"]
    binding = built.get(reciprocal.WINDOWS_BINDING)
    if "godot/tests/swarm456_reciprocal_ui.gd" in built:
        require(binding is not None, "Qualified reciprocal source has no Windows generator binding")
    reciprocal.verify_bound_package(folder, binding)
    require(all(files.get(name) == digest for name, digest in DEPENDENCIES.items()),
            "Evaluator dependency pins differ")
    native_path = engine.RUNTIMES["windows"]
    require(files.get(native_path) == manifest.get("native_sha256")
            and files.get(engine.RAPIER["windows"][0]) == engine.RAPIER["windows"][1],
            "Evaluator native or Rapier identity differs")
    for required in ("Open Persistent Areas.cmd", "Open Workbench.cmd", "Run Automated Smoke.ps1",
                     "Capture Failure Evidence.ps1", "godot/persistent_areas.tscn",
                     "godot/scripts/persistent_area_fixtures.gd", "qualification/qualification.json"):
        require(required in files, "Evaluator is incomplete: " + required)
    return manifest


def launcher(source: str, persistent: bool) -> str:
    destination = ('--persistent-areas --persistent-profile="%~dp0userdata\\persistent-profile"'
                   if persistent else "--workbench")
    return (
        '@echo off\nsetlocal\ncd /d "%~dp0"\n'
        'set "APPDATA=%~dp0userdata\\roaming"\nset "LOCALAPPDATA=%~dp0userdata\\local"\n'
        'set "XDG_DATA_HOME=%~dp0userdata\\roaming"\n'
        f'set "CYBERSAND_SOURCE_REVISION={source}"\n'
        'if not exist "%~dp0userdata" mkdir "%~dp0userdata"\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --headless --path "%~dp0godot" --editor --import --quit\n'
        'if errorlevel 1 (\n  if not defined CI if not "%~1"=="--headless" pause\n  exit /b 1\n)\n'
        '"%~dp0Godot_v4.7-stable_win64_console.exe" --path "%~dp0godot" '
        '--rendering-method gl_compatibility --rendering-driver opengl3 %* -- ' + destination + '\n'
        'set "evaluation_exit=%errorlevel%"\n'
        'if not "%evaluation_exit%"=="0" if not defined CI if not "%~1"=="--headless" pause\n'
        'exit /b %evaluation_exit%\n')


SMOKE = r'''$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fffffff')
$output = Join-Path $base "smoke\$stamp"
New-Item -ItemType Directory -Path $output -Force | Out-Null
$env:APPDATA = Join-Path $output 'userdata'
$env:LOCALAPPDATA = Join-Path $output 'localdata'
$env:XDG_DATA_HOME = $env:APPDATA
$engine = Join-Path $base 'Godot_v4.7-stable_win64_console.exe'
$project = Join-Path $base 'godot'
function Invoke-LoggedGodot {
    param([string[]]$GodotArguments, [string]$LogPath, [string]$Label)
    $previousPreference = $ErrorActionPreference
    $nativeExitCode = $null
    try {
        # Windows PowerShell 5 wraps native stderr (including warnings) in
        # ErrorRecords. Preserve their text without treating the stream itself
        # as failure; exit status, error markers and receipts remain mandatory.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = $null
        & $engine @GodotArguments 2>&1 |
            ForEach-Object { $_.ToString() } -ErrorAction Stop |
            Tee-Object -FilePath $LogPath -ErrorAction Stop
        $nativeExitCode = $global:LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($null -eq $nativeExitCode -or $nativeExitCode -ne 0) { throw "$Label process failed (exit $nativeExitCode)." }
    if ((Get-Content -Raw -LiteralPath $LogPath) -match 'SCRIPT ERROR:|(?m)^ERROR:') { throw "$Label reported an error." }
}
Invoke-LoggedGodot -GodotArguments @('--headless','--path',$project,'--editor','--import','--quit') `
    -LogPath (Join-Path $output 'import.log') -Label 'Godot import'
foreach ($mode in @('write', 'reopen')) {
    $godotArguments = @('--path',$project,'--rendering-method','gl_compatibility','--rendering-driver','opengl3',
        '--audio-driver','Dummy','--script','res://tests/test_persistent_areas_workbench.gd','--',
        "--persistent-profile=$output\profile","--persistent-evidence=$output",
        "--persistent-test-mode=$mode",'--persistent-test-workers=1',
        '--persistent-start-paused','--persistent-require-graphics')
    Invoke-LoggedGodot -GodotArguments $godotArguments -LogPath (Join-Path $output "$mode.log") `
        -Label "Native graphical $mode"
    $receipt = Get-Content -Raw (Join-Path $output "workbench-$mode.json") | ConvertFrom-Json
    if ($receipt.failures.Count -ne 0 -or !$receipt.graphical -or
        ($receipt.assertions -isnot [int] -and $receipt.assertions -isnot [long]) -or
        $receipt.assertions -le 0) {
        throw "Incomplete graphical $mode receipt."
    }
}
$first = Get-Content -Raw (Join-Path $output 'workbench-write.json') | ConvertFrom-Json
$second = Get-Content -Raw (Join-Path $output 'workbench-reopen.json') | ConvertFrom-Json
if ($first.process_id -eq $second.process_id) { throw 'Reopening did not use a new process.' }
Write-Output "GEN006_PACKAGED_GRAPHICAL_SMOKE_PASS $output"
'''

FAILURE_CAPTURE = r'''$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fffffff')
$output = Join-Path $base "failure-evidence\$stamp"
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item (Join-Path $base 'evaluation-manifest.json') $output
foreach ($name in @('userdata','smoke')) {
    $path = Join-Path $base $name
    if (Test-Path $path) { Copy-Item $path (Join-Path $output $name) -Recurse }
}
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber |
    ConvertTo-Json | Set-Content (Join-Path $output 'windows.json')
Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,VideoProcessor |
    ConvertTo-Json | Set-Content (Join-Path $output 'display-adapter.json')
Get-FileHash (Join-Path $base 'godot\addons\cybersand_native\bin\cybersand_native.windows.x86_64.dll') -Algorithm SHA256 |
    ConvertTo-Json | Set-Content (Join-Path $output 'native-runtime.json')
Compress-Archive -Path "$output\*" -DestinationPath "$output.zip"
Write-Output "Captured failure evidence: $output.zip"
'''


def build(args: argparse.Namespace) -> None:
    source = engine.git("rev-parse", "HEAD").decode().strip()
    bundle = args.runtime_bundle.resolve(strict=True)
    runtime = engine.verify_bundle(bundle, "windows", source, validated=True)
    qualification = bundle / "qualification"
    qvalue = json.loads((qualification / "qualification.json").read_text(encoding="utf-8"))
    require(qvalue.get("platform") == "windows", "Windows evaluator needs actual Windows qualification")
    dependencies = args.dependencies.resolve(strict=True)
    for name, digest in DEPENDENCIES.items():
        require(sha(dependencies / name) == digest, "Pinned dependency mismatch: " + name)
    vc = verify_vc_runtime(dependencies)
    require(sha(ROOT / engine.RAPIER["windows"][0]) == engine.RAPIER["windows"][1], "Unpinned Windows Rapier")
    output = args.output.resolve()
    require(not output.exists(), "Evaluator output must be a new directory")
    output.mkdir(parents=True)
    paths = ["godot", "examples/worldgen", "native/include", "native/src", "native/tests/test_persistent_area_continuation.cpp",
             "third_party/godot-runtime.lock.json", "third_party/native-toolchain.lock.json",
             "third_party/rapier-bvh-build.lock.json", "third_party/patches/rapier-0.35.1-cooperative-bvh-join.patch",
             "THIRD_PARTY_NOTICES.md", "LICENSE_STATUS.md", engine.EVIDENCE]
    archive = subprocess.check_output(["git", "-c", "core.autocrlf=false", "-c", "core.eol=lf", "archive", source, "--", *paths],
        cwd=ROOT, env=dict(os.environ, GIT_LFS_SKIP_SMUDGE="1"), timeout=60)
    replacements = {
        **reciprocal.windows_cli_replacement(ROOT),
        engine.RUNTIMES["windows"]: bundle / Path(engine.RUNTIMES["windows"]).name,
        engine.MANIFESTS["windows"]: engine.manifest_path(bundle, "windows"),
        engine.RAPIER["windows"][0]: ROOT / engine.RAPIER["windows"][0],
    }
    with tarfile.open(fileobj=io.BytesIO(archive)) as contents:
        for entry in contents:
            if not entry.isfile() or entry.name.startswith("godot/.godot/"):
                continue
            if "/bin/" in entry.name and entry.name not in replacements:
                continue
            if entry.name == engine.MANIFESTS["linux"] or entry.name in reciprocal.FOREIGN_PATHS:
                continue
            publication.safe_relative(entry.name)
            data = replacements[entry.name].read_bytes() if entry.name in replacements else contents.extractfile(entry).read()
            require(not data.startswith(b"version https://git-lfs.github.com/spec/v1\n"),
                    "Required package asset is an LFS pointer: " + entry.name)
            destination = output / entry.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
    profiles = stage_generator_profiles(output)
    omitted = omit_regenerated_imports(output)
    for name in [*DEPENDENCIES, "vcruntime140.dll", "vc-runtime-provenance.json"]:
        shutil.copyfile(dependencies / name, output / name)
    for name, persistent in (("Open Persistent Areas.cmd", True), ("Open Workbench.cmd", False)):
        (output / name).write_text(launcher(source, persistent), encoding="utf-8", newline="\r\n")
    (output / "Run Automated Smoke.ps1").write_text(SMOKE, encoding="utf-8", newline="\r\n")
    (output / "Run Automated Smoke.cmd").write_text(
        '@echo off\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run Automated Smoke.ps1"\nexit /b %errorlevel%\n',
        encoding="utf-8", newline="\r\n")
    (output / "Capture Failure Evidence.ps1").write_text(FAILURE_CAPTURE, encoding="utf-8", newline="\r\n")
    (output / "Capture Failure Evidence.cmd").write_text(
        '@echo off\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture Failure Evidence.ps1"\npause\n',
        encoding="utf-8", newline="\r\n")
    evidence = output / "qualification"
    evidence.mkdir()
    for relative in ["qualification.json", *qvalue["files_sha256"]]:
        original = qualification / publication.safe_relative(relative)
        destination = evidence / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, destination)
    for name in ("native-build.json", "native-build.log", "validation.json"):
        shutil.copyfile(bundle / name, evidence / name)
    readme = f"""# CyberSand — three persistent areas

**Draft/HOLD owner evaluator.** Source `{source}`; tree `{runtime['source_tree']}`.
Native DLL SHA-256 `{runtime['sha256']}`. Godot `{engine.GODOT_VERSION}`.

## Start and travel

Extract the complete ZIP into a writable folder, then double-click **Open Persistent Areas.cmd**.
The first launch imports local resources and creates three independent native checkpoints.
The ordinary application is available separately through **Open Workbench.cmd**.

Use **A · Industrial fire**, **B · Waterworks**, and **C · Foundry gallery** to travel.
Only one 512 × 512 native canvas is active. The editor/camera is the traveller.
Use normal Workbench pause, paint, erase, Art and Flatten controls to author it.
Persistent areas save the evolved native World as well as its authored start; ordinary **Save start**
keeps its existing authoring meaning. **Save all areas** checkpoints the persistent profile.

## Owner acceptance sequence

1. In A, watch Wood, Oil and Coal burn with native Fire and Smoke. Pause and erase some timber or paint a firebreak.
2. Travel to B. Spend game time observing Water/Sand settling; erase the wooden gate and leave a material mark.
3. Travel to C. Alter the recognisable gallery and watch Sand falling through the chute.
4. Return to A and B. Check your destructive edits, material marks and progressed environment.
5. Choose 5, 30 or 120 seconds and press **Simulate Ahead**. Observe completed time and any remaining debt.
   **Cancel safely** retains completed durable work; **Pay catch-up debt** continues bounded work.
6. Click **Save all areas**, close CyberSand normally, reopen the same launcher and revisit all three areas.
   Repeat travel and deliberate progression; destroyed authored material must not reappear.

**Game**, **Area**, and **Debt** display total game time, the selected area's accounted-for native time,
and remaining catch-up. Shutdown time creates no game time. Each operation admits at most 600 native ticks,
with a 3-second stepping budget checked between slices (maximum 32 ticks / 100 ms per slice).
Capture, storage and native indivisible ticks can take longer; the qualification records their actual cost.
Skipped time is never silently credited. Repeated visits pay only remaining debt.

## Saves, cancellation and failures

This extracted copy owns its isolated `userdata/persistent-profile` and normal Workbench saves under `userdata`.
Keep the folder writable. Close the application before moving, backing up or sharing its profile.
Saves bind this exact native binary and domain version; another platform/build is visibly incompatible.
Keep the old evaluator and profile together when trying a newer build.

An interrupted operation retains the last published checkpoint. If loading reports corruption or incompatibility,
read **Details / limits** and use **Retry saved profile** or the explicit **Recover previous save** action only after
reading its status. Do not delete a refused profile or replace it with a seed to hide the error.
For a fresh independent experiment, extract another copy of the ZIP into a new folder.

## Supported scope

Native CYPS2 continuation includes the supported Current/FreeMass cellular state, activity, temperature,
clocks, events and solver quantities. The supplied scenes use real supported fire/reaction/settling behaviour.
Exact native stepping is admitted. Coarse clock skipping is refused because sleeping chunks can have future
reaction deadlines and state epochs; its reported time credit is zero.

This milestone supports material editing and an editor/camera traveller. Live Rapier actors, NPC/controller state,
host emitters/equipment, pending external effects, host scenario-event cursors, Wave and unsupported solver state
pin or refuse transition. There is no cross-area actor/fluid flux, arbitrary selective chunk eviction, universal
recipe reconciliation or claim that the broader GEN-006 programme is complete.

## Automated smoke and failure evidence

Double-click **Run Automated Smoke.cmd** for actual graphical write → exit → new-process reopen checks.
It uses a new `smoke` profile, preserves your interactive profile, and records JSON, logs and PNG captures.
The package's `qualification` folder retains the source-bound Windows campaign and native build provenance.
`evaluation-manifest.json` binds all original package files; local Godot caches and new saves are additional files.

If something fails, preserve the on-screen message and close the application if possible. Run
**Capture Failure Evidence.cmd** to collect the isolated saves, logs, package identity and Windows/display driver
information into a ZIP under `failure-evidence`. Add a screenshot and the exact sequence of controls used.
The script only creates local files; choose how to share them after reviewing their contents.

Automated GitHub-hosted Windows/Linux evidence does not establish physical Windows 11/NVIDIA owner acceptance.
This evaluator installs nothing globally, changes no production default, and performs no merge.
"""
    (output / "READ-ME.md").write_text(readme, encoding="utf-8")
    manifest = {"schema": "gen006-persistent-areas-owner-evaluation-v1", "disposition": "Draft/HOLD",
        "source_commit": source, "source_tree": runtime["source_tree"], "native_sha256": runtime["sha256"],
        "runtime_provenance_sha256": sha(engine.manifest_path(bundle, "windows")),
        "qualification_sha256": sha(qualification / "qualification.json"), "godot_version": engine.GODOT_VERSION,
        "vc_runtime_sha256": vc["files_sha256"]["vcruntime140.dll"],
        "generator_profiles_sha256": profiles, "regenerated_imports_sha256": omitted,
        "area_ids": ["a", "b", "c"], "owner_nvidia_acceptance": "pending",
        "files_sha256": payload_files(output)}
    engine.write_json(output / "evaluation-manifest.json", manifest)
    verify_package(output)
    engine.verify_bundle(bundle, "windows", source, validated=True)
    if args.archive:
        require(not args.archive.exists(), "Refusing to overwrite an evaluation ZIP")
        args.archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for path in sorted(output.rglob("*")):
                if path.is_file(): archive.write(path, path.relative_to(output).as_posix())
        args.archive.with_suffix(args.archive.suffix + ".sha256").write_text(
            sha(args.archive) + "  " + args.archive.name + "\n", encoding="utf-8")
    print(output / "Open Persistent Areas.cmd")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    make = commands.add_parser("build")
    make.add_argument("--runtime-bundle", required=True, type=Path)
    make.add_argument("--dependencies", required=True, type=Path)
    make.add_argument("--output", required=True, type=Path)
    make.add_argument("--archive", type=Path)
    verify = commands.add_parser("verify")
    verify.add_argument("package", type=Path)
    args = parser.parse_args()
    if args.command == "build": build(args)
    else: print(json.dumps({"verified":str(args.package), "source_commit":verify_package(args.package)["source_commit"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
