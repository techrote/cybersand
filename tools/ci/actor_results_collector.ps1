# ACTOR-COMPOSE-FINAL-001: local-only, opt-in Windows evidence collector.
# Run after closing the interactive Workbench. Does not transmit any data.
param([switch]$EvidenceOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $root
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $root ("Actor-Acceptance-Results\" + $stamp)
New-Item -ItemType Directory -Path $out -Force | Out-Null
$summary = [ordered]@{schema=1; started_utc=[DateTime]::UtcNow.ToString('o');
  source_commit=''; package_identity='unverified'; native_identity='unverified';
  godot_import='not_run'; pilot='not_run'; pilot_checks=0; pilot_failures=@();
  elapsed_seconds=0; windows_graphics='unknown'; manifest_files_expected=0;
  manifest_files_verified=0; completed_utc=''; status='pending';
  notes='Local-only collector; owner Windows 11/NVIDIA playfeel is not automatically verified.'}
$watch = [Diagnostics.Stopwatch]::StartNew()
$success = $false
try {
    $manifestFile = Join-Path $root 'candidate-manifest.json'
    $manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
    $summary.source_commit = [string]$manifest.source_commit
    Copy-Item -LiteralPath $manifestFile -Destination (Join-Path $out 'candidate-manifest.json')
    $sourceFile = Join-Path $root 'source-built-candidate-provenance.json'
    Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $out 'source-built-candidate-provenance.json')
    $candidate = Get-Content -LiteralPath $sourceFile -Raw | ConvertFrom-Json
    # Hash every shipped payload member, not just the binary quartet.
    # Reject path escape, aliases, missing members and reparse-point substitutions.
    $properties = @($manifest.files_sha256.PSObject.Properties)
    if ($properties.Count -lt 1) { throw 'Candidate manifest has no payload members' }
    $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\') + [IO.Path]::DirectorySeparatorChar
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $identities = @()
    $summary.manifest_files_expected = $properties.Count
    $summary.manifest_files_verified = 0
    foreach ($entry in $properties) {
        $name = [string]$entry.Name
        if ([string]::IsNullOrWhiteSpace($name) -or
            $name -match '(^/|//|(^|/)\.{1,2}(/|$)|[\\:]|[<>|?"*])' -or
            -not $seen.Add($name)) {
            throw ('Unsafe, empty, or duplicate manifest path: ' + $name)
        }
        $expected = [string]$entry.Value
        if ($expected -cnotmatch '^[0-9a-f]{64}$') {
            throw ('Invalid manifest SHA-256 digest: ' + $name)
        }
        $file = [IO.Path]::GetFullPath((Join-Path $root ($name -replace '/','\')))
        if (-not $file.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw ('Missing or escaped manifest member: ' + $name)
        }
        $info = Get-Item -LiteralPath $file -Force
        if (($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ('Manifest member is a reparse point: ' + $name)
        }
        $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $expected) {
            throw ('Packaged file differs from manifest: ' + $name)
        }
        $identities += [pscustomobject]@{path=$name; sha256=$actual; verified=$true}
        $summary.manifest_files_verified += 1
    }
    if ($summary.manifest_files_verified -ne $summary.manifest_files_expected) {
        throw 'Incomplete full-package verification'
    }
    $identities | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $out 'verified-files.json')
    if ($candidate.source_commit -ne $manifest.source_commit -or
        $candidate.source_tree -ne $manifest.source_tree -or
        $candidate.sha256 -ne $manifest.native_sha256) {
        throw 'Native provenance does not bind to this exact package source'
    }
    $summary.package_identity = 'passed'
    $summary.native_identity = 'passed'
    $console = Join-Path $root 'Godot_v4.7-stable_win64_console.exe'
    $project = Join-Path $root 'godot'
    (& $console --version) | Out-File -FilePath (Join-Path $out 'godot-version.txt')
    if (-not $EvidenceOnly) {
        $env:CYBERSAND_SOURCE_REVISION = [string]$manifest.source_commit
        $ErrorActionPreference = 'Continue'
        & $console --headless --path $project --editor --quit *> (Join-Path $out 'godot-import.log')
        $importExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $summary.godot_import = if ($importExit -eq 0) { 'passed' } else { 'failed' }
        if ($importExit -ne 0) { throw ('Godot import returned ' + $importExit) }
        # Graphical physical Workbench regression, not a manual focus/playfeel verdict.
        $ErrorActionPreference = 'Continue'
        & $console --path $project --rendering-driver opengl3_angle --script res://tests/test_workbench_actor_configuration_native.gd *> (Join-Path $out 'pilot-workbench-rapier.log')
        $pilotExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        $raw = Get-Content -LiteralPath (Join-Path $out 'pilot-workbench-rapier.log') -Raw
        $lines = @($raw -split '\r?\n' | Where-Object { $_.StartsWith('WB_ACTOR_CONFIGURATION_NATIVE ') })
        if ($lines.Count -ne 1) { throw 'Expected exactly one native Workbench assertion receipt' }
        $receipt = $lines[0].Substring('WB_ACTOR_CONFIGURATION_NATIVE '.Length) | ConvertFrom-Json
        $summary.pilot_checks = [int]$receipt.checks
        $summary.pilot_failures = @($receipt.failures)
        $summary.pilot = if ($pilotExit -eq 0 -and $receipt.checks -ge 60 -and
            $summary.pilot_failures.Count -eq 0) { 'passed' } else { 'failed' }
        if ($summary.pilot -ne 'passed') { throw 'Graphical input-to-Rapier regression failed' }
    } else {
        $summary.pilot = 'not_run_evidence_only'
    }
    $success = $true
} catch {
    $_.ToString() | Set-Content -LiteralPath (Join-Path $out 'collector-error.txt')
    Write-Warning ('Actor collector: ' + $_.ToString())
} finally {
    try {
        [pscustomobject]@{
            os=[Environment]::OSVersion.VersionString
            gpu=@(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM)
            cpu=@(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors)
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'local-hardware.json')
        $summary.windows_graphics = 'hardware_summary_recorded'
    } catch {
        ('Hardware query unavailable: ' + $_.ToString()) | Set-Content -LiteralPath (Join-Path $out 'hardware-error.txt')
    }
    $watch.Stop()
    $summary.elapsed_seconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
    $summary.completed_utc = [DateTime]::UtcNow.ToString('o')
    $summary.status = if ($success) { 'passed' } else { 'failed' }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out 'acceptance-collector.json')
    @'
OWNER PHYSICAL ACCEPTANCE — fill in manually
Source package and GPU driver:
Living Mixed Workshop loads:
Inspect Runner without stealing pilot:
Pilot inspected -> close Configuration -> Play -> A/D/Space:
Explicit picker, Scripted -> Human -> Scripted and preserved body:
Grab articulated part while Play, then release:
Paused placement, Q/E rotation, Escape:
Paint/erase while other actors and materials progress:
Focus loss/recovery, pause/resume, configuration close:
Actor deletion, reset, fresh Save/Load:
Observed frame rate and longest visible freeze in milliseconds:
Other observations:
'@ | Set-Content -LiteralPath (Join-Path $out 'owner-observations.txt')
    $archive = $out + '.zip'
    try {
        Compress-Archive -Path (Join-Path $out '*') -DestinationPath $archive -Force
    } catch {
        Write-Warning ('Could not create ZIP; logs retained: ' + $_.ToString())
    }
    Write-Host ('Results: ' + $out)
    Write-Host ('ZIP if available: ' + $archive)
}
if (-not $success) { exit 1 }
