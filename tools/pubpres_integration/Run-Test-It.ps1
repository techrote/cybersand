[CmdletBinding()]
param(
    [switch]$Quick,
    [switch]$Extended,
    [string]$Case = '',
    [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver = 'opengl3',
    [ValidateSet('safe','separate')][string]$RenderThread = 'safe',
    [ValidateRange(60,1800)][int]$TimeoutSeconds = 900
)

# Windows PowerShell 5.1 and in-box modules only. Every arm gets its own
# process, profile, and immutable request receipt before the first launch.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($Name in @('Microsoft.PowerShell.Management','Microsoft.PowerShell.Utility','CimCmdlets','Microsoft.PowerShell.Archive')) {
    Import-Module -Name (Join-Path $PSHOME "Modules\$Name\$Name.psd1") -Force
}

. (Join-Path $PSScriptRoot 'Read-Results.ps1')
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$PackageProject = Join-Path $Root 'godot'
$Engine = Join-Path $Root 'Godot_v4.7-stable_win64_console.exe'
$ManifestPath = Join-Path $Root 'PUBPRES-MANIFEST.json'
$CampaignPath = Join-Path $PSScriptRoot 'campaign.json'
$Manifest = Read-Json $ManifestPath
Assert-Result ($Manifest.schema -eq 'pubpres-integration-windows-v1') 'Unknown package manifest'
foreach ($Entry in $Manifest.files_sha256.PSObject.Properties) {
    Assert-Result ($Entry.Name -notmatch '(^|/)\.\.(/|$)|\\|:|^/') "Invalid payload path $($Entry.Name)"
    $File = Join-Path $Root $Entry.Name
    Assert-Result ((Test-Path -LiteralPath $File -PathType Leaf) -and (Get-Sha $File) -eq $Entry.Value) "Package file missing or changed: $($Entry.Name)"
}
$Campaign = Read-Json $CampaignPath
Assert-Result ($Campaign.schema -eq 'pubpres-integration-campaign-v1' -and ($Campaign.order -join '') -ceq 'ABBA') 'Unknown or unbalanced campaign'
Assert-Result (@($Campaign.cases | Where-Object { $_.id -eq 'transition_2048_w1' -and $_.campaign -eq 'ordinary'}).Count -eq 1) 'Ordinary campaign must include transition_2048_w1'
Assert-Result (-not ($Quick -and $Extended) -and -not ($Case -and ($Quick -or $Extended))) 'Select one campaign mode'
$Cases = @($Campaign.cases | Where-Object {
    if ($Case) { $_.id -eq $Case }
    elseif ($Quick) { (Get-Field $_ 'quick' $false) }
    elseif ($Extended) { $true }
    else { $_.campaign -eq 'ordinary' }
})
Assert-Result ($Cases.Count -gt 0) 'No matching campaign cases'
$Stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$Output = Join-Path $Root "Test-It-Results\$Stamp"
[void][IO.Directory]::CreateDirectory($Output)
$Project = Join-Path $Output 'project'
$Results = [Collections.Generic.List[object]]::new()
$Failures = [Collections.Generic.List[object]]::new()
Copy-Item -LiteralPath $ManifestPath -Destination (Join-Path $Output 'package-manifest.json')
Copy-Item -LiteralPath $CampaignPath -Destination (Join-Path $Output 'campaign.json')
Copy-Item -LiteralPath (Join-Path $Root 'ACCEPTANCE.md') -Destination (Join-Path $Output 'acceptance-at-start.md')
$Hardware = [ordered]@{ source=$Manifest.source_commit; tree=$Manifest.source_tree; windows=[Environment]::OSVersion.VersionString
    started_utc=(Get-Date).ToUniversalTime().ToString('o'); powershell=$PSVersionTable.PSVersion.ToString() }
try { $Hardware.cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors) } catch { $Hardware.cpu_error=$_.Exception.Message }
try { $Hardware.gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate) } catch { $Hardware.gpu_error=$_.Exception.Message }
try { $Hardware.os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber } catch { $Hardware.os_error=$_.Exception.Message }
Write-Json (Join-Path $Output 'hardware.json') $Hardware
Write-Json (Join-Path $Output 'request.json') ([ordered]@{
    source=$Manifest.source_commit; tree=$Manifest.source_tree; parent=$Manifest.parent; accepted_main=$Manifest.accepted_main
    native=$Manifest.native; rapier=$Manifest.rapier; campaign_sha256=(Get-Sha $CampaignPath)
    package_manifest_sha256=(Get-Sha $ManifestPath); order=$Campaign.order; arms=$Campaign.arms; cases=$Cases
    rendering_driver=$RenderingDriver; render_thread=$RenderThread; timeout_seconds=$TimeoutSeconds
})

function Start-Capture([string]$Folder, [string[]]$Arguments, $Settings, [int]$Limit) {
    [void][IO.Directory]::CreateDirectory($Folder)
    $Info = [Diagnostics.ProcessStartInfo]::new()
    $Info.FileName = $Engine
    $Info.WorkingDirectory = $Root
    $Info.UseShellExecute = $false
    $Info.RedirectStandardOutput = $true
    $Info.RedirectStandardError = $true
    $Info.CreateNoWindow = $true
    $Info.Arguments = ($Arguments | ForEach-Object {
        Assert-Result (-not $_.Contains('"')) 'Unexpected quote in application argument'
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }) -join ' '
    foreach ($Name in @($Info.EnvironmentVariables.Keys)) {
        if ($Name -match '^CYBERSAND_') { $Info.EnvironmentVariables.Remove($Name) }
    }
    foreach ($Name in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME')) {
        $ProfilePath = Join-Path $Folder "profile\$Name"
        [void][IO.Directory]::CreateDirectory($ProfilePath)
        $Info.EnvironmentVariables[$Name] = $ProfilePath
    }
    foreach ($Name in $Settings.Keys) { $Info.EnvironmentVariables[$Name] = [string]$Settings[$Name] }
    $Info.EnvironmentVariables['CYBERSAND_SOURCE_REVISION'] = $Manifest.source_commit
    $Info.EnvironmentVariables['CYBERSAND_SOURCE_SHA'] = $Manifest.source_commit
    $Watch = [Diagnostics.Stopwatch]::StartNew()
    $Process = [Diagnostics.Process]::Start($Info)
    $Stdout = $Process.StandardOutput.ReadToEndAsync()
    $Stderr = $Process.StandardError.ReadToEndAsync()
    $PeakWorkingSet = $null
    $PeakPrivate = $null
    $CpuTime = $null
    $TimedOut = $false
    $AppProcess = $null
    $AppPid = $null
    $Discovery = 0
    try {
        while (-not $Process.WaitForExit(200)) {
            if ($Watch.Elapsed.TotalSeconds -gt $Limit) {
                $TimedOut = $true
                & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $Process.Id /T /F | Out-Null
                break
            }
            try {
                # The Windows console launcher is a small forwarding wrapper.
                # Bind observations to its actual Godot child, verified again
                # against the runtime receipt, before reporting process memory.
                if ($null -eq $AppProcess -and $Discovery -lt 3) {
                    $Discovery++
                    $Child = @(Get-CimInstance -ClassName Win32_Process -Filter ('ParentProcessId = ' + $Process.Id) |
                        Where-Object { $_.Name -eq 'Godot_v4.7-stable_win64.exe' })
                    if ($Child.Count -eq 1) {
                        $AppProcess = [Diagnostics.Process]::GetProcessById($Child[0].ProcessId)
                        $AppPid = $AppProcess.Id
                    }
                }
                if ($null -ne $AppProcess) {
                    $AppProcess.Refresh()
                    $PeakWorkingSet = [Math]::Max([long]$PeakWorkingSet,$AppProcess.PeakWorkingSet64)
                    $PeakPrivate = [Math]::Max([long]$PeakPrivate,$AppProcess.PrivateMemorySize64)
                    $CpuTime = $AppProcess.TotalProcessorTime.TotalMilliseconds
                }
            } catch { }
        }
        Assert-Result ($Process.WaitForExit(10000)) 'Application process did not terminate'
        $LogsRead = [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($Stdout,$Stderr),10000)
        Assert-Result $LogsRead 'Application output stream did not close'
        $Text = $Stdout.Result
        $Errors = $Stderr.Result
        [IO.File]::WriteAllText((Join-Path $Folder 'stdout.log'),$Text)
        [IO.File]::WriteAllText((Join-Path $Folder 'stderr.log'),$Errors)
        $Receipt = [ordered]@{ pid=$Process.Id; command=@($Engine)+$Arguments; elapsed_seconds=$Watch.Elapsed.TotalSeconds
            exit_code=$Process.ExitCode; timed_out=$TimedOut; sampled_peak_working_set_bytes=$PeakWorkingSet
            sampled_peak_private_bytes=$PeakPrivate; last_sampled_process_cpu_ms=$CpuTime; observed_application_pid=$AppPid }
        Write-Json (Join-Path $Folder 'process.json') $Receipt
        Assert-Result (-not $TimedOut -and $Process.ExitCode -eq 0 -and (($Text+$Errors) -notmatch 'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|Unhandled XServer error|Error initializing GLAD|MakeCurrent failed')) "Application failed in $Folder; original process output is retained"
        return $Receipt
    } finally {
        if ($null -ne $AppProcess) { $AppProcess.Dispose() }
        $Process.Dispose()
    }
}

function Run-Arm($Scenario, [string]$Letter, [int]$Index) {
    $Arm = Get-Field $Campaign.arms $Letter
    $Folder = Join-Path $Output "$($Scenario.id)\$Index-$Letter"
    [void][IO.Directory]::CreateDirectory($Folder)
    $Receipt = Join-Path $Folder 'receipt.json'
    $Nonce = [Guid]::NewGuid().ToString('N')
    $Settings = @{
        CYBERSAND_MATERIAL_PUBLICATION=$Arm.material; CYBERSAND_DIAG_PHYSICS_PUBLICATION=$Arm.physics
        CYBERSAND_DIAG_NATIVE_RENDEZVOUS=$Arm.rendezvous; CYBERSAND_DIAG_COMMON_OBSERVER='0'
        CYBERSAND_DIAG_MATERIAL_TIMING=$Arm.timing
        CYBERSAND_SHADER_NONCE=$Nonce; CYBERSAND_SHADER_CACHE_STATE='isolated-process-profile'
    }
    $Arguments = @('--path',$Project,'--rendering-method','gl_compatibility','--rendering-driver',$RenderingDriver,
        '--render-thread',$RenderThread,'--audio-driver','Dummy','--log-file',(Join-Path $Folder 'godot.log'),'--script')
    if ($Scenario.kind -eq 'transition') {
        $Arguments += @('res://tests/pubpres_transition.gd','--',"--material=$($Arm.material)","--receipt=$Receipt")
    } else {
        $Repeat = if ($Index -in 0,1) { 1 } else { 2 }
        $Fps = if ($Scenario.profile -eq 'interactive-default') { 0 } else { 60 }
        $Arguments += @('res://tests/pubpres_physical.gd','--','--engine-lab-scripted',"--family=$($Scenario.family)",
            "--workers=$($Scenario.workers)","--repeat=$Repeat","--camera=$($Scenario.camera)",'--pose=guarded',
            "--pixel-hz=$($Scenario.pixel_hz)",'--publication-hz=60',"--fps=$Fps",'--rapier-hz=60',
            "--ack-delay=$($Scenario.ack_delay)",'--ack-gated=0','--wait-sample=1','--sample-wake=1',
            '--smoothing=1','--cadence=repaired','--cadence-tape=1',"--presentation=$($Arm.presentation)",
            '--fire-mode=on-off',"--display-profile=$($Scenario.profile)","--receipt=$Receipt")
        $Law = Get-Field $Scenario 'water_law'
        if ($Law) { $Arguments += "--water-law=$Law" }
    }
    Write-Json (Join-Path $Folder 'arm.json') @{ scenario=$Scenario; arm=$Arm; order_index=$Index; nonce=$Nonce; selectors=$Settings; args=$Arguments }
    Write-Host "$($Scenario.id) | $Letter ($($Index+1)/4)"
    $Process = Start-Capture $Folder $Arguments $Settings $TimeoutSeconds
    $Data = Read-Json $Receipt
    if ($Scenario.kind -eq 'transition') {
        $Stats = Read-Transition $Data $Folder $Manifest $Arm $RenderingDriver $Nonce
    } else {
        $Stats = Read-Physical $Data $Folder $Manifest $Campaign.geometry $Scenario $Arm $RenderingDriver $RenderThread $Repeat $Nonce
    }
    $Process['app_sampler_pid_matched'] = $Process.observed_application_pid -eq $Stats.process_id
    if (-not $Process.app_sampler_pid_matched) {
        $Process.sampled_peak_working_set_bytes = $null
        $Process.sampled_peak_private_bytes = $null
        $Process.last_sampled_process_cpu_ms = $null
    }
    Write-Json (Join-Path $Folder 'process.json') $Process
    Write-Json (Join-Path $Folder 'analysis.json') $Stats
    return [ordered]@{ arm=$Letter; index=$Index; process=$Process; statistics=$Stats; receipt_sha256=(Get-Sha $Receipt) }
}

try {
    # Godot's editor can regenerate import sidecars and bootstrap metadata.
    # Keep the package intact for repeated hash-verified launches and tests.
    Copy-Item -LiteralPath $PackageProject -Destination $Project -Recurse
    $null = Start-Capture (Join-Path $Output 'import') @('--headless','--audio-driver','Dummy','--path',$Project,'--editor','--quit') @{} 300
    foreach ($Scenario in $Cases) {
        $Arms = [Collections.Generic.List[object]]::new()
        for ($Index = 0; $Index -lt $Campaign.order.Count; $Index++) {
            try { $Arms.Add((Run-Arm $Scenario $Campaign.order[$Index] $Index)) }
            catch {
                $Failures.Add(@{ scenario=$Scenario.id; index=$Index; reason=$_.Exception.Message })
                Write-Host "Arm incomplete: $($_.Exception.Message)"
            }
        }
        try { Assert-Matched $Arms.ToArray() }
        catch { $Failures.Add(@{ scenario=$Scenario.id; reason=$_.Exception.Message }) }
        $Results.Add(@{ scenario=$Scenario.id; scope=$Scenario.kind; arms=$Arms.ToArray() })
        Write-Json (Join-Path $Output 'summary.json') @{ complete=$false; cases=$Results.ToArray(); failures=$Failures.ToArray() }
    }
} catch { $Failures.Add(@{ reason=$_.Exception.Message }) }
finally {
    $Complete = $Failures.Count -eq 0 -and $Results.Count -eq $Cases.Count
    Write-Json (Join-Path $Output 'summary.json') ([ordered]@{ complete=$Complete; physical_acceptance='HOLD'; cases=$Results.ToArray(); failures=$Failures.ToArray()
        meaning='Complete means the requested captures and source/receipt checks ran. Diagnostics use CPU/API wall clocks and available driver reports. No hardware presentation acceptance is inferred.' })
    $Lines = [Collections.Generic.List[string]]::new()
    $Lines.Add("Capture complete: $Complete | Physical acceptance: HOLD | $($Manifest.source_commit)")
    foreach ($Row in $Results) {
        foreach ($Arm in $Row.arms) {
            $Stats = $Arm.statistics
            $Frame = $Stats.frame_ms
            $Gap = Get-Field $Stats 'physical_gap_ms'
            $Lines.Add(('{0} {1}{2} | frame p50/p95/p99/max {3:N2}/{4:N2}/{5:N2}/{6:N2} ms' -f $Row.scenario,$Arm.arm,$Arm.index,$Frame.p50,$Frame.p95,$Frame.p99,$Frame.max))
            $Treatment = $Stats.material_treatment
            $Policy = if ($Treatment.policy) { " ($($Treatment.policy))" } else { '' }
            $Lines.Add("  material requested=$($Treatment.requested) actual=$($Treatment.backend)$Policy")
            if ($null -ne $Gap) { $Lines.Add(('  physical gaps {0:N2}/{1:N2}/{2:N2}/{3:N2} ms | native={4:N2}/s Rapier={5:N2}/s uploads={6:N2}/s' -f $Gap.p50,$Gap.p95,$Gap.p99,$Gap.max,$Stats.native_ticks_per_second,$Stats.rapier_steps_per_second,$Stats.publications_per_second)) }
        }
    }
    foreach ($Problem in $Failures) { $Lines.Add("INCOMPLETE $($Problem.reason)") }
    [IO.File]::WriteAllLines((Join-Path $Output 'READ-RESULTS.txt'),$Lines)
    Write-Host "Results: $Output"
    & (Join-Path $PSScriptRoot 'Pack-Results.ps1') -RunDirectory $Output
}
if (-not $Complete) { exit 1 }
