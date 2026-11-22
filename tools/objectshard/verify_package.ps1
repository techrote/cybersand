param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference = "Stop"
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
    'godot/tests/test_object_shard_package_boot.gd')
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
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.Value) { throw "Package file changed: $relative" }
    $count += 1
}
if ($manifest.native.path -ne $nativeRelative -or $manifest.rapier.path -ne $rapierRelative) { throw 'Unexpected native runtime paths' }
$native = Join-Path $root $manifest.native.path
if ((Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.native.sha256) { throw 'Native identity mismatch' }
$rapier = Join-Path $root $manifest.rapier.path
if ((Get-FileHash -LiteralPath $rapier -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.rapier.sha256) { throw 'Rapier identity mismatch' }
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
