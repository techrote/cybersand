[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InputRoot,
    [Parameter(Mandatory=$true)][string]$OutputRoot,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSource,
    [ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedCampaignSha256 = '9f63b56caa455428718705cdd80fe20b9976c29b459b703a8b3ed9233204fc20',
    [ValidatePattern('^[0-9a-f]{64}$')][string]$ExpectedOriginalReaderSha256 = '1e3c3a60f54306182c5cacef69e381c027bc0bdd244ad410566fd2ec77792b1e'
)

# Windows PowerShell 5.1, standard library only. Replays retained observations;
# it never launches Godot, alters a timing window or writes original evidence.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($Name in @('Microsoft.PowerShell.Management','Microsoft.PowerShell.Utility')) {
    Import-Module -Name (Join-Path $PSHOME "Modules\$Name\$Name.psd1") -Force
}
. (Join-Path $PSScriptRoot 'Read-Results.ps1')
. (Join-Path $PSScriptRoot 'Read-Source-Results.ps1')

Assert-Result ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1) 'This replay gate must run on Windows PowerShell 5.1'
$InputRoot = [IO.Path]::GetFullPath($InputRoot).TrimEnd('\','/')
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\','/')
Assert-Result ((Test-Path -LiteralPath $InputRoot -PathType Container) -and -not (Test-Path -LiteralPath $OutputRoot)) 'Require existing originals and a fresh derived output directory'
Assert-Result (-not $OutputRoot.StartsWith($InputRoot+'\',[StringComparison]::OrdinalIgnoreCase) -and $OutputRoot -cne $InputRoot) 'Derived output must be outside the original evidence directory'
[void][IO.Directory]::CreateDirectory($OutputRoot)

$InputHashes = [ordered]@{}
foreach ($File in Get-ChildItem -LiteralPath $InputRoot -File -Recurse) {
    $Relative = $File.FullName.Substring($InputRoot.Length+1).Replace('\','/')
    $InputHashes[$Relative] = [ordered]@{sha256=(Get-Sha $File.FullName); bytes=$File.Length}
}
$OriginalSummary = Read-Json (Join-Path $InputRoot 'summary.json')
$Request = Read-Json (Join-Path $InputRoot 'request.json')
$Campaign = Read-Json (Join-Path $InputRoot 'source_campaign.json')
$Manifest = Read-Json (Join-Path $InputRoot 'package-manifest.json')
Assert-Result ($OriginalSummary.complete -and $OriginalSummary.failures.Count -eq 0 -and $OriginalSummary.cases.Count -eq 6) 'The original 36-arm source campaign must be complete'
Assert-Result ($Manifest.source_commit -eq $ExpectedSource -and $Request.sources.C.source_commit -eq $ExpectedSource) 'Unexpected captured candidate source'
Assert-Result ((Get-Sha (Join-Path $InputRoot 'source_campaign.json')) -eq $ExpectedCampaignSha256 -and $Request.campaign_sha256 -eq $ExpectedCampaignSha256) 'Registered campaign changed'
Assert-Result ((Get-Sha (Join-Path $InputRoot 'package-manifest.json')) -eq $Request.package_manifest_sha256) 'Original manifest changed'
Assert-Result ((Get-Field $Manifest.files_sha256 'tools/pubpres_integration/Read-Source-Results.ps1') -eq $ExpectedOriginalReaderSha256) 'Unexpected original reader version'
Assert-Result (($Request.order -join '') -ceq 'MICCIM' -and $Request.rendering_driver -eq 'opengl3_angle' -and $Request.render_thread -eq 'safe') 'Unexpected original source order or Windows renderer'
Assert-Result ($Request.sources.M.source_commit -eq $Campaign.source_commits.main -and $Request.sources.I.source_commit -eq $Campaign.source_commits.integration) 'Historical source references changed'
Assert-Result ((@($OriginalSummary.cases.scenario | Sort-Object) -join '/') -ceq (@($Campaign.cases.id | Sort-Object) -join '/')) 'The six registered gameplay scenarios differ'
# The package no longer substitutes full uploads for a requested WARP blit.
# Read-SourceGameplay below separately enforces the original campaign's policy
# on every historical upload, including old C=full and I=blit on the same host.
$CurrentBlit = Get-MaterialTreatment @{material='blit'} 'opengl3_angle' 'ANGLE Microsoft Basic Render Driver Direct3D11'
$CurrentFull = Get-MaterialTreatment @{material='full'} 'opengl3_angle' 'ANGLE Microsoft Basic Render Driver Direct3D11'
Assert-Result ($CurrentBlit.backend -eq 'blit' -and $CurrentBlit.policy -eq '' -and $CurrentFull.backend -eq 'full' -and $CurrentFull.policy -eq '') 'Current package treatment still applies the rejected WARP override'

$script:NumericComparisons = 0
$script:OtherComparisons = 0
function Get-ReplayKeys($Value) {
    if ($Value -is [Collections.IDictionary]) { return @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object) }
    return @($Value.PSObject.Properties | ForEach-Object { $_.Name } | Sort-Object)
}
function Test-ReplayNumber($Value) {
    return $null -ne $Value -and [Type]::GetTypeCode($Value.GetType()) -in @('Byte','SByte','Int16','UInt16','Int32','UInt32','Int64','UInt64','Single','Double','Decimal')
}
function Test-ReplayInteger($Value) {
    return $null -ne $Value -and [Type]::GetTypeCode($Value.GetType()) -in @('Byte','SByte','Int16','UInt16','Int32','UInt32','Int64','UInt64')
}
function Assert-ReplayEquivalent($Left, $Right, [string]$Label, [switch]$ExceptTail) {
    if ($ExceptTail -and $Label -match '/windows/(first_10s|first_144_steps|whole_capture)/worst_frame_intervals$') { return }
    if ($null -eq $Left -or $null -eq $Right) {
        Assert-Result ($null -eq $Left -and $null -eq $Right) "Null mismatch at $Label"
        $script:OtherComparisons++
    } elseif ((Test-ReplayNumber $Left) -and (Test-ReplayNumber $Right)) {
        $script:NumericComparisons++
        if ((Test-ReplayInteger $Left) -and (Test-ReplayInteger $Right)) {
            Assert-Result ($Left -eq $Right) "Integer mismatch at $Label"
        } else {
            $Difference = [Math]::Abs([double]$Left-[double]$Right)
            $Tolerance = [Math]::Max(0.000000001,0.000000000001*[Math]::Max([Math]::Abs([double]$Left),[Math]::Abs([double]$Right)))
            Assert-Result ($Difference -le $Tolerance) "Numeric mismatch at $Label"
        }
    } elseif ($Left -is [Collections.IDictionary] -or $Left -is [PSCustomObject]) {
        Assert-Result ($Right -is [Collections.IDictionary] -or $Right -is [PSCustomObject]) "Object type mismatch at $Label"
        $Keys = @(Get-ReplayKeys $Left)
        Assert-Result (($Keys -join "`n") -ceq ((Get-ReplayKeys $Right) -join "`n")) "Object fields differ at $Label"
        foreach ($Key in $Keys) { Assert-ReplayEquivalent (Get-Field $Left $Key) (Get-Field $Right $Key) ($Label+'/'+$Key) -ExceptTail:$ExceptTail }
    } elseif ($Left -is [Collections.IList]) {
        Assert-Result ($Right -is [Collections.IList] -and $Left.Count -eq $Right.Count) "Array length/type differs at $Label"
        for ($Index = 0; $Index -lt $Left.Count; $Index++) { Assert-ReplayEquivalent $Left[$Index] $Right[$Index] ($Label+'/'+$Index) -ExceptTail:$ExceptTail }
    } else {
        Assert-Result ($Left.GetType() -eq $Right.GetType() -and $Left -ceq $Right) "Value mismatch at $Label"
        $script:OtherComparisons++
    }
}

function Get-ReplayTailOracle($Events, [long]$StartUsec, [long]$EndUsec) {
    $Main = @($Events | Where-Object { $_.event -eq 'main_callback' -and $_.time_usec -ge $StartUsec -and $_.time_usec -le $EndUsec } | Sort-Object start_usec)
    $Top = [Collections.Generic.List[object]]::new()
    $ByStart = @{}
    # Independent bounded insertion ranking, without Sort-Object on dictionaries.
    for ($Index = 1; $Index -lt $Main.Count; $Index++) {
        $Start = [long]$Main[$Index-1].start_usec
        $GapUsec = [long]$Main[$Index].start_usec-$Start
        $Entry = [ordered]@{from_process_frame=$Main[$Index-1].process_frame; to_process_frame=$Main[$Index].process_frame; start_usec=$Start; gap_ms=$GapUsec/1000.0}
        Assert-Result (-not $ByStart.ContainsKey([string]$Start)) 'Ambiguous repeated Main callback start clock'
        $ByStart[[string]$Start] = $Entry
        $Position = 0
        while ($Position -lt $Top.Count) {
            $Other = $Top[$Position]
            if ($GapUsec -gt $Other.gap_usec -or ($GapUsec -eq $Other.gap_usec -and $Start -lt $Other.row.start_usec)) { break }
            $Position++
        }
        if ($Position -lt 12) {
            $Top.Insert($Position,@{gap_usec=$GapUsec; row=$Entry})
            if ($Top.Count -gt 12) { $Top.RemoveAt(12) }
        }
    }
    return @{rows=@($Top | ForEach-Object { $_.row }); by_start=$ByStart; total_intervals=$Main.Count-1}
}

$Records = [Collections.Generic.List[object]]::new()
$WindowsVerified = 0
$OriginalTailDifferences = 0
$ReplayStarted = (Get-Date).ToUniversalTime().ToString('o')
Write-Json (Join-Path $OutputRoot 'replay-request.json') ([ordered]@{
    schema='pubpres-source-results-replay-v1'; started_utc=$ReplayStarted; original_root=$InputRoot; source_commit=$ExpectedSource
    powershell=$PSVersionTable.PSVersion.ToString(); expected_campaign_sha256=$ExpectedCampaignSha256
    original_reader_sha256=$ExpectedOriginalReaderSha256; corrected_reader_sha256=(Get-Sha (Join-Path $PSScriptRoot 'Read-Source-Results.ps1'))
    shared_reader_sha256=(Get-Sha (Join-Path $PSScriptRoot 'Read-Results.ps1')); verifier_sha256=(Get-Sha $PSCommandPath)
    tolerance=[ordered]@{absolute=0.000000001; relative=0.000000000001; integer_counts='exact'}
    original_inputs=$InputHashes; scope='Offline replay only. Original timing, process, source, controls and outputs remain unchanged. Only derived ranked tail lists may differ.'
})

foreach ($Case in $OriginalSummary.cases) {
    Assert-Result ($Case.scenario -match '^[a-z0-9_]+$' -and ($Case.arms.arm -join '') -ceq 'MICCIM') 'Unsafe case name or unbalanced arm order'
    $Scenarios = @($Campaign.cases | Where-Object { $_.id -eq $Case.scenario })
    Assert-Result ($Scenarios.Count -eq 1) 'Unknown registered scenario'
    $Scenario = $Scenarios[0]
    for ($Index = 0; $Index -lt 6; $Index++) {
        $OriginalArm = $Case.arms[$Index]
        $Letter = [string]$OriginalArm.arm
        Assert-Result ($OriginalArm.index -eq $Index) 'Original arm index differs'
        $Relative = $Case.scenario+'/'+$Index+'-'+$Letter
        $Folder = Join-Path $InputRoot $Relative
        $Data = Read-Json (Join-Path $Folder 'receipt.json')
        $Original = Read-Json (Join-Path $Folder 'analysis.json')
        $Process = Read-Json (Join-Path $Folder 'process.json')
        Assert-Result ($Process.exit_code -eq 0 -and -not $Process.timed_out -and (Get-Sha (Join-Path $Folder 'receipt.json')) -eq $OriginalArm.receipt_sha256) 'Original process or receipt failed integrity'
        Assert-ReplayEquivalent $Process $OriginalArm.process ($Relative+'/original-process-summary')
        Assert-ReplayEquivalent $Original $OriginalArm.statistics ($Relative+'/original-summary')
        $Source = Get-Field $Request.sources $Letter
        $Arm = Get-Field $Campaign.arms $Letter
        $Updated = Read-SourceGameplay $Data $Folder $Manifest $Source $Scenario $Arm $Campaign $Request.rendering_driver $Request.render_thread $OriginalArm.nonce
        Assert-ReplayEquivalent $Updated $Original ($Relative+'/statistics') -ExceptTail
        $Events = @([IO.File]::ReadLines((Join-Path $Folder 'receipt-events.jsonl')) | ForEach-Object { ConvertFrom-Json -InputObject $_ } | Where-Object { $_.event -ne 'identity' })
        $Windows = [ordered]@{}
        foreach ($Name in @('first_10s','first_144_steps','whole_capture')) {
            $Window = Get-Field $Updated.windows $Name
            $OriginalWindow = Get-Field $Original.windows $Name
            $Oracle = Get-ReplayTailOracle $Events ([long]$Data.capture_start_usec) ([long]$Window.end_usec)
            Assert-ReplayEquivalent $Window.worst_frame_intervals $Oracle.rows ($Relative+'/'+$Name+'/raw-oracle')
            Assert-Result ($OriginalWindow.worst_frame_intervals.Count -eq $Oracle.rows.Count) 'Original tail excerpt length differs'
            foreach ($Row in $OriginalWindow.worst_frame_intervals) {
                Assert-Result ($Oracle.by_start.ContainsKey([string]$Row.start_usec)) 'Original tail row is not a retained raw interval'
                Assert-ReplayEquivalent $Row $Oracle.by_start[[string]$Row.start_usec] ($Relative+'/'+$Name+'/original-raw-row')
            }
            $OriginalOrder = @($OriginalWindow.worst_frame_intervals | ForEach-Object { [string]$_.start_usec }) -join '/'
            $CorrectOrder = @($Oracle.rows | ForEach-Object { [string]$_.start_usec }) -join '/'
            $Changed = $OriginalOrder -cne $CorrectOrder
            if ($Changed) { $OriginalTailDifferences++ }
            $Windows[$Name] = [ordered]@{raw_intervals=$Oracle.total_intervals; original_tail_ranking_changed=$Changed; corrected_tail_equals_independent_raw_oracle=$true; all_other_fields_match_original=$true}
            $WindowsVerified++
        }
        $DerivedFolder = Join-Path $OutputRoot $Relative
        [void][IO.Directory]::CreateDirectory($DerivedFolder)
        Write-Json (Join-Path $DerivedFolder 'analysis-corrected.json') $Updated
        $Record = [ordered]@{case=$Case.scenario; arm=$Letter; index=$Index; receipt_sha256=(Get-Sha (Join-Path $Folder 'receipt.json'))
            original_analysis_sha256=(Get-Sha (Join-Path $Folder 'analysis.json')); corrected_analysis_sha256=(Get-Sha (Join-Path $DerivedFolder 'analysis-corrected.json')); windows=$Windows}
        $Records.Add($Record)
        Write-Output ("Replayed {0}: three raw-ranked windows, other fields unchanged" -f $Relative)
    }
}
Assert-Result ($Records.Count -eq 36 -and $WindowsVerified -eq 108) 'The complete 36-arm/108-window replay was not performed'
foreach ($Relative in $InputHashes.Keys) {
    $Path = Join-Path $InputRoot $Relative
    Assert-Result ((Get-Item -LiteralPath $Path).Length -eq $InputHashes[$Relative].bytes -and (Get-Sha $Path) -eq $InputHashes[$Relative].sha256) "Original evidence was modified: $Relative"
}
$CurrentInputs = @(Get-ChildItem -LiteralPath $InputRoot -File -Recurse)
Assert-Result ($CurrentInputs.Count -eq $InputHashes.Count) 'Original evidence membership changed'
Write-Json (Join-Path $OutputRoot 'summary.json') ([ordered]@{
    schema='pubpres-source-results-replay-v1'; complete=$true; source_commit=$ExpectedSource; captures=$Records.Count; windows=$WindowsVerified
    original_tail_rankings_changed=$OriginalTailDifferences; numeric_comparisons=$script:NumericComparisons; other_comparisons=$script:OtherComparisons
    original_inputs_unchanged=$true; all_non_tail_fields_match=$true; independent_raw_tail_oracle_passed=$true
    corrected_reader_sha256=(Get-Sha (Join-Path $PSScriptRoot 'Read-Source-Results.ps1')); verifier_sha256=(Get-Sha $PSCommandPath)
    request_sha256=(Get-Sha (Join-Path $OutputRoot 'replay-request.json')); captures_replayed=$Records.ToArray()
    scope='The original tail excerpts remain retained and may be misranked. Separate derived analyses use the corrected reader. No process or frame was rerun; no source, control, timestep, health invariant or measured window changed. Completion does not grant performance acceptance.'
    physical_acceptance='HOLD'
})
Write-Output ("PASS: {0} captures, {1} windows; {2} original tail rankings corrected; original evidence unchanged." -f $Records.Count,$WindowsVerified,$OriginalTailDifferences)
