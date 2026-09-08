param([ValidateSet('compat', 'threaded')][string]$Profile = 'compat')
$ErrorActionPreference = 'Stop'
$folder = if ($Profile -eq 'threaded') { 'web-threaded' } else { 'web' }
$variant = if ($Profile -eq 'threaded') { 'threads' } else { 'nothreads' }
$buildRoot = "C:\kybersand\source\build\$folder"
$deliverRoot = "C:\cybersand\$folder"
$manifest = Join-Path $buildRoot 'SHA256SUMS'
if (!(Test-Path -LiteralPath $manifest)) { throw 'Build/export Web first using dev.cmd web.' }
$verifiedFiles = @()
foreach ($line in Get-Content -LiteralPath $manifest) {
    if (!$line.Trim()) { continue }
    if ($line -notmatch '^([0-9a-fA-F]{64})\s+\*?(.+)$') { throw "Invalid checksum entry: $line" }
    $expected = $Matches[1]
    $relative = $Matches[2]
    $sourceFile = [IO.Path]::GetFullPath((Join-Path $buildRoot $relative))
    if (!$sourceFile.StartsWith($buildRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe manifest path' }
    if ((Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash -ne $expected) { throw "Checksum mismatch: $relative" }
    $verifiedFiles += $relative
}
if ($verifiedFiles.Count -eq 0) { throw 'Empty manifest' }
$identity = Get-Content -LiteralPath (Join-Path $buildRoot 'build-info.json') -Raw | ConvertFrom-Json
if ($identity.rapier -ne 'disabled') {
    foreach ($required in @('godot_rapier.wasm', 'RAPIER_LICENSE.txt', 'RAPIER_THIRDPARTY.txt')) {
        if ($required -notin $verifiedFiles) { throw "Missing Rapier payload: $required" }
    }
    if ((Get-FileHash -LiteralPath (Join-Path $buildRoot 'godot_rapier.wasm')).Hash -ne $identity.rapier_sha256) { throw 'Rapier identity mismatch' }
}
foreach ($required in @('index.html', 'index.js', 'index.wasm', 'index.side.wasm', 'index.pck', "libcybersand_native.web.$variant.wasm")) {
    if ($required -notin $verifiedFiles) { throw "Missing required payload: $required" }
}
New-Item -ItemType Directory -Path $deliverRoot -Force | Out-Null
foreach ($relative in ($verifiedFiles + 'SHA256SUMS')) {
    $targetFile = Join-Path $deliverRoot $relative
    New-Item -ItemType Directory -Path (Split-Path $targetFile) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $buildRoot $relative) -Destination $targetFile -Force
    if ((Get-FileHash -LiteralPath $targetFile).Hash -ne (Get-FileHash -LiteralPath (Join-Path $buildRoot $relative)).Hash) { throw "Delivery copy mismatch: $relative" }
}
Write-Output "Delivered $($verifiedFiles.Count) verified files to $deliverRoot"
