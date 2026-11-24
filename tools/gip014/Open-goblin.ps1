[CmdletBinding()]
param(
    [ValidateSet('Interactive', 'SelfTest')][string]$Mode = 'Interactive',
    [switch]$GraphicalSmoke
)

# Fixed developer evaluator launcher. The game receives only a disposable
# profile marker and finite scene/policy options. No Python installation needed.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')
$manifestPath = Join-Path $packageRoot 'goblin-evaluator-manifest.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 50) + "`n"), $utf8)
}

function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Relative([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($packageRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'An evaluator output is outside this extracted package.'
    }
    return $full.Substring($packageRoot.Length + 1).Replace('\', '/')
}

function Assert-Payload($Manifest) {
    if ($Manifest.schema -ne 'cybersand-goblin-evaluator-v1' -or $Manifest.source_commit -notmatch '^[0-9a-f]{40}$') {
        throw 'The goblin evaluator manifest is missing or unsupported.'
    }
    foreach ($entry in $Manifest.files_sha256.PSObject.Properties) {
        $name = [string]$entry.Name
        if ($name.StartsWith('/') -or $name.Contains('\') -or $name.Contains(':') -or $name.Split('/') -contains '..') {
            throw "Invalid package member: $name"
        }
        $path = [IO.Path]::GetFullPath((Join-Path $packageRoot $name))
        if (-not $path.StartsWith($packageRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha $path) -ne [string]$entry.Value) {
            throw "Evaluator file changed or is missing: $name"
        }
    }
}

function New-TestProfile([string]$Fixture, [string]$Policy, [int]$Budget, [string]$EvidenceKind) {
    $outputRoot = Join-Path $packageRoot 'test-output'
    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $profile = Join-Path $outputRoot ([Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($profile) | Out-Null
    foreach ($name in @('data', 'config', 'cache', 'appdata', 'localappdata')) {
        [IO.Directory]::CreateDirectory((Join-Path $profile $name)) | Out-Null
    }
    $env:XDG_DATA_HOME = Join-Path $profile 'data'
    $env:XDG_CONFIG_HOME = Join-Path $profile 'config'
    $env:XDG_CACHE_HOME = Join-Path $profile 'cache'
    $env:APPDATA = Join-Path $profile 'appdata'
    $env:LOCALAPPDATA = Join-Path $profile 'localappdata'
    $env:CYBERSAND_GOBLIN_PROFILE = $profile
    $env:CYBERSAND_SOURCE_REVISION = [string]$manifest.source_commit
    foreach ($relative in @('appdata/Godot/app_userdata/Cyber Sand Reference Sandbox', 'data/godot/app_userdata/Cyber Sand Reference Sandbox')) {
        [IO.Directory]::CreateDirectory((Join-Path $profile $relative)) | Out-Null
    }
    $launch = @{ fixture_id = $Fixture; policy = $Policy; seed = 13; budget = $Budget;
                 pacing_ms = $(if ($Mode -eq 'Interactive') { 150 } else { 0 });
                 evidence_kind = $EvidenceKind; replay = $false }
    Write-Json (Join-Path $profile 'goblin-profile.json') @{ schema = 'cybersand-goblin-profile-v1'; launch = $launch; provenance = $manifest.provenance }
    return $profile
}

function Invoke-FixedGodot([string]$Profile, [string]$Name, [string[]]$GameArguments, [int]$Seconds) {
    $stdout = Join-Path $Profile ($Name + '-stdout.log')
    $stderr = Join-Path $Profile ($Name + '-stderr.log')
    $log = Join-Path $Profile ($Name + '.log')
    $arguments = @('--path', (Join-Path $packageRoot 'godot')) + $GameArguments
    # Values here are fixed flags, package-local paths and committed res:// names.
    $quoted = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $started = [DateTime]::UtcNow
    $process = Start-Process -FilePath (Join-Path $packageRoot 'Godot_v4.7-stable_win64_console.exe') -ArgumentList $quoted -WorkingDirectory $packageRoot -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    [void]$process.Handle
    if ($Seconds -gt 0 -and -not $process.WaitForExit($Seconds * 1000)) {
        # The console wrapper may own the actual engine process. Stop only this
        # launched test's process tree, then preserve its real timeout outcome.
        & (Join-Path $env:SystemRoot 'System32/taskkill.exe') /PID ([string]$process.Id) /T /F | Out-Null
        if (-not $process.HasExited) { $process.Kill() }
        $process.WaitForExit()
        [IO.File]::WriteAllText($log, "GOBLIN_PACKAGE_TIMEOUT`n" + [IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr), $utf8)
        throw "The fixed $Name test reached its normal timeout; evidence remains in $Profile"
    }
    if ($Seconds -eq 0) { $process.WaitForExit() }
    $process.Refresh()
    $text = [IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr)
    [IO.File]::WriteAllText($log, $text, $utf8)
    if ($process.ExitCode -ne 0 -or $text -match '(?m)SCRIPT ERROR:|Parse Error:|ERROR:|Fatal signal|Segmentation fault') {
        throw "The fixed $Name test failed; see $log"
    }
    return @{ log = $log; text = $text; elapsed_seconds = ([DateTime]::UtcNow - $started).TotalSeconds; exit_code = $process.ExitCode }
}

function Invoke-CampaignCase([string]$Fixture) {
    $profile = New-TestProfile $Fixture 'CONTROL' 64 'packaged_evaluator'
    $run = Invoke-FixedGodot $profile 'campaign' @('--headless', '--script', 'res://goblin/run_campaign.gd') 180
    $terminal = @($run.text -split '\r?\n' | Where-Object { $_ -eq 'GOBLIN_CAMPAIGN_COMPLETE' })
    $resultLines = @($run.text -split '\r?\n' | Where-Object { $_.StartsWith('GOBLIN_CAMPAIGN_RESULT ') })
    if ($terminal.Count -ne 1 -or $resultLines.Count -ne 1) { throw 'Campaign completion/validation marker is missing or duplicated.' }
    $result = $resultLines[0].Substring('GOBLIN_CAMPAIGN_RESULT '.Length) | ConvertFrom-Json
    if ($result.validation.ok -ne $true -or @($result.validation.errors).Count -ne 0) { throw 'Godot rejected the recorded transcript.' }
    $transcripts = @(Get-ChildItem -LiteralPath $profile -Recurse -File -Filter 'transcript.json' | Where-Object { $_.Directory.Name -eq 'goblin' })
    if ($transcripts.Count -ne 1) { throw 'The campaign did not leave exactly one fixed transcript.' }
    $transcriptPath = $transcripts[0].FullName
    $tape = [IO.File]::ReadAllText($transcriptPath) | ConvertFrom-Json
    if ($tape.schema -ne 'cybersand-goblin-transcript-v1' -or $tape.header.fixture_id -ne $Fixture -or
        $tape.header.policy -ne 'CONTROL' -or $tape.header.seed -ne 13 -or $tape.header.budget -ne 64 -or
        $tape.header.provenance.source_commit -ne $manifest.source_commit -or
        $tape.header.provenance.native_sha256 -ne $manifest.provenance.native_sha256 -or
        $tape.header.provenance.rapier_sha256 -ne $manifest.provenance.rapier_sha256 -or
        $tape.header.provenance.godot_sha256 -ne $manifest.provenance.godot_sha256 -or
        $tape.summary.termination -ne 'budget_complete' -or $tape.summary.attempted_actions -ne 64 -or
        @($tape.steps).Count -ne 64 -or $tape.summary.completed_actions -le 0 -or @($tape.summary.failures).Count -ne 0) {
        throw 'The extracted-package campaign lacks complete matching source/native evidence.'
    }
    return @{ fixture = $Fixture; policy = 'CONTROL'; seed = 13; budget = 64; status = 'pass';
              termination = $tape.summary.termination; attempted_actions = $tape.summary.attempted_actions;
              completed_actions = $tape.summary.completed_actions; assertion_failures = @($tape.summary.failures).Count;
              validation_ok = $true; completion_marker = $true; elapsed_seconds = $run.elapsed_seconds;
              log = Get-Relative $run.log; log_sha256 = Get-Sha $run.log;
              transcript = Get-Relative $transcriptPath; transcript_sha256 = Get-Sha $transcriptPath }
}

$reportPath = $null
$report = $null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This evaluator uses the pinned Windows runtime.' }
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    Assert-Payload $manifest
    $version = ((& (Join-Path $packageRoot 'Godot_v4.7-stable_win64_console.exe') --version) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $version -ne $manifest.provenance.godot_version) { throw 'The packaged engine does not report the pinned version.' }
    $preflight = New-TestProfile 'material_playground' 'CONTROL' 64 'packaged_evaluator'
    $import = Invoke-FixedGodot $preflight 'import' @('--headless', '--editor', '--quit') 240
    if ($Mode -eq 'Interactive') {
        $profile = New-TestProfile 'material_playground' 'WANDERER' 128 'graphical_godot'
        Write-Host "Opening goblin. This run's outputs: $profile"
        Invoke-FixedGodot $profile 'interactive' @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle', '--scene', 'res://goblin/goblin.tscn') 0 | Out-Null
    } else {
        $reportPath = Join-Path $preflight 'package-selftest.json'
        $report = @{ schema = 'cybersand-goblin-package-selftest-v1'; status = 'running';
                     source_commit = $manifest.source_commit; source_tree = $manifest.source_tree;
                     manifest_sha256 = Get-Sha $manifestPath; platform = 'Windows'; cases = @();
                     import_log = Get-Relative $import.log; import_log_sha256 = Get-Sha $import.log;
                     graphical_smoke = @{ status = 'not_run' }; evidence_scope = 'hosted extracted package; no physical NVIDIA acceptance' }
        Write-Json $reportPath $report
        foreach ($fixture in @('actor_workshop', 'save_reopen')) {
            $case = Invoke-CampaignCase $fixture
            $report.cases += $case
            Write-Json $reportPath $report
        }
        if ($GraphicalSmoke) {
            $profile = New-TestProfile 'construction' 'CONTROL' 16 'graphical_godot'
            $report.graphical_smoke = @{ status = 'running'; profile = Get-Relative $profile }
            Write-Json $reportPath $report
            try {
                $smoke = Invoke-FixedGodot $profile 'interactive-smoke' @('--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle', '--script', 'res://goblin/tests/test_interactive.gd') 180
                if ($smoke.text -notmatch 'GOBLIN_INTERACTIVE_RESULT') { throw 'Interactive smoke emitted no result.' }
                $report.graphical_smoke = @{ status = 'pass'; log = Get-Relative $smoke.log; log_sha256 = Get-Sha $smoke.log }
            } catch {
                $report.graphical_smoke.status = 'failed'
                $report.graphical_smoke.error = $_.Exception.Message
                $failedLog = Join-Path $profile 'interactive-smoke.log'
                if (Test-Path -LiteralPath $failedLog -PathType Leaf) {
                    $report.graphical_smoke.log = Get-Relative $failedLog
                    $report.graphical_smoke.log_sha256 = Get-Sha $failedLog
                }
                Write-Json $reportPath $report
                throw
            }
        }
        Assert-Payload $manifest
        $report.status = 'pass'
        Write-Json $reportPath $report
        Write-Host "GOBLIN_PACKAGE_SELFTEST_PASS $reportPath"
    }
    exit 0
} catch {
    if ($null -ne $reportPath -and $null -ne $report) {
        $report.status = 'failed'
        $report.error = $_.Exception.Message
        Write-Json $reportPath $report
    }
    Write-Error $_.Exception.Message
    exit 1
}
