[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedCandidate,
    [Parameter(Mandatory=$true)][string]$Output,
    [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver = 'opengl3_angle',
    [ValidateSet('C','F')][string]$SourceKey = 'C',
    [ValidateSet('Ordinary','Wave2048')][string]$Scenario = 'Ordinary'
)

# Two genuine ordinary Workbench processes from one fresh immutable-package
# copy. Save/native-plane reconstruction remains the separate installed-author
# gate; startup alone cannot establish either persistence or playability.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ReplayInputs = @{Root=$PackageRoot; Candidate=$ExpectedCandidate; Output=$Output; Driver=$RenderingDriver; Source=$SourceKey; Scenario=$Scenario.ToLowerInvariant()}
$ReplayLauncher = Join-Path $PSScriptRoot 'Start-PUBPRES-Playability.ps1'
. $ReplayLauncher -Library
$ReplayRoot = [IO.Path]::GetFullPath($ReplayInputs.Root)
$ReplayOutput = [IO.Path]::GetFullPath($ReplayInputs.Output)
Assert-PP (-not (Test-Path -LiteralPath $ReplayOutput) -and
    -not $ReplayOutput.StartsWith($ReplayRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Use new replay evidence outside the pristine package'
[IO.Directory]::CreateDirectory($ReplayOutput) | Out-Null
$ReplayReport = [ordered]@{schema='pubpres003-pristine-replay-v1'; candidate_commit=$ReplayInputs.Candidate;
    status='HOLD'; complete=$false; failure=$null; checks=[Collections.Generic.List[object]]::new();
    scope='Actual Windows Safe/eager fresh import/startup and same-run fresh-process reopen; no Save or physical NVIDIA acceptance'}
try {
    $ReplayManifest = Test-PPPackage $ReplayRoot $ReplayInputs.Candidate
    $ReplayReport.mission = $ReplayManifest.mission
    $ReplayReport.source = $ReplayInputs.Source; $ReplayReport.scenario = $ReplayInputs.Scenario
    if ($ReplayInputs.Scenario -ceq 'wave2048') { $ReplayReport.scope='Actual Windows Safe/eager active Wave2048 first preparation, ordinary initial Save and fresh-process Load/Play; four real startup steps per process; no steady-state or physical NVIDIA acceptance' }
    $ReplayReport.manifest_sha256 = Get-PPHash (Join-Path $ReplayRoot $script:PPManifestName)
    $ReplayRun = New-PPRun $ReplayRoot $ReplayManifest $ReplayInputs.Source 'eager' 'safe' $ReplayInputs.Driver 'off' $ReplayInputs.Scenario
    $ReplayReport.run = $ReplayRun
    $ReplayDescriptor = Join-PPSafe $ReplayRun 'source/godot/addons/godot-rapier2d/Radial2D.svg.import'
    $ReplayDescriptorHash = Get-PPHash $ReplayDescriptor
    $ReplayReport.import_descriptor_before_sha256 = $ReplayDescriptorHash
    foreach ($ReplayPhase in @('first','reopen')) {
        & $ReplayLauncher -PackageRoot $ReplayRoot -ExpectedCandidate $ReplayInputs.Candidate `
            -Action Open -ReopenRun $ReplayRun -QuitAfterReady
        $ReplayRecord = Test-PPRun $ReplayRun $ReplayRoot $ReplayManifest
        Assert-PP ($ReplayRecord.source -ceq $ReplayInputs.Source -and $ReplayRecord.render_thread -ceq 'safe' -and
            $ReplayRecord.staging_pools -ceq 'eager' -and $ReplayRecord.same_frame_continuation -ceq 'off' -and
            $ReplayRecord.render_driver -ceq $ReplayInputs.Driver) 'Replay selectors changed'
        Assert-PP ((Get-PPHash $ReplayDescriptor) -ceq $ReplayDescriptorHash) 'Committed import descriptor changed during legitimate replay'
        $ReplayReady = @(Get-ChildItem -LiteralPath (Join-Path $ReplayRun 'launches') -Recurse -File -Filter 'verified-startup.json')
        $ReplayExpectedCount = if ($ReplayPhase -ceq 'first') { 1 } else { 2 }
        Assert-PP ($ReplayReady.Count -eq $ReplayExpectedCount) 'Each actual process must retain its own verified startup'
        Test-PPPackage $ReplayRoot $ReplayInputs.Candidate | Out-Null
        $ReplayReport.checks.Add([ordered]@{phase=$ReplayPhase; status='PASS'; verified_startups=$ReplayReady.Count;
            import_descriptor_sha256=Get-PPHash $ReplayDescriptor; source_verified=$true; pristine_verified=$true})
        Write-PPJson (Join-Path $ReplayOutput 'SUMMARY.json') $ReplayReport
    }
    $ReplayReport.startup_receipts = @($ReplayReady | ForEach-Object { [ordered]@{path=$_.FullName;sha256=Get-PPHash $_.FullName} })
    $ReplayReport.status = 'PASS'; $ReplayReport.complete = $true
} catch {
    $ReplayReport.status = 'FAIL'; $ReplayReport.failure = $_.Exception.Message
} finally {
    Write-PPJson (Join-Path $ReplayOutput 'SUMMARY.json') $ReplayReport
}
if (-not $ReplayReport.complete) { throw ('Pristine replay failed: '+$ReplayReport.failure) }
