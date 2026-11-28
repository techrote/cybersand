[CmdletBinding()]
param(
    [switch]$Quick,
    [switch]$Extended,
    [string]$Case = '',
    [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver = 'opengl3',
    [ValidateSet('safe','separate')][string]$RenderThread = 'safe',
    [ValidateRange(120,1800)][int]$TimeoutSeconds = 900
)

# Portable Windows PowerShell 5.1: no installed Git, Python or Godot.
# All package sources remain immutable. Only isolated test copies get the
# identical registered observation overlay and Godot-generated import files.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($Name in @('Microsoft.PowerShell.Management','Microsoft.PowerShell.Utility','CimCmdlets','Microsoft.PowerShell.Archive')) {
    Import-Module -Name (Join-Path $PSHOME "Modules\$Name\$Name.psd1") -Force
}
. (Join-Path $PSScriptRoot 'Read-Results.ps1')
. (Join-Path $PSScriptRoot 'Read-Source-Results.ps1')
. (Join-Path $PSScriptRoot 'Read-Source-Transition.ps1')
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Engine = Join-Path $Root 'Godot_v4.7-stable_win64_console.exe'
$ManifestPath = Join-Path $Root 'PUBPRES-MANIFEST.json'
$CampaignPath = Join-Path $PSScriptRoot 'source_campaign.json'
$Manifest = Read-Json $ManifestPath
$Campaign = Read-Json $CampaignPath
Assert-Result ($Manifest.schema -eq 'pubpres-integration-windows-v1') 'Unknown package manifest'
Assert-Result ($Campaign.schema -eq 'pubpres-source-campaign-v1' -and ($Campaign.order -join '') -ceq 'MICCIM') 'Unknown or unbalanced source campaign'
Assert-Result (-not ($Quick -and $Extended) -and -not ($Case -and ($Quick -or $Extended))) 'Select one source campaign mode'
foreach ($Entry in $Manifest.files_sha256.PSObject.Properties) {
    Assert-Result ($Entry.Name -notmatch '(^|/)\.\.(/|$)|\\|:|^/') "Invalid payload path $($Entry.Name)"
    $File = Join-Path $Root $Entry.Name
    Assert-Result ((Test-Path -LiteralPath $File -PathType Leaf) -and (Get-Sha $File) -eq $Entry.Value) "Package file missing or changed: $($Entry.Name)"
}
$Sources = @{
    M=(Get-Field $Manifest.source_references 'main')
    I=(Get-Field $Manifest.source_references 'integration')
    C=[ordered]@{source_commit=$Manifest.source_commit; source_tree=$Manifest.source_tree; project='godot'}
}
Assert-Result ($null -ne $Sources.M -and $null -ne $Sources.I) 'The complete accepted-main and prior-integration source references are required'
foreach ($Letter in @('M','I','C')) {
    $Source = $Sources[$Letter]
    Assert-Result ($Source.source_commit -match '^[0-9a-f]{40}$' -and $Source.source_tree -match '^[0-9a-f]{40}$' -and
        $Source.project -notmatch '(^|/)\.\.(/|$)|\\|:|^/' -and (Test-Path -LiteralPath (Join-Path $Root ($Source.project+'/project.godot')))) 'Invalid source reference'
}
Assert-Result ($Sources.M.source_commit -eq $Campaign.source_commits.main -and $Sources.I.source_commit -eq $Campaign.source_commits.integration) 'Registered historical sources differ'
$OverlayEntries = @($Campaign.overlay_sha256.PSObject.Properties) + @($Campaign.transition_overlay_sha256.PSObject.Properties)
foreach ($Entry in $OverlayEntries) {
    Assert-Result ((Get-Sha (Join-Path $Root ('godot/'+$Entry.Name))) -eq $Entry.Value) "Observation overlay differs: $($Entry.Name)"
}
$Cases = @($Campaign.cases | Where-Object {
    if ($Case) { $_.id -eq $Case } elseif ($Extended) { $true } else { $_.quick }
})
if ($Case -eq $Campaign.transition_case.id) { $Cases = @($Campaign.transition_case) }
Assert-Result ($Cases.Count -gt 0) 'No matching registered source cases'
$Stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-source-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$Output = Join-Path $Root "Test-It-Results\$Stamp"
$ProjectRoot = Join-Path $Output 'project'
[void][IO.Directory]::CreateDirectory($ProjectRoot)
$Results = [Collections.Generic.List[object]]::new()
$Failures = [Collections.Generic.List[object]]::new()
$Templates = @{}
Copy-Item -LiteralPath $ManifestPath -Destination (Join-Path $Output 'package-manifest.json')
Copy-Item -LiteralPath $CampaignPath -Destination (Join-Path $Output 'source_campaign.json')
Copy-Item -LiteralPath (Join-Path $Root 'ACCEPTANCE.md') -Destination (Join-Path $Output 'acceptance-at-start.md')
$Hardware = [ordered]@{started_utc=(Get-Date).ToUniversalTime().ToString('o'); windows=[Environment]::OSVersion.VersionString; powershell=$PSVersionTable.PSVersion.ToString()}
try { $Hardware.cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors) } catch { $Hardware.cpu_error=$_.Exception.Message }
try { $Hardware.gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate) } catch { $Hardware.gpu_error=$_.Exception.Message }
try { $Hardware.os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber } catch { $Hardware.os_error=$_.Exception.Message }
Write-Json (Join-Path $Output 'hardware.json') $Hardware
Write-Json (Join-Path $Output 'request.json') ([ordered]@{
    sources=$Sources; order=$Campaign.order; arms=$Campaign.arms; cases=$Cases; measurement=$Campaign.measurement
    overlay_sha256=$Campaign.overlay_sha256; transition_overlay_sha256=$Campaign.transition_overlay_sha256
    campaign_sha256=(Get-Sha $CampaignPath); package_manifest_sha256=(Get-Sha $ManifestPath)
    rendering_driver=$RenderingDriver; render_thread=$RenderThread; timeout_seconds=$TimeoutSeconds
    cache_policy='fresh process, fresh profile and fresh copy of an imported source template per arm; driver-global caches are uncontrolled and order-balanced'
})

function Start-SourceProcess([string]$Folder, [string[]]$Arguments, $Settings, [string]$SourceSha, [int]$Limit) {
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
        if ($_ -match '\s') { '"'+$_+'"' } else { $_ }
    }) -join ' '
    foreach ($Name in @($Info.EnvironmentVariables.Keys)) {
        if ($Name -match '^CYBERSAND_') { $Info.EnvironmentVariables.Remove($Name) }
    }
    foreach ($Name in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME')) {
        $Profile = Join-Path $Folder "profile\$Name"
        [void][IO.Directory]::CreateDirectory($Profile)
        $Info.EnvironmentVariables[$Name] = $Profile
    }
    foreach ($Name in $Settings.Keys) { $Info.EnvironmentVariables[$Name] = [string]$Settings[$Name] }
    $Info.EnvironmentVariables['CYBERSAND_SOURCE_REVISION'] = $SourceSha
    $Info.EnvironmentVariables['CYBERSAND_SOURCE_SHA'] = $SourceSha
    $Watch = [Diagnostics.Stopwatch]::StartNew()
    $Process = [Diagnostics.Process]::Start($Info)
    $Stdout = $Process.StandardOutput.ReadToEndAsync()
    $Stderr = $Process.StandardError.ReadToEndAsync()
    $Sampler = $null
    $SamplerPid = $null
    $TimedOut = $false
    $Discovery = 0
    $Memory = [Collections.Generic.List[object]]::new()
    try {
        while (-not $Process.WaitForExit(250)) {
            if ($Watch.Elapsed.TotalSeconds -gt $Limit) {
                $TimedOut = $true
                & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $Process.Id /T /F | Out-Null
                break
            }
            try {
                if ($null -eq $Sampler -and $Discovery -lt 4) {
                    $Discovery++
                    $Child = @(Get-CimInstance Win32_Process -Filter ('ParentProcessId = '+$Process.Id) | Where-Object { $_.Name -eq 'Godot_v4.7-stable_win64.exe' })
                    if ($Child.Count -eq 1) { $Sampler=[Diagnostics.Process]::GetProcessById($Child[0].ProcessId); $SamplerPid=$Sampler.Id }
                }
                if ($null -ne $Sampler) {
                    $Sampler.Refresh()
                    $Memory.Add([ordered]@{elapsed_ms=$Watch.Elapsed.TotalMilliseconds; pid=$SamplerPid; working_set_bytes=$Sampler.WorkingSet64
                        peak_working_set_bytes=$Sampler.PeakWorkingSet64; private_bytes=$Sampler.PrivateMemorySize64; cpu_ms=$Sampler.TotalProcessorTime.TotalMilliseconds})
                }
            } catch { }
        }
        Assert-Result ($Process.WaitForExit(10000)) 'Application process did not terminate'
        Assert-Result ([Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($Stdout,$Stderr),10000)) 'Application output streams did not close'
        $Text = $Stdout.Result
        $Errors = $Stderr.Result
        [IO.File]::WriteAllText((Join-Path $Folder 'stdout.log'),$Text)
        [IO.File]::WriteAllText((Join-Path $Folder 'stderr.log'),$Errors)
        Write-Json (Join-Path $Folder 'process-memory.json') $Memory.ToArray()
        $Receipt = [ordered]@{wrapper_pid=$Process.Id; observed_application_pid=$SamplerPid; command=@($Engine)+$Arguments
            source_commit=$SourceSha; elapsed_seconds=$Watch.Elapsed.TotalSeconds; exit_code=$Process.ExitCode; timed_out=$TimedOut
            sampled_peak_working_set_bytes=$(if ($Memory.Count) {($Memory.peak_working_set_bytes | Measure-Object -Maximum).Maximum} else {$null})
            sampled_peak_private_bytes=$(if ($Memory.Count) {($Memory.private_bytes | Measure-Object -Maximum).Maximum} else {$null})
            memory_scope='250ms samples of actual Godot child, including setup/import and capture; valid only if receipt process_id matches'}
        Write-Json (Join-Path $Folder 'process.json') $Receipt
        Assert-Result (-not $TimedOut -and $Process.ExitCode -eq 0 -and (($Text+$Errors) -notmatch 'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|Unhandled XServer error|Error initializing GLAD|MakeCurrent failed')) "Application failed in $Folder; original logs retained"
        return $Receipt
    } finally {
        if ($null -ne $Sampler) { $Sampler.Dispose() }
        $Process.Dispose()
    }
}

function Run-SourceArm($Scenario, [string]$Letter, [int]$Index, [switch]$Oracle) {
    $Source = $Sources[$Letter]
    $Arm = Get-Field $Campaign.arms $Letter
    $Suffix = if ($Oracle) { 'oracle-'+$Letter } else { "$Index-$Letter" }
    $Folder = Join-Path $Output "$($Scenario.id)\$Suffix"
    [void][IO.Directory]::CreateDirectory($Folder)
    $Project = Join-Path $ProjectRoot "$($Scenario.id)-$Suffix"
    Copy-Item -LiteralPath $Templates[$Letter] -Destination $Project -Recurse
    $Nonce = [Guid]::NewGuid().ToString('N')
    $Settings = @{
        CYBERSAND_MATERIAL_PUBLICATION=$Arm.material; CYBERSAND_DIAG_PHYSICS_PUBLICATION=$Arm.physics
        CYBERSAND_DIAG_PRESENTATION=$Arm.presentation; CYBERSAND_DIAG_MATERIAL_TIMING=$Arm.timing
        CYBERSAND_DIAG_NATIVE_RENDEZVOUS=$Arm.rendezvous; CYBERSAND_DIAG_COMMON_OBSERVER='0'
        CYBERSAND_SHADER_NONCE=$Nonce; CYBERSAND_SHADER_CACHE_STATE='isolated-project-and-profile'
    }
    if ($Arm.cadence -ne 'source-default') { $Settings.CYBERSAND_DIAG_RENDER_CADENCE=$Arm.cadence }
    $Receipt = Join-Path $Folder 'receipt.json'
    $Arguments = @('--path',$Project,'--rendering-method','gl_compatibility','--rendering-driver',$RenderingDriver,
        '--render-thread',$RenderThread,'--audio-driver','Dummy','--log-file',(Join-Path $Folder 'godot.log'),
        '--script')
    $Transition = (Get-Field $Scenario 'kind') -eq 'transition'
    if ($Transition) {
        $Script = if ($Oracle) { 'res://tests/pubpres_source_transition_oracle.gd' } else { 'res://tests/pubpres_transition.gd' }
        $Arguments += @($Script,'--',"--receipt=$Receipt","--material=$($Arm.material)")
    } else {
        Assert-Result (-not $Oracle) 'History oracle applies only to the transition case'
        $Arguments += @('res://tests/pubpres_source_gameplay.gd','--',"--receipt=$Receipt","--fixture=$($Scenario.fixture)",
            "--camera=$($Scenario.camera)","--workers=$($Scenario.workers)","--water-law=$($Scenario.water_law)")
    }
    Write-Json (Join-Path $Folder 'arm.json') ([ordered]@{source=$Source; scenario=$Scenario; arm=$Arm; order_index=$Index; nonce=$Nonce; selectors=$Settings; arguments=$Arguments})
    Write-Host "$($Scenario.id) | $Suffix | $($Source.source_commit)"
    $Process = Start-SourceProcess $Folder $Arguments $Settings $Source.source_commit $TimeoutSeconds
    $Data = Read-Json $Receipt
    if ($Oracle) {
        $Stats = Read-SourceTransitionOracle $Data $Manifest $Source $Arm $Campaign $RenderingDriver $Nonce
    } elseif ($Transition) {
        $Stats = Read-SourceTransition $Data $Folder $Manifest $Source $Arm $Campaign $RenderingDriver $Nonce
    } else {
        $Stats = Read-SourceGameplay $Data $Folder $Manifest $Source $Scenario $Arm $Campaign $RenderingDriver $RenderThread $Nonce
    }
    $Process['app_sampler_pid_matched'] = $Process.observed_application_pid -eq $Stats.process_id
    if (-not $Process.app_sampler_pid_matched) {
        $Process.sampled_peak_working_set_bytes=$null
        $Process.sampled_peak_private_bytes=$null
    }
    Write-Json (Join-Path $Folder 'process.json') $Process
    Write-Json (Join-Path $Folder 'analysis.json') $Stats
    # The source package, immutable request and complete trace are retained.
    # Successful transient projects are reproducible and need not accumulate.
    Remove-Item -LiteralPath $Project -Recurse -Force
    return [ordered]@{arm=$Letter; index=$Index; nonce=$Nonce; process=$Process; statistics=$Stats; receipt_sha256=(Get-Sha $Receipt)}
}

try {
    foreach ($Letter in @('M','I','C')) {
        $Source = $Sources[$Letter]
        $Project = Join-Path $ProjectRoot ('template-'+$Letter)
        Copy-Item -LiteralPath (Join-Path $Root $Source.project) -Destination $Project -Recurse
        foreach ($Entry in $OverlayEntries) {
            $Target = Join-Path $Project $Entry.Name
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Target))
            Copy-Item -LiteralPath (Join-Path $Root ('godot/'+$Entry.Name)) -Destination $Target
            Assert-Result ((Get-Sha $Target) -eq $Entry.Value) 'Overlay copy changed'
        }
        $null = Start-SourceProcess (Join-Path $Output ('import-'+$Letter)) @('--headless','--audio-driver','Dummy','--path',$Project,'--editor','--import') @{} $Source.source_commit 300
        $Templates[$Letter] = $Project
    }
    foreach ($Scenario in $Cases) {
        $Arms = [Collections.Generic.List[object]]::new()
        $Oracles = [Collections.Generic.List[object]]::new()
        $OracleComplete = $true
        if ((Get-Field $Scenario 'kind') -eq 'transition') {
            foreach ($Letter in @('M','I','C')) {
                try { $Oracles.Add((Run-SourceArm $Scenario $Letter 0 -Oracle)) }
                catch {
                    $OracleComplete = $false
                    $Failures.Add(@{scenario=$Scenario.id; oracle=$Letter; reason=$_.Exception.Message})
                    Write-Host "Oracle incomplete: $($_.Exception.Message)"
                }
            }
            if ($OracleComplete) {
                $ExpectedEntries = $Oracles[0].statistics.entry_history | ConvertTo-Json -Depth 15 -Compress
                foreach ($Row in $Oracles) {
                    if (($Row.statistics.entry_history | ConvertTo-Json -Depth 15 -Compress) -cne $ExpectedEntries) {
                        $OracleComplete = $false
                        $Failures.Add(@{scenario=$Scenario.id; reason='Per-revision re-entry histories differ across real sources'})
                    }
                }
            }
        }
        if ($OracleComplete) {
            for ($Index=0; $Index -lt $Campaign.order.Count; $Index++) {
                try { $Arms.Add((Run-SourceArm $Scenario $Campaign.order[$Index] $Index)) }
                catch {
                    $Failures.Add(@{scenario=$Scenario.id; index=$Index; reason=$_.Exception.Message})
                    Write-Host "Arm incomplete: $($_.Exception.Message)"
                }
            }
        }
        try { Assert-SourceMatched $Arms.ToArray() }
        catch { $Failures.Add(@{scenario=$Scenario.id; reason=$_.Exception.Message}) }
        if ((Get-Field $Scenario 'kind') -eq 'transition' -and $Arms.Count -eq 6) {
            try { Assert-Result (@($Arms.statistics.screenshot_sha256 | Select-Object -Unique).Count -eq 1) 'Actual transition framebuffer PNGs differ across sources' }
            catch { $Failures.Add(@{scenario=$Scenario.id; reason=$_.Exception.Message}) }
        }
        $Results.Add(@{scenario=$Scenario.id; arms=$Arms.ToArray(); untimed_oracles=$Oracles.ToArray()})
        Write-Json (Join-Path $Output 'summary.json') @{complete=$false; physical_acceptance='HOLD'; cases=$Results.ToArray(); failures=$Failures.ToArray()}
    }
} catch { $Failures.Add(@{reason=$_.Exception.Message}) }
finally {
    $Complete = $Failures.Count -eq 0 -and $Results.Count -eq $Cases.Count
    Write-Json (Join-Path $Output 'summary.json') ([ordered]@{schema='pubpres-source-comparison-v1'; complete=$Complete; physical_acceptance='HOLD'
        cases=$Results.ToArray(); failures=$Failures.ToArray(); sources=$Sources; order=$Campaign.order
        meaning='Complete means source-matched captures and correctness checks ran. It does not assert a performance win or physical Windows/NVIDIA acceptance. Inspect both repeats, frame tails, real physical gaps and freshness.'})
    $Lines = [Collections.Generic.List[string]]::new()
    $Lines.Add("Source comparison capture complete: $Complete | Physical acceptance: HOLD")
    $Lines.Add('M=accepted main; I=prior qualified integration; C=repaired candidate. Every case order: M-I-C-C-I-M.')
    $Lines.Add('Gameplay display: 1600x900, 60 FPS cap. Transition display: 960x720, uncapped. Actual VSync and driver are checked in receipts.')
    foreach ($Row in $Results) {
        foreach ($Arm in $Row.arms) {
            if ((Get-Field $Arm.statistics 'kind') -eq 'transition') {
                $Frame = $Arm.statistics.frame_ms
                $Treatment = $Arm.statistics.material_treatment
                $Lines.Add(('{0} {1}{2} | frame p50/p95/p99/max {3:N2}/{4:N2}/{5:N2}/{6:N2} ms | {7:N2} accepted updates/s' -f $Row.scenario,$Arm.arm,$Arm.index,$Frame.p50,$Frame.p95,$Frame.p99,$Frame.max,$Arm.statistics.publications_per_second))
                $Lines.Add("  requested=$($Treatment.requested) actual=$($Treatment.backend) policy=$($Treatment.policy); independent 180-revision readback checked both histories before timing")
                continue
            }
            foreach ($WindowName in @('first_10s','first_144_steps','whole_capture')) {
                $Stats = Get-Field $Arm.statistics.windows $WindowName
                $Frame = $Stats.frame_ms; $Physical = $Stats.physical_gap_ms; $Native = $Stats.native_observed_gap_ms
                $Lines.Add(('{0} {1}{2} {3} | frame p50/p95/p99/max {4:N2}/{5:N2}/{6:N2}/{7:N2} ms' -f $Row.scenario,$Arm.arm,$Arm.index,$WindowName,$Frame.p50,$Frame.p95,$Frame.p99,$Frame.max))
                $Lines.Add(('  physical {0:N2}/{1:N2}/{2:N2}/{3:N2} ms | native-observed {4:N2}/{5:N2}/{6:N2}/{7:N2} ms | native {8:N2}/s Rapier {9:N2}/s' -f $Physical.p50,$Physical.p95,$Physical.p99,$Physical.max,$Native.p50,$Native.p95,$Native.p99,$Native.max,$Stats.native_ticks_per_second,$Stats.rapier_steps_per_second))
            }
        }
    }
    foreach ($Limit in $Campaign.measurement.limits) { $Lines.Add('Scope: '+$Limit) }
    foreach ($Problem in $Failures) { $Lines.Add('INCOMPLETE '+$Problem.reason) }
    [IO.File]::WriteAllLines((Join-Path $Output 'READ-RESULTS.txt'),$Lines)
    Write-Host "Results: $Output"
    & (Join-Path $PSScriptRoot 'Pack-Results.ps1') -RunDirectory $Output
}
if (-not $Complete) { exit 1 }
