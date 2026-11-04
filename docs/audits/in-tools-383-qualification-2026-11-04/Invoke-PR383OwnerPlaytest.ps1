# Run from a real Windows x64 PowerShell session. All physical/manual rows remain
# UNTESTED until the operator performs and records windows-owner-playtest.md.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$GodotExecutable,
    [Parameter(Mandatory = $true)][string]$GodotArchive,
    [Parameter(Mandatory = $true)][string]$EvidenceDirectory
)
$ErrorActionPreference = 'Stop'
$ExpectedSource = '73b10f9b800e72f358f22f470e57a4531002c168'
$PreviousDirectory = Get-Location
try {
    if ($env:OS -ne 'Windows_NT') { throw 'This procedure requires actual Windows execution.' }
    if (Test-Path -LiteralPath $EvidenceDirectory) { throw 'Choose a new evidence directory; preserve every earlier attempt.' }
    Set-Location -LiteralPath $Repository
    & python 'tools/play/create_manual_packet.py' --expected-sha $ExpectedSource `
        --godot $GodotExecutable --godot-archive $GodotArchive --output $EvidenceDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Source/runtime preflight failed. Retain the error; do not bypass the gate.' }
    Write-Host 'Preflight passed. Physical input and displayed behavior are still UNTESTED.'
    Write-Host 'Perform windows-owner-playtest.md in the existing PLAY/F5 application route and retain its evidence.'
    & (Join-Path $EvidenceDirectory 'launch.ps1')
} finally {
    Set-Location -LiteralPath $PreviousDirectory.Path
}
