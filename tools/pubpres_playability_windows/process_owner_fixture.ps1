[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('leaf','zero-exit','wait')][string]$Mode,
    [Parameter(Mandatory=$true)][string]$LeafReceipt,
    [string]$CancelSignal = ''
)

# Harmless, finite actual-Windows negative control. It only starts this same
# fixture, writes its own PID/start-time receipt and waits. No network, World,
# renderer, native simulation or user profile is touched.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Utf8 = [Text.UTF8Encoding]::new($false)
if ($Mode -ceq 'leaf') {
    $Self = [Diagnostics.Process]::GetCurrentProcess()
    $Record = [ordered]@{schema='pubpres-owned-leaf-fixture-v1';process_id=$Self.Id;
        start_time_utc_ticks=$Self.StartTime.ToUniversalTime().Ticks;fixture_sha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()}
    # The parent may exit immediately after seeing readiness. Publish the
    # complete receipt by rename so Job teardown cannot interrupt its write.
    [IO.File]::WriteAllText(($LeafReceipt+'.pending'),($Record | ConvertTo-Json)+"`n",$Utf8)
    [IO.File]::Move(($LeafReceipt+'.pending'),$LeafReceipt)
    [Console]::WriteLine('PUBPRES_OWNED_LEAF_READY '+$Self.Id)
    [Threading.Thread]::Sleep(60000)
    exit 0
}
$Engine = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$Info = [Diagnostics.ProcessStartInfo]::new()
$Info.FileName=$Engine; $Info.UseShellExecute=$false; $Info.CreateNoWindow=$true
foreach ($Value in @($PSCommandPath,$LeafReceipt)) { if ($Value.Contains('"') -or $Value -match '[\r\n\x00]') { throw 'Invalid fixture argument' } }
$Info.Arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Mode leaf -LeafReceipt "'+$LeafReceipt+'"'
$Leaf = [Diagnostics.Process]::Start($Info)
try {
    $Clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $LeafReceipt -PathType Leaf)) {
        if ($Leaf.HasExited -or $Clock.Elapsed.TotalSeconds -gt 15) { throw 'Fixture leaf did not become ready' }
        [Threading.Thread]::Sleep(20)
    }
    if ($CancelSignal) { [IO.File]::WriteAllText($CancelSignal,'request owned cancellation',$Utf8) }
    if ($Mode -ceq 'zero-exit') {
        [Console]::WriteLine('PUBPRES_ROOT_EXIT_ZERO_WITH_LIVE_LEAF '+$Leaf.Id)
        # Deliberately do not terminate the leaf. Job ownership must catch it.
        exit 0
    }
    [Console]::WriteLine('PUBPRES_ROOT_WAITING_WITH_LIVE_LEAF '+$Leaf.Id)
    [Threading.Thread]::Sleep(60000)
} finally { $Leaf.Dispose() }
