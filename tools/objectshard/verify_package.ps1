param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference = "Stop"

# Windows PowerShell can inherit a PowerShell 7 module path from CI or a
# developer shell. Do not depend on Get-FileHash module autoloading: the same
# streaming .NET SHA-256 primitive also works in the Windows 11 inbox runtime.
function Get-PackageSha256([string]$LiteralPath) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [IO.File]::OpenRead($LiteralPath)
        $digest = $algorithm.ComputeHash($stream)
        return [BitConverter]::ToString($digest).Replace('-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $algorithm.Dispose()
    }
}

$root = [IO.Path]::GetFullPath($Package)
$manifest = Get-Content -LiteralPath (Join-Path $root 'objectshard-lab-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'objectshard-lab-package-v1') { throw 'Unsupported ObjectShard package manifest' }
if ($manifest.source_commit -notmatch '^[0-9a-f]{40}$' -or $manifest.source_tree -notmatch '^[0-9a-f]{40}$') { throw 'Missing exact source identity' }
$nativeRelative = 'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'
$rapierRelative = 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
$required = @($nativeRelative, $rapierRelative, 'Godot_v4.7-stable_win64.exe', 'Godot_v4.7-stable_win64_console.exe',
    'Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'vcruntime140.dll',
    'Microsoft-Visual-C-Runtime-LICENSE.docx', 'Microsoft-Visual-Studio-2022-LICENSE.docx',
    'source-built-candidate-provenance.json', 'godot/project.godot', 'godot/object_shard_lab.tscn',
    'godot/scripts/object_shard_lab.gd', 'godot/scripts/object_shard_lab_session.gd',
    'godot/scripts/object_shard_lab_view.gd', 'godot/scripts/object_shard_physics_bridge.gd',
    'godot/addons/godot-rapier2d/runtime-provenance.windows.json', 'READ-ME.md',
    'Open ObjectShard Lab.cmd', 'Verify ObjectShard Lab.cmd', 'tools/objectshard/verify_package.ps1',
    'godot/tests/probe_object_shard_package_boot.gd')
$preflightScene = 'godot/object_shard_worker_rehearsal.tscn'
if ($null -ne $manifest.preflight -or $null -ne $manifest.files_sha256.PSObject.Properties[$preflightScene]) {
    if ($manifest.preflight.schema -ne 'objectshard-m3-preflight-v1' -or
        $manifest.preflight.host -ne 'standalone-exclusive-worker-rehearsal' -or
        $manifest.preflight.scene -ne $preflightScene -or
        $manifest.preflight.launcher -ne 'Open ObjectShard M3 Preflight.cmd' -or
        $manifest.preflight.replay_driver -ne 'godot/tests/replay_object_shard_worker_trace.gd' -or
        $manifest.preflight.production_workbench -isnot [bool] -or $manifest.preflight.production_workbench) {
        throw 'Incomplete or misleading M3 preflight identity'
    }
    $required += @($preflightScene, 'Open ObjectShard M3 Preflight.cmd',
        'godot/tests/replay_object_shard_worker_trace.gd',
        'godot/scripts/feature_launcher.gd', 'godot/scripts/object_shard_native_worker.gd', 'godot/scripts/object_shard_worker_host.gd',
        'godot/scripts/object_shard_worker_rehearsal.gd', 'godot/tests/probe_object_shard_worker_package_boot.gd',
        'docs/operations/objectshard-m3-preflight-playtest.md')
}
foreach ($relative in $required) {
    if ($null -eq $manifest.files_sha256.PSObject.Properties[$relative]) { throw "Incomplete package inventory: $relative" }
}
$count = 0
foreach ($entry in $manifest.files_sha256.PSObject.Properties) {
    $relative = $entry.Name
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[/\\])\.\.([/\\]|$)' -or $relative.Contains(':')) { throw "Unsafe package path: $relative" }
    if ($entry.Value -notmatch '^[0-9a-f]{64}$') { throw "Malformed digest: $relative" }
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package file: $relative" }
    $actual = (Get-PackageSha256 -LiteralPath $path)
    if ($actual -ne $entry.Value) { throw "Package file changed: $relative" }
    $count += 1
}
if ($manifest.native.path -ne $nativeRelative -or $manifest.rapier.path -ne $rapierRelative) { throw 'Unexpected native runtime paths' }
$native = Join-Path $root $manifest.native.path
if ((Get-PackageSha256 -LiteralPath $native) -ne $manifest.native.sha256) { throw 'Native identity mismatch' }
$rapier = Join-Path $root $manifest.rapier.path
if ((Get-PackageSha256 -LiteralPath $rapier) -ne $manifest.rapier.sha256) { throw 'Rapier identity mismatch' }
if ($manifest.godot.version -ne '4.7.stable.official.5b4e0cb0f' -or
    $manifest.godot.runtime_sha256 -ne $manifest.files_sha256.'Godot_v4.7-stable_win64.exe' -or
    $manifest.godot.console_sha256 -ne $manifest.files_sha256.'Godot_v4.7-stable_win64_console.exe') { throw 'Windows engine identity mismatch' }
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
        $bytes = $hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))
        $actual = [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
    } finally { $hash.Dispose() }
    if ($actual -ne $entry.Value) { throw "Native source differs from built candidate: $relative" }
    $sourceCount += 1
}
if ($sourceCount -eq 0 -or @($candidate.source_inputs.PSObject.Properties).Count -ne $sourceCount) { throw 'Incomplete native source ledger' }
Write-Host "ObjectShard Lab package PASS: $count files; source $($manifest.source_commit)"
Write-Host 'Automated file verification is separate from owner physical acceptance.'
