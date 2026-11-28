[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedCandidate,
    [Parameter(Mandatory=$true)][string]$ArtifactZip,
    [Parameter(Mandatory=$true)][string]$Output
)
$Probe=@{root=$PackageRoot;candidate=$ExpectedCandidate;archive=$ArtifactZip;output=$Output}
. (Join-Path $PSScriptRoot 'Start-PUBPRES-Final.ps1') -Library
$ProbeRoot=[IO.Path]::GetFullPath($Probe.root)
$ProbeOutput=[IO.Path]::GetFullPath($Probe.output)
Assert-PP (-not (Test-Path -LiteralPath $ProbeOutput) -and
    -not $ProbeOutput.StartsWith($ProbeRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Evidence must be new and outside the payload'
[IO.Directory]::CreateDirectory($ProbeOutput)|Out-Null
$Report=[ordered]@{schema='pubpres-recovery-extracted-evaluator-v1';candidate=$Probe.candidate;complete=$false;
    checks=[Collections.Generic.List[object]]::new();launches=[Collections.Generic.List[object]]::new();failure=$null;physical_acceptance='HOLD';
    scope='Actual extracted Windows source/runtime/launcher/reopen/scene/collector/process-owner qualification. No physical NVIDIA or sustained gameplay acceptance.'}
$Extracted=Join-Path $ProbeOutput 'extracted package with spaces'
$Report['extracted_package']=$Extracted
function Refuses([string]$Name,[scriptblock]$Operation) {
    $Rejected=$false
    try { & $Operation|Out-Null } catch { $Rejected=$true }
    Assert-PP $Rejected ('Negative control was accepted: '+$Name)
    $Report.checks.Add(@{name=$Name;passed=$true})
}
function Assert-Scene($Receipt,[string]$SceneName) {
    Assert-PP ($Receipt.scene -ceq $SceneName) 'Actual scene differs'
    if($SceneName -ceq 'ordinary') { return }
    $Side=if($SceneName -ceq 'wave512') {512} elseif($SceneName -ceq 'wave1024') {1024} else {2048}
    $Count=if($SceneName -cin @('wave1024','mixed2048')) {4} else {1}
    Assert-PP ($Receipt.extent[0] -eq $Side -and $Receipt.extent[1] -eq $Side -and
        $Receipt.authored_actor_count -eq $Count -and $Receipt.wave_flow.enabled -eq $true -and
        $Receipt.authored_setup_sha256 -cmatch '^[0-9a-f]{64}$') 'Representative scene/native Wave/actor roster differs'
    if($SceneName -ceq 'mixed2048') {
        $Witness=$Receipt.scene_material_witness
        Assert-PP ($Witness.cell[0] -eq 864 -and $Witness.cell[1] -eq 1944 -and
            $Witness.expected_material -eq 2 -and $Witness.observed_material -eq 2 -and
            $Witness.uploaded_serial -gt 0 -and $Witness.world_generation -eq $Receipt.world_generation) 'Actual published mixed-scene Sand witness differs'
    }
}
function Check-NewLaunch([string]$Label,[scriptblock]$Operation,[string]$SceneName,[string]$ExpectedSource='C') {
    $Log=Join-Path $ProbeOutput ($Label+'.log')
    & $Operation *> $Log
    Assert-PP ($LASTEXITCODE -eq 0) ('Actual installed launcher failed: '+$Log)
    $Runs=Join-Path $ProbeOutput 'Runs'
    $Verified=@(Get-ChildItem -LiteralPath $Runs -Recurse -File -Filter 'verified-startup.json')
    Assert-PP ($Verified.Count -eq $Report.launches.Count+1) 'Expected one fresh verified process receipt per launch'
    $Newest=$Verified|Sort-Object LastWriteTimeUtc|Select-Object -Last 1
    $Ready=Read-PPJson $Newest.FullName
    Assert-Scene $Ready $SceneName
    Assert-PP ($Ready.source_commit -ceq $Manifest.sources.$ExpectedSource.source_commit) 'Actual source role differs'
    $Report.launches.Add(@{label=$Label;scene=$SceneName;source=$ExpectedSource;source_commit=$Ready.source_commit;pid=$Ready.process_id;receipt=$Newest.FullName;
        receipt_sha256=(Get-PPHash $Newest.FullName);engine_sha256=$Ready.engine_sha256;
        render_thread_inline=$Ready.render_thread_inline;material=$Ready.material_publication})
    Test-PPPackage $Extracted $Probe.candidate|Out-Null
}
try {
    $Original=Test-PPPackage $ProbeRoot $Probe.candidate
    $ArchivePath=[IO.Path]::GetFullPath($Probe.archive)
    Assert-PP ([IO.Path]::GetFileName($ArchivePath) -ceq $Original.package_filename) 'Pass the newly built inner evaluator ZIP'
    Assert-PP ((Get-PPHash $ArchivePath) -ceq (Read-PPChecksum ($ArchivePath+'.sha256') $Original.package_filename)) 'Archive sidecar differs'
    $Zip=[IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        Get-PPZipEntries $Zip
        [IO.Directory]::CreateDirectory($Extracted)|Out-Null
        foreach($Entry in $Zip.Entries) {
            if($Entry.FullName.EndsWith('/')) { continue }
            Copy-PPZipEntry $Entry (Join-PPSafe $Extracted $Entry.FullName)
        }
    } finally { $Zip.Dispose() }
    $Manifest=Test-PPPackage $Extracted $Probe.candidate
    Assert-PP ((Get-PPHash (Join-Path $Extracted $script:PPManifestName)) -ceq
        (Get-PPHash (Join-Path $ProbeRoot $script:PPManifestName))) 'Extracted manifest differs from built artifact'
    $Report.checks.Add(@{name='fresh-archive-extraction-and-identical-manifest';passed=$true;archive_sha256=(Get-PPHash $ArchivePath)})
    $PowerShell=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    & $PowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Extracted 'tools/pubpres_playability_windows/Test-ProcessOwner.ps1') -Output (Join-Path $ProbeOutput 'process-owner')
    Assert-PP ($LASTEXITCODE -eq 0) 'Retained actual-Windows process owner tests failed'
    $Report.checks.Add(@{name='creation-time-job-owner-controls';passed=$true})
    $Selected=Get-PFConfiguration 'C' 'Selected'
    Refuses 'frozen-donor-cannot-use-three-slots' { Get-PFSettings 'D' 'stock' 'safe' 3 'opengl3_angle' 'ordinary' 'Fallback' }
    Refuses 'stock-separate-is-not-qualified' { Get-PFSettings 'C' 'stock' 'separate' 2 'opengl3_angle' 'ordinary' 'Fallback' }
    Refuses 'selected-three-slots-is-not-qualified' { Get-PFSettings 'C' $Selected.engine $Selected.render_thread 3 'opengl3_angle' 'ordinary' }
    Refuses 'selected-egl-is-not-qualified' { Get-PFSettings 'C' 'egl' 'safe' 2 'opengl3_angle' 'ordinary' }
    Refuses 'unknown-scene' { Get-PFSettings 'C' 'stock' 'safe' 2 'opengl3_angle' 'made-up' }
    $Native=Join-PPSafe $Extracted $Manifest.sources.C.native.path
    $Stream=[IO.File]::Open($Native,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite)
    try { $Byte=$Stream.ReadByte(); $Stream.Position=0; $Stream.WriteByte([byte]($Byte -bxor 1)) } finally { $Stream.Dispose() }
    try { Refuses 'corrupted-native-refused' { Test-PPPackage $Extracted $Probe.candidate } }
    finally {
        $Stream=[IO.File]::Open($Native,[IO.FileMode]::Open,[IO.FileAccess]::Write)
        try { $Stream.WriteByte([byte]$Byte) } finally { $Stream.Dispose() }
    }
    $Extra=Join-Path $Extracted 'stale-source.txt'
    try { [IO.File]::WriteAllText($Extra,'stale',$script:PPUtf8); Refuses 'stale-extra-file-refused' { Test-PPPackage $Extracted $Probe.candidate } }
    finally { Remove-Item -LiteralPath $Extra }
    $Command=Join-Path $Extracted 'Open Workbench.cmd'
    Check-NewLaunch 'ordinary-open' { & $Command --hosted-smoke } 'ordinary'
    $OwnerRun=@(Get-ChildItem -LiteralPath (Join-Path $ProbeOutput 'Runs') -Directory|Where-Object {$_.Name -like '*-ordinary'})
    Assert-PP ($OwnerRun.Count -eq 1) 'Ordinary persistent profile is not unique'
    $RunPath=$OwnerRun[0].FullName
    $WrongProfile=[pscustomobject]@{profile=(Join-Path $ProbeOutput 'wrong-user-directory');user_directory_policy=[pscustomobject]@{application_name='Cyber Sand Reference Sandbox';use_custom_user_dir=$false}}
    Refuses 'wrong-actual-user-directory-is-refused' { Test-PFReadyProfile $WrongProfile (Join-Path $RunPath 'profile') }
    $Before=Get-PPHash (Join-Path $RunPath 'run.json')
    Check-NewLaunch 'ordinary-reopen' { & $Command --hosted-smoke } 'ordinary'
    Assert-PP ((Get-PPHash (Join-Path $RunPath 'run.json')) -ceq $Before -and
        $Report.launches[0].pid -ne $Report.launches[1].pid) 'Reopen did not preserve one profile and execute a fresh process'
    $RunSource=Join-Path $RunPath 'source/godot/scripts/main.gd'
    $Bytes=[IO.File]::ReadAllBytes($RunSource)
    try {
        [IO.File]::AppendAllText($RunSource,"`n# changed source`n",$script:PPUtf8)
        Refuses 'changed-run-source-refuses-reopen' { Test-PFRun $RunPath $Extracted $Manifest }
    } finally { [IO.File]::WriteAllBytes($RunSource,$Bytes) }
    foreach($Entry in $Manifest.owner_commands.PSObject.Properties) {
        if($Entry.Value -ceq 'ordinary') { continue }
        $SceneCommand=Join-PPSafe $Extracted $Entry.Name
        Check-NewLaunch $Entry.Value { & $SceneCommand --hosted-smoke } $Entry.Value
    }
    $FallbackCommand=Join-PPSafe $Extracted 'Open Stock Safe Fallback.cmd'
    Check-NewLaunch 'stock-safe-fallback-open' { & $FallbackCommand --hosted-smoke } 'ordinary'
    Check-NewLaunch 'stock-safe-fallback-reopen' { & $FallbackCommand --hosted-smoke } 'ordinary'
    $Fallback=@(Get-ChildItem -LiteralPath (Join-Path $ProbeOutput 'Runs') -Directory|Where-Object {$_.Name -like '*-C-stock-safe-slots2-opengl3_angle-Fallback-ordinary'})
    Assert-PP ($Fallback.Count -eq 1 -and $Fallback[0].FullName -cne $RunPath) 'Fallback must retain its own persistent owner profile'
    $FallbackRecord=Test-PFRun $Fallback[0].FullName $Extracted $Manifest
    Assert-PP ($FallbackRecord.settings.CYBERSAND_DIAG_WATER_COMPOSITION -ceq '0' -and
        $FallbackRecord.settings.CYBERSAND_DIAG_ACTUAL_SUBMISSION -ceq '0') 'Fallback enabled a recovery treatment'
    if($Manifest.recovery_selection.experimental_architecture -cne 'none') {
        Refuses 'experimental-cannot-select-stock' { Get-PFSettings 'C' 'stock' 'safe' 2 'opengl3_angle' 'ordinary' 'Experimental' }
        $ExperimentalCommand=Join-PPSafe $Extracted 'Open Bounded Experimental.cmd'
        Check-NewLaunch 'bounded-experimental-open' { & $ExperimentalCommand --hosted-smoke } 'ordinary'
        Check-NewLaunch 'bounded-experimental-reopen' { & $ExperimentalCommand --hosted-smoke } 'ordinary'
        $Experimental=@(Get-ChildItem -LiteralPath (Join-Path $ProbeOutput 'Runs') -Directory|Where-Object {$_.Name -like '*-C-atomic-separate-slots2-opengl3_angle-Experimental-ordinary'})
        Assert-PP ($Experimental.Count -eq 1 -and $Experimental[0].FullName -cne $RunPath) 'Experimental launch must preserve an independent owner profile'
    } else {
        Refuses 'unregistered-experimental-mode-refused' { Get-PFConfiguration 'C' 'Experimental' }
    }
    foreach($Entry in $Manifest.comparison_commands.PSObject.Properties) {
        $SceneCommand=Join-PPSafe $Extracted $Entry.Name
        $SceneName=[string]$Entry.Value.scene
        Check-NewLaunch ($Entry.Value.mode.ToLowerInvariant()+'-'+$SceneName) { & $SceneCommand --hosted-smoke } $SceneName
    }
    $Launcher=Join-PPSafe $Extracted $Manifest.owner_launcher
    if('D' -cin @($Manifest.sources.PSObject.Properties.Name)) {
        $DonorLaunchIndex=$Report.launches.Count
        $DonorCommand=Join-PPSafe $Extracted 'Open Frozen Control.cmd'
        Check-NewLaunch 'donor-ordinary-open' {
            & $DonorCommand --hosted-smoke
        } 'ordinary' 'D'
        $DonorRuns=@(Get-ChildItem -LiteralPath (Join-Path $ProbeOutput 'Runs') -Directory|
            Where-Object {$_.Name -like '*-D-stock-safe-slots2-opengl3_angle-Fallback-ordinary'})
        Assert-PP ($DonorRuns.Count -eq 1) 'Frozen donor must keep its own persistent profile'
        $DonorRecord=Join-Path $DonorRuns[0].FullName 'run.json'
        $DonorBefore=Get-PPHash $DonorRecord
        Check-NewLaunch 'donor-ordinary-reopen' {
            & $DonorCommand --hosted-smoke
        } 'ordinary' 'D'
        Assert-PP ((Get-PPHash $DonorRecord) -ceq $DonorBefore -and
            $Report.launches[$DonorLaunchIndex].pid -ne $Report.launches[$DonorLaunchIndex+1].pid) 'Donor reopen did not preserve its profile and execute a fresh process'
        $Report.checks.Add(@{name='frozen-donor-real-startup-and-reopen';passed=$true;source_commit=$Manifest.sources.D.source_commit})
    }
    $Collector=Join-Path $Extracted 'Collect Results.cmd'
    & $Collector --hosted-smoke *> (Join-Path $ProbeOutput 'collector.log')
    Assert-PP ($LASTEXITCODE -eq 0) 'Shipped collector command failed'
    $Reports=@(Get-ChildItem -LiteralPath (Join-Path $ProbeOutput 'Runs/Reports') -File -Filter '*.zip')
    Assert-PP ($Reports.Count -eq 1) 'Expected one new collected evidence archive'
    $Collected=$Reports[0].FullName
    Assert-PP ((Get-PPHash $Collected) -ceq (Read-PPChecksum ($Collected+'.sha256') $Reports[0].Name)) 'Collector checksum differs'
    $Bundle=[IO.Compression.ZipFile]::OpenRead($Collected)
    try {
        Get-PPZipEntries $Bundle
        $Reader=[IO.StreamReader]::new($Bundle.GetEntry('INDEX.json').Open())
        try { $Index=$Reader.ReadToEnd()|ConvertFrom-Json } finally { $Reader.Dispose() }
        Assert-PP ($Index.candidate_commit -ceq $Probe.candidate -and $Index.package_manifest_sha256 -ceq
            (Get-PPHash (Join-Path $Extracted $script:PPManifestName)) -and @($Index.matched_runs).Count -ge 5 -and
            @($Index.omitted).Count -eq 0 -and @($Index.files).Count -gt 0) 'Collector did not capture exact closed-profile evidence'
        foreach($Entry in $Index.files) {
            $Member=$Bundle.GetEntry($Entry.file)
            Assert-PP ($null -ne $Member -and $Member.Length -eq $Entry.bytes -and $Entry.file -notmatch '\.(exe|dll)$') 'Collected inventory includes a missing file or runtime binary'
            $Stream=$Member.Open(); $Hash=[Security.Cryptography.SHA256]::Create()
            try { $Actual=([BitConverter]::ToString($Hash.ComputeHash($Stream))).Replace('-','').ToLowerInvariant() }
            finally { $Hash.Dispose(); $Stream.Dispose() }
            Assert-PP ($Actual -ceq $Entry.sha256) 'Collected evidence bytes differ from index'
        }
    } finally { $Bundle.Dispose() }
    $Report.checks.Add(@{name='actual-shipped-collector-and-index';passed=$true;archive=$Collected;sha256=(Get-PPHash $Collected)})
    Test-PPPackage $Extracted $Probe.candidate|Out-Null
    Test-PPPackage $ProbeRoot $Probe.candidate|Out-Null
    $Report.complete=$true
} catch { $Report.failure=$_.Exception.Message }
finally { Write-PPJson (Join-Path $ProbeOutput 'SUMMARY.json') $Report }
Assert-PP $Report.complete ('Extracted evaluator qualification failed: '+$Report.failure)
