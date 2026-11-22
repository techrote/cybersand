# Shared Read-Results.ps1 supplies JSON, hash, assertion and quantile helpers.
# No timing threshold is inferred from the observed results.
function Get-SourceGaps($Rows, [string]$Clock = 'time_usec') {
    for ($Index = 1; $Index -lt $Rows.Count; $Index++) {
        ([double](Get-Field $Rows[$Index] $Clock) - [double](Get-Field $Rows[$Index-1] $Clock))/1000.0
    }
}

function Get-SourceSum($Rows, [string]$Field) {
    $Total = 0L
    foreach ($Row in $Rows) { $Total += [long](Get-Field $Row $Field 0) }
    return $Total
}

function Assert-SourceWaterLedger($State, [string]$Label) {
    $Water = Get-Field $State 'water_ledger'
    Assert-Result ((Get-Field $State 'water_ledger_healthy' $false) -eq $true -and $null -ne $Water) "$Label native Water ledger is unavailable or unhealthy"
    Assert-Result ([long]$Water.total -eq [long]$Water.expected -and
        [long]$Water.visible+[long]$Water.overfill+[long]$Water.ballistic -eq [long]$Water.total) "$Label grid/ballistic Water does not match the native source/sink ledger"
}

function Get-SourceMaterialTreatment($Data, $Arm) {
    $Expected = [ordered]@{backend=(Get-Field $Arm 'backend' $Arm.material); policy=''}
    foreach ($Rule in @(Get-Field $Arm 'material_policy_overrides' @())) {
        Assert-Result ($Arm.reference -eq 'candidate') 'Only the current candidate may select its registered renderer policy'
        $AdapterMatches = $true
        foreach ($Part in $Rule.adapter_contains) {
            if (-not ([string]$Data.adapter).ToLowerInvariant().Contains([string]$Part)) { $AdapterMatches=$false }
        }
        if ((Get-Field $Data 'platform') -eq $Rule.platform -and $Data.renderer -eq $Rule.driver -and $AdapterMatches) {
            $Expected = [ordered]@{backend=$Rule.backend; policy=$Rule.policy}
        }
    }
    return $Expected
}

function Assert-SourceMaterialStatus($Status, $Arm, $Expected) {
    Assert-Result ($null -ne $Status -and $Status.requested_mode -eq $Arm.material -and
        $Status.backend -eq $Expected.backend -and (Get-Field $Status 'policy' '') -eq $Expected.policy -and
        (Get-Field $Status 'fallback_reason' '') -eq '') 'Material backend/policy differs from registered source and adapter treatment'
}

function Read-SourceWindow($Events, $Data, [long]$EndUsec) {
    $StartUsec = [long]$Data.capture_start_usec
    $Rows = @($Events | Where-Object { $_.time_usec -ge $StartUsec -and $_.time_usec -le $EndUsec })
    $Main = @($Rows | Where-Object { $_.event -eq 'main_callback' } | Sort-Object start_usec)
    $Draws = @($Rows | Where-Object { $_.event -eq 'framebuffer_draw' } | Sort-Object time_usec)
    $Steps = @($Rows | Where-Object { $_.event -eq 'rapier_step' } | Sort-Object step)
    $Native = @($Rows | Where-Object { $_.event -eq 'native_completion_observed' } | Sort-Object tick_index)
    $Uploads = @($Rows | Where-Object { $_.event -eq 'texture_upload' } | Sort-Object time_usec)
    $Worker = @($Rows | Where-Object { $_.event -eq 'worker_snapshot' } | Sort-Object time_usec)
    $Physics = @($Rows | Where-Object { $_.event -eq 'physics_callback' })
    $Seconds = ($EndUsec-$StartUsec)/1000000.0
    Assert-Result ($Seconds -gt 0 -and $Steps.Count -gt 1 -and $Main.Count -gt 1 -and $Native.Count -gt 1) 'Insufficient actual progression in registered window'
    $NativeByTick = @{}
    foreach ($Row in $Events | Where-Object { $_.event -eq 'native_completion_observed' }) {
        $NativeByTick[[string]$Row.tick_index] = $Row
    }
    # A duplicate status publication cannot reset time already spent waiting
    # for this exact completion/terrain. Accepted main lacks a mailbox clock;
    # its full-snapshot observation remains a separate queue lower bound.
    $FirstReady = @{}
    $FirstHandoff = @{}
    foreach ($Row in $Events | Where-Object { $_.event -eq 'worker_snapshot' -and -not $_.failed -and $_.hard_surface_revision -eq $_.required_hard_revision }) {
        $Key = '{0}/{1}/{2}/{3}' -f $Row.world_generation,$Row.tick_index,$Row.completed_body_sample,$Row.required_hard_revision
        if (-not $FirstReady.ContainsKey($Key) -or $Row.time_usec -lt $FirstReady[$Key]) { $FirstReady[$Key] = [long]$Row.time_usec }
        $Stamp = Get-Field $Row 'physics_handoff_usec' 0
        if ($null -ne $Stamp -and $Stamp -gt 0 -and (-not $FirstHandoff.ContainsKey($Key) -or $Stamp -lt $FirstHandoff[$Key])) { $FirstHandoff[$Key] = [long]$Stamp }
    }
    $FirstReadyAges = [Collections.Generic.List[double]]::new()
    $FirstHandoffAges = [Collections.Generic.List[double]]::new()
    $FirstNativeHandoff = [Collections.Generic.List[double]]::new()
    foreach ($Row in $Steps) {
        $Observed = $NativeByTick[[string]$Row.native_tick_used]
        if ($null -eq $Observed) { continue }
        $Key = '{0}/{1}/{2}/{3}' -f $Observed.world_generation,$Row.native_tick_used,$Row.completed_body_sample,$Row.required_hard_revision
        if ($FirstReady.ContainsKey($Key) -and $FirstReady[$Key] -le $Row.time_usec) { $FirstReadyAges.Add(($Row.time_usec-$FirstReady[$Key])/1000.0) }
        if ($FirstHandoff.ContainsKey($Key) -and $FirstHandoff[$Key] -le $Row.time_usec) {
            $FirstHandoffAges.Add(($Row.time_usec-$FirstHandoff[$Key])/1000.0)
            if ((Get-Field $Row 'native_completed_usec' 0) -gt 0) { $FirstNativeHandoff.Add(($FirstHandoff[$Key]-$Row.native_completed_usec)/1000.0) }
        }
    }
    $UniqueWorkerTicks = @{}
    $PublishedPackets = @{}
    foreach ($Row in $Worker) {
        $Key = [string]$Row.tick_index
        if (-not $UniqueWorkerTicks.ContainsKey($Key)) { $UniqueWorkerTicks[$Key] = $Row }
        $Key = [string]$Row.render_serial
        if (-not $PublishedPackets.ContainsKey($Key)) { $PublishedPackets[$Key] = $Row }
    }
    $TickRows = @($UniqueWorkerTicks.Values | Where-Object {
        $Observed = $NativeByTick[[string]$_.tick_index]
        $null -ne $Observed -and $Observed.time_usec -ge $StartUsec -and $Observed.time_usec -le $EndUsec
    } | Sort-Object tick_index)
    $ExactNative = @($TickRows | Where-Object { $null -ne $_.native_completed_usec -and $_.native_completed_usec -ge $StartUsec } | Sort-Object native_completed_usec)
    $SubmissionRows = @($Uploads | Where-Object { $null -ne (Get-Field $_ 'material') })
    $Modes = [ordered]@{}
    foreach ($Row in $SubmissionRows) {
        $Mode = [string](Get-Field $Row.material 'mode' (Get-Field $Row.material 'backend' 'unknown'))
        $Modes[$Mode] = 1 + [int]$Modes[$Mode]
    }
    $ObservedAge = @($Steps | ForEach-Object {
        $NativeRow = $NativeByTick[[string]$_.native_tick_used]
        if ($null -ne $NativeRow) { ($_.time_usec-$NativeRow.time_usec)/1000.0 }
    })
    $PostDraw = @($Uploads | ForEach-Object {
        $Upload = $_
        $Draw = $Draws | Where-Object { $_.time_usec -ge $Upload.time_usec -and $_.render_serial -ge $Upload.render_serial } | Select-Object -First 1
        if ($null -ne $Draw) { ($Draw.time_usec-$Upload.time_usec)/1000.0 }
    })
    $PairedFrameGaps = @(for ($Index = 2; $Index -lt $Main.Count; $Index++) {
        ($Main[$Index].start_usec-$Main[$Index-2].start_usec)/1000.0
    })
    $FrameGaps = @(Get-SourceGaps $Main 'start_usec')
    $TailGaps = @(for ($Index = 1; $Index -lt $Main.Count; $Index++) {
        [ordered]@{ from_process_frame=$Main[$Index-1].process_frame; to_process_frame=$Main[$Index].process_frame
            start_usec=$Main[$Index-1].start_usec; gap_ms=$FrameGaps[$Index-1] }
    })
    $Stages = [ordered]@{}
    foreach ($Stage in @('image_patch_usec','content_cache_usec','atlas_assembly_usec','backend_submit_usec','staging_upload_usec','gpu_blit_submit_usec','direct_upload_usec','whole_storage_create_usec','whole_storage_replace_usec','initialization_usec')) {
        $Stages[$Stage] = Get-Distribution @($SubmissionRows | ForEach-Object { Get-Field $_.material $Stage })
    }
    return [ordered]@{
        start_usec=$StartUsec; end_usec=$EndUsec; duration_seconds=$Seconds
        completed_native_ticks=$Native.Count; completed_rapier_steps=$Steps.Count
        completed_rapier_simulation_seconds=($Steps.fixed_delta | Measure-Object -Sum).Sum
        physical_simulation_seconds_per_wall_second=($Steps.fixed_delta | Measure-Object -Sum).Sum/$Seconds
        first_step=$Steps[0].step; last_step=$Steps[-1].step
        native_ticks_per_second=$Native.Count/$Seconds; rapier_steps_per_second=$Steps.Count/$Seconds
        frame_ms=(Get-Distribution $FrameGaps); consecutive_two_frame_ms=(Get-Distribution $PairedFrameGaps)
        # Tail rows are ordered dictionaries. PowerShell 5.1's named-property
        # sort does not reliably read their keys; select numeric keys explicitly.
        worst_frame_intervals=@($TailGaps | Sort-Object -Property `
            @{Expression={[double]($_['gap_ms'])}; Descending=$true}, `
            @{Expression={[long]($_['start_usec'])}; Descending=$false} | Select-Object -First 12)
        post_draw_callback_gap_ms=(Get-Distribution @(Get-SourceGaps $Draws))
        native_observed_gap_ms=(Get-Distribution @(Get-SourceGaps $Native))
        native_exact_gap_ms=(Get-Distribution @(Get-SourceGaps $ExactNative 'native_completed_usec'))
        physical_gap_ms=(Get-Distribution @(Get-SourceGaps $Steps))
        native_tick_ms=(Get-Distribution $TickRows.native_tick_ms)
        main_callback_ms=(Get-Distribution @($Main | ForEach-Object { ($_.time_usec-$_.start_usec)/1000.0 }))
        worker_publication_ms=(Get-Distribution @($Worker | ForEach-Object { ($_.time_usec-$_.start_usec)/1000.0 }))
        snapshot_copy_ms=(Get-Distribution $Worker.copy_ms)
        snapshot_publication_ms=(Get-Distribution $Worker.publication_ms)
        rapier_solver_ms=(Get-Distribution @($Steps | ForEach-Object { $_.solver_usec/1000.0 }))
        rapier_callback_to_completion_ms=(Get-Distribution @($Steps | ForEach-Object { ($_.time_usec-$_.start_usec)/1000.0 }))
        rapier_observer_ms=(Get-Distribution @($Steps | ForEach-Object { (Get-Field $_ 'observer_usec' 0)/1000.0 }))
        native_observed_to_rapier_ms=(Get-Distribution $ObservedAge)
        native_exact_to_rapier_ms=(Get-Distribution @($Steps | Where-Object { (Get-Field $_ 'native_completed_usec' 0) -gt 0 } | ForEach-Object { ($_.time_usec-$_.native_completed_usec)/1000.0 }))
        native_exact_to_physics_handoff_ms=(Get-Distribution @($Steps | Where-Object { (Get-Field $_ 'native_completed_usec' 0) -gt 0 -and (Get-Field $_ 'physics_handoff_usec' 0) -gt 0 } | ForEach-Object { ($_.physics_handoff_usec-$_.native_completed_usec)/1000.0 }))
        physics_handoff_to_rapier_ms=(Get-Distribution @($Steps | Where-Object { (Get-Field $_ 'physics_handoff_usec' 0) -gt 0 } | ForEach-Object { ($_.time_usec-$_.physics_handoff_usec)/1000.0 }))
        first_observed_eligible_snapshot_to_rapier_ms=(Get-Distribution @($FirstReadyAges))
        first_physics_handoff_to_rapier_ms=(Get-Distribution @($FirstHandoffAges))
        native_exact_to_first_physics_handoff_ms=(Get-Distribution @($FirstNativeHandoff))
        first_ready_scope='First healthy matching world/native-tick/body-sample/terrain packet. Observation clock is full snapshot hook exit (queue lower bound); exact physics handoff remains unavailable on accepted main. Latest handoff metrics above remain separately reported.'
        snapshot_generated_to_upload_ms=(Get-Distribution @($Uploads | Where-Object { $_.generated_usec -gt 0 } | ForEach-Object { ($_.time_usec-$_.generated_usec)/1000.0 }))
        material_age_at_main_end_ms=(Get-Distribution @($Main | Where-Object { (Get-Field $_ 'uploaded_generated_usec' 0) -gt 0 } | ForEach-Object { ($_.time_usec-$_.uploaded_generated_usec)/1000.0 }))
        material_submission_ms=(Get-Distribution @($Uploads | ForEach-Object { ($_.time_usec-$_.start_usec)/1000.0 }))
        upload_to_post_draw_callback_ms=(Get-Distribution $PostDraw)
        submission_stages_usec=$Stages
        publication=[ordered]@{
            accepted_uploads=$Uploads.Count; uploads_per_second=$Uploads.Count/$Seconds
            native_full_inputs=@($Uploads | Where-Object { $_.full_refresh }).Count
            native_sparse_inputs=@($Uploads | Where-Object { -not $_.full_refresh }).Count
            input_payload_bytes=(Get-SourceSum $Uploads 'patch_bytes'); input_patch_count=(Get-SourceSum $Uploads 'patch_count')
            unique_worker_render_serials=$PublishedPackets.Count
            submission_modes=$Modes
            cpu_staging_submitted_bytes=$(if ($SubmissionRows.Count -eq $Uploads.Count) { Get-SourceSum $SubmissionRows.material 'submitted_bytes' } else { $null })
            staging_residency_bytes=(Get-Distribution @($SubmissionRows | ForEach-Object { Get-Field $_.material 'allocated_gpu_bytes' }))
            dropped_publications=$null; expired_publications=$null; refused_publications=$null
            unavailable_reason='The common legacy seam cannot distinguish publication refusal/expiration from no-op consumption; original integrated diagnostics retain finer counters.'
            byte_scope='Input RG8 packet bytes and CPU staging upload bytes are distinct. Neither measures GPU bandwidth.'
        }
        physical_callbacks_without_step=@($Physics | Where-Object { $_.before_step -eq $_.after_step }).Count
        physical_callbacks_with_pending_terrain=@($Physics | Where-Object { $_.pending_hard_chunks -gt 0 }).Count
        response_refusals=@($Steps | Where-Object { $_.response_refusal -ne '' } | Group-Object response_refusal | ForEach-Object { @{reason=$_.Name; count=$_.Count} })
        contacts_observed=@($Steps | ForEach-Object { $_.bodies } | Where-Object { $_.contacts -gt 0 }).Count
    }
}

function Read-SourceGameplay($Data, [string]$Folder, $Manifest, $Source, $Scenario, $Arm, $Campaign, [string]$Driver, [string]$Thread, [string]$Nonce) {
    Assert-Result ($Data.schema -eq 'pubpres-source-gameplay-v1' -and $Data.complete -eq $true -and $Data.failures.Count -eq 0) 'Common gameplay receipt incomplete'
    Assert-Result ($Data.source_identity.source_sha -eq $Source.source_commit -and $Data.source_identity.engine_sha256 -eq $Manifest.engine.gui_sha256) 'Application source or pinned engine differs'
    Assert-Result ($Data.renderer -eq $Driver -and $Data.display.server -ne 'headless' -and $Data.case_nonce -eq $Nonce) 'Renderer, graphical surface or process nonce differs'
    Assert-Result ($Data.fixture.name -eq $Scenario.fixture -and $Data.camera -eq $Scenario.camera -and $Data.workers -eq $Scenario.workers -and $Data.water_law -eq $Scenario.water_law) 'Gameplay case changed'
    Assert-Result (($Data.display.window -join 'x') -eq '1600x900' -and $Data.display.fps_cap -eq 60 -and $Data.display.physics_callbacks_hz -eq 60 -and $Data.display.vsync_mode -eq 0) 'Registered capped display or disabled VSync condition differs'
    Assert-Result ($Data.gpu_history.current_matches_cpu -eq $true -and $Data.gpu_history.previous_verified -eq $false) 'Current GPU parity or declared history scope differs'
    foreach ($File in $Data.source_identity.files.PSObject.Properties) {
        Assert-Result ($File.Name.StartsWith('res://')) 'Unexpected runtime identity path'
        $Relative = $File.Name.Substring(6)
        $Expected = Get-Field $Campaign.overlay_sha256 $Relative
        if ($null -eq $Expected) { $Expected = Get-Field $Manifest.files_sha256 ($Source.project+'/'+$Relative) }
        Assert-Result ($File.Value -eq $Expected) "Source/runtime identity differs: $($File.Name)"
    }
    foreach ($Runtime in @('addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll','addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll')) {
        Assert-Result ((Get-Field $Data.source_identity.files ('res://'+$Runtime)) -match '^[0-9a-f]{64}$') "Missing loaded runtime identity: $Runtime"
    }
    $Fixture = Get-Field $Campaign.fixtures $Scenario.fixture
    foreach ($Name in @('setup_sha256','json_sha256','generated_sha256','receipts')) {
        $Expected = Get-Field $Fixture $Name
        if ($null -ne $Expected) { Assert-Result ((Get-Field $Data.fixture $Name) -eq $Expected) "Fixture $Name differs" }
    }
    Assert-Result ($Data.input_events.Count -eq 11 -and $Data.input_tape.Count -eq 11) 'Input tape is incomplete'
    for ($Index = 0; $Index -lt 11; $Index++) {
        $Input = $Data.input_events[$Index]
        Assert-Result ($Input.input_index -eq $Index -and $Input.requested_physical_tick -eq $Input.accepted_physical_tick -and
            $Input.requested_physical_tick -eq $Data.input_tape[$Index].tick -and ($Input.move -join ',') -eq ($Data.input_tape[$Index].move -join ',') -and
            $Input.requested_physical_tick -eq $Campaign.measurement.input_tape[$Index].tick -and
            ($Input.move -join ',') -eq ($Campaign.measurement.input_tape[$Index].move -join ',')) 'Input was not admitted at the registered real step'
    }
    $MaterialExpected = Get-SourceMaterialTreatment $Data $Arm
    foreach ($Selectors in @($Data.selectors_before,$Data.selectors_after)) {
        Assert-Result ($Selectors.requested.CYBERSAND_MATERIAL_PUBLICATION -eq $Arm.material -and
            $Selectors.requested.CYBERSAND_DIAG_PHYSICS_PUBLICATION -eq $Arm.physics -and
            $Selectors.requested.CYBERSAND_DIAG_PRESENTATION -eq $Arm.presentation -and
            $Selectors.requested.CYBERSAND_DIAG_MATERIAL_TIMING -eq $Arm.timing) 'Requested selectors changed'
        if ($Arm.reference -eq 'main') {
            Assert-Result ($null -eq $Selectors.material -and $null -eq $Selectors.physics -and $null -eq $Selectors.presentation) 'Accepted main acquired integrated diagnostic behavior'
        } else {
            Assert-SourceMaterialStatus $Selectors.material $Arm $MaterialExpected
            Assert-Result ($Selectors.physics -eq 'early' -and $Selectors.presentation -eq 'coherent' -and
                $Selectors.material_timing -ne 'legacy_requested' -and $null -ne $Selectors.material_timing -and
                $Selectors.cadence -eq 'repaired' -and $Selectors.rendezvous.mode -eq 'off' -and
                $Selectors.rendezvous.separate_render_thread -eq ($Thread -eq 'separate')) 'Requested integration treatment did not reach actual runtime'
        }
    }
    $TracePath = Join-Path $Folder 'receipt-events.jsonl'
    Assert-Result ((Get-Sha $TracePath) -eq $Data.trace_sha256) 'Original event trace changed'
    $Trace = @([IO.File]::ReadLines($TracePath) | ForEach-Object { ConvertFrom-Json -InputObject $_ })
    Assert-Result ($Trace.Count -gt 2 -and $Trace[0].event -eq 'identity') 'Missing trace identity'
    Assert-Result (($Trace[0].source | ConvertTo-Json -Depth 10 -Compress) -ceq ($Data.source_identity | ConvertTo-Json -Depth 10 -Compress)) 'Trace and receipt source identities differ'
    $Events = @($Trace | Where-Object { $_.event -ne 'identity' })
    foreach ($Upload in $Events | Where-Object { $_.event -eq 'texture_upload' }) {
        if ($Arm.reference -eq 'main') { Assert-Result ($null -eq $Upload.material) 'Accepted main acquired integrated material telemetry' }
        else { Assert-SourceMaterialStatus $Upload.material $Arm $MaterialExpected }
    }
    $Steps = @($Events | Where-Object { $_.event -eq 'rapier_step' } | Sort-Object step)
    $Native = @($Events | Where-Object { $_.event -eq 'native_completion_observed' } | Sort-Object tick_index)
    Assert-Result ($Steps.Count -ge 144 -and $Native.Count -gt 1 -and $Steps[0].step -eq $Data.capture_physical_tick_start+1) 'Missing real native/physical progress'
    Assert-Result (@($Steps | Where-Object { [Math]::Abs($_.fixed_delta-(1.0/60.0)) -gt 0.000000000001 }).Count -eq 0) 'Rapier fixed simulation timestep changed'
    for ($Index = 1; $Index -lt $Steps.Count; $Index++) {
        Assert-Result ($Steps[$Index].step -eq $Steps[$Index-1].step+1 -and $Steps[$Index].manual_steps -eq $Steps[$Index-1].manual_steps+1 -and
            $Steps[$Index].time_usec -ge $Steps[$Index-1].time_usec) 'Missing or reordered genuine Rapier completion'
    }
    for ($Index = 1; $Index -lt $Native.Count; $Index++) {
        Assert-Result ($Native[$Index].tick_index -eq $Native[$Index-1].tick_index+1 -and $Native[$Index].time_usec -ge $Native[$Index-1].time_usec) 'Missing or reordered native completion observation'
    }
    Assert-Result (@($Native.world_generation | Sort-Object -Unique).Count -eq 1 -and @($Steps | ForEach-Object { '{0}/{1}' -f $_.session,$_.epoch } | Sort-Object -Unique).Count -eq 1) 'World or physical owner changed during registered capture'
    $Participation = @($Events | Where-Object { $_.event -eq 'worker_participation' } | ForEach-Object { $_.sample })
    Assert-Result (@($Participation | Where-Object { $_.worker_capacity -gt 0 -and $_.workers_observed -gt 0 }).Count -gt 0) 'No actual completed native worker participation'
    Assert-Result (@($Participation | Where-Object { $_.worker_capacity -ne $Scenario.workers }).Count -eq 0) 'Native worker capacity did not equal the registered request'
    $Before = $Data.water_before
    $After = $Data.water_after
    Assert-SourceWaterLedger $Before 'Initial'
    Assert-SourceWaterLedger $After 'Final'
    $QuantityByTick = [Collections.Generic.List[object]]::new()
    $LastQuantityKey = ''
    foreach ($Sample in @($Events | Where-Object { $_.event -eq 'worker_snapshot' } | Sort-Object time_usec)) {
        Assert-SourceWaterLedger $Sample 'Published'
        $Quantity = [ordered]@{tick_index=$Sample.tick_index; completed_body_sample=$Sample.completed_body_sample; world_generation=$Sample.world_generation; water=$Sample.water_ledger}
        $Key = $Quantity | ConvertTo-Json -Compress
        if ($Key -cne $LastQuantityKey) { $QuantityByTick.Add($Quantity); $LastQuantityKey=$Key }
    }
    if ($Scenario.water_law -eq 'wave_flow_v1') {
        Assert-Result ($Before.wave_flow.enabled -and $After.wave_flow.enabled -and $After.wave_flow.healthy -and
            $After.wave_flow.session_generation -eq $Before.wave_flow.session_generation -and
            $After.wave_flow.ticks -gt $Before.wave_flow.ticks -and
            $After.wave_flow.rounds-$Before.wave_flow.rounds -eq ($After.wave_flow.ticks-$Before.wave_flow.ticks)*$After.wave_flow.substeps -and
            $Before.construction.receipt_hash -eq $After.construction.receipt_hash -and $After.policy.effective_water_solver -eq 'wave_flow_v1') 'Wave source, conservation, health or genuine rounds differ'
        if ($Scenario.fixture -eq 'landscape2048x1024') {
            Assert-Result ($Before.wave_flow.water_quantity -eq $After.wave_flow.water_quantity) 'Closed landscape Water quantity changed'
        }
    }
    Assert-Result ($Data.framebuffers.Count -eq 2) 'Original graphical evidence missing'
    foreach ($Capture in $Data.framebuffers) {
        Assert-Result ((Get-Sha (Join-Path $Folder ('receipt-'+$Capture.label+'.png'))) -eq $Capture.sha256 -and $Capture.outside_timing) 'Graphical readback identity or timing boundary differs'
    }
    $MinimumEnd = [long]$Data.capture_start_usec+10000000L
    Assert-Result ($Data.capture_end_usec -ge $MinimumEnd) 'Registered ten-second capture was shortened'
    return [ordered]@{
        process_id=$Data.process_id; source=$Source.source_commit; trace_sha256=$Data.trace_sha256
        match=[ordered]@{ engine=$Data.source_identity.engine_sha256; platform=(Get-Field $Data 'platform'); renderer=$Data.renderer; adapter=$Data.adapter; cpu=$Data.cpu
            logical_processors=$Data.logical_processors; display=$Data.display; fixture=$Data.fixture; tape=$Data.input_tape
            workers_requested=$Data.workers; worker_capacities=@($Participation.worker_capacity | Sort-Object -Unique)
            water_policy_hash=$Before.policy.policy_hash; wave_parameters=$(if ($Scenario.water_law -eq 'wave_flow_v1') {$Before.wave_flow.parameters} else {$null})
            initial_body_state_sha256=$Before.construction.initial_body_state_sha256
            prepared_payload_hash=$Before.construction.prepared_payload_hash; prepared_setup_hash=$Before.construction.prepared_setup_hash }
        windows=[ordered]@{ first_10s=(Read-SourceWindow $Events $Data $MinimumEnd)
            first_144_steps=(Read-SourceWindow $Events $Data ([long]$Steps[143].time_usec))
            whole_capture=(Read-SourceWindow $Events $Data ([long]$Data.capture_end_usec)) }
        actual_worker_participation=$Participation
        memory=[ordered]@{ godot_static_peak_bytes=$Data.static_memory_peak_bytes; reported_video_final_bytes=$Data.video_memory_bytes }
        water_quantity_before=(Get-Field $Before.wave_flow 'water_quantity'); water_quantity_after=(Get-Field $After.wave_flow 'water_quantity')
        water_ledger_before=$Before.water_ledger; water_ledger_after=$After.water_ledger
        water_by_native_tick=$QuantityByTick.ToArray()
        selectors_before=$Data.selectors_before; selectors_after=$Data.selectors_after; gpu_history=$Data.gpu_history
        registered_material_treatment=$MaterialExpected
        observation_limits=$Campaign.measurement.limits
    }
}

function Assert-SourceMatched($Arms) {
    Assert-Result ($Arms.Count -eq 6 -and ($Arms.arm -join '') -ceq 'MICCIM') 'Incomplete M-I-C-C-I-M comparison'
    $Reference = $Arms[0].statistics.match | ConvertTo-Json -Depth 30 -Compress
    foreach ($Row in $Arms) {
        Assert-Result (($Row.statistics.match | ConvertTo-Json -Depth 30 -Compress) -ceq $Reference) 'Source comparison has unmatched hardware, fixture, display, policy or workload'
    }
    Assert-Result (@($Arms.nonce | Select-Object -Unique).Count -eq 6) 'Source arm nonce reused'
}
