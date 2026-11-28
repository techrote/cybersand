[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$PackageRoot,
    [Parameter(Mandatory=$true)][string]$ExpectedCandidate,
    [Parameter(Mandatory=$true)][string]$Output,
    [string]$ArtifactZip = ''
)

# Run on actual Windows after assembling the new exact-source payload.
# These tests qualify package/process refusal behavior, not playability/GPU.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PPTestInputs = @{PackageRoot=$PackageRoot; ExpectedCandidate=$ExpectedCandidate; ArtifactZip=$ArtifactZip}
. (Join-Path $PSScriptRoot 'Start-PUBPRES-Playability.ps1') -Library
# Dot-sourced script parameters share this scope, including their defaults.
# Restore the mandatory test inputs before using the imported helper functions.
$PackageRoot = $PPTestInputs.PackageRoot
$ExpectedCandidate = $PPTestInputs.ExpectedCandidate
$ArtifactZip = $PPTestInputs.ArtifactZip
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)
$Output = [IO.Path]::GetFullPath($Output)
Assert-PP (-not (Test-Path -LiteralPath $Output) -and -not $Output.StartsWith($PackageRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Test output must be new and outside the pristine package'
[IO.Directory]::CreateDirectory($Output) | Out-Null
$Checks = [Collections.Generic.List[object]]::new()
$Failures = [Collections.Generic.List[string]]::new()

function Expect-PPRefusal([string]$CaseLabel,[scriptblock]$Probe,[string]$ExpectedPattern,[object[]]$ProbeArguments=@()) {
    # Distinct helper names avoid dynamically shadowing variables in callers.
    # Data-dependent probes pass their input explicitly through parameters.
    $ProbeRejected = $false; $ProbeReason = ''
    try { & $Probe @ProbeArguments | Out-Null } catch { $ProbeRejected = $true; $ProbeReason = $_.Exception.Message }
    $ProbePassed = $ProbeRejected -and $ProbeReason -match $ExpectedPattern
    $Checks.Add([ordered]@{name=$CaseLabel;passed=$ProbePassed;rejected=$ProbeRejected;reason=$ProbeReason})
    if (-not $ProbePassed) { $Failures.Add($CaseLabel+': unexpected acceptance or reason: '+$ProbeReason) }
}
function Add-PPZipFile($Zip,[string]$Name,[string]$Source) {
    $Entry = $Zip.CreateEntry($Name,[IO.Compression.CompressionLevel]::NoCompression)
    $From = [IO.File]::OpenRead($Source); $To = $Entry.Open()
    try { $From.CopyTo($To) } finally { $To.Dispose(); $From.Dispose() }
}
function Add-PPZipText($Zip,[string]$Name,[string]$Text) {
    $Entry = $Zip.CreateEntry($Name); $To = $Entry.Open()
    try { $Bytes = $script:PPUtf8.GetBytes($Text); $To.Write($Bytes,0,$Bytes.Length) } finally { $To.Dispose() }
}

try {
    foreach ($Script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
        $Tokens = $null; $Errors = $null
        [Management.Automation.Language.Parser]::ParseFile($Script.FullName,[ref]$Tokens,[ref]$Errors) | Out-Null
        Assert-PP (@($Errors).Count -eq 0) ('PowerShell parse failed: '+$Script.Name+': '+($Errors -join ';'))
    }
    $Manifest = Test-PPPackage $PackageRoot $ExpectedCandidate
    $Checks.Add([ordered]@{name='pristine-all-files-and-independent-sources';passed=$true;files=$Manifest.file_count})
    & (Join-Path $PSScriptRoot 'Test-ProcessOwner.ps1') -Output (Join-Path $Output 'owned-process-lifecycle')
    $Lifecycle = Read-PPJson (Join-Path $Output 'owned-process-lifecycle/process-owner-tests.json')
    Assert-PP (@($Lifecycle.failures).Count -eq 0 -and @($Lifecycle.checks).Count -eq 4) 'Owned descendant lifecycle controls failed'
    $Checks.Add([ordered]@{name='creation-time-job-and-descendant-lifecycle';passed=$true;controls=$Lifecycle.checks})
    Expect-PPRefusal 'wrong-expected-source' { Test-PPPackage $PackageRoot ('0'*40) } 'identity|candidate|SHA'
    foreach ($UnsafePath in @('../escape','/absolute','a\b','a:stream','a/CON.txt','a/../bad')) {
        $PathAudit = [ordered]@{actual_input=$null}
        Expect-PPRefusal ('unsafe-path-'+$UnsafePath) {
            param([string]$ActualPath,[Collections.IDictionary]$Audit)
            $Audit['actual_input'] = $ActualPath
            Test-PPSafeName $ActualPath
        } 'Unsafe' @($UnsafePath,$PathAudit)
        $PathCheck = $Checks[$Checks.Count-1]
        $PathCheck['expected_input'] = $UnsafePath
        $PathCheck['actual_input'] = $PathAudit.actual_input
        $PathCheck['input_matches_fixture'] = $PathAudit.actual_input -ceq $UnsafePath
        if (-not $PathCheck.input_matches_fixture) { $PathCheck['passed'] = $false }
        Assert-PP $PathCheck.input_matches_fixture 'Unsafe-path probe executed a different input from its fixture'
    }
    $Run = New-PPRun $PackageRoot $Manifest 'C' 'eager' 'safe' 'opengl3'
    $RunRecord = Test-PPRun $Run $PackageRoot $Manifest
    Assert-PP ($RunRecord.same_frame_continuation -ceq 'off' -and $RunRecord.settings.CYBERSAND_DIAG_SAME_FRAME_CONTINUATION -ceq '0') 'Continuation default changed'
    $Checks.Add([ordered]@{name='pristine-isolated-run';passed=$true;run=$Run})
    $ContinuationRun = New-PPRun $PackageRoot $Manifest 'C' 'eager' 'safe' 'opengl3' 'on'
    $ContinuationRecord = Test-PPRun $ContinuationRun $PackageRoot $Manifest
    Assert-PP ($ContinuationRecord.same_frame_continuation -ceq 'on' -and $ContinuationRecord.settings.CYBERSAND_DIAG_SAME_FRAME_CONTINUATION -ceq '1') 'Explicit continuation selector differs'
    $Checks.Add([ordered]@{name='explicit-continuation-isolated-run';passed=$true;run=$ContinuationRun})
    $World = Join-PPSafe $Run 'source/native/src/world.cpp'
    if (-not (Test-Path -LiteralPath $World -PathType Leaf)) {
        $World = @(Get-ChildItem -LiteralPath (Join-PPSafe $Run 'source/native/src') -Filter '*.cpp' -Recurse)[0].FullName
    }
    $Original = [IO.File]::ReadAllBytes($World)
    $OriginalRun = [IO.File]::ReadAllBytes((Join-Path $Run 'run.json'))
    try {
        [IO.File]::AppendAllText($World,"`n// deliberate source-corruption test`n",$script:PPUtf8)
        Expect-PPRefusal 'changed-world-source' { Test-PPRun $Run $PackageRoot $Manifest } 'Changed World/application source'
        $Changed = Read-PPJson (Join-Path $Run 'run.json')
        $Relative = $World.Substring((Join-Path $Run 'source').Length+1).Replace('\','/')
        $Changed.files_sha256.$Relative = Get-PPHash $World
        Write-PPJson (Join-Path $Run 'run.json') $Changed
        Expect-PPRefusal 'changed-world-and-forged-local-hash' { Test-PPRun $Run $PackageRoot $Manifest } 'Changed World/application source'
    } finally {
        [IO.File]::WriteAllBytes($World,$Original)
        [IO.File]::WriteAllBytes((Join-Path $Run 'run.json'),$OriginalRun)
    }
    # Source-derived import metadata remains immutable and hash checked.
    # Canonical archive export must prevent Godot's LF rewrite on every source.
    foreach ($SourceKey in $Manifest.sources.PSObject.Properties.Name) {
        $DescriptorPath = Join-PPSafe $PackageRoot ($Manifest.sources.$SourceKey.root+'/godot/addons/godot-rapier2d/Radial2D.svg.import')
        $DescriptorBytes = [IO.File]::ReadAllBytes($DescriptorPath)
        Assert-PP (-not ($script:PPUtf8.GetString($DescriptorBytes).Contains("`r"))) 'Committed import descriptor must be canonical LF'
        $Checks.Add([ordered]@{name=('canonical-import-descriptor-'+$SourceKey);passed=$true;sha256=(Get-PPHash $DescriptorPath)})
    }
    $Import = Join-PPSafe $Run 'source/godot/addons/godot-rapier2d/Radial2D.svg.import'
    $OriginalImport = [IO.File]::ReadAllBytes($Import)
    try {
        [IO.File]::AppendAllText($Import,"`n# deliberate import metadata corruption`n",$script:PPUtf8)
        Expect-PPRefusal 'changed-committed-import-descriptor' { Test-PPRun $Run $PackageRoot $Manifest } 'Changed World/application source'
        $Changed = Read-PPJson (Join-Path $Run 'run.json')
        $Changed.files_sha256.'godot/addons/godot-rapier2d/Radial2D.svg.import' = Get-PPHash $Import
        Write-PPJson (Join-Path $Run 'run.json') $Changed
        Expect-PPRefusal 'changed-import-and-forged-local-hash' { Test-PPRun $Run $PackageRoot $Manifest } 'Changed World/application source'
    } finally {
        [IO.File]::WriteAllBytes($Import,$OriginalImport)
        [IO.File]::WriteAllBytes((Join-Path $Run 'run.json'),$OriginalRun)
    }
    $Changed = Read-PPJson (Join-Path $Run 'run.json')
    try {
        $Changed.settings.CYBERSAND_DIAG_NATIVE_RENDEZVOUS = '1'
        Write-PPJson (Join-Path $Run 'run.json') $Changed
        Expect-PPRefusal 'forged-rendezvous-selector' { Test-PPRun $Run $PackageRoot $Manifest } 'selectors changed'
    } finally { [IO.File]::WriteAllBytes((Join-Path $Run 'run.json'),$OriginalRun) }
    $Changed = Read-PPJson (Join-Path $Run 'run.json')
    try {
        $Changed.settings.CYBERSAND_DIAG_SAME_FRAME_CONTINUATION = '1'
        Write-PPJson (Join-Path $Run 'run.json') $Changed
        Expect-PPRefusal 'forged-continuation-selector' { Test-PPRun $Run $PackageRoot $Manifest } 'selectors changed'
    } finally { [IO.File]::WriteAllBytes((Join-Path $Run 'run.json'),$OriginalRun) }
    Test-PPRun $Run $PackageRoot $Manifest | Out-Null
    $Extra = Join-PPSafe $Run 'source/godot/scripts/unexpected_source.gd'
    try {
        [IO.File]::WriteAllText($Extra,'extends Node',$script:PPUtf8)
        Expect-PPRefusal 'unexpected-world-source-file' { Test-PPRun $Run $PackageRoot $Manifest } 'Unexpected run source'
    } finally { Remove-Item -LiteralPath $Extra }
    Expect-PPRefusal 'historical-source-cannot-enable-new-pools' { Get-PPSettings 'M' 'reachable' 'safe' 'opengl3' } 'Unsupported run selectors'
    Expect-PPRefusal 'main-cannot-enable-continuation' { Get-PPSettings 'M' 'eager' 'safe' 'opengl3' 'on' } 'Unsupported run selectors'
    Expect-PPRefusal 'reference-cannot-enable-continuation' { Get-PPSettings 'I' 'eager' 'safe' 'opengl3' 'on' } 'Unsupported run selectors'
    Expect-PPRefusal 'continuation-requires-qualified-render-owner' { Get-PPSettings 'C' 'eager' 'separate' 'opengl3' 'on' } 'Unsupported run selectors'

    # One separate payload copy permits corruption tests without mutating
    # the pristine package, binary history or any previous evidence.
    $ChangedRoot = Join-Path $Output 'corruption-copy'
    Copy-Item -LiteralPath $PackageRoot -Destination $ChangedRoot -Recurse
    $Native = Join-PPSafe $ChangedRoot $Manifest.sources.C.native.path
    $Stream = [IO.File]::Open($Native,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite)
    try { $Byte = $Stream.ReadByte(); $Stream.Position=0; $Stream.WriteByte([byte]($Byte -bxor 1)) } finally { $Stream.Dispose() }
    Expect-PPRefusal 'corrupted-native-binary' { Test-PPPackage $ChangedRoot $ExpectedCandidate } 'Changed/reparse payload'
    [IO.File]::Copy((Join-PPSafe $PackageRoot $Manifest.sources.C.native.path),$Native,$true)
    $Stale = Join-Path $ChangedRoot 'old-package-leftover.txt'
    try {
        [IO.File]::WriteAllText($Stale,'stale',$script:PPUtf8)
        Expect-PPRefusal 'stale-extra-payload-file' { Test-PPPackage $ChangedRoot $ExpectedCandidate } 'Unexpected file'
    } finally { Remove-Item -LiteralPath $Stale }
    $Receipt = Join-PPSafe $ChangedRoot $Manifest.sources.C.native.receipt
    $Original = [IO.File]::ReadAllBytes($Receipt)
    try {
        [IO.File]::AppendAllText($Receipt,'corrupt',$script:PPUtf8)
        Expect-PPRefusal 'corrupted-build-evidence' { Test-PPPackage $ChangedRoot $ExpectedCandidate } 'Changed/reparse payload'
    } finally { [IO.File]::WriteAllBytes($Receipt,$Original) }
    Test-PPPackage $ChangedRoot $ExpectedCandidate | Out-Null

    if ($ArtifactZip) {
        $ArtifactZip = [IO.Path]::GetFullPath($ArtifactZip)
        $ExpectedName = $Manifest.package_filename
        Assert-PP ([IO.Path]::GetFileName($ArtifactZip) -ceq $ExpectedName) 'Pass the freshly built inner evaluator ZIP to package tests'
        $OuterPath = Join-Path $Output 'nested-github-artifact.zip'
        $Zip = [IO.Compression.ZipFile]::Open($OuterPath,[IO.Compression.ZipArchiveMode]::Create)
        try {
            Add-PPZipFile $Zip ('evaluator/'+$ExpectedName) $ArtifactZip
            Add-PPZipFile $Zip ('evaluator/'+$ExpectedName+'.sha256') ($ArtifactZip+'.sha256')
        } finally { $Zip.Dispose() }
        $Extracted = Expand-PPEvaluator $OuterPath '' (Get-PPHash $ArtifactZip) (Join-Path $Output 'nested-extraction') $ExpectedCandidate $Manifest.mission
        Test-PPPackage $Extracted $ExpectedCandidate | Out-Null
        $Checks.Add([ordered]@{name='exact-nested-artifact-and-sidecar';passed=$true;payload=$Extracted})
        Expect-PPRefusal 'stale-extraction-destination' {
            Expand-PPEvaluator $OuterPath '' '' (Join-Path $Output 'nested-extraction') $ExpectedCandidate $Manifest.mission
        } 'Destination already exists'
        Expect-PPRefusal 'wrong-independent-archive-digest' {
            Expand-PPEvaluator $ArtifactZip '' ('0'*64) (Join-Path $Output 'bad-known-hash') $ExpectedCandidate $Manifest.mission
        } 'expected archive SHA differs'
        $WrongSidecar = Join-Path $Output 'wrong.sha256'
        [IO.File]::WriteAllText($WrongSidecar,('0'*64)+'  '+$ExpectedName+"`n",$script:PPUtf8)
        Expect-PPRefusal 'corrupted-archive-sidecar' {
            Expand-PPEvaluator $ArtifactZip $WrongSidecar '' (Join-Path $Output 'bad-sidecar') $ExpectedCandidate $Manifest.mission
        } 'ZIP is corrupt|differs from its sidecar'
        $Ambiguous = Join-Path $Output 'ambiguous-outer.zip'
        $Zip = [IO.Compression.ZipFile]::Open($Ambiguous,[IO.Compression.ZipArchiveMode]::Create)
        try {
            Add-PPZipText $Zip ('a/'+$ExpectedName) 'a'; Add-PPZipText $Zip ('b/'+$ExpectedName) 'b'
        } finally { $Zip.Dispose() }
        Expect-PPRefusal 'ambiguous-nested-evaluators' {
            Expand-PPEvaluator $Ambiguous '' '' (Join-Path $Output 'bad-ambiguous') $ExpectedCandidate $Manifest.mission
        } 'exactly one correctly named'
    }

    $Engine = Join-PPSafe $PackageRoot $Manifest.engine.gui.path
    $Project = Join-PPSafe $Run 'source/godot'
    $Settings = Get-PPSettings 'C' 'eager' 'safe' 'opengl3'
    $Failed = Join-Path $Output 'failed-child'
    Expect-PPRefusal 'failed-child' {
        Invoke-PPProcess $Engine @('--headless','--path',$Project,'--audio-driver','Dummy','--script','res://does-not-exist.gd') $Failed (Join-Path $Output 'failed-profile') $Settings $ExpectedCandidate 60
    } 'Application failed|script/renderer error'
    Assert-PP (Test-Path -LiteralPath (Join-Path $Failed 'process.json')) 'Failed child receipt was not retained'
    $WaitScript = Join-Path $Output 'wait_forever.gd'
    [IO.File]::WriteAllText($WaitScript,"extends SceneTree`nfunc _initialize() -> void:`n`tprint(`"PUBPRES_TIMEOUT_FIXTURE`")`n",$script:PPUtf8)
    $Timed = Join-Path $Output 'timeout-child'
    Expect-PPRefusal 'bounded-child-timeout' {
        Invoke-PPProcess $Engine @('--headless','--path',$Project,'--audio-driver','Dummy','--script',$WaitScript) $Timed (Join-Path $Output 'timeout-profile') $Settings $ExpectedCandidate 2
    } 'Application failed'
    $Deadline = Read-PPJson (Join-Path $Timed 'process.json')
    Assert-PP ($Deadline.timed_out -eq $true -and $null -ne $Deadline.exit_code) 'Timeout did not retain actual child termination'
    $Missing = Join-Path $Output 'failed-executable'
    Expect-PPRefusal 'unstartable-child' {
        Invoke-PPProcess (Join-Path $Output 'missing.exe') @() $Missing (Join-Path $Output 'missing-profile') $Settings $ExpectedCandidate 2
    } 'CreateProcessW in owned suspended Job|cannot find|not found|No such file|system cannot|specified'
    Assert-PP (Test-Path -LiteralPath (Join-Path $Missing 'process.json')) 'Unstartable child receipt was not retained'
    Test-PPPackage $PackageRoot $ExpectedCandidate | Out-Null
    $Checks.Add([ordered]@{name='pristine-package-still-identical';passed=$true})
} catch { $Failures.Add($_.Exception.Message) }
finally {
    Write-PPJson (Join-Path $Output 'package-tests.json') ([ordered]@{schema='pubpres-playability-package-tests-v1';
        candidate_commit=$ExpectedCandidate;checks=$Checks.ToArray();failures=$Failures.ToArray();platform=[Environment]::OSVersion.ToString();
        powershell=$PSVersionTable.PSVersion.ToString();physical_acceptance='HOLD';
        scope='Actual Windows pristine package, source/corruption refusal, creation-time Job ownership, zero-exit orphan refusal, explicit cancellation and child failure/deadline tests. No graphical or physical playability claim. Physical console Ctrl+C remains a separate owner exercise.'})
}
Assert-PP ($Failures.Count -eq 0) ('Package qualification failures: '+($Failures -join '; '))
Write-Host ('Passed '+$Checks.Count+' package/process checks; physical NVIDIA acceptance remains HOLD.')
