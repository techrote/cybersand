[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Read-Results.ps1')
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Manifest = Read-Json (Join-Path $Root 'PUBPRES-MANIFEST.json')
Assert-Result ($Manifest.schema -eq 'pubpres-integration-windows-v1') 'Unknown package manifest'
foreach ($Entry in $Manifest.files_sha256.PSObject.Properties) {
    Assert-Result ($Entry.Name -notmatch '(^|/)\.\.(/|$)|\\|:|^/') ('Invalid payload path: ' + $Entry.Name)
    $File = Join-Path $Root $Entry.Name
    Assert-Result ((Test-Path -LiteralPath $File -PathType Leaf) -and (Get-Sha $File) -eq $Entry.Value) ('Missing or changed payload: ' + $Entry.Name)
}
Write-Host ('Verified ' + @($Manifest.files_sha256.PSObject.Properties).Count + ' payload files.')
Write-Host ('Candidate source: ' + $Manifest.source_commit)
Write-Host ('Accepted main: ' + $Manifest.source_references.main.source_commit)
Write-Host ('Previous integration: ' + $Manifest.source_references.integration.source_commit)
Write-Host 'Physical Windows/NVIDIA acceptance remains HOLD.'
