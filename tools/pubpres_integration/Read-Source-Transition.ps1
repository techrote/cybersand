# Shared assertions come from Read-Results and Read-Source-Results. This lane
# runs real source renderers, with an identical test-only transition overlay.
function Get-SourceTransitionTreatment($Context, $Arm) {
    $Observed = @{platform=$Context.platform; renderer=$Context.backend; adapter=$Context.video_adapter}
    $Expected = Get-SourceMaterialTreatment $Observed $Arm
    return [ordered]@{requested=$Arm.material; backend=$Expected.backend; policy=$Expected.policy}
}

function Assert-SourceTransitionIdentity($Data, $Manifest, $Source, $Campaign, [string]$Script, [string]$Driver, [string]$Nonce) {
    $Context = $Data.context
    Assert-Result ($Context.source_revision -eq $Source.source_commit -and $Context.platform -eq 'Windows' -and
        $Context.backend -eq $Driver -and $Context.display_server -ne 'headless' -and $Context.nonce -eq $Nonce -and
        $Context.engine_sha256 -eq $Manifest.engine.gui_sha256 -and $Context.fixture -eq ('res://'+$Script) -and
        $Context.fixture_sha256 -eq (Get-Field $Campaign.transition_overlay_sha256 $Script) -and
        $Data.application_main_sha256 -eq (Get-Field $Manifest.files_sha256 ($Source.project+'/scripts/main.gd'))) 'Transition source, engine, fixture or actual Main bytes differ'
    Assert-Result ($Data.initial_plane_sha256 -eq $Campaign.transition_case.initial_plane_sha256 -and
        $Data.tape -eq 'transition' -and $Data.failures.Count -eq 0) 'Transition input or runtime correctness differs'
    foreach ($Key in @('current_sha256','previous_sha256')) {
        Assert-Result ((Get-Field $Data.history $Key) -eq (Get-Field $Campaign.transition_case.history $Key)) 'Final complete history differs from the registered byte sequence'
    }
}

function Read-SourceTransition($Data, [string]$Folder, $Manifest, $Source, $Arm, $Campaign, [string]$Driver, [string]$Nonce) {
    Assert-SourceTransitionIdentity $Data $Manifest $Source $Campaign 'tests/pubpres_transition.gd' $Driver $Nonce
    $Treatment = Get-SourceTransitionTreatment $Data.context $Arm
    $Identity = @{source_commit=$Source.source_commit; engine=$Manifest.engine}
    $Stats = Read-Transition $Data $Folder $Identity $Arm $Driver $Nonce $Treatment
    $PreviousPostDraw = $null
    foreach ($Row in $Data.samples) {
        Assert-Result (-not [double]::IsNaN([double]$Row.frame_ms) -and -not [double]::IsInfinity([double]$Row.frame_ms) -and
            [double]$Row.frame_ms -gt 0 -and -not [double]::IsNaN([double]$Row.publication_ms) -and
            -not [double]::IsInfinity([double]$Row.publication_ms) -and [double]$Row.publication_ms -ge 0) 'Non-finite or invalid transition timing'
        Assert-Result ($Row.post_draw_usec -ge $Row.publish_end_usec -and $Row.publish_end_usec -ge $Row.publish_begin_usec) 'Invalid submission-to-post-draw timeline'
        Assert-Result ([Math]::Abs([double]$Row.publication_ms-($Row.publish_end_usec-$Row.publish_begin_usec)/1000.0) -lt 0.000001) 'Publication duration differs from its actual timestamps'
        if ($null -ne $PreviousPostDraw) {
            Assert-Result ($Row.publish_begin_usec -ge $PreviousPostDraw -and
                [Math]::Abs([double]$Row.frame_ms-($Row.post_draw_usec-$PreviousPostDraw)/1000.0) -lt 0.000001) 'Frame interval differs from consecutive post-draw timestamps'
        }
        $PreviousPostDraw = $Row.post_draw_usec
    }
    $Stats['kind'] = 'transition'
    $Stats['submission_to_post_draw_ms'] = Get-Distribution @($Data.samples | ForEach-Object { ($_.post_draw_usec-$_.publish_end_usec)/1000.0 })
    $Stats['submitted_bytes'] = ($Data.samples | ForEach-Object { Get-Field $_.material 'submitted_bytes' } | Measure-Object -Sum).Sum
    $Stats['history_copy_count'] = @($Data.samples | Where-Object { Get-Field $_.material 'history_copy' $false }).Count
    $Stats['whole_upload_count'] = @($Data.samples | Where-Object { $_.material.backend -eq 'full' -or (Get-Field $_.material 'direct_whole' $false) }).Count
    $Stats['scope'] = 'Actual production renderer and detached Main seam. No native or Rapier owner in this lane. Post-draw is callback delivery, not GPU completion or scanout.'
    return $Stats
}

function Read-SourceTransitionOracle($Data, $Manifest, $Source, $Arm, $Campaign, [string]$Driver, [string]$Nonce) {
    Assert-SourceTransitionIdentity $Data $Manifest $Source $Campaign 'tests/pubpres_source_transition_oracle.gd' $Driver $Nonce
    Assert-Result ($Data.schema -eq 'pubpres-source-transition-history-v1' -and $Data.complete -and
        $Data.frames_checked -eq 180 -and $Data.current_matches -eq 180 -and $Data.previous_matches -eq 180 -and
        $Data.sparse_entries -eq 15 -and $Data.admissions.Count -eq 180 -and $Data.entry_history.Count -eq 15) 'Independent per-revision history readback did not complete'
    $Treatment = Get-SourceTransitionTreatment $Data.context $Arm
    for ($Index=0; $Index -lt 180; $Index++) {
        $Row = $Data.admissions[$Index]
        Assert-Result ($Row.sequence -eq $Index+30 -and $Row.revision -eq $Index+31 -and $Row.current_matches -and $Row.previous_matches) 'Oracle admission or exact history differs'
        Assert-MaterialTreatment $Row.material $Treatment
    }
    foreach ($Key in @('current_sha256','previous_sha256')) {
        Assert-Result ((Get-Field $Data.warmup_history $Key) -eq (Get-Field $Campaign.transition_case.warmup_history $Key)) 'Oracle warm-up history differs'
    }
    return [ordered]@{process_id=$Data.context.process_id; context=$Data.context; material_treatment=$Treatment
        current_matches=$Data.current_matches; previous_matches=$Data.previous_matches
        history=$Data.history; warmup_history=$Data.warmup_history; entry_history=$Data.entry_history}
}
