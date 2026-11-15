# Self-contained installed evaluation. No download, install or cloud access.
[CmdletBinding()]
param(
    [switch]$Automated,
    [ValidateSet('opengl3', 'opengl3_angle')][string]$RenderingDriver = 'opengl3',
    [ValidateRange(5, 180)][int]$TotalTimeoutMinutes = 90
)
# The .cmd wrapper already isolates module discovery before powershell.exe
# starts. Repeat it for direct script invocation and import only in-box modules;
# a parent pwsh process must not inject incompatible PowerShell Core modules.
$env:PSModulePath = [IO.Path]::Combine($PSHOME, 'Modules')
foreach ($Module in @('Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Utility', 'CimCmdlets')) {
    Import-Module ([IO.Path]::Combine($PSHOME, 'Modules', $Module, ($Module + '.psd1'))) -ErrorAction Stop
}
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($PSScriptRoot)
$Engine = Join-Path $Root 'Godot_v4.7-stable_win64.exe'
$Console = Join-Path $Root 'Godot_v4.7-stable_win64_console.exe'
$Project = Join-Path $Root 'godot'
$Output = Join-Path $Root ('Test-It-Results\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID)
$CaseRoot = Join-Path $Output 'cases'
$Started = [DateTime]::UtcNow
$Deadline = $Started.AddMinutes($TotalTimeoutMinutes)
$CaseResults = @{}
$Receipts = @{}
$Summary = [ordered]@{schema = 'camera-stack-installed-execution-v1'; status = 'running'; complete = $false
    source_commit = 'unverified'; source_tree = ''; driver = $RenderingDriver; platform = 'Windows'
    automated = [bool]$Automated; physical_gpu_acceptance = 'pending'; cases = @(); errors = @()}
[void](New-Item -ItemType Directory -Path $CaseRoot -Force)

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Digest([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Json([string]$Path) {
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Save-Summary {
    $Summary.elapsed_seconds = [Math]::Round(([DateTime]::UtcNow - $Started).TotalSeconds, 3)
    [IO.File]::WriteAllText((Join-Path $Output 'summary.json'),
        (($Summary | ConvertTo-Json -Depth 40) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
}

function Package-Path([string]$Relative) {
    Require ($Relative.Length -gt 0 -and $Relative -notmatch '(^[\\/]|[<>:"|?*]|(^|[\\/])\.\.([\\/]|$))') ('Unsafe inventory path: ' + $Relative)
    $Path = [IO.Path]::GetFullPath((Join-Path $Root ($Relative.Replace('/', '\'))))
    Require ($Path.StartsWith($Root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) ('Path leaves package: ' + $Relative)
    return $Path
}

function Verify-Package {
    $Manifest = Json (Join-Path $Root 'CAMERA-STACK-MANIFEST.json')
    Require ($Manifest.schema -eq 'camera-stack-windows-evaluation-v1') 'Wrong evaluation manifest'
    Require ($Manifest.source_commit -match '^[0-9a-f]{40}$' -and $Manifest.source_tree -match '^[0-9a-f]{40}$') 'Application source identity missing'
    Require ($Manifest.accepted_main -eq '018bd09503d7f079ddac52e225c2f7daf8d678bf' -and $Manifest.retained_native_unchanged) 'Accepted-main native custody missing'
    $Verified = 0
    $Expected = @{}
    foreach ($Entry in $Manifest.files_sha256.PSObject.Properties) {
        $Expected[$Entry.Name] = $Entry.Value
        # Godot legitimately regenerates import metadata when opened; product,
        # test, shader, recipe and runtime bytes always remain hash checked.
        if ($Entry.Name.EndsWith('.import') -or $Entry.Name.StartsWith('godot/.godot/')) { continue }
        $Path = Package-Path $Entry.Name
        Require (Test-Path -LiteralPath $Path -PathType Leaf) ('Missing package file: ' + $Entry.Name)
        Require ((Digest $Path) -eq $Entry.Value) ('Package hash changed: ' + $Entry.Name)
        $Verified++
    }
    foreach ($File in @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force)) {
        $Name = $File.FullName.Substring($Root.Length + 1).Replace('\', '/')
        if ($Name -eq 'CAMERA-STACK-MANIFEST.json' -or $Name.StartsWith('godot/.godot/') -or
            $Name.StartsWith('Test-It-Results/') -or $Name.EndsWith('.import')) { continue }
        if ($Name.EndsWith('.uid') -and -not $Expected.ContainsKey($Name)) {
            $Owner = $Name.Substring(0, $Name.Length - 4)
            if ($Expected.ContainsKey($Owner) -and $Owner -match '\.(gd|gdshader|gdextension)$') { continue }
        }
        Require ($Expected.ContainsKey($Name)) ('Unexpected evaluation payload: ' + $Name)
    }
    Require ($Verified -gt 100) 'Incomplete evaluation inventory'
    $Native = Join-Path $Project 'addons\cybersand_native\bin\cybersand_native.windows.x86_64.dll'
    $Rapier = Join-Path $Project 'addons\godot-rapier2d\bin\libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
    Require ((Digest $Native) -eq $Manifest.native_sha256 -and (Digest $Rapier) -eq $Manifest.rapier_sha256) 'Native/Rapier bytes changed'
    $Provenance = Json (Join-Path $Project 'addons\cybersand_native\runtime-provenance.json')
    Require ($Provenance.source_commit -eq $Manifest.native_build_commit -and $Provenance.sha256 -eq $Manifest.native_sha256) 'Retained build provenance changed'
    foreach ($Entry in $Provenance.source_inputs.PSObject.Properties) {
        $Path = Package-Path $Entry.Name
        $Text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
        $Algorithm = [Security.Cryptography.SHA256]::Create()
        try {
            $Hash = ([BitConverter]::ToString($Algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant()
            Require ($Hash -eq $Entry.Value) ('Native source differs from retained build: ' + $Entry.Name)
        } finally { $Algorithm.Dispose() }
    }
    $Version = (& $Console --version | Select-Object -First 1).Trim()
    Require ($LASTEXITCODE -eq 0 -and $Version -eq $Manifest.godot_version) 'Bundled Godot version mismatch'
    $Summary.source_commit = $Manifest.source_commit
    $Summary.source_tree = $Manifest.source_tree
    $Summary.native_build_commit = $Manifest.native_build_commit
    $Summary.native_sha256 = $Manifest.native_sha256
    $Summary.rapier_sha256 = $Manifest.rapier_sha256
    $Summary.godot_version = $Version
    $Summary.engine_sha256 = Digest $Engine
    $Summary.payloads_verified = $Verified
    Write-Host "SOURCE VERIFIED $($Manifest.source_commit) / $Verified payload files"
    return $Manifest
}

function Quote([string]$Value) {
    if ($Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    $Escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $Escaped = [regex]::Replace($Escaped, '(\\+)$', '$1$1')
    return '"' + $Escaped + '"'
}

function Execute-Godot([string]$Name, [string[]]$Arguments, [int]$Timeout,
                       [string]$Directory, [hashtable]$Environment) {
    $Remaining = [int][Math]::Floor(($Deadline - [DateTime]::UtcNow).TotalSeconds)
    Require ($Remaining -gt 0) 'Whole-run deadline reached; remaining cases were not executed'
    $Timeout = [Math]::Min($Timeout, $Remaining)
    $Info = New-Object System.Diagnostics.ProcessStartInfo
    # Start the actual engine directly. The console EXE can launch a second
    # process; using the GUI image gives timeout/cleanup direct PID custody.
    $Info.FileName = $Engine
    $Info.Arguments = (($Arguments | ForEach-Object { Quote $_ }) -join ' ')
    $Info.WorkingDirectory = $Root
    $Info.UseShellExecute = $false
    $Info.RedirectStandardOutput = $true
    $Info.RedirectStandardError = $true
    $Info.CreateNoWindow = $false
    foreach ($Key in @($Info.EnvironmentVariables.Keys)) {
        if ($Key -match '^(CYBERSAND_|FLATTEN_|WB_|PAINT_)') { $Info.EnvironmentVariables.Remove($Key) }
    }
    foreach ($Key in $Environment.Keys) { $Info.EnvironmentVariables[$Key] = [string]$Environment[$Key] }
    $Proc = New-Object System.Diagnostics.Process
    $Proc.StartInfo = $Info
    $Exit = -999
    $ProcessId = -1
    $Complete = $false
    $Text = ''
    $Start = [DateTime]::UtcNow
    try {
        Require ($Proc.Start()) ($Name + ' failed to start')
        $ProcessId = $Proc.Id
        $Stdout = $Proc.StandardOutput.ReadToEndAsync()
        $Stderr = $Proc.StandardError.ReadToEndAsync()
        $Complete = $Proc.WaitForExit($Timeout * 1000)
        if (-not $Complete) {
            & "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>&1 | Out-Null
            [void]$Proc.WaitForExit(10000)
        }
        $OutText = if ($Stdout.Wait(10000)) { [string]$Stdout.Result } else { 'STDOUT stream did not close after bounded termination' }
        $ErrText = if ($Stderr.Wait(10000)) { [string]$Stderr.Result } else { 'STDERR stream did not close after bounded termination' }
        [IO.File]::WriteAllText((Join-Path $Directory 'stdout.log'), $OutText, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $Directory 'stderr.log'), $ErrText, [Text.UTF8Encoding]::new($false))
        $Text = $OutText + "`n" + $ErrText
        Require $Complete ($Name + ' timed out; original logs retained')
        $Exit = $Proc.ExitCode
        Require ($Exit -eq 0) ($Name + ' failed with exit ' + $Exit)
        Require ($Text -notmatch 'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|GDExtension library not found') ($Name + ' logged a script/runtime error')
    } finally {
        $Record = [ordered]@{name = $Name; process_id = $ProcessId; exit_code = $Exit; completed = $Complete
            engine_path = $Engine; command = $Arguments; timeout_seconds = $Timeout
            elapsed_seconds = [Math]::Round(([DateTime]::UtcNow - $Start).TotalSeconds, 3)}
        [IO.File]::WriteAllText((Join-Path $Directory 'process.json'),
            (($Record | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
        $Proc.Dispose()
    }
    return $Text
}

function Valid-Receipt($Data, [string]$Name) {
    Require ($Data.PSObject.Properties.Name -contains 'checks' -and [int]$Data.checks -gt 0) ($Name + ' has no executed checks')
    Require ($Data.PSObject.Properties.Name -contains 'failures') ($Name + ' lacks failure accounting')
    $Failures = $Data.failures
    $NoFailures = if ($Failures -is [Array]) { $Failures.Count -eq 0 } else { [int]$Failures -eq 0 }
    Require $NoFailures ($Name + ' contains failed checks')
}

function Validate-Case($Case, [string]$Text, [string]$Directory) {
    $Lines = @($Text -split "`r?`n" | Where-Object { $_.StartsWith($Case.marker + ' ') })
    Require ($Lines.Count -eq 1) ($Case.name + ' requires one exact completion marker')
    $Payload = $Lines[0].Substring($Case.marker.Length).Trim()
    $Data = $null
    if ($Case.kind -in @('json', 'flatten', 'recovery', 'combined')) {
        $Data = $Payload | ConvertFrom-Json
        Valid-Receipt $Data $Case.name
    } elseif ($Case.kind -eq 'architecture') {
        Require ($Payload -match '^phase=([a-z-]+) checks=([1-9][0-9]*) failures=0 complete=true$') ($Case.name + ' is incomplete')
        $Phase = [string]$Case.env.CYBERSAND_ARCHITECTURE_PHASE
        Require ($Matches[1] -eq $Phase) 'Architecture receipt phase differs'
        $Data = Json (Join-Path $Directory ('architecture-' + $Phase + '.json'))
        Valid-Receipt $Data $Case.name
        Require ($Data.phase -eq $Phase) 'Architecture output phase differs'
        if ($Case.graphical) { Require ($Data.display -ne 'headless' -and $Data.display.Length -gt 0) 'Architecture was not graphical' }
    } elseif ($Case.kind -eq 'legacy') {
        Require ($Payload -eq 'checks=5 failures=0') 'Legacy reconstruction incomplete'
        $Data = Json (Join-Path $Directory 'legacy-materials.json')
        $Reference = Json (Join-Path $Root 'qualification\accepted-main-legacy.json')
        $Portable = Json (Join-Path $Root 'tools\architecture\legacy-materials-ac0d9fb9.json')
        Require (@($Data.profiles.PSObject.Properties).Count -eq 5 -and @($Reference.profiles.PSObject.Properties).Count -eq 5) 'Legacy profile inventory changed'
        foreach ($Profile in $Reference.profiles.PSObject.Properties) {
            $Actual = $Data.profiles.($Profile.Name)
            foreach ($Field in $Profile.Value.PSObject.Properties) {
                Require (($Actual.($Field.Name) | ConvertTo-Json -Compress -Depth 15) -ceq
                         ($Field.Value | ConvertTo-Json -Compress -Depth 15)) ('Legacy full Windows reference mismatch: ' + $Profile.Name + '/' + $Field.Name)
            }
            foreach ($Field in @('bounds', 'cells', 'schema', 'recipe_sha256', 'material_sha256')) {
                Require (($Actual.$Field | ConvertTo-Json -Compress -Depth 15) -ceq
                         ($Portable.profiles.($Profile.Name).$Field | ConvertTo-Json -Compress -Depth 15)) ('Legacy portable material mismatch: ' + $Profile.Name + '/' + $Field)
            }
        }
    } else {
        Require ($Payload -match '^checks=([1-9][0-9]*) failures=0$') ($Case.name + ' lacks positive completion')
        $Data = @{checks = [int]$Matches[1]; failures = 0}
    }
    if ($Case.kind -in @('flatten', 'recovery')) {
        Require ($Data.completed -and $Data.side -eq 512 -and $Data.canonical_bytes -eq 524288) ($Case.name + ' did not finish the exact material-baseline case')
        Require ($Data.source_identity.display -ne 'headless') ($Case.name + ' was not graphical')
        if ($Data.phase -eq 'reopen') {
            $Author = $Receipts[$Case.group + '-author']
            Require ($null -ne $Author -and $Data.process_instance -ne $Author.process_instance -and $Data.pid -ne $Author.pid) 'Reopen reused author process'
            Require (($Data.source_identity | ConvertTo-Json -Compress -Depth 20) -ceq
                     ($Author.source_identity | ConvertTo-Json -Compress -Depth 20)) 'Reopen runtime/source identity differs'
            if ($Case.kind -eq 'recovery') {
                Require ($Author.expected_plane_sha256 -eq $Data.reconstructed_plane_sha256) 'Recovered native material plane differs'
                foreach ($Field in @('expected_plane_sha256', 'saved_baseline_sha256', 'saved_file_sha256')) {
                    Require ($Author.$Field -eq $Data.$Field) ('Recovery identity differs: ' + $Field)
                }
            }
        }
    }
    if ($Case.kind -eq 'combined') {
        Require ($Data.map_side -eq 512 -and $Data.source_identity.display -ne 'headless') 'Combined source/display/extent mismatch'
        $Complete = if ($Case.name.EndsWith('reopen')) { $Data.reopen_complete } else { $Data.author_complete }
        Require ([bool]$Complete) 'Combined PAINT/Agent authoring did not complete'
    }
    foreach ($Name in $Case.pngs) {
        $Path = Join-Path $Directory ('frames\' + $Name)
        Require (Test-Path -LiteralPath $Path) ('Required framebuffer missing: ' + $Name)
        $Bytes = [IO.File]::ReadAllBytes($Path)
        Require ($Bytes.Length -gt 8 -and [BitConverter]::ToString($Bytes[0..7]) -eq '89-50-4E-47-0D-0A-1A-0A') ('Invalid framebuffer PNG: ' + $Name)
    }
    return $Data
}

try {
    $Manifest = Verify-Package
    $Summary.windows = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber
    $Summary.gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object {
        @{name = $_.Name; driver = $_.DriverVersion; horizontal = $_.CurrentHorizontalResolution
          vertical = $_.CurrentVerticalResolution; refresh_hz = $_.CurrentRefreshRate}
    })
    Save-Summary
    $Import = Join-Path $Output 'import'
    [void](New-Item -ItemType Directory -Path $Import)
    $ImportEnv = @{APPDATA = (Join-Path $Output 'import-userdata'); XDG_DATA_HOME = (Join-Path $Output 'import-userdata')
                   CYBERSAND_SOURCE_REVISION = $Manifest.source_commit; CYBERSAND_EVAL_SOURCE_SHA = $Manifest.source_commit}
    [void](Execute-Godot 'import' @('--headless', '--audio-driver', 'Dummy', '--path', $Project, '--editor', '--quit') 240 $Import $ImportEnv)
    $Plan = Json (Join-Path $Root 'Test-Plan.json')
    Require ($Plan.schema -eq 'camera-stack-installed-test-plan-v1' -and @($Plan.cases).Count -ge 20) 'Incomplete test plan'
    foreach ($Case in $Plan.cases) {
        $Directory = Join-Path $CaseRoot $Case.name
        [void](New-Item -ItemType Directory -Path $Directory)
        $Row = [ordered]@{name = $Case.name; status = 'running'; graphical_requested = [bool]$Case.graphical}
        try {
            foreach ($Dependency in $Case.depends) {
                Require ($CaseResults.ContainsKey($Dependency) -and $CaseResults[$Dependency]) ('Required author phase failed: ' + $Dependency)
            }
            $UserData = Join-Path $Output ('userdata\' + $Case.group)
            [void](New-Item -ItemType Directory -Path $UserData -Force)
            $Environment = @{APPDATA = $UserData; XDG_DATA_HOME = $UserData; LOCALAPPDATA = (Join-Path $UserData 'local')
                             CYBERSAND_SOURCE_REVISION = $Manifest.source_commit; CYBERSAND_EVAL_SOURCE_SHA = $Manifest.source_commit}
            foreach ($Entry in $Case.env.PSObject.Properties) {
                $Value = ([string]$Entry.Value).Replace('{case}', $Directory).Replace('{output}', $Output)
                $Environment[$Entry.Name] = $Value
            }
            $Script = if ($Case.kind -eq 'legacy') { Join-Path $Root 'tools\architecture\capture_legacy.gd' } else { 'res://tests/' + $Case.script }
            $Arguments = @('--audio-driver', 'Dummy', '--path', $Project)
            if ($Case.graphical) { $Arguments += @('--rendering-method', 'gl_compatibility', '--rendering-driver', $RenderingDriver, '--max-fps', '60') }
            else { $Arguments += '--headless' }
            $Arguments += @('--script', $Script)
            if (@($Case.extra).Count -gt 0) { $Arguments += @('--') + @($Case.extra) }
            Write-Host ('RUN ' + $Case.name) -ForegroundColor Cyan
            $Text = Execute-Godot $Case.name $Arguments $Case.timeout_seconds $Directory $Environment
            $Data = Validate-Case $Case $Text $Directory
            $Receipts[$Case.name] = $Data
            $CaseResults[$Case.name] = $true
            $Row.status = 'passed'
            $Row.receipt = $Data
            Write-Host ('PASS ' + $Case.name) -ForegroundColor Green
        } catch {
            $CaseResults[$Case.name] = $false
            $Row.status = 'failed'
            $Row.error = [string]$_.Exception.Message
            $Summary.errors += ($Case.name + ': ' + $Row.error)
            Write-Host ('FAIL ' + $Case.name + ': ' + $Row.error) -ForegroundColor Red
        } finally {
            $Row.files_sha256 = @{}
            foreach ($File in @(Get-ChildItem -LiteralPath $Directory -File -Recurse)) {
                $Row.files_sha256[$File.FullName.Substring($Directory.Length + 1).Replace('\', '/')] = Digest $File.FullName
            }
            $Summary.cases += $Row
            Save-Summary
        }
    }
    [void](Verify-Package)
    $Summary.complete = ($Summary.errors.Count -eq 0 -and $Summary.cases.Count -eq @($Plan.cases).Count)
    $Summary.status = if ($Summary.complete) { 'passed' } else { 'failed' }
} catch {
    $Summary.errors += [string]$_.Exception.Message
    $Summary.status = 'failed'
    $Summary.complete = $false
    Write-Host ('TEST IT FAILED: ' + $_.Exception.Message) -ForegroundColor Red
} finally {
    Save-Summary
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $Zip = $Output + '.zip'
        [IO.Compression.ZipFile]::CreateFromDirectory($Output, $Zip, [IO.Compression.CompressionLevel]::Optimal, $true)
        Write-Host ('EVIDENCE ZIP: ' + $Zip) -ForegroundColor Cyan
        Write-Host ('ZIP SHA256: ' + (Digest $Zip))
    } catch { Write-Warning ('Evidence archive failed; original files remain at ' + $Output + ': ' + $_.Exception.Message) }
}
Write-Host ('CAMERA_STACK_TEST_IT ' + $Summary.status.ToUpperInvariant() + ' ' + $Summary.source_commit)
if (-not $Summary.complete) { exit 1 }
exit 0
