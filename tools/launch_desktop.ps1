[CmdletBinding()]
param(
    [string]$Godot = "",
    [switch]$Editor,
    [switch]$PrintIdentityOnly
)

$ErrorActionPreference = "Stop"
$PinnedGodotVersion = "4.7.stable.official.5b4e0cb0f"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ProjectDir = Join-Path $RepoRoot "godot"
$ProjectFile = Join-Path $ProjectDir "project.godot"
$NativeDll = Join-Path $ProjectDir "addons\cybersand_native\bin\cybersand_native.windows.x86_64.dll"
$NativeProvenance = Join-Path $ProjectDir "addons\cybersand_native\runtime-provenance.json"
$RapierDll = Join-Path $ProjectDir "addons\godot-rapier2d\bin\libgodot_rapier.windows.x86_64-pc-windows-msvc.dll"

function Resolve-GodotExecutable {
    param([string]$Override)

    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
            throw "Explicit Godot executable does not exist: $Override"
        }
        return (Resolve-Path -LiteralPath $Override).Path
    }

    if (-not [string]::IsNullOrWhiteSpace($env:CYBERSAND_GODOT)) {
        if (-not (Test-Path -LiteralPath $env:CYBERSAND_GODOT -PathType Leaf)) {
            throw "CYBERSAND_GODOT does not point to a file: $($env:CYBERSAND_GODOT)"
        }
        return (Resolve-Path -LiteralPath $env:CYBERSAND_GODOT).Path
    }

    $root = "C:\Godot47"
    $preferred = @(
        (Join-Path $root "Godot_v4.7-stable_win64.exe"),
        (Join-Path $root "Godot_v4.7-stable_win64_console.exe"),
        (Join-Path $root "Godot.exe")
    )
    foreach ($candidate in $preferred) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if (Test-Path -LiteralPath $root -PathType Container) {
        $fallback = Get-ChildItem -LiteralPath $root -Filter "Godot*.exe" -File |
            Sort-Object @{Expression = { $_.Name -like "*console*" }}, Name |
            Select-Object -First 1
        if ($null -ne $fallback) {
            return $fallback.FullName
        }
    }

    throw "Pinned Godot 4.7 executable was not found under C:\Godot47. Pass -Godot <path> or set CYBERSAND_GODOT."
}

function Resolve-GodotVersionProbe {
    param([string]$LaunchExecutable)

    $leaf = [System.IO.Path]::GetFileName($LaunchExecutable)
    if ($leaf -notlike "*console*") {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
        $consoleCandidate = Join-Path (
            [System.IO.Path]::GetDirectoryName($LaunchExecutable)
        ) ($stem + "_console.exe")
        if (Test-Path -LiteralPath $consoleCandidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $consoleCandidate).Path
        }
    }
    return $LaunchExecutable
}

foreach ($required in @($ProjectFile, $NativeDll, $NativeProvenance, $RapierDll)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required desktop runtime input is missing: $required. This launcher does not rebuild or replace runtime files."
    }
}

function Assert-MaterializedRuntime {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -ge 1024) {
        return
    }
    $smallText = [System.IO.File]::ReadAllText($item.FullName)
    if ($smallText.StartsWith("version https://git-lfs.github.com/spec/v1")) {
        throw "Required runtime is only a Git LFS pointer, not materialized bytes: $Path. Run the repository's normal LFS materialization step; this launcher will not replace it."
    }
}

Assert-MaterializedRuntime -Path $NativeDll
Assert-MaterializedRuntime -Path $RapierDll

$GodotExe = Resolve-GodotExecutable -Override $Godot
$GodotVersionProbe = Resolve-GodotVersionProbe -LaunchExecutable $GodotExe
$GodotVersionOutput = @(& $GodotVersionProbe --version 2>&1)
if ($LASTEXITCODE -ne 0 -or $GodotVersionOutput.Count -eq 0) {
    throw "Godot version probe failed for $GodotVersionProbe with exit code $LASTEXITCODE."
}
$GodotVersion = ([string]$GodotVersionOutput[0]).Trim()
if ($GodotVersion -ne $PinnedGodotVersion) {
    throw "Godot version mismatch. Required '$PinnedGodotVersion'; found '$GodotVersion' via '$GodotVersionProbe'."
}

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $gitCommand) {
    throw "git is required to report the current checkout identity."
}
$CheckoutHead = ((& $gitCommand.Path -C $RepoRoot rev-parse HEAD 2>&1) | Select-Object -First 1).ToString().Trim()
if ($LASTEXITCODE -ne 0 -or $CheckoutHead -notmatch "^[0-9a-f]{40}$") {
    throw "Could not identify the Git checkout at '$RepoRoot'."
}
$CheckoutDirtyLines = @(& $gitCommand.Path -C $RepoRoot status --porcelain 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect Git checkout status at '$RepoRoot'."
}
$CheckoutState = if ($CheckoutDirtyLines.Count -eq 0) { "clean" } else { "tracked-dirty" }

$provenance = Get-Content -LiteralPath $NativeProvenance -Raw | ConvertFrom-Json
$NativeHash = (Get-FileHash -LiteralPath $NativeDll -Algorithm SHA256).Hash.ToLowerInvariant()
$RapierHash = (Get-FileHash -LiteralPath $RapierDll -Algorithm SHA256).Hash.ToLowerInvariant()
$ExpectedNativeHash = [string]$provenance.sha256
if (-not [string]::IsNullOrWhiteSpace($ExpectedNativeHash) -and
    $NativeHash -ne $ExpectedNativeHash.ToLowerInvariant()) {
    throw "Retained CyberSand DLL hash does not match runtime-provenance.json. Expected $ExpectedNativeHash; found $NativeHash. No rebuild was attempted."
}

Write-Host "CyberSand desktop launcher"
Write-Host "  checkout       : $CheckoutHead ($CheckoutState)"
Write-Host "  project        : $ProjectFile"
Write-Host "  Godot          : $GodotVersion"
Write-Host "  Godot exe      : $GodotExe"
Write-Host "  version probe  : $GodotVersionProbe"
Write-Host "  native runtime : $NativeHash"
Write-Host "  native source  : $($provenance.source_commit)"
Write-Host "  Rapier runtime : $RapierHash"
Write-Host "  action         : launch retained runtime only; no rebuild or replacement"

if ($PrintIdentityOnly) {
    exit 0
}

$GodotArguments = @("--path", $ProjectDir)
if ($Editor) {
    $GodotArguments += "--editor"
}
& $GodotExe @GodotArguments
exit $LASTEXITCODE
