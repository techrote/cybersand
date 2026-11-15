# CyberSand Test It: packaged Windows x64 graphical, real-Needle/2048 source.
# Local-only (no installs/downloads), all evidence retained, one final ZIP.
[CmdletBinding()]
param(
  [switch]$Quick,
  [switch]$Full,
  [switch]$Compare,
  [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver='opengl3',
  [ValidateRange(60,1200)][int]$TimeoutSeconds=900
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=(Resolve-Path -LiteralPath $PSScriptRoot).Path
$Engine=Join-Path $Root 'Godot_v4.7-stable_win64_console.exe'
$Project=Join-Path $Root 'godot'
$ManifestFile=Join-Path $Root 'PR593-MANIFEST.json'
$Output=Join-Path $Root ('Test-It-Results\'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+$PID)
$Zip=$Output+'.zip'
$Cases=Join-Path $Output 'cases'
New-Item -ItemType Directory -Force -Path $Cases|Out-Null
$PreviousAppData=$env:APPDATA
$PreviousXdg=$env:XDG_DATA_HOME
$PreviousSource=$env:CYBERSAND_SOURCE_REVISION
$PreviousPose=$env:CYBERSAND_DIAG_FLYER_POSE
$Start=Get-Date
$Summary=@{schema='engine-lab-scripted-pose-test-it-v1';status='incomplete';complete=$false
    source='unverified';driver=$RenderingDriver;cases=@();errors=@();processes=@()
    mode=$(if($Quick){'quick'}elseif($Compare){'compare'}elseif($Full){'full'}else{'eight-case'})}
function Require([bool]$Ok,[string]$Message){if(-not $Ok){throw $Message}}
function Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Save-Summary {
    $Summary.elapsed_seconds=[Math]::Round(((Get-Date)-$Start).TotalSeconds,3)
    [IO.File]::WriteAllText((Join-Path $Output 'summary.json'),
      (($Summary|ConvertTo-Json -Depth 28)+[Environment]::NewLine),
      [Text.UTF8Encoding]::new($false))
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
                  [string]$Camera,[string]$Pose,[int]$PixelHz,[int]$RenderHz) {
    $Name="$Family-w$Workers-r$Repeat-$Camera-$Pose-p$PixelHz-r$RenderHz"
    $Dir=Join-Path $Cases $Name
    New-Item -ItemType Directory -Force -Path $Dir|Out-Null
    $Receipt=Join-Path $Dir 'receipt.json'
    $env:APPDATA=Join-Path $Dir 'userdata'
    $env:XDG_DATA_HOME=$env:APPDATA
    $env:CYBERSAND_DIAG_FLYER_POSE=$(if($Pose -eq 'mask'){'mask'}else{''})
    New-Item -ItemType Directory -Force -Path $env:APPDATA|Out-Null
    Write-Host "TEST IT | $Name | real 2048-square World / Needle physics tape" -ForegroundColor Cyan
    $Arguments=@('--rendering-driver',$RenderingDriver,'--rendering-method',
       'gl_compatibility','--audio-driver','Dummy','--max-fps','60',
       '--path',$Project,'--script','res://tests/test_engine_lab_physical_test_it.gd',
       '--','--engine-lab-scripted',"--family=$Family","--workers=$Workers",
       "--repeat=$Repeat","--camera=$Camera","--pose=$Pose",
       "--pixel-hz=$PixelHz","--render-hz=$RenderHz","--receipt=$Receipt")
    Run-Godot $Name $Arguments $TimeoutSeconds $Dir
    Require (Test-Path -LiteralPath $Receipt -PathType Leaf) "$Name did not write a receipt"
    $Data=Get-Content -LiteralPath $Receipt -Raw -Encoding UTF8|ConvertFrom-Json
    $Trace=Join-Path $Dir 'receipt-poses.jsonl'
    Require (Test-Path -LiteralPath $Trace -PathType Leaf) "$Name did not write pose JSONL"
    Require ($Data.complete -eq $true -and $Data.status -eq 'passed') "$Name incomplete"
    Require ($Data.source_sha -eq $Summary.source) "$Name source identity changed"
    Require ($Data.world_size[0] -eq 2048 -and $Data.world_size[1] -eq 2048) "$Name wrong World size"
    Require ($Data.reference.json_sha256 -eq 'b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954') "$Name wrong owner fixture"
    Require ($Data.reference.generated_material_sha256 -eq '71610b37531531e284f069cf1e07c151283a441c9b0ff32a4fcc1dbb6c997a7a') "$Name wrong generated World"
    Require ($Data.reference.native_receipts -eq 256) "$Name missing generation receipts"
    Require ($Data.input_tape.complete -eq $true -and @($Data.input_tape.observed).Count -eq 8) "$Name missed exact physics-tick inputs"
    Require ($Data.native_ticks -gt 0 -and $Data.rapier_steps -ge 24) "$Name no positive native/Rapier progress"
    Require ($Data.trace.frames -gt 0) "$Name missing frame-level diagnostic trace"
    $Row=@{name=$Name;passed=$true;workers=$Workers;family=$Family;camera=$Camera;pose=$Pose
        pixel_target_hz=$PixelHz;render_target_hz=$RenderHz
        actual_native_ticks=$Data.native_ticks;actual_rapier_steps=$Data.rapier_steps
        rendered_pose_frames=$Data.trace.frames;dropped=$Data.trace.dropped
        video_adapter=$Data.video_adapter;receipt_sha256=(Sha $Receipt);trace_sha256=(Sha $Trace)}
    $Summary.cases+=,$Row
    Save-Summary
    Write-Host "PASS $Name - $($Row.rendered_pose_frames) trace frames" -ForegroundColor Green
}
try {
    Require (-not ($Quick -and ($Full -or $Compare)) -and -not ($Full -and $Compare)) 'Select only one test mode'
    Require (Test-Path -LiteralPath $Engine -PathType Leaf) 'Bundled Godot console missing: extract inner ZIP completely'
    Require (Test-Path -LiteralPath $ManifestFile -PathType Leaf) 'PR593-MANIFEST.json missing'
    Require (Test-Path -LiteralPath (Join-Path $Project 'tests\test_engine_lab_physical_test_it.gd')) 'Test It GDScript is absent: use latest pose-test package'
    $Manifest=Get-Content -LiteralPath $ManifestFile -Raw -Encoding UTF8|ConvertFrom-Json
    Require ([string]$Manifest.source_commit -match '^[0-9a-f]{40}$') 'Source SHA not pinned'
    $Summary.source=[string]$Manifest.source_commit
    $env:CYBERSAND_SOURCE_REVISION=$Summary.source
    foreach($HashEntry in $Manifest.files_sha256.PSObject.Properties) {
        $Path=Join-Path $Root ($HashEntry.Name.Replace('/','\'))
        Require (Test-Path -LiteralPath $Path -PathType Leaf) "Missing package payload: $($HashEntry.Name)"
        Require ((Sha $Path) -eq [string]$HashEntry.Value) "Package payload hash drift: $($HashEntry.Name)"
    }
    $Native=Join-Path $Project 'addons\cybersand_native\bin\cybersand_native.windows.x86_64.dll'
    $Rapier=Join-Path $Project 'addons\godot-rapier2d\bin\libgodot_rapier.windows.x86_64-pc-windows-msvc.dll'
    Require ((Sha $Native) -eq $Manifest.native_sha256) 'Native runtime not source-qualified'
    Require ((Sha $Rapier) -eq $Manifest.rapier_sha256) 'Rapier runtime hash drift'
    $Version=(& $Engine --version|Select-Object -First 1).Trim()
    Require ($Version -eq $Manifest.godot_version) 'Godot version not pinned'
    $Summary.godot_version=$Version
    $Summary.gpu=@(Get-CimInstance Win32_VideoController|ForEach-Object{@{name=$_.Name;driver=$_.DriverVersion}})
    $Summary.windows=Get-CimInstance Win32_OperatingSystem|Select-Object Caption,Version,BuildNumber
    Save-Summary
    $env:APPDATA=Join-Path $Output 'import-userdata'
    $env:XDG_DATA_HOME=$env:APPDATA
    New-Item -ItemType Directory -Force -Path $env:APPDATA|Out-Null
    Run-Godot 'import' @('--headless','--path',$Project,'--editor','--quit') 240 $Output
    if($Quick) {
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
    Write-Host "TEST IT PASS: exact reference, eight tick inputs, native/Rapier progression and pose-trace captured." -ForegroundColor Green
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
    try {
        Save-Summary
        Compress-Archive -LiteralPath $Output -DestinationPath $Zip -CompressionLevel Optimal
        Write-Host "EVIDENCE ZIP: $Zip" -ForegroundColor Cyan
        Write-Host ("ZIP SHA-256: "+(Sha $Zip))
    }catch{Write-Warning ("ZIP failed; original evidence preserved at "+$Output+": "+$_.Exception.Message)}
}
if(-not $Summary.complete){exit 1}
exit 0
