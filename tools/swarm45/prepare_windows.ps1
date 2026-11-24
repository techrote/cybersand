param([switch]$Package)
$ErrorActionPreference = 'Stop'
if ($env:TARGET_SOURCE -notmatch '^[0-9a-f]{40}$' -or (git rev-parse HEAD) -ne $env:TARGET_SOURCE) { throw 'Source mismatch' }
python tools/swarm45/runtime_custody.py build/swarm45-windows
if ($LASTEXITCODE -ne 0) { throw 'Windows producer custody failed' }
git lfs install --local
git lfs pull --include='godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll,godot/tools/gentek_reciprocal.exe' --exclude=''
if ($LASTEXITCODE -ne 0) { throw 'Rapier materialization failed' }
$rapier = 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
if ((Get-FileHash $rapier -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7') { throw 'Rapier pin mismatch' }
if (-not $Package) {
    $sourceStage = Join-Path $env:RUNNER_TEMP 'swarm45-source'
    python tools/swarm45/stage_source.py --runtime build/swarm45-windows --output $sourceStage
    if ($LASTEXITCODE -ne 0) { throw 'Source-bound isolated Windows project staging failed' }
    'SWARM45_SOURCE_PROJECT=' + (Join-Path $sourceStage 'godot') | Out-File -Append $env:GITHUB_ENV
}
$zip = Join-Path $env:RUNNER_TEMP 'swarm45-godot.zip'
curl.exe -fL --retry 3 -o $zip https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_win64.exe.zip
if ($LASTEXITCODE -ne 0) { throw 'Godot download failed' }
$sha = '41645a908eb3181d6f2d1201ed7b6d6f095f6a23aaed8903d5d255277cc8d142814f3e6817f865b3cac142c39b8aff99280091d3bbdaa301517730b3ba0522b9'
if ((Get-FileHash $zip -Algorithm SHA512).Hash.ToLowerInvariant() -ne $sha) { throw 'Godot archive pin mismatch' }
$engineDir = Join-Path $env:RUNNER_TEMP 'swarm45-godot'
Expand-Archive $zip $engineDir
# Use the actual engine in every source/package/preservation lane. The console
# wrapper has a different PID and cannot satisfy the strict report/process join.
$engine = Join-Path $engineDir 'Godot_v4.7-stable_win64.exe'
'GODOT_EXE=' + $engine | Out-File -Append $env:GITHUB_ENV
if (-not $Package) { exit 0 }
$notices = Join-Path $env:RUNNER_TEMP 'swarm45-notices'
New-Item -ItemType Directory -Force $notices | Out-Null
foreach ($name in @('LICENSE.txt','COPYRIGHT.txt')) {
    curl.exe -fL --retry 3 -o (Join-Path $notices $name) "https://raw.githubusercontent.com/godotengine/godot/5b4e0cb0f/$name"
    if ($LASTEXITCODE -ne 0) { throw 'Godot notices download failed' }
}
if ((Get-FileHash (Join-Path $notices 'LICENSE.txt') -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80' -or (Get-FileHash (Join-Path $notices 'COPYRIGHT.txt') -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'cb1980c88089573bcacd7221d777c689bb8bbd778799f24c27fca0fe5f774d6d') { throw 'Godot notices mismatch' }
$runtimeLicense = Join-Path $notices 'Microsoft-Visual-C-Runtime-LICENSE.docx'
$developerLicense = Join-Path $notices 'Microsoft-Visual-Studio-2022-LICENSE.docx'
curl.exe -fL --retry 3 -o $runtimeLicense 'https://visualstudio.microsoft.com/wp-content/uploads/2021/09/Visual-C-Runtime-2015-2022-License-1.docx'
if ($LASTEXITCODE -ne 0) { throw 'Runtime licence download failed' }
curl.exe -fL --retry 3 -o $developerLicense 'https://visualstudio.microsoft.com/wp-content/uploads/2021/11/Visual-Studio-2022-Enterprise-Professional-License-EN.docx'
if ($LASTEXITCODE -ne 0) { throw 'Redistribution licence download failed' }
$vc = Join-Path $env:RUNNER_TEMP 'swarm45-vc-runtime'
& tools/ci/stage_windows_vc_runtime.ps1 -Output $vc -License $runtimeLicense -DeveloperLicense $developerLicense
if ($LASTEXITCODE -ne 0) { throw 'Runtime staging failed' }
python tools/swarm45/package_owner.py --engine $engine --engine-notices $notices --runtime build/swarm45-windows --vc-runtime $vc --output build/swarm45-owner
if ($LASTEXITCODE -ne 0) { throw 'Evaluator packaging failed' }
python tools/swarm006/seal_owner.py --package build/swarm45-owner --output build/swarm456-sealed --source $env:TARGET_SOURCE
if ($LASTEXITCODE -ne 0) { throw 'Unified evaluator sealing failed' }
python tools/swarm006/test_owner_launcher.py --sealed build/swarm456-sealed --output evidence/windows-launcher --source $env:TARGET_SOURCE
if ($LASTEXITCODE -ne 0) { throw 'Actual Windows owner launcher qualification failed' }
Copy-Item build/swarm456-sealed/swarm456-owner-seal.json evidence/windows-package-seal.json
$archive = "build/swarm456-sealed/CyberSand-SWARM456-Draft-HOLD-Windows-$($env:TARGET_SOURCE.Substring(0,12)).zip"
$launcher = 'build/swarm456-sealed/CyberSand-SWARM456-Windows-Owner-Acceptance.ps1'
$validation = Join-Path $env:RUNNER_TEMP 'swarm45-pristine-package'
& $launcher -Archive $archive -Destination $validation -VerifyOnly
if (-not $?) { throw 'Source-bound fresh owner ZIP extraction failed' }
'SWARM45_PACKAGE=' + $validation | Out-File -Append $env:GITHUB_ENV
'SWARM45_PACKAGE_ZIP=' + (Resolve-Path $archive).Path | Out-File -Append $env:GITHUB_ENV
'SWARM45_PACKAGE_ENGINE=' + (Join-Path $validation 'Godot_v4.7-stable_win64.exe') | Out-File -Append $env:GITHUB_ENV
