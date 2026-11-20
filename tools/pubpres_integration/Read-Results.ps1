function Assert-Result([bool]$Condition, [string]$Reason) {
    if (-not $Condition) { throw $Reason }
}

function Get-Field($Object, [string]$Name, $Default = $null) {
    if ($null -eq $Object) { return $Default }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $Default }
    return $Property.Value
}

function Read-Json([string]$Path) {
    return ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($Path))
}

function Write-Json([string]$Path, $Object) {
    [IO.File]::WriteAllText($Path, (($Object | ConvertTo-Json -Depth 60) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Distribution($Values) {
    $Sorted = @($Values | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ } | Sort-Object)
    if ($Sorted.Count -eq 0) { return $null }
    $Result = [ordered]@{ count=$Sorted.Count; max=$Sorted[-1] }
    foreach ($Quantile in @('p50','p95','p99')) {
        $Position = ($Sorted.Count-1) * ([int]$Quantile.Substring(1)/100.0)
        $Lo = [int][Math]::Floor($Position)
        $Hi = [int][Math]::Ceiling($Position)
        $Result[$Quantile] = $Sorted[$Lo]+($Sorted[$Hi]-$Sorted[$Lo])*($Position-$Lo)
    }
    return $Result
}

function Read-Transition($Data, [string]$Folder, $Manifest, $Arm, [string]$Driver, [string]$Nonce) {
    Assert-Result ($Data.schema -eq 'pubpres-transition-v1' -and $Data.complete -eq $true -and $Data.case -eq 'transition_2048_w1') 'Transition receipt incomplete'
    Assert-Result ($Data.context.source_revision -eq $Manifest.source_commit -and $Data.context.display_server -ne 'headless' -and
        $Data.context.nonce -eq $Nonce -and $Data.context.backend -eq $Driver -and $Data.context.engine_sha256 -eq $Manifest.engine.gui_sha256) 'Transition source, process, engine or renderer differs'
    Assert-Result (($Data.size -join 'x') -eq '2048x2048' -and $Data.channels -eq 2 -and $Data.warmup_frames -eq 30 -and
        $Data.samples.Count -eq 180 -and $Data.material_strategy -eq $Arm.material -and $Data.initial_plane_sha256 -match '^[0-9a-f]{64}$') 'Transition geometry, treatment or tape differs'
    Assert-Result ($Data.history.current_matches -and $Data.history.previous_matches) 'Transition lost texture history'
    Assert-Result ((Get-Sha (Join-Path $Folder 'receipt-after.png')) -eq $Data.screenshot_sha256) 'Transition screenshot differs'
    $Phases = [ordered]@{}
    $Modes = @{}
    $Dense = 0
    $Sparse = 0
    for ($Index = 0; $Index -lt $Data.samples.Count; $Index++) {
        $Sample = $Data.samples[$Index]
        $Sequence = $Index+30
        $Phase = switch ($Sequence%12) { 0 {'enter_dense'} 1 {'dense'} 2 {'enter_sparse'} default {'sparse'} }
        $IsDense = $Sequence%12 -lt 2
        Assert-Result ($Sample.sequence -eq $Sequence -and $Sample.sample -eq $Index -and $Sample.accepted -eq $true -and
            $Sample.accepted_revision -eq $Sequence+1 -and $Sample.phase -eq $Phase -and $Sample.dense -eq $IsDense -and
            $Sample.patch_bytes -eq $(if ($IsDense) {8388608} else {128})) 'Transition silently changed cadence or skipped input'
        $Backend = $Sample.material.backend
        $Modes[$Backend] = 1 + [int]$Modes[$Backend]
        if ($IsDense) { $Dense++ } elseif ($Backend -eq 'blit') { $Sparse++ }
        if ($Arm.material -eq 'full') { Assert-Result ($Backend -eq 'full') 'Control did not use full publication' }
    }
    Assert-Result ($Dense -eq 30 -and ($Arm.material -ne 'blit' -or $Sparse -gt 0)) 'Missing dense/sparse transfer coverage'
    foreach ($Phase in @('enter_dense','dense','enter_sparse','sparse')) {
        $Rows = @($Data.samples | Where-Object { $_.phase -eq $Phase })
        $Phases[$Phase] = @{ frame_ms=(Get-Distribution $Rows.frame_ms); publication_ms=(Get-Distribution $Rows.publication_ms)
            backend_submit_ms=(Get-Distribution @($Rows | ForEach-Object {
                $Value = Get-Field $_.material 'backend_submit_usec'
                if ($null -ne $Value) { [double]$Value/1000.0 }
            })) }
    }
    $Seconds = ($Data.samples.frame_ms | Measure-Object -Sum).Sum/1000.0
    return [ordered]@{ process_id=$Data.context.process_id; match=[ordered]@{
            engine=$Data.context.engine_sha256; driver=$Data.context.backend; display=$Data.context.display_server
            adapter=$Data.context.video_adapter; fixture=$Data.initial_plane_sha256; history=$Data.history }
        frame_ms=(Get-Distribution $Data.samples.frame_ms); publication_ms=(Get-Distribution $Data.samples.publication_ms)
        phases=$Phases; backend_modes=$Modes; publications_per_second=$Data.samples.Count/$Seconds; dense_inputs=$Dense
        setup_ms=$Data.setup_usec/1000.0; static_memory_peak_bytes=($Data.samples.godot_static_memory_peak_bytes | Measure-Object -Maximum).Maximum
        reported_video_memory_peak_bytes=($Data.samples.reported_video_memory_bytes | Measure-Object -Maximum).Maximum
        owned_staging_bytes=(Get-Distribution @($Data.samples | ForEach-Object { Get-Field $_.material 'allocated_gpu_bytes' }))
        screenshot_sha256=$Data.screenshot_sha256 }
}

function Read-Physical($Data, [string]$Folder, $Manifest, $Geometry, $Scenario, $Arm, [string]$Driver, [string]$Thread, [int]$Repeat, [string]$Nonce) {
    Assert-Result ($Data.schema -eq 'engine-lab-scripted-pose-test-it-v1' -and $Data.complete -eq $true -and $Data.status -eq 'passed') 'Physical receipt incomplete'
    $Workers = $Data.native_workers
    Assert-Result ($Data.source_sha -eq $Manifest.source_commit -and $Data.render_driver -eq $Driver -and
        $Data.display.server -ne 'headless' -and $Workers.case_nonce -eq $Nonce -and $Workers.engine_sha256 -eq $Manifest.engine.gui_sha256) 'Physical source, process, engine or renderer differs'
    Assert-Result ($Data.family -eq $Scenario.family -and $Data.camera -eq $Scenario.camera -and $Data.repeat -eq $Repeat -and
        $Data.pose_mode -eq 'guarded' -and $Data.presentation_mode -eq $Arm.presentation -and $Data.cadence_mode -eq 'repaired' -and
        $Data.material_publication.requested_mode -eq $Arm.material -and $Data.material_publication.backend -eq $Arm.material -and
        $Data.physics_publication -eq $Arm.physics -and $Workers.native_rendezvous.mode -eq 'off' -and
        $Workers.native_rendezvous.separate_render_thread -eq ($Thread -eq 'separate')) 'Physical treatment did not reach runtime'
    Assert-Result (($Data.world_size -join 'x') -eq ($Geometry.world -join 'x') -and $Data.reference.json_sha256 -eq $Geometry.recipe_sha256 -and
        $Data.reference.generated_material_sha256 -eq $Geometry.generated_sha256 -and
        $Data.reference.installed_generated_sha256 -eq $Geometry.generated_sha256 -and $Data.reference.native_receipts -eq $Geometry.generation_receipts -and
        $Data.input_tape.identity -eq $Geometry.tape -and $Data.input_tape.complete -eq $true -and $Data.input_tape.observed.Count -eq 11) 'Physical World or tick-addressed input tape differs'
    Assert-Result ($Data.display.profile -eq $Scenario.profile -and $Data.requested_rapier_callback_hz -eq 60 -and
        $Data.effective_pacing.pixel_hz -eq $Scenario.pixel_hz -and $Data.effective_pacing.ack_delay_frames -eq $Scenario.ack_delay -and
        $Data.effective_pacing.publication_hz -eq 60 -and $Data.effective_pacing.wait_native_sample -eq $true -and
        $Data.effective_pacing.sample_wake -eq $true -and $Data.effective_pacing.ack_gated_publication -eq $false -and
        [Math]::Abs($Data.fixed_physics_step_seconds-(1.0/60.0)) -lt 0.000000000001) 'Effective physical pacing differs'
    $Fire = @($Data.fire_schedule.events)
    Assert-Result ($Fire.Count -eq 2 -and $Fire[0].observed_step -eq 0 -and $Fire[0].enabled -eq $true -and
        $Fire[1].observed_step -eq 60 -and $Fire[1].enabled -eq $false) 'Tick-addressed Fire control missing'
    $Samples = @($Workers.completed_task_participation | Where-Object {
        $_.workers_observed -gt 0 -and $_.worker_capacity -eq $Workers.resolved_capacity -and $_.completed_tick -gt $Data.capture_native_tick_start
    })
    Assert-Result ($Workers.requested -eq $Scenario.workers -and $Workers.observed_request -eq $Scenario.workers -and
        $Workers.resolved_capacity -gt 0 -and $Samples.Count -gt 0 -and -not $Workers.participation_overflow) 'Actual completed native worker tasks were not recorded'
    Assert-Result ($Data.framebuffer_captures.Count -eq 2) 'Two original physical framebuffers required'
    foreach ($Capture in $Data.framebuffer_captures) {
        Assert-Result ($Capture.label -in @('before','after') -and
            (Get-Sha (Join-Path $Folder "receipt-$($Capture.label).png")) -eq $Capture.sha256) 'Physical screenshot differs'
    }
    $TracePath = Join-Path $Folder 'receipt-poses.jsonl'
    $Trace = @([IO.File]::ReadLines($TracePath) | ForEach-Object { ConvertFrom-Json -InputObject $_ })
    Assert-Result ($Trace.Count -gt 2 -and $Trace[0].type -eq 'header' -and $Trace[-1].type -eq 'summary' -and
        $Trace[-1].dropped -eq 0 -and $Trace[-1].events_dropped -eq 0 -and $Trace[-1].worker_events_dropped -eq 0) 'Physical trace incomplete or overflowed'
    $Frames = @($Trace | Where-Object { $_.type -eq 'frame' -and $_.time_usec -ge $Data.capture_start_usec -and $_.time_usec -le $Data.capture_end_usec } | Sort-Object time_usec)
    $Events = @($Trace | Where-Object { $_.type -eq 'event' -and $_.time_usec -ge $Data.capture_start_usec -and $_.time_usec -le $Data.capture_end_usec })
    $Main = @($Events | Where-Object { $_.event -eq 'main_callback' } | Sort-Object time_usec)
    $Steps = @($Events | Where-Object { $_.event -eq 'rapier_step' } | Sort-Object step)
    $Native = @($Events | Where-Object { $_.event -eq 'native_tick' } | Sort-Object tick_index)
    $Uploads = @($Events | Where-Object { $_.event -eq 'texture_upload' } | Sort-Object time_usec)
    $Pauses = @($Events | Where-Object { $_.event -eq 'rapier_hold' -and $_.reason -eq 'paused' } | Sort-Object time_usec)
    Assert-Result ($Frames.Count -gt 1 -and $Main.Count -gt 1 -and $Steps.Count -ge $Geometry.physical_step_target -and
        $Native.Count -gt 1 -and $Uploads.Count -gt 1 -and $Steps[0].step -eq 1) 'Missing completed native ticks, uploads, Main callbacks or Rapier steps'
    $Gaps = for ($Index = 1; $Index -lt $Steps.Count; $Index++) {
        $Prior = $Steps[$Index-1]
        $Current = $Steps[$Index]
        Assert-Result ($Current.step -eq $Prior.step+1 -and $Current.time_usec -ge $Prior.time_usec) 'Missing or out-of-order completed physical step'
        if (@($Pauses | Where-Object { $_.time_usec -gt $Prior.time_usec -and $_.time_usec -le $Current.time_usec }).Count -eq 0) {
            ($Current.time_usec-$Prior.time_usec)/1000.0
        }
    }
    Assert-Result ($Data.capture_wall_seconds -gt 0 -and $Data.rapier_steps -eq $Steps[-1].step) 'Incomplete physical close receipt'
    $MainIntervals = for ($Index = 1; $Index -lt $Main.Count; $Index++) { ($Main[$Index].time_usec-$Main[$Index-1].time_usec)/1000.0 }
    $FollowVisible = @($Frames | ForEach-Object { Get-Field $_ 'bodies' } | Where-Object { $_.visible -eq $true })
    $VisibleTime = @($FollowVisible | Where-Object { $null -ne $_.presentation_step })
    $Rewinds = @($VisibleTime | Where-Object { $_.presentation_source_rewind -eq $true }).Count
    Assert-Result ($Arm.presentation -ne 'coherent' -or ($VisibleTime.Count -gt 0 -and $Rewinds -eq 0)) 'Missing visible coherent physical steps or temporal rewind'
    $Holds = @($Events | Where-Object { $_.event -eq 'rapier_hold' } | Group-Object reason | ForEach-Object { @{ reason=$_.Name; count=$_.Count } })
    $UploadScope = [ordered]@{}
    foreach ($Stage in @('image_patch_usec','tile_assembly_usec','atlas_assembly_usec','backend_submit_usec','initialization_usec','allocated_gpu_bytes')) {
        $UploadScope[$Stage] = Get-Distribution @($Uploads | ForEach-Object { Get-Field $_.material_publication $Stage })
    }
    return [ordered]@{ process_id=$Workers.process_id; match=[ordered]@{
            engine=$Workers.engine_sha256; driver=$Data.render_driver; display=$Data.display; adapter=$Data.video_adapter
            fixture=$Data.reference.installed_generated_sha256; tape=$Data.input_tape.script; workers=$Workers.resolved_capacity }
        frame_ms=(Get-Distribution $MainIntervals); physical_gap_ms=(Get-Distribution $Gaps)
        timing_scopes=[ordered]@{ main_callback_wall_ms=(Get-Distribution @($Main | ForEach-Object { ($_.time_usec-$_.start_usec)/1000.0 }))
            native_tick_wall_ms=(Get-Distribution @($Native | ForEach-Object { ($_.completed_usec-$_.start_usec)/1000.0 }))
            rapier_step_wall_ms=(Get-Distribution @($Steps | ForEach-Object { ($_.time_usec-$_.start_usec)/1000.0 }))
            rapier_solver_wall_ms=(Get-Distribution @($Steps | ForEach-Object { $_.solver_usec/1000.0 }))
            rapier_flush_wall_ms=(Get-Distribution @($Steps | ForEach-Object { $_.flush_usec/1000.0 }))
            material_publication_wall_ms=(Get-Distribution @($Uploads | ForEach-Object { ($_.time_usec-$_.start_usec)/1000.0 }))
            material_detailed_usec_or_byte_counts=$UploadScope }
        material_snapshot_to_upload_ms=(Get-Distribution @($Uploads | Where-Object { $_.generated_usec -gt 0 } | ForEach-Object { ($_.time_usec-$_.generated_usec)/1000.0 }))
        frame_material_age_at_submission_ms=(Get-Distribution @($Frames | Where-Object { $_.render_snapshot_built_usec -gt 0 } | ForEach-Object { ($_.time_usec-$_.render_snapshot_built_usec)/1000.0 }))
        native_ticks_per_second=$Native.Count/$Data.capture_wall_seconds; rapier_steps_per_second=$Steps.Count/$Data.capture_wall_seconds
        publications_per_second=$Uploads.Count/$Data.capture_wall_seconds; physical_holds=$Holds; sample_count=$Samples.Count
        worker_observed=(Get-Distribution @($Samples.workers_observed)); visible_step_observations=$VisibleTime.Count; rewinds=$Rewinds
        static_memory_peak_bytes=$Workers.static_memory_peak_bytes; reported_video_memory_final_bytes=$Workers.reported_video_memory_bytes
        source_cold_preparation_seconds=$Data.elapsed_seconds-$Data.capture_wall_seconds; trace_sha256=(Get-Sha $TracePath) }
}

function Assert-Matched($Arms) {
    Assert-Result ($Arms.Count -eq 4 -and ($Arms.arm -join '') -ceq 'ABBA') 'Incomplete ordered A-B-B-A comparison'
    $ObservedProcesses = @($Arms | ForEach-Object { $_.statistics.process_id } | Select-Object -Unique)
    Assert-Result ($ObservedProcesses.Count -eq 4) 'Process reuse across comparison arms'
    $Reference = $Arms[0].statistics.match | ConvertTo-Json -Depth 20 -Compress
    foreach ($Row in $Arms[1..3]) {
        Assert-Result (($Row.statistics.match | ConvertTo-Json -Depth 20 -Compress) -ceq $Reference) 'Mismatched actual renderer, World, geometry, worker capacity or input tape'
    }
}
