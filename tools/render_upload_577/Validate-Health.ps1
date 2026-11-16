# Shared by installed Test It and source-bound negative controls. Windows PS5.1.
# Do not trust ok:true, a healthy final summary, or a positive final tick alone.
function Test-HealthInteger($Value) {
    return ($Value -is [int] -or $Value -is [long])
}
function Test-HealthEmptyObject($Value) {
    return ($null -ne $Value -and $Value -is [pscustomobject] -and @($Value.PSObject.Properties).Count -eq 0)
}
function Assert-RenderUploadRequestedCase($Data, $Expected, [string]$Strategy) {
    foreach ($key in @('size','workload','workers','family','channels','ack','fixture')) {
        if ($key -cin @('size','workers','channels')) {
            if (-not (Test-HealthInteger $Data.config.$key)) { throw ('Capture lacks the requested numeric '+$key+'.') }
        } elseif ($Data.config.$key -isnot [string]) { throw ('Capture lacks the requested text '+$key+'.') }
        if ($Data.config.$key -cne $Expected[$key]) { throw ('Capture differs from requested '+$key+'.') }
    }
    if ($Data.config.strategy -isnot [string] -or $Data.strategy -isnot [string] -or $Data.workload -isnot [string] -or
        $Data.config.strategy -cne $Strategy -or $Data.strategy -cne $Strategy -or
        $Data.workload -cne $Expected['workload']) {
        throw 'Capture top-level workload/strategy differs from the requested case.'
    }
}
function Assert-RenderUploadHealth($Data) {
    $workload = $Data.workload
    $syntheticWorkloads = @('sparse','regions','dense','full','repeated','coverage','transition')
    $nativeWorkloads = @('manual','burst','active','dormant','actor')
    if ($workload -isnot [string] -or ($workload -cnotin $syntheticWorkloads -and $workload -cnotin $nativeWorkloads)) {
        throw 'Native health lacks a known workload identity.'
    }
    $expectedCohort = if ($workload -cin $syntheticWorkloads) {'deterministic_renderer_seam'} else {'mounted_native_workbench'}
    if ($Data.cohort -isnot [string] -or $Data.cohort -cne $expectedCohort) { throw 'Native health cohort differs from the workload.' }
    $health = $Data.native_health
    $frames = @($Data.frames)
    if ($health.schema -isnot [string] -or $health.schema -cne 'render-upload-577-native-health-v1' -or $frames.Count -eq 0) {
        throw 'Missing original native health observations.'
    }
    if (-not (Test-HealthEmptyObject $health.first_failure) -or
        -not (Test-HealthInteger $health.failure_observations) -or $health.failure_observations -ne 0) {
        throw 'Native health retained a failed or stopped owner.'
    }
    if ($Data.cohort -ceq 'deterministic_renderer_seam') {
        if ($health.applicable -isnot [bool] -or $health.applicable) { throw 'Synthetic native health applicability differs.' }
        foreach ($key in @('before','after_timing','final')) {
            if (-not (Test-HealthEmptyObject $health.$key)) { throw 'Synthetic cohort cannot claim native owner health.' }
        }
        foreach ($frame in $frames) {
            if (-not (Test-HealthEmptyObject $frame.native_health)) { throw 'Synthetic cohort contains native health observations.' }
        }
        return
    }
    if ($Data.cohort -cne 'mounted_native_workbench' -or $health.applicable -isnot [bool] -or -not $health.applicable) {
        throw 'Native health applicability differs from the cohort.'
    }
    $observations = @(@{stage='before';frame=-1;row=$health.before})
    for ($i=0; $i -lt $frames.Count; $i++) { $observations += @{stage='frame';frame=$i;row=$frames[$i].native_health} }
    $observations += @{stage='after_timing';frame=-1;row=$health.after_timing}
    $observations += @{stage='final_after_worker_join';frame=-1;row=$health.final}
    $running = $false
    $playRequested = $false
    [long]$observedUsec = -1
    $integerFields = @('snapshot_serial','published_usec','tick_index','simulation_world_revision','world_revision',
        'render_world_generation','render_snapshot_serial','render_tick_index','failed_tick_index','tick_failure_count')
    foreach ($observation in $observations) {
        $row = $observation.row
        if ($null -eq $row -or $row.stage -isnot [string] -or $row.stage -cne $observation.stage -or
            -not (Test-HealthInteger $row.frame) -or $row.frame -ne $observation.frame) {
            throw 'Native health observation is missing or associated with another frame.'
        }
        if (-not (Test-HealthInteger $row.observed_usec) -or $row.observed_usec -lt $observedUsec -or
            $row.healthy -isnot [bool] -or -not $row.healthy -or @($row.reasons).Count -ne 0 -or
            $row.worker_has_failed -isnot [bool] -or $row.worker_has_failed) {
            throw 'Native health observation records failure or invalid order.'
        }
        $observedUsec = $row.observed_usec
        foreach ($key in @('expect_running','worker_running_observed_before','worker_running_observed','main_paused')) {
            if ($row.$key -isnot [bool]) { throw 'Native health lacks explicit owner/play state.' }
        }
        if ($row.workbench_refusal -isnot [string] -or $row.workbench_refusal -cne '' -or
            $row.main_error -isnot [string] -or $row.main_error -cne '' -or $row.workbench_message -isnot [string]) {
            throw 'Native health lacks original Workbench status or records refusal.'
        }
        foreach ($key in @('worker_snapshot','main_snapshot')) {
            $snapshot = $row.$key
            if ($null -eq $snapshot -or $snapshot.available -isnot [bool] -or -not $snapshot.available -or
                $snapshot.backend_name -isnot [string] -or $snapshot.backend_name -cne 'native-phased' -or $snapshot.paused -isnot [bool] -or
                $snapshot.simulation_failed -isnot [bool] -or $snapshot.simulation_failed -or
                $snapshot.failed_tick_index -ne 0 -or $snapshot.tick_failure_count -ne 0 -or
                $snapshot.last_tick_error -isnot [string] -or $snapshot.last_tick_error -cne '' -or
                $snapshot.workbench_refusal -isnot [string] -or $snapshot.workbench_refusal -cne '') {
                throw ('Original '+$key+' is missing, failed, or refused.')
            }
            foreach ($field in $integerFields) {
                if (-not (Test-HealthInteger $snapshot.$field) -or $snapshot.$field -lt 0) {
                    throw ('Original '+$key+' lacks its native identity.')
                }
            }
        }
        if ($row.worker_running_observed_before -ne $running) { throw 'Native running-state history was lost.' }
        $owner = $row.worker_owner_state
        if ($owner.thread_running -isnot [bool] -or $owner.requested_paused -isnot [bool]) {
            throw 'Native requested owner state is missing.'
        }
        if ($observation.stage -cne 'final_after_worker_join' -and -not $owner.thread_running) {
            throw 'Native worker thread stopped during timing.'
        }
        if ($observation.stage -ceq 'final_after_worker_join' -and $owner.thread_running) {
            throw 'Final native health was not observed after worker join.'
        }
        if ($row.expect_running -and ($row.main_paused -or ($running -and $owner.requested_paused))) {
            throw 'Native owner stopped after Play was requested.'
        }
        $running = $running -or ($owner.thread_running -and -not $owner.requested_paused)
        if ($row.worker_running_observed -ne $running) { throw 'Native running-state observation disagrees with its source.' }
        if ($playRequested -and -not $row.expect_running) { throw 'Native Play request was silently withdrawn.' }
        $playRequested = $row.expect_running
        if ($Data.workload -cin @('active','dormant','actor') -and -not $playRequested) {
            throw 'Active workload did not request continued native play.'
        }
        if ($Data.workload -ceq 'manual' -and $playRequested) { throw 'Paused manual workload unexpectedly requested play.' }
    }
    if ($Data.workload -cin @('active','dormant','actor') -and
        (-not $running -or $frames[-1].tick -le $Data.initial_native_tick)) {
        throw 'Active workload did not observe native progress.'
    }
    if ($Data.workload -ceq 'actor') {
        if (-not (Test-HealthInteger $Data.initial_rapier_step)) { throw 'Actor lacks its initial completed-step identity.' }
        $previous = $Data.initial_rapier_step
        foreach ($frame in $frames) {
            if (-not (Test-HealthInteger $frame.rapier_step) -or $frame.rapier_step -lt $previous) {
                throw 'Actor completed-step observations are absent or regress.'
            }
            $previous = $frame.rapier_step
        }
        if ($previous -le $Data.initial_rapier_step) { throw 'Actor did not complete a physical step during timing.' }
    }
}
