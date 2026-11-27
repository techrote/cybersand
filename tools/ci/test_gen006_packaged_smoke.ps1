[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Output)

# This is a shell/receipt regression test, not native CyberSand qualification.
# Exercise the actual packaged script under Windows PowerShell 5.1: its treatment
# of redirected native stderr differs from PowerShell 7.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Run this regression with Windows powershell.exe 5.1.'
}
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputPath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $outputPath) { throw 'Regression output must be a new directory.' }
New-Item -ItemType Directory -Path $outputPath | Out-Null
$shell = Join-Path $PSHOME 'powershell.exe'
$packageScript = Join-Path $root 'tools\package_gen006_persistent_areas.py'
$smokeSource = Join-Path $outputPath 'actual-packaged-smoke.ps1'
$extractor = @'
import ast
from pathlib import Path
import sys
tree = ast.parse(Path(sys.argv[1]).read_text(encoding="utf-8"))
matches = [node.value for node in tree.body if isinstance(node, ast.Assign)
           and any(isinstance(target, ast.Name) and target.id == "SMOKE"
                   for target in node.targets)]
assert len(matches) == 1
value = ast.literal_eval(matches[0])
assert isinstance(value, str)
Path(sys.argv[2]).write_text(value, encoding="utf-8-sig")
'@
$extractorPath = Join-Path $outputPath 'extract-packaged-smoke.py'
[IO.File]::WriteAllText($extractorPath, $extractor)
& python $extractorPath $packageScript $smokeSource
if ($LASTEXITCODE -ne 0) { throw 'Could not extract the actual packaged smoke script.' }

$stubSource = @'
using System;
using System.Diagnostics;
using System.IO;

public static class Gen006PackagedSmokeStub {
    private static int Main(string[] args) {
        string scenario = Environment.GetEnvironmentVariable("GEN006_SMOKE_STUB_CASE");
        string trace = Environment.GetEnvironmentVariable("GEN006_SMOKE_STUB_TRACE");
        string mode = "import";
        string evidence = null;
        foreach (string arg in args) {
            if (arg.StartsWith("--persistent-test-mode="))
                mode = arg.Substring("--persistent-test-mode=".Length);
            if (arg.StartsWith("--persistent-evidence="))
                evidence = arg.Substring("--persistent-evidence=".Length);
        }
        int pid = Process.GetCurrentProcess().Id;
        File.AppendAllText(trace, mode + " " + pid + Environment.NewLine);
        Console.WriteLine("GEN006_SHELL_STUB " + scenario + " " + mode + " pid=" + pid);
        if (scenario == "warning-stderr" || scenario == "warning-nonzero") {
            Console.Error.WriteLine("WARNING: Your video card drivers seem not to support OpenGL 3.3; switching to ANGLE.");
        }
        if (mode == "import") return 0;
        if (mode != "write" && mode != "reopen") return 97;
        if (String.IsNullOrEmpty(evidence) || !Directory.Exists(evidence)) return 98;
        if (scenario == "nonzero-exit" || scenario == "warning-nonzero") return 7;
        if (scenario == "script-error") Console.Error.WriteLine("SCRIPT ERROR: deliberate shell regression marker");
        if (scenario == "engine-error") Console.WriteLine("ERROR: deliberate shell regression marker");
        if (scenario == "missing-receipt") return 0;
        string assertions = scenario == "invalid-assertions" ? "\"12\"" :
                            scenario == "zero-assertions" ? "0" : "12";
        string graphical = scenario == "not-graphical" ? "false" : "true";
        string failures = scenario == "receipt-failure" ? "[\"deliberate failure\"]" : "[]";
        int receiptPid = scenario == "reused-pid" ? 42 : pid;
        string json = "{\"assertions\":" + assertions + ",\"graphical\":" + graphical +
                      ",\"failures\":" + failures + ",\"process_id\":" + receiptPid + "}";
        File.WriteAllText(Path.Combine(evidence, "workbench-" + mode + ".json"), json);
        return 0;
    }
}
'@
$stubSourcePath = Join-Path $outputPath 'console-stub.cs'
[IO.File]::WriteAllText($stubSourcePath, $stubSource)
$stubExe = Join-Path $outputPath 'console-stub.exe'
Add-Type -TypeDefinition $stubSource -OutputAssembly $stubExe -OutputType ConsoleApplication

$cases = @(
    @{ name = 'clean-success'; pass = $true; modes = 'import,write,reopen' },
    @{ name = 'warning-stderr'; pass = $true; modes = 'import,write,reopen' },
    @{ name = 'warning-nonzero'; pass = $false; modes = 'import,write' },
    @{ name = 'nonzero-exit'; pass = $false; modes = 'import,write' },
    @{ name = 'script-error'; pass = $false; modes = 'import,write' },
    @{ name = 'engine-error'; pass = $false; modes = 'import,write' },
    @{ name = 'missing-receipt'; pass = $false; modes = 'import,write' },
    @{ name = 'invalid-assertions'; pass = $false; modes = 'import,write' },
    @{ name = 'zero-assertions'; pass = $false; modes = 'import,write' },
    @{ name = 'not-graphical'; pass = $false; modes = 'import,write' },
    @{ name = 'receipt-failure'; pass = $false; modes = 'import,write' },
    @{ name = 'reused-pid'; pass = $false; modes = 'import,write,reopen' },
    @{ name = 'missing-executable'; pass = $false; modes = '' }
)
$rows = @()
$savedScenario = $env:GEN006_SMOKE_STUB_CASE
$savedTrace = $env:GEN006_SMOKE_STUB_TRACE
try {
    foreach ($case in $cases) {
        $casePath = Join-Path $outputPath ('case with spaces ' + $case.name)
        New-Item -ItemType Directory -Path $casePath | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $casePath 'godot') | Out-Null
        $script = Join-Path $casePath 'Run Automated Smoke.ps1'
        Copy-Item -LiteralPath $smokeSource -Destination $script
        if ($case.name -ne 'missing-executable') {
            Copy-Item -LiteralPath $stubExe -Destination (Join-Path $casePath 'Godot_v4.7-stable_win64_console.exe')
        }
        $stdout = Join-Path $casePath 'child-stdout.log'
        $stderr = Join-Path $casePath 'child-stderr.log'
        $tracePath = Join-Path $casePath 'executed-processes.txt'
        $env:GEN006_SMOKE_STUB_CASE = $case.name
        $env:GEN006_SMOKE_STUB_TRACE = $tracePath
        $watch = [Diagnostics.Stopwatch]::StartNew()
        # Redirect to files in the OS process API, avoiding this test runner's
        # own PowerShell error-stream interpretation of the expected failures.
        $process = Start-Process -FilePath $shell -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $script + '"')) `
            -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        [void]$process.Handle
        $completed = $process.WaitForExit(45000)
        if (!$completed) { $process.Kill() }
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        $watch.Stop()
        $text = [IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr)
        $markerCount = [regex]::Matches($text, '(?m)^GEN006_PACKAGED_GRAPHICAL_SMOKE_PASS ').Count
        $traceRows = @()
        if (Test-Path -LiteralPath $tracePath) { $traceRows = @(Get-Content -LiteralPath $tracePath) }
        $observedModes = (@($traceRows | ForEach-Object { ($_ -split ' ')[0] }) -join ',')
        $observedPids = @($traceRows | ForEach-Object { [int](($_ -split ' ')[1]) })
        $writeReopenPids = @($traceRows | Where-Object { $_ -match '^(write|reopen) ' } |
            ForEach-Object { [int](($_ -split ' ')[1]) })
        # The product's restart claim concerns write/reopen. A short-lived
        # import process may legitimately have its PID reused by Windows.
        $writeReopenDistinct = @($writeReopenPids | Select-Object -Unique).Count -eq $writeReopenPids.Count
        $accepted = $completed -and $null -ne $exitCode -and $exitCode -eq 0 -and $markerCount -eq 1
        $refused = $completed -and $null -ne $exitCode -and $exitCode -ne 0 -and $markerCount -eq 0
        $passed = (($case.pass -and $accepted) -or (!$case.pass -and $refused)) -and
                  $observedModes -eq $case.modes -and $writeReopenDistinct
        $warningRetained = $null
        if ($case.name -eq 'warning-stderr') {
            $nativeLogs = @(Get-ChildItem -LiteralPath (Join-Path $casePath 'smoke') -Recurse -Filter '*.log')
            $warningRetained = $nativeLogs.Count -eq 3
            foreach ($log in $nativeLogs) {
                if ([IO.File]::ReadAllText($log.FullName) -notmatch 'switching to ANGLE') { $warningRetained = $false }
            }
            $passed = $passed -and $warningRetained
        }
        $row = [ordered]@{
            name = $case.name; status = $(if ($passed) { 'passed' } else { 'failed' })
            expected_acceptance = $case.pass; completed = $completed; exit_code = $exitCode
            pass_marker_count = $markerCount; elapsed_ms = $watch.ElapsedMilliseconds
            expected_modes = $case.modes; observed_modes = $observedModes
            subprocess_ids = $observedPids; distinct_write_reopen_subprocesses = $writeReopenDistinct
            warning_retained_in_all_native_logs = $warningRetained
            stdout = $stdout; stderr = $stderr
        }
        $rows += $row
        Write-Output ('GEN006_PACKAGED_SMOKE_GUARD ' + $case.name + ' ' + $row.status)
    }
} finally {
    $env:GEN006_SMOKE_STUB_CASE = $savedScenario
    $env:GEN006_SMOKE_STUB_TRACE = $savedTrace
}
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($smokeSource, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Actual packaged smoke has PowerShell parse errors.' }
$helpers = @($ast.FindAll({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-LoggedGodot'
}, $true))
if ($helpers.Count -ne 1) { throw 'Actual packaged smoke helper is missing or ambiguous.' }
# Load the function's actual parsed extent, without executing or rewriting the
# smoke's top-level import/receipt loop. Probe failure cleanup independently.
Invoke-Expression $helpers[0].Extent.Text
$helperRows = @()
try {
    foreach ($name in @('success-preference', 'error-preference', 'missing-after-import', 'unwritable-log')) {
        $helperPath = Join-Path $outputPath ('helper with spaces ' + $name)
        New-Item -ItemType Directory -Path $helperPath | Out-Null
        $engine = Join-Path $helperPath 'native stub.exe'
        Copy-Item -LiteralPath $stubExe -Destination $engine
        $env:GEN006_SMOKE_STUB_TRACE = Join-Path $helperPath 'executed-processes.txt'
        $env:GEN006_SMOKE_STUB_CASE = 'warning-stderr'
        $ErrorActionPreference = 'Stop'
        $caught = $null
        $passed = $false
        $log = Join-Path $helperPath 'native.log'
        try {
            if ($name -eq 'success-preference') {
                $nativeText = @(Invoke-LoggedGodot -GodotArguments @('--headless') -LogPath $log -Label 'Probe import') -join "`n"
                $logged = [IO.File]::ReadAllText($log)
                $passed = $nativeText -match 'switching to ANGLE' -and $logged -match 'switching to ANGLE' -and
                          $logged -match 'GEN006_SHELL_STUB' -and $global:LASTEXITCODE -eq 0
            } elseif ($name -eq 'error-preference') {
                $env:GEN006_SMOKE_STUB_CASE = 'nonzero-exit'
                try {
                    Invoke-LoggedGodot -GodotArguments @('--persistent-test-mode=write', ('--persistent-evidence=' + $helperPath)) `
                        -LogPath $log -Label 'Probe native failure' | Out-Null
                } catch { $caught = $_.ToString() }
                $passed = $null -ne $caught -and $caught -match 'exit 7' -and $global:LASTEXITCODE -eq 7
            } elseif ($name -eq 'missing-after-import') {
                Invoke-LoggedGodot -GodotArguments @('--headless') -LogPath (Join-Path $helperPath 'import.log') `
                    -Label 'Probe successful import' | Out-Null
                $zeroBefore = $global:LASTEXITCODE -eq 0
                Remove-Item -LiteralPath $engine
                try {
                    Invoke-LoggedGodot -GodotArguments @('--headless') -LogPath $log -Label 'Probe missing executable' | Out-Null
                } catch { $caught = $_.ToString() }
                $passed = $zeroBefore -and $null -ne $caught -and $null -eq $global:LASTEXITCODE
            } else {
                New-Item -ItemType Directory -Path $log | Out-Null
                try {
                    Invoke-LoggedGodot -GodotArguments @('--headless') -LogPath $log -Label 'Probe unwritable log' | Out-Null
                } catch { $caught = $_.ToString() }
                $passed = $null -ne $caught -and [IO.Directory]::Exists($log)
            }
        } catch { $caught = $_.ToString(); $passed = $false }
        $restored = $ErrorActionPreference -eq 'Stop'
        $passed = $passed -and $restored
        $helperRows += [ordered]@{
            name = $name; status = $(if ($passed) { 'passed' } else { 'failed' })
            preference_restored = $restored; caught = $caught
        }
        Write-Output ('GEN006_PACKAGED_SMOKE_HELPER ' + $name + ' ' + $(if ($passed) { 'passed' } else { 'failed' }))
    }
} finally {
    $env:GEN006_SMOKE_STUB_CASE = $savedScenario
    $env:GEN006_SMOKE_STUB_TRACE = $savedTrace
}
$failed = @($rows | Where-Object { $_.status -ne 'passed' }) + @($helperRows | Where-Object { $_.status -ne 'passed' })
$report = [ordered]@{
    schema = 'gen006-packaged-smoke-shell-regression-v1'
    status = $(if ($failed.Count -eq 0 -and $rows.Count -eq $cases.Count -and $helperRows.Count -eq 4) { 'passed' } else { 'failed' })
    scope = 'Windows PowerShell native stderr, exit status and receipt validation; stub processes, not native CyberSand simulation.'
    powershell_version = $PSVersionTable.PSVersion.ToString()
    powershell_edition = $PSVersionTable.PSEdition
    package_script_sha256 = (Get-FileHash -LiteralPath $packageScript -Algorithm SHA256).Hash.ToLowerInvariant()
    extracted_smoke_sha256 = (Get-FileHash -LiteralPath $smokeSource -Algorithm SHA256).Hash.ToLowerInvariant()
    stub_source_sha256 = (Get-FileHash -LiteralPath $stubSourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    stub_executable_sha256 = (Get-FileHash -LiteralPath $stubExe -Algorithm SHA256).Hash.ToLowerInvariant()
    cases = $rows
    helper_probes = $helperRows
}
[IO.File]::WriteAllText((Join-Path $outputPath 'results.json'), ($report | ConvertTo-Json -Depth 10))
if ($report.status -ne 'passed') { throw 'Packaged smoke shell regression failed; inspect retained results.json and child logs.' }
Write-Output ('GEN006_PACKAGED_SMOKE_GUARDS_PASS cases=' + $rows.Count + ' helper_probes=' + $helperRows.Count)
