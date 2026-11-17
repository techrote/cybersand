[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Application,
      [Parameter(Mandatory=$true)][string]$Evidence)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Application=[IO.Path]::GetFullPath($Application)
$Evidence=[IO.Path]::GetFullPath($Evidence)
[void][IO.Directory]::CreateDirectory($Evidence)
$Rows=@()
# Inject probe-only overrides into the invoked cmd process, never this caller.
# The actual package launchers must select the reviewed source defaults.
$InheritedSelectors=@{CYBERSAND_DIAG_MATERIAL_STAGING_SLOTS='1';CYBERSAND_DIAG_MATERIAL_HISTORY_TARGETS='3'
    CYBERSAND_DIAG_MATERIAL_COPY_MODE='tiles';CYBERSAND_DIAG_COMMON_OBSERVER='1';CYBERSAND_DIAG_NATIVE_RENDEZVOUS='1'}
$CallerSelectors=@{}
foreach($Key in $InheritedSelectors.Keys){$CallerSelectors[$Key]=[Environment]::GetEnvironmentVariable($Key,'Process')}
$SelectorProbe=@{injected_child_environment=$InheritedSelectors;caller_environment=$CallerSelectors
    scope='Actual graphical cmd launchers; child-scoped overrides leave the caller unchanged'}
$SelectorProbe|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $Evidence 'inherited-selector-probe.json') -Encoding UTF8
foreach($Name in @('Open Workbench.cmd','Open Publication Control.cmd','Open Full Texture Control.cmd',
                  'Open Safe Renderer Control.cmd','Open Separate Renderer Control.cmd')) {
    $Label=$Name.Replace(' ','-')
    $Log=Join-Path $Evidence ($Label+'.log')
    $Receipt=Join-Path $Evidence ($Label+'-ready.json')
    $Profile=Join-Path $Evidence ($Label+'-profile')
    [void][IO.Directory]::CreateDirectory($Profile)
    $Info=New-Object System.Diagnostics.ProcessStartInfo
    $Info.FileName=$env:ComSpec
    $Info.Arguments='/d /s /c ""'+(Join-Path $Application $Name)+'" --rendering-driver opengl3_angle --audio-driver Dummy --log-file "'+$Log+'""'
    $Info.WorkingDirectory=$Application
    $Info.UseShellExecute=$false
    $Info.RedirectStandardOutput=$true
    $Info.RedirectStandardError=$true
    # start /wait retains the graphical child's actual exit code and avoids a
    # race with short-lived processes. The invoked cmd, engine and app are real.
    $Info.EnvironmentVariables['CYBERSAND_LAUNCH_TEST_WAIT']='1'
    $Info.EnvironmentVariables['CYBERSAND_LAUNCH_READY_RECEIPT']=$Receipt
    $Info.EnvironmentVariables['CYBERSAND_LAUNCH_QUIT_AFTER_READY']='1'
    $Info.EnvironmentVariables['APPDATA']=$Profile
    $Info.EnvironmentVariables['XDG_DATA_HOME']=$Profile
    foreach($Key in $InheritedSelectors.Keys){$Info.EnvironmentVariables[$Key]=$InheritedSelectors[$Key]}
    $Launcher=New-Object System.Diagnostics.Process
    $Launcher.StartInfo=$Info
    $Stdout=$null;$Stderr=$null;$Started=$false
    try {
        $Started=$Launcher.Start()
        if(-not $Started){throw ('Launcher refused: '+$Name)}
        $Stdout=$Launcher.StandardOutput.ReadToEndAsync()
        $Stderr=$Launcher.StandardError.ReadToEndAsync()
        if(-not $Launcher.WaitForExit(300000)){throw ('Actual launcher or Workbench readiness timed out: '+$Name)}
        $Code=$Launcher.ExitCode
        if($Code -ne 0 -or -not (Test-Path -LiteralPath $Log) -or -not (Test-Path -LiteralPath $Receipt)) {
            throw ('Actual graphical launcher failed or did not install Workbench: '+$Name)
        }
        $Text=Get-Content -LiteralPath $Log -Raw
        if($Text -match 'SCRIPT ERROR:|SHADER ERROR:|Parse Error:|Shader compilation failed|Error initializing GLAD|glXMakeCurrent failed|wglMakeCurrent failed|Unhandled XServer error|Failed to create (native |ANGLE )?OpenGL window|Could not set V-Sync mode\.' -or $Text -notmatch 'WORKBENCH_LAUNCH_READY') {
            throw ('Graphical launcher did not run the production application cleanly: '+$Name)
        }
        $Ready=Get-Content -LiteralPath $Receipt -Raw|ConvertFrom-Json
        $ExpectedBackend=if($Name -in @('Open Publication Control.cmd','Open Full Texture Control.cmd')){'full'}else{'blit'}
        $ExpectedPhysics=if($Name -eq 'Open Publication Control.cmd'){'combined'}else{'early'}
        $ExpectedSeparate=$Name -notin @('Open Publication Control.cmd','Open Safe Renderer Control.cmd')
        $ExpectedRendezvous=if($Name -in @('Open Workbench.cmd','Open Full Texture Control.cmd')){'render-overlap'}else{'off'}
        $ExpectedEnabled=$ExpectedRendezvous -eq 'render-overlap'
        $ExpectedCap=if($ExpectedEnabled){66667}else{16667}
        $Delta=$Ready.native_rendezvous.fixed_physics_delta
        if(($Delta -isnot [int] -and $Delta -isnot [long] -and $Delta -isnot [single] -and
            $Delta -isnot [double] -and $Delta -isnot [decimal]) -or
           [double]::IsNaN([double]$Delta) -or [double]::IsInfinity([double]$Delta)) {
            throw ('Launched Workbench fixed timestep is not finite numeric data: '+$Name)
        }
        if($Ready.workbench_installed -isnot [bool] -or -not $Ready.workbench_installed -or
           $Ready.native_rendezvous.enabled -isnot [bool] -or $Ready.native_rendezvous.separate_render_thread -isnot [bool] -or
           $Ready.native_rendezvous.waits_for_native_sample -isnot [bool] -or -not $Ready.native_rendezvous.waits_for_native_sample -or
           $Ready.source -ne $env:CYBERSAND_EVAL_SOURCE_SHA -or
           $Ready.world_generation -lt 0 -or $Ready.uploaded_revision -lt 0 -or $Ready.pending_hard_chunks -ne 0 -or
           $Ready.material_publication.backend -ne $ExpectedBackend -or $Ready.physics_publication -ne $ExpectedPhysics -or
           $Ready.native_rendezvous.mode -ne $ExpectedRendezvous -or $Ready.native_rendezvous.enabled -ne $ExpectedEnabled -or
           $Ready.native_rendezvous.separate_render_thread -ne $ExpectedSeparate -or
           $Ready.native_rendezvous.render_overlap_available -isnot [bool] -or
           $Ready.native_rendezvous.render_overlap_available -ne ($ExpectedEnabled -and $ExpectedSeparate) -or
           $Ready.native_rendezvous.max_frame_wait_usec -ne $ExpectedCap -or
           $Ready.native_rendezvous.poll_usec -ne 250 -or
           [math]::Abs([double]$Ready.native_rendezvous.fixed_physics_delta-(1.0/60.0)) -gt 0.000000001 -or
           $Ready.physics_required -ne ($Ready.authored_actor_count -gt 0) -or
           ($Ready.physics_required -and -not $Ready.rapier_initialized)) {
            throw ('Launched Workbench identity or publication mode mismatch: '+$Name)
        }
        if($ExpectedBackend -eq 'blit' -and
           ($Ready.material_publication.staging_slots -ne 3 -or $Ready.material_publication.copy_mode -ne 'runs')) {
            throw 'Ordinary launcher retained an inherited material probe selector'
        }
        $Rows+=@{launcher=$Name;actual_graphical_cmd_exit=$Code;ready=$Ready;injected_child_environment=$InheritedSelectors;
            log_sha256=(Get-FileHash -LiteralPath $Log -Algorithm SHA256).Hash.ToLowerInvariant()}
        $Rows|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $Evidence 'launchers.json') -Encoding UTF8
    } finally {
        if($Started -and -not $Launcher.HasExited) {
            & taskkill.exe /PID $Launcher.Id /T /F | Out-Null
            [void]$Launcher.WaitForExit(10000)
        }
        if($null -ne $Stdout -and $null -ne $Stderr) {
            [IO.File]::WriteAllText((Join-Path $Evidence ($Label+'-cmd.log')),
                ($Stdout.Result+[Environment]::NewLine+$Stderr.Result))
        }
        $Launcher.Dispose()
        foreach($Key in $InheritedSelectors.Keys) {
            if(-not [object]::Equals([Environment]::GetEnvironmentVariable($Key,'Process'),$CallerSelectors[$Key])) {
                throw ('Launcher gate changed its caller environment: '+$Key)
            }
        }
    }
}
Write-Host ('WORKBENCH_LAUNCHERS_PASS '+$Rows.Count)
