# ENG-LAB-001 / Windows 11 NVIDIA hardware comparison.
# All cases run the same tested native Workbench, Needle, and no-input capture.
[CmdletBinding()]
param([switch]$Smoke, [switch]$Scripted, [switch]$FullScripted, [switch]$AllowOtherAdapter, [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver='opengl3')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).Path
$Engine = Join-Path $Root 'Godot_v4.7-stable_win64_console.exe'
$Project = Join-Path $Root 'godot'
$ManifestPath = Join-Path $Root 'evaluation-manifest.json'
$Source = (Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).application_commit
$Out = Join-Path $Root ('Benchmark-Results\' + $(if($Scripted){'Test-It-'}else{'NVIDIA-'}) + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID)
New-Item -ItemType Directory -Path $Out -Force | Out-Null
$ReportPath = Join-Path $Out 'summary.json'
$Report = @{
 schema=$(if($Scripted){'eng-lab-scripted-owner-zip-v1'}else{'eng-lab-001-owner-nvidia-v1'}); source=$Source
 mode=$(if($Scripted){$(if($Smoke){'scripted-smoke'}elseif($FullScripted){'scripted-full'}else{'scripted-four-families'})}elseif($Smoke){'smoke'}else{'full'})
 status='incomplete'; complete=$false; cases=@(); order=@()
 created=(Get-Date).ToString('o')
}
$OldAppData=$env:APPDATA
$OldDataHome=$env:XDG_DATA_HOME
$OldSource=$env:CYBERSAND_SOURCE_REVISION
$Started=Get-Date
$First=$null
$ExitStatus=1

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
function Godot-Run([string]$Name,[string[]]$Arguments,[int]$TimeoutSeconds) {
 $Stdout=Join-Path $Out ($Name+'-stdout.log')
 $Stderr=Join-Path $Out ($Name+'-stderr.log')
 # Windows PowerShell 5.1 Start-Process -PassThru sometimes gives an unowned
 # Process proxy whose ExitCode is null or throws 'not started by this object'.
 # Instead create/start the actual .NET Process and pump BOTH pipes concurrently.
 $Info=New-Object System.Diagnostics.ProcessStartInfo
 $Info.FileName=$Engine
 $Info.Arguments=($Arguments -join ' ')
 $Info.WorkingDirectory=$Root
 $Info.UseShellExecute=$false
 $Info.RedirectStandardOutput=$true
 $Info.RedirectStandardError=$true
 $Info.CreateNoWindow=$false
 $Child=New-Object System.Diagnostics.Process
 $Child.StartInfo=$Info
 try {
   Require ([bool]$Child.Start()) "$Name failed to start native Godot executable"
   $OutTask=$Child.StandardOutput.ReadToEndAsync()
   $ErrTask=$Child.StandardError.ReadToEndAsync()
   $Exited=$Child.WaitForExit($TimeoutSeconds*1000)
   if(-not $Exited) {
     try { $Child.Kill() } catch {}
     [void]$Child.WaitForExit(10000)
   }
   [IO.File]::WriteAllText($Stdout,[string]$OutTask.Result,[Text.UTF8Encoding]::new($false))
   [IO.File]::WriteAllText($Stderr,[string]$ErrTask.Result,[Text.UTF8Encoding]::new($false))
   if(-not $Exited) { throw "$Name exceeded $TimeoutSeconds seconds; retained $Stdout and $Stderr" }
   $Code=[int]$Child.ExitCode
   Write-Host ("ENGINE_LAB_PROCESS {0} id={1} exit_code={2}" -f $Name,$Child.Id,$Code)
   if($Code -ne 0) {
     throw "$Name returned exit code $Code; retained $Stdout and $Stderr"
   }
 } finally {
   $Child.Dispose()
 }
}
function Run-Case([string]$Family,[int]$Workers,[int]$Repeat) {
 $Name="w$Workers-r$Repeat-$Family"
 $Receipt=Join-Path $Out ($Name+'.json')
 $User=Join-Path $Out ($Name+'-userdata')
 New-Item -ItemType Directory -Path $User -Force|Out-Null
 $env:APPDATA=$User
 $env:XDG_DATA_HOME=$User
 Write-Host "CASE ${Name}: actual $(if($Scripted){'2048-square scripted'}else{'1024-square passive'}) World, physical Needle, native Water" -ForegroundColor Cyan
 $Arguments=@('--audio-driver','Dummy','--rendering-method','gl_compatibility',
              '--rendering-driver',$RenderingDriver,'--max-fps','60',
              '--path',('"' + $Project + '"'),
              '--script',$(if($Scripted){'res://tests/bench_engine_lab_test_it.gd'}else{'res://tests/bench_engine_lab_water_family.gd'}),'--',
              "--family=$Family","--workers=$Workers","--repeat=$Repeat",
              ('--receipt="' + $Receipt + '"'))
 if($Scripted) { $Arguments += '--engine-lab-scripted' }
 Godot-Run $Name $Arguments $(if($Scripted){900}else{360})
 Require (Test-Path -LiteralPath $Receipt -PathType Leaf) "$Name missing test receipt"
 $Data=Get-Content -LiteralPath $Receipt -Raw -Encoding UTF8 | ConvertFrom-Json
 $B=$Data.benchmark; $I=$B.identity
 $Expected=@{freemass='freemass_v1';pressure='pressure_flow_v1';cellular='cellular_yield_v1';inertial='inertial_cellular_v1'}[$Family]
 $Variant=$(if($Family -eq 'pressure'){'cached_dormant'}else{'reference'})
 $Actual=@($(if($Scripted){$Data.native_solver.applied.assignments}else{$Data.applied_native_policy.assignments})|Where-Object {$_.material -eq 3})
 if($Scripted) {
   Require ($Data.status -eq 'passed' -and @($Data.failures).Count -eq 0 -and $B.status -eq 'passed') "$Name scripted native benchmark refused or incomplete"
   Require ($Data.input_tape.complete -eq $true -and @($Data.input_tape.observed.events).Count -eq 8 -and [string]$Data.input_tape.observed.error -eq '') "$Name physics-tick script was truncated/refused"
   Require ($Data.reference.json_sha256 -eq 'b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954' -and $Data.reference.generated_material_sha256 -eq '71610b37531531e284f069cf1e07c151283a441c9b0ff32a4fcc1dbb6c997a7a' -and $Data.reference.native_receipts -eq 256) "$Name not the verified owner 2048-square source"
 } else {
   Require ($Data.ok -eq $true -and @($Data.failures).Count -eq 0 -and $B.status -eq 'passed') "$Name source/native benchmark refused or incomplete"
 }
 Require ($Actual.Count -eq 1 -and $Actual[0].applied_family -eq $Expected -and $Actual[0].applied_variant -eq $Variant) "$Name native applied Water differs from request"
 Require ($I.source_revision -eq $Source -and $I.native_runtime_sha256 -eq $script:NativeHash) "$Name source/native runtime identity mismatch"
 Require ($Data.native_worker_request_readback -eq $Workers -and $Data.active_actor_tick -gt 0) "$Name actual native workers/Needle not admitted"
 Require ($B.native_ticks -gt 0 -and $B.rapier_steps -gt 0 -and $B.frame_count -gt 10) "$Name no real physics progression"
 $RequiredSize=$(if($Scripted){2048}else{1024})
 Require ($Data.world_size[0] -eq $RequiredSize -and $Data.world_size[1] -eq $RequiredSize) "$Name incorrect World dimensions"
 $Adapter=[string]$I.video_adapter
 Require ($Adapter -ne '' -and $I.rendering_driver -match 'opengl') "$Name driver/adapter unavailable or not native OpenGL"
 if(-not $AllowOtherAdapter) {
   Require ($Adapter -match '(?i)nvidia|geforce|quadro|rtx|gtx') "$Name is NOT reporting an NVIDIA GPU: $Adapter"
 }
 $Current=@{
    name=$Name;family=$Family;workers=$Workers;repeat=$Repeat;passed=$true
    adapter=$Adapter;rendering_driver=$I.rendering_driver
    window=$(if($Scripted){$Data.actual_window}else{$Data.window_size})
    fixture_sha256=$(if($Scripted){$Data.reference.json_sha256}else{$Data.fixture_sha256})
    source=$I.source_revision;main_sha256=$I.main_script_sha256
    worker_sha256=$I.worker_script_sha256;native_sha256=$I.native_runtime_sha256
    policy_hash=$(if($Scripted){$Data.native_solver.applied.policy_hash}else{$Data.applied_native_policy.policy_hash})
    native_radius=$(if($Scripted){$Data.native_solver.minimum_rule_radius}else{$Data.minimum_native_rule_radius})
    input_event_count=$(if($Scripted){@($Data.input_tape.observed.events).Count}else{0})
    input_contract_sha256=$(if($Scripted){$Data.input_tape.contract_sha256}else{''})
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
 $ExpectedNative=$M.native_runtime.cybersand_runtime.sha256
 Require ($script:NativeHash -eq $ExpectedNative) 'Native runtime hash mismatch'
 if($Scripted) {
   $Ref=Join-Path $Project 'tests\fixtures\engine_lab\setup-gate-canvas.json'
   Require ((Hash $Ref) -eq 'b001849d0823b9a1c3fdff7a650d455945eb1ebb885004e9836ee7525ce1b954') 'Installed source gate canvas differs from owner-provided JSON'
   Copy-Item -LiteralPath $Ref -Destination (Join-Path $Out 'setup-gate-canvas.json')
 }
 $Report.godot_sha256=Hash $Engine
 $Report.requested_driver=$RenderingDriver
 $Report.native_sha256=$script:NativeHash
 $Report.machine_gpus=@(Get-CimInstance Win32_VideoController | ForEach-Object {@{name=$_.Name;driver=$_.DriverVersion}})
 $env:CYBERSAND_SOURCE_REVISION=$Source
 $env:APPDATA=Join-Path $Out 'import-userdata'
 New-Item -ItemType Directory -Path $env:APPDATA -Force|Out-Null
 Write-Host "Preparing the exact-source Godot 4.7 project..." -ForegroundColor Cyan
 Godot-Run 'import' @('--headless','--path',('"' + $Project + '"'),'--editor','--quit') 240
 $Plan=@()
 if($Smoke) { $Plan+=,@('freemass',1,1) }
 elseif($Scripted -and -not $FullScripted) {
   $Order=@('freemass','pressure','cellular','inertial')
   foreach($Family in $Order) {$Plan+=,@($Family,1,1)}
   [array]::Reverse($Order)
   foreach($Family in $Order) {$Plan+=,@($Family,1,2)}
 } else {
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
 $Report.notes=@('Scripted Test It drives the same admitted Needle command path at fixed completed physics ticks; no human timing variance', 'Real NVIDIA OpenGL, not ANGLE; no GPU busy or scanout measurement',
 'Inertial requires rule radius3, other family arms typically radius2',
 'This is baseline render ACK from #602 ancestry, not the separate #585 gated experiment',
 'Pass certifies the apparatus and positive clock progression, not a preferred Water law')
 Save-Report
 Write-Host "SUCCESS: measurements complete; sealing one evidence ZIP." -ForegroundColor Green
 $ExitStatus=0
} catch {
 $Report.complete=$false; $Report.status='incomplete'
 $Report.error=[string]$_.Exception.Message
 Save-Report
 Write-Host ("INCOMPLETE: "+$Report.error) -ForegroundColor Red
 Write-Host "Preserved diagnostic files: $Out"
 $ExitStatus=1
} finally {
 if($Scripted) {
   # ZIP lives NEXT TO, not inside, the run folder. Successful and failed
   # campaigns both become one portable evidence bundle, including raw inputs.
   try {
     Add-Type -AssemblyName System.IO.Compression
     Add-Type -AssemblyName System.IO.Compression.FileSystem
     $Zip=Join-Path (Split-Path -Parent $Out) ((Split-Path -Leaf $Out)+'.zip')
     if(Test-Path -LiteralPath $Zip) {throw 'Cannot overwrite Test It evidence ZIP'}
     # Only portable evidence goes in the single ZIP. Ignore per-process
     # sandbox userdata and Godot import caches; never leak local user files.
     $Archive=[IO.Compression.ZipFile]::Open($Zip,[IO.Compression.ZipArchiveMode]::Create)
     try {
       foreach($Entry in (Get-ChildItem -LiteralPath $Out -File | Sort-Object Name)) {
         [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,$Entry.FullName,$Entry.Name,[IO.Compression.CompressionLevel]::Optimal)
       }
     } finally { $Archive.Dispose() }
     Write-Host "TEST_IT_RESULT_ZIP $Zip" -ForegroundColor Green
     Write-Host "ZIP_SHA256 $(Hash $Zip)"
   } catch {
     $ExitStatus=1
     $Report.complete=$false
     $Report.status='incomplete'
     $Report.error="Evidence ZIP creation/refusal: "+$_.Exception.Message
     Save-Report
     if($Zip -and (Test-Path -LiteralPath $Zip)) { Remove-Item -LiteralPath $Zip -Force }
     Write-Host ("TEST_IT_ZIP_FAILED: "+$_.Exception.Message) -ForegroundColor Red
   }
 }
 $env:APPDATA=$OldAppData
 $env:XDG_DATA_HOME=$OldDataHome
 $env:CYBERSAND_SOURCE_REVISION=$OldSource
}
exit $ExitStatus