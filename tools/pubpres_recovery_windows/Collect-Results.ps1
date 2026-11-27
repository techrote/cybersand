[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedCandidate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot).TrimEnd([char[]]'\/')
$Verifier = Join-Path $PackageRoot 'tools/pubpres_recovery_windows/Start-PUBPRES-Final.ps1'
. $Verifier -Library -PackageRoot $PackageRoot -ExpectedCandidate $ExpectedCandidate
$Manifest = Test-PPPackage $PackageRoot $ExpectedCandidate
Assert-PP ($Manifest.schema -cin @('pubpres-playability-recovery-windows-v1','pubpres-local-owner-retest-v1')) 'Collection requires a verified evaluator package'
$ManifestHash = Get-PPHash (Join-Path $PackageRoot $script:PPManifestName)
$Runs = Join-Path ([IO.Path]::GetDirectoryName($PackageRoot)) 'Runs'
Assert-PP (Test-Path -LiteralPath $Runs -PathType Container) 'Open Workbench first; no Runs directory exists'
Assert-PP (((Get-Item -LiteralPath $Runs).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Runs cannot be a reparse point'
$Reports = Join-Path $Runs 'Reports'
if (Test-Path -LiteralPath $Reports) {
    Assert-PP (((Get-Item -LiteralPath $Reports).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reports cannot be a reparse point'
} else { [IO.Directory]::CreateDirectory($Reports) | Out-Null }
$Name = 'PUBPRES-Owner-'+$ExpectedCandidate.Substring(0,12)+'-'+(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$ZipPath = Join-Path $Reports ($Name+'.zip')
$FileLimit = 16MB
$TotalLimit = 128MB
$CountLimit = 512
$EntryLimit = 8192
$script:CollectedBytes = [long]0
$script:Collected = New-Object 'System.Collections.Generic.List[object]'
$script:Omitted = New-Object 'System.Collections.Generic.List[object]'
$script:Visited = 0
$script:VisitedEntries = 0
$script:TraversalStopped = $false
$script:MatchedRuns = New-Object 'System.Collections.Generic.List[string]'
$script:Seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

function Enter-ResultEntry {
    if ($script:TraversalStopped) { return $false }
    $script:VisitedEntries += 1
    if ($script:VisitedEntries -gt $EntryLimit) {
        $script:TraversalStopped = $true
        $script:Omitted.Add(@{file='unvisited entries';reason='global directory-entry capacity; remaining paths were not enumerated'})
        return $false
    }
    return $true
}

function Read-ResultBytes([string]$Path,[long]$Limit,[string]$ArchiveName) {
    # Bound allocation even if a live producer grows the file after the first
    # metadata check. On Windows this sharing mode also refuses active writers.
    $ReadStream = $null
    try {
        $Item = Get-Item -LiteralPath $Path
        if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $Item.PSIsContainer) {
            $script:Omitted.Add(@{file=$ArchiveName;reason='reparse point or non-file'})
            return $null
        }
        if ($Item.Length -gt $Limit) {
            $script:Omitted.Add(@{file=$ArchiveName;bytes=$Item.Length;reason='bounded collection capacity'})
            return $null
        }
        $Length = $Item.Length
        $Written = $Item.LastWriteTimeUtc
        $ReadStream = [IO.File]::Open($Item.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        if ($ReadStream.Length -ne $Length) {
            $script:Omitted.Add(@{file=$ArchiveName;reason='file changed before collecting; close Workbench and retry'})
            return $null
        }
        $Bytes = [byte[]]::new([int]$Length)
        $Offset = 0
        while ($Offset -lt $Bytes.Length) {
            $Read = $ReadStream.Read($Bytes,$Offset,$Bytes.Length-$Offset)
            if ($Read -eq 0) { break }
            $Offset += $Read
        }
        $After = Get-Item -LiteralPath $Item.FullName
        if ($Offset -ne $Length -or $ReadStream.Length -ne $Length -or $After.Length -ne $Length -or $After.LastWriteTimeUtc -ne $Written) {
            $script:Omitted.Add(@{file=$ArchiveName;reason='file changed while reading; close Workbench and retry'})
            return $null
        }
        # Do not enumerate a byte array through the PowerShell output pipeline.
        return ,$Bytes
    } catch {
        $script:Omitted.Add(@{file=$ArchiveName;reason='file unavailable or in use; close Workbench and retry'})
        return $null
    } finally { if ($null -ne $ReadStream) { $ReadStream.Dispose() } }
}

function Add-ResultFile([string]$Path,[string]$ArchiveName,[byte[]]$CapturedBytes=$null) {
    if ($script:Collected.Count -ge $CountLimit) {
        $script:Omitted.Add(@{file=$ArchiveName;reason='bounded collection count'})
        return
    }
    Assert-PP ($ArchiveName -notmatch '(^/|\\|(^|/)\.\.(/|$))' -and $script:Seen.Add($ArchiveName)) 'Invalid or repeated result path'
    $Capacity = [Math]::Min($FileLimit,$TotalLimit-$script:CollectedBytes)
    $Bytes = $CapturedBytes
    if ($null -eq $Bytes) { $Bytes = Read-ResultBytes $Path $Capacity $ArchiveName }
    if ($null -eq $Bytes) { return }
    if ($Bytes.LongLength -gt $Capacity) {
        $script:Omitted.Add(@{file=$ArchiveName;bytes=$Bytes.LongLength;reason='bounded collection capacity'})
        return
    }
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try { $Hash = ([BitConverter]::ToString($Hasher.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $Hasher.Dispose() }
    $Entry = $script:Archive.CreateEntry($ArchiveName,[IO.Compression.CompressionLevel]::Optimal)
    $Stream = $Entry.Open()
    try { $Stream.Write($Bytes,0,$Bytes.Length) } finally { $Stream.Dispose() }
    $script:CollectedBytes += $Bytes.LongLength
    $script:Collected.Add(@{file=$ArchiveName;bytes=$Bytes.LongLength;sha256=$Hash})
}

function Add-ResultTree([string]$Root,[string]$Prefix,[bool]$ProfileOnly) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return }
    $Queue = New-Object 'System.Collections.Generic.Queue[object]'
    $Queue.Enqueue(@{path=$Root;relative='';depth=0})
    while ($Queue.Count -gt 0 -and -not $script:TraversalStopped) {
        $Directory = $Queue.Dequeue()
        $script:Visited += 1
        if ($script:Visited -gt 4096 -or $Directory.depth -gt 12) {
            $script:Omitted.Add(@{file=$Prefix+$Directory.relative;reason='directory traversal capacity'})
            return
        }
        if (((Get-Item -LiteralPath $Directory.path).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $script:Omitted.Add(@{file=$Prefix+$Directory.relative;reason='reparse directory'})
            continue
        }
        # Enumerate lazily: sorting Get-ChildItem would first allocate an
        # unbounded list for a large directory, before applying our limits.
        foreach ($Item in [IO.DirectoryInfo]::new($Directory.path).EnumerateFileSystemInfos()) {
            if (-not (Enter-ResultEntry)) { break }
            $Relative = $Directory.relative+$Item.Name
            if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $script:Omitted.Add(@{file=$Prefix+$Relative;reason='reparse point'})
                continue
            }
            if (($Item.Attributes -band [IO.FileAttributes]::Directory) -ne 0) {
                if ($Item.Name -notin @('.godot','cache','Cache','Caches','art-traffic')) {
                    $Queue.Enqueue(@{path=$Item.FullName;relative=$Relative+'/';depth=$Directory.depth+1})
                }
            } elseif (-not $ProfileOnly -or $Item.Name -like 'engine-lab-*' -or $Relative -match '(^|/)(logs|workbench)/') {
                Add-ResultFile $Item.FullName ($Prefix+$Relative)
            }
        }
    }
}

$Hardware=[ordered]@{schema='pubpres-owner-hardware-v1';collected_utc=(Get-Date).ToUniversalTime().ToString('o');
    os=$null;processors=@();video_controllers=@();errors=@();
    scope='Windows CIM readback at collection time. Startup receipts identify each actual renderer; monitor values may be unavailable or stale. No physical scanout, input latency or gameplay acceptance is inferred.'}
try { $Hardware.os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 5 | Select-Object Caption,Version,BuildNumber,OSArchitecture }
catch { $Hardware.errors+=('OS readback: '+$_.Exception.Message) }
try { $Hardware.processors=@(Get-CimInstance Win32_Processor -OperationTimeoutSec 5 | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors) }
catch { $Hardware.errors+=('CPU readback: '+$_.Exception.Message) }
try { $Hardware.video_controllers=@(Get-CimInstance Win32_VideoController -OperationTimeoutSec 5 |
    Select-Object Name,DriverVersion,DriverDate,VideoProcessor,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate) }
catch { $Hardware.errors+=('Graphics readback: '+$_.Exception.Message) }
$HardwarePath=Join-Path $Reports ($Name+'-hardware.json')
Write-PPJson $HardwarePath $Hardware
$script:Archive = [IO.Compression.ZipFile]::Open($ZipPath,[IO.Compression.ZipArchiveMode]::Create)
try {
    Add-ResultFile (Join-Path $PackageRoot $script:PPManifestName) $script:PPManifestName
    Add-ResultFile $HardwarePath 'hardware.json'
    Add-ResultFile (Join-Path $PackageRoot 'tools/pubpres_recovery_windows/selection.json') 'selection.json'
    foreach ($Run in [IO.DirectoryInfo]::new($Runs).EnumerateFileSystemInfos()) {
        if (-not (Enter-ResultEntry)) { break }
        if (($Run.Attributes -band [IO.FileAttributes]::Directory) -eq 0 -or $Run.Name -in @('Reports','Screenshots') -or
            ($Run.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        $RecordPath = Join-Path $Run.FullName 'run.json'
        if (-not (Test-Path -LiteralPath $RecordPath -PathType Leaf)) { continue }
        $RecordBytes = Read-ResultBytes $RecordPath 8MB ('runs/'+$Run.Name+'/run.json')
        if ($null -eq $RecordBytes) { continue }
        try { $Record = $script:PPUtf8.GetString($RecordBytes) | ConvertFrom-Json }
        catch {
            $script:Omitted.Add(@{file='runs/'+$Run.Name+'/run.json';reason='invalid run JSON; matching identity cannot be verified'})
            continue
        }
        if ((Get-PPField $Record 'candidate_commit') -cne $ExpectedCandidate -or (Get-PPField $Record 'package_manifest_sha256') -cne $ManifestHash) { continue }
        $script:MatchedRuns.Add($Run.Name)
        $Prefix = 'runs/'+$Run.Name+'/'
        # Archive the same stable bytes whose identity we admitted, avoiding a
        # second read that could select a different concurrently replaced run.
        Add-ResultFile $RecordPath ($Prefix+'run.json') $RecordBytes
        foreach ($Ready in $Run.EnumerateFileSystemInfos()) {
            if (-not (Enter-ResultEntry)) { break }
            if (($Ready.Attributes -band [IO.FileAttributes]::Directory) -eq 0 -and $Ready.Name -like 'ready-*.json') {
                Add-ResultFile $Ready.FullName ($Prefix+$Ready.Name)
            }
        }
        Add-ResultTree (Join-Path $Run.FullName 'launches') ($Prefix+'launches/') $false
        Add-ResultTree (Join-Path $Run.FullName 'profile') ($Prefix+'profile/') $true
    }
    $Notes = Join-Path $Runs 'OWNER-ACCEPTANCE.md'
    if (Test-Path -LiteralPath $Notes -PathType Leaf) { Add-ResultFile $Notes 'OWNER-ACCEPTANCE.md' }
    Add-ResultTree (Join-Path $Runs 'Screenshots') 'screenshots/' $false
    $Index = [ordered]@{schema='pubpres-owner-results-v1';candidate_commit=$ExpectedCandidate;package_manifest_sha256=$ManifestHash;
        collected_utc=(Get-Date).ToUniversalTime().ToString('o');physical_acceptance='HOLD';matched_runs=@($script:MatchedRuns.ToArray());
        file_limit_bytes=$FileLimit;total_limit_bytes=$TotalLimit;count_limit=$CountLimit;entry_limit=$EntryLimit;
        visited_entries=[Math]::Min($script:VisitedEntries,$EntryLimit);total_bytes=$script:CollectedBytes;
        files=@($script:Collected.ToArray());omitted=@($script:Omitted.ToArray());
        scope='Collected owner evidence; no automatic gameplay acceptance. Original profiles, authored starts and package remain unchanged.'}
    $Entry = $script:Archive.CreateEntry('INDEX.json',[IO.Compression.CompressionLevel]::Optimal)
    $Writer = [IO.StreamWriter]::new($Entry.Open(),$script:PPUtf8)
    try { $Writer.WriteLine(($Index | ConvertTo-Json -Depth 12)) } finally { $Writer.Dispose() }
} finally { $script:Archive.Dispose() }
$Hash = Get-PPHash $ZipPath
[IO.File]::WriteAllText($ZipPath+'.sha256',$Hash+'  '+[IO.Path]::GetFileName($ZipPath)+"`n",$script:PPUtf8)
Write-Host ('Collected '+$script:Collected.Count+' files from '+$script:MatchedRuns.Count+' matching runs: '+$ZipPath)
Write-Host ('SHA-256 '+$Hash)
if ($script:Omitted.Count -gt 0) { Write-Warning ('Partial collection: '+$script:Omitted.Count+' entries omitted; see INDEX.json. Original files remain in place.') }
if ($script:MatchedRuns.Count -eq 0) { Write-Warning 'No launch belongs to this exact package. This archive does not demonstrate that Workbench ran.' }
