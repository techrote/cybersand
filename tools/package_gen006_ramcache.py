#!/usr/bin/env python3
"""Build the stacked, source-matched Windows RAM-cache owner evaluator."""
from __future__ import annotations

import argparse
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent/"ci"))
import gen006_ramcache_runtime_publication as publication

_spec = spec_from_file_location("_ramcache_donor_package", Path(__file__).with_name("package_gen006_persistent_areas.py"))
donor = module_from_spec(_spec)
_spec.loader.exec_module(donor)
donor.publication = publication
donor.engine = publication.engine
donor.ROOT = publication.engine.ROOT
engine, require, sha = publication.engine, publication.require, publication.sha


def _legacy_cold_smoke(source: str) -> str:
    """Preserve the inherited private-candidate smoke contract in this package."""
    anchor = "'--persistent-start-paused','--persistent-require-graphics')"
    require(source.count(anchor) == 1 and source.count("res://tests/test_persistent_areas_workbench.gd") == 1
        and "--persistent-cache-off" not in source, "Inherited Workbench smoke argument boundary changed")
    return source.replace(anchor,
        "'--persistent-start-paused','--persistent-require-graphics','--persistent-cache-off')", 1)


# This is the successor's private donor module, not the donor package source.
# The dedicated RAM smoke below independently qualifies real cache behavior.
donor.SMOKE = _legacy_cold_smoke(donor.SMOKE)

# Direct-launch the GUI executable: the console wrapper otherwise hides its
# real engine child PID. Preserve both original output streams and actual
# process measurements; never infer a fresh process merely from two receipts.
RAM_SMOKE = r'''$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fffffff')
$output = Join-Path $base "smoke\$stamp"
New-Item -ItemType Directory -Path $output -Force | Out-Null
$env:APPDATA = Join-Path $output 'userdata'
$env:LOCALAPPDATA = Join-Path $output 'localdata'
$env:XDG_DATA_HOME = $env:APPDATA
$engine = Join-Path $base 'Godot_v4.7-stable_win64.exe'
$project = Join-Path $base 'godot'
$native = Join-Path $project 'addons\cybersand_native\bin\cybersand_native.windows.x86_64.dll'
$manifestPath = Join-Path $base 'evaluation-manifest.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$env:CYBERSAND_SOURCE_REVISION = $manifest.source_commit
$script:processRows = New-Object 'System.Collections.Generic.List[object]'
function Get-PayloadIdentity {
    return [ordered]@{
        engine_sha256 = (Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant()
        native_sha256 = (Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToLowerInvariant()
        manifest_sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
function Quote-NativeArgument {
    param([string]$Value)
    # Generated tokens cannot contain quotes/newlines; spaces and terminal
    # backslashes still need correct Win32 argument quoting.
    if ($Value -match '["\r\n\x00]') { throw 'Unexpected character in generated smoke argument.' }
    return '"' + [regex]::Replace($Value, '(\\+)$', '$1$1') + '"'
}
function Invoke-LoggedGodot {
    param([string[]]$GodotArguments, [string]$LogPath, [string]$Mode)
    $before = Get-PayloadIdentity
    if (($before | ConvertTo-Json -Compress) -ne ($script:payloadAnchor | ConvertTo-Json -Compress)) {
        throw 'The payload changed between actual smoke processes.'
    }
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $engine
    $info.Arguments = [string]::Join(' ', @($GodotArguments | ForEach-Object { Quote-NativeArgument $_ }))
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.CreateNoWindow = $true
    $child = New-Object System.Diagnostics.Process
    $child.StartInfo = $info
    $clock = [Diagnostics.Stopwatch]::StartNew()
    if (!$child.Start()) { throw "Could not launch actual Godot $Mode process." }
    $actualPid = $child.Id
    $outTask = $child.StandardOutput.ReadToEndAsync()
    $errTask = $child.StandardError.ReadToEndAsync()
    $timedOut = $false
    $peak = [long]0
    try {
        while (!$child.WaitForExit(50)) {
            $child.Refresh()
            try { $peak = [Math]::Max($peak, $child.WorkingSet64) } catch { }
            if ($clock.Elapsed.TotalSeconds -gt 900) {
                $timedOut = $true
                $child.Kill()
                if (!$child.WaitForExit(10000)) { throw 'Timed-out engine did not terminate.' }
                break
            }
        }
        $child.WaitForExit()
        $nativeExitCode = $child.ExitCode
        try { $peak = [Math]::Max($peak, $child.PeakWorkingSet64) } catch { }
        $cpu = $child.TotalProcessorTime.TotalSeconds
        $stdout = $outTask.GetAwaiter().GetResult()
        $stderr = $errTask.GetAwaiter().GetResult()
    } finally {
        $clock.Stop()
        if (!$child.HasExited) { $child.Kill(); $child.WaitForExit() }
        $child.Dispose()
    }
    [IO.File]::WriteAllText($LogPath + '.stdout', $stdout)
    [IO.File]::WriteAllText($LogPath + '.stderr', $stderr)
    [IO.File]::WriteAllText($LogPath, $stdout + "`n" + $stderr)
    $after = Get-PayloadIdentity
    $script:processRows.Add([ordered]@{
        mode = $Mode; pid = $actualPid; executable = $engine; arguments = $GodotArguments
        exit_code = $nativeExitCode; timed_out = $timedOut; elapsed_ms = $clock.Elapsed.TotalMilliseconds
        peak_working_set_bytes = $peak; cpu_seconds = $cpu; before = $before; after = $after
        memory_scope = 'Observed whole-engine working set; includes rendering and host allocations'
    })
    @($script:processRows.ToArray()) | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath (Join-Path $output 'packaged-processes.json') -Encoding UTF8
    Write-Host $stdout
    if ($stderr) { Write-Host $stderr }
    if ($timedOut -or $nativeExitCode -ne 0) { throw "Actual $Mode process failed (exit $nativeExitCode; timeout $timedOut)." }
    if (($before | ConvertTo-Json -Compress) -ne ($after | ConvertTo-Json -Compress)) { throw 'Executed payload changed during smoke.' }
    if (($stdout + "`n" + $stderr) -match 'SCRIPT ERROR:|(?m)^ERROR:') { throw "Actual $Mode process reported an error." }
    return [int]$actualPid
}
$script:payloadAnchor = Get-PayloadIdentity
if ($manifest.source_commit -notmatch '^[0-9a-f]{40}$' -or
    $script:payloadAnchor.engine_sha256 -ne $manifest.files_sha256.'Godot_v4.7-stable_win64.exe' -or
    $script:payloadAnchor.native_sha256 -ne $manifest.native_sha256 -or
    $script:payloadAnchor.native_sha256 -ne $manifest.files_sha256.'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll') {
    throw 'The actual engine/native payload does not match its source-bound evaluation manifest.'
}
[void](Invoke-LoggedGodot -GodotArguments @('--headless','--path',$project,'--editor','--import','--quit') `
    -LogPath (Join-Path $output 'import.log') -Mode 'import')
$observedPids = @{}
foreach ($mode in @('write', 'reopen')) {
    $arguments = @('--path',$project,'--rendering-method','gl_compatibility','--rendering-driver','opengl3',
        '--audio-driver','Dummy','--script','res://tests/test_persistent_area_ramcache.gd','--',
        "--persistent-profile=$output\profile","--persistent-evidence=$output",
        "--persistent-test-mode=$mode",'--persistent-test-workers=1',
        '--persistent-start-paused','--persistent-require-graphics','--ramcache-hot-samples=3','--ramcache-warm-samples=3')
    $actualPid = Invoke-LoggedGodot -GodotArguments $arguments -LogPath (Join-Path $output "$mode.log") -Mode $mode
    $observedPids[$mode] = $actualPid
    $receipt = Get-Content -Raw (Join-Path $output "workbench-$mode.json") | ConvertFrom-Json
    $cache = Get-Content -Raw (Join-Path $output "ramcache-$mode.json") | ConvertFrom-Json
    if ($receipt.failures.Count -ne 0 -or !$receipt.graphical -or $receipt.mode -ne $mode -or
        $receipt.process_id -ne $actualPid -or
        ($receipt.assertions -isnot [int] -and $receipt.assertions -isnot [long]) -or $receipt.assertions -le 0 -or
        $cache.schema -ne 'gen006-ramcache-workbench-v1' -or $cache.failures.Count -ne 0 -or !$cache.graphical -or
        $cache.mode -ne $mode -or $cache.process_id -ne $actualPid -or
        ($cache.checks -isnot [int] -and $cache.checks -isnot [long]) -or $cache.checks -le 0) {
        throw "Incomplete or wrong-process graphical $mode receipt."
    }
    $markers = @(Get-Content -LiteralPath (Join-Path $output "$mode.log") | Where-Object { $_.StartsWith('GEN006_RAMCACHE ') })
    if ($markers.Count -ne 1) { throw "Missing or ambiguous actual $mode completion marker." }
    $done = $markers[0].Substring('GEN006_RAMCACHE '.Length) | ConvertFrom-Json
    if ($done.pid -ne $actualPid -or $done.mode -ne $mode -or !$done.graphical -or
        $done.failures.Count -ne 0 -or $done.checks -ne ($cache.checks + 1) -or
        $done.hot_samples -ne $cache.hot_samples.Count -or $done.warm_samples -ne $cache.warm_samples.Count) {
        throw "Original $mode completion contradicts the native receipt."
    }
    if ($mode -eq 'write' -and ($cache.hot_samples.Count -ne 3 -or $cache.warm_samples.Count -ne 3 -or
        $cache.evidence.cache_io.prefetch_hits -lt 1 -or $cache.evidence.cache_io.background_publications -lt 1)) {
        throw 'Incomplete actual RAM-cache, background publication or prefetched-arrival evidence.'
    }
}
if ($observedPids.write -eq $observedPids.reopen) { throw 'Reopening did not use an independently observed new process.' }
[ordered]@{
    schema = 'gen006-ramcache-packaged-smoke-v1'; source_commit = $manifest.source_commit
    payload = Get-PayloadIdentity; processes = @($script:processRows.ToArray()); status = 'passed'
    observations = @('ramcache-write.json','ramcache-reopen.json','workbench-write.json','workbench-reopen.json')
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $output 'packaged-report.json') -Encoding UTF8
Write-Output "GEN006_RAMCACHE_PACKAGED_GRAPHICAL_SMOKE_PASS $output"
'''


def verify_package(folder: Path) -> dict:
    manifest = donor.verify_package(folder)
    require(manifest.get("ramcache_schema") == "gen006-ramcache-owner-evaluation-v1"
        and manifest.get("donor_commit") == "d0d043f4740ffed5f0dbb4120e437458d7a9bd57",
        "Missing stacked RAM-cache evaluator identity")
    for name in ("Run RAM Cache Smoke.ps1", "Run RAM Cache Smoke.cmd", "RAM-CACHE-OWNER-GUIDE.md",
        "godot/scripts/persistent_area_cache.gd", "godot/scripts/persistent_area_writeback.gd",
        "godot/scripts/persistent_area_connectivity.gd", "godot/scripts/persistent_area_worker_protocol.gd",
        "godot/tests/test_persistent_area_ramcache.gd"):
        require(name in manifest["files_sha256"], "RAM-cache evaluator is incomplete: "+name)
    qualification = json.loads((folder/"qualification/qualification.json").read_text(encoding="utf-8"))
    provenance = json.loads((folder/engine.MANIFESTS["windows"]).read_text(encoding="utf-8"))
    require(manifest.get("qualification_sha256") == sha(folder/"qualification/qualification.json")
        and manifest.get("runtime_provenance_sha256") == sha(folder/engine.MANIFESTS["windows"])
        and all(qualification.get(key) == manifest.get(key) for key in ("source_commit", "source_tree", "native_sha256"))
        and provenance.get("source_commit") == manifest.get("source_commit")
        and provenance.get("source_tree") == manifest.get("source_tree")
        and provenance.get("sha256") == manifest.get("native_sha256")
        and provenance.get("source_inputs") and all(qualification.get("source_inputs_sha256", {}).get(path) == digest
            for path, digest in provenance["source_inputs"].items())
        and qualification.get("engine_sha256") == donor.DEPENDENCIES["Godot_v4.7-stable_win64.exe"]
        and qualification.get("rapier_sha256") == engine.RAPIER["windows"][1]
        and qualification.get("status") == "passed" and qualification.get("completed") is True
        and qualification.get("platform") == "windows" and qualification.get("graphical") is True
        and qualification.get("input_custody") == "passed" and qualification.get("local_delta") == []
        and qualification.get("missing_source_inputs") == [], "Portable qualification/source/runtime identity differs")
    executed_inputs = qualification.get("source_inputs_sha256", {})
    source_inputs = provenance.get("source_inputs", {}) | provenance.get("build_inputs", {})
    for relative, digest in provenance.get("source_inputs", {}).items():
        if relative in manifest["files_sha256"]:
            require(manifest["files_sha256"][relative] == digest,
                "Packaged native review source differs from the actual built runtime: "+relative)
    for relative, digest in source_inputs.items():
        if relative.startswith("godot/") and Path(relative).suffix in (".gd", ".tscn", ".tres", ".gdshader", ".godot", ".gdextension"):
            require(executed_inputs.get(relative) == digest and manifest["files_sha256"].get(relative) == digest,
                "Packaged Godot source or execution configuration differs from its qualified build: "+relative)
    for relative, digest in executed_inputs.items():
        if relative.startswith("godot/") and Path(relative).suffix in (".gd", ".tscn", ".tres", ".gdshader", ".godot", ".gdextension"):
            require(source_inputs.get(relative) == digest and manifest["files_sha256"].get(relative) == digest,
                "Packaged Godot input is absent or changed in the source-bound provenance: "+relative)
    publication.verify_ramcache_evidence(folder/"qualification", qualification)
    return manifest


def build(args: argparse.Namespace) -> None:
    archive = args.archive
    args.archive = None
    donor.build(args)
    folder = args.output.resolve()
    source = engine.git("rev-parse", "HEAD").decode().strip()
    (folder/"Run RAM Cache Smoke.ps1").write_text(RAM_SMOKE, encoding="utf-8", newline="\r\n")
    (folder/"Run RAM Cache Smoke.cmd").write_text(
        '@echo off\npowershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run RAM Cache Smoke.ps1"\nexit /b %errorlevel%\n',
        encoding="utf-8", newline="\r\n")
    guide = (engine.ROOT/"docs/operations/persistent-area-ramcache-evaluation.md").read_text(encoding="utf-8")
    (folder/"RAM-CACHE-OWNER-GUIDE.md").write_text(guide, encoding="utf-8")
    (folder/"PERSISTENT-AREAS-BASELINE-GUIDE.md").write_bytes((folder/"READ-ME.md").read_bytes())
    (folder/"READ-ME.md").write_text(
        f"# CyberSand — native RAM residency and persistent areas\n\n"
        f"**Draft/HOLD.** Exact implementation source `{source}`.\n\n"
        "Extract the whole ZIP into a writable folder. Double-click **Open Persistent Areas.cmd**. "
        "Open the cache controls to configure memory, durability and destination preparation. "
        "The experimental profile starts with strict durability; read and acknowledge deferred mode before enabling it.\n\n"
        "Follow **RAM-CACHE-OWNER-GUIDE.md** for hot returns, state retention, memory pressure, background Save, "
        "prefetch and reversal. **Run RAM Cache Smoke.cmd** executes the real graphical scenario and a new-process restore "
        "in an isolated smoke profile. **Run Automated Smoke.cmd** checks the cache-disabled persistence path. "
        "**Open Workbench.cmd** launches ordinary Workbench.\n\n"
        "**Save all areas** must acknowledge before closing. In deferred mode, resident changes are not durable until "
        "publication acknowledges; a process crash may lose newer RAM-only work. **Capture Failure Evidence.cmd** "
        "collects local logs, saves and Windows/graphics identities.\n\n"
        "The manifest and qualification directory bind source, actual DLL, pinned Godot and original platform evidence. "
        "The measured cache admission budget is distinct from process RSS and temporary preparation headroom. "
        "Physical Windows 11/NVIDIA acceptance remains an owner task.\n", encoding="utf-8")
    manifest = json.loads((folder/"evaluation-manifest.json").read_text(encoding="utf-8"))
    manifest.update(ramcache_schema="gen006-ramcache-owner-evaluation-v1",
        donor_commit="d0d043f4740ffed5f0dbb4120e437458d7a9bd57", files_sha256=donor.payload_files(folder))
    engine.write_json(folder/"evaluation-manifest.json", manifest)
    verify_package(folder)
    if archive:
        require(not archive.exists(), "Refusing to overwrite an owner ZIP")
        archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
            for path in sorted(folder.rglob("*")):
                if path.is_file(): output.write(path, path.relative_to(folder).as_posix())
        archive.with_suffix(archive.suffix+".sha256").write_text(sha(archive)+"  "+archive.name+"\n", encoding="utf-8")


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
    else: print(json.dumps({"verified": str(args.package), "source_commit": verify_package(args.package)["source_commit"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
