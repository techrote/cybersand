[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Output)

# One bounded developer-only qualification lane on the existing Windows host.
# All game invocations use the fixed goblin scenes and fresh application profiles.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$outputPath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $outputPath) { throw 'Qualification output must be a new directory.' }
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$sourceTests = Join-Path $outputPath 'source-tests'
[IO.Directory]::CreateDirectory($sourceTests) | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)

function Download-Pinned([string]$Url, [string]$Path, [string]$Algorithm, [string]$Hash) {
    Invoke-WebRequest -Uri $Url -OutFile $Path
    if ((Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant() -ne $Hash) {
        throw "Pinned dependency hash mismatch: $Path"
    }
}

function Invoke-Python([string[]]$Arguments, [string]$Log) {
    & python @Arguments 2>&1 | Tee-Object -FilePath $Log
    if ($LASTEXITCODE -ne 0) { throw "Qualification command failed; see $Log" }
}

$engineZip = Join-Path $outputPath 'godot-windows.zip'
Download-Pinned 'https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_win64.exe.zip' $engineZip SHA512 '41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9'
$engineRoot = Join-Path $outputPath 'engine'
Expand-Archive -LiteralPath $engineZip -DestinationPath $engineRoot
$engine = Join-Path $engineRoot 'Godot_v4.7-stable_win64_console.exe'
$version = ((& $engine --version) -join "`n").Trim()
if ($LASTEXITCODE -ne 0 -or $version -ne '4.7.stable.official.5b4e0cb0f') { throw 'Pinned Godot version mismatch.' }

Invoke-Python @('-m', 'pip', 'install', '-r', 'tools/gip014/requirements.txt') (Join-Path $outputPath 'process-monitor-dependency.log')
$env:GOBLIN_PARITY_GODOT = $engine
Invoke-Python @('-m', 'unittest', 'discover', '-s', 'tools/gip014', '-p', 'test_*.py') (Join-Path $outputPath 'python-contracts.log')
$cases = @('unit', 'discovery', 'adapter', 'expanded', 'controller', 'laboratory', 'gameplay', 'metamorphic', 'authored_lineage', 'baseline')
foreach ($case in $cases) {
    Invoke-Python @('tools/gip014/run_goblin.py', '--godot', $engine, '--case', $case, '--out', (Join-Path $sourceTests $case), '--timeout-seconds', '300') (Join-Path $outputPath ($case + '.log'))
}
Invoke-Python @('tools/gip014/qualify_reproduction.py', '--laboratory', (Join-Path $sourceTests 'laboratory'), '--out', (Join-Path $outputPath 'regression-case')) (Join-Path $outputPath 'regression-export.log')

# Two distinct actual-game campaigns keep this focused lane affordable.
Invoke-Python @('tools/gip014/run_goblin.py', '--godot', $engine, '--out', (Join-Path $sourceTests 'control-64'), '--fixture', 'actor_workshop', '--policy', 'CONTROL', '--seed', '13', '--budget', '64') (Join-Path $outputPath 'control-64.log')
Invoke-Python @('tools/gip014/run_goblin.py', '--godot', $engine, '--out', (Join-Path $sourceTests 'builder-128'), '--fixture', 'liquid_channel', '--policy', 'BUILDER', '--seed', '605', '--budget', '128') (Join-Path $outputPath 'builder-128.log')
Invoke-Python @('tools/gip014/run_goblin.py', '--godot', $engine, '--case', 'replay', '--out', (Join-Path $sourceTests 'control-64-replay'), '--replay', (Join-Path $sourceTests 'control-64/transcript.json')) (Join-Path $outputPath 'control-64-replay.log')

# Successor policies exercise meaningful observed conditions before packaging.
foreach ($policy in @('STATEFUL', 'NOVELTY', 'COVERAGE_HUNTER')) {
    Invoke-Python @('tools/gip014/run_goblin.py', '--godot', $engine, '--out', (Join-Path $sourceTests ($policy.ToLowerInvariant() + '-64')), '--fixture', 'alchemy', '--policy', $policy, '--seed', '1701', '--budget', '64') (Join-Path $outputPath ($policy.ToLowerInvariant() + '-64.log'))
}

$notices = Join-Path $outputPath 'engine-notices'
[IO.Directory]::CreateDirectory($notices) | Out-Null
Download-Pinned 'https://raw.githubusercontent.com/godotengine/godot/5b4e0cb0f/LICENSE.txt' (Join-Path $notices 'LICENSE.txt') SHA256 'b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80'
Download-Pinned 'https://raw.githubusercontent.com/godotengine/godot/5b4e0cb0f/COPYRIGHT.txt' (Join-Path $notices 'COPYRIGHT.txt') SHA256 'cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d'
$runtimeLicense = Join-Path $outputPath 'vc-runtime-license.docx'
$developerLicense = Join-Path $outputPath 'vc-developer-license.docx'
Download-Pinned 'https://visualstudio.microsoft.com/wp-content/uploads/2021/09/Visual-C-Runtime-2015-2022-License-1.docx' $runtimeLicense SHA256 'f1e3d56ceb2ad68aae0711b910375009e651ac5530fa0760f0dea6e81e54fae1'
Download-Pinned 'https://visualstudio.microsoft.com/wp-content/uploads/2021/11/Visual-Studio-2022-Enterprise-Professional-License-EN.docx' $developerLicense SHA256 '9c0cd52b20db9d081854c75bd1b50c75514b8f8cb09c8cad15e89d90b97b5bf3'
$vcStage = Join-Path $outputPath 'vc-runtime'
& tools/ci/stage_windows_vc_runtime.ps1 -Output $vcStage -License $runtimeLicense -DeveloperLicense $developerLicense
if ($LASTEXITCODE -ne 0) { throw 'Established Visual C++ runtime staging failed.' }

$candidate = Join-Path $outputPath 'CyberSand-goblin-base.zip'
Invoke-Python @('tools/gip014/package_evaluator.py', '--godot-archive', $engineZip, '--engine-notices', $notices, '--vc-runtime', $vcStage, '--campaign-evidence', $sourceTests, '--out', $candidate) (Join-Path $outputPath 'packaging.log')
$extracted = Join-Path $outputPath 'extracted'
Expand-Archive -LiteralPath $candidate -DestinationPath $extracted
$packageRoot = Join-Path $extracted 'CyberSand-goblin'
$selftestLog = Join-Path $outputPath 'extracted-selftest.log'
Invoke-Python @('tools/gip014/qualify_extracted.py', '--package', $packageRoot, '--log', $selftestLog) (Join-Path $outputPath 'extracted-process-monitor.log')
$markers = @(Get-Content -LiteralPath $selftestLog | Where-Object { $_.StartsWith('GOBLIN_PACKAGE_SELFTEST_PASS ') })
if ($markers.Count -ne 1) { throw 'Extracted evaluator completion is absent or ambiguous.' }
$reportPath = $markers[0].Substring('GOBLIN_PACKAGE_SELFTEST_PASS '.Length)
Invoke-Python @('tools/gip014/package_evaluator.py', '--verify-extracted', $packageRoot, '--qualification', $reportPath) (Join-Path $outputPath 'extracted-verification.log')
$report = [IO.File]::ReadAllText($reportPath) | ConvertFrom-Json
if ($report.graphical_smoke.status -ne 'pass') { throw 'The actual graphical developer scene has not passed.' }
$final = Join-Path $outputPath 'CyberSand-goblin.zip'
$seal = Join-Path $outputPath 'delivery-seal.json'
Invoke-Python @('tools/gip014/seal_evaluator.py', '--base', $candidate, '--extracted', $packageRoot, '--qualification', $reportPath, '--out', $final, '--receipt', $seal) (Join-Path $outputPath 'delivery-seal.log')
$commit = ((& git rev-parse HEAD) -join '').Trim()
$summary = @{ schema = 'cybersand-goblin-windows-qualification-v1'; source_commit = $commit;
    status = 'pass'; evaluator_sha256 = (Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash.ToLowerInvariant();
    base_evaluator_sha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant();
    delivery_seal_sha256 = (Get-FileHash -LiteralPath $seal -Algorithm SHA256).Hash.ToLowerInvariant();
    extracted_report = $reportPath; extracted_report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant();
    source_cases = $cases + @('native regression export/reproduction', 'CONTROL actor_workshop64', 'BUILDER liquid_channel128', 'CONTROL replay64', 'STATEFUL alchemy64', 'NOVELTY alchemy64', 'COVERAGE_HUNTER alchemy64');
    scope = 'Draft developer evaluator on hosted Windows; no physical NVIDIA owner acceptance';
    native_runtime_basis = 'retained binaries with matching105 native and4 Rapier source inputs; no native rebuild claimed' }
[IO.File]::WriteAllText((Join-Path $outputPath 'windows-qualification.json'), (($summary | ConvertTo-Json -Depth 8) + "`n"), $utf8)
Write-Host "GOBLIN_WINDOWS_QUALIFICATION_PASS $commit"
