[CmdletBinding()]
param([string]$RunDirectory = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Results = Join-Path $Root 'Test-It-Results'
if (-not $RunDirectory) {
    $Latest = Get-ChildItem -LiteralPath $Results -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'summary.json') -PathType Leaf } |
        Sort-Object -Property Name -Descending | Select-Object -First 1
    if ($null -eq $Latest) { throw 'No Test It result is available.' }
    $RunDirectory = $Latest.FullName
}
$RunDirectory = [IO.Path]::GetFullPath($RunDirectory)
if (-not $RunDirectory.StartsWith($Results+'\',[StringComparison]::OrdinalIgnoreCase) -or
    -not (Test-Path -LiteralPath (Join-Path $RunDirectory 'summary.json') -PathType Leaf)) {
    throw 'Select a captured run beneath the installed Test-It-Results directory.'
}
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$ArchivePath = $RunDirectory + '.zip'
if (Test-Path -LiteralPath $ArchivePath) {
    $ArchivePath = $RunDirectory + '-return-' + [Guid]::NewGuid().ToString('N').Substring(0,8) + '.zip'
}
$Archive = [IO.Compression.ZipFile]::Open($ArchivePath,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($File in Get-ChildItem -LiteralPath $RunDirectory -Recurse -File) {
        $Relative = $File.FullName.Substring($RunDirectory.Length+1).Replace('\','/')
        if ($Relative -match '(^|/)profile(/|$)|^project/') { continue }
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,$File.FullName,$Relative,[IO.Compression.CompressionLevel]::Optimal)
    }
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,(Join-Path $Root 'ACCEPTANCE.md'),'ACCEPTANCE.md',[IO.Compression.CompressionLevel]::Optimal)
} finally { $Archive.Dispose() }
Write-Host "Results ZIP: $ArchivePath"
