# CyberSand Test It: packaged Windows x64 graphical, real-Needle/2048 source.
# Local-only (no installs/downloads), all evidence retained, one final ZIP.
[CmdletBinding()]
param(
  [switch]$Quick,
  [switch]$Full,
  [switch]$Compare,
  [switch]$Cadence,
  [switch]$Coherence,
  [switch]$Publication,
  [string[]]$CoherenceConditions=@(),
  [switch]$FullCadence,
  [string[]]$CadenceConditions=@(),
  [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver='opengl3',
  [ValidateRange(60,1200)][int]$TimeoutSeconds=900
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ExplicitRenderingDriver=$PSBoundParameters.ContainsKey('RenderingDriver')
if(-not ($Coherence -or $Cadence -or $FullCadence -or $Full -or $Compare)){$Publication=$true}
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
$PreviousMaterialPublication=$env:CYBERSAND_MATERIAL_PUBLICATION
$PreviousPhysicsPublication=$env:CYBERSAND_DIAG_PHYSICS_PUBLICATION
$PreviousNativeRendezvous=$env:CYBERSAND_DIAG_NATIVE_RENDEZVOUS
$PreviousMaterialStagingSlots=$env:CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS
$PreviousMaterialHistoryTargets=$env:CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS
$PreviousMaterialCopyMode=$env:CYBERSAND_DIAG_MATERIAL_COPY_MODE
$PreviousCommonObserver=$env:CYBERSAND_DIAG_COMMON_OBSERVER
$Start=Get-Date
$Summary=@{schema='engine-lab-scripted-pose-test-it-v1';status='incomplete';complete=$false
    source='unverified';driver=$RenderingDriver;cases=@();errors=@();processes=@()
    powershell=@{version=[string]$PSVersionTable.PSVersion;edition=[string]$PSVersionTable.PSEdition
        home=$PSHOME;modules=$ModuleProvenance;validated_commands=$RequiredCommands}
    pairs=@();failures=@();physical_acceptance='pending_owner_NVIDIA_review'
    physics_rate_semantics='Fixed 1/60 second per completed Rapier step; 120 callbacks is not normalized 120Hz physics. Compare physical trajectories at equal completed steps.'
    mode=$(if($Publication){'publication'}elseif($Coherence){'coherence'}elseif($FullCadence){'full-cadence'}elseif($Cadence){'cadence'}elseif($Quick){'quick'}elseif($Compare){'compare'}elseif($Full){'full'}else{'eight-case'})}
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
function Physics-Distribution($Values) {
    # Match analyze_pose_trace.py's interpolated quantiles, independently of
    # the retained nearest-rank summaries used by the older pacing suite.
    $Sorted=@($Values|ForEach-Object{[double]$_}|Sort-Object)
    $Result=@{count=$Sorted.Count;minimum=$null;median=$null;p95=$null;p99=$null;maximum=$null;mean=$null}
    if($Sorted.Count -eq 0){return $Result}
    $Result.minimum=[Math]::Round($Sorted[0],6);$Result.maximum=[Math]::Round($Sorted[-1],6)
    $Result.mean=[Math]::Round([double]($Sorted|Measure-Object -Average).Average,6)
    foreach($Entry in @(@('median',0.5),@('p95',0.95),@('p99',0.99))) {
        $Index=($Sorted.Count-1)*[double]$Entry[1];$Low=[int][Math]::Floor($Index)
        $High=[Math]::Min($Low+1,$Sorted.Count-1)
        $Result[[string]$Entry[0]]=[Math]::Round($Sorted[$Low]+($Sorted[$High]-$Sorted[$Low])*($Index-$Low),6)
    }
    return $Result
}
function Event-Time($Event) {
    $Value=Field $Event 'time_usec' (Field $Event 'completed_usec')
    if($null -eq $Value){return $null}
    $Time=[double]$Value
    if($Time -ge 0 -and -not [double]::IsInfinity($Time) -and -not [double]::IsNaN($Time)){return $Time}
    return $null
}
function Read-PhysicsProgress($Frames,$Events) {
    # A displayed live pose may conceal stopped physics. Measure only exact,
    # consecutive completed-step events; do not infer completions from frames.
    $Steps=New-Object 'System.Collections.Generic.List[object]'
    $Seen=@{}
    foreach($Event in @($Events|Where-Object{(Field $_ 'event') -eq 'rapier_step' -and
            $null -ne (Event-Time $_)}|Sort-Object -Property {Event-Time $_})) {
        $Key=Field $Event 'step'
        if($null -eq $Key -or $Seen.ContainsKey([string]$Key)){continue}
        $Seen[[string]$Key]=$true;$Steps.Add($Event)
    }
    $Holds=@($Events|Where-Object{(Field $_ 'event') -eq 'rapier_hold' -and
        $null -ne (Event-Time $_)}|Sort-Object -Property {Event-Time $_})
    $MainTimes=@($Frames|ForEach-Object{[double]$_.time_usec}|Sort-Object)
    $Intervals=New-Object 'System.Collections.Generic.List[object]'
    $Missing=0;$HoldIndex=0;$MainIndex=0
    for($Index=1;$Index -lt $Steps.Count;$Index++) {
        $Before=$Steps[$Index-1];$After=$Steps[$Index]
        if([long]$After.step -ne [long]$Before.step+1){$Missing++;continue}
        $Begin=Event-Time $Before;$End=Event-Time $After
        Require ($End -ge $Begin) 'Nonmonotonic completed physics timestamps'
        $Reasons=@{}
        while($HoldIndex -lt $Holds.Count -and (Event-Time $Holds[$HoldIndex]) -le $Begin){$HoldIndex++}
        while($HoldIndex -lt $Holds.Count -and (Event-Time $Holds[$HoldIndex]) -le $End) {
            $Reason=[string](Field $Holds[$HoldIndex] 'reason' 'unknown')
            if(-not $Reasons.ContainsKey($Reason)){$Reasons[$Reason]=0};$Reasons[$Reason]++
            $HoldIndex++
        }
        while($MainIndex -lt $MainTimes.Count -and $MainTimes[$MainIndex] -le $Begin){$MainIndex++}
        $Submissions=0
        while($MainIndex -lt $MainTimes.Count -and $MainTimes[$MainIndex] -le $End){$Submissions++;$MainIndex++}
        $WorkStart=Field $After 'start_usec'
        $Interval=@{previous_step=$Before.step;step=$After.step;start_usec=$Begin;end_usec=$End
            gap_ms=($End-$Begin)/1000.0;hold_reasons=$Reasons;includes_pause=$Reasons.ContainsKey('paused')
            main_submissions=$Submissions;step_work_ms=$(if($null -ne $WorkStart){($End-[double]$WorkStart)/1000.0}else{$null})}
        foreach($FieldName in @('solver','flush')) {
            $Value=Field $After ($FieldName+'_usec')
            $Interval[$FieldName+'_ms']=$(if($null -ne $Value){[double]$Value/1000.0}else{$null})
        }
        $Intervals.Add($Interval)
    }
    $Active=@($Intervals|Where-Object{-not $_.includes_pause})
    $KnownFrames=@($Frames|Where-Object{$null -ne (Field $_ 'rapier_step')})
    $Unchanged=0
    for($Index=1;$Index -lt $KnownFrames.Count;$Index++) {
        $Before=$KnownFrames[$Index-1];$After=$KnownFrames[$Index]
        if($Before.rapier_step -eq $After.rapier_step -and
            -not [bool](Field $Before 'paused' $false) -and -not [bool](Field $After 'paused' $false)){$Unchanged++}
    }
    return @{consecutive_step_intervals=$Intervals.Count;unmeasured_intervals_with_missing_completions=$Missing
        pause_spanning_intervals=$Intervals.Count-$Active.Count
        active_completed_step_gap_ms=(Physics-Distribution @($Active|ForEach-Object{$_.gap_ms}))
        active_gaps_at_least_50ms=@($Active|Where-Object{$_.gap_ms -ge 50}).Count
        active_gaps_at_least_100ms=@($Active|Where-Object{$_.gap_ms -ge 100}).Count
        active_gaps_at_least_250ms=@($Active|Where-Object{$_.gap_ms -ge 250}).Count
        active_gaps_at_least_1000ms=@($Active|Where-Object{$_.gap_ms -ge 1000}).Count
        main_intervals_without_physics_progress=$Unchanged;observed_main_intervals=[Math]::Max(0,$KnownFrames.Count-1)
        step_work_ms=(Physics-Distribution @($Steps|Where-Object{$null -ne (Field $_ 'start_usec')}|ForEach-Object{((Event-Time $_)-[double]$_.start_usec)/1000.0}))
        solver_ms=(Physics-Distribution @($Steps|Where-Object{$null -ne (Field $_ 'solver_usec')}|ForEach-Object{[double]$_.solver_usec/1000.0}))
        flush_ms=(Physics-Distribution @($Steps|Where-Object{$null -ne (Field $_ 'flush_usec')}|ForEach-Object{[double]$_.flush_usec/1000.0}))
        # Windows PowerShell 5.1 does not resolve Hashtable keys through a
        # property-name sort. Read numeric keys explicitly; equal gaps retain
        # chronological order, matching the Python analyzer's stable sort.
        largest_active_gaps=@($Active|Sort-Object -Property `
            @{Expression={[double]$_['gap_ms']};Descending=$true}, `
            @{Expression={[double]$_['start_usec']};Ascending=$true}, `
            @{Expression={[long]$_['step']};Ascending=$true}|Select-Object -First 10)
        meaning='Wall-clock physical completions, separate from visual pose holds. Hold reasons are observed gates, not complete causal attribution. Step/solver timers include possible OS descheduling; no GPU scanout is measured.'}
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
    $FollowResidual=New-Object 'System.Collections.Generic.List[double]'
    $TemporalRewinds=0;$IntentionalHolds=0;$Withheld=0;$MissingSubmissions=0;$SelectedSteps=0;$UnknownSelectedSteps=0
    for($Index=0;$Index -lt $Frames.Count;$Index++) {
        $Frame=$Frames[$Index]
        $Contract=Field $Frame 'presentation'
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
    $Counts=@{};$Trajectory=@{};$EventTimes=@{};$UploadsBySerial=@{};$UnmatchedAcks=0;$PhysicsHolds=@{}
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
        if($Kind -eq 'rapier_hold') {
            $Reason=[string](Field $Event 'reason' 'unknown')
            if(-not $PhysicsHolds.ContainsKey($Reason)){$PhysicsHolds[$Reason]=0};$PhysicsHolds[$Reason]++
        }
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
            foreach($Required in @('step','native_tick_used','epoch','session','world_generation','native_response','hard_surface_shapes','pending_hard_chunks','input_tape_index','fixed_delta','simulation_time_sec','bodies')) {
                Require ($null -ne (Field $Event $Required)) ('Incomplete physical association record: '+$Required)
            }
            Require (@($Event.bodies).Count -gt 0) 'Physical completion has no actor state records'
            foreach($Body in @(Field $Event 'bodies' @())) {
                foreach($Required in @('slot','instance_id','xy','angle','velocity')) {
                    Require ($null -ne (Field $Body $Required)) ('Incomplete physical actor state: '+$Required)
                }
                Require (@($Body.xy).Count -eq 2 -and @($Body.velocity).Count -eq 2) 'Incomplete physical vectors'
                $Key=([string]$Event.step)+':'+([string]$Body.slot)
                Require (-not $Trajectory.ContainsKey($Key)) ('Duplicate completed Rapier event '+$Key)
                $Trajectory[$Key]=@{xy=@($Body.xy);velocity=@($Body.velocity);angle=[double]$Body.angle
                    native_tick_used=(Field $Event 'native_tick_used' -1)
                    feedback=(@{native_response=(Field $Event 'native_response');epoch=(Field $Event 'epoch');session=(Field $Event 'session');world_generation=(Field $Event 'world_generation');hard_surface_shapes=(Field $Event 'hard_surface_shapes');pending_hard_chunks=(Field $Event 'pending_hard_chunks');instance_id=(Field $Body 'instance_id');fixed_delta=(Field $Event 'fixed_delta');input_tape_index=(Field $Event 'input_tape_index');simulation_time_sec=(Field $Event 'simulation_time_sec')}|ConvertTo-Json -Depth 15 -Compress)}
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
        physics_progress=(Read-PhysicsProgress $Frames $Events);physics_hold_reasons=$PhysicsHolds
        snapshot_age_at_presentation_ms=(Distribution $SnapshotAges);bound_native_age_at_presentation_ms=(Distribution $NativeAges)
        native_tick_wall_ms=(Distribution $NativeWall);texture_upload_cpu_call_ms=(Distribution $UploadWall)
        snapshot_age_at_upload_ms=(Distribution $UploadAges);upload_to_ack_issue_ms=(Distribution $AckLatencies)
        ack_latency_unavailable=$UnmatchedAcks;presentation_cpu_ms=(Distribution $ResolveCpu)
        selected_step_observations=$SelectedSteps;selected_step_unknown_visible_frames=$UnknownSelectedSteps
        selected_source_time_rewinds=$TemporalRewinds;intentional_hold_frames=$IntentionalHolds
        withheld_body_frames=$Withheld;follow_target_minus_selected_cells=(Distribution $FollowResidual)
        callbacks_without_overlay_submission=$MissingSubmissions
        dropped_frames=[int]$Records[-1].dropped;duplicate_callbacks=[int]$Records[-1].duplicates
        actual_first_view=@($Frames[0].view_world_cells);actual_last_view=@($Frames[-1].view_world_cells)}
    $PublicationRows=@($Events|Where-Object{(Field $_ 'event') -eq 'texture_upload' -and $null -ne (Field $_ 'material_publication')}|ForEach-Object{Field $_ 'material_publication'})
    $PublicationScopes=@{}
    foreach($Scope in @('image_patch_usec','content_cache_usec','tile_assembly_usec','atlas_assembly_usec','backend_submit_usec','staging_upload_usec','gpu_blit_submit_usec')) {
        $Values=@($PublicationRows|Where-Object{$null -ne (Field $_ $Scope)}|ForEach-Object{[double](Field $_ $Scope)/1000.0})
        $PublicationScopes[$Scope]=Distribution $Values
    }
    $Result.material_publication_elapsed_ms=$PublicationScopes
    $Result.material_backend_modes=@{}
    $Result.material_fallback_reasons=@{}
    foreach($PublicationRow in $PublicationRows) {
        $Backend=[string](Field $PublicationRow 'backend' (Field $PublicationRow 'mode' 'unknown'))
        if(-not $Result.material_backend_modes.ContainsKey($Backend)){$Result.material_backend_modes[$Backend]=0}
        $Result.material_backend_modes[$Backend]++
        $Fallback=[string](Field $PublicationRow 'fallback_reason' '')
        if($Fallback) {
            if(-not $Result.material_fallback_reasons.ContainsKey($Fallback)){$Result.material_fallback_reasons[$Fallback]=0}
            $Result.material_fallback_reasons[$Fallback]++
        }
    }
    $Result.material_submitted_bytes=Distribution @($PublicationRows|Where-Object{$null -ne (Field $_ 'submitted_bytes')}|ForEach-Object{[double](Field $_ 'submitted_bytes')})
    $Result.material_estimated_target_write_bytes=Distribution @($PublicationRows|Where-Object{$null -ne (Field $_ 'estimated_target_write_bytes')}|ForEach-Object{[double](Field $_ 'estimated_target_write_bytes')})
    $Result.material_allocated_gpu_bytes=Distribution @($PublicationRows|Where-Object{$null -ne (Field $_ 'allocated_gpu_bytes')}|ForEach-Object{[double](Field $_ 'allocated_gpu_bytes')})
    $Result.physics_timing_observation=$(if($Result.physics_progress.active_completed_step_gap_ms.count -eq 0){
        'unavailable_no_consecutive_active_steps'
    }elseif($Result.physics_progress.active_gaps_at_least_100ms -gt 0){
        'performance_concern_100ms_plus'
    }else{'no_100ms_gap_observed_not_acceptance'})
    return @{statistics=$Result;trajectory=$Trajectory}
}
function Compare-PhysicalSteps($Before,$After,[int]$RequiredSteps=24) {
    $BeforeSteps=@($Before.Keys|ForEach-Object{[long]($_.Split(':')[0])}|Sort-Object -Unique)
    $AfterSteps=@($After.Keys|ForEach-Object{[long]($_.Split(':')[0])}|Sort-Object -Unique)
    Require ($BeforeSteps.Count -gt 0 -and $AfterSteps.Count -gt 0) 'Missing physical completion records'
    Require ($BeforeSteps[0] -eq $AfterSteps[0]) 'Compared captures start at different physical steps'
    Require ($BeforeSteps[0] -eq 1) 'Compared captures omit initial physical completions'
    foreach($Steps in @(@{values=$BeforeSteps},@{values=$AfterSteps})) {
        $Values=$Steps.values
        Require ($Values.Count -eq $Values[-1]-$Values[0]+1) 'Missing intermediate physical completion records'
    }
    $Last=[Math]::Min($BeforeSteps[-1],$AfterSteps[-1])
    Require ($Last -ge $RequiredSteps) 'Compared captures omit required physical completions'
    for($Step=[long]$BeforeSteps[0];$Step -le $Last;$Step++) {
        $Prefix=([string]$Step)+':'
        $BeforeSlots=@($Before.Keys|Where-Object{$_.StartsWith($Prefix)}|Sort-Object)
        $AfterSlots=@($After.Keys|Where-Object{$_.StartsWith($Prefix)}|Sort-Object)
        Require (($BeforeSlots -join ',') -ceq ($AfterSlots -join ',')) ('Missing or changed actor slots at step '+$Step)
    }
    $Positions=New-Object 'System.Collections.Generic.List[double]'
    $Velocities=New-Object 'System.Collections.Generic.List[double]'
    $Angles=New-Object 'System.Collections.Generic.List[double]'
    $DifferentNative=0;$DifferentFeedback=0
    foreach($Key in $Before.Keys) {
        if(-not $After.ContainsKey($Key)){continue}
        $A=$Before[$Key];$B=$After[$Key]
        $Position=Gap $A.xy $B.xy;$Velocity=Gap $A.velocity $B.velocity
        if($null -ne $Position){$Positions.Add($Position)}
        if($null -ne $Velocity){$Velocities.Add($Velocity)}
        $Angles.Add([Math]::Abs([Math]::Atan2([Math]::Sin($A.angle-$B.angle),[Math]::Cos($A.angle-$B.angle))))
        if($A.native_tick_used -ne $B.native_tick_used){$DifferentNative++}
        if((Field $A 'feedback' '') -cne (Field $B 'feedback' '')){$DifferentFeedback++}
    }
    return @{comparison_clock='same completed Rapier step and body slot, fixed 1/60 simulated seconds per step'
        common_step_bodies=$Positions.Count;legacy_step_bodies=$Before.Count;repaired_step_bodies=$After.Count
        position_delta_cells=(Distribution $Positions);velocity_delta=(Distribution $Velocities)
        angle_delta_radians=(Distribution $Angles);different_native_tick_inputs=$DifferentNative
        different_feedback=$DifferentFeedback
        exact=($Positions.Count -gt 0 -and ($Positions|Measure-Object -Maximum).Maximum -eq 0 -and ($Velocities|Measure-Object -Maximum).Maximum -eq 0 -and ($Angles|Measure-Object -Maximum).Maximum -eq 0 -and $DifferentNative -eq 0 -and $DifferentFeedback -eq 0)
        status=$(if($Positions.Count -eq 0){'unavailable'}elseif(($Positions|Measure-Object -Maximum).Maximum -gt 0.001){'physical_trajectory_differs'}else{'matched_within_0.001_cells'})}
}
function Read-LauncherWorkerPreference {
    # FeatureLauncher reads this one file before Main is constructed. Inspect
    # the ordinary profile without copying it into cases or changing it.
    $Preference=@{requested=0;status='no saved override; Auto';exists=$false
        meaning='Ordinary launcher request only. Each case records its actual resolved native pool separately.'}
    if([string]::IsNullOrEmpty($PreviousAppData)){$Preference.status='APPDATA unavailable';return $Preference}
    $ProjectText=Get-Content -LiteralPath (Join-Path $Project 'project.godot') -Raw -Encoding UTF8
    $Match=[regex]::Match($ProjectText,'(?m)^config/name="([^"]+)"')
    Require $Match.Success 'Cannot identify ordinary Godot user-data directory'
    $UserProfileFolder=Join-Path (Join-Path $PreviousAppData 'Godot\app_userdata') $Match.Groups[1].Value
    $Preference.path=Join-Path $UserProfileFolder 'cybersand-engine-lab-workers.json'
    if(-not (Test-Path -LiteralPath $Preference.path -PathType Leaf)){return $Preference}
    $Preference.exists=$true
    try {
        $Preference.sha256=Sha $Preference.path
        $Saved=Get-Content -LiteralPath $Preference.path -Raw -Encoding UTF8|ConvertFrom-Json
        $Value=Field $Saved 'native_threads'
        if(($Value -is [int] -or $Value -is [long]) -and $Value -ge 0 -and $Value -le 32) {
            $Preference.requested=[int]$Value
            $Preference.status=$(if($Value -eq 0){'saved Auto request'}else{'saved explicit worker request'})
        }else{$Preference.status='invalid saved value; launcher retains Auto'}
    }catch{$Preference.status='unreadable saved preference';$Preference.error=[string]$_.Exception.Message}
    return $Preference
}
function Save-Summary {
    $Summary.elapsed_seconds=[Math]::Round(((Get-Date)-$Start).TotalSeconds,3)
    $Summary.physics_timing_concerns=@($Summary.cases|Where-Object{$_.statistics.physics_timing_observation -eq 'performance_concern_100ms_plus'}).Count
    [IO.File]::WriteAllText((Join-Path $Output 'summary.json'),
      (($Summary|ConvertTo-Json -Depth 28)+[Environment]::NewLine),
      [Text.UTF8Encoding]::new($false))
    $Lines=New-Object 'System.Collections.Generic.List[string]'
    $Lines.Add('CyberSand presentation comparison - local measured results')
    $Lines.Add('Source: '+$Summary.source)
    $Lines.Add('Capture status: '+$Summary.status+'; physical NVIDIA acceptance: PENDING OWNER REVIEW')
    $Lines.Add('A complete capture is not a physics smoothness or physical NVIDIA acceptance result.')
    $Lines.Add(('Cases with measured active physics gaps of at least 100ms: {0}. These are performance concerns even when capture completes.' -f $Summary.physics_timing_concerns))
    $Lines.Add('Rates below are achieved. Coupled defaults preserve startup VSync; the six pacing experiments disable it.')
    $Lines.Add('Main means overlay submission, not monitor scanout. See summary.json and raw traces for full evidence.')
    $Lines.Add('Rapier targets count callbacks per second; each completed step still advances 1/60 simulated second.')
    foreach($CpuIdentity in @(Field $Summary 'cpu' @())) {
        $Lines.Add(('CPU: {0}; logical processors: {1}; physical cores: {2}' -f $CpuIdentity.model,$CpuIdentity.logical_processors,$CpuIdentity.physical_cores))
    }
    $Preference=Field $Summary 'launcher_worker_preference'
    if($null -ne $Preference) {
        $Lines.Add(('Ordinary launcher worker request: {0} ({1}). Case profiles are isolated; your saved setting is unchanged.' -f $Preference.requested,$Preference.status))
    }
    $Lines.Add('')
    foreach($Row in $Summary.cases) {
        $Stats=$Row.statistics;$Timing=$Stats.frame_interval_ms;$Cpu=$Stats.presentation_cpu_ms
        $Physics=Field $Stats 'physics_progress';$Gaps=Field $Physics 'active_completed_step_gap_ms'
        $PhysicsHolds=Field $Stats 'physics_hold_reasons' @{}
        $Lines.Add($Row.name)
        $TimingDescription=$(if($Stats.physics_timing_observation -eq 'performance_concern_100ms_plus'){
            'PERFORMANCE CONCERN: active completed-step gaps reached at least 100ms.'
        }elseif($Stats.physics_timing_observation -eq 'unavailable_no_consecutive_active_steps'){
            'UNAVAILABLE: no exact consecutive active completed-step intervals.'
        }else{'No 100ms gap observed; this alone is not a gameplay acceptance result.'})
        $Lines.Add('  Physics: '+$TimingDescription)
        $Material=Field $Row 'material_publication'
        $Lines.Add(('  Material publication: requested={0}, backend={1}, last CPU upload bytes={2}; physics handoff={3}' -f
            (Field $Material 'requested_mode' 'unrecorded'),(Field $Material 'backend' 'unrecorded'),
            (Field $Material 'submitted_bytes' 'unrecorded'),(Field $Row 'physics_publication' 'unrecorded')))
        foreach($Scope in @('image_patch_usec','content_cache_usec','tile_assembly_usec','atlas_assembly_usec','backend_submit_usec','staging_upload_usec','gpu_blit_submit_usec')) {
            $ScopeTiming=Field (Field $Stats 'material_publication_elapsed_ms') $Scope
            $Lines.Add(('  {0} elapsed ms median/p95/max: {1} / {2} / {3}' -f $Scope,
                (Field $ScopeTiming 'p50' 'n/a'),(Field $ScopeTiming 'p95' 'n/a'),(Field $ScopeTiming 'max' 'n/a')))
        }

        $Lines.Add('  Timing scopes overlap: backend includes staging upload and GPU blit/retirement submission; assembly aliases must not be added. These are elapsed wall calls, not isolated CPU/GPU execution.')
        $Lines.Add(('  Logical GPU target-write bytes median: {0}; allocated GPU texture bytes maximum: {1}. These are estimates, not measured bandwidth.' -f
            (Field (Field $Stats 'material_estimated_target_write_bytes') 'p50' 'n/a'),
            (Field (Field $Stats 'material_allocated_gpu_bytes') 'max' 'n/a')))
        $WorkerRequest=$(if($Row.native_workers.requested -eq 0){'Auto (0)'}else{[string]$Row.native_workers.requested})
        $Lines.Add(('  Profile: {0}; renderer: {1}; VSync enum: {2}; window: {3}; native workers requested/resolved: {4} / {5}' -f
            $Row.display.profile,$Row.render_driver,$Row.display.vsync_mode,($Row.display.window_size -join 'x'),$WorkerRequest,$Row.native_workers.resolved_capacity))
        $DisplayStartup=Field $Row.display 'startup'
        $Lines.Add(('  VSync enum project/start/effective: {0} / {1} / {2}; started window: {3}' -f
            (Field $DisplayStartup 'project_vsync_mode' 'unrecorded'),(Field $DisplayStartup 'vsync_mode' 'unrecorded'),
            $Row.display.vsync_mode,((Field $DisplayStartup 'window_size' @('unrecorded')) -join 'x')))
        $Lines.Add(('  Native/Rapier targets: {0} / {1}; wait for native sample: {2}; wake on sample: {3}' -f
            $Row.pixel_target_hz,$Row.rapier_callback_target_hz,$Row.wait_native_sample,$Row.wake_on_rapier_sample))
        $Lines.Add(('  Main/native/Rapier Hz: {0:N2} / {1:N2} / {2:N2}' -f $Stats.achieved_overlay_fps,$Stats.achieved_native_hz,$Stats.achieved_rapier_hz))
        $Lines.Add(('  Main interval ms median/p95/p99: {0} / {1} / {2}; samples: {3}' -f (Field $Timing 'p50' 'n/a'),(Field $Timing 'p95' 'n/a'),(Field $Timing 'p99' 'n/a'),(Field $Timing 'count' 0)))
        $Lines.Add(('  Completed Rapier gap ms median/p95/p99/max: {0} / {1} / {2} / {3}; consecutive active intervals: {4}' -f
            (Field $Gaps 'median' 'n/a'),(Field $Gaps 'p95' 'n/a'),(Field $Gaps 'p99' 'n/a'),(Field $Gaps 'maximum' 'n/a'),(Field $Gaps 'count' 0)))
        $Lines.Add(('  Active gaps at least 50 / 100 / 250 / 1000 ms: {0} / {1} / {2} / {3}; Main intervals without physical progress: {4} / {5}' -f
            $Physics.active_gaps_at_least_50ms,$Physics.active_gaps_at_least_100ms,$Physics.active_gaps_at_least_250ms,$Physics.active_gaps_at_least_1000ms,
            $Physics.main_intervals_without_physics_progress,$Physics.observed_main_intervals))
        $Lines.Add(('  Physics hold callbacks: native_sample={0}; terrain_installation={1}; paused={2}; all reasons: {3}' -f
            (Field $PhysicsHolds 'native_sample' 0),(Field $PhysicsHolds 'terrain_installation' 0),(Field $PhysicsHolds 'paused' 0),($PhysicsHolds|ConvertTo-Json -Compress)))
        $Lines.Add(('  Excluded pause-spanning intervals: {0}; unmeasured intervals with missing completions: {1}' -f
            $Physics.pause_spanning_intervals,$Physics.unmeasured_intervals_with_missing_completions))
        foreach($Stage in @('step_work_ms','solver_ms','flush_ms')) {
            $Work=Field $Physics $Stage
            $Lines.Add(('  {0} median/p95/p99/max: {1} / {2} / {3} / {4}; samples: {5}' -f
                $Stage,(Field $Work 'median' 'n/a'),(Field $Work 'p95' 'n/a'),(Field $Work 'p99' 'n/a'),(Field $Work 'maximum' 'n/a'),(Field $Work 'count' 0)))
        }
        $Lines.Add(('  Presentation CPU ms median/p95/p99: {0} / {1} / {2}; recorded source rewinds: {3}' -f (Field $Cpu 'p50' 'n/a'),(Field $Cpu 'p95' 'n/a'),(Field $Cpu 'p99' 'n/a'),$Stats.selected_source_time_rewinds))
        $Lines.Add(('  Visual selection only - intentional holds: {0}; withheld actor frames: {1}' -f $Stats.intentional_hold_frames,$Stats.withheld_body_frames))
        $Lines.Add(('  Known selected steps: {0}; visible unknown source times: {1}; callbacks without a submission: {2}' -f $Stats.selected_step_observations,$Stats.selected_step_unknown_visible_frames,$Stats.callbacks_without_overlay_submission))
        $Lines.Add('')
    }
    $Lines.Add('Physics hold reasons identify observed gates, not complete causes. Material and solver scopes are elapsed wall calls, including possible waits and OS descheduling; they do not isolate CPU execution or GPU transfer time.')
    $Lines.Add('Zero visual holds or zero 100ms gaps alone does not establish continuous or acceptable gameplay.')
    $Lines.Add('Compare your ordinary interactive renderer, VSync, worker setting and gameplay separately; hosted software rendering is not physical NVIDIA evidence.')
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
                  [string]$PoseSelection='coherent',[string]$FireMode='unchanged',[string]$DisplayProfile='scripted') {
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
    New-Item -ItemType Directory -Force -Path $env:APPDATA|Out-Null
    Write-Host "TEST IT | $Name | real 2048-square World / Needle physics tape" -ForegroundColor Cyan
    $Arguments=@()
    if($DisplayProfile -eq 'scripted') {
        $Arguments+=@('--rendering-driver',$RenderingDriver,'--rendering-method',
            'gl_compatibility','--audio-driver','Dummy','--max-fps',[string]$Fps)
    }elseif($ExplicitRenderingDriver){$Arguments+=@('--rendering-driver',$RenderingDriver)}
    $Arguments+=@('--path',$Project,'--script','res://tests/test_engine_lab_physical_test_it.gd',
       '--','--engine-lab-scripted',"--family=$Family","--workers=$Workers",
       "--repeat=$Repeat","--camera=$Camera","--pose=$Pose",
       "--pixel-hz=$PixelHz","--publication-hz=$RenderHz","--fps=$Fps","--rapier-hz=$RapierHz",
       "--ack-delay=$AckDelay","--ack-gated=$([int]$AckGated)","--wait-sample=$([int]$WaitSample)",
       "--sample-wake=$([int]$SampleWake)","--smoothing=$([int]$Smoothing)","--cadence=$Presentation",
       "--cadence-tape=$([int]$CadenceTape)","--presentation=$PoseSelection","--fire-mode=$FireMode",
       "--display-profile=$DisplayProfile","--receipt=$Receipt")
    $CaseIdentity=@{name=$Name;source=$Summary.source;arguments=$Arguments;isolated_user_profile=$env:APPDATA
        requested_native_workers=$Workers;display_profile=$DisplayProfile;material_publication=$env:CYBERSAND_MATERIAL_PUBLICATION;physics_publication=$env:CYBERSAND_DIAG_PHYSICS_PUBLICATION
        material_staging_slots=$env:CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS;material_history_targets=$env:CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS
        native_rendezvous=$env:CYBERSAND_DIAG_NATIVE_RENDEZVOUS;material_copy_mode=$env:CYBERSAND_DIAG_MATERIAL_COPY_MODE;common_observer=$env:CYBERSAND_DIAG_COMMON_OBSERVER;rendering_driver_override=$(if($DisplayProfile -eq 'scripted' -or $ExplicitRenderingDriver){$RenderingDriver}else{$null})}
    [IO.File]::WriteAllText((Join-Path $Dir 'case.json'),(($CaseIdentity|ConvertTo-Json -Depth 8)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    Run-Godot $Name $Arguments $TimeoutSeconds $Dir
    Require (Test-Path -LiteralPath $Receipt -PathType Leaf) "$Name did not write a receipt"
    $Data=Get-Content -LiteralPath $Receipt -Raw -Encoding UTF8|ConvertFrom-Json
    $Trace=Join-Path $Dir 'receipt-poses.jsonl'
    Require (Test-Path -LiteralPath $Trace -PathType Leaf) "$Name did not write pose JSONL"
    Require ($Data.complete -eq $true -and $Data.status -eq 'passed') "$Name incomplete"
    Require ($Data.source_sha -eq $Summary.source) "$Name source identity changed"
    Require ($Data.presentation_mode -eq $PoseSelection -and $Data.cadence_mode -eq $Presentation) "$Name comparison arm differs"
    Require ($Data.native_workers.requested -eq $Workers -and $Data.native_workers.observed_request -eq $Workers -and
        $Data.native_workers.resolved_capacity -gt 0) "$Name native worker selection not verified"
    Require ($Data.cpu.logical_processors -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$Data.cpu.model)) "$Name CPU identity missing"
    Require ($Data.effective_pacing.pixel_hz -eq $PixelHz -and $Data.effective_pacing.rapier_callback_hz -eq $RapierHz -and
        $Data.effective_pacing.wait_native_sample -eq $WaitSample -and $Data.effective_pacing.sample_wake -eq $SampleWake -and
        $Data.effective_pacing.graphical_fps_cap -eq $Fps -and $Data.effective_pacing.publication_hz -eq $RenderHz -and
        $Data.effective_pacing.ack_delay_frames -eq $AckDelay -and $Data.effective_pacing.ack_gated_publication -eq $AckGated -and
        $Data.effective_pacing.smoothing -eq $Smoothing) "$Name effective pacing differs from requested settings"
    Require ($Data.display.profile -eq $DisplayProfile) "$Name display profile differs"
    if($DisplayProfile -eq 'interactive-default') {
        Require ($Data.display.vsync_mode -eq $Data.display.startup.vsync_mode) "$Name changed the ordinary startup VSync setting"
    }
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
    $ExpectedView=$(if($DisplayProfile -eq 'interactive-default'){@(480,270)}else{@(240,135)})
    Require ($Data.view_size[0] -eq $ExpectedView[0] -and $Data.view_size[1] -eq $ExpectedView[1]) "$Name actual view does not match requested framing"
    Require (@($Data.framebuffer_captures).Count -eq 2) "$Name did not capture both actual framebuffers"
    $Analysis=Read-PoseStatistics $Trace
    Require ($Analysis.statistics.physics_progress.consecutive_step_intervals -gt 0) "$Name missing exact completed Rapier intervals"
    [IO.File]::WriteAllText((Join-Path $Dir 'analysis.json'),
        (($Analysis.statistics|ConvertTo-Json -Depth 28)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    if(($Coherence -or $Publication) -and $PoseSelection -eq 'coherent') {
        Require ($Analysis.statistics.selected_step_observations -gt 0 -and
            $Analysis.statistics.selected_source_time_rewinds -eq 0) "$Name missing or rewinding selected presentation timeline"
        if($Camera -eq 'follow') {
            $Follow=$Analysis.statistics.follow_target_minus_selected_cells
            Require ($null -ne $Follow -and [double](Field $Follow 'max' 1) -le 0.000001) "$Name Follow target differs from selected pose"
        }
    }
    $Row=@{name=$Name;passed=$true;workers=$Workers;family=$Family;camera=$Camera;pose=$Pose
        condition=$Condition;cadence_mode=$Presentation;presentation_mode=$PoseSelection
        fire_schedule=$Data.fire_schedule;display=$Data.display;cpu=$Data.cpu;native_workers=$Data.native_workers
        effective_pacing=$Data.effective_pacing;render_driver=$Data.render_driver
        material_publication=(Field $Data 'material_publication');physics_publication=(Field $Data 'physics_publication')
        pixel_target_hz=$PixelHz;publication_target_hz=$RenderHz;graphical_fps_target=$Fps
        rapier_callback_target_hz=$RapierHz;fixed_simulation_step_seconds=(1.0/60.0)
        ack_delay_frames=$AckDelay;ack_gated_publication=$AckGated;wait_native_sample=$WaitSample
        wake_on_rapier_sample=$SampleWake;smoothing=$Smoothing;statistics=$Analysis.statistics
        actual_native_ticks=$Data.native_ticks;actual_rapier_steps=$Data.rapier_steps
        rendered_pose_frames=$Data.trace.frames;dropped=$Data.trace.dropped
        video_adapter=$Data.video_adapter;receipt_sha256=(Sha $Receipt);trace_sha256=(Sha $Trace);case_sha256=(Sha (Join-Path $Dir 'case.json'))}
    $Summary.cases+=,$Row
    $script:LastCaseRow=$Row
    $script:LastTrajectory=$Analysis.trajectory
    Save-Summary
    Write-Host "CAPTURE COMPLETE $Name - $($Row.rendered_pose_frames) trace frames" -ForegroundColor Cyan
    if($Analysis.statistics.physics_timing_observation -eq 'performance_concern_100ms_plus') {
        Write-Host ('PERFORMANCE CONCERN {0}: {1} active Rapier gaps at least 100ms; maximum {2}ms. See READ-RESULTS.txt.' -f
            $Name,$Analysis.statistics.physics_progress.active_gaps_at_least_100ms,$Analysis.statistics.physics_progress.active_completed_step_gap_ms.maximum) -ForegroundColor Yellow
    }
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
function Run-PublicationMatrix {
    # The owner comparison selects the source defaults for experimental material
    # controls. Inherited probe settings must not silently select another design
    # or suppress the callback/mailbox evidence. Restore the caller in finally.
    $env:CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS=''
    $env:CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS=''
    $env:CYBERSAND_DIAG_MATERIAL_COPY_MODE=''
    $env:CYBERSAND_DIAG_COMMON_OBSERVER='0'
    $env:CYBERSAND_DIAG_NATIVE_RENDEZVOUS=''
    $Summary.publication_controls=@{staging_slots='source default';history_targets='source default';copy_mode='source default';detailed_observer=$true}
    $MatrixPath=Join-Path $Project 'tests\fixtures\engine_lab\coherence-conditions.json'
    $Matrix=Get-Content -LiteralPath $MatrixPath -Raw -Encoding UTF8|ConvertFrom-Json
    Require ($Matrix.schema -eq 'camera-stack-coherence-conditions-v1') 'Unknown publication condition schema'
    $Conditions=@($Matrix.conditions|Where-Object{$_.name -in @('interactive-follow','interactive-free')})
    if($Quick){$Conditions=@($Conditions|Where-Object{$_.name -eq 'interactive-follow'})}
    Require ($Conditions.Count -eq $(if($Quick){1}else{2})) 'Missing ordinary publication comparison conditions'
    $Summary.planned_conditions=$Conditions;$Summary.planned_cases=$Conditions.Count*2
    $Summary.comparison='Same reviewed source: full texture/combined publication control versus automatic staged GPU rectangle copies/early physics publication; both coherent, fixed-step and strictly coupled. This control does not restore the historical binary.'
    Save-Summary
    foreach($Condition in $Conditions) {
        $Rows=@{};$Trajectories=@{}
        foreach($Arm in @('control','candidate')) {
            try {
                $env:CYBERSAND_MATERIAL_PUBLICATION=$(if($Arm -eq 'control'){'full'}else{'auto'})
                $env:CYBERSAND_DIAG_PHYSICS_PUBLICATION=$(if($Arm -eq 'control'){'combined'}else{''})
                Run-Case 'freemass' ([int]$Condition.workers) 1 $Condition.camera $Condition.pose $Condition.pixel $Condition.publication `
                    $Condition.fps $Condition.rapier $Condition.ack $Condition.gated $Condition.wait $Condition.wake `
                    $Condition.smoothing 'repaired' ($Condition.name+'-'+$Arm) $true 'coherent' $Condition.fire $Condition.display_profile
                $Rows[$Arm]=$script:LastCaseRow;$Trajectories[$Arm]=$script:LastTrajectory
                Require ($Rows[$Arm].material_publication.requested_mode -eq $env:CYBERSAND_MATERIAL_PUBLICATION) 'Material publication control did not reach the runtime'
                Require ($Rows[$Arm].physics_publication -eq $(if($Arm -eq 'control'){'combined'}else{'early'})) 'Physics publication control did not reach the runtime'
                $ExpectedBackend=$(if($Arm -eq 'control'){'full'}else{'blit'})
                $BackendModes=$Rows[$Arm].statistics.material_backend_modes
                Require ($Rows[$Arm].material_publication.backend -eq $ExpectedBackend -and
                    $BackendModes.Count -eq 1 -and $BackendModes.ContainsKey($ExpectedBackend) -and
                    $Rows[$Arm].statistics.material_fallback_reasons.Count -eq 0) 'Capture did not exercise the expected material backend throughout. Full fallback is valid application behavior but cannot qualify this incremental-publication comparison.'
            }catch{
                $Summary.failures+=@{condition=$Condition.name;arm=$Arm;error=[string]$_.Exception.Message}
                Write-Host ('CASE INCOMPLETE: '+$Condition.name+' '+$Arm+' '+$_.Exception.Message) -ForegroundColor Red
                Save-Summary
            }
        }
        if($Rows.Count -eq 2) {
            $Comparison=Compare-PhysicalSteps $Trajectories.control $Trajectories.candidate 144
            $Summary.pairs+=@{condition=$Condition.name;control=$Rows.control.name;candidate=$Rows.candidate.name
                physical_trajectory=$Comparison;control_statistics=$Rows.control.statistics;candidate_statistics=$Rows.candidate.statistics}
            if(-not $Comparison.exact){$Summary.failures+=@{condition=$Condition.name;error='Physical states or native feedback associations differ; inspect the preserved comparison and raw traces'}}
            Save-Summary
        }
    }
    $script:LastTrajectory=@{}
    Require ($Summary.failures.Count -eq 0) 'Publication comparison is incomplete; all original evidence is retained'
}

function Run-CoherenceMatrix {
    $MatrixPath=Join-Path $Project 'tests\fixtures\engine_lab\coherence-conditions.json'
    $Matrix=Get-Content -LiteralPath $MatrixPath -Raw -Encoding UTF8|ConvertFrom-Json
    Require ($Matrix.schema -eq 'camera-stack-coherence-conditions-v1') 'Wrong coherence matrix schema'
    $Conditions=@($Matrix.conditions)
    if($Quick){$Conditions=@($Conditions|Where-Object{$_.name -eq $Matrix.quick_condition})}
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
                Run-Case 'freemass' ([int](Field $Condition 'workers' 1)) 1 $Condition.camera $Condition.pose $Condition.pixel $Condition.publication `
                    $Condition.fps $Condition.rapier $Condition.ack $Condition.gated $Condition.wait $Condition.wake `
                    $Condition.smoothing 'repaired' $Condition.name $true $Selection $Condition.fire ([string](Field $Condition 'display_profile' 'scripted'))
                $Rows[$Selection]=$script:LastCaseRow;$Trajectories[$Selection]=$script:LastTrajectory
            }catch{
                $Summary.failures+=@{condition=$Condition.name;presentation=$Selection;error=[string]$_.Exception.Message}
                Write-Host ('CASE INCOMPLETE: '+$Condition.name+' '+$Selection+' '+$_.Exception.Message) -ForegroundColor Red
                Save-Summary
            }
        }
        if($Rows.Count -eq 2) {
            $Summary.pairs+=@{condition=$Condition.name;legacy=$Rows.legacy.name;coherent=$Rows.coherent.name
                physical_trajectory=(Compare-PhysicalSteps $Trajectories.legacy $Trajectories.coherent)
                legacy_statistics=$Rows.legacy.statistics;coherent_statistics=$Rows.coherent.statistics}
            Save-Summary
        }
    }
    $script:LastTrajectory=@{}
    Require ($Summary.failures.Count -eq 0) 'One or more coherence cases were incomplete; all available evidence was retained'
}
try {
    Require (-not ($Publication -and ($Coherence -or $Cadence -or $FullCadence -or $Full -or $Compare))) 'Publication may combine with Quick only'
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
    $Summary.cpu=@(Get-CimInstance Win32_Processor|ForEach-Object{@{model=$_.Name
        logical_processors=$_.NumberOfLogicalProcessors;physical_cores=$_.NumberOfCores;architecture=$_.Architecture}})
    $Summary.launcher_worker_preference=Read-LauncherWorkerPreference
    $Summary.gpu=@(Get-CimInstance Win32_VideoController|ForEach-Object{@{name=$_.Name;driver=$_.DriverVersion
        resolution=@($_.CurrentHorizontalResolution,$_.CurrentVerticalResolution);refresh_hz=$_.CurrentRefreshRate}})
    $Summary.dpi_and_vsync_notice='Each case records DPI, scale, refresh, window size, startup/effective VSync and renderer. Coupled interactive-default cases preserve startup VSync/window/zoom; six retained pacing cases disable VSync and use a smaller matched view. Driver/desktop differences remain explicit; hosted software rendering is not physical NVIDIA acceptance.'
    $Summary.rendering_driver_request=@{driver=$RenderingDriver;explicit_override=$ExplicitRenderingDriver
        interactive_default=$(if($ExplicitRenderingDriver){'explicit command-line override'}else{'project/platform default; no driver override'})}
    $Summary.case_profile_notice='Fresh isolated profiles preserve the owner saved settings. Auto0 reproduces a fresh launcher default, not a saved explicit worker override. Native pool capacity is not CPU utilization.'
    $Summary.windows=Get-CimInstance Win32_OperatingSystem|Select-Object Caption,Version,BuildNumber
    Save-Summary
    $env:CYBERSAND_DIAG_NATIVE_RENDEZVOUS=''
    $env:APPDATA=Join-Path $Output 'import-userdata'
    $env:XDG_DATA_HOME=$env:APPDATA
    New-Item -ItemType Directory -Force -Path $env:APPDATA|Out-Null
    Run-Godot 'import' @('--headless','--path',$Project,'--editor','--quit') 240 $Output
    if($Publication) {
        Run-PublicationMatrix
    }elseif($Coherence) {
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
    $env:CYBERSAND_MATERIAL_PUBLICATION=$PreviousMaterialPublication
    $env:CYBERSAND_DIAG_PHYSICS_PUBLICATION=$PreviousPhysicsPublication
    $env:CYBERSAND_DIAG_NATIVE_RENDEZVOUS=$PreviousNativeRendezvous
    $env:CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS=$PreviousMaterialStagingSlots
    $env:CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS=$PreviousMaterialHistoryTargets
    $env:CYBERSAND_DIAG_MATERIAL_COPY_MODE=$PreviousMaterialCopyMode
    $env:CYBERSAND_DIAG_COMMON_OBSERVER=$PreviousCommonObserver
    try {
        Save-Summary
        Compress-Archive -LiteralPath $Output -DestinationPath $Zip -CompressionLevel Optimal
        Write-Host "EVIDENCE ZIP: $Zip" -ForegroundColor Cyan
        Write-Host ("ZIP SHA-256: "+(Sha $Zip))
    }catch{Write-Warning ("ZIP failed; original evidence preserved at "+$Output+": "+$_.Exception.Message)}
}
if(-not $Summary.complete){exit 1}
exit 0
