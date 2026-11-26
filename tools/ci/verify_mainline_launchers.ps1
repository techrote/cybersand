[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][string]$Output
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
