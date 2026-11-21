#requires -Version 5.1
<#
.SYNOPSIS
  Physical Windows/NVIDIA owner acceptance for the immutable CyberSand PR #685 World Art package.
.DESCRIPTION
  Downloads/extracts (or accepts an existing copy of) the source-qualified Windows package,
  verifies its SHA-256/file inventory, executes real Godot ANGLE captures on the current PC,
  requires Godot to identify an NVIDIA render adapter, tests extreme fit framing,
  streams/verifies a 67,108,864-pixel PNG, verifies safe refusal, and records manual acceptance.
  Does not merge code, alter CyberSand native World limits, overwrite capture output,
  or mistake an installed NVIDIA card for the adapter actually used by Godot.
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\CyberSand-World-Art-NVIDIA-Acceptance.ps1
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\CyberSand-World-Art-NVIDIA-Acceptance.ps1 -ArchivePath "$HOME\Downloads\world-art-windows-evaluation-44732085788-1.zip"
.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\CyberSand-World-Art-NVIDIA-Acceptance.ps1 -PackageDirectory 'C:\WorldArt\CyberSand-World-Art' -SkipLargeExport -SkipManual
#>
[CmdletBinding()]
param(
    [string] $ArchivePath,
    [string] $PackageDirectory,
    [string] $OutputRoot,
    [switch] $SkipLargeExport,
    [switch] $SkipSizeMatrix,
    [switch] $SkipManual
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$SourceCommit = '386a790239f77e5e1b8a133a967cdf0fb27228ec'
$MergedCommit = 'd5b0371501eb7ccd32c261f738b4a2612218fbc1'
$ExpectedInnerSha = 'c8ba08551d8ec3f0418a3ab1c3e5940e99d3592f0da229346d8312306ebc18d2'
$ExpectedOuterSha = 'c46c2d63da7e501d35a1f4ff1542c5c12ff362814d82ec467478dd8bbf0ed4fd'
$ArtifactUrl = 'https://github.com/techrote/cybersand/actions/runs/44732085788/artifacts/14626733328'
$ArtifactName = 'world-art-windows-evaluation-44732085788-1'
$RunId = '44732085788'

if ($env:OS -ne 'Windows_NT') { throw 'Use this script in a real Windows PowerShell desktop session.' }
if ($ArchivePath -and $PackageDirectory) { throw 'Supply either -ArchivePath or -PackageDirectory, not both.' }
if (-not $OutputRoot) {
    $OutputRoot = Join-Path (Join-Path $HOME 'Downloads') ('CyberSand-WorldArt-NVIDIA-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID)
}
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $OutputRoot) { throw "Output directory already exists; supply a fresh -OutputRoot: $OutputRoot" }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
$script:Logs = Join-Path $OutputRoot 'logs'
$script:Captures = Join-Path $OutputRoot 'captures'
New-Item -ItemType Directory -Path $script:Logs, $script:Captures -Force | Out-Null
$script:Receipt = Join-Path $OutputRoot 'physical-nvidia-acceptance.json'
$script:Package = $null
$script:Python = $null
$script:Engine = $null
$script:Launcher = $null

$script:Report = [ordered]@{
    schema = 'cybersand.world-art.physical-nvidia-acceptance/1'
    utc_started = [DateTime]::UtcNow.ToString('o')
    utc_completed = $null
    pr = 685
    package_qualified_source_commit = $SourceCommit
    merged_main_commit = $MergedCommit
    artifact_url = $ArtifactUrl
    artifact_expires = '2026-12-20'
    machine = [ordered]@{ os = [Environment]::OSVersion.VersionString; nvidia_devices = @() }
    package = [ordered]@{ path = $null; source_commit = $null; manifest_seal = $null; zip_sha256 = $null }
    engine = [ordered]@{ rendering_driver = $null; graphics_adapter = $null; graphics_vendor = $null; nvidia_active = $false }
    automated = [ordered]@{}
    manual = [ordered]@{}
    outputs = [ordered]@{}
    failures = @()
    result = 'INCOMPLETE'
}
function Save-Receipt {
    $json = $script:Report | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText($script:Receipt, $json + [Environment]::NewLine, ([System.Text.UTF8Encoding]::new($false)))
}
function Require([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}
function Record([string] $Step, [string] $State, [string] $Details) {
    $script:Report.automated[$Step] = [ordered]@{ status = $State; details = $Details }
    Save-Receipt
    $color = if ($State -eq 'PASS') { 'Green' } elseif ($State -eq 'SKIP') { 'Yellow' } else { 'Red' }
    Write-Host ("[{0}] {1}: {2}" -f $State, $Step, $Details) -ForegroundColor $color
}
function Quote-Arg([string] $Value) {
    if ($Value -match '[\s"]') { return '"' + $Value.Replace('"', '\"') + '"' }
    return $Value
}
function Invoke-Logged {
    param(
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Exe,
        [string[]] $Arguments = @(),
        [string] $ArgumentLine,
        [switch] $AllowFailure
    )
    $stdout = Join-Path $script:Logs ($Name + '.stdout.log')
    $stderr = Join-Path $script:Logs ($Name + '.stderr.log')
    if (-not $ArgumentLine) { $ArgumentLine = (($Arguments | ForEach-Object { Quote-Arg ([string] $_) }) -join ' ') }
    Write-Host "Running $Name ..." -ForegroundColor Cyan
    $p = Start-Process -FilePath $Exe -ArgumentList $ArgumentLine -WorkingDirectory $script:Package -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $code = [int] $p.ExitCode
    if ($code -ne 0 -and -not $AllowFailure) {
        $tail = if (Test-Path -LiteralPath $stderr) { (Get-Content -LiteralPath $stderr -Tail 12) -join ' | ' } else { '' }
        throw "Step $Name exited $code. Logs: $stdout / $stderr. $tail"
    }
    return [pscustomobject]@{ ExitCode = $code; Stdout = $stdout; Stderr = $stderr }
}
function Read-Json([string] $Path) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "Missing JSON: $Path"
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}
function Validate-Bundle([string] $Name, [string] $Path) {
    $check = Invoke-Logged -Name ($Name + '-verify') -Exe $script:Python -Arguments @('-B', $script:Launcher, '--verify-bundle', $Path)
    $result = Read-Json $check.Stdout
    Require ($result.valid -eq $true) "$Name verification did not report valid=true"
    Require (@($result.problems).Count -eq 0) "$Name verification returned problems"
    $manifest = Read-Json (Join-Path $Path 'batch-manifest.json')
    Require ($manifest.status -eq 'completed') "$Name has incomplete batch status"
    Require ([bool] $manifest.source_guard.unchanged) "$Name did not preserve the source"
    return $manifest
}
function Assert-NvidiaRenderer([string] $Name, [string] $CaptureDir) {
    $run = Read-Json (Join-Path $CaptureDir 'godot-run.json')
    $d = $run.display
    Require ($null -ne $d) "$Name lacks Godot display identity"
    $adapter = [string] $d.graphics_adapter
    $driver = [string] $d.rendering_driver
    $vendor = [string] $d.graphics_vendor
    Require ($driver -eq 'opengl3_angle') "$Name actually used '$driver', not the packaged ANGLE rendering driver"
    Require ($adapter -match '(?i)(NVIDIA|GEFORCE|QUADRO|TESLA|TITAN|RTX)') `
        "$Name DID NOT RENDER ON NVIDIA: Godot selected '$adapter' (vendor '$vendor'). An NVIDIA card merely being installed is not sufficient. Configure Windows Graphics/NVIDIA preference for the packaged Godot executable and rerun from a fresh output location."
    Require ($adapter -notmatch '(?i)(Microsoft Basic|WARP|llvmpipe|SwiftShader|software rasterizer)') `
        "$Name used a software renderer: $adapter"
    if ($Name -eq 'ordinary') {
        $script:Report.engine.rendering_driver = $driver
        $script:Report.engine.graphics_adapter = $adapter
        $script:Report.engine.graphics_vendor = $vendor
        $script:Report.engine.nvidia_active = $true
    }
    return $adapter
}
function Confirm-Manually([string] $Label, [string] $Prompt) {
    while ($true) {
        $answer = ([string](Read-Host "$Prompt [P=PASS / F=FAIL / S=SKIP]")).Trim().ToUpperInvariant()
        switch ($answer) {
            'P' { $script:Report.manual[$Label] = 'PASS'; Save-Receipt; return }
            'F' { $script:Report.manual[$Label] = 'FAIL'; Save-Receipt; return }
            'S' { $script:Report.manual[$Label] = 'SKIP'; Save-Receipt; return }
        }
        Write-Host 'Enter P, F, or S.' -ForegroundColor Yellow
    }
}
Save-Receipt

try {
    Write-Host "Physical Windows/NVIDIA acceptance for merged CyberSand PR #685" -ForegroundColor Cyan
    Write-Host "Evidence root: $OutputRoot"
    Write-Host 'This tests the original qualified Windows package, not CyberSand native gameplay.'

    # Diagnostic inventory only. The authoritative selected GPU comes from Godot's actual capture.
    try {
        $devices = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
            [ordered]@{ name = [string] $_.Name; vendor = [string] $_.AdapterCompatibility;
                driver_version = [string] $_.DriverVersion; pnp_id = [string] $_.PNPDeviceID }
        })
        $script:Report.machine.nvidia_devices = @($devices | Where-Object { $_.name -match '(?i)NVIDIA' -or $_.vendor -match '(?i)NVIDIA' })
        Write-Host ('Windows GPU inventory: ' + (($devices | ForEach-Object { $_.name }) -join ', '))
    } catch {
        Write-Warning ('Windows GPU inventory unavailable: ' + $_.Exception.Message + '. Godot selected-adapter verification remains mandatory.')
    }

    if ($PackageDirectory) {
        $script:Package = (Resolve-Path -LiteralPath $PackageDirectory).Path
    } else {
        $staging = Join-Path $OutputRoot 'download'
        New-Item -ItemType Directory -Path $staging | Out-Null
        $input = $null
        if ($ArchivePath) {
            $input = (Resolve-Path -LiteralPath $ArchivePath).Path
        } else {
            $gh = Get-Command gh -ErrorAction SilentlyContinue
            if (-not $gh) {
                throw "No -ArchivePath supplied and GitHub CLI (gh) is missing. Download $ArtifactUrl in a browser and rerun with -ArchivePath 'C:\path\downloaded-artifact.zip'."
            }
            Write-Host 'Downloading the exact qualified artifact with authenticated gh CLI ...'
            & $gh.Source run download $RunId -R 'techrote/cybersand' -n $ArtifactName -D $staging
            Require ($LASTEXITCODE -eq 0) "gh download failed. Download $ArtifactUrl in your browser and supply -ArchivePath."
            $candidate = Get-ChildItem -LiteralPath $staging -Filter 'CyberSand-World-Art-Windows.zip' -Recurse -File | Select-Object -First 1
            Require ($null -ne $candidate) 'gh download succeeded but the inner ZIP is missing'
            $input = $candidate.FullName
        }
        Require (([IO.Path]::GetExtension($input)).ToLowerInvariant() -eq '.zip') '-ArchivePath must point to a ZIP'
        $givenSha = (Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash.ToLowerInvariant()
        $innerZip = $null
        if ($givenSha -eq $ExpectedInnerSha) {
            $innerZip = $input
        } elseif ($givenSha -eq $ExpectedOuterSha) {
            $unwrapped = Join-Path $staging 'outer-extracted'
            Expand-Archive -LiteralPath $input -DestinationPath $unwrapped
            $candidate = Get-ChildItem -LiteralPath $unwrapped -Filter 'CyberSand-World-Art-Windows.zip' -File -Recurse | Select-Object -First 1
            Require ($null -ne $candidate) 'Verified outer Actions ZIP lacks the expected inner package'
            $innerZip = $candidate.FullName
        } else {
            throw "Archive SHA-256 mismatch. Expected known outer $ExpectedOuterSha or inner $ExpectedInnerSha, got $givenSha. Refusing extraction."
        }
        $innerSha = (Get-FileHash -LiteralPath $innerZip -Algorithm SHA256).Hash.ToLowerInvariant()
        Require ($innerSha -eq $ExpectedInnerSha) "Inner package SHA-256 mismatch: $innerSha"
        $script:Report.package.zip_sha256 = $innerSha
        $unpacked = Join-Path $OutputRoot 'unpacked'
        Expand-Archive -LiteralPath $innerZip -DestinationPath $unpacked
        $found = Get-ChildItem -LiteralPath $unpacked -Filter 'world-art-evaluation.json' -Recurse -File | Where-Object {
            Test-Path -LiteralPath (Join-Path $_.DirectoryName 'Open World Art.cmd')
        } | Select-Object -First 1
        Require ($null -ne $found) 'Inner ZIP does not contain an extracted World Art package root'
        $script:Package = $found.DirectoryName
    }
    $script:Package = [IO.Path]::GetFullPath($script:Package)
    $script:Report.package.path = $script:Package
    $script:Python = Join-Path $script:Package 'dependencies\python\python.exe'
    $script:Engine = Join-Path $script:Package 'Godot_v4.7-stable_win64_console.exe'
    $script:Launcher = Join-Path $script:Package 'tools\world_art_preview_launcher.py'
    foreach ($path in @($script:Python, $script:Engine, $script:Launcher, (Join-Path $script:Package 'Gallery.html'))) {
        Require (Test-Path -LiteralPath $path -PathType Leaf) "Package file missing: $path"
    }

    $verified = Invoke-Logged -Name 'package-verify' -Exe $script:Python `
        -Arguments @('-B', (Join-Path $script:Package 'tools\world_art_evaluation_package.py'), 'verify', '--package', $script:Package)
    $message = Get-Content -LiteralPath $verified.Stdout -Raw -Encoding UTF8
    Require ($message -match 'WORLD_ART_PACKAGE_OK') 'Package verifier did not confirm WORLD_ART_PACKAGE_OK'
    $manifest = Read-Json (Join-Path $script:Package 'world-art-evaluation.json')
    Require ($manifest.source_commit -eq $SourceCommit) "Package was not built from qualified source $SourceCommit"
    Require ($manifest.status -eq 'complete') 'Package manifest is incomplete'
    $script:Report.package.source_commit = $manifest.source_commit
    $script:Report.package.manifest_seal = $manifest.manifest_sha256
    Record 'package_hashes_and_ledger' 'PASS' ('Source ' + $SourceCommit.Substring(0, 12) + ', sealed manifest and file inventory verified')

    $ordinary = Join-Path $script:Captures 'ordinary-lumen-fault'
    $cmd = Join-Path $script:Package 'Capture example.cmd'
    Require (Test-Path -LiteralPath $cmd) 'Capture example.cmd not found'
    $cmdline = '/d /c call "' + $cmd + '" "' + $ordinary + '"'
    $null = Invoke-Logged -Name 'ordinary-shipped-cmd' -Exe $env:ComSpec -ArgumentLine $cmdline
    $normal = Validate-Bundle -Name 'ordinary' -Path $ordinary
    Require (@($normal.jobs).Count -eq 1) 'Expected one Lumen Fault ordinary capture'
    $normalAdapter = Assert-NvidiaRenderer 'ordinary' $ordinary
    $full = @($normal.jobs[0].shots | Where-Object { $_.kind -eq 'full' })
    Require ($full.Count -eq 1) 'Missing ordinary full PNG'
    $expectedNative = (Read-Json (Join-Path $script:Package 'docs\world-design\lumen-fault\pack.json')).scene.size
    Require ($full[0].width -eq [int] $expectedNative[0] -and $full[0].height -eq [int] $expectedNative[1]) `
        'Ordinary full PNG dimensions differ from native source dimensions'
    $script:Report.outputs.ordinary = $ordinary
    Record 'ordinary_capture_and_nvidia' 'PASS' ("Godot selected $normalAdapter; full PNG $($full[0].width)x$($full[0].height), verified manifest")

    if (-not $SkipSizeMatrix) {
        $sizes = @('1024x4096', '512x8192', '8192x512', '2048x8192', '16384x1024')
        $sizeDir = Join-Path $script:Captures 'five-asymmetric-fit-tests'
        $sizeArgs = @('-B', $script:Launcher, '--godot', $script:Engine, '--rendering-driver', 'opengl3_angle', '--capture')
        foreach ($size in $sizes) {
            $inputPath = Join-Path $script:Package ("evidence\source-inputs\size-matrix-$size\01-matrix-$size.json")
            Require (Test-Path -LiteralPath $inputPath -PathType Leaf) "Missing shipped source for $size : $inputPath"
            $sizeArgs += @('--pack', $inputPath)
        }
        $sizeArgs += @('--shots', 'viewport', '--framing', 'fit', '--resolution', '640x360', '--scale', '1', '--output-dir', $sizeDir, '--timeout', '3600')
        $null = Invoke-Logged -Name 'asymmetric-five-capture' -Exe $script:Python -Arguments $sizeArgs
        $sizesManifest = Validate-Bundle -Name 'asymmetric-five' -Path $sizeDir
        $null = Assert-NvidiaRenderer 'asymmetric-five' $sizeDir
        Require (@($sizesManifest.jobs).Count -eq 5) 'Expected exactly five asymmetric source captures'
        foreach ($entry in $sizesManifest.jobs) {
            $sizeName = ([string] $entry.collection) -replace '^size-matrix-', ''
            Require ($sizes -contains $sizeName) "Unrecognized size fixture $($entry.collection)"
            $job = Read-Json (Join-Path $sizeDir ([string] $entry.manifest))
            $frame = @($job.shots | Where-Object { $_.kind -eq 'viewport' })
            Require ($frame.Count -eq 1) "$sizeName lacks exactly one viewport shot"
            $cam = $frame[0].camera
            Require ($cam.map_fully_visible -eq $true) "Fit-all cropped $sizeName"
            foreach ($edge in @('left', 'top', 'right', 'bottom')) {
                Require ($cam.clips.$edge -eq $false) "Fit-all clipped $edge edge of $sizeName"
            }
            $width, $height = $sizeName -split 'x'
            Require ($cam.native_size[0] -eq [int] $width -and $cam.native_size[1] -eq [int] $height) `
                "Source native size mismatch for $sizeName"
        }
        $script:Report.outputs.size_matrix = $sizeDir
        Record 'five_asymmetric_canvases' 'PASS' '1024x4096, 512x8192, 8192x512, 2048x8192, 16384x1024; NVIDIA and zero fit clipping confirmed'
    } else { Record 'five_asymmetric_canvases' 'SKIP' 'Explicit -SkipSizeMatrix supplied' }

    if (-not $SkipLargeExport) {
        $input = Join-Path $script:Package 'evidence\source-inputs\large-streamed-rgb8-67m\01-streamed-art.json'
        Require (Test-Path -LiteralPath $input -PathType Leaf) "Large streamed source fixture missing: $input"
        $largeDir = Join-Path $script:Captures 'streamed-4096x16384'
        $null = Invoke-Logged -Name 'streamed-67m-capture' -Exe $script:Python `
            -Arguments @('-B', $script:Launcher, '--godot', $script:Engine, '--rendering-driver', 'opengl3_angle',
                '--capture', '--pack', $input, '--shots', 'full', '--scale', '4', '--stream-large',
                '--output-dir', $largeDir, '--timeout', '3600')
        $large = Validate-Bundle -Name 'streamed-67m' -Path $largeDir
        $null = Assert-NvidiaRenderer 'streamed-67m' $largeDir
        Require (@($large.jobs).Count -eq 1) 'Large streamed capture did not have one job'
        $streamed = @($large.jobs[0].shots | Where-Object { $_.kind -eq 'full' })
        Require ($streamed.Count -eq 1 -and $streamed[0].width -eq 4096 -and $streamed[0].height -eq 16384) `
            'Large streamed PNG is incomplete or wrong size; expected 4096x16384'
        Require ($large.stream_large -eq $true) 'Large export was not explicitly streamed'
        $script:Report.outputs.large_streamed = $largeDir
        Record '67m_streamed_png' 'PASS' 'Original Godot 4096x16384 pixels decoded, source-hashed, sealed and rendered with NVIDIA'
    } else { Record '67m_streamed_png' 'SKIP' 'Explicit -SkipLargeExport supplied' }

    # Re-run the exact shipped capture into an existing completed directory.
    # The refusal must leave the completed manifest byte-for-byte unchanged.
    $beforeHash = (Get-FileHash -LiteralPath (Join-Path $ordinary 'batch-manifest.json') -Algorithm SHA256).Hash
    $attempt = Invoke-Logged -Name 'must-refuse-overwrite' -Exe $env:ComSpec -ArgumentLine $cmdline -AllowFailure
    $afterHash = (Get-FileHash -LiteralPath (Join-Path $ordinary 'batch-manifest.json') -Algorithm SHA256).Hash
    Require ($attempt.ExitCode -ne 0 -and $beforeHash -eq $afterHash) 'Overwrite refusal failed or altered completed evidence'
    $null = Validate-Bundle -Name 'ordinary-after-refusal' -Path $ordinary
    Record 'no_overwrite' 'PASS' 'Second capture refused without changing the original manifest; original bundle still valid'

    # An invalid working copy must fail, never publishing a completed bundle.
    $badRoot = Join-Path $OutputRoot 'invalid-working-source'
    New-Item -ItemType Directory -Path $badRoot | Out-Null
    $invalid = Join-Path $badRoot 'pack.json'
    [IO.File]::WriteAllText($invalid, '{ "invalid-json": ', ([System.Text.UTF8Encoding]::new($false)))
    $badOut = Join-Path $script:Captures 'invalid-source-refusal'
    $bad = Invoke-Logged -Name 'must-refuse-invalid-input' -Exe $script:Python -Arguments @('-B', $script:Launcher,
        '--godot', $script:Engine, '--rendering-driver', 'opengl3_angle', '--capture', '--pack', $invalid,
        '--shots', 'viewport', '--output-dir', $badOut, '--timeout', '300') -AllowFailure
    $badManifest = Join-Path $badOut 'batch-manifest.json'
    $accidentallyCompleted = (Test-Path -LiteralPath $badManifest) -and ((Read-Json $badManifest).status -eq 'completed')
    Require ($bad.ExitCode -ne 0 -and -not $accidentallyCompleted) 'Malformed source was accepted or published as completed'
    Record 'corrupt_input_refusal' 'PASS' 'Malformed external source refused; no successful publication'

    $workingDir = Join-Path $OutputRoot 'editable-working-copy\lumen-fault'
    New-Item -ItemType Directory -Path $workingDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $script:Package 'docs\world-design\lumen-fault\pack.json') `
        -Destination (Join-Path $workingDir 'pack.json')
    $script:Report.outputs.editable_working_copy = (Join-Path $workingDir 'pack.json')
    Record 'working_copy_created' 'PASS' 'Original source preserved; editable copy available for live reload/pin comparison'

    if (-not $SkipManual) {
        Write-Host ''
        Write-Host 'MANUAL WINDOWS/NVIDIA ACCEPTANCE (record P/F/S after inspecting)' -ForegroundColor Cyan
        Write-Host "Gallery and canvas captures: $script:Package\Gallery.html and $script:Captures"
        Write-Host 'Inspect original geometry, material boundaries, lighting, negative space and side elevation.'
        Write-Host 'Test F, W, H, 1, wheel zoom, pan, minimap, scene/feature changes, P pin, B compare and R reload.'
        Write-Host "For a writable editing source use: $workingDir\pack.json (never edit the package reference)."
        Write-Host 'Close the viewer to return to the acceptance questions.'
        Start-Process -FilePath (Join-Path $script:Package 'Open Gallery.cmd') -WorkingDirectory $script:Package
        Start-Process -FilePath (Join-Path $script:Package 'Open World Art.cmd') -WorkingDirectory $script:Package -Wait
        Confirm-Manually 'original_artwork_gallery' 'Original artwork and full 15-scene/120-feature gallery acceptable?'
        Confirm-Manually 'viewer_navigation_comparison_reload' 'Viewer F/W/H/1, zoom, pan, minimap, pin/compare and manual reload acceptable?'
        Confirm-Manually 'asymmetric_edges' 'Five wide/tall fit captures and far-edge regions look correct?'
        Confirm-Manually 'png_exports' 'Ordinary and streamed export image quality and pixel dimensions acceptable?'
        Confirm-Manually 'failure_behaviour' 'No-overwrite, corrupt refusal and fresh-directory retry policy acceptable?'
        $script:Report.manual['notes'] = Read-Host 'Optional notes (blank if none)'
    } else {
        foreach ($key in @('original_artwork_gallery', 'viewer_navigation_comparison_reload',
            'asymmetric_edges', 'png_exports', 'failure_behaviour')) { $script:Report.manual[$key] = 'PENDING' }
    }

    $autoStatuses = @($script:Report.automated.Values | ForEach-Object { $_.status })
    $manualStatuses = @($script:Report.manual.GetEnumerator() | Where-Object { $_.Key -ne 'notes' } | ForEach-Object { $_.Value })
    if (($autoStatuses -contains 'FAIL') -or ($manualStatuses -contains 'FAIL')) { $script:Report.result = 'FAIL' }
    elseif (($autoStatuses -contains 'SKIP') -or ($manualStatuses -contains 'SKIP') -or ($manualStatuses -contains 'PENDING')) {
        $script:Report.result = 'PARTIAL_OR_MANUAL_PENDING'
    } else { $script:Report.result = 'PASS_PHYSICAL_WINDOWS_NVIDIA_AND_OWNER_VISUAL' }
} catch {
    $message = $_.Exception.Message
    $script:Report.failures += $message
    $script:Report.result = 'FAIL_OR_INCOMPLETE'
    Write-Host "[FAIL] $message" -ForegroundColor Red
} finally {
    $script:Report.utc_completed = [DateTime]::UtcNow.ToString('o')
    Save-Receipt
    Write-Host ''
    Write-Host ('RESULT: ' + $script:Report.result) -ForegroundColor $(if ($script:Report.result -eq 'PASS_PHYSICAL_WINDOWS_NVIDIA_AND_OWNER_VISUAL') { 'Green' } else { 'Yellow' })
    Write-Host "Receipt: $script:Receipt"
    Write-Host "Capture/log evidence: $OutputRoot"
    Write-Host 'Physical NVIDIA acceptance requires the actual Godot adapter to identify NVIDIA and owner manual PASSes.'
}
if ($script:Report.result -eq 'PASS_PHYSICAL_WINDOWS_NVIDIA_AND_OWNER_VISUAL') { exit 0 }
exit 1