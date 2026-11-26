[CmdletBinding()]
param(
    [ValidateSet('Interactive', 'SelfTest', 'Replay')][string]$Mode = 'Interactive',
    [switch]$GraphicalSmoke,
    [string]$Corpus = '',
    [ValidatePattern('^$|^case-[0-9]{3}$')][string]$ReplayCase = '',
    [switch]$ClearCorpus
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

function Invoke-CampaignCase([string]$Fixture, [string]$Policy = 'CONTROL') {
    $profile = New-TestProfile $Fixture $Policy 64 'packaged_evaluator'
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
        $tape.header.policy -ne $Policy -or $tape.header.seed -ne 13 -or $tape.header.budget -ne 64 -or
        $tape.header.provenance.source_commit -ne $manifest.source_commit -or
        $tape.header.provenance.native_sha256 -ne $manifest.provenance.native_sha256 -or
        $tape.header.provenance.rapier_sha256 -ne $manifest.provenance.rapier_sha256 -or
        $tape.header.provenance.godot_sha256 -ne $manifest.provenance.godot_sha256 -or
        $tape.summary.termination -ne 'budget_complete' -or $tape.summary.attempted_actions -ne 64 -or
        @($tape.steps).Count -ne 64 -or $tape.summary.completed_actions -le 0 -or @($tape.summary.failures).Count -ne 0) {
        throw 'The extracted-package campaign lacks complete matching source/native evidence.'
    }
    return @{ fixture = $Fixture; policy = $Policy; profile = Get-Relative $profile; seed = 13; budget = 64; status = 'pass';
              termination = $tape.summary.termination; attempted_actions = $tape.summary.attempted_actions;
              completed_actions = $tape.summary.completed_actions; assertion_failures = @($tape.summary.failures).Count;
              validation_ok = $true; completion_marker = $true; elapsed_seconds = $run.elapsed_seconds;
              log = Get-Relative $run.log; log_sha256 = Get-Sha $run.log;
              transcript = Get-Relative $transcriptPath; transcript_sha256 = Get-Sha $transcriptPath }
}

function Invoke-AuthoredLineage {
    $profile = New-TestProfile 'conservation_cell' 'CONTROL' 20 'packaged_evaluator'
    $entry = @{ status = 'running'; profile = Get-Relative $profile; wall_limit_seconds = 300;
                script = 'res://goblin/tests/test_authored_lineage.gd';
                script_sha256 = Get-Sha (Join-Path $packageRoot 'godot/goblin/tests/test_authored_lineage.gd') }
    $report.authored_lineage = $entry
    Write-Json $reportPath $report
    try {
        $run = Invoke-FixedGodot $profile 'authored-lineage' @('--headless', '--script', 'res://goblin/tests/test_authored_lineage.gd') 300
        $lines = @($run.text -split '\r?\n' | Where-Object { $_.StartsWith('GOBLIN_AUTHORED_LINEAGE_RESULT ') })
        if ($lines.Count -ne 1) { throw 'Authored-lineage native completion is missing or duplicated.' }
        $files = @(Get-ChildItem -LiteralPath $profile -Recurse -File -Filter 'authored-lineage-test.json' | Where-Object { $_.Directory.Name -eq 'goblin' })
        if ($files.Count -ne 1 -or $files[0].Length -lt 1 -or $files[0].Length -gt 8388608 -or
            ($files[0].Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Authored-lineage native report is absent, linked, ambiguous or oversized.'
        }
        $native = [IO.File]::ReadAllText($files[0].FullName) | ConvertFrom-Json
        if ($native.schema -cne 'cybersand-goblin-authored-lineage-test-v1' -or $native.status -cne 'pass' -or
            @($native.checks.PSObject.Properties).Count -lt 1 -or @($native.failures).Count -ne 0 -or @($native.native_cases).Count -ne 4 -or
            $native.actual_actions.attempted -ne 20 -or $native.actual_actions.completed -ne 20 -or
            $native.provenance.source_dirty -ne $false) {
            throw 'Authored-lineage native gate did not complete all four ordinary gameplay cases.'
        }
        foreach ($check in $native.checks.PSObject.Properties) {
            if ($check.Value -isnot [bool] -or $check.Value -ne $true) { throw 'Authored-lineage precondition did not pass.' }
        }
        foreach ($key in @('source_commit', 'source_tree', 'platform', 'godot_version', 'godot_sha256', 'native_sha256', 'rapier_sha256', 'project_files_sha256')) {
            if ([string]$native.provenance.$key -cne [string]$manifest.provenance.$key) { throw 'Authored-lineage report belongs to another source/runtime.' }
        }
        if ($native.provenance.replay_identity.game_sources_sha256 -cne $manifest.provenance.replay_identity.game_sources_sha256) {
            throw 'Authored-lineage game-source identity differs.'
        }
        $expected = @('fresh_authored', 'retained_evolved', 'restore_authored', 'actor_reset_retains_evolved')
        $seen = @{}
        foreach ($case in $native.native_cases) {
            if ($expected -cnotcontains [string]$case.id -or $seen.ContainsKey([string]$case.id) -or $case.status -cne 'pass') {
                throw 'Authored-lineage native case identity or status differs.'
            }
            $seen[[string]$case.id] = $true
        }
        $entry.status = 'pass'
        $entry.checks = @($native.checks.PSObject.Properties).Count
        $entry.native_case_count = @($native.native_cases).Count
        $entry.attempted_actions = $native.actual_actions.attempted
        $entry.completed_actions = $native.actual_actions.completed
        $entry.elapsed_seconds = $run.elapsed_seconds
    } catch {
        $entry.status = 'failed'
        $entry.error = $_.Exception.Message
        throw
    } finally {
        $log = Join-Path $profile 'authored-lineage.log'
        if (Test-Path -LiteralPath $log -PathType Leaf) { $entry.log = Get-Relative $log; $entry.log_sha256 = Get-Sha $log }
        $retained = @(Get-ChildItem -LiteralPath $profile -Recurse -File -Filter 'authored-lineage-test.json' | Where-Object { $_.Directory.Name -eq 'goblin' })
        if ($retained.Count -eq 1 -and $retained[0].Length -le 8388608) {
            $entry.report = Get-Relative ($retained[0].FullName)
            $entry.report_sha256 = Get-Sha ($retained[0].FullName)
        }
        Write-Json $reportPath $report
    }
    return $entry
}

function Assert-CorpusShape([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Corpus file is missing.' }
    $file = Get-Item -LiteralPath $Path
    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $file.Length -gt 2097152) {
        throw 'Corpus must be an ordinary file of at most 2 MiB.'
    }
    $data = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
    if ($data.schema -ne 'cybersand-goblin-corpus-v1' -or @($data.records).Count -gt 64) { throw 'Unsupported bounded corpus schema.' }
    return $file.FullName
}

function Import-ProfileMemory([string]$Profile, [string]$Source) {
    $sourcePath = Assert-CorpusShape $Source
    $target = Join-Path $Profile 'goblin-corpus.json'
    Copy-Item -LiteralPath $sourcePath -Destination $target
    $run = Invoke-FixedGodot $Profile 'corpus-admission' @('--headless', '--script', 'res://goblin/validate_corpus.gd') 60
    $lines = @($run.text -split '\r?\n' | Where-Object { $_.StartsWith('GOBLIN_CORPUS_IMPORT_VALID ') })
    if ($lines.Count -ne 1) { throw 'Supported corpus admission did not complete uniquely.' }
    $result = $lines[0].Substring('GOBLIN_CORPUS_IMPORT_VALID '.Length) | ConvertFrom-Json
    if ($result.ok -ne $true -or $result.records -lt 0 -or $result.records -gt 64 -or (Get-Sha $sourcePath) -ne (Get-Sha $target)) {
        throw 'Corpus admission changed bytes or rejected supported records.'
    }
    return @{ source_sha256 = Get-Sha $sourcePath; staged_sha256 = Get-Sha $target; staged_corpus = Get-Relative $target;
              admission_log = Get-Relative $run.log; admission_log_sha256 = Get-Sha $run.log; records = $result.records }
}

function Save-ProfileMemory([string]$Profile) {
    $sources = @(Get-ChildItem -LiteralPath $Profile -Recurse -File -Filter 'corpus.json' | Where-Object { $_.Directory.Name -eq 'goblin' })
    if ($sources.Count -eq 0) { return }
    if ($sources.Count -ne 1) { throw 'The isolated game left ambiguous corpus evidence.' }
    $validation = New-TestProfile 'construction' 'CONTROL' 1 'packaged_evaluator'
    $receipt = Import-ProfileMemory $validation ($sources[0].FullName)
    $output = Join-Path $packageRoot 'test-output'
    $current = Join-Path $output 'goblin-memory.json'
    $previous = Join-Path $output 'goblin-memory.previous.json'
    $partial = Join-Path $output 'goblin-memory.partial.json'
    Copy-Item -LiteralPath ($sources[0].FullName) -Destination $partial
    if (Test-Path -LiteralPath $current -PathType Leaf) {
        [void](Assert-CorpusShape $current)
        Copy-Item -LiteralPath $current -Destination $previous -Force
    }
    Move-Item -LiteralPath $partial -Destination $current -Force
    Write-Json (Join-Path $output 'goblin-memory-receipt.json') @{
        schema = 'cybersand-goblin-memory-publication-v1'; source_commit = $manifest.source_commit;
        memory_sha256 = Get-Sha $current; validation = $receipt;
        retained_backup = (Test-Path -LiteralPath $previous -PathType Leaf); physical_checkpoint_resume = $false
    }
    Write-Host 'Retained bounded goblin experiment memory for the next isolated launch.'
    return @{ source_corpus = Get-Relative ($sources[0].FullName); source_sha256 = Get-Sha ($sources[0].FullName);
              published_sha256 = Get-Sha $current; validation = $receipt }
}

function Clear-ExperimentMemory {
    $count = 0
    foreach ($name in @('goblin-memory.json', 'goblin-memory.previous.json', 'goblin-memory.partial.json', 'goblin-memory-receipt.json')) {
        $path = Join-Path (Join-Path $packageRoot 'test-output') $name
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path; $count++ }
    }
    return $count
}

function Invoke-MemoryRoundtrip($FirstCase, $LastCase) {
    $output = Join-Path $packageRoot 'test-output'
    foreach ($name in @('goblin-memory.json', 'goblin-memory.previous.json', 'goblin-memory.partial.json', 'goblin-memory-receipt.json')) {
        if (Test-Path -LiteralPath (Join-Path $output $name)) { throw 'Qualification memory gate requires an initially fresh package.' }
    }
    $archives = @()
    foreach ($item in @($FirstCase, $LastCase)) {
        $profile = Join-Path $packageRoot $item.profile
        $tapes = @(Get-ChildItem -LiteralPath $profile -Recurse -File -Filter 'run-*.json' | Where-Object { $_.Directory.Name -eq 'goblin' })
        if ($tapes.Count -lt 1 -or $tapes.Count -gt 4) { throw 'Actual retained campaign archives are required for memory clear.' }
        foreach ($tape in $tapes) { $archives += @{ path = Get-Relative $tape.FullName; sha256 = Get-Sha $tape.FullName } }
    }
    $first = Save-ProfileMemory (Join-Path $packageRoot $FirstCase.profile)
    $last = Save-ProfileMemory (Join-Path $packageRoot $LastCase.profile)
    if ($null -eq $first -or $null -eq $last -or $first.validation.records -lt 1 -or $last.validation.records -lt 1 -or $first.published_sha256 -eq $last.published_sha256) {
        throw 'Memory gate requires two distinct actual nonempty campaign corpora.'
    }
    $current = Join-Path $output 'goblin-memory.json'
    $backup = Join-Path $output 'goblin-memory.previous.json'
    $backups = @(Get-ChildItem -LiteralPath $output -File -Filter 'goblin-memory.previous*.json')
    if ($backups.Count -ne 1 -or (Get-Sha $backup) -ne $first.published_sha256 -or (Get-Sha $current) -ne $last.published_sha256) {
        throw 'Memory publication did not preserve exactly one predecessor backup.'
    }
    $fresh = New-TestProfile 'alchemy' 'COVERAGE_HUNTER' 1 'packaged_evaluator'
    $imported = Import-ProfileMemory $fresh $current
    if ($imported.records -lt 1 -or $imported.staged_sha256 -ne $last.published_sha256) { throw 'Fresh-profile memory reuse lost actual records.' }
    $cleared = Clear-ExperimentMemory
    foreach ($name in @('goblin-memory.json', 'goblin-memory.previous.json', 'goblin-memory.partial.json', 'goblin-memory-receipt.json')) {
        if (Test-Path -LiteralPath (Join-Path $output $name)) { throw 'Clear left fixed experiment memory behind.' }
    }
    foreach ($archive in $archives) {
        if ((Get-Sha (Join-Path $packageRoot $archive.path)) -ne $archive.sha256) { throw 'Memory clear changed a retained native campaign archive.' }
    }
    if ($cleared -ne 3) { throw 'Memory clear did not remove the expected fixed publication and backup.' }
    return @{ status = 'pass'; first_corpus = $first.source_corpus; first_corpus_sha256 = $first.source_sha256;
              source_corpus = $last.source_corpus; source_corpus_sha256 = $last.source_sha256;
              first_memory_sha256 = $first.published_sha256; latest_memory_sha256 = $last.published_sha256;
              backup_sha256 = $first.published_sha256; backup_count = 1; fresh_profile_import = $imported;
              records = $imported.records; archive_checks = $archives; initial_memory_absent = $true;
              clear_preserved_archives = $true; cleared_fixed_files = $cleared; final_fixed_memory_absent = $true;
              scope = 'Actual isolated campaign memory; fresh-profile validated hints; no physical checkpoint resume' }
}

function Invoke-PortableReplay([string]$CaseId) {
    $index = [IO.File]::ReadAllText((Join-Path $packageRoot 'replay-corpus/index.json')) | ConvertFrom-Json
    if ($index.schema -ne 'cybersand-goblin-portable-replay-v1' -or @($index.cases).Count -lt 1 -or @($index.cases).Count -gt 8) { throw 'Unsupported portable replay catalogue.' }
    if ($CaseId -eq '') { $CaseId = [string]$index.cases[0].id }
    $selected = @($index.cases | Where-Object { $_.id -eq $CaseId })
    if ($selected.Count -ne 1 -or $CaseId -notmatch '^case-[0-9]{3}$') { throw 'Select one supported portable replay case.' }
    $item = $selected[0]
    if ($item.path -ne ('replay-corpus/' + $CaseId + '.json')) { throw 'Unsupported replay source location.' }
    $source = Join-Path $packageRoot $item.path
    if ((Get-Item -LiteralPath $source).Length -gt 33554432 -or (Get-Sha $source) -ne $item.sha256) { throw 'Portable replay source is oversized or changed.' }
    $tape = [IO.File]::ReadAllText($source) | ConvertFrom-Json
    $actionCount = @($tape.steps).Count
    if ($tape.schema -ne 'cybersand-goblin-transcript-v1' -or $actionCount -lt 1 -or $actionCount -gt 1024) { throw 'Portable replay action bound/schema is unsupported.' }
    $profile = New-TestProfile ([string]$tape.header.fixture_id) ([string]$tape.header.policy) $actionCount 'packaged_evaluator'
    $markerPath = Join-Path $profile 'goblin-profile.json'
    $marker = [IO.File]::ReadAllText($markerPath) | ConvertFrom-Json
    $marker.launch.replay = $true
    Write-Json $markerPath $marker
    Copy-Item -LiteralPath $source -Destination (Join-Path $profile 'goblin-replay.json')
    $seconds = [int][Math]::Min(1200, [Math]::Max(210, $actionCount * 1.2 + 60))
    $run = Invoke-FixedGodot $profile 'portable-replay' @('--headless', '--script', 'res://goblin/run_campaign.gd') $seconds
    $lines = @($run.text -split '\r?\n' | Where-Object { $_.StartsWith('GOBLIN_CAMPAIGN_RESULT ') })
    $complete = @($run.text -split '\r?\n' | Where-Object { $_ -eq 'GOBLIN_CAMPAIGN_COMPLETE' })
    if ($lines.Count -ne 1 -or $complete.Count -ne 1) { throw 'Portable replay did not complete uniquely.' }
    $result = $lines[0].Substring('GOBLIN_CAMPAIGN_RESULT '.Length) | ConvertFrom-Json
    if ($result.validation.ok -ne $true -or $result.replay.semantic_match -ne $true -or $result.evidence_exported -ne $true) { throw 'Portable semantic replay did not reproduce its source.' }
    $actual = @(Get-ChildItem -LiteralPath $profile -Recurse -File -Filter 'transcript.json' | Where-Object { $_.Directory.Name -eq 'goblin' })
    if ($actual.Count -ne 1) { throw 'Portable replay left ambiguous actual evidence.' }
    return @{ status = 'pass'; case_id = $CaseId; semantic_match = $true;
              exact_observation_match = $result.replay.exact_observation_match; original = [string]$item.path;
              original_sha256 = Get-Sha $source; transcript = Get-Relative ($actual[0].FullName);
              transcript_sha256 = Get-Sha ($actual[0].FullName); log = Get-Relative $run.log;
              log_sha256 = Get-Sha $run.log; elapsed_seconds = $run.elapsed_seconds }
}

$reportPath = $null
$report = $null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This evaluator uses the pinned Windows runtime.' }
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    Assert-Payload $manifest
    if ($ClearCorpus) {
        [void](Clear-ExperimentMemory)
        Write-Host 'Cleared bounded experiment memory; archived tapes are preserved.'
        exit 0
    }
    if ($Corpus -ne '' -and $Mode -ne 'Interactive') { throw 'Explicit corpus import is supported only for Interactive mode.' }
    $version = ((& (Join-Path $packageRoot 'Godot_v4.7-stable_win64_console.exe') --version) -join "`n").Trim()
    if ($LASTEXITCODE -ne 0 -or $version -ne $manifest.provenance.godot_version) { throw 'The packaged engine does not report the pinned version.' }
    $preflight = New-TestProfile 'material_playground' 'CONTROL' 64 'packaged_evaluator'
    $import = Invoke-FixedGodot $preflight 'import' @('--headless', '--editor', '--quit') 240
    if ($Mode -eq 'Interactive') {
        $profile = New-TestProfile 'material_playground' 'WANDERER' 128 'graphical_godot'
        $memory = if ($Corpus -ne '') { [IO.Path]::GetFullPath($Corpus) } else { Join-Path (Join-Path $packageRoot 'test-output') 'goblin-memory.json' }
        if (Test-Path -LiteralPath $memory -PathType Leaf) { [void](Import-ProfileMemory $profile $memory) }
        elseif ($Corpus -ne '') { throw 'Explicit corpus file does not exist.' }
        Write-Host "Opening goblin. This run's outputs: $profile"
        Invoke-FixedGodot $profile 'interactive' @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle', '--scene', 'res://goblin/goblin.tscn') 0 | Out-Null
        [void](Save-ProfileMemory $profile)
    } elseif ($Mode -eq 'Replay') {
        $replayResult = Invoke-PortableReplay $ReplayCase
        Write-Host ('GOBLIN_PORTABLE_REPLAY_PASS ' + ($replayResult | ConvertTo-Json -Compress -Depth 8))
    } else {
        $reportPath = Join-Path $preflight 'package-selftest.json'
        $report = @{ schema = 'cybersand-goblin-package-selftest-v1'; status = 'running';
                     source_commit = $manifest.source_commit; source_tree = $manifest.source_tree;
                     manifest_sha256 = Get-Sha $manifestPath; platform = 'Windows'; cases = @();
                     import_log = Get-Relative $import.log; import_log_sha256 = Get-Sha $import.log;
                     graphical_smoke = @{ status = 'not_run' }; evidence_scope = 'hosted extracted package; no physical NVIDIA acceptance' }
        Write-Json $reportPath $report
        $report.authored_lineage = Invoke-AuthoredLineage
        Write-Json $reportPath $report
        foreach ($fixture in @('actor_workshop', 'save_reopen')) {
            $case = Invoke-CampaignCase $fixture
            $report.cases += $case
            Write-Json $reportPath $report
        }
        $discovery = Invoke-CampaignCase 'alchemy' 'COVERAGE_HUNTER'
        $report.cases += $discovery
        $report.portable_replay = Invoke-PortableReplay ([string]$manifest.portable_replay_index.required_replay_case)
        $report.memory_roundtrip = Invoke-MemoryRoundtrip ($report.cases[0]) $discovery
        Write-Json $reportPath $report
        if ($GraphicalSmoke) {
            $profile = New-TestProfile 'construction' 'CONTROL' 16 'graphical_godot'
            $report.graphical_smoke = @{ status = 'running'; profile = Get-Relative $profile }
            Write-Json $reportPath $report
            try {
                $smoke = Invoke-FixedGodot $profile 'interactive-smoke' @('--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle', '--script', 'res://goblin/tests/test_interactive.gd') 180
                if ($smoke.text -notmatch 'GOBLIN_INTERACTIVE_RESULT') { throw 'Interactive smoke emitted no result.' }
                $screenshots = @(Get-ChildItem -LiteralPath $profile -Recurse -File -Filter 'interactive*.png' | ForEach-Object { @{ path = Get-Relative $_.FullName; sha256 = Get-Sha $_.FullName } })
                if ($screenshots.Count -eq 0) { throw 'Actual graphical smoke left no screenshots.' }
                $report.graphical_smoke = @{ status = 'pass'; log = Get-Relative $smoke.log; log_sha256 = Get-Sha $smoke.log; screenshots = $screenshots }
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
