# PAINT-END2END-002 isolated physical Windows/NVIDIA owner acceptance.
# Extract the CI evaluator ZIP before running. Does not modify an installed
# Workbench or update production Git LFS. Requires git/git-lfs, Python 3.9+,
# official Godot 4.7, and an interactive NVIDIA-powered Windows desktop.
[CmdletBinding()]
param(
    [ValidateSet('16k','65k','262k','all')]
    [string]$Scenario = '262k',
    [string]$Godot = 'C:\Godot_v4.7-stable_win64_console.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$bundle = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceFile = Join-Path $bundle 'source-sha.txt'
$candidate = Join-Path $bundle 'windows-candidate'
if (!(Test-Path -LiteralPath $sourceFile)) { throw "Missing exact source-sha.txt from evaluator ZIP." }
$sha = (Get-Content -LiteralPath $sourceFile -Raw).Trim()
if ($sha -notmatch '^[0-9a-f]{40}$') { throw "Invalid source SHA in evaluator ZIP." }
$dll = Join-Path $candidate 'cybersand_native.windows.x86_64.dll'
if (!(Test-Path -LiteralPath $dll)) { throw "Source-built Windows candidate DLL absent." }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw "Git for Windows is required." }
if (!(Get-Command python -ErrorAction SilentlyContinue)) { throw "Python 3.9 or later is required." }
& git lfs version | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Git LFS is required for the pinned Rapier DLL." }
if (!(Test-Path -LiteralPath $Godot)) {
    $alternate = 'C:\Tools\Godot\Godot_v4.7-stable_win64_console.exe'
    if (Test-Path -LiteralPath $alternate) { $Godot = $alternate }
    else { throw "Specify -Godot with the installed Godot 4.7 console executable path." }
}
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$short = $sha.Substring(0,12)
$workspace = Join-Path $bundle ("isolated-" + $short)
$evidence = Join-Path $bundle ("evidence-" + $short + "-" + $Scenario)
$marker = Join-Path $workspace '.paint-end2end-002-disposable'
if (Test-Path -LiteralPath $workspace) {
    if (!(Test-Path -LiteralPath $marker)) {
        throw "Existing working directory is not a PAINT-END2END-002 disposable checkout: $workspace"
    }
    if ((Get-Content -LiteralPath $marker -Raw).Trim() -ne $sha) {
        throw "Existing disposable checkout is for a different source commit."
    }
    $actual = (& git -C $workspace rev-parse HEAD).Trim()
    if ($actual -ne $sha) { throw "Existing disposable checkout no longer matches package source." }
} else {
    # Avoid fetching all Git LFS assets. Do not reuse the user's actual checkout.
    $oldSkip = $env:GIT_LFS_SKIP_SMUDGE
    try {
        $env:GIT_LFS_SKIP_SMUDGE = '1'
        & git clone --filter=blob:none --no-checkout https://github.com/techrote/cybersand.git $workspace
        if ($LASTEXITCODE -ne 0) { throw "Source clone failed." }
        & git -C $workspace -c advice.detachedHead=false checkout --detach $sha
        if ($LASTEXITCODE -ne 0) { throw "Exact evaluator source commit checkout failed." }
    } finally { $env:GIT_LFS_SKIP_SMUDGE = $oldSkip }
    Set-Content -LiteralPath $marker -Value $sha -Encoding ascii
}
& git -C $workspace lfs install --local | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Local git-lfs initialization failed." }
$rapier = 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
& git -C $workspace lfs pull --include=$rapier --exclude=''
if ($LASTEXITCODE -ne 0) { throw "Pinned Rapier LFS download failed." }
$runScript = Join-Path $workspace 'tools\ci\qualify_paint_end2end_002_owner_windows.py'
if (!(Test-Path -LiteralPath $runScript)) {
    throw "Source-matched evaluator Python runner missing. No approximate version is allowed."
}
& python $runScript --self-test
if ($LASTEXITCODE -ne 0) { throw "Evaluator self-test failed." }
Write-Host ("Source-matched PAINT-END2END-002 evaluator: " + $sha)
Write-Host ("Disposable checkout: " + $workspace)
Write-Host ("Exact-source DLL: " + $dll)
Write-Host ("Godot 4.7: " + $Godot)
Write-Host ("Scenario: " + $Scenario)
& python $runScript --candidate $candidate --godot $Godot --source-sha $sha --scenario $Scenario --output $evidence
$exitCode = $LASTEXITCODE
$zip = "$evidence-evidence.zip"
Write-Host ("Evidence JSON: " + (Join-Path $evidence 'qualification.json'))
Write-Host ("Evidence ZIP: " + $zip)
if ($exitCode -ne 0) { throw "PAINT-END2END-002 physical qualification FAILED. Preserve evidence ZIP for review." }
Write-Host "Evidence captured. This does not approve promotion, Ready, or merge."
