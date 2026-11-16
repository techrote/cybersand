[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Cases, [string]$NegativeReceipt='')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Validate-Health.ps1')
$checks = 0
foreach ($case in (Get-Content -LiteralPath $Cases -Raw | ConvertFrom-Json)) {
    $accepted = $true
    try {
        if ($case.PSObject.Properties.Name -contains 'expected_case') {
            $expected = @{}
            foreach ($property in $case.expected_case.PSObject.Properties) { $expected[$property.Name]=$property.Value }
            Assert-RenderUploadRequestedCase $case.receipt $expected $case.expected_strategy
        }
        Assert-RenderUploadHealth $case.receipt
    } catch { $accepted = $false }
    if ($accepted -ne $case.accepted) { throw ('Health validator misclassified: '+$case.name) }
    $checks++
}
if ($NegativeReceipt) {
    $data = Get-Content -LiteralPath $NegativeReceipt -Raw | ConvertFrom-Json
    # Deliberately forge the outer success flags. Native failure must still win.
    $data.ok = $true
    $data.failures = @()
    $rejected = $false
    try { Assert-RenderUploadHealth $data } catch { $rejected = $true }
    if (-not $rejected) { throw 'Actual failed PressureFlow receipt passed health admission.' }
    $checks++
}
Write-Output ('RENDER_UPLOAD_577_HEALTH_VALIDATOR '+(@{checks=$checks;powershell=$PSVersionTable.PSVersion.ToString()} | ConvertTo-Json -Compress))
