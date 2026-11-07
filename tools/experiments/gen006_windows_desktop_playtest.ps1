# GEN-006 Windows desktop acceptance, opt-in and isolated from main.
# Invokes real compiled CyberSand native World and a real-window Godot 4.7
# OpenGL framebuffer test, then records a separate HUMAN desktop verdict.
[CmdletBinding()]
param(
    [string]$GodotExe = "godot",
    [string]$NativeExe = "",
    [string]$EvidenceRoot = "",
    [string]$RepositoryRoot = "",
    [switch]$SkipBuild,
    [switch]$AutomatedOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Require([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../.."))
} else {
    $repo = [IO.Path]::GetFullPath($RepositoryRoot)
}
Require (Test-Path -LiteralPath (Join-Path $repo "native/tests/gen006_streaming_slice.cpp")) "RepositoryRoot must name a CyberSand checkout containing the experimental GEN-006 source."
Push-Location $repo
try {
    $godotCommand = Get-Command $GodotExe -ErrorAction SilentlyContinue
    Require ($null -ne $godotCommand) "Godot executable not found; pass -GodotExe with its full path."
    $godotPath = $godotCommand.Source
    if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        $EvidenceRoot = Join-Path $repo ("build/gen006-desktop-acceptance/run-" +
            (Get-Date -Format "yyyyMMdd-HHmmss"))
    }
    $evidence = [IO.Path]::GetFullPath($EvidenceRoot)
    Require (-not (Test-Path -LiteralPath $evidence)) "Select a fresh evidence root; refusing to overwrite an existing run."
    New-Item -ItemType Directory -Path $evidence -Force | Out-Null
    $project = Join-Path $evidence "godot-project"
    $tests = Join-Path $project "tests"
    $captures = Join-Path $evidence "screenshots"
    New-Item -ItemType Directory -Path $tests,$captures -Force | Out-Null
    $paths = @(
        "godot/tests/gen006_streaming_slice_demo.gd",
        "godot/tests/gen006_streaming_slice_demo.tscn",
        "godot/tests/gen006_graphical_qualification.gd"
    )
    foreach ($path in $paths) {
        Copy-Item -LiteralPath (Join-Path $repo $path) -Destination $tests
    }
    @'
config_version=5
[application]
config/name="GEN006 Windows Desktop Acceptance"
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/size/window_width_override=1280
window/size/window_height_override=800
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $project "project.godot") -Encoding ASCII

    $head = (& git rev-parse HEAD).Trim()
    $tree = (& git rev-parse 'HEAD^{tree}').Trim()
    $godotVersion = ((& $godotPath --version) | Out-String).Trim()
    $gpu = @()
    try { $gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) } catch {}
    $environment = [ordered]@{
        type = "GEN006_WINDOWS_DESKTOP_ACCEPTANCE_V1"
        date = (Get-Date).ToUniversalTime().ToString("o")
        source_commit = $head
        source_tree = $tree
        source_status = @(& git status --porcelain)
        native_source_tree = (& git rev-parse 'HEAD:native').Trim()
        test_inputs = @($paths + "tools/experiments/gen006_windows_desktop_playtest.ps1" | ForEach-Object {
            [ordered]@{ file = $_; sha256 = (Get-FileHash -LiteralPath (Join-Path $repo $_) -Algorithm SHA256).Hash }
        })
        godot_version = $godotVersion
        windows_version = [Environment]::OSVersion.VersionString
        gpu = @($gpu)
        visual_test = "not-run"
        manual_verdict = "not-run"
        not_production = $true
    }
    $environment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence "source.json") -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($NativeExe)) {
        $NativeExe = Join-Path $evidence "streaming-slice.exe"
    } elseif (-not [IO.Path]::IsPathRooted($NativeExe)) {
        $NativeExe = [IO.Path]::GetFullPath((Join-Path $repo $NativeExe))
    }
    if (-not $SkipBuild) {
        $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
        Require (-not [string]::IsNullOrEmpty($programFilesX86)) "Visual Studio C++ tools are required."
        $vswhere = Join-Path $programFilesX86 "Microsoft Visual Studio/Installer/vswhere.exe"
        Require (Test-Path -LiteralPath $vswhere) "vswhere.exe is missing; install Visual Studio C++ Build Tools."
        $vsroot = (& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
        Require (-not [string]::IsNullOrWhiteSpace($vsroot)) "MSVC x64 build environment not found."
        $vsdev = Join-Path $vsroot "Common7/Tools/VsDevCmd.bat"
        $clang = Join-Path $env:ProgramFiles "LLVM/bin/clang++.exe"
        if (-not (Test-Path -LiteralPath $clang)) {
            $clang = Join-Path $vsroot "VC/Tools/Llvm/x64/bin/clang++.exe"
        }
        Require (Test-Path -LiteralPath $clang) "LLVM clang++.exe not found."
        $sources = @(
            "native/src/world.cpp", "native/src/material_rules.cpp",
            "native/src/scheduler_geometry.cpp", "native/src/settled_world_discovery.cpp",
            "native/src/world_generation.cpp", "native/src/generation_fields.cpp",
            "native/src/generation_typed_fields.cpp", "native/src/generation_spatial.cpp",
            "native/src/generation_grammar.cpp", "native/src/generation_planes.cpp",
            "native/tests/gen006_streaming_slice.cpp"
        )
        $cmdFile = Join-Path $evidence "compile.cmd"
        $lines = @(
            "@echo off",
            ('call "' + $vsdev + '" -no_logo -arch=x64 -host_arch=x64'),
            "if errorlevel 1 exit /b 1",
            ('"' + $clang + '" -std=c++20 -O0 -I native/include ' +
                ($sources -join " ") + ' -o "' + $NativeExe + '"'),
            "if errorlevel 1 exit /b 1",
            "exit /b 0"
        )
        $lines | Set-Content -LiteralPath $cmdFile -Encoding ASCII
        $build = Start-Process -FilePath "cmd.exe" -ArgumentList @("/d","/c",('"'+$cmdFile+'"')) -Wait -PassThru -NoNewWindow -RedirectStandardOutput (Join-Path $evidence "compile.stdout.log") -RedirectStandardError (Join-Path $evidence "compile.stderr.log")
        $environment.build_exit_code = $build.ExitCode
        & $clang --version | Set-Content -LiteralPath (Join-Path $evidence "compiler.txt") -Encoding UTF8
        Require ($build.ExitCode -eq 0) "Actual native World compilation failed; inspect compile stderr/stdout."
    }
    Require (Test-Path -LiteralPath $NativeExe) "Native streaming executable not found."
    $environment.native_executable = $NativeExe
    $environment.native_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $NativeExe).Hash

    # Automated real-window test. Never pass --headless: this reads actual
    # Godot Viewport pixels, including terrain and the visible simulation pin.
    $env:GEN006_SLICE_EXECUTABLE = $NativeExe
    $env:GEN006_SLICE_ROOT = Join-Path $evidence "auto-world"
    $env:GEN006_GRAPHICAL_EVIDENCE = $captures
    $windowTest = Start-Process -FilePath $godotPath -ArgumentList @(
        "--rendering-driver", "opengl3",
        "--path", ('"'+$project+'"'),
        "--script", "res://tests/gen006_graphical_qualification.gd"
    ) -Wait -PassThru -RedirectStandardOutput (Join-Path $evidence "graphical.stdout.log") -RedirectStandardError (Join-Path $evidence "graphical.stderr.log")
    $environment.graphical_exit_code = $windowTest.ExitCode
    $graphicalLog = Get-Content -LiteralPath (Join-Path $evidence "graphical.stdout.log") -Raw
    $expectedPngs = @(
        "00-generated-terrain", "01-dug", "02-painted-wall",
        "03-distant-chunk", "04-reloaded-wall", "05-water17",
        "06-reloaded-terrain", "07-visible-simulation-pin"
    )
    $pngs = foreach ($name in $expectedPngs) {
        $path = Join-Path $captures ($name + ".png")
        Require ((Test-Path -LiteralPath $path) -and ((Get-Item $path).Length -gt 1000)) "Missing genuine Godot screenshot: $name"
        [ordered]@{ file = $name + ".png"; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    }
    Require ($windowTest.ExitCode -eq 0) "Godot actual-viewport test failed; inspect original logs."
    Require ($graphicalLog -match "GEN006_GODOT_GRAPHICAL_FRAME_PASS") "Real Godot framebuffer assertions were not satisfied."
    Require ($graphicalLog -match "persistent_native_process=1") "Native process identity was not maintained."
    Require ($graphicalLog -match "native_surface_first_frame=1") "Native generated terrain was not actually displayed."
    $pngs | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence "screenshots.sha256.json") -Encoding UTF8
    $environment.visual_test = "passed"
    $environment.screenshot_count = @($pngs).Count
    Write-Host "PASS: real Godot viewport, native streaming, 8 original PNGs, stable native PID."

    if (-not $AutomatedOnly) {
        Write-Host ""
        Write-Host "HUMAN DESKTOP ACCEPTANCE (not the same as automated CI):"
        Write-Host "Session 1: observe visible generated terrain; paint Wall/Empty/Water; move with arrows and Shift+arrows; verify ticking; exit normally."
        Write-Host "Session 2: reopen the same save root; verify saved edits, viewport, navigation, pin/refusal warnings and responsive input; exit."
        Write-Host "Cross-shard Water, Rapier and shared-World eviction are NOT supported by #486; do not mark them passing."
        $env:GEN006_SLICE_ROOT = Join-Path $evidence "manual-world"
        Remove-Item Env:GEN006_GRAPHICAL_EVIDENCE -ErrorAction SilentlyContinue
        $scene = "res://tests/gen006_streaming_slice_demo.tscn"
        for ($session = 1; $session -le 2; $session++) {
            Write-Host ("Launching real Godot desktop playtest session " + $session + "/2.")
            $manual = Start-Process -FilePath $godotPath -ArgumentList @(
                "--rendering-driver","opengl3","--path",('"'+$project+'"'),$scene
            ) -Wait -PassThru -RedirectStandardOutput (Join-Path $evidence "manual-$session.stdout.log") -RedirectStandardError (Join-Path $evidence "manual-$session.stderr.log")
            $environment["manual_${session}_exit_code"] = $manual.ExitCode
            Require ($manual.ExitCode -eq 0) "Manual Godot session $session exited with error."
        }
        $verdict = Read-Host "Did the real two-session Windows desktop gameplay meet the checks (PASS / FAIL / HOLD)?"
        $notes = Read-Host "Record observed problems, input latency, unsupported behaviour and evidence"
        $environment.manual_verdict = $verdict
        $environment.manual_notes = $notes
    }
    $environment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence "source.json") -Encoding UTF8
    Write-Host ("Evidence retained in: " + $evidence)
    Write-Host "Do not claim production/shared-World admission on the basis of this desktop test."
} finally {
    if ((Get-Variable environment -ErrorAction SilentlyContinue) -and
        (Get-Variable evidence -ErrorAction SilentlyContinue)) {
        $environment | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence "source.json") -Encoding UTF8
    }
    Pop-Location
}
