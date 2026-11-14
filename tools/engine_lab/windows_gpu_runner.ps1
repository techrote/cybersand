# ENG-LAB-001 / Windows 11 NVIDIA hardware comparison.
# All cases run the same tested native Workbench, Needle, and no-input capture.
[CmdletBinding()]
param([switch]$Smoke, [switch]$AllowOtherAdapter)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).Path
$Engine = Join-Path $Root 'Godot_v4.7-stable_win64_console.exe'
$Project = Join-Path $Root 'godot'
$ManifestPath = Join-Path $Root 'evaluation-manifest.json'
$Source = '50a87a0a11388887a87f38dd11072f8b319756f2'
$Out = Join-Path $Root ('Benchmark-Results\NVIDIA-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID)
New-Item -ItemType Directory -Path $Out -Force | Out-Null
$ReportPath = Join-Path $Out 'summary.json'
$Report = @{
 schema='eng-lab-001-owner-nvidia-v1'; source=$Source
 mode=$(if($Smoke){'smoke'}else{'full'})
 status='incomplete'; complete=$false; cases=@(); order=@()
 created=(Get-Date).ToString('o')
}
$OldAppData=$env:APPDATA
$OldDataHome=$env:XDG_DATA_HOME
$OldSource=$env:CYBERSAND_SOURCE_REVISION
$Started=Get-Date
$First=$null

function Require([bool]$Condition,[string]$Message) {
 if(-not $Condition) { throw $Message }
}
function Hash([string]$File) {
 return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Save-Report {
 $Report.elapsed_seconds=[Math]::Round(((Get-Date)-$Started).TotalSeconds,3)
 [IO.File]::WriteAllText($ReportPath,($Report|ConvertTo-Json -Depth 24)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
}
function Godot-Run([string]$Name,[string[]]$Args,[int]$TimeoutSeconds) {
 $Stdout=Join-Path $Out ($Name+'-stdout.log')
 $Stderr=Join-Path $Out ($Name+'-stderr.log')
 $Process=Start-Process -FilePath $Engine -ArgumentList $Args -PassThru -NoNewWindow -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
 if(-not $Process.WaitForExit($TimeoutSeconds*1000)) {
   try {$Process.Kill()} catch {}
   throw "$Name timed out after $TimeoutSeconds seconds; retained $Stdout and $Stderr"
 }
 if($Process.ExitCode -ne 0) {
   throw "$Name returned exit code $($Process.ExitCode); retained $Stdout and $Stderr"
 }
}
function Run-Case([string]$Family,[int]$Workers,[int]$Repeat) {
 $Name="w$Workers-r$Repeat-$Family"
 $Receipt=Join-Path $Out ($Name+'.json')
 $User=Join-Path $Out ($Name+'-userdata')
 New-Item -ItemType Directory -Path $User -Force|Out-Null
 $env:APPDATA=$User
 $env:XDG_DATA_HOME=$User
 Write-Host "CASE $Name: actual 1024-square World, physical Needle, native Water" -ForegroundColor Cyan
 $Arguments=@('--audio-driver','Dummy','--rendering-method','gl_compatibility',
              '--rendering-driver','opengl3','--max-fps','60',
              '--path',('"' + $Project + '"'),
              '--script','res://tests/bench_engine_lab_water_family.gd','--',
              "--family=$Family","--workers=$Workers","--repeat=$Repeat",
              ('--receipt="' + $Receipt + '"'))
 Godot-Run $Name $Arguments 360
 Require (Test-Path -LiteralPath $Receipt -PathType Leaf) "$Name missing test receipt"
 $Data=Get-Content -LiteralPath $Receipt -Raw -Encoding UTF8 | ConvertFrom-Json
 $B=$Data.benchmark; $I=$B.identity
 $Expected=@{freemass='freemass_v1';pressure='pressure_flow_v1';cellular='cellular_yield_v1';inertial='inertial_cellular_v1'}[$Family]
 $Variant=$(if($Family -eq 'pressure'){'cached_dormant'}else{'reference'})
 $Actual=@($Data.applied_native_policy.assignments|Where-Object {$_.material -eq 3})
 Require ($Data.ok -eq $true -and @($Data.failures).Count -eq 0 -and $B.status -eq 'passed') "$Name source/native benchmark refused or incomplete"
 Require ($Actual.Count -eq 1 -and $Actual[0].applied_family -eq $Expected -and $Actual[0].applied_variant -eq $Variant) "$Name native applied Water differs from request"
 Require ($I.source_revision -eq $Source -and $I.native_runtime_sha256 -eq $script:NativeHash) "$Name source/native runtime identity mismatch"
 Require ($Data.native_worker_request_readback -eq $Workers -and $Data.active_actor_tick -gt 0) "$Name actual native workers/Needle not admitted"
 Require ($B.native_ticks -gt 0 -and $B.rapier_steps -gt 0 -and $B.frame_count -gt 10) "$Name no real physics progression"
 Require ($Data.world_size[0] -eq 1024 -and $Data.world_size[1] -eq 1024) "$Name incorrect World dimensions"
 $Adapter=[string]$I.video_adapter
 Require ($Adapter -ne '' -and $I.rendering_driver -match 'opengl') "$Name driver/adapter unavailable or not native OpenGL"
 if(-not $AllowOtherAdapter) {
   Require ($Adapter -match '(?i)nvidia|geforce|quadro|rtx|gtx') "$Name is NOT reporting an NVIDIA GPU: $Adapter"
 }
 $Current=@{
    name=$Name;family=$Family;workers=$Workers;repeat=$Repeat;passed=$true
    adapter=$Adapter;rendering_driver=$I.rendering_driver
    window=$Data.window_size;fixture_sha256=$Data.fixture_sha256
    source=$I.source_revision;main_sha256=$I.main_script_sha256
    worker_sha256=$I.worker_script_sha256;native_sha256=$I.native_runtime_sha256
    policy_hash=$Data.applied_native_policy.policy_hash
    native_radius=$Data.minimum_native_rule_radius
    native_hz=$B.actual_native_hz;rapier_hz=$B.actual_rapier_hz
    frame_p95_ms=$B.frame_interval_ms.p95;frame_p99_ms=$B.frame_interval_ms.p99
    native_solve_p95_ms=$B.native_completed_tick_cost_ms.p95
    rapier_solve_p95_ms=$B.rapier_completed_step_cost_ms.p95
    render_age_p95_ms=$B.render_payload_age_at_frame_ms.p95
    holds=$B.coupling_held_physics_frames
    raw_receipt=$Name+'.json';raw_receipt_sha256=(Hash $Receipt)
 }
 if($script:First -eq $null) { $script:First=$Current }
 else {
   foreach($Key in @('fixture_sha256','adapter','rendering_driver','source','main_sha256','worker_sha256','native_sha256')) {
     Require ($Current[$Key] -eq $script:First[$Key]) "$Name matched-host identity changed: $Key"
   }
   Require (($Current.window -join ',') -eq ($script:First.window -join ',')) "$Name actual window size changed"
 }
 $Report.cases+=,$Current
 Save-Report
 Write-Host ("PASS {0}: native {1:N2}Hz / Rapier {2:N2}Hz / frame p95 {3:N1}ms" -f $Name,[double]$B.actual_native_hz,[double]$B.actual_rapier_hz,[double]$B.frame_interval_ms.p95) -ForegroundColor Green
}
try {
 Require (Test-Path -LiteralPath $Engine -PathType Leaf) 'Bundled Godot console engine missing'
 Require (Test-Path -LiteralPath $ManifestPath -PathType Leaf) 'Bundle identity manifest missing'
 $M=Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json
 Require ($M.application_commit -eq $Source) 'Application is not qualified immutable source'
 Require ($M.godot.version -eq '4.7.stable.official.5b4e0cb0f' -and (Hash $Engine) -eq $M.godot.console_sha256) 'Bundled Godot version/hash mismatch'
 $Native=Join-Path $Project 'addons\cybersand_native\bin\cybersand_native.windows.x86_64.dll'
 $script:NativeHash=Hash $Native
 $ExpectedNative=$M.native_runtime.cybersand_runtime.'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'.sha256
 Require ($script:NativeHash -eq $ExpectedNative) 'Native runtime hash mismatch'
 $Report.godot_sha256=Hash $Engine
 $Report.native_sha256=$script:NativeHash
 $Report.machine_gpus=@(Get-CimInstance Win32_VideoController | ForEach-Object {@{name=$_.Name;driver=$_.DriverVersion}})
 $env:CYBERSAND_SOURCE_REVISION=$Source
 $env:APPDATA=Join-Path $Out 'import-userdata'
 New-Item -ItemType Directory -Path $env:APPDATA -Force|Out-Null
 Write-Host "Preparing the exact-source Godot 4.7 project..." -ForegroundColor Cyan
 Godot-Run 'import' @('--headless','--path',('"' + $Project + '"'),'--editor','--quit') 240
 $Plan=@()
 if($Smoke) { $Plan+=,@('freemass',1,1) }
 else {
   foreach($W in @(1,4)) {
     $Order=$(if($W -eq 1){@('freemass','pressure','cellular','inertial')}else{@('cellular','inertial','freemass','pressure')})
     foreach($Family in $Order) {$Plan+=,@($Family,$W,1)}
     [array]::Reverse($Order)
     foreach($Family in $Order) {$Plan+=,@($Family,$W,2)}
   }
 }
 $Report.order=@($Plan|ForEach-Object {"w$($_[1])-r$($_[2])-$($_[0])"})
 Save-Report
 foreach($Entry in $Plan) {Run-Case ([string]$Entry[0]) ([int]$Entry[1]) ([int]$Entry[2])}
 Require ($Report.cases.Count -eq $Plan.Count) 'Not every requested arm completed'
 $Report.complete=$true
 $Report.status='passed'
 $Report.notes=@('Real NVIDIA OpenGL, not ANGLE; no GPU busy or scanout measurement',
 'Inertial requires rule radius3, other family arms typically radius2',
 'This is baseline render ACK from #602 ancestry, not the separate #585 gated experiment',
 'Pass certifies the apparatus and positive clock progression, not a preferred Water law')
 Save-Report
 Write-Host "SUCCESS: completed; retain $Out and send summary.json plus w*.json files" -ForegroundColor Green
 exit 0
} catch {
 $Report.complete=$false; $Report.status='incomplete'
 $Report.error=[string]$_.Exception.Message
 Save-Report
 Write-Host ("INCOMPLETE: "+$Report.error) -ForegroundColor Red
 Write-Host "Preserved diagnostic files: $Out"
 exit 1
} finally {
 $env:APPDATA=$OldAppData
 $env:XDG_DATA_HOME=$OldDataHome
 $env:CYBERSAND_SOURCE_REVISION=$OldSource
}