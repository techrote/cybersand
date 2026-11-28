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
if ($manifest.entry.scene -ne 'godot/main.tscn' -or $manifest.entry.startup_scene -ne 'godot/feature_launcher.tscn' -or
    $manifest.entry.host -ne 'ordinary-workbench' -or $manifest.entry.rendering_driver -ne 'opengl3_angle' -or
    $manifest.entry.launcher -ne 'Open Workbench.cmd' -or $manifest.entry.opt_in -isnot [bool] -or -not $manifest.entry.opt_in -or
    ($manifest.entry.scenario_ids -join ',') -ne 'tower,viaduct,timber,mixed,stress,perforated,weathered,editing_yard,owner_tower' -or
    $manifest.ordinary_production_defaults_changed -isnot [bool] -or $manifest.ordinary_production_defaults_changed) {
    throw 'Incomplete ordinary Workbench entry contract'
}
$nativeRelative = 'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'
$rapierRelative = 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
$generatorRelative = 'godot/tools/gentek_reciprocal.exe'
$bindingRelative = 'godot/tools/swarm004-runtime.windows.json'
$retainedReference = 'godot/addons/cybersand_native/retained-runtime-provenance.reference.json'
if (Test-Path -LiteralPath (Join-Path $root 'godot/addons/cybersand_native/runtime-provenance.json')) {
    throw 'Active retained runtime provenance is forbidden in an evaluator'
}
$required = @($nativeRelative, $rapierRelative, 'Godot_v4.7-stable_win64.exe', 'Godot_v4.7-stable_win64_console.exe',
    'Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'vcruntime140.dll',
    'Microsoft-Visual-C-Runtime-LICENSE.docx', 'Microsoft-Visual-Studio-2022-LICENSE.docx',
    'source-built-candidate-provenance.json', $retainedReference, 'godot/project.godot', 'godot/main.tscn',
    'godot/feature_launcher.tscn', 'godot/scripts/feature_launcher.gd',
    'godot/scripts/main.gd', 'godot/scripts/shared_workbench.gd', 'godot/scripts/simulation_worker.gd',
    'godot/scripts/object_shard_m4_runtime.gd', 'godot/scripts/object_shard_workbench_scenes.gd',
    'godot/data/objectshard_owner_tower2_authored_start.json',
    'godot/scripts/object_shard_live_edit_diagnostics.gd',
    'godot/tests/test_object_shard_live_edit_diagnostics.gd',
    'godot/tests/test_object_shard_live_edit_contract.gd',
    'godot/tests/test_object_shard_m4_creative_scenes.gd',
    'godot/tests/test_object_shard_m4_creative_constructions.gd',
    'godot/tests/test_object_shard_m4_edit_preview_render.gd',
    'godot/tests/test_object_shard_m4_disabled_input.gd',
    'godot/tests/test_object_shard_m4_live_input.gd',
    'godot/tests/test_object_shard_m4_live_tools.gd',
    'godot/tests/test_object_shard_m4_live_stress.gd',
    'godot/tests/test_object_shard_m4_owner_authored.gd',
    'godot/tests/test_object_shard_m4_visible_footprints.gd',
    'godot/tests/support/object_shard_m4_live_input_fixture.gd',
    'godot/scripts/object_shard_physics_bridge.gd', 'godot/tests/test_object_shard_m4_workbench_completion.gd',
    'godot/tests/test_object_shard_physics_bridge.gd', 'godot/tests/test_object_shard_rest_contacts.gd',
    'godot/tests/test_object_shard_m4_material_only_workbench.gd',
    'godot/tests/test_object_shard_m4_fragment_reabsorption.gd',
    'godot/tests/test_object_shard_m4_lifecycle_adverse.gd',
    'godot/tests/test_object_shard_m4_completed_sample.gd',
    'godot/tests/test_object_shard_m4_equipment_completion.gd',
    'godot/tests/test_object_shard_m4_long_burn.gd',
    'godot/tests/test_object_shard_m4_lifecycle_fuzz.gd',
    'godot/tests/test_object_shard_m4_overlay_identity.gd', 'godot/tests/profile_object_shard_m4_render_control.gd',
    'godot/tests/probe_object_shard_workbench_package.gd', 'godot/tests/profile_object_shard_m4_workbench.gd',
    'godot/addons/godot-rapier2d/runtime-provenance.windows.json', 'READ-ME.md',
    'Open Workbench.cmd', 'Verify Workbench.cmd', 'tools/objectshard/verify_workbench_package.ps1')
$hasGenerator = ($null -ne $manifest.files_sha256.PSObject.Properties['godot/scripts/workbench_reciprocal_panel.gd'] -or
    $null -ne $manifest.native.source_inputs.PSObject.Properties['native/include/cybersand/workbench_authoring_patch.hpp'] -or
    $null -ne $manifest.files_sha256.PSObject.Properties[$generatorRelative] -or
    $null -ne $manifest.files_sha256.PSObject.Properties[$bindingRelative])
if ($hasGenerator) {
    $required += @($generatorRelative, $bindingRelative, 'godot/tests/fixtures/object_shard_m4_authored_reopen.gd')
}
foreach ($relative in $required) {
    if ($null -eq $manifest.files_sha256.PSObject.Properties[$relative]) { throw "Missing inventory: $relative" }
}
foreach ($foreign in @('godot/tools/gentek_reciprocal', 'godot/tools/swarm004-runtime.linux.json')) {
    if (Test-Path -LiteralPath (Join-Path $root $foreign)) { throw "Foreign reciprocal generator input: $foreign" }
}
$codeSuffixes = @('.exe','.dll','.so','.dylib','.gdextension','.gd','.gdc','.cs','.tscn','.tres','.pck',
    '.gdshader','.gdshaderinc','.ps1','.cmd','.bat','.py')
foreach ($item in Get-ChildItem -LiteralPath $root -Recurse -Force) {
    $relative = $item.FullName.Substring($root.TrimEnd([IO.Path]::DirectorySeparatorChar).Length + 1).Replace('\','/')
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "External package path: $relative" }
    if ($item.PSIsContainer) { continue }
    if ($relative -eq 'objectshard-workbench-manifest.json' -or $null -ne $manifest.files_sha256.PSObject.Properties[$relative]) { continue }
    $cache = $relative.StartsWith('godot/.godot/') -and ([IO.Path]::GetExtension($relative).ToLowerInvariant() -notin $codeSuffixes)
    $uid = ($relative.EndsWith('.gd.uid') -or $relative.EndsWith('.gdshader.uid')) -and
        $null -ne $manifest.files_sha256.PSObject.Properties[$relative.Substring(0,$relative.Length-4)]
    $import = $relative.StartsWith('godot/') -and $relative.EndsWith('.import') -and
        $null -ne $manifest.files_sha256.PSObject.Properties[$relative.Substring(0,$relative.Length-7)]
    if (-not ($cache -or $uid -or $import)) { throw "Unlisted package input: $relative" }
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
if ($hasGenerator) {
    $binding = Get-Content -LiteralPath (Join-Path $root $bindingRelative) -Raw | ConvertFrom-Json
    $generator = Get-Item -LiteralPath (Join-Path $root $generatorRelative)
    if ($binding.platform -cne 'windows' -or $binding.artifact -cne $generatorRelative -or
        ($binding.bytes -isnot [int] -and $binding.bytes -isnot [long]) -or $binding.bytes -ne $generator.Length -or
        $binding.sha256 -cne $manifest.files_sha256.PSObject.Properties[$generatorRelative].Value) {
        throw 'Windows reciprocal generator differs from its delivered binding'
    }
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
$nativeFile = Get-Item -LiteralPath (Join-Path $root $nativeRelative)
if (($candidate.schema_version -isnot [int] -and $candidate.schema_version -isnot [long]) -or
    $candidate.schema_version -ne 1 -or $candidate.kind -ne 'source-built-windows-candidate' -or
    $candidate.artifact -ne $nativeRelative -or
    ($candidate.size -isnot [int] -and $candidate.size -isnot [long]) -or $candidate.size -ne $nativeFile.Length) {
    throw 'Native candidate provenance contract mismatch'
}
$nativeStream = [IO.File]::OpenRead($nativeFile.FullName)
try {
    if ($nativeStream.ReadByte() -ne 77 -or $nativeStream.ReadByte() -ne 90) { throw 'Native candidate is not a Windows PE runtime' }
} finally { $nativeStream.Dispose() }
if ($candidate.sha256 -ne $manifest.native.sha256) { throw 'Candidate binary identity mismatch' }
$sameSource = ($candidate.source_commit -eq $manifest.source_commit -and
               $candidate.source_tree -eq $manifest.source_tree -and
               $candidate.build_commit -eq $manifest.source_commit)
$reuse = $null
if (-not $sameSource) {
    $reuseRelative = 'qualified-candidate-reuse-provenance.json'
    if ($null -eq $manifest.files_sha256.PSObject.Properties[$reuseRelative]) {
        throw 'Reused native candidate lacks an inventoried equivalence receipt'
    }
    $reusePath = Join-Path $root $reuseRelative
    if (-not (Test-Path -LiteralPath $reusePath -PathType Leaf)) {
        throw 'Reused native candidate equivalence receipt is missing'
    }
    $reuse = Get-Content -LiteralPath $reusePath -Raw | ConvertFrom-Json
    if ($reuse.schema_version -ne 1 -or $reuse.kind -ne 'qualified-windows-candidate-input-equivalence' -or
        $reuse.artifact -ne $nativeRelative -or
        $reuse.qualified_source_commit -ne $candidate.source_commit -or
        $candidate.build_commit -ne $candidate.source_commit -or
        $reuse.current_source_commit -ne $manifest.source_commit -or
        $reuse.current_source_tree -ne $manifest.source_tree -or
        $reuse.sha256 -ne $manifest.native.sha256 -or $reuse.size -ne $nativeFile.Length -or
        $reuse.source_inputs_sha256 -notmatch '^[0-9a-f]{64}$' -or
        ($reuse.source_input_count -isnot [int] -and $reuse.source_input_count -isnot [long]) -or
        $reuse.source_input_count -le 0 -or
        ($reuse.qualified_workflow_run -isnot [int] -and $reuse.qualified_workflow_run -isnot [long]) -or
        $reuse.qualified_workflow_run -le 0 -or
        ($reuse.qualified_artifact_id -isnot [int] -and $reuse.qualified_artifact_id -isnot [long]) -or
        $reuse.qualified_artifact_id -le 0) {
        throw 'Reused native candidate equivalence provenance mismatch'
    }
}
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
if ($null -ne $reuse) {
    if ($reuse.source_input_count -ne $sourceCount) { throw 'Reused native input count mismatch' }
    $canonicalParts = foreach ($entry in ($manifest.native.source_inputs.PSObject.Properties | Sort-Object Name)) {
        if ($entry.Name -notmatch '^[A-Za-z0-9_./-]+$' -or $entry.Value -notmatch '^[0-9a-f]{64}$') {
            throw "Unsafe native input ledger entry: $($entry.Name)"
        }
        '"' + [string]$entry.Name + '":"' + [string]$entry.Value + '"'
    }
    $canonicalInputs = '{' + ($canonicalParts -join ',') + '}'
    $inputHash = [Security.Cryptography.SHA256]::Create()
    try {
        $inputDigest = [BitConverter]::ToString(
            $inputHash.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonicalInputs))
        ).Replace('-', '').ToLowerInvariant()
    } finally { $inputHash.Dispose() }
    if ($reuse.source_inputs_sha256 -cne $inputDigest) { throw 'Reused native input digest mismatch' }
}
Write-Host "Workbench package PASS: $count files; source $($manifest.source_commit)"
Write-Host 'Physical Windows/NVIDIA acceptance is separate from this exact-byte verification.'
