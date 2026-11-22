[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Output)

# Execute the actual imported RAM_SMOKE under Windows PowerShell 5.1. These
# deliberately small stub processes test shell/PID/receipt custody, not native
# CyberSand simulation, graphical rendering or physical owner acceptance.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Run this regression with Windows powershell.exe 5.1.'
}
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputPath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $outputPath) { throw 'Regression output must be a new directory.' }
New-Item -ItemType Directory -Path $outputPath | Out-Null
$shell = Join-Path $PSHOME 'powershell.exe'
$packageScript = Join-Path $root 'tools\package_gen006_ramcache.py'
$smokeSource = Join-Path $outputPath 'actual-packaged-ramcache-smoke.ps1'
$extractor = @'
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys
path = Path(sys.argv[1])
spec = spec_from_file_location("actual_ramcache_package", path)
module = module_from_spec(spec)
spec.loader.exec_module(module)
assert isinstance(module.RAM_SMOKE, str)
Path(sys.argv[2]).write_text(module.RAM_SMOKE, encoding="utf-8-sig")
'@
$extractorPath = Join-Path $outputPath 'extract-packaged-ramcache-smoke.py'
[IO.File]::WriteAllText($extractorPath, $extractor)
& python $extractorPath $packageScript $smokeSource
if ($LASTEXITCODE -ne 0) { throw 'Could not import the actual packaged RAM smoke script.' }
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($smokeSource, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Actual packaged RAM smoke has PowerShell parse errors.' }

$stubSource = @'
using System;
using System.Diagnostics;
using System.IO;

public static class Gen006RamcachePackagedSmokeStub {
    private static int Main(string[] args) {
        string scenario = Environment.GetEnvironmentVariable("GEN006_RAMCACHE_SMOKE_STUB_CASE");
        string trace = Environment.GetEnvironmentVariable("GEN006_RAMCACHE_SMOKE_STUB_TRACE");
        string root = Environment.GetEnvironmentVariable("GEN006_RAMCACHE_SMOKE_STUB_ROOT");
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
        Console.WriteLine("GEN006_RAMCACHE_SHELL_STUB " + scenario + " " + mode + " pid=" + pid);
        if (scenario == "warning-stderr" || scenario == "warning-nonzero")
            Console.Error.WriteLine("WARNING: Your video card drivers seem not to support OpenGL 3.3; switching to ANGLE.");
        if (mode == "import") return 0;
        if (mode != "write" && mode != "reopen") return 97;
        if (String.IsNullOrEmpty(evidence) || !Directory.Exists(evidence)) return 98;
        if (scenario == "nonzero-exit" || scenario == "warning-nonzero") return 7;
        if (scenario == "script-error") Console.Error.WriteLine("SCRIPT ERROR: deliberate shell regression marker");
        if (scenario == "engine-error") Console.WriteLine("ERROR: deliberate shell regression marker");
        string assertions = scenario == "invalid-assertions" ? "\"12\"" :
                            scenario == "zero-assertions" ? "0" : "12";
        string checks = scenario == "invalid-checks" ? "\"30\"" :
                        scenario == "zero-checks" ? "0" : "30";
        string graphical = scenario == "not-graphical" ? "false" : "true";
        string failures = scenario == "receipt-failure" ? "[\"deliberate failure\"]" : "[]";
        int baselinePid = scenario == "fake-baseline-pid" || scenario == "reused-pid" ? 42 : pid;
        int cachePid = scenario == "fake-ramcache-pid" || scenario == "reused-pid" ? 42 : pid;
        string baselineMode = scenario == "wrong-baseline-mode" ? "not-the-requested-mode" : mode;
        string cacheMode = scenario == "wrong-ramcache-mode" ? "not-the-requested-mode" : mode;
        string workbench = "{\"assertions\":" + assertions + ",\"graphical\":" + graphical +
              ",\"failures\":" + failures + ",\"process_id\":" + baselinePid + ",\"mode\":\"" + baselineMode + "\"}";
        int hotCount = mode == "reopen" ? 0 : scenario == "wrong-hot-count" ? 2 : 3;
        int warmCount = mode == "reopen" ? 0 : scenario == "wrong-warm-count" ? 2 : 3;
        string hot = hotCount == 0 ? "[]" : hotCount == 2 ? "[{},{}]" : "[{},{},{}]";
        string warm = warmCount == 0 ? "[]" : warmCount == 2 ? "[{},{}]" : "[{},{},{}]";
        int prefetch = scenario == "missing-prefetch" || mode == "reopen" ? 0 : 1;
        int saves = scenario == "missing-writeback" || mode == "reopen" ? 0 : 1;
        string cache = "{\"schema\":\"gen006-ramcache-workbench-v1\",\"checks\":" + checks +
              ",\"graphical\":" + graphical + ",\"failures\":" + failures + ",\"process_id\":" + cachePid +
              ",\"mode\":\"" + cacheMode + "\",\"hot_samples\":" + hot + ",\"warm_samples\":" + warm +
              ",\"evidence\":{\"cache_io\":{\"prefetch_hits\":" + prefetch + ",\"background_publications\":" + saves + "}}}";
        if (scenario != "missing-baseline-receipt")
            File.WriteAllText(Path.Combine(evidence, "workbench-" + mode + ".json"), workbench);
        if (scenario != "missing-ramcache-receipt")
            File.WriteAllText(Path.Combine(evidence, "ramcache-" + mode + ".json"), cache);
        if (scenario == "changed-native")
            File.AppendAllText(Path.Combine(root, "godot", "addons", "cybersand_native", "bin", "cybersand_native.windows.x86_64.dll"), "changed");
        if (scenario == "changed-manifest")
            File.AppendAllText(Path.Combine(root, "evaluation-manifest.json"), " ");
        int markerPid = scenario == "wrong-marker-pid" ? 42 : pid;
        string markerMode = scenario == "wrong-marker-mode" ? "not-the-requested-mode" : mode;
        int markerChecks = scenario == "wrong-marker-count" ? 30 : 31;
        string markerFailures = scenario == "failed-marker" ? "[\"failed marker\"]" : "[]";
        string marker = "GEN006_RAMCACHE {\"checks\":" + markerChecks + ",\"failures\":" + markerFailures +
              ",\"graphical\":true,\"pid\":" + markerPid + ",\"mode\":\"" + markerMode +
              "\",\"hot_samples\":" + hotCount + ",\"warm_samples\":" + warmCount + "}";
        if (scenario != "missing-marker") Console.WriteLine(marker);
        if (scenario == "duplicate-marker") Console.WriteLine(marker);
        return 0;
    }
}
'@
$stubSourcePath = Join-Path $outputPath 'direct-engine-stub.cs'
[IO.File]::WriteAllText($stubSourcePath, $stubSource)
$stubExe = Join-Path $outputPath 'direct-engine-stub.exe'
Add-Type -TypeDefinition $stubSource -OutputAssembly $stubExe -OutputType ConsoleApplication

$cases = @(
    @{ name = 'clean-success'; pass = $true; modes = 'import,write,reopen' },
    @{ name = 'warning-stderr'; pass = $true; modes = 'import,write,reopen' },
    @{ name = 'warning-nonzero'; pass = $false; modes = 'import,write' },
    @{ name = 'nonzero-exit'; pass = $false; modes = 'import,write' },
    @{ name = 'script-error'; pass = $false; modes = 'import,write' },
    @{ name = 'engine-error'; pass = $false; modes = 'import,write' },
    @{ name = 'missing-baseline-receipt'; pass = $false; modes = 'import,write' },
    @{ name = 'missing-ramcache-receipt'; pass = $false; modes = 'import,write' },
    @{ name = 'invalid-assertions'; pass = $false; modes = 'import,write' },
    @{ name = 'zero-assertions'; pass = $false; modes = 'import,write' },
    @{ name = 'invalid-checks'; pass = $false; modes = 'import,write' },
    @{ name = 'zero-checks'; pass = $false; modes = 'import,write' },
    @{ name = 'not-graphical'; pass = $false; modes = 'import,write' },
    @{ name = 'receipt-failure'; pass = $false; modes = 'import,write' },
    @{ name = 'fake-baseline-pid'; pass = $false; modes = 'import,write' },
    @{ name = 'fake-ramcache-pid'; pass = $false; modes = 'import,write' },
    @{ name = 'reused-pid'; pass = $false; modes = 'import,write' },
    @{ name = 'wrong-baseline-mode'; pass = $false; modes = 'import,write' },
    @{ name = 'wrong-ramcache-mode'; pass = $false; modes = 'import,write' },
    @{ name = 'wrong-hot-count'; pass = $false; modes = 'import,write' },
    @{ name = 'wrong-warm-count'; pass = $false; modes = 'import,write' },
    @{ name = 'missing-prefetch'; pass = $false; modes = 'import,write' },
    @{ name = 'missing-writeback'; pass = $false; modes = 'import,write' },
    @{ name = 'wrong-marker-pid'; pass = $false; modes = 'import,write' },
    @{ name = 'wrong-marker-mode'; pass = $false; modes = 'import,write' },
    @{ name = 'wrong-marker-count'; pass = $false; modes = 'import,write' },
    @{ name = 'missing-marker'; pass = $false; modes = 'import,write' },
    @{ name = 'duplicate-marker'; pass = $false; modes = 'import,write' },
    @{ name = 'failed-marker'; pass = $false; modes = 'import,write' },
    @{ name = 'changed-native'; pass = $false; modes = 'import,write' },
    @{ name = 'changed-manifest'; pass = $false; modes = 'import,write' },
    @{ name = 'stale-engine-pin'; pass = $false; modes = '' },
    @{ name = 'stale-native-pin'; pass = $false; modes = '' },
    @{ name = 'stale-native-file-pin'; pass = $false; modes = '' },
    @{ name = 'premodified-engine'; pass = $false; modes = '' },
    @{ name = 'premodified-native'; pass = $false; modes = '' },
    @{ name = 'invalid-source-identity'; pass = $false; modes = '' },
    @{ name = 'missing-executable'; pass = $false; modes = '' }
)
$rows = @()
$savedScenario = $env:GEN006_RAMCACHE_SMOKE_STUB_CASE
$savedTrace = $env:GEN006_RAMCACHE_SMOKE_STUB_TRACE
$savedRoot = $env:GEN006_RAMCACHE_SMOKE_STUB_ROOT
try {
    foreach ($case in $cases) {
        $casePath = Join-Path $outputPath ('case with spaces ' + $case.name)
        New-Item -ItemType Directory -Path $casePath | Out-Null
        $nativeDirectory = Join-Path $casePath 'godot\addons\cybersand_native\bin'
        New-Item -ItemType Directory -Path $nativeDirectory -Force | Out-Null
        $nativeFile = Join-Path $nativeDirectory 'cybersand_native.windows.x86_64.dll'
        [IO.File]::WriteAllText($nativeFile, 'Placeholder bytes for shell custody only; not a native runtime.')
        $script = Join-Path $casePath 'Run RAM Cache Smoke.ps1'
        Copy-Item -LiteralPath $smokeSource -Destination $script
        if ($case.name -ne 'missing-executable') {
            Copy-Item -LiteralPath $stubExe -Destination (Join-Path $casePath 'Godot_v4.7-stable_win64.exe')
        }
        $manifest = [ordered]@{
            source_commit = ('a' * 40); source_tree = ('b' * 40)
            native_sha256 = (Get-FileHash -LiteralPath $nativeFile -Algorithm SHA256).Hash.ToLowerInvariant()
            files_sha256 = @{
                'Godot_v4.7-stable_win64.exe' = (Get-FileHash -LiteralPath $stubExe -Algorithm SHA256).Hash.ToLowerInvariant()
                'godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll' = (Get-FileHash -LiteralPath $nativeFile -Algorithm SHA256).Hash.ToLowerInvariant()
            }
            scope = 'Stub-only PowerShell regression; no native/graphics qualification.'
        }
        if ($case.name -eq 'stale-engine-pin') { $manifest.files_sha256['Godot_v4.7-stable_win64.exe'] = '0' * 64 }
        if ($case.name -eq 'stale-native-pin') { $manifest.native_sha256 = '0' * 64 }
        if ($case.name -eq 'stale-native-file-pin') {
            $manifest.files_sha256['godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'] = '0' * 64
        }
        if ($case.name -eq 'invalid-source-identity') { $manifest.source_commit = 'G' * 40 }
        [IO.File]::WriteAllText((Join-Path $casePath 'evaluation-manifest.json'), ($manifest | ConvertTo-Json))
        $initialPayload = @{
            engine_sha256 = (Get-FileHash -LiteralPath $stubExe -Algorithm SHA256).Hash.ToLowerInvariant()
            native_sha256 = (Get-FileHash -LiteralPath $nativeFile -Algorithm SHA256).Hash.ToLowerInvariant()
            manifest_sha256 = (Get-FileHash -LiteralPath (Join-Path $casePath 'evaluation-manifest.json') -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        if ($case.name -eq 'premodified-engine') {
            [IO.File]::AppendAllText((Join-Path $casePath 'Godot_v4.7-stable_win64.exe'), 'unpublished overlay')
        }
        if ($case.name -eq 'premodified-native') { [IO.File]::AppendAllText($nativeFile, 'unpublished bytes') }
        $stdout = Join-Path $casePath 'child-stdout.log'
        $stderr = Join-Path $casePath 'child-stderr.log'
        $tracePath = Join-Path $casePath 'executed-processes.txt'
        $env:GEN006_RAMCACHE_SMOKE_STUB_CASE = $case.name
        $env:GEN006_RAMCACHE_SMOKE_STUB_TRACE = $tracePath
        $env:GEN006_RAMCACHE_SMOKE_STUB_ROOT = $casePath
        $watch = [Diagnostics.Stopwatch]::StartNew()
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
        $markerCount = [regex]::Matches($text, '(?m)^GEN006_RAMCACHE_PACKAGED_GRAPHICAL_SMOKE_PASS ').Count
        $traceRows = @()
        if (Test-Path -LiteralPath $tracePath) { $traceRows = @(Get-Content -LiteralPath $tracePath) }
        $observedModes = (@($traceRows | ForEach-Object { ($_ -split ' ')[0] }) -join ',')
        $observedPids = @($traceRows | ForEach-Object { [int](($_ -split ' ')[1]) })
        $writeReopenPids = @($traceRows | Where-Object { $_ -match '^(write|reopen) ' } |
            ForEach-Object { [int](($_ -split ' ')[1]) })
        $writeReopenDistinct = @($writeReopenPids | Select-Object -Unique).Count -eq $writeReopenPids.Count
        $accepted = $completed -and $null -ne $exitCode -and $exitCode -eq 0 -and $markerCount -eq 1
        $refused = $completed -and $null -ne $exitCode -and $exitCode -ne 0 -and $markerCount -eq 0
        $passed = (($case.pass -and $accepted) -or (!$case.pass -and $refused)) -and
            $observedModes -eq $case.modes -and $writeReopenDistinct
        $warningRetained = $null
        if ($case.name -eq 'warning-stderr') {
            $nativeLogs = @(Get-ChildItem -LiteralPath (Join-Path $casePath 'smoke') -Recurse -Filter '*.log')
            $warningLogs = @($nativeLogs | Where-Object { [IO.File]::ReadAllText($_.FullName) -match 'switching to ANGLE' })
            $warningRetained = $warningLogs.Count -ge 3
            $passed = $passed -and $warningRetained
        }
        $ledgerValid = $true
        $ledgerError = $null
        $ledgerRows = @()
        try {
            $ledgerFiles = @(Get-ChildItem -LiteralPath (Join-Path $casePath 'smoke') -Recurse -Filter 'packaged-processes.json')
            if ($observedPids.Count -eq 0) {
                $ledgerValid = $ledgerFiles.Count -eq 0
            } else {
                if ($ledgerFiles.Count -ne 1) { throw 'Missing or ambiguous original process ledger.' }
                # Windows PowerShell 5 emits a decoded JSON array as one pipeline
                # object. Enumerate the decoded value explicitly so @() cannot
                # wrap the entire process ledger inside an extra array layer.
                $decodedLedger = Get-Content -Raw -LiteralPath $ledgerFiles[0].FullName | ConvertFrom-Json
                if (-not ($decodedLedger -is [Array])) { throw 'The original process ledger is not a JSON array.' }
                $ledgerRows = @()
                foreach ($entry in $decodedLedger) { $ledgerRows += $entry }
                if ($ledgerRows.Count -ne $traceRows.Count) { throw 'Ledger omitted a directly observed engine process.' }
                for ($index = 0; $index -lt $traceRows.Count; $index++) {
                    $observedMode = ($traceRows[$index] -split ' ')[0]
                    $entry = $ledgerRows[$index]
                    $expectedExit = $(if ($observedMode -eq 'write' -and $case.name -in @('nonzero-exit','warning-nonzero')) { 7 } else { 0 })
                    if ($entry.mode -ne $observedMode -or $entry.pid -ne $observedPids[$index] -or
                        $entry.executable -ne (Join-Path $casePath 'Godot_v4.7-stable_win64.exe') -or
                        $entry.exit_code -ne $expectedExit -or $entry.timed_out -ne $false -or
                        $null -eq $entry.elapsed_ms -or $entry.elapsed_ms -lt 0 -or
                        $null -eq $entry.peak_working_set_bytes -or $entry.peak_working_set_bytes -lt 0 -or
                        $null -eq $entry.cpu_seconds -or $entry.cpu_seconds -lt 0) {
                        throw 'Ledger process identity, result or measured fields differ from the actual stub.'
                    }
                    foreach ($key in @('engine_sha256','native_sha256','manifest_sha256')) {
                        $expectedAfter = $initialPayload[$key]
                        if ($observedMode -eq 'write' -and $case.name -eq 'changed-native' -and $key -eq 'native_sha256') {
                            $expectedAfter = (Get-FileHash -LiteralPath $nativeFile -Algorithm SHA256).Hash.ToLowerInvariant()
                        }
                        if ($observedMode -eq 'write' -and $case.name -eq 'changed-manifest' -and $key -eq 'manifest_sha256') {
                            $expectedAfter = (Get-FileHash -LiteralPath (Join-Path $casePath 'evaluation-manifest.json') -Algorithm SHA256).Hash.ToLowerInvariant()
                        }
                        if ($entry.before.$key -ne $initialPayload[$key] -or $entry.after.$key -ne $expectedAfter) {
                            throw 'Process ledger omitted or changed its actual payload-hash observations.'
                        }
                    }
                }
            }
            $reportFiles = @(Get-ChildItem -LiteralPath (Join-Path $casePath 'smoke') -Recurse -Filter 'packaged-report.json')
            if ($case.pass) {
                if ($reportFiles.Count -ne 1) { throw 'Successful smoke omitted its original portable report.' }
                $productReport = Get-Content -Raw -LiteralPath $reportFiles[0].FullName | ConvertFrom-Json
                if ($productReport.status -ne 'passed' -or $productReport.schema -ne 'gen006-ramcache-packaged-smoke-v1' -or
                    $productReport.source_commit -ne $manifest.source_commit -or $productReport.processes.Count -ne 3 -or
                    ($productReport.processes | ConvertTo-Json -Depth 12 -Compress) -ne ($ledgerRows | ConvertTo-Json -Depth 12 -Compress)) {
                    throw 'Successful portable report differs from its observed process ledger.'
                }
                foreach ($key in @('engine_sha256','native_sha256','manifest_sha256')) {
                    if ($productReport.payload.$key -ne $initialPayload[$key]) { throw 'Portable report changed its payload identity.' }
                }
            } elseif ($reportFiles.Count -ne 0) { throw 'Refused smoke published a successful portable report.' }
        } catch {
            $ledgerValid = $false
            $ledgerError = $_.ToString()
        }
        $passed = $passed -and $ledgerValid
        $rows += [ordered]@{
            name = $case.name; status = $(if ($passed) { 'passed' } else { 'failed' })
            expected_acceptance = $case.pass; completed = $completed; exit_code = $exitCode
            pass_marker_count = $markerCount; elapsed_ms = $watch.ElapsedMilliseconds
            expected_modes = $case.modes; observed_modes = $observedModes
            subprocess_ids = $observedPids; distinct_write_reopen_subprocesses = $writeReopenDistinct
            warning_retained_in_all_native_logs = $warningRetained
            actual_process_ledger_valid = $ledgerValid; process_ledger_error = $ledgerError
            recorded_process_count = $ledgerRows.Count
            stdout = $stdout; stderr = $stderr
        }
        Write-Output ('GEN006_RAMCACHE_PACKAGED_SMOKE_GUARD ' + $case.name + ' ' + $rows[-1].status)
    }
} finally {
    $env:GEN006_RAMCACHE_SMOKE_STUB_CASE = $savedScenario
    $env:GEN006_RAMCACHE_SMOKE_STUB_TRACE = $savedTrace
    $env:GEN006_RAMCACHE_SMOKE_STUB_ROOT = $savedRoot
}
$failed = @($rows | Where-Object { $_.status -ne 'passed' })
$report = [ordered]@{
    schema = 'gen006-ramcache-packaged-smoke-shell-regression-v1'
    status = $(if ($failed.Count -eq 0 -and $rows.Count -eq $cases.Count) { 'passed' } else { 'failed' })
    scope = 'Actual packaged script under Windows PowerShell5 with stub engine processes; no native simulation or graphics claim.'
    powershell_version = $PSVersionTable.PSVersion.ToString()
    powershell_edition = $PSVersionTable.PSEdition
    package_script_sha256 = (Get-FileHash -LiteralPath $packageScript -Algorithm SHA256).Hash.ToLowerInvariant()
    extracted_smoke_sha256 = (Get-FileHash -LiteralPath $smokeSource -Algorithm SHA256).Hash.ToLowerInvariant()
    stub_source_sha256 = (Get-FileHash -LiteralPath $stubSourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    stub_executable_sha256 = (Get-FileHash -LiteralPath $stubExe -Algorithm SHA256).Hash.ToLowerInvariant()
    cases = $rows
}
[IO.File]::WriteAllText((Join-Path $outputPath 'results.json'), ($report | ConvertTo-Json -Depth 12))
if ($report.status -ne 'passed') { throw 'RAM-cache smoke shell guards failed; inspect original results and child logs.' }
Write-Output ('GEN006_RAMCACHE_PACKAGED_SMOKE_GUARDS_PASS cases=' + $rows.Count)
