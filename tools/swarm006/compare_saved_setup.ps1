# SWARM006 exact-crop OFF/ON native comparison, Windows PowerShell 5.1+.
# Read-only: never loads, edits, applies, or overwrites the owner's saved World.
# Uses its v2 authored rectangles to reconstruct an exact finite source crop.
[CmdletBinding()]
param(
    [string]$Setup = "$HOME\Downloads\setup-swarm-006-smoketest.json",
    [string]$PackageRoot = "",
    [int]$CropX = 800,
    [int]$CropY = 400,
    [int]$Width = 192,
    [int]$Height = 112,
    [int]$Seed = 605,
    [int]$Rounds = 2,
    [ValidateSet("off","on","both")][string]$Swarm005Options = "both",
    [string]$Output = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$sourceCommit = "4e8ff0b01043d9e1bed336559b17e37283094add"
$cliSha256 = "0db65201955dfe1d8be518feb66de3812d1d2ec8fe70e450e338f007510c60d3"
$downloads = Join-Path $HOME "Downloads"
if (-not (Test-Path -LiteralPath $Setup -PathType Leaf)) {
    throw "Saved setup not found: $Setup. Save the chat attachment to Downloads or pass -Setup FULLPATH."
}
if ($Width -ne 192 -or $Height -ne 112 -or $Rounds -lt 0 -or $Rounds -gt 4) {
    throw "This frozen owner case requires 192x112; rounds must be 0..4."
}
if (-not $PackageRoot) {
    Write-Host "Locating the exact source-matched SWARM006 evaluator under Downloads..."
    $options = @(Get-ChildItem -LiteralPath $downloads -File -Recurse -Filter "gentek_reciprocal.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]godot[\\/]tools[\\/]gentek_reciprocal\.exe$' } |
        Sort-Object LastWriteTime -Descending)
    foreach ($file in $options) {
        $candidate = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $file.FullName))
        $infoFile = Join-Path $candidate "godot\tools\swarm004-runtime.json"
        if (-not (Test-Path -LiteralPath $infoFile -PathType Leaf)) { continue }
        try {
            $info = Get-Content -LiteralPath $infoFile -Raw | ConvertFrom-Json
            if ($info.source -eq $sourceCommit) {
                $PackageRoot = $candidate
                break
            }
        } catch {}
    }
}
if (-not $PackageRoot) {
    throw "Cannot find the extracted SWARM006 4e8ff0b0 owner package. Pass -PackageRoot FULLPATH to the folder containing candidate-manifest.json."
}
$PackageRoot = (Resolve-Path -LiteralPath $PackageRoot).Path
$cli = Join-Path $PackageRoot "godot\tools\gentek_reciprocal.exe"
$infoFile = Join-Path $PackageRoot "godot\tools\swarm004-runtime.json"
$manifestFile = Join-Path $PackageRoot "candidate-manifest.json"
foreach ($path in @($cli,$infoFile,$manifestFile)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Incomplete owner package: $path" }
}
$info = Get-Content -LiteralPath $infoFile -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
if ($manifest.programme -ne "GENTEK-SWARM-006" -or $manifest.source_commit -ne $sourceCommit -or
    $info.source -ne $sourceCommit -or $info.sha256 -ne $cliSha256) {
    throw "This owner package does not identify the frozen SWARM006 executable."
}
$actual = (Get-FileHash -LiteralPath $cli -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $cliSha256) { throw "Native executable SHA256 mismatch: $actual" }

$setupHash = (Get-FileHash -LiteralPath $Setup -Algorithm SHA256).Hash.ToLowerInvariant()
$data = Get-Content -LiteralPath $Setup -Raw | ConvertFrom-Json
if ($data.version -ne 2 -or $data.extent.Count -ne 2 -or
    $data.extent[0] -ne 2048 -or $data.extent[1] -ne 2048 -or
    $data.normalize -ne $false -or $data.actors.Count -ne 0 -or $data.source.Count -ne 0) {
    throw "Expected the submitted 2048x2048 authored-start setup with no actors, sources or native baseline."
}
if ($CropX -lt 0 -or $CropY -lt 0 -or $CropX+$Width -gt 2048 -or $CropY+$Height -gt 2048) {
    throw "The finite crop lies outside the saved World."
}
if (-not $Output) {
    $Output = Join-Path $downloads ("SWARM006-exact-crop-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
}
if (Test-Path -LiteralPath $Output) { throw "Use a new output directory; refusing to overwrite: $Output" }
New-Item -ItemType Directory -Path $Output | Out-Null
$Output = (Resolve-Path -LiteralPath $Output).Path

# Replay the saved, ordered authored rectangle stamps into a PRIVATE cropped plane.
# All 1646 stamps in the supplied setup are 5-field boxes. Fail closed on discs.
$count = $Width * $Height
$context = New-Object 'System.Int32[]' $count
$intersections = 0
foreach ($stamp in $data.edits) {
    if ($stamp.Count -ne 5) { throw "Nonrectangular stamp; this exact-history comparator will not approximate disc paint." }
    $sx=[int]$stamp[0];$sy=[int]$stamp[1]
    $ex=$sx+[int]$stamp[2];$ey=$sy+[int]$stamp[3];$material=[int]$stamp[4]
    $left=[Math]::Max($sx,$CropX);$right=[Math]::Min($ex,$CropX+$Width)
    $top=[Math]::Max($sy,$CropY);$bottom=[Math]::Min($ey,$CropY+$Height)
    if ($right -le $left -or $bottom -le $top) { continue }
    $intersections++
    for ($worldY=$top;$worldY -lt $bottom;$worldY++) {
        for ($worldX=$left;$worldX -lt $right;$worldX++) {
            $at=($worldY-$CropY)*$Width+($worldX-$CropX)
            $context[$at]=$material
        }
    }
}
$nonempty=0
$plane=New-Object 'System.Byte[]' ($count*2)
for ($at=0;$at -lt $count;$at++) {
    $id=$context[$at]
    if ($id -lt 0 -or $id -gt 131 -or $id -eq 10) { throw "Native material outside qualified request catalogue." }
    if ($id -ne 0) {$nonempty++}
    $plane[$at*2]=[byte]($id -band 255)
    $plane[$at*2+1]=[byte](($id -shr 8) -band 255)
}
$planePath=Join-Path $Output "same-source-native-crop.le16"
[IO.File]::WriteAllBytes($planePath,$plane)
$planeHash=(Get-FileHash -LiteralPath $planePath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("Fixed source: origin ({0},{1}); {2}x{3}; nonempty {4}; stamp overlaps {5}" -f
    $CropX,$CropY,$Width,$Height,$nonempty,$intersections) -ForegroundColor Cyan

# Exact reference for godot/scripts/workbench_reciprocal_protocol.gd:
# left_right owner mask; 4-cell border; reach 13; no protected marks.
$bodyLines = New-Object 'System.Collections.Generic.List[string]'
$border=4
$mid=[int]($Width/2)
for ($y=0;$y -lt $Height;$y++) {
    for ($x=0;$x -lt $Width;$x++) {
        $inside = $x -ge $border -and $y -ge $border -and
                  $x -lt ($Width-$border) -and $y -lt ($Height-$border)
        $frame=0;$mosaic=0;$shared=0
        if ($inside) {
            if ($x -lt $mid) { $frame=1 } else { $mosaic=1 }
            if ($x -ge ($mid-1-13) -and $x -le ($mid+13)) {$shared=1}
        }
        $nativeMaterial=$context[$y*$Width+$x]
        $bodyLines.Add("$frame $mosaic 0 $shared $nativeMaterial")
    }
}
$body=([string]::Join([Environment]::NewLine,$bodyLines.ToArray())+[Environment]::NewLine)
$profiles = [ordered]@{
    industrial = "0.65000000 0.15000000 0.00000000 0.00000000 0.75000000 1.00000000 0.15000000"
    viaduct_like = "0.65000000 0.05000000 0.00000000 0.00000000 0.55000000 0.25000000 0.35000000"
    irregular_megastructure = "0.65000000 0.95000000 0.00000000 0.00000000 1.00000000 0.70000000 0.20000000"
}
$variants = if ($Swarm005Options -eq "both") {@("off","on")} else {@($Swarm005Options)}
$records=New-Object 'System.Collections.Generic.List[object]'
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($variant in $variants) {
    $extra = $variant -eq "on"
    foreach ($style in @($profiles.Keys)) {
        foreach ($recovery in @($false,$true)) {
            $mode = if ($recovery) {"recovery_on"} else {"recovery_off"}
            $stem = "$style-$variant-$mode"
            $magic = if ($recovery) {"SWARM006 4"} elseif ($extra) {"SWARM005 3"} else {"SWARM004 1"}
            $header=New-Object 'System.Collections.Generic.List[string]'
            $header.Add($magic)
            $header.Add("$Width $Height $Seed $CropX $CropY $Rounds 13 -1")
            $header.Add($style)
            $header.Add($profiles[$style] + " 1")
            if ($recovery -or $extra) { $header.Add($profiles[$style] + " 1") }
            if ($recovery) {
                $c=if ($extra) {1} else {0}
                $header.Add("$c $c 1")
            } elseif ($extra) { $header.Add("1 1") }
            $header.Add("1")
            $header.Add("$mid $([int]($Height/2))")
            $request=Join-Path $Output ($stem+".request.txt")
            $response=Join-Path $Output ($stem+".result.json")
            $log=Join-Path $Output ($stem+".log")
            [IO.File]::WriteAllText($request,[string]::Join([Environment]::NewLine,$header.ToArray())+
                [Environment]::NewLine+$body,$utf8)
            Write-Host "Generating $stem" -ForegroundColor Cyan
            $global:LASTEXITCODE=0
            & $cli "request" $request $response $sourceCommit 2>&1 | Out-File -LiteralPath $log -Encoding UTF8
            $exit=[int]$LASTEXITCODE
            if ($exit -ne 0 -or -not (Test-Path -LiteralPath $response -PathType Leaf)) {
                throw "Native candidate refused/failed for $stem (exit $exit). See $log. No result is counted as a success."
            }
            $result=Get-Content -LiteralPath $response -Raw | ConvertFrom-Json
            if ($result.source -ne $sourceCommit -or
                $result.input.frame.width -ne $Width -or $result.input.frame.height -ne $Height -or
                $result.input.frame.seed -ne $Seed -or
                $result.input.frame.origin[0] -ne $CropX -or $result.input.frame.origin[1] -ne $CropY) {
                throw "Native output changed the common immutable crop or source: $stem"
            }
            $expectedRecovery=[bool]$recovery
            $nativeRecovery = $false
            if ($null -ne $result.input.options.PSObject.Properties["negotiated_recovery"]) {
                $nativeRecovery = [bool]$result.input.options.negotiated_recovery
            }
            if ($nativeRecovery -ne $expectedRecovery) {
                throw "Native output does not attest the selected recovery flag: $stem"
            }
            $obligations=@($result.obligations)
            $required=@($obligations | Where-Object {$_.state -eq "STILL_REQUIRED"}).Count
            $foreign=@($obligations | Where-Object {$_.state -eq "FOREIGN_JOINED"}).Count
            $joints=@($result.joints).Count
            $apply=($result.status -eq "complete" -and $result.can_apply -eq $true -and $required -eq 0)
            $knownFinal=($result.status -eq "complete" -or $result.status -eq "blocked")
            $cells=0
            foreach ($m in $result.cells) { if ([int]$m -ne 0) {$cells++} }
            $foreignValue=$null;$requiredValue=$null
            if ($knownFinal) { $foreignValue=$foreign;$requiredValue=$required }
            $row=[pscustomobject]@{
                Style=$style;Swarm005Options=$variant;Recovery=$mode;
                Status=[string]$result.status;CanApply=[bool]$result.can_apply;
                ApplyValid=[bool]$apply;MaterialCells=$cells;
                QualifiedJoints=$joints;
                ForeignJoined=$foreignValue;
                StillRequired=$requiredValue;
                StopReason=[string]$result.stop_reason;
                ChargedWork=[string]$result.metrics.total_charged_work;
                RequestSHA256=(Get-FileHash -LiteralPath $request -Algorithm SHA256).Hash.ToLowerInvariant();
                ResultSHA256=(Get-FileHash -LiteralPath $response -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            $records.Add($row)
            Write-Host ("  {0}: Apply={1}, joints={2}, unresolved={3}" -f
                $row.Status,$row.ApplyValid,$row.QualifiedJoints,$row.StillRequired)
            $result=$null
        }
    }
}
$rows=@($records.ToArray())
$rows | Export-Csv -LiteralPath (Join-Path $Output "all-cases.csv") -NoTypeInformation -Encoding UTF8
$pairs=New-Object 'System.Collections.Generic.List[object]'
foreach($variant in $variants) {
    foreach($style in @($profiles.Keys)) {
        $off=@($rows | Where-Object {$_.Style -eq $style -and $_.Swarm005Options -eq $variant -and $_.Recovery -eq "recovery_off"})[0]
        $on=@($rows | Where-Object {$_.Style -eq $style -and $_.Swarm005Options -eq $variant -and $_.Recovery -eq "recovery_on"})[0]
        $pairs.Add([pscustomobject]@{
            Style=$style;Swarm005Options=$variant;
            OffStatus=$off.Status;OffApply=$off.ApplyValid;OffJoints=$off.QualifiedJoints;OffUnresolved=$off.StillRequired;
            OnStatus=$on.Status;OnApply=$on.ApplyValid;OnJoints=$on.QualifiedJoints;OnUnresolved=$on.StillRequired;
            GainInQualifiedJoints=($on.QualifiedJoints-$off.QualifiedJoints);
            RescuedApply=([bool]$on.ApplyValid -and -not [bool]$off.ApplyValid)
        })
    }
}
@($pairs.ToArray()) | Export-Csv -LiteralPath (Join-Path $Output "paired-results.csv") -NoTypeInformation -Encoding UTF8
[pscustomobject]@{
    Schema=1;Scope="Saved authored-setup rectangle replay on identical finite native crop; not transient live World";
    SavedSetup=(Resolve-Path -LiteralPath $Setup).Path;SavedSetupSHA256=$setupHash;
    SourceCommit=$sourceCommit;NativeExecutableSHA256=$cliSha256;
    Origin=@($CropX,$CropY);Size=@($Width,$Height);Seed=$Seed;Rounds=$Rounds;
    Border=$border;InterfaceReach=13;Layout="FRAME left / MOSAIC right";SharedTerritory=$true;
    OptionalNegotiation=$true;Orientation="Balanced";
    NativeContextSHA256=$planeHash;ContextNonemptyCells=$nonempty;
    OverlappingSavedStamps=$intersections;ActivationLocal=@($mid,[int]($Height/2));
    SWARM005Options=$Swarm005Options;Programmes=@("SWARM004","SWARM005","SWARM006");
    Notes="Actual authoritative native generator; results are independent proposals, no Apply/Undo/Save writes. Different protocol version when recovery toggled is required by the qualified bridge."
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Output "comparison-manifest.json") -Encoding UTF8
Write-Host ""
Write-Host "Exact same-source OFF/ON comparison completed. No World writes." -ForegroundColor Green
@($pairs.ToArray()) | Format-Table -AutoSize
Write-Host "Saved: $Output" -ForegroundColor Cyan
Write-Host "Please send paired-results.csv and comparison-manifest.json for independent interpretation."
