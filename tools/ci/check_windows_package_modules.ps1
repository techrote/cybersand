<#
Prove that a copied Windows installation loads its own required DLLs.
The console executable is a wrapper; inspect the directly launched GUI PID.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$Evidence,
    [switch]$Combined
)

$ErrorActionPreference = 'Stop'
$startupSeconds = 60
$evidencePath = [System.IO.Path]::GetFullPath($Evidence)
$evidenceDirectory = [System.IO.Path]::GetDirectoryName($evidencePath)
[System.IO.Directory]::CreateDirectory($evidenceDirectory) | Out-Null
$logStem = [System.IO.Path]::GetFileNameWithoutExtension($evidencePath)
$stdoutPath = Join-Path $evidenceDirectory ($logStem + '.stdout.log')
$stderrPath = Join-Path $evidenceDirectory ($logStem + '.stderr.log')
$ownedProcess = $null
$previousEnvironment = @{}
$elapsed = [System.Diagnostics.Stopwatch]::StartNew()
$receipt = [ordered]@{
    schema = 1
    purpose = 'Actual copied-installation Windows module resolution'
    status = 'failed'
    requested_package = $Package
    package = $null
    source_commit = $null
    source_tree = $null
    started_utc = [DateTime]::UtcNow.ToString('o')
    finished_utc = $null
    startup_deadline_seconds = $startupSeconds
    elapsed_seconds = $null
    pid = $null
    executable = $null
    modules = @()
    observed_module_inventory = @()
    arguments = @()
    stdout_path = $stdoutPath
    stderr_path = $stderrPath
    userdata_directory = $null
    enumeration_error_count = 0
    last_enumeration_error = $null
    error = $null
    cleanup = [ordered]@{
        terminated_owned_process = $false
        exit_code = $null
        environment_restored = $false
        error = $null
    }
}

function Get-CanonicalFilePath([string]$FilePath) {
    return [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $FilePath).ProviderPath)
}

function New-PackageFileRecord([string]$RelativePath) {
    $properties = @($manifest.files_sha256.PSObject.Properties | Where-Object {
        [string]::Equals($_.Name, $RelativePath, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($properties.Count -ne 1 -or [string]$properties[0].Value -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Candidate manifest lacks a unique SHA-256 for $RelativePath"
    }
    $path = Get-CanonicalFilePath (Join-Path $receipt.package $RelativePath)
    $expectedHash = ([string]$properties[0].Value).ToLowerInvariant()
    $packagedHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($packagedHash -ne $expectedHash) {
        throw "Copied package file differs from its manifest: $RelativePath"
    }
    return [ordered]@{
        name = [System.IO.Path]::GetFileName($path)
        relative_path = $RelativePath
        expected_path = $path
        expected_sha256 = $expectedHash
        packaged_sha256 = $packagedHash
        observed_path = $null
        observed_sha256 = $null
        status = 'unobserved'
    }
}

function Confirm-ObservedFile($Record, [string]$ObservedPath) {
    # Retain the actual loader path even when it names a system-installed DLL.
    $Record.observed_path = $ObservedPath
    $actualPath = Get-CanonicalFilePath $ObservedPath
    $Record.observed_sha256 = (Get-FileHash -LiteralPath $actualPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not [string]::Equals($actualPath, $Record.expected_path, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Loaded $($Record.name) from '$actualPath'; expected '$($Record.expected_path)'"
    }
    if ($Record.observed_sha256 -ne $Record.expected_sha256) {
        throw "Loaded file differs from its candidate manifest: $actualPath"
    }
    $Record.status = 'verified'
}

try {
    [System.IO.File]::WriteAllText($stdoutPath, '')
    [System.IO.File]::WriteAllText($stderrPath, '')
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or [IntPtr]::Size -ne 8) {
        throw 'Module acceptance requires 64-bit PowerShell on Windows'
    }
    $receipt.package = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Package).ProviderPath)
    $manifestName = if ($Combined) { 'materials-lab-evaluation.json' } else { 'candidate-manifest.json' }
    $projectRelative = if ($Combined) { 'source/godot' } else { 'godot' }
    $manifest = Get-Content -LiteralPath (Join-Path $receipt.package $manifestName) -Raw | ConvertFrom-Json
    $receipt.source_commit = [string]$manifest.source_commit
    $receipt.source_tree = [string]$manifest.source_tree
    if ($receipt.source_commit -notmatch '^[0-9a-f]{40}$') {
        throw 'Candidate manifest lacks a valid source commit'
    }
    $receipt.executable = New-PackageFileRecord 'Godot_v4.7-stable_win64.exe'
    $receipt.modules = @(
        (New-PackageFileRecord 'vcruntime140.dll'),
        (New-PackageFileRecord ($projectRelative + '/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll')),
        (New-PackageFileRecord ($projectRelative + '/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'))
    )
    $projectPath = (Resolve-Path -LiteralPath (Join-Path $receipt.package $projectRelative)).ProviderPath
    if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'project.godot') -PathType Leaf)) {
        throw 'Copied installation has no Godot project'
    }
    $userdata = Join-Path ([System.IO.Path]::GetTempPath()) ('cybersand-package-modules-' + [Guid]::NewGuid().ToString('N'))
    $receipt.userdata_directory = $userdata
    $probeEnvironment = @{
        APPDATA = (Join-Path $userdata 'appdata')
        LOCALAPPDATA = (Join-Path $userdata 'localappdata')
        XDG_DATA_HOME = (Join-Path $userdata 'data')
        XDG_CONFIG_HOME = (Join-Path $userdata 'config')
        CYBERSAND_SOURCE_REVISION = $receipt.source_commit
    }
    foreach ($name in $probeEnvironment.Keys) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($name -ne 'CYBERSAND_SOURCE_REVISION') {
            [System.IO.Directory]::CreateDirectory($probeEnvironment[$name]) | Out-Null
        }
        [Environment]::SetEnvironmentVariable($name, $probeEnvironment[$name], 'Process')
    }
    $receipt.arguments = @('--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
        '--rendering-driver', 'opengl3_angle', '--path', $projectPath, '--', '--workbench')
    # Start-Process joins its argument array; quote the project path explicitly.
    $launchArguments = @('--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
        '--rendering-driver', 'opengl3_angle', '--path', ('"{0}"' -f $projectPath), '--', '--workbench')
    $startup = [System.Diagnostics.Stopwatch]::StartNew()
    $ownedProcess = Start-Process -FilePath $receipt.executable.expected_path -ArgumentList $launchArguments `
        -WorkingDirectory $receipt.package -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    $receipt.pid = $ownedProcess.Id
    while ($startup.Elapsed.TotalSeconds -lt $startupSeconds) {
        $ownedProcess.Refresh()
        if ($ownedProcess.HasExited) {
            throw "Owned Godot process exited before module acceptance (exit $($ownedProcess.ExitCode))"
        }
        $liveProcess = $null
        $snapshot = $null
        try {
            $liveProcess = Get-Process -Id $ownedProcess.Id
            $observedExecutable = $liveProcess.Path
            $receipt.executable.observed_path = $observedExecutable
            $snapshot = @($liveProcess.Modules | ForEach-Object {
                [ordered]@{ name = $_.ModuleName; path = $_.FileName }
            })
        } catch {
            # Startup can briefly race Windows module enumeration. A bounded
            # retry records the error and cannot turn missing evidence into PASS.
            $receipt.enumeration_error_count += 1
            $receipt.last_enumeration_error = $_.Exception.Message
        } finally {
            if ($null -ne $liveProcess) { $liveProcess.Dispose() }
        }
        if ($null -ne $snapshot) {
            $receipt.observed_module_inventory = $snapshot
            if ($receipt.executable.status -ne 'verified') {
                Confirm-ObservedFile $receipt.executable $observedExecutable
            }
            $presentRequired = 0
            foreach ($record in $receipt.modules) {
                $matchingModules = @($snapshot | Where-Object { $_.name -ieq $record.name })
                if ($matchingModules.Count -gt 1) { throw "Multiple loaded modules named $($record.name)" }
                if ($matchingModules.Count -eq 1) {
                    $presentRequired += 1
                    if ($record.status -ne 'verified' -or -not [string]::Equals(
                            $record.observed_path, $matchingModules[0].path, [StringComparison]::OrdinalIgnoreCase)) {
                        Confirm-ObservedFile $record $matchingModules[0].path
                    }
                }
            }
            if ($presentRequired -eq $receipt.modules.Count) {
                $ownedProcess.Refresh()
                if ($ownedProcess.HasExited) { throw 'Godot exited while its modules were inspected' }
                if ($startup.Elapsed.TotalSeconds -ge $startupSeconds) { break }
                $receipt.status = 'passed'
                break
            }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($receipt.status -ne 'passed') {
        $missing = @($receipt.modules | Where-Object { $_.status -ne 'verified' } | ForEach-Object { $_.name })
        throw "Godot module acceptance exceeded ${startupSeconds}s; unverified: $($missing -join ', ')"
    }
} catch {
    $receipt.status = 'failed'
    $receipt.error = $_.Exception.Message
} finally {
    if ($null -ne $ownedProcess) {
        try {
            $ownedProcess.Refresh()
            if (-not $ownedProcess.HasExited) {
                # The direct GUI Process object owns this handle. Do not kill
                # process names, an unrelated PID, or any other Godot session.
                $ownedProcess.Kill()
                if (-not $ownedProcess.WaitForExit(5000)) { throw 'Owned Godot process did not stop within 5s' }
                $receipt.cleanup.terminated_owned_process = $true
            } elseif ($receipt.status -eq 'passed') {
                throw 'Godot exited before the completed probe could stop it'
            }
            $receipt.cleanup.exit_code = $ownedProcess.ExitCode
        } catch {
            $receipt.status = 'failed'
            $receipt.cleanup.error = $_.Exception.Message
        } finally {
            $ownedProcess.Dispose()
        }
    }
    try {
        foreach ($name in $previousEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
        }
        $receipt.cleanup.environment_restored = $true
    } catch {
        $receipt.status = 'failed'
        $receipt.cleanup.error = "$($receipt.cleanup.error) Environment restore failed: $($_.Exception.Message)".Trim()
    } finally {
        $receipt.finished_utc = [DateTime]::UtcNow.ToString('o')
        $receipt.elapsed_seconds = [Math]::Round($elapsed.Elapsed.TotalSeconds, 3)
        $receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    }
}

if ($receipt.status -ne 'passed') {
    throw "Windows package module acceptance failed: $($receipt.error) $($receipt.cleanup.error). Evidence: $evidencePath"
}
Write-Output "PASS copied Windows module paths and manifest hashes: $evidencePath"
