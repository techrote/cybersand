[CmdletBinding()]
param([switch]$Quick, [ValidateSet('','opengl3','opengl3_angle')][string]$RenderingDriver='')

# Windows PowerShell 5.1; uses only the packaged Godot and operating system.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$manifestPath = Join-Path $root 'RENDER-UPLOAD-577-MANIFEST.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'render-upload-577-windows-v1') { throw 'Unexpected package manifest.' }

function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 50) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Get-Quantiles($Values) {
    $ordered = @($Values | ForEach-Object { [double]$_ } | Sort-Object)
    if ($ordered.Count -eq 0) { return @{count=0} }
    return [ordered]@{
        count=$ordered.Count
        p50=$ordered[[Math]::Max(0,[Math]::Ceiling($ordered.Count*0.50)-1)]
        p95=$ordered[[Math]::Max(0,[Math]::Ceiling($ordered.Count*0.95)-1)]
        p99=$ordered[[Math]::Max(0,[Math]::Ceiling($ordered.Count*0.99)-1)]
        maximum=$ordered[-1]
    }
}

# Authenticate before starting any timed process. Keep package source and
# dependency identities in the portable evidence; don't copy old results in.
foreach ($property in $manifest.files_sha256.PSObject.Properties) {
    $file = Join-Path $root $property.Name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or
        (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $property.Value) {
        throw ('Package file missing or changed: ' + $property.Name)
    }
}
. (Join-Path $PSScriptRoot 'Validate-Health.ps1')
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$output = Join-Path $root ('Test-It-Results\' + $stamp)
New-Item -ItemType Directory -Path $output | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $output 'package-manifest.json')
$hardware = [ordered]@{source=$manifest.source_commit; tree=$manifest.source_tree; started_utc=(Get-Date).ToUniversalTime().ToString('o'); quick=[bool]$Quick; requested_rendering_driver=$RenderingDriver}
try { $hardware.cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors) } catch { $hardware.cpu_error=$_.Exception.Message }
try { $hardware.gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate) } catch { $hardware.gpu_error=$_.Exception.Message }
$hardware.windows = [Environment]::OSVersion.VersionString
$hardware.powershell = $PSVersionTable.PSVersion.ToString()
Write-Json (Join-Path $output 'hardware.json') $hardware

$cases = @(
    @{name='sparse';size=2048;workers=1;family='freemass_v1'},
    @{name='manual';size=2048;workers=1;family='freemass_v1'},
    @{name='dense';size=2048;workers=1;family='freemass_v1'}
)
if (-not $Quick) {
    $cases += @(
        @{name='full';size=2048;workers=1;family='freemass_v1'},
        @{name='active';size=2048;workers=1;family='freemass_v1'},
        @{name='active';size=2048;workers=4;family='freemass_v1'},
        @{name='active';size=2048;workers=4;family='pressure_flow_v1';fixture='pressure_dam_v1'},
        @{name='actor';size=1024;workers=1;family='freemass_v1'},
        @{name='manual';size=1024;workers=1;family='freemass_v1';ack='delayed150'},
        @{name='manual';size=1024;workers=1;family='freemass_v1';ack='withheld'}
    )
}
foreach ($case in $cases) {
    if (-not $case.ContainsKey('ack')) { $case.ack='normal' }
    if (-not $case.ContainsKey('fixture')) { $case.fixture='workload_v1' }
}
$frames = 180
$engine = Join-Path $root 'Godot_v4.7-stable_win64_console.exe'
$project = Join-Path $root 'godot'
$rows = [Collections.Generic.List[object]]::new()
$failure = $null
$failureHealth = $null
$oldVariables = @{}
$variableNames = @('CYBERSAND_SOURCE_REVISION','CYBERSAND_SOURCE_SHA','APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME')
foreach ($name in $variableNames) { $oldVariables[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
try {
    $env:CYBERSAND_SOURCE_REVISION = $manifest.source_commit
    $env:CYBERSAND_SOURCE_SHA = $manifest.source_commit
    $importLog = Join-Path $output 'import.log'
    $importErrors = Join-Path $output 'import-stderr.log'
    # Native stderr redirection through PS5.1's pipeline can turn harmless
    # engine warnings into terminating NativeCommandError records.
    $importProcess = Start-Process -FilePath $engine -ArgumentList @('--headless','--audio-driver','Dummy','--path',('"'+$project+'"'),'--editor','--quit') -WorkingDirectory $root -PassThru -RedirectStandardOutput $importLog -RedirectStandardError $importErrors
    # PS5.1 redirected Start-Process can otherwise lose its exit-code handle:
    # https://github.com/PowerShell/PowerShell/issues/5421
    $importHandle = $importProcess.Handle
    if ($null -eq $importHandle -or $importHandle -eq [IntPtr]::Zero) { throw 'Cannot retain the import process handle.' }
    if (-not $importProcess.WaitForExit(300000)) {
        & taskkill.exe /PID $importProcess.Id /T /F | Out-Null
        throw 'Project import timed out.'
    }
    $importProcess.Refresh()
    $importText = (Get-Content -LiteralPath $importLog -Raw) + (Get-Content -LiteralPath $importErrors -Raw)
    Write-Json (Join-Path $output 'import-process.json') @{exit_code=$importProcess.ExitCode;stdout='import.log';stderr='import-stderr.log'}
    if ($importProcess.ExitCode -ne 0 -or $importText -match 'SCRIPT ERROR:|Parse Error:|Failed to load script') {
        Write-Host ($importText.Substring([Math]::Max(0,$importText.Length-6000)))
        throw ('Project import failed with exit '+$importProcess.ExitCode+'. Original stdout/stderr are retained.')
    }
    foreach ($case in $cases) {
        $phase = 0
        foreach ($strategy in @('full','hybrid','hybrid','full')) {
            $label = '{0}_{1}_w{2}_{3}_{4}_ack_{5}-{6}-{7}' -f $case.name,$case.size,$case.workers,$case.family,$case.fixture,$case.ack,$phase,$strategy
            Write-Host ('Collecting ' + $label)
            $folder = Join-Path $output $label
            New-Item -ItemType Directory -Path $folder | Out-Null
            foreach ($name in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME')) {
                $path = Join-Path $folder ('userdata\' + $name)
                New-Item -ItemType Directory -Path $path -Force | Out-Null
                [Environment]::SetEnvironmentVariable($name,$path,'Process')
            }
            $jsonPath = Join-Path $folder 'runtime.json'
            $stdout = Join-Path $folder 'stdout.log'
            $stderr = Join-Path $folder 'stderr.log'
            # Paths are quoted for Start-Process's Windows command-line joining.
            $arguments = @('--audio-driver','Dummy','--rendering-method','gl_compatibility')
            if ($RenderingDriver) { $arguments += @('--rendering-driver',$RenderingDriver) }
            $arguments += @('--path',('"'+$project+'"'),
                '--script','res://tests/run_render_upload_577_benchmark.gd','--',
                ('--strategy='+$strategy),('--render-upload='+$strategy),('--size='+$case.size),
                ('--workers='+$case.workers),('--family='+$case.family),('--workload='+$case.name),
                ('--ack='+$case.ack),
                ('--fixture='+$case.fixture),
                ('--frames='+$frames),'--warmup=30','--channels=2',('--output="'+$jsonPath+'"'))
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $process = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $root -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
            $captureHandle = $process.Handle
            if ($null -eq $captureHandle -or $captureHandle -eq [IntPtr]::Zero) { throw ('Cannot retain capture process handle: '+$label) }
            $timedOut = $false
            try {
                while (-not $process.WaitForExit(250)) {
                    if ($watch.Elapsed.TotalSeconds -gt 1800) { $timedOut=$true; break }
                }
            } finally {
                if (-not $process.HasExited) {
                    & taskkill.exe /PID $process.Id /T /F | Out-Null
                    $process.WaitForExit()
                }
                $process.Refresh()
            }
            $processReceipt = [ordered]@{command=@($engine)+$arguments; elapsed_seconds=$watch.Elapsed.TotalSeconds; exit_code=$process.ExitCode; timed_out=$timedOut}
            Write-Json (Join-Path $folder 'process.json') $processReceipt
            $text = (Get-Content -LiteralPath $stdout -Raw) + (Get-Content -LiteralPath $stderr -Raw)
            if ($timedOut -or $process.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR:|Parse Error:|Failed to load script|(?m)^ERROR:') {
                if (Test-Path -LiteralPath $jsonPath) {
                    $failedReceipt = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
                    if ($failedReceipt.PSObject.Properties.Name -contains 'native_health') { $failureHealth=$failedReceipt.native_health }
                }
                throw ('Capture failed: '+$label+'; original stdout/stderr and any native health receipt are retained.')
            }
            if (-not (Test-Path -LiteralPath $jsonPath)) { throw ('Capture receipt missing: '+$label) }
            $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
            if (-not $data.ok -or $data.failures.Count -ne 0 -or $data.frames.Count -ne $frames -or
                $data.context.source_revision -ne $manifest.source_commit -or
                $data.final_strategy.active -ne $strategy -or -not $data.final_current_texture_matches_cpu -or
                $data.context.display_server -eq 'headless') { throw ('Capture identity/correctness failed: '+$label) }
            if ($RenderingDriver -and $data.context.backend -ne $RenderingDriver) { throw ('Capture backend differs: '+$label) }
            $expectedCase = @{size=$case.size;workload=$case.name;workers=$case.workers;family=$case.family;
                              channels=2;ack=$case.ack;fixture=$case.fixture}
            Assert-RenderUploadRequestedCase $data $expectedCase $strategy
            Assert-RenderUploadHealth $data
            $preparation = $data.shader_preparation
            if (($preparation | ConvertTo-Json -Depth 50 -Compress) -ne
                ($data.shader_preparation_at_measurement | ConvertTo-Json -Depth 50 -Compress)) {
                throw ('Shader preparation changed inside the measured window: '+$label)
            }
            $preparationMs = 0.0
            $preparationRuns = 0
            if ($strategy -eq 'hybrid' -and $data.cohort -eq 'mounted_native_workbench') {
                if (-not $preparation.prepared -or $preparation.error -or $preparation.runs -lt 1 -or
                    $preparation.total_initialization_usec -lt $preparation.initialization_usec -or
                    $preparation.initialization_usec -le 0 -or $preparation.total_initialization_usec -gt $data.setup_ms*1000.0) {
                    throw ('Shader preparation/cost receipt failed: '+$label)
                }
                $preparationMs = $preparation.total_initialization_usec / 1000.0
                $preparationRuns = $preparation.runs
            } elseif (@($preparation.PSObject.Properties).Count -ne 0) {
                throw ('Unexpected baseline/detached shader preparation: '+$label)
            }
            $row = [ordered]@{case=$case;phase=$phase;strategy=$strategy;folder=$label; setup_ms=$data.setup_ms;benchmark_elapsed_ms=$data.elapsed_ms;process_elapsed_ms=$processReceipt.elapsed_seconds*1000.0;shader_preparation_ms=$preparationMs;shader_preparation_runs=$preparationRuns;frame_ms=(Get-Quantiles @($data.frames | ForEach-Object {$_.frame_ms})); publication_ms=(Get-Quantiles @($data.uploads | ForEach-Object {$_.upload_ms})); submission_ms=(Get-Quantiles @($data.uploads | ForEach-Object {$_.submit_ms}));material_age_ms=(Get-Quantiles @($data.frames | Where-Object {$null -ne $_.displayed_material_age_ms} | ForEach-Object {$_.displayed_material_age_ms}))}
            foreach ($key in @('observed_ticks_per_second','rapier_steps_per_second','accepted_updates_per_second','transport_full_publications','native_full_refreshes')) {
                if ($data.PSObject.Properties.Name -contains $key) { $row[$key]=$data.$key }
            }
            $rows.Add($row)
            Write-Json (Join-Path $output 'summary.json') @{complete=$false;arms=@($rows.ToArray());limits='CPU durations are not GPU completion. Readbacks occur after timing. Physical acceptance remains owner-gated.'}
            $phase++
        }
    }
} catch {
    $failure = $_.Exception.Message
    Write-Host ('Capture stopped: ' + $failure)
} finally {
    foreach ($name in $variableNames) { [Environment]::SetEnvironmentVariable($name,$oldVariables[$name],'Process') }
    Write-Json (Join-Path $output 'summary.json') @{complete=($null -eq $failure -and $rows.Count -eq $cases.Count*4);failure=$failure;native_health_failure=$failureHealth;arms=@($rows.ToArray());limits='Sequential same-host ABBA. CPU duration is not GPU time or scanout. Shader caches and asynchronous native progress are recorded in raw receipts.'}
    $report = @('CyberSand material publication comparison',('Source '+$manifest.source_commit),'','Per-arm milliseconds (read with native/physics cadence and material age):')
    foreach ($row in $rows) {
        $report += ('{0}: frame p50 {1:N3}, p95 {2:N3}, p99 {3:N3}, max {4:N3}; publication p95 {5:N3}' -f $row.folder,$row.frame_ms.p50,$row.frame_ms.p95,$row.frame_ms.p99,$row.frame_ms.maximum,$row.publication_ms.p95)
        $report += ('  Setup {0:N1} ms, including shader preparation {1:N1} ms across {2} runs; complete process {3:N1} ms.' -f $row.setup_ms,$row.shader_preparation_ms,$row.shader_preparation_runs,$row.process_elapsed_ms)
    }
    $report += @('',('Failure: '+$failure),'Full source/runtime/hardware identities and raw observations accompany this file. Hosted or automatic completion does not establish physical smoothness acceptance.')
    [IO.File]::WriteAllLines((Join-Path $output 'READ-RESULTS.txt'),$report,[Text.UTF8Encoding]::new($false))
    # Caches are reproducible, large, and outside the scientific observations.
    Get-ChildItem -LiteralPath $output -Directory | ForEach-Object {
        $cache = Join-Path $_.FullName 'userdata'
        if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache -Recurse -Force }
    }
    $zip = $output + '.zip'
    Compress-Archive -Path (Join-Path $output '*') -DestinationPath $zip
    Write-Host ('Evidence: '+$zip)
}
if ($null -ne $failure) { exit 1 }
