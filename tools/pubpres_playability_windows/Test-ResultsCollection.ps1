[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedCandidate,
    [Parameter(Mandatory=$true)][string]$Output
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Probe = @{Root=[IO.Path]::GetFullPath($PackageRoot);Candidate=$ExpectedCandidate;Output=[IO.Path]::GetFullPath($Output)}
. (Join-Path $PSScriptRoot 'Start-PUBPRES-Playability.ps1') -Library
Assert-PP (-not (Test-Path -LiteralPath $Probe.Output) -and
    -not $Probe.Output.StartsWith($Probe.Root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Use new evidence storage outside the extracted payload'
[void][IO.Directory]::CreateDirectory($Probe.Output)
$Manifest = Read-PPJson (Join-Path $Probe.Root $script:PPManifestName)
$ManifestHash = Get-PPHash (Join-Path $Probe.Root $script:PPManifestName)
$Runs = Join-Path ([IO.Path]::GetDirectoryName($Probe.Root)) 'Runs'
$Reports = Join-Path $Runs 'Reports'
$Profile = 'Workbench-'+$Probe.Candidate.Substring(0,12)+'-'+$ManifestHash.Substring(0,12)+'-opengl3_angle'
$RunState = Join-Path (Join-Path $Runs $Profile) 'run.json'
$RunHash = Get-PPHash $RunState
$Command = Join-PPSafe $Probe.Root $Manifest.owner_results_command
& $Command --hosted-smoke *> (Join-Path $Probe.Output 'collector.log')
Assert-PP ($LASTEXITCODE -eq 0) 'The shipped result collection command failed'
$Bundles = @(Get-ChildItem -LiteralPath $Reports -File -Filter 'PUBPRES-Owner-*.zip')
Assert-PP ($Bundles.Count -eq 1) 'Expected exactly one fresh owner results ZIP'
$Bundle = $Bundles[0]
$SHA = Get-PPHash $Bundle.FullName
Assert-PP ([IO.File]::ReadAllText($Bundle.FullName+'.sha256') -ceq ($SHA+'  '+$Bundle.Name+"`n")) 'Owner result archive checksum differs'
$Zip = [IO.Compression.ZipFile]::OpenRead($Bundle.FullName)
try {
    $Reader = [IO.StreamReader]::new($Zip.GetEntry('INDEX.json').Open())
    try { $Index = $Reader.ReadToEnd() | ConvertFrom-Json } finally { $Reader.Dispose() }
    Assert-PP ($Index.schema -ceq 'pubpres-owner-results-v1' -and $Index.physical_acceptance -ceq 'HOLD' -and
        $Index.candidate_commit -ceq $Probe.Candidate -and $Index.package_manifest_sha256 -ceq $ManifestHash -and
        $Index.matched_runs -ccontains $Profile -and @($Index.omitted).Count -eq 0) 'Owner result bundle differs from the exact installed run'
    $EntryCount = $Zip.Entries.Count
    Assert-PP ($EntryCount -eq (@($Index.files).Count+1)) 'Owner result ZIP inventory differs'
    $Names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($Record in $Index.files) {
            $Entry = $Zip.GetEntry($Record.file)
            Assert-PP ($Names.Add($Record.file) -and $null -ne $Entry -and $Entry.Length -eq $Record.bytes) 'Owner result file inventory is incomplete'
            $Stream = $Entry.Open()
            try { $Hash = ([BitConverter]::ToString($Hasher.ComputeHash($Stream))).Replace('-','').ToLowerInvariant() }
            finally { $Stream.Dispose() }
            Assert-PP ($Hash -ceq $Record.sha256) 'Owner result file hash differs'
        }
    } finally { $Hasher.Dispose() }
    $StartupPrefix = 'runs/'+$Profile+'/launches/'
    $Startups = @($Index.files | Where-Object { $_.file.StartsWith($StartupPrefix) -and $_.file.EndsWith('/verified-startup.json') })
    $IndexedRun = @($Index.files | Where-Object { $_.file -ceq ('runs/'+$Profile+'/run.json') })
    Assert-PP ($Startups.Count -eq 2 -and $IndexedRun.Count -eq 1 -and $IndexedRun[0].sha256 -ceq $RunHash -and
        (Get-PPHash $RunState) -ceq $RunHash) 'Owner collection lost a fresh launch receipt or changed the original run'
} finally { $Zip.Dispose() }
Test-PPPackage $Probe.Root $Probe.Candidate | Out-Null
Copy-Item -LiteralPath @($Bundle.FullName,($Bundle.FullName+'.sha256')) -Destination $Probe.Output
Write-PPJson (Join-Path $Probe.Output 'SUMMARY.json') ([ordered]@{schema='pubpres-owner-results-smoke-v1';complete=$true;
    candidate_commit=$Probe.Candidate;package_manifest_sha256=$ManifestHash;owner_archive_sha256=$SHA;owner_archive_file=$Bundle.Name;
    owner_archive_entries=$EntryCount;verified_startup_receipts=$Startups.Count;physical_acceptance='HOLD'})
