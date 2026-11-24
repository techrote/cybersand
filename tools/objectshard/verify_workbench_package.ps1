param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference = 'Stop'

function Get-PackageSha256([string]$LiteralPath) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [IO.File]::OpenRead($LiteralPath)
        return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $algorithm.Dispose()
    }
}

$root = [IO.Path]::GetFullPath($Package)
$manifest = Get-Content -LiteralPath (Join-Path $root 'objectshard-workbench-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'objectshard-m4-workbench-package-v1') { throw 'Unsupported Workbench manifest' }
if ($manifest.source_commit -notmatch '^[0-9a-f]{40}$' -or $manifest.source_tree -notmatch '^[0-9a-f]{40}$') { throw 'Missing exact source identity' }
if ($manifest.entry.scene -ne 'godot/main.tscn' -or $manifest.entry.host -ne 'ordinary-workbench' -or
    $manifest.entry.launcher -ne 'Open Workbench.cmd' -or $manifest.entry.opt_in -isnot [bool] -or -not $manifest.entry.opt_in -or
    ($manifest.entry.scenario_ids -join ',') -ne 'tower,viaduct,timber,mixed,stress' -or
    $manifest.ordinary_production_defaults_changed -isnot [bool] -or $manifest.ordinary_production_defaults_changed) {
    throw 'Incomplete ordinary Workbench entry contract'
}
$nativeRelative = 'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'
$rapierRelative = 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
$required = @($nativeRelative, $rapierRelative, 'Godot_v4.7-stable_win64.exe', 'Godot_v4.7-stable_win64_console.exe',
    'Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'vcruntime140.dll',
    'Microsoft-Visual-C-Runtime-LICENSE.docx', 'Microsoft-Visual-Studio-2022-LICENSE.docx',
    'source-built-candidate-provenance.json', 'godot/project.godot', 'godot/main.tscn',
    'godot/scripts/main.gd', 'godot/scripts/shared_workbench.gd', 'godot/scripts/simulation_worker.gd',
    'godot/scripts/object_shard_m4_runtime.gd', 'godot/scripts/object_shard_workbench_scenes.gd',
    'godot/scripts/object_shard_physics_bridge.gd', 'godot/tests/test_object_shard_m4_workbench_completion.gd',
    'godot/tests/test_object_shard_m4_material_only_workbench.gd',
    'godot/tests/probe_object_shard_workbench_package.gd', 'godot/tests/profile_object_shard_m4_workbench.gd',
    'godot/addons/godot-rapier2d/runtime-provenance.windows.json', 'READ-ME.md',
    'Open Workbench.cmd', 'Verify Workbench.cmd', 'tools/objectshard/verify_workbench_package.ps1')
foreach ($relative in $required) {
    if ($null -eq $manifest.files_sha256.PSObject.Properties[$relative]) { throw "Missing inventory: $relative" }
}
$count = 0
foreach ($entry in $manifest.files_sha256.PSObject.Properties) {
    $relative = $entry.Name
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[/\\])\.\.([/\\]|$)' -or $relative.Contains(':')) { throw "Unsafe package path: $relative" }
    if ($entry.Value -notmatch '^[0-9a-f]{64}$') { throw "Malformed digest: $relative" }
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package file: $relative" }
    if ((Get-PackageSha256 $path) -ne $entry.Value) { throw "Package file changed: $relative" }
    $count += 1
}
if ($manifest.native.path -ne $nativeRelative -or $manifest.rapier.path -ne $rapierRelative) { throw 'Unexpected runtime paths' }
if ((Get-PackageSha256 (Join-Path $root $nativeRelative)) -ne $manifest.native.sha256) { throw 'Native identity mismatch' }
if ($manifest.rapier.sha256 -ne 'b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7' -or
    (Get-PackageSha256 (Join-Path $root $rapierRelative)) -ne $manifest.rapier.sha256) { throw 'Rapier identity mismatch' }
if ($manifest.godot.version -ne '4.7.stable.official.5b4e0cb0f' -or
    $manifest.godot.runtime_sha256 -ne $manifest.files_sha256.'Godot_v4.7-stable_win64.exe' -or
    $manifest.godot.console_sha256 -ne $manifest.files_sha256.'Godot_v4.7-stable_win64_console.exe') { throw 'Engine identity mismatch' }
if ($manifest.vc_runtime_sha256 -ne $manifest.files_sha256.'vcruntime140.dll') { throw 'VC runtime identity mismatch' }
$candidate = Get-Content -LiteralPath (Join-Path $root 'source-built-candidate-provenance.json') -Raw | ConvertFrom-Json
if ($candidate.source_commit -ne $manifest.source_commit -or $candidate.source_tree -ne $manifest.source_tree -or
    $candidate.sha256 -ne $manifest.native.sha256) { throw 'Candidate source identity mismatch' }
$sourceCount = 0
foreach ($entry in $manifest.native.source_inputs.PSObject.Properties) {
    $relative = $entry.Name
    if ($null -eq $manifest.files_sha256.PSObject.Properties[$relative] -or
        $candidate.source_inputs.PSObject.Properties[$relative].Value -ne $entry.Value) { throw "Native build ledger mismatch: $relative" }
    $text = [IO.File]::ReadAllText((Join-Path $root $relative)).Replace("`r`n", "`n")
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        $actual = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace('-', '').ToLowerInvariant()
    } finally { $hash.Dispose() }
    if ($actual -ne $entry.Value) { throw "Native source differs from built candidate: $relative" }
    $sourceCount += 1
}
if ($sourceCount -eq 0 -or @($candidate.source_inputs.PSObject.Properties).Count -ne $sourceCount) { throw 'Incomplete native source ledger' }
Write-Host "Workbench package PASS: $count files; source $($manifest.source_commit)"
Write-Host 'Physical Windows/NVIDIA acceptance is separate from this exact-byte verification.'
