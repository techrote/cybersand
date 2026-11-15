param(
    [Parameter(Mandatory = $true)][string]$Archive,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$Evidence
)
$ErrorActionPreference = 'Stop'
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
if (Test-Path -LiteralPath $Destination) { throw 'Refuse to overwrite an extraction directory' }
$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$report = [ordered]@{
    schema = 'cybersand-windows-zip-compatibility-v1'
    archive_sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    status = 'running'
    completed = $false
    dotnet_extraction = 'not run'
    shell_archive_handler = 'not run'
    explorer_gui = 'not tested'
}
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $reader = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $names = @($reader.Entries | ForEach-Object { $_.FullName })
        if ($names.Count -eq 0) { throw 'Empty Windows evaluation archive' }
        $maximum = ($names | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
        if ($maximum -gt 220 -or ($destinationPath.Length + 1 + $maximum) -ge 260) {
            throw 'Archive or destination exceeds the conventional Windows extraction path budget'
        }
        $report.members = $names.Count
        $report.maximum_relative_path = $maximum
        $report.maximum_extracted_path = $destinationPath.Length + 1 + $maximum
    } finally { $reader.Dispose() }
    # This is Microsoft's built-in ZIP implementation, with hidden .git history
    # and the exact payload inventory preserved. The smoke suite uses this tree.
    [System.IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $destinationPath)
    $manifest = Get-Content -LiteralPath (Join-Path $destinationPath 'materials-lab-evaluation.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $expected = @{}
    foreach ($property in $manifest.files_sha256.PSObject.Properties) { $expected[$property.Name] = $property.Value }
    $files = @(Get-ChildItem -LiteralPath $destinationPath -File -Recurse -Force)
    if ($files.Count -ne ($expected.Count + 1)) { throw 'Built-in extraction changed the complete package inventory' }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($destinationPath.Length + 1).Replace([System.IO.Path]::DirectorySeparatorChar, [char]'/')
        if ($relative -eq 'materials-lab-evaluation.json') { continue }
        if (-not $expected.ContainsKey($relative)) { throw "Unexpected extracted member: $relative" }
        $sha = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sha -ne $expected[$relative]) { throw "Built-in extraction changed payload bytes: $relative" }
    }
    $report.dotnet_extraction = 'passed; all manifested files independently hashed'
    $report.source_commit = $manifest.source_commit
    $report.source_tree = $manifest.source_tree
    $report.extracted_files = $files.Count

    # Exercise the Shell ZIP namespace and copy handler used by Explorer.
    # This is not an observed interactive Explorer GUI test.
    $shell = $null
    try { $shell = New-Object -ComObject Shell.Application } catch {
        $report.shell_archive_handler = 'unavailable: Shell.Application COM activation failed'
        $report.shell_error = $_.Exception.Message
    }
    if ($null -ne $shell) {
        $zipFolder = $shell.NameSpace($archivePath)
        if ($null -eq $zipFolder) { throw 'Windows Shell archive handler could not open the new ZIP' }
        $report.shell_root_entries = $zipFolder.Items().Count
        $shellOutput = Join-Path (Split-Path $destinationPath -Parent) ('cs-zip-shell-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $shellOutput | Out-Null
        try {
            $outputFolder = $shell.NameSpace($shellOutput)
            if ($null -eq $outputFolder) { throw 'Windows Shell extraction destination is unavailable' }
            foreach ($name in @('Open Workbench.cmd', 'Open-Materials-Lab.cmd', 'README.txt')) {
                $item = $zipFolder.ParseName($name)
                if ($null -eq $item) { throw "Windows Shell cannot enumerate required member: $name" }
                $outputFolder.CopyHere($item, 4 + 16 + 512 + 1024)
                $target = Join-Path $shellOutput $name
                $deadline = [DateTime]::UtcNow.AddSeconds(30)
                do {
                    Start-Sleep -Milliseconds 100
                    $match = $false
                    try {
                        if (Test-Path -LiteralPath $target) {
                            $match = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expected[$name]
                        }
                    } catch {
                        # CopyHere is asynchronous; an existing target can still
                        # be locked by the Shell writer. Retry within this bound.
                        $match = $false
                    }
                } while (-not $match -and [DateTime]::UtcNow -lt $deadline)
                if (-not $match) { throw "Windows Shell did not extract exact bytes: $name" }
            }
            $report.shell_archive_handler = 'passed; ZIP opened and both launchers plus README extracted with exact hashes'
        } finally {
            Remove-Item -LiteralPath $shellOutput -Recurse -Force
        }
    }
    $report.status = 'passed'
    $report.completed = $true
} catch {
    $report.status = 'failed'
    $report.error = $_.Exception.Message
    throw
} finally {
    $evidencePath = [System.IO.Path]::GetFullPath($Evidence)
    New-Item -ItemType Directory -Force (Split-Path $evidencePath -Parent) | Out-Null
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
}
