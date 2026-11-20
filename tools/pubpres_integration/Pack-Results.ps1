[CmdletBinding()]
param([string]$RunDirectory = '', [switch]$All)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Results = Join-Path $Root 'Test-It-Results'
if ($All -and $RunDirectory) { throw 'Select all captured runs or one run directory.' }
$Captured = @(Get-ChildItem -LiteralPath $Results -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'summary.json') -PathType Leaf } |
    Sort-Object -Property Name)
if ($All) {
    if ($Captured.Count -eq 0) { throw 'No captured results are available.' }
    $Selected = @($Captured | ForEach-Object { $_.FullName })
    $Stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $ArchivePath = Join-Path $Results ('All-Results-'+$Stamp+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)+'.zip')
} else {
    if (-not $RunDirectory) {
        if ($Captured.Count -eq 0) { throw 'No captured result is available.' }
        $RunDirectory = $Captured[-1].FullName
    }
    $RunDirectory = [IO.Path]::GetFullPath($RunDirectory)
    if (-not $RunDirectory.StartsWith($Results+'\',[StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath (Join-Path $RunDirectory 'summary.json') -PathType Leaf)) {
        throw 'Select a captured run beneath the installed Test-It-Results directory.'
    }
    $Selected = @($RunDirectory)
    $ArchivePath = $RunDirectory+'.zip'
    if (Test-Path -LiteralPath $ArchivePath) {
        $ArchivePath = $RunDirectory+'-return-'+[Guid]::NewGuid().ToString('N').Substring(0,8)+'.zip'
    }
}
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
# The final name is a completion marker for evidence retention. Failed writes
# must leave no final .zip that could cause original run files to be skipped.
$TemporaryPath = $ArchivePath+'.partial-'+[Guid]::NewGuid().ToString('N')
$Archive = [IO.Compression.ZipFile]::Open($TemporaryPath,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($Directory in $Selected) {
        $Prefix = if ($All) { 'runs/'+[IO.Path]::GetFileName($Directory)+'/' } else { '' }
        foreach ($File in Get-ChildItem -LiteralPath $Directory -Recurse -File) {
            $Relative = $File.FullName.Substring($Directory.Length+1).Replace('\','/')
            if ($Relative -match '(^|/)profile(/|$)|^project/') { continue }
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,$File.FullName,($Prefix+$Relative),[IO.Compression.CompressionLevel]::Optimal)
        }
    }
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,(Join-Path $Root 'ACCEPTANCE.md'),'ACCEPTANCE.md',[IO.Compression.CompressionLevel]::Optimal)
    if ($All) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,(Join-Path $Root 'PUBPRES-MANIFEST.json'),'CURRENT-PACKAGE-MANIFEST.json',[IO.Compression.CompressionLevel]::Optimal)
        $Entry = $Archive.CreateEntry('COLLECTION.json')
        $Writer = [IO.StreamWriter]::new($Entry.Open(),[Text.UTF8Encoding]::new($false))
        try {
            $Writer.Write(([ordered]@{schema='pubpres-local-results-collection-v1'; physical_acceptance='HOLD';
                runs=@($Selected | ForEach-Object { [IO.Path]::GetFileName($_) });
                scope='All captured run directories with summaries, including failed runs; original logs, receipts and pixel captures. Transient application projects and profiles excluded.'} | ConvertTo-Json -Depth 5))
        } finally { $Writer.Dispose() }
    }
} finally { $Archive.Dispose() }
[IO.File]::Move($TemporaryPath,$ArchivePath)
Write-Host "Results ZIP: $ArchivePath"
