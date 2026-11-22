[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Output)

# Cheap actual-Windows prerequisite, also invoked by Test-Package.ps1. No
# Godot/native build is needed; this is process lifecycle evidence only.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Start-PUBPRES-Playability.ps1') -Library
$Output=[IO.Path]::GetFullPath($Output)
Assert-PP (-not (Test-Path -LiteralPath $Output)) 'Process-owner output must be new'
[IO.Directory]::CreateDirectory($Output) | Out-Null
$Engine=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$Fixture=Join-Path $PSScriptRoot 'process_owner_fixture.ps1'
$Checks=[Collections.Generic.List[object]]::new()
$JsonArrayChecks=[Collections.Generic.List[object]]::new()
$Failures=[Collections.Generic.List[string]]::new()
$RetainedLeaves=[Collections.Generic.List[object]]::new()

function Test-PPLeafGone($Leaf) {
    try { $Process=[Diagnostics.Process]::GetProcessById([int]$Leaf.process_id) }
    catch [ArgumentException] { return $true }
    try {
        if ($Process.StartTime.ToUniversalTime().Ticks -ne [long]$Leaf.start_time_utc_ticks) { return $true }
        return $Process.WaitForExit(5000)
    } finally { $Process.Dispose() }
}
function Assert-PPMemoryEvidence([string]$Folder,$ProcessReceipt) {
    $Text=[IO.File]::ReadAllText((Join-Path $Folder 'process-memory.json'))
    # Keep the parsed array inside an object so the test's own PowerShell
    # output pipeline cannot hide a singleton/empty serialization defect.
    $Wrapped=ConvertFrom-Json -InputObject ('{"samples":'+$Text+'}')
    Assert-PP ($Wrapped.samples -is [Array] -and $Wrapped.samples.Length -eq $ProcessReceipt.samples) 'Actual process memory evidence is not an array with its reported sample count'
}
try {
    $JsonFolder=Join-Path $Output 'json-array-writer'
    [IO.Directory]::CreateDirectory($JsonFolder) | Out-Null
    foreach ($Count in @(0,1,2)) {
        $Values=[Collections.Generic.List[object]]::new()
        for ($Index=0; $Index -lt $Count; $Index++) { $Values.Add([ordered]@{sample_index=$Index;working_set_bytes=4096+$Index}) }
        $Path=Join-Path $JsonFolder ($Count.ToString()+'.json')
        Write-PPJson $Path ($Values.ToArray())
        $Text=[IO.File]::ReadAllText($Path)
        $Wrapped=ConvertFrom-Json -InputObject ('{"samples":'+$Text+'}')
        $Pass=$Wrapped.samples -is [Array] -and $Wrapped.samples.Length -eq $Count
        for ($Index=0; $Pass -and $Index -lt $Count; $Index++) {
            $Pass=$Wrapped.samples[$Index].sample_index -eq $Index -and $Wrapped.samples[$Index].working_set_bytes -eq (4096+$Index)
        }
        $JsonArrayChecks.Add([ordered]@{expected_samples=$Count;passed=$Pass;path=('json-array-writer/'+$Count+'.json');sha256=(Get-PPHash $Path)})
        Assert-PP $Pass ('JSON writer changed the array type, count or values for '+$Count+' samples')
    }
    $CleanFolder=Join-Path $Output 'clean-zero-exit'
    $Clean=Invoke-PPProcess -Engine $Engine -Arguments @('-NoProfile','-NonInteractive','-Command','exit 0') `
        -Folder (Join-Path $CleanFolder 'process') -Profile (Join-Path $CleanFolder 'profile') -Settings @{} -SourceSha ('0'*40) -TimeoutSeconds 30
    $CleanOwner=Read-PPJson (Join-Path $CleanFolder 'process/process-owner.json')
    Assert-PPMemoryEvidence (Join-Path $CleanFolder 'process') $Clean
    $CleanPass=$Clean.exit_code -eq 0 -and $Clean.termination_reason -ceq 'completed' -and
        $CleanOwner.assigned_before_resume -eq $true -and $CleanOwner.initial_thread_resumed -eq $true -and
        $CleanOwner.parent_exited_before_cleanup -eq $true -and $CleanOwner.active_before_cleanup -eq 0 -and
        $CleanOwner.active_after_cleanup -eq 0 -and $CleanOwner.cleanup_established -eq $true -and $CleanOwner.had_survivors -eq $false
    $Checks.Add([ordered]@{case='clean-zero-exit';passed=$CleanPass;ownership=$CleanOwner})
    Assert-PP $CleanPass 'A clean successful child must be admitted without false orphan accounting'
    foreach ($Case in @('zero-exit','timeout','cancel')) {
        $Folder=Join-Path $Output $Case
        [IO.Directory]::CreateDirectory($Folder) | Out-Null
        $LeafPath=Join-Path $Folder 'leaf.json'; $SignalPath=Join-Path $Folder 'cancel.signal'
        $Arguments=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$Fixture,
            '-Mode',$(if($Case -ceq 'zero-exit'){'zero-exit'}else{'wait'}),'-LeafReceipt',$LeafPath)
        if ($Case -ceq 'cancel') { $Arguments+=@('-CancelSignal',$SignalPath) }
        $Rejected=$false; $Reason=''
        try {
            Invoke-PPProcess -Engine $Engine -Arguments $Arguments -Folder (Join-Path $Folder 'process') -Profile (Join-Path $Folder 'profile') `
                -Settings @{} -SourceSha ('0'*40) -TimeoutSeconds $(if($Case -ceq 'timeout'){8}else{30}) `
                -CancellationSignalPath $(if($Case -ceq 'cancel'){$SignalPath}else{''}) | Out-Null
        } catch { $Rejected=$true; $Reason=$_.Exception.Message }
        $ProcessReceipt=Read-PPJson (Join-Path $Folder 'process/process.json')
        $Owner=Read-PPJson (Join-Path $Folder 'process/process-owner.json')
        Assert-PP (Test-Path -LiteralPath $LeafPath -PathType Leaf) ($Case+': actual child did not run; negative control is invalid')
        $Leaf=Read-PPJson $LeafPath; $RetainedLeaves.Add($Leaf)
        Assert-PPMemoryEvidence (Join-Path $Folder 'process') $ProcessReceipt
        $Gone=Test-PPLeafGone $Leaf
        $Pass=$Rejected -and $Gone -and $Owner.assigned_before_resume -eq $true -and $Owner.initial_thread_resumed -eq $true -and $Owner.creation_time_job_list -eq $true -and
            $Owner.standard_handle_allowlist -eq $true -and $Owner.cleanup_established -eq $true -and $Owner.active_after_cleanup -eq 0
        if ($Case -ceq 'zero-exit') {
            $Pass=$Pass -and $Owner.root_exit_code -eq 0 -and $Owner.zero_exit_with_descendants -eq $true -and
                $Owner.parent_exited_before_cleanup -eq $true -and $Owner.active_before_cleanup -gt 0 -and $Reason -match 'left owned descendants'
        } elseif ($Case -ceq 'timeout') {
            $Pass=$Pass -and $ProcessReceipt.timed_out -eq $true -and $Owner.had_survivors -eq $true -and $Reason -match 'Application failed'
        } else {
            $Pass=$Pass -and $ProcessReceipt.cancelled -eq $true -and $Owner.cancellation_requested -eq $true -and $Reason -match 'Application cancelled'
        }
        $Checks.Add([ordered]@{case=$Case;passed=$Pass;refused=$Rejected;reason=$Reason;leaf=$Leaf;leaf_exited=$Gone;ownership=$Owner})
        if (-not $Pass) { $Failures.Add($Case+': lifecycle contract did not hold') }
    }
} catch { $Failures.Add($_.Exception.Message) }
finally {
    # If the implementation under test is broken, retire only the exact
    # fixture PID/start-time pair, and retain the failure. Never count this
    # emergency test cleanup as successful Job ownership.
    foreach ($Leaf in $RetainedLeaves) {
        try {
            $Process=[Diagnostics.Process]::GetProcessById([int]$Leaf.process_id)
            try {
                if ($Process.StartTime.ToUniversalTime().Ticks -eq [long]$Leaf.start_time_utc_ticks -and -not $Process.HasExited) {
                    $Process.Kill(); $Process.WaitForExit(5000) | Out-Null
                    $Failures.Add('Emergency fixture cleanup was required')
                }
            } finally { $Process.Dispose() }
        } catch [ArgumentException] { }
    }
    Write-PPJson (Join-Path $Output 'process-owner-tests.json') ([ordered]@{schema='pubpres-windows-process-owner-tests-v1';
        checks=$Checks.ToArray();json_array_writer=$JsonArrayChecks.ToArray();failures=$Failures.ToArray();platform=[Environment]::OSVersion.ToString();powershell=$PSVersionTable.PSVersion.ToString();
        helper_sha256=(Get-PPHash (Join-Path $PSScriptRoot 'process_owner.cs'));fixture_sha256=(Get-PPHash $Fixture);physical_acceptance='HOLD';
        scope='Actual Windows creation-time Job ownership, natural zero-exit orphan refusal, timeout and explicit cancellation through the same native owner cancellation path. No renderer/native progression claim; physical console Ctrl+C remains a separate owner exercise.'})
}
Assert-PP ($Failures.Count -eq 0 -and $Checks.Count -eq 4 -and $JsonArrayChecks.Count -eq 3) ('Windows process ownership/evidence failed: '+($Failures -join '; '))
Write-Host 'Passed four actual-Windows Job lifecycle controls; physical acceptance remains HOLD.'
