[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedCandidate,
    [ValidateSet('New','Reopen','Evidence')][string]$Action = 'New',
    [ValidateSet('Candidate','FrozenBaseline')][string]$Source = 'Candidate',
    [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver = 'opengl3',
    [switch]$QuitAfterReady
)

# Thin owner convenience surface; the same strict launcher remains authority.
$OwnerInputs = @{Root=$PackageRoot;Candidate=$ExpectedCandidate;Action=$Action;Source=$Source;
    Driver=$RenderingDriver;Quit=$QuitAfterReady.IsPresent}
$OwnerLauncher = Join-Path $PSScriptRoot 'Start-PUBPRES-Playability.ps1'
. $OwnerLauncher -Library
$OwnerRoot = [IO.Path]::GetFullPath($OwnerInputs.Root)
$OwnerManifest = Test-PPPackage $OwnerRoot $OwnerInputs.Candidate
Assert-PP ($OwnerManifest.schema -ceq 'pubpres-playability-windows-v3') 'One-click F/C gameplay requires the explicit v3 package'
$OwnerParent = [IO.Path]::GetDirectoryName($OwnerRoot.TrimEnd([char[]]'\/'))
$OwnerSessions = Join-Path $OwnerParent 'OwnerSessions'
[IO.Directory]::CreateDirectory($OwnerSessions) | Out-Null
$OwnerKey = if ($OwnerInputs.Source -ceq 'Candidate') { 'C' } else { 'F' }
$OwnerState = Join-Path $OwnerSessions ($OwnerKey+'-'+$OwnerInputs.Candidate.Substring(0,12)+'.json')

function Read-OwnerRun([string]$StatePath,[string]$RequiredKey) {
    $State = Read-PPJson $StatePath
    Assert-PP ($State.candidate_commit -ceq $OwnerInputs.Candidate -and $State.source -ceq $RequiredKey) 'Saved launcher session identifies another source'
    $Run = [IO.Path]::GetFullPath($State.run)
    $RunsRoot = [IO.Path]::GetFullPath((Join-Path $OwnerParent 'Runs'))
    Assert-PP ([IO.Path]::GetDirectoryName($Run) -ceq $RunsRoot) 'Saved session escaped the package run directory'
    $Record = Test-PPRun $Run $OwnerRoot $OwnerManifest
    Assert-PP ($Record.source -ceq $RequiredKey -and $Record.scenario -ceq 'wave2048') 'Saved launcher session is not the selected Wave2048 run'
    return $Run
}

function Lock-OwnerRun([string]$Run) {
    try { return [IO.File]::Open((Join-Path $Run 'owner-session.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch { throw 'This owner session is already open. Close its Workbench before reopening or packing evidence.' }
}

if ($OwnerInputs.Action -ceq 'Evidence') {
    $EvidenceName = 'PUBPRES003-evidence-'+(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $EvidenceRoot = Join-Path $OwnerParent $EvidenceName
    [IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null
    $EvidenceRuns = [Collections.Generic.List[object]]::new()
    foreach ($Key in @('F','C')) {
        $StatePath = Join-Path $OwnerSessions ($Key+'-'+$OwnerInputs.Candidate.Substring(0,12)+'.json')
        if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { continue }
        $Run = Read-OwnerRun $StatePath $Key
        $Lock = Lock-OwnerRun $Run
        try {
            $Destination = Join-Path $EvidenceRoot $Key
            [IO.Directory]::CreateDirectory($Destination) | Out-Null
            foreach ($Directory in @('launches','profile')) {
                $Path = Join-Path $Run $Directory
                if (Test-Path -LiteralPath $Path) {
                    Get-PPFiles $Path | Out-Null
                    Copy-Item -LiteralPath $Path -Destination $Destination -Recurse
                }
            }
            foreach ($File in Get-ChildItem -LiteralPath $Run -File) {
                if ($File.Name -eq 'run.json' -or $File.Name -like 'ready-*.json' -or $File.Name -like 'ready-*.png') {
                    Copy-Item -LiteralPath $File.FullName -Destination $Destination
                }
            }
            Copy-Item -LiteralPath $StatePath -Destination (Join-Path $Destination 'owner-session.json')
            $Provenance = Join-PPSafe $OwnerRoot ($OwnerManifest.sources.$Key.root+'/provenance')
            Copy-Item -LiteralPath $Provenance -Destination (Join-Path $Destination 'native-provenance') -Recurse
            $EvidenceRuns.Add([ordered]@{source=$Key;source_commit=$OwnerManifest.sources.$Key.source_commit;run=$Run})
        } finally { $Lock.Dispose() }
    }
    Assert-PP ($EvidenceRuns.Count -gt 0) 'No owner gameplay sessions exist for this candidate yet'
    foreach ($Name in @($script:PPManifestName,($script:PPManifestName+'.sha256'),'READ-ME.md')) {
        Copy-Item -LiteralPath (Join-Path $OwnerRoot $Name) -Destination $EvidenceRoot
    }
    $Adapters = @()
    try { $Adapters = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,PNPDeviceID,AdapterRAM) }
    catch { $Adapters = @([ordered]@{enumeration_error=$_.Exception.Message}) }
    $Inventory = [ordered]@{}
    foreach ($File in Get-PPFiles $EvidenceRoot) {
        $Relative = $File.FullName.Substring($EvidenceRoot.Length+1).Replace('\','/')
        $Inventory[$Relative] = Get-PPHash $File.FullName
    }
    Write-PPJson (Join-Path $EvidenceRoot 'EVIDENCE.json') ([ordered]@{schema='pubpres003-owner-evidence-v1';
        candidate_commit=$OwnerInputs.Candidate;package_manifest_sha256=Get-PPHash (Join-Path $OwnerRoot $script:PPManifestName);
        sessions=$EvidenceRuns.ToArray();video_controllers=$Adapters;files_sha256=$Inventory;
        scope='Actual source/runtime manifests, owner process logs, startup framebuffers and isolated authored profiles. Adapter inventory alone does not establish playable NVIDIA acceptance.'})
    $EvidenceArchive = $EvidenceRoot+'.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($EvidenceRoot,$EvidenceArchive,[IO.Compression.CompressionLevel]::Optimal,$true)
    [IO.File]::WriteAllText($EvidenceArchive+'.sha256',(Get-PPHash $EvidenceArchive)+'  '+[IO.Path]::GetFileName($EvidenceArchive)+"`n",$script:PPUtf8)
    Write-Host ('Owner evidence: '+$EvidenceArchive)
    return
}

if ($OwnerInputs.Action -ceq 'New') {
    $OwnerRun = New-PPRun $OwnerRoot $OwnerManifest $OwnerKey 'eager' 'safe' $OwnerInputs.Driver 'off' 'wave2048'
} else {
    Assert-PP (Test-Path -LiteralPath $OwnerState -PathType Leaf) 'No saved launcher session exists; use Play first'
    $OwnerRun = Read-OwnerRun $OwnerState $OwnerKey
}
$OwnerLock = Lock-OwnerRun $OwnerRun
try {
    Write-PPJson $OwnerState ([ordered]@{schema='pubpres003-owner-session-v1';candidate_commit=$OwnerInputs.Candidate;
        source=$OwnerKey;source_commit=$OwnerManifest.sources.$OwnerKey.source_commit;run=$OwnerRun})
    Write-Host 'Preparing the active Wave2048 scene. Native generation and terrain preparation may take a moment.'
    Write-Host 'Use ordinary pilot input, Paint, Pause/Play and Save start. Keep save name pubpres003-wave2048 for one-click reopen.'
    & $OwnerLauncher -PackageRoot $OwnerRoot -ExpectedCandidate $OwnerInputs.Candidate -Action Open `
        -ReopenRun $OwnerRun -QuitAfterReady:$OwnerInputs.Quit
} finally { $OwnerLock.Dispose() }
