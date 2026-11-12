[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Output,
    [Parameter(Mandatory = $true)][string]$License,
    [Parameter(Mandatory = $true)][string]$DeveloperLicense
)

# Stage only the release redistributable supplied by the installed, licensed
# Visual Studio 2022 Professional/Enterprise installation. Never take a DLL
# from System32 or Debug_NonRedist, and never install anything on the host.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Visual C++ runtime staging requires Windows.'
}
$outputPath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $outputPath) {
    throw "Runtime stage must be a new directory: $outputPath"
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-License([string]$Path, [long]$Size, [string]$Sha256) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.PSIsContainer -or $item.Length -ne $Size -or (Get-Sha256 $item.FullName) -ne $Sha256) {
        throw "Official Microsoft licence size/hash mismatch: $Path"
    }
    return $item.FullName
}

function Assert-Amd64Dll([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) {
            throw 'Redistributable is not a PE file.'
        }
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 64 -or $peOffset -gt ($stream.Length - 24)) {
            throw 'Redistributable has an invalid PE header offset.'
        }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550 -or $reader.ReadUInt16() -ne 0x8664) {
            throw 'Redistributable must be an AMD64 PE image.'
        }
        $stream.Position = $peOffset + 22
        if (($reader.ReadUInt16() -band 0x2000) -eq 0) {
            throw 'Redistributable PE image is not a DLL.'
        }
    }
    finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

$runtimeLicenseHash = 'f1e3d56ceb2ad68aae0711b910375009e651ac5530fa0760f0dea6e81e54fae1'
$developerLicenseHash = '9c0cd52b20db9d081854c75bd1b50c75514b8f8cb09c8cad15e89d90b97b5bf3'
$runtimeLicensePath = Assert-License $License 39644 $runtimeLicenseHash
$developerLicensePath = Assert-License $DeveloperLicense 63513 $developerLicenseHash

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
    throw 'The installed Visual Studio discovery tool is unavailable.'
}
$products = @('Microsoft.VisualStudio.Product.Enterprise', 'Microsoft.VisualStudio.Product.Professional')
$vsArguments = @('-latest', '-products') + $products + @(
    '-version', '[17.0,18.0)',
    '-requires', 'Microsoft.VisualStudio.Component.VC.Redist.14.Latest',
    '-format', 'json', '-utf8'
)
$vsJson = (& $vswhere @vsArguments) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "Visual Studio discovery failed with exit $LASTEXITCODE."
}
$installations = @($vsJson | ConvertFrom-Json -ErrorAction Stop)
if ($installations.Count -ne 1) {
    throw 'Exactly one complete release Visual Studio 2022 Pro/Enterprise installation with the VC redistributable is required.'
}
$installation = $installations[0]
if ($installation.productId -notin $products -or $installation.isPrerelease -or
        ([version]$installation.installationVersion).Major -ne 17) {
    throw 'Discovered Visual Studio product does not match the retained VS2022 Pro/Enterprise licence.'
}
$installationPath = [IO.Path]::GetFullPath([string]$installation.installationPath).TrimEnd('\')
$redistRoot = Join-Path $installationPath 'VC\Redist\MSVC'
$candidates = @(
    Get-ChildItem -LiteralPath $redistRoot -Directory | Where-Object {
        $_.Name -match '^\d+\.\d+\.\d+(?:\.\d+)?$'
    } | Sort-Object { [version]$_.Name } -Descending | ForEach-Object {
        $path = Join-Path $_.FullName 'x64\Microsoft.VC143.CRT\vcruntime140.dll'
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Get-Item -LiteralPath $path
        }
    }
)
if ($candidates.Count -eq 0) {
    throw 'VS2022 has no release x64 Microsoft.VC143.CRT vcruntime140.dll redistributable.'
}
$runtime = $candidates[0]
$sourceRelative = $runtime.FullName.Substring($installationPath.Length + 1).Replace('\', '/')
if ($sourceRelative -notmatch '^VC/Redist/MSVC/\d+\.\d+\.\d+(?:\.\d+)?/x64/Microsoft\.VC143\.CRT/vcruntime140\.dll$' -or
        ($runtime.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Refused a runtime outside the ordinary release Visual Studio redistributable location.'
}
Assert-Amd64Dll $runtime.FullName
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($runtime.FullName)
if ($version.IsDebug -or $version.IsPreRelease -or $version.FileMajorPart -ne 14) {
    throw 'Redistributable must be a release Visual C++ v14 runtime.'
}
$signature = Get-AuthenticodeSignature -LiteralPath $runtime.FullName
if ($signature.Status.ToString() -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
        $signature.SignerCertificate.Subject -notmatch '(?:^|,\s*)O="?Microsoft Corporation"?(?:,|$)') {
    throw 'Redistributable does not have a valid Microsoft Authenticode signature.'
}
$runtimeHash = Get-Sha256 $runtime.FullName

# Create the output only after all sources have passed their identity checks.
New-Item -ItemType Directory -Path $outputPath -ErrorAction Stop | Out-Null
$files = [ordered]@{
    'vcruntime140.dll' = $runtime.FullName
    'Microsoft-Visual-C-Runtime-LICENSE.docx' = $runtimeLicensePath
    'Microsoft-Visual-Studio-2022-LICENSE.docx' = $developerLicensePath
}
$hashes = [ordered]@{}
foreach ($name in $files.Keys) {
    $target = Join-Path $outputPath $name
    Copy-Item -LiteralPath $files[$name] -Destination $target -ErrorAction Stop
    $hashes[$name] = Get-Sha256 $target
}
if ($hashes['vcruntime140.dll'] -ne $runtimeHash -or
        $hashes['Microsoft-Visual-C-Runtime-LICENSE.docx'] -ne $runtimeLicenseHash -or
        $hashes['Microsoft-Visual-Studio-2022-LICENSE.docx'] -ne $developerLicenseHash) {
    throw 'A redistributable or licence changed while being staged.'
}

$record = [ordered]@{
    schema = 1
    kind = 'app-local-microsoft-visual-c-runtime'
    architecture = 'x86_64'
    runtime = [ordered]@{
        file = 'vcruntime140.dll'
        size = $runtime.Length
        sha256 = $runtimeHash
        file_version = $version.FileVersion
        product_version = $version.ProductVersion
        company_name = $version.CompanyName
        pe_machine = 'AMD64 (0x8664)'
        source_relative_redist_path = $sourceRelative
    }
    visual_studio = [ordered]@{
        instance_id = $installation.instanceId
        product_id = $installation.productId
        installation_name = $installation.installationName
        installation_version = $installation.installationVersion
        product_display_version = $installation.catalog.productDisplayVersion
        is_prerelease = $installation.isPrerelease
        vswhere_sha256 = Get-Sha256 $vswhere
    }
    authenticode = [ordered]@{
        status = $signature.Status.ToString()
        signature_type = $signature.SignatureType.ToString()
        signer_subject = $signature.SignerCertificate.Subject
        signer_issuer = $signature.SignerCertificate.Issuer
        signer_thumbprint = $signature.SignerCertificate.Thumbprint
        signer_not_before_utc = $signature.SignerCertificate.NotBefore.ToUniversalTime().ToString('o')
        signer_not_after_utc = $signature.SignerCertificate.NotAfter.ToUniversalTime().ToString('o')
        timestamp_subject = $(if ($null -ne $signature.TimeStamperCertificate) { $signature.TimeStamperCertificate.Subject } else { $null })
        timestamp_thumbprint = $(if ($null -ne $signature.TimeStamperCertificate) { $signature.TimeStamperCertificate.Thumbprint } else { $null })
    }
    runner = [ordered]@{
        image_os = $env:ImageOS
        image_version = $env:ImageVersion
        runner_os = $env:RUNNER_OS
        runner_arch = $env:RUNNER_ARCH
        workflow_run = $env:GITHUB_RUN_ID
        workflow_attempt = $env:GITHUB_RUN_ATTEMPT
        source_commit = $env:GITHUB_SHA
    }
    licensing = [ordered]@{
        runtime_end_user_license = 'Microsoft-Visual-C-Runtime-LICENSE.docx'
        runtime_license_url = 'https://visualstudio.microsoft.com/wp-content/uploads/2021/09/Visual-C-Runtime-2015-2022-License-1.docx'
        developer_license = 'Microsoft-Visual-Studio-2022-LICENSE.docx'
        developer_license_url = 'https://visualstudio.microsoft.com/wp-content/uploads/2021/11/Visual-Studio-2022-Enterprise-Professional-License-EN.docx'
        redistribution_basis = 'Visual Studio 2022 Professional/Enterprise licence, section 5, and the referenced distributable-code list; the runtime end-user licence is not the redistribution grant.'
        redistribution_list_url = 'https://aka.ms/vs/17/redistribution'
        deployment_guidance_url = 'https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files'
    }
    files_sha256 = $hashes
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
[IO.File]::WriteAllText((Join-Path $outputPath 'vc-runtime-provenance.json'), $json, [Text.UTF8Encoding]::new($false))
Write-Output ("Staged VS2022 x64 Visual C++ runtime {0}; SHA256 {1}" -f $version.FileVersion, $runtimeHash)
