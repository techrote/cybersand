[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$Output,
    [switch]$PersistentOnly,
    [string]$Archive
)

# Execute the delivered top-level CMD files from a path containing spaces.
# Only the processes started here can be terminated by the owned watchdog.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath($Package).TrimEnd('\', '/')
$outputRoot = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $outputRoot) { throw 'Launcher evidence must be a new directory.' }
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestPath = Join-Path $packageRoot 'mainline-evaluation-manifest.json'
$manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
$reportPath = Join-Path $outputRoot 'launcher-proof.json'
$report = @{
    schema = 'cybersand-mainline-launcher-proof-v1'; status = 'running';
    source_commit = $manifest.source_commit;
    manifest_sha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant();
    cases = @{}; owner_playfeel_accepted = $false
}

function Write-Report {
    [IO.File]::WriteAllText($reportPath, (($report | ConvertTo-Json -Depth 12) + "`n"), $utf8)
}

function Invoke-DeliveredCmd([string]$Name, [string]$Filename, [string]$Arguments, [int]$Seconds) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $env:ComSpec
    $start.Arguments = '/d /s /c ""' + (Join-Path $packageRoot $Filename) + '" ' + $Arguments + '"'
    $start.WorkingDirectory = $packageRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['CYBERSAND_EVALUATOR_AUTOMATION'] = '1'
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $row = @{ status = 'running'; pid = $process.Id; timeout_seconds = $Seconds;
        launcher = $Filename; arguments = $Arguments; started_utc = $started.ToString('o') }
    $report.cases[$Name] = $row
    Write-Report
    $timedOut = !$process.WaitForExit($Seconds * 1000)
    if ($timedOut) {
        & (Join-Path $env:SystemRoot 'System32/taskkill.exe') /PID ([string]$process.Id) /T /F | Out-Null
        if (!$process.HasExited) { $process.Kill() }
        if (!$process.WaitForExit(30000)) {
            $row.status = 'failed'
            $row.error = 'Owned process did not retire within the cleanup allowance.'
            Write-Report
            throw $row.error
        }
    }
    $process.Refresh()
    # A parent can exit while a descendant still holds an inherited pipe. Never
    # block indefinitely on .Result after the process watchdog has completed.
    try {
        $drained = [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 30000)
    } catch {
        $drained = $false
        $row.output_drain_error = $_.Exception.Message
    }
    $stdoutText = if ($stdout.Status -eq [Threading.Tasks.TaskStatus]::RanToCompletion) { $stdout.Result } else { 'MAINLINE_STDOUT_DRAIN_INCOMPLETE' }
    $stderrText = if ($stderr.Status -eq [Threading.Tasks.TaskStatus]::RanToCompletion) { $stderr.Result } else { 'MAINLINE_STDERR_DRAIN_INCOMPLETE' }
    $stdoutPath = Join-Path $outputRoot ($Name + '-stdout.log')
    $stderrPath = Join-Path $outputRoot ($Name + '-stderr.log')
    [IO.File]::WriteAllText($stdoutPath, $stdoutText, $utf8)
    [IO.File]::WriteAllText($stderrPath, $stderrText, $utf8)
    $row.exit_code = $process.ExitCode
    $row.seconds = ([DateTime]::UtcNow - $started).TotalSeconds
    $row.stdout = $stdoutPath
    $row.stderr = $stderrPath
    $row.stdout_sha256 = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $row.stderr_sha256 = (Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $row.output_drain_complete = $drained
    $row.status = 'failed'
    Write-Report
    if ($timedOut) { throw "Delivered $Name launcher exceeded its owned $Seconds-second watchdog." }
    if (!$drained) { throw "Delivered $Name launcher left an unclosed output owner; qualification is incomplete." }
    $text = $stdoutText + $stderrText
    if ($process.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:|Fatal signal|Segmentation fault') {
        throw "Delivered $Name launcher failed; original evidence is retained."
    }
    if ($Name -eq 'workbench') {
        $markers = @($text -split '\r?\n' | Where-Object { $_.StartsWith('SHARED_WORKBENCH_LAUNCH_READY') })
        if ($markers.Count -ne 1) { throw 'Ordinary Workbench launch did not complete exactly once.' }
        $renderer = @($text -split '\r?\n' | Where-Object { $_ -match 'OpenGL.*ANGLE|ANGLE.*OpenGL' })
        if ($renderer.Count -lt 1) { throw 'Delivered ordinary Workbench did not prove actual Windows ANGLE initialization.' }
        $row.renderer_initialization = $renderer
    } elseif ($Name -eq 'persistent') {
        $markers = @($text -split '\r?\n' | Where-Object { $_.StartsWith('PERSISTENT_AREAS_READY ') })
        if ($markers.Count -ne 1 -or $text -notmatch 'OpenGL.*ANGLE|ANGLE.*OpenGL') {
            throw 'The delivered Persistent Areas launcher did not acknowledge native initialization and the ANGLE renderer.'
        }
        $row.ready = $markers[0].Substring('PERSISTENT_AREAS_READY '.Length) | ConvertFrom-Json
    } else {
        $markers = @($text -split '\r?\n' | Where-Object { $_.StartsWith('GOBLIN_PACKAGE_SELFTEST_PASS ') })
        if ($markers.Count -ne 1) { throw 'Delivered Goblin self-test did not complete exactly once.' }
        $goblinReport = [IO.Path]::GetFullPath($markers[0].Substring('GOBLIN_PACKAGE_SELFTEST_PASS '.Length))
        $allowed = (Join-Path $packageRoot 'workbench\test-output') + [IO.Path]::DirectorySeparatorChar
        if (!$goblinReport.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Goblin self-test receipt is outside its delivered disposable profile.'
        }
        $detail = [IO.File]::ReadAllText($goblinReport) | ConvertFrom-Json
        if ($detail.status -ne 'pass' -or $detail.graphical_smoke.status -ne 'pass') { throw 'Goblin graphical/package proof failed.' }
        $report.goblin_report = $goblinReport
        $report.goblin_report_sha256 = (Get-FileHash -LiteralPath $goblinReport -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $row.status = 'passed'
    Write-Report
}

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Actual Windows launcher proof is required.' }
    Write-Report
    if ($PersistentOnly) {
        $profile = Join-Path $packageRoot 'workbench/userdata/persistent-profile'
        if ('persistent_areas' -notin $manifest.integrated_features -or (Test-Path -LiteralPath $profile)) {
            throw 'The optional Persistent Areas launcher requires its shipped feature and a fresh profile.'
        }
        Invoke-DeliveredCmd 'persistent' 'Open Persistent Areas.cmd' '--audio-driver Dummy --max-fps 20 --quit-after 2400' ([int]$manifest.execution_budget.launcher_watchdogs.workbench)
        $row = $report.cases['persistent']
        $current = Join-Path $profile 'current.cypm'
        if ((Get-Item -LiteralPath $current).Length -gt 262144) { throw 'Persistent manifest exceeds the source capacity.' }
        $bytes = [IO.File]::ReadAllBytes($current)
        if ($bytes.Length -lt 52 -or [Text.Encoding]::ASCII.GetString($bytes, 0, 7) -cne 'CYSPROF' -or
            $bytes[7] -ne 0 -or [BitConverter]::ToUInt32($bytes, 8) -ne 1 -or
            [BitConverter]::ToUInt32($bytes, 12) -ne ($bytes.Length - 52) -or [BitConverter]::ToUInt32($bytes, 16) -ne 0) {
            throw 'The delivered launcher wrote an invalid persistence envelope.'
        }
        $hash = [Security.Cryptography.SHA256]::Create()
        try { $digest = $hash.ComputeHash($bytes, 52, $bytes.Length - 52) } finally { $hash.Dispose() }
        if ([BitConverter]::ToString($digest) -ne [BitConverter]::ToString($bytes, 20, 32)) { throw 'Persistent manifest digest mismatch.' }
        $state = [Text.Encoding]::UTF8.GetString($bytes, 52, $bytes.Length - 52) | ConvertFrom-Json
        if ($row.ready.session -cnotmatch '^[0-9a-f]{32}$' -or $row.ready.revision -lt 1 -or
            $row.ready.session -cne $state.session_id -or $row.ready.revision -gt $state.revision -or
            ($state.areas.PSObject.Properties.Name | Sort-Object) -join ',' -cne 'a,b,c') {
            throw 'Persistent launch acknowledgement or durable area roster differs from disk.'
        }
        $areaHashes = @{}
        foreach ($id in @('a','b','c')) {
            $record = $state.areas.$id
            if ($record.blob -cnotmatch ('^area-' + $id + '-[0-9a-f]{32}\.cypa$') -or $record.area_id -cne $id) {
                throw 'Unsafe or mismatched persistent area record.'
            }
            $areaHashes[$id] = (Get-FileHash -LiteralPath (Join-Path $profile $record.blob) -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($record.sha256 -cne $areaHashes[$id]) { throw 'Persisted area content differs from the acknowledged manifest.' }
        }
        $receipt = @{
            schema = 'cybersand-mainline-persistent-launcher-v1'; status = 'passed'; source_commit = $manifest.source_commit
            archive_sha256 = (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant(); manifest_sha256 = $report.manifest_sha256
            run_id = $env:GITHUB_RUN_ID; run_attempt = $env:GITHUB_RUN_ATTEMPT; launcher = $row.launcher; exit_code = $row.exit_code
            durable_areas = $areaHashes.Count; durable_blobs_sha256 = $areaHashes; session_id = $state.session_id; revision = $state.revision
            active_area = $row.ready.area; renderer = 'ANGLE'; stdout_sha256 = $row.stdout_sha256; stderr_sha256 = $row.stderr_sha256
        }
        [IO.File]::WriteAllText((Join-Path $outputRoot 'persistent-launcher.json'), (($receipt | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $utf8)
        $report.status = 'passed'
        Write-Report
        exit 0
    }
    if ($manifest.execution_budget.schema -ne 'cybersand-mainline-evaluator-budget-v1' -or
        $manifest.execution_budget.parent_minutes -ne 360 -or $manifest.execution_budget.total_seconds -gt 21600) {
        throw 'Source-derived complete package execution budget is missing or exceeds the parent.'
    }
    # Hosted Windows workers have no physical audio endpoint. Use the same
    # explicit silent backend as the original AMBIENT graphics proof while
    # retaining the delivered CMD, actual ANGLE renderer and strict error gate.
    Invoke-DeliveredCmd 'workbench' 'Open Workbench.cmd' '--audio-driver Dummy --quit-after 180' ([int]$manifest.execution_budget.launcher_watchdogs.workbench)
    # This fixed option executes the unchanged feature launcher's two actual
    # gameplay/reopen campaigns and its ANGLE scene, without interactive waiting.
    Invoke-DeliveredCmd 'goblin' 'Open Goblin.cmd' '-Mode SelfTest -GraphicalSmoke' ([int]$manifest.execution_budget.launcher_watchdogs.goblin)
    $report.status = 'passed'
    Write-Report
    Write-Host "MAINLINE_LAUNCHERS_PASS $reportPath"
    # An invoked PowerShell script must publish its successful exit explicitly;
    # .NET Process.ExitCode does not set the caller's LASTEXITCODE variable.
    exit 0
} catch {
    $report.status = 'failed'
    $report.error = $_.Exception.Message
    Write-Report
    throw
}
