# CyberSand Test It: packaged Windows x64 graphical, real-Needle/2048 source.
# Local-only (no installs/downloads), all evidence retained, one final ZIP.
[CmdletBinding()]
param(
  [switch]$Quick,
  [switch]$Full,
  [switch]$Compare,
  [switch]$Cadence,
  [switch]$Coherence,
  [string[]]$CoherenceConditions=@(),
  [switch]$FullCadence,
  [string[]]$CadenceConditions=@(),
  [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver='opengl3',
  [ValidateRange(60,1200)][int]$TimeoutSeconds=900
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($PSScriptRoot)
$Output=[IO.Path]::Combine($Root,'Test-It-Results',([DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+$PID))
[void][IO.Directory]::CreateDirectory($Output)
$ModuleProvenance=@()
$RequiredCommands=@('Get-FileHash','Get-CimInstance','ConvertFrom-Json','ConvertTo-Json',
    'Compress-Archive','Get-Date','Get-Content','New-Item','Resolve-Path','Join-Path',
    'Test-Path','New-Object','Measure-Object','Sort-Object','Select-Object','Write-Host',
    'Write-Warning','Out-Null','Where-Object','ForEach-Object')
try {
    # Explicit in-box paths also support direct PS1 invocation from a process
    # that inherited PowerShell 7's PSModulePath. No module downloads/install.
    foreach($ModuleName in @('Microsoft.PowerShell.Management','Microsoft.PowerShell.Utility',
                             'CimCmdlets','Microsoft.PowerShell.Archive')) {
        $ModuleManifest=[IO.Path]::Combine($PSHOME,'Modules',$ModuleName,($ModuleName+'.psd1'))
        if(-not [IO.File]::Exists($ModuleManifest)){throw ('Missing in-box PowerShell module: '+$ModuleManifest)}
        foreach($LoadedModule in @(Import-Module -Name $ModuleManifest -Force -PassThru -ErrorAction Stop)) {
            $ModuleProvenance+=@{name=$LoadedModule.Name;version=[string]$LoadedModule.Version;path=$LoadedModule.Path}
        }
    }
    foreach($CommandName in $RequiredCommands){[void](Get-Command -Name $CommandName -ErrorAction Stop)}
}catch{
    # A missing in-box JSON/archive module cannot produce the ordinary ZIP;
    # preserve a plain receipt using only .NET and the already-created folder.
    $BootstrapFailure='TEST IT BOOTSTRAP INCOMPLETE'+[Environment]::NewLine+
        'PowerShell '+[string]$PSVersionTable.PSVersion+' at '+$PSHOME+[Environment]::NewLine+
        $_.Exception.ToString()+[Environment]::NewLine
    [IO.File]::WriteAllText([IO.Path]::Combine($Output,'bootstrap-failure.txt'),$BootstrapFailure,[Text.UTF8Encoding]::new($false))
    [Console]::Error.WriteLine($BootstrapFailure)
    exit 1
}
$Engine=Join-Path $Root 'Godot_v4.7-stable_win64_console.exe'
$Project=Join-Path $Root 'godot'
$ManifestFile=Join-Path $Root 'CAMERA-STACK-MANIFEST.json'
$Zip=$Output+'.zip'
$Cases=Join-Path $Output 'cases'
New-Item -ItemType Directory -Force -Path $Cases|Out-Null
$PreviousAppData=$env:APPDATA
$PreviousXdg=$env:XDG_DATA_HOME
$PreviousSource=$env:CYBERSAND_SOURCE_REVISION
$PreviousPose=$env:CYBERSAND_DIAG_FLYER_POSE
$PreviousCadence=$env:CYBERSAND_DIAG_RENDER_CADENCE
$PreviousPresentation=$env:CYBERSAND_DIAG_PRESENTATION
$PreviousMaterialTiming=$env:CYBERSAND_DIAG_MATERIAL_TIMING
$Start=Get-Date
$Summary=@{schema='engine-lab-scripted-pose-test-it-v1';status='incomplete';complete=$false
    source='unverified';driver=$RenderingDriver;cases=@();errors=@();processes=@()
    powershell=@{version=[string]$PSVersionTable.PSVersion;edition=[string]$PSVersionTable.PSEdition
        home=$PSHOME;modules=$ModuleProvenance;validated_commands=$RequiredCommands}
    pairs=@();failures=@();physical_acceptance='pending_owner_NVIDIA_review'
    physics_rate_semantics='Fixed 1/60 second per completed Rapier step; 120 callbacks is not normalized 120Hz physics. Compare physical trajectories at equal completed steps.'
    mode=$(if($Coherence){'coherence'}elseif($FullCadence){'full-cadence'}elseif($Cadence){'cadence'}elseif($Quick){'quick'}elseif($Compare){'compare'}elseif($Full){'full'}else{'eight-case'})}
Write-Host ('TEST_IT_POWERSHELL_RUNTIME '+($Summary.powershell|ConvertTo-Json -Depth 5 -Compress))
function Require([bool]$Ok,[string]$Message){if(-not $Ok){throw $Message}}
function Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Field($Object,[string]$Name,$Fallback=$null) {
    if($null -eq $Object){return $Fallback}
    if($Object -is [System.Collections.IDictionary]) {
        if($Object.Contains($Name)){return $Object[$Name]}
        return $Fallback
    }
    $Property=$Object.PSObject.Properties[$Name]
    if($null -eq $Property){return $Fallback}
    return $Property.Value
}
function Gap($A,$B) {
    if($null -eq $A -or $null -eq $B -or @($A).Count -ne 2 -or @($B).Count -ne 2){return $null}
    return [Math]::Sqrt([Math]::Pow(([double]$A[0]-[double]$B[0]),2)+[Math]::Pow(([double]$A[1]-[double]$B[1]),2))
}
function Distribution($Values) {
    $Sorted=@($Values|ForEach-Object{[double]$_}|Sort-Object)
    if($Sorted.Count -eq 0){return $null}
    return @{count=$Sorted.Count;min=$Sorted[0];p50=$Sorted[[Math]::Max(0,[Math]::Ceiling($Sorted.Count*0.50)-1)]
      p95=$Sorted[[Math]::Max(0,[Math]::Ceiling($Sorted.Count*0.95)-1)]
      p99=$Sorted[[Math]::Max(0,[Math]::Ceiling($Sorted.Count*0.99)-1)];max=$Sorted[-1]}
}
function Read-PoseStatistics([string]$Path) {
    # Independent PowerShell reduction; no Python/development tools needed.
    $Records=@(Get-Content -LiteralPath $Path -Encoding UTF8|Where-Object{$_ -ne ''}|ForEach-Object{ConvertFrom-Json -InputObject $_})
    Require ($Records.Count -ge 3 -and $Records[0].type -eq 'header' -and $Records[-1].type -eq 'summary') 'Incomplete pose trace'
    $Frames=@($Records|Where-Object{$_.type -eq 'frame'})
    $Events=@($Records|Where-Object{$_.type -eq 'event'})
    Require ($Frames.Count -eq [int]$Records[-1].frames -and $Frames.Count -ge 2) 'Missing actual frame submissions'
    Require ([int]$Records[-1].dropped -eq 0 -and [int](Field $Records[-1] 'events_dropped' 0) -eq 0 -and
        [int](Field $Records[-1] 'worker_events_dropped' 0) -eq 0) 'Capture overflowed; original partial trace is retained'
    $Span=([double]$Frames[-1].time_usec-[double]$Frames[0].time_usec)/1000000.0
    Require ($Span -gt 0) 'Nonpositive trace wall interval'
    $Intervals=New-Object 'System.Collections.Generic.List[double]'
    $ScreenSteps=New-Object 'System.Collections.Generic.List[double]'
    $SourceLag=New-Object 'System.Collections.Generic.List[double]'
    $Residuals=New-Object 'System.Collections.Generic.List[double]'
    $SnapshotAges=New-Object 'System.Collections.Generic.List[double]'
    $NativeAges=New-Object 'System.Collections.Generic.List[double]'
    $Sources=@{};$Reasons=@{};$Last=@{};$Holds=0;$Switches=0;$UploadChanges=0
    $ResolveCpu=New-Object 'System.Collections.Generic.List[double]'
    $MaterialAges=New-Object 'System.Collections.Generic.List[double]'
    $UploadAges=New-Object 'System.Collections.Generic.List[double]'
    $SelectedAges=New-Object 'System.Collections.Generic.List[double]'
    $VisibleHoldAges=New-Object 'System.Collections.Generic.List[double]'
    $TimingUploads=@{};$TimingSources=@{};$Reentries=0;$MaxRecovery=0
    $FollowResidual=New-Object 'System.Collections.Generic.List[double]'
    $TemporalRewinds=0;$IntentionalHolds=0;$Withheld=0;$MissingSubmissions=0;$SelectedSteps=0;$UnknownSelectedSteps=0
    for($Index=0;$Index -lt $Frames.Count;$Index++) {
        $Frame=$Frames[$Index]
        $Contract=Field $Frame 'presentation'
        $MaterialTiming=Field $Contract 'material_timing'
        if($null -ne $MaterialTiming) {
            $TimingSource=[string](Field $MaterialTiming 'timing_source' 'unknown')
            if(-not $TimingSources.ContainsKey($TimingSource)){$TimingSources[$TimingSource]=0};$TimingSources[$TimingSource]++
            $CurrentTiming=Field $MaterialTiming 'current'
            $TimingSerial=Field $CurrentTiming 'serial'
            if($null -ne $TimingSerial){$TimingUploads[([string](Field $CurrentTiming 'generation')+':'+[string]$TimingSerial)]=$MaterialTiming}
            $MaterialAge=[double](Field $MaterialTiming 'material_age_usec' -1)
            $UploadAge=[double](Field $MaterialTiming 'upload_age_usec' -1)
            if($MaterialAge -ge 0){$MaterialAges.Add($MaterialAge/1000.0)}
            if($UploadAge -ge 0){$UploadAges.Add($UploadAge/1000.0)}
        }
        $ResolveTime=Field $Contract 'resolve_usec'
        if($null -ne $ResolveTime){$ResolveCpu.Add([double]$ResolveTime/1000.0)}
        $Built=[double](Field $Frame 'render_snapshot_built_usec' -1)
        if($Built -ge 0){$SnapshotAges.Add(([double]$Frame.time_usec-$Built)/1000.0)}
        $Completed=[double](Field $Frame 'mask_native_completed_usec' -1)
        if($Completed -ge 0){$NativeAges.Add(([double]$Frame.time_usec-$Completed)/1000.0)}
        if($Index -gt 0) {
            $Prior=$Frames[$Index-1]
            $Interval=([double]$Frame.time_usec-[double]$Prior.time_usec)/1000.0
            Require ($Interval -gt 0) 'Nonmonotonic frame timestamps'
            $Intervals.Add($Interval)
            $MissingSubmissions+=[Math]::Max(0,[int]$Frame.process_frame-[int]$Prior.process_frame-1)
            if($Frame.uploaded_render_serial -ne $Prior.uploaded_render_serial){$UploadChanges++}
        }
        foreach($Body in @($Frame.bodies)) {
            $Key=[string]$Body.slot;$Source=[string]$Body.source;$Reason=[string]$Body.guard_reason
            $SelectedStep=Field $Body 'presentation_step'
            if($null -ne (Field $Body 'selected')) {
                $SelectedAge=[double](Field $Body 'selected_age_usec' -1)
                if($SelectedAge -ge 0){$SelectedAges.Add($SelectedAge/1000.0)}
                if([bool](Field $Body 'intentional_hold' $false)){$VisibleHoldAges.Add([double](Field $Body 'hold_age_usec' 0)/1000.0)}
            }
            if([bool](Field $Body 'explicit_reentry' $false)){$Reentries++}
            $MaxRecovery=[Math]::Max($MaxRecovery,[int](Field $Body 'recovery_attempts' 0))
            if($null -ne $SelectedStep -and [double]$SelectedStep -ge 0){$SelectedSteps++}
            elseif($null -ne (Field $Body 'selected')){$UnknownSelectedSteps++}
            if([bool](Field $Body 'presentation_source_rewind' $false)){$TemporalRewinds++}
            if([bool](Field $Body 'intentional_hold' $false)){$IntentionalHolds++}
            if($null -eq (Field $Body 'selected')){$Withheld++}
            if((Field $Body 'instance_id' -1) -eq (Field $Contract 'follow_instance_id' -2)) {
                $FollowGap=Gap (Field $Contract 'follow_position') (Field (Field $Body 'selected') 'xy')
                if($null -ne $FollowGap){$FollowResidual.Add($FollowGap)}
            }
            if(-not $Sources.ContainsKey($Source)){$Sources[$Source]=0};$Sources[$Source]++
            if(-not $Reasons.ContainsKey($Reason)){$Reasons[$Reason]=0};$Reasons[$Reason]++
            $Projection=Field $Body 'screen_selected'
            if($null -ne $Projection){$Residuals.Add([double](Field $Projection 'residual_magnitude_px' 0))}
            $Lag=Gap (Field $Body 'selected_screen') (Field $Body 'live_screen')
            if($null -ne $Lag){$SourceLag.Add($Lag)}
            if($Last.ContainsKey($Key)) {
                $PriorBody=$Last[$Key]
                if($Source -ne [string]$PriorBody.source){$Switches++}
                $Step=Gap (Field $Body 'selected_screen') (Field $PriorBody 'selected_screen')
                if($null -ne $Step){$ScreenSteps.Add($Step)}
                $Selected=Field $Body 'selected';$PriorSelected=Field $PriorBody 'selected'
                $WorldStep=Gap (Field $Selected 'xy') (Field $PriorSelected 'xy')
                if($null -ne $WorldStep -and $WorldStep -lt 0.000001 -and
                   [Math]::Abs([double](Field $Selected 'radians' 0)-[double](Field $PriorSelected 'radians' 0)) -lt 0.000001){$Holds++}
            }
            $Last[$Key]=$Body
        }
    }
    $Counts=@{};$Trajectory=@{};$EventTimes=@{};$UploadsBySerial=@{};$UnmatchedAcks=0
    # Legacy delayed ACK rows have uploaded_usec=0. Join the captured upload
    # identity instead; an upload before capture has no measured latency here.
    foreach($Event in $Events) {
        if((Field $Event 'event') -eq 'texture_upload' -and [double](Field $Event 'completed_usec' -1) -gt 0) {
            $UploadsBySerial[[string]$Event.render_serial]=[double]$Event.completed_usec
        }
    }
    $NativeWall=New-Object 'System.Collections.Generic.List[double]'
    $UploadWall=New-Object 'System.Collections.Generic.List[double]'
    $UploadAges=New-Object 'System.Collections.Generic.List[double]'
    $AckLatencies=New-Object 'System.Collections.Generic.List[double]'
    foreach($Event in $Events) {
        $Kind=[string](Field $Event 'event' 'unknown')
        if(-not $Counts.ContainsKey($Kind)){$Counts[$Kind]=0};$Counts[$Kind]++
        $EventTime=[double](Field $Event 'time_usec' (Field $Event 'completed_usec' -1))
        if(-not $EventTimes.ContainsKey($Kind)){$EventTimes[$Kind]=New-Object 'System.Collections.Generic.List[double]'}
        if($EventTime -ge 0){$EventTimes[$Kind].Add($EventTime)}
        if($Kind -eq 'native_tick') {
            $NativeWall.Add(([double]$Event.completed_usec-[double]$Event.start_usec)/1000.0)
        }elseif($Kind -eq 'texture_upload') {
            $UploadWall.Add(([double]$Event.completed_usec-[double]$Event.start_usec)/1000.0)
            if([double]$Event.generated_usec -ge 0){$UploadAges.Add(([double]$Event.completed_usec-[double]$Event.generated_usec)/1000.0)}
        }elseif($Kind -eq 'render_ack') {
            $Serial=[string]$Event.render_serial
            if($UploadsBySerial.ContainsKey($Serial) -and $EventTime -ge $UploadsBySerial[$Serial]) {
                $AckLatencies.Add(($EventTime-$UploadsBySerial[$Serial])/1000.0)
            }else{$UnmatchedAcks++}
        }
        if($Kind -eq 'rapier_step') {
            foreach($Body in @(Field $Event 'bodies' @())) {
                $Key=([string]$Event.step)+':'+([string]$Body.slot)
                Require (-not $Trajectory.ContainsKey($Key)) ('Duplicate completed Rapier event '+$Key)
                $Trajectory[$Key]=@{xy=@($Body.xy);velocity=@($Body.velocity);angle=[double]$Body.angle
                    native_tick_used=(Field $Event 'native_tick_used' -1)}
            }
        }
    }
    $EventRates=@{}
    foreach($Kind in $EventTimes.Keys) {
        $Times=@($EventTimes[$Kind]|Sort-Object)
        if($Times.Count -gt 1 -and $Times[-1] -gt $Times[0]){$EventRates[$Kind]=($Times.Count-1)*1000000.0/($Times[-1]-$Times[0])}
    }
    $Result=@{measurement='Main overlay submission, not GPU scanout';frames=$Frames.Count;span_seconds=$Span
        achieved_overlay_fps=($Frames.Count-1)/$Span
        achieved_native_hz=([double]$Frames[-1].native_tick-[double]$Frames[0].native_tick)/$Span
        achieved_rapier_hz=([double]$Frames[-1].rapier_step-[double]$Frames[0].rapier_step)/$Span
        achieved_upload_hz=$UploadChanges/$Span;frame_interval_ms=(Distribution $Intervals)
        screen_step_px=(Distribution $ScreenSteps);submitted_to_live_gap_px=(Distribution $SourceLag)
        projection_residual_px=(Distribution $Residuals);selected_world_pose_holds=$Holds
        source_switches=$Switches;source_counts=$Sources;guard_reasons=$Reasons;event_counts=$Counts;event_rates_hz=$EventRates
        snapshot_age_at_presentation_ms=(Distribution $SnapshotAges);bound_native_age_at_presentation_ms=(Distribution $NativeAges)
        native_tick_wall_ms=(Distribution $NativeWall);texture_upload_cpu_call_ms=(Distribution $UploadWall)
        snapshot_age_at_upload_ms=(Distribution $UploadAges);upload_to_ack_issue_ms=(Distribution $AckLatencies)
        ack_latency_unavailable=$UnmatchedAcks;presentation_cpu_ms=(Distribution $ResolveCpu)
        delivery_timing=@{observed_uploads=$TimingUploads.Count;timing_sources=$TimingSources
            upload_interval_ms=(Distribution @($TimingUploads.Values|ForEach-Object{[double]$_.upload_interval_usec/1000.0}))
            publication_interval_ms=(Distribution @($TimingUploads.Values|ForEach-Object{[double]$_.publication_interval_usec/1000.0}))
            blend_duration_ms=(Distribution @($TimingUploads.Values|ForEach-Object{[double]$_.blend_duration_usec/1000.0}))
            material_age_ms=(Distribution $MaterialAges);upload_age_ms=(Distribution $UploadAges)
            selected_pose_age_ms=(Distribution $SelectedAges);visible_hold_age_ms=(Distribution $VisibleHoldAges)
            explicit_reentries=$Reentries;max_recovery_attempts=$MaxRecovery
            notice='Intervals count uploads once; ages count submitted frames. Unknown ages are omitted, not zero latency.'}
        selected_step_observations=$SelectedSteps;selected_step_unknown_visible_frames=$UnknownSelectedSteps
        selected_source_time_rewinds=$TemporalRewinds;intentional_hold_frames=$IntentionalHolds
        withheld_body_frames=$Withheld;follow_target_minus_selected_cells=(Distribution $FollowResidual)
        callbacks_without_overlay_submission=$MissingSubmissions
        dropped_frames=[int]$Records[-1].dropped;duplicate_callbacks=[int]$Records[-1].duplicates
        actual_first_view=@($Frames[0].view_world_cells);actual_last_view=@($Frames[-1].view_world_cells)}
    return @{statistics=$Result;trajectory=$Trajectory}
}
function Compare-PhysicalSteps($Before,$After) {
    $Positions=New-Object 'System.Collections.Generic.List[double]'
    $Velocities=New-Object 'System.Collections.Generic.List[double]'
    $Angles=New-Object 'System.Collections.Generic.List[double]'
    $DifferentNative=0
    foreach($Key in $Before.Keys) {
        if(-not $After.ContainsKey($Key)){continue}
        $A=$Before[$Key];$B=$After[$Key]
        $Position=Gap $A.xy $B.xy;$Velocity=Gap $A.velocity $B.velocity
        if($null -ne $Position){$Positions.Add($Position)}
        if($null -ne $Velocity){$Velocities.Add($Velocity)}
        $Angles.Add([Math]::Abs([Math]::Atan2([Math]::Sin($A.angle-$B.angle),[Math]::Cos($A.angle-$B.angle))))
        if($A.native_tick_used -ne $B.native_tick_used){$DifferentNative++}
    }
    $Complete=$Positions.Count -gt 0 -and $Positions.Count -eq $Velocities.Count -and $Positions.Count -eq $Angles.Count
    $Within=$Complete -and ($Positions|Measure-Object -Maximum).Maximum -le 0.001 -and
        ($Velocities|Measure-Object -Maximum).Maximum -le 0.001 -and ($Angles|Measure-Object -Maximum).Maximum -le 0.00001
    $ComparisonStatus=if(-not $Complete){'unavailable'}elseif($DifferentNative -gt 0){'incomparable_native_input_schedule'}elseif($Within){'matched_within_tolerances'}else{'physical_trajectory_differs'}
    return @{comparison_clock='same completed Rapier step and body slot, fixed 1/60 simulated seconds per step'
        common_step_bodies=$Positions.Count;legacy_step_bodies=$Before.Count;repaired_step_bodies=$After.Count
        position_delta_cells=(Distribution $Positions);velocity_delta=(Distribution $Velocities)
        angle_delta_radians=(Distribution $Angles);different_native_tick_inputs=$DifferentNative
        tolerances=@{position_cells=0.001;velocity_cells_per_second=0.001;angle_radians=0.00001}
        observed_deltas_within_tolerances=[bool]$Within;status=$ComparisonStatus}
}
function Save-Summary {
    $Summary.elapsed_seconds=[Math]::Round(((Get-Date)-$Start).TotalSeconds,3)
    [IO.File]::WriteAllText((Join-Path $Output 'summary.json'),
      (($Summary|ConvertTo-Json -Depth 28)+[Environment]::NewLine),
      [Text.UTF8Encoding]::new($false))
    $Lines=New-Object 'System.Collections.Generic.List[string]'
    $Lines.Add('CyberSand presentation comparison - local measured results')
    $Lines.Add('Source: '+$Summary.source)
    $Lines.Add('Capture status: '+$Summary.status+'; physical NVIDIA acceptance: PENDING OWNER REVIEW')
    $Lines.Add('Rates below are achieved. VSync is disabled only for these scripted pacing cases.')
    $Lines.Add('Main means overlay submission, not monitor scanout. See summary.json and raw traces for full evidence.')
    $Lines.Add('')
    foreach($Row in $Summary.cases) {
        $Stats=$Row.statistics;$Timing=$Stats.frame_interval_ms;$Cpu=$Stats.presentation_cpu_ms
        $Lines.Add($Row.name)
        $Lines.Add(('  Main/native/Rapier Hz: {0:N2} / {1:N2} / {2:N2}' -f $Stats.achieved_overlay_fps,$Stats.achieved_native_hz,$Stats.achieved_rapier_hz))
        $Lines.Add(('  Main interval ms median/p95/p99: {0} / {1} / {2}; samples: {3}' -f (Field $Timing 'p50' 'n/a'),(Field $Timing 'p95' 'n/a'),(Field $Timing 'p99' 'n/a'),(Field $Timing 'count' 0)))
        $Lines.Add(('  Presentation CPU ms median/p95/p99: {0} / {1} / {2}; recorded source rewinds: {3}' -f (Field $Cpu 'p50' 'n/a'),(Field $Cpu 'p95' 'n/a'),(Field $Cpu 'p99' 'n/a'),$Stats.selected_source_time_rewinds))
        $Lines.Add(('  Intentional holds: {0}; withheld actor frames: {1}' -f $Stats.intentional_hold_frames,$Stats.withheld_body_frames))
        $Delivery=Field $Stats 'delivery_timing'
        $Lines.Add(('  Measured delivery/fade ms p95: upload {0}, publication {1}, blend {2}; observed uploads {3}' -f
            (Field (Field $Delivery 'upload_interval_ms') 'p95' 'n/a'),(Field (Field $Delivery 'publication_interval_ms') 'p95' 'n/a'),
            (Field (Field $Delivery 'blend_duration_ms') 'p95' 'n/a'),(Field $Delivery 'observed_uploads' 0)))
        $Lines.Add(('  Selected pose age ms p95/max: {0}/{1}; visible hold max ms: {2}; explicit reentries {3}' -f
            (Field (Field $Delivery 'selected_pose_age_ms') 'p95' 'n/a'),(Field (Field $Delivery 'selected_pose_age_ms') 'max' 'n/a'),
            (Field (Field $Delivery 'visible_hold_age_ms') 'max' 'n/a'),(Field $Delivery 'explicit_reentries' 0)))
        $Lines.Add(('  Known selected steps: {0}; visible unknown source times: {1}; callbacks without a submission: {2}' -f $Stats.selected_step_observations,$Stats.selected_step_unknown_visible_frames,$Stats.callbacks_without_overlay_submission))
    }
    foreach($Pair in @($Summary.pairs)) {
        $Physical=$Pair.physical_trajectory
        $Lines.Add(('Physical comparison {0}: {1}; differing native input steps: {2}' -f $Pair.condition,$Physical.status,$Physical.different_native_tick_inputs))
    }
    $Lines.Add('Incomparable native input schedules do not prove unchanged physics. Installed deterministic authority control provides a separate same-input check.')
    if($Summary.failures.Count -gt 0){$Lines.Add('Incomplete cases: '+$Summary.failures.Count+'; original logs are retained.')}
    [IO.File]::WriteAllLines((Join-Path $Output 'READ-RESULTS.txt'),$Lines.ToArray(),[Text.UTF8Encoding]::new($false))
}
function Quote([string]$Value) {
    if($Value.Length -eq 0){return '""'}
    if($Value -notmatch '[\s"]'){return $Value}
    $quoted=[regex]::Replace($Value,'(\\*)"','$1$1\"')
    $quoted=[regex]::Replace($quoted,'(\\+)$','$1$1')
    return '"'+$quoted+'"'
}
function Run-Godot([string]$Name,[string[]]$Argv,[int]$Timeout,[string]$Directory) {
    $Info=New-Object System.Diagnostics.ProcessStartInfo
    $Info.FileName=$Engine
    $Info.Arguments=(($Argv|ForEach-Object{Quote $_}) -join ' ')
    $Info.WorkingDirectory=$Root
    $Info.UseShellExecute=$false
    $Info.RedirectStandardOutput=$true
    $Info.RedirectStandardError=$true
    $Info.CreateNoWindow=$false
    $Proc=New-Object System.Diagnostics.Process
    $Proc.StartInfo=$Info
    $Code=-999
    $ProcessId=-1
    try {
        Require ([bool]$Proc.Start()) "$Name refused to start"
        $ProcessId=$Proc.Id
        $OutputTask=$Proc.StandardOutput.ReadToEndAsync()
        $ErrorTask=$Proc.StandardError.ReadToEndAsync()
        $Completed=$Proc.WaitForExit($Timeout*1000)
        if(-not $Completed) {
            try{$Proc.Kill()}catch{}
            [void]$Proc.WaitForExit(10000)
        }
        [IO.File]::WriteAllText((Join-Path $Directory ($Name+'-stdout.log')),
           [string]$OutputTask.Result,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $Directory ($Name+'-stderr.log')),
           [string]$ErrorTask.Result,[Text.UTF8Encoding]::new($false))
        Require $Completed "$Name TIMED OUT ($Timeout seconds); logs retained"
        $Code=[int]$Proc.ExitCode
        Write-Host "TEST_IT_PROCESS $Name PID=$ProcessId EXIT=$Code"
        Require ($Code -eq 0) "$Name exited $Code; logs and any receipts retained"
    }finally{
        $Summary.processes+=@{name=$Name;pid=$ProcessId;exit_code=$Code}
        $Proc.Dispose()
    }
}
function Run-Case([string]$Family,[int]$Workers,[int]$Repeat,
                  [string]$Camera,[string]$Pose,[int]$PixelHz,[int]$RenderHz,
                  [int]$Fps=60,[int]$RapierHz=60,[int]$AckDelay=0,[bool]$AckGated=$false,
                  [bool]$WaitSample=$true,[bool]$SampleWake=$true,[bool]$Smoothing=$true,
                  [string]$Presentation='repaired',[string]$Condition='legacy-suite',[bool]$CadenceTape=$false,
                  [string]$PoseSelection='coherent',[string]$FireMode='unchanged') {
    # Keep paths short for Windows PowerShell 5.1 and Godot shader-cache names.
    # Every requested axis is still written in the receipt and summary.
    $Name=$(if($Condition -eq 'legacy-suite'){"$Family-w$Workers-r$Repeat-$Camera-$Pose-p$PixelHz-u$RenderHz"}elseif($Coherence){"$Condition-$PoseSelection"}else{"$Condition-$Presentation"})
    $Dir=Join-Path $Cases $Name
    New-Item -ItemType Directory -Force -Path $Dir|Out-Null
    $Receipt=Join-Path $Dir 'receipt.json'
    $env:APPDATA=Join-Path $Dir 'userdata'
    $env:XDG_DATA_HOME=$env:APPDATA
    $env:CYBERSAND_DIAG_FLYER_POSE=$(if($Pose -eq 'mask'){'mask'}else{''})
    $env:CYBERSAND_DIAG_RENDER_CADENCE=$(if($Presentation -eq 'legacy'){'legacy'}else{''})
    $env:CYBERSAND_DIAG_PRESENTATION=$(if($PoseSelection -eq 'legacy'){'legacy'}else{''})
    $env:CYBERSAND_DIAG_MATERIAL_TIMING=$(if($PoseSelection -eq 'legacy'){'legacy'}else{''})
    New-Item -ItemType Directory -Force -Path $env:APPDATA|Out-Null
    Write-Host "TEST IT | $Name | real 2048-square World / Needle physics tape" -ForegroundColor Cyan
    $Arguments=@('--rendering-driver',$RenderingDriver,'--rendering-method',
       'gl_compatibility','--audio-driver','Dummy','--max-fps',[string]$Fps,
       '--path',$Project,'--script','res://tests/test_engine_lab_physical_test_it.gd',
       '--','--engine-lab-scripted',"--family=$Family","--workers=$Workers",
       "--repeat=$Repeat","--camera=$Camera","--pose=$Pose",
       "--pixel-hz=$PixelHz","--publication-hz=$RenderHz","--fps=$Fps","--rapier-hz=$RapierHz",
       "--ack-delay=$AckDelay","--ack-gated=$([int]$AckGated)","--wait-sample=$([int]$WaitSample)",
       "--sample-wake=$([int]$SampleWake)","--smoothing=$([int]$Smoothing)","--cadence=$Presentation",
       "--cadence-tape=$([int]$CadenceTape)","--presentation=$PoseSelection","--fire-mode=$FireMode","--receipt=$Receipt")
    Run-Godot $Name $Arguments $TimeoutSeconds $Dir
    Require (Test-Path -LiteralPath $Receipt -PathType Leaf) "$Name did not write a receipt"
    $Data=Get-Content -LiteralPath $Receipt -Raw -Encoding UTF8|ConvertFrom-Json
    $Trace=Join-Path $Dir 'receipt-poses.jsonl'
    Require (Test-Path -LiteralPath $Trace -PathType Leaf) "$Name did not write pose JSONL"
    Require ($Data.complete -eq $true -and $Data.status -eq 'passed') "$Name incomplete"
    Require ($Data.source_sha -eq $Summary.source) "$Name source identity changed"
    Require ($Data.presentation_mode -eq $PoseSelection -and $Data.cadence_mode -eq $Presentation -and
        $Data.material_timing_mode -eq $(if($PoseSelection -eq 'legacy'){'legacy'}else{'measured'})) "$Name comparison arm differs"
    if($FireMode -eq 'on-off') {
        $FireEvents=@($Data.fire_schedule.events)
        Require ($FireEvents.Count -eq 2 -and $FireEvents[0].observed_step -eq 0 -and $FireEvents[1].observed_step -eq 60 -and
            $FireEvents[0].enabled -eq $true -and $FireEvents[1].enabled -eq $false) "$Name Fire schedule incomplete"
    }
    Require ($Data.world_size[0] -eq 2048 -and $Data.world_size[1] -eq 2048) "$Name wrong World size"
    Require ($Data.reference.json_sha256 -eq 'b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954') "$Name wrong owner fixture"
    Require ($Data.reference.generated_material_sha256 -eq '71610b37531531e284f069cf1e07c151283a441c9b0ff32a4fcc1dbb6c997a7a') "$Name wrong generated World"
    Require ($Data.reference.native_receipts -eq 256) "$Name missing generation receipts"
    $ExpectedInputs=$(if($CadenceTape){11}else{8})
    Require ($Data.input_tape.complete -eq $true -and @($Data.input_tape.observed).Count -eq $ExpectedInputs) "$Name missed exact physics-tick inputs"
    Require ($Data.native_ticks -gt 0 -and $Data.rapier_steps -ge 24) "$Name no positive native/Rapier progress"
    Require ($Data.trace.frames -gt 0) "$Name missing frame-level diagnostic trace"
    Require ($Data.view_size[0] -eq 240 -and $Data.view_size[1] -eq 135) "$Name actual view does not match requested framing"
    Require (@($Data.framebuffer_captures).Count -eq 2) "$Name did not capture both actual framebuffers"
    $Analysis=Read-PoseStatistics $Trace
    [IO.File]::WriteAllText((Join-Path $Dir 'analysis.json'),
        (($Analysis.statistics|ConvertTo-Json -Depth 28)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    if($Coherence -and $PoseSelection -eq 'coherent') {
        Require ($Analysis.statistics.selected_step_observations -gt 0 -and
            $Analysis.statistics.selected_source_time_rewinds -eq 0) "$Name missing or rewinding selected presentation timeline"
        if($Camera -eq 'follow') {
            $Follow=$Analysis.statistics.follow_target_minus_selected_cells
            Require ($null -ne $Follow -and [double](Field $Follow 'max' 1) -le 0.000001) "$Name Follow target differs from selected pose"
        }
    }
    $Row=@{name=$Name;passed=$true;workers=$Workers;family=$Family;camera=$Camera;pose=$Pose
        condition=$Condition;cadence_mode=$Presentation;presentation_mode=$PoseSelection
        material_timing_mode=$Data.material_timing_mode
        fire_schedule=$Data.fire_schedule;display=$Data.display
        pixel_target_hz=$PixelHz;publication_target_hz=$RenderHz;graphical_fps_target=$Fps
        rapier_callback_target_hz=$RapierHz;fixed_simulation_step_seconds=(1.0/60.0)
        ack_delay_frames=$AckDelay;ack_gated_publication=$AckGated;wait_native_sample=$WaitSample
        wake_on_rapier_sample=$SampleWake;smoothing=$Smoothing;statistics=$Analysis.statistics
        actual_native_ticks=$Data.native_ticks;actual_rapier_steps=$Data.rapier_steps
        rendered_pose_frames=$Data.trace.frames;dropped=$Data.trace.dropped
        video_adapter=$Data.video_adapter;receipt_sha256=(Sha $Receipt);trace_sha256=(Sha $Trace)}
    $Summary.cases+=,$Row
    $script:LastCaseRow=$Row
    $script:LastTrajectory=$Analysis.trajectory
    Save-Summary
    Write-Host "PASS $Name - $($Row.rendered_pose_frames) trace frames" -ForegroundColor Green
}
function Cadence-Condition([string]$Name,$Overrides=@{}) {
    $Row=@{name=$Name;pixel=30;rapier=120;fps=60;publication=60;camera='follow';pose='guarded'
        ack=0;gated=$false;wait=$false;wake=$false;smoothing=$true}
    foreach($Key in $Overrides.Keys){$Row[$Key]=$Overrides[$Key]}
    return $Row
}
function Run-CadencePair($Condition) {
    $Rows=@{};$Trajectories=@{}
    foreach($Presentation in @('legacy','repaired')) {
        try {
            Run-Case 'freemass' 1 1 $Condition.camera $Condition.pose $Condition.pixel $Condition.publication `
                $Condition.fps $Condition.rapier $Condition.ack $Condition.gated $Condition.wait $Condition.wake `
                $Condition.smoothing $Presentation $Condition.name $true 'legacy'
            $Rows[$Presentation]=$script:LastCaseRow
            $Trajectories[$Presentation]=$script:LastTrajectory
        }catch{
            $Summary.failures+=@{condition=$Condition.name;presentation=$Presentation;error=[string]$_.Exception.Message}
            Write-Host ('CASE INCOMPLETE: '+$Condition.name+' '+$Presentation+' '+$_.Exception.Message) -ForegroundColor Red
            Save-Summary
        }
    }
    if($Rows.Count -eq 2) {
        $Summary.pairs+=@{condition=$Condition.name;legacy=$Rows.legacy.name;repaired=$Rows.repaired.name
            physical_trajectory=(Compare-PhysicalSteps $Trajectories.legacy $Trajectories.repaired)
            legacy_statistics=$Rows.legacy.statistics;repaired_statistics=$Rows.repaired.statistics}
        Save-Summary
    }
    $script:LastTrajectory=@{}
}
function Run-CadenceMatrix {
    $Conditions=New-Object 'System.Collections.Generic.List[object]'
    if($FullCadence) {
        # Exhaustive PRIMARY axes; publication=60 and smoothing=on are explicit.
        foreach($Pixel in @(30,60,120)){foreach($Rapier in @(60,120)){foreach($Fps in @(30,60,120,0)){
          foreach($Camera in @('free','follow')){foreach($Pose in @('guarded','mask')){
           foreach($Ack in @(0,3)){foreach($Gate in @($false,$true)){
            $Name="matrix-p$Pixel-q$Rapier-f$Fps-$Camera-$Pose-a$Ack-g$([int]$Gate)"
            $Conditions.Add((Cadence-Condition $Name @{pixel=$Pixel;rapier=$Rapier;fps=$Fps;camera=$Camera;pose=$Pose;ack=$Ack;gated=$Gate}))
        }}}}}}}
    }else{
        $MatrixPath=Join-Path $Project 'tests\fixtures\engine_lab\render-cadence-conditions.json'
        $Matrix=Get-Content -LiteralPath $MatrixPath -Raw -Encoding UTF8|ConvertFrom-Json
        Require ($Matrix.schema -eq 'render-cadence-conditions-v1') 'Wrong cadence matrix schema'
        foreach($Condition in @($Matrix.conditions)) {
            if(-not $Quick -or $Condition.name -eq 'baseline'){$Conditions.Add($Condition)}
        }
    }
    if($CadenceConditions.Count -gt 0) {
        foreach($Name in $CadenceConditions){Require (@($Conditions|Where-Object{$_.name -eq $Name}).Count -eq 1) ('Unknown cadence condition: '+$Name)}
        $Selected=@($Conditions|Where-Object{$CadenceConditions -contains $_.name})
    }else{$Selected=@($Conditions.ToArray())}
    $Summary.planned_conditions=$Selected
    $Summary.planned_cases=$Selected.Count*2
    Save-Summary
    Write-Host ("CADENCE: "+$Selected.Count+" matched legacy/repaired pairs; all targets independent; achieved rates will be measured.") -ForegroundColor Cyan
    foreach($Condition in $Selected){Run-CadencePair $Condition}
    Require ($Summary.failures.Count -eq 0) 'One or more cadence cases were incomplete; all independent cases and partial results are retained'
}
function Run-CoherenceMatrix {
    $MatrixPath=Join-Path $Project 'tests\fixtures\engine_lab\coherence-conditions.json'
    $Matrix=Get-Content -LiteralPath $MatrixPath -Raw -Encoding UTF8|ConvertFrom-Json
    Require ($Matrix.schema -eq 'camera-stack-coherence-conditions-v1') 'Wrong coherence matrix schema'
    $Conditions=@($Matrix.conditions)
    if($Quick){$Conditions=@($Conditions|Where-Object{$_.name -eq 'follow60'})}
    if($CoherenceConditions.Count -gt 0) {
        foreach($Name in $CoherenceConditions){Require (@($Conditions|Where-Object{$_.name -eq $Name}).Count -eq 1) ('Unknown coherence condition: '+$Name)}
        $Conditions=@($Conditions|Where-Object{$CoherenceConditions -contains $_.name})
    }
    $Summary.planned_conditions=$Conditions;$Summary.planned_cases=$Conditions.Count*2
    $Summary.comparison='Original guarded presentation versus coherent timeline; both use repaired material history and ACK'
    Save-Summary
    Write-Host ('COHERENCE: '+$Conditions.Count+' matched pairs. Close other CyberSand windows; results stay local.') -ForegroundColor Cyan
    foreach($Condition in $Conditions) {
        $Rows=@{};$Trajectories=@{}
        foreach($Selection in @('legacy','coherent')) {
            try {
                Run-Case 'freemass' 1 1 $Condition.camera $Condition.pose $Condition.pixel $Condition.publication `
                    $Condition.fps $Condition.rapier $Condition.ack $Condition.gated $Condition.wait $Condition.wake `
                    $Condition.smoothing 'repaired' $Condition.name $true $Selection $Condition.fire
                $Rows[$Selection]=$script:LastCaseRow;$Trajectories[$Selection]=$script:LastTrajectory
            }catch{
                $Summary.failures+=@{condition=$Condition.name;presentation=$Selection;error=[string]$_.Exception.Message}
                Write-Host ('CASE INCOMPLETE: '+$Condition.name+' '+$Selection+' '+$_.Exception.Message) -ForegroundColor Red
                Save-Summary
            }
        }
        if($Rows.Count -eq 2) {
            $Physical=Compare-PhysicalSteps $Trajectories.legacy $Trajectories.coherent
            $Summary.pairs+=@{condition=$Condition.name;legacy=$Rows.legacy.name;coherent=$Rows.coherent.name
                physical_trajectory=$Physical
                legacy_statistics=$Rows.legacy.statistics;coherent_statistics=$Rows.coherent.statistics}
            if($Physical.status -in @('unavailable','physical_trajectory_differs')) {
                $Summary.failures+=@{condition=$Condition.name;presentation='physical-equivalence';error=$Physical.status}
            }
            Save-Summary
        }
    }
    $script:LastTrajectory=@{}
    $Summary.physical_comparison=@{
        matched_pairs=@($Summary.pairs|Where-Object{$_.physical_trajectory.status -eq 'matched_within_tolerances'}).Count
        incomparable_pairs=@($Summary.pairs|Where-Object{$_.physical_trajectory.status -eq 'incomparable_native_input_schedule'}|ForEach-Object{$_.condition})
        notice='Different native input schedules are incomparable for physics equivalence; deterministic production authority control is separate.'}
    Require ($Summary.failures.Count -eq 0) 'One or more coherence cases were incomplete; all available evidence was retained'
}
try {
    Require (-not ($Quick -and ($Full -or $Compare -or $FullCadence)) -and -not ($Full -and $Compare)) 'Select compatible test modes; Quick may combine with Cadence or Coherence'
    Require (-not (($Cadence -or $FullCadence) -and ($Full -or $Compare))) 'Cadence modes cannot combine with old Compare/Full modes'
    Require (-not ($Cadence -and $FullCadence)) 'Select Cadence or FullCadence'
    Require (-not ($Coherence -and ($Cadence -or $FullCadence -or $Compare -or $Full))) 'Coherence may combine with Quick or CoherenceConditions only'
    Require ($CoherenceConditions.Count -eq 0 -or $Coherence) 'CoherenceConditions requires Coherence'
    Require ($CadenceConditions.Count -eq 0 -or $Cadence -or $FullCadence) 'CadenceConditions requires a cadence mode'
    Require (Test-Path -LiteralPath $Engine -PathType Leaf) 'Bundled Godot console missing: extract inner ZIP completely'
    Require (Test-Path -LiteralPath $ManifestFile -PathType Leaf) 'CAMERA-STACK-MANIFEST.json missing'
    Require (Test-Path -LiteralPath (Join-Path $Project 'tests\test_engine_lab_physical_test_it.gd')) 'Test It GDScript is absent: use latest pose-test package'
    $Manifest=Get-Content -LiteralPath $ManifestFile -Raw -Encoding UTF8|ConvertFrom-Json
    Require ($Manifest.schema -eq 'camera-stack-coherence-windows-v1' -and
        $Manifest.accepted_main -eq '018bd09503d7f079ddac52e225c2f7daf8d678bf') 'Wrong integrated evaluation manifest'
    Require ([string]$Manifest.source_commit -match '^[0-9a-f]{40}$') 'Source SHA not pinned'
    $Summary.source=[string]$Manifest.source_commit
    $env:CYBERSAND_SOURCE_REVISION=$Summary.source
    # Editor import may rewrite generated Godot *.import metadata. Preserve
    # strict source/DLL/shader/test checks instead of refusing a package that
    # was already opened legitimately in the Workbench.
    $GeneratedMetadataSkipped=0
    foreach($HashEntry in $Manifest.files_sha256.PSObject.Properties) {
        if ($HashEntry.Name.EndsWith('.import') -or $HashEntry.Name.StartsWith('godot/.godot/')) {
            $GeneratedMetadataSkipped++
            continue
        }
        $Path=Join-Path $Root ($HashEntry.Name.Replace('/','\'))
        Require (Test-Path -LiteralPath $Path -PathType Leaf) "Missing package payload: $($HashEntry.Name)"
        Require ((Sha $Path) -eq [string]$HashEntry.Value) "Package payload hash drift: $($HashEntry.Name)"
    }
    $Summary.import_metadata_excluded_from_integrity=$GeneratedMetadataSkipped
    $Native=Join-Path $Project 'addons\cybersand_native\bin\cybersand_native.windows.x86_64.dll'
    $Rapier=Join-Path $Project 'addons\godot-rapier2d\bin\libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
    Require ((Sha $Native) -eq $Manifest.native_sha256) 'Native runtime not source-qualified'
    Require ((Sha $Rapier) -eq $Manifest.rapier_sha256) 'Rapier runtime hash drift'
    $Version=(& $Engine --version|Select-Object -First 1).Trim()
    Require ($Version -eq $Manifest.godot_version) 'Godot version not pinned'
    $Summary.godot_version=$Version
    $Summary.gpu=@(Get-CimInstance Win32_VideoController|ForEach-Object{@{name=$_.Name;driver=$_.DriverVersion
        resolution=@($_.CurrentHorizontalResolution,$_.CurrentVerticalResolution);refresh_hz=$_.CurrentRefreshRate}})
    $Summary.dpi_and_vsync_notice='Per-window Godot screen DPI, display scale, refresh rate and effective VSync enum are captured in each case display receipt. Scripted pacing disables VSync; manual review should also use your ordinary setting.'
    $Summary.windows=Get-CimInstance Win32_OperatingSystem|Select-Object Caption,Version,BuildNumber
    Save-Summary
    $env:APPDATA=Join-Path $Output 'import-userdata'
    $env:XDG_DATA_HOME=$env:APPDATA
    New-Item -ItemType Directory -Force -Path $env:APPDATA|Out-Null
    Run-Godot 'import' @('--headless','--path',$Project,'--editor','--quit') 240 $Output
    if($Coherence) {
        Run-CoherenceMatrix
    }elseif($Cadence -or $FullCadence) {
        Run-CadenceMatrix
    }elseif($Quick) {
        Run-Case 'freemass' 1 1 'follow' 'guarded' 60 60
    }elseif($Compare) {
        foreach($Camera in @('free','follow')) {
            foreach($Pose in @('guarded','mask')) {
                Run-Case 'freemass' 1 1 $Camera $Pose 60 60
            }
        }
        Run-Case 'freemass' 1 2 'follow' 'guarded' 30 30
        Run-Case 'freemass' 1 2 'follow' 'guarded' 120 120
    }else {
        $WorkerCounts=$(if($Full){@(1,4)}else{@(1)})
        foreach($W in $WorkerCounts) {
            foreach($Repeat in @(1,2)) {
                foreach($Family in @('freemass','pressure','cellular','inertial')) {
                    Run-Case $Family $W $Repeat 'follow' 'guarded' 60 60
                }
            }
        }
    }
    $Summary.complete=$true
    $Summary.status='passed'
    Save-Summary
    Write-Host "TEST IT CAPTURE COMPLETE: exact reference, tick-addressed inputs, native/Rapier progress and raw frame evidence retained. Physical acceptance remains pending." -ForegroundColor Green
}catch{
    $Summary.complete=$false
    $Summary.status='incomplete'
    $Summary.errors+=[string]$_.Exception.Message
    Save-Summary
    Write-Host ("TEST IT INCOMPLETE: "+$_.Exception.Message) -ForegroundColor Red
}finally{
    $env:APPDATA=$PreviousAppData
    $env:XDG_DATA_HOME=$PreviousXdg
    $env:CYBERSAND_SOURCE_REVISION=$PreviousSource
    $env:CYBERSAND_DIAG_FLYER_POSE=$PreviousPose
    $env:CYBERSAND_DIAG_RENDER_CADENCE=$PreviousCadence
    $env:CYBERSAND_DIAG_PRESENTATION=$PreviousPresentation
    $env:CYBERSAND_DIAG_MATERIAL_TIMING=$PreviousMaterialTiming
    try {
        Save-Summary
        Compress-Archive -LiteralPath $Output -DestinationPath $Zip -CompressionLevel Optimal
        Write-Host "EVIDENCE ZIP: $Zip" -ForegroundColor Cyan
        Write-Host ("ZIP SHA-256: "+(Sha $Zip))
    }catch{Write-Warning ("ZIP failed; original evidence preserved at "+$Output+": "+$_.Exception.Message)}
}
if(-not $Summary.complete){exit 1}
exit 0
