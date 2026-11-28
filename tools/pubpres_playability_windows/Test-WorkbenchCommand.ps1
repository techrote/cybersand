[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedCandidate,
    [Parameter(Mandatory=$true)][string]$Output
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Probe = @{Root=$PackageRoot; Candidate=$ExpectedCandidate; Output=$Output}
. (Join-Path $PSScriptRoot 'Start-PUBPRES-Playability.ps1') -Library
$ProbeRoot = [IO.Path]::GetFullPath($Probe.Root)
$ProbeOutput = [IO.Path]::GetFullPath($Probe.Output)
Assert-PP (-not (Test-Path -LiteralPath $ProbeOutput) -and
    -not $ProbeOutput.StartsWith($ProbeRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Use a new evidence folder outside the extracted payload'
[IO.Directory]::CreateDirectory($ProbeOutput) | Out-Null
$Report = [ordered]@{
    schema='pubpres-completion-one-click-v1'; candidate_commit=$Probe.Candidate; complete=$false
    failure=$null; run=$null; manifest_sha256=$null; phases=[Collections.Generic.List[object]]::new()
    physical_acceptance='HOLD'; scope='Actual installed Windows CMD, Safe/full publication and continuation OFF on ANGLE, one isolated profile and two actual launch processes'
}
try {
    $ProbeManifest = Test-PPPackage $ProbeRoot $Probe.Candidate
    $Report.manifest_sha256 = Get-PPHash (Join-Path $ProbeRoot $script:PPManifestName)
    $InstalledCommand = Join-PPSafe $ProbeRoot $ProbeManifest.owner_command
    $Runs = Join-Path ([IO.Path]::GetDirectoryName($ProbeRoot)) 'Runs'
    $Folder = 'Workbench-'+$Probe.Candidate.Substring(0,12)+'-'+$Report.manifest_sha256.Substring(0,12)+'-opengl3_angle'
    $Run = Join-PPSafe $Runs $Folder
    Assert-PP (-not (Test-Path -LiteralPath $Run)) 'Unexpected reused owner qualification profile'
    $Report.run = $Run
    for ($LaunchNumber=1; $LaunchNumber -le 2; $LaunchNumber++) {
        $Log = Join-Path $ProbeOutput ('launcher-'+$LaunchNumber+'.log')
        & $InstalledCommand --hosted-smoke *> $Log
        Assert-PP ($LASTEXITCODE -eq 0) ('The shipped Workbench command failed; retained log: '+$Log)
        $RunRecord = Test-PPRun $Run $ProbeRoot $ProbeManifest
        Assert-PP ($RunRecord.source -ceq 'C' -and $RunRecord.render_thread -ceq 'safe' -and
            $RunRecord.staging_pools -ceq 'eager' -and $RunRecord.same_frame_continuation -ceq 'off' -and
            $RunRecord.render_driver -ceq 'opengl3_angle' -and
            $RunRecord.settings.CYBERSAND_MATERIAL_PUBLICATION -ceq 'full') 'Installed Workbench launch selectors differ'
        $Ready = @(Get-ChildItem -LiteralPath (Join-Path $Run 'launches') -Recurse -File -Filter 'verified-startup.json')
        Assert-PP ($Ready.Count -eq $LaunchNumber) 'Expected a separately verified startup for each fresh launch'
        $Report.phases.Add([ordered]@{launch=$LaunchNumber; startup_sha256=@($Ready | ForEach-Object { Get-PPHash $_.FullName });
            run_json_sha256=Get-PPHash (Join-Path $Run 'run.json'); command_sha256=Get-PPHash $InstalledCommand})
        Test-PPPackage $ProbeRoot $Probe.Candidate | Out-Null
    }
    Assert-PP ($Report.phases[0].run_json_sha256 -ceq $Report.phases[1].run_json_sha256) 'Reopen did not preserve the original run'
    $Report.complete = $true
} catch {
    $Report.failure = $_.Exception.Message
} finally {
    Write-PPJson (Join-Path $ProbeOutput 'SUMMARY.json') $Report
}
Assert-PP $Report.complete ('Installed CMD launch/reopen failed: '+$Report.failure)
