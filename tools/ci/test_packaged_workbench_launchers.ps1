[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Application,
      [Parameter(Mandatory=$true)][string]$Evidence)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Application=[IO.Path]::GetFullPath($Application)
$Evidence=[IO.Path]::GetFullPath($Evidence)
[void][IO.Directory]::CreateDirectory($Evidence)
$Rows=@()
foreach($Name in @('Open Workbench.cmd','Open Publication Control.cmd','Open Full Texture Control.cmd')) {
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
        if($Text -match 'SCRIPT ERROR:|SHADER ERROR:|Parse Error:|Shader compilation failed' -or $Text -notmatch 'WORKBENCH_LAUNCH_READY') {
            throw ('Graphical launcher did not run the production application cleanly: '+$Name)
        }
        $Ready=Get-Content -LiteralPath $Receipt -Raw|ConvertFrom-Json
        $ExpectedBackend=if($Name -eq 'Open Workbench.cmd'){'tiled'}else{'full'}
        $ExpectedPhysics=if($Name -eq 'Open Publication Control.cmd'){'combined'}else{'early'}
        if(-not $Ready.workbench_installed -or $Ready.source -ne $env:CYBERSAND_EVAL_SOURCE_SHA -or
           $Ready.world_generation -lt 0 -or $Ready.uploaded_revision -lt 0 -or $Ready.pending_hard_chunks -ne 0 -or
           $Ready.material_publication.backend -ne $ExpectedBackend -or $Ready.physics_publication -ne $ExpectedPhysics) {
            throw ('Launched Workbench identity or publication mode mismatch: '+$Name)
        }
        $Rows+=@{launcher=$Name;actual_graphical_cmd_exit=$Code;ready=$Ready;
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
    }
}
Write-Host ('WORKBENCH_LAUNCHERS_PASS '+$Rows.Count)
