param([Parameter(Mandatory=$true)][string]$Output)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (Test-Path -LiteralPath $Output) { throw 'Preserve dependency evidence: output must be new' }
$Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
[void][IO.Directory]::CreateDirectory($Output)
$Notices = Join-Path $Output 'notices'
[void][IO.Directory]::CreateDirectory($Notices)
function Fetch([string]$Url,[string]$File) {
    curl.exe --fail --location --retry 3 --max-time 300 --output $File $Url
    if ($LASTEXITCODE -ne 0) { throw ('Dependency capture failed: '+$Url) }
}
foreach ($Name in @('LICENSE.txt','COPYRIGHT.txt')) {
    Fetch ('https://raw.githubusercontent.com/godotengine/godot/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/'+$Name) (Join-Path $Notices $Name)
}
$RuntimeLicense = Join-Path $Notices 'Microsoft-Visual-C-Runtime-LICENSE.docx'
$DeveloperLicense = Join-Path $Notices 'Microsoft-Visual-Studio-2022-LICENSE.docx'
Fetch 'https://visualstudio.microsoft.com/wp-content/uploads/2021/09/Visual-C-Runtime-2015-2022-License-1.docx' $RuntimeLicense
Fetch 'https://visualstudio.microsoft.com/wp-content/uploads/2021/11/Visual-Studio-2022-Enterprise-Professional-License-EN.docx' $DeveloperLicense
& (Join-Path $Root 'tools/ci/stage_windows_vc_runtime.ps1') -Output (Join-Path $Output 'vc') -License $RuntimeLicense -DeveloperLicense $DeveloperLicense
if (-not (Test-Path -LiteralPath (Join-Path $Output 'vc/vc-runtime-provenance.json'))) { throw 'Missing signed VC custody' }
