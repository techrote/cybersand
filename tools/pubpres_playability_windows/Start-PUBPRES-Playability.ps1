[CmdletBinding()]
param(
    [string]$ArtifactZip = '',
    [string]$ChecksumFile = '',
    [string]$ExpectedArchiveSha256 = '',
    [string]$ExpectedCandidate = '',
    [ValidateSet('PUBPRES-PLAYABILITY-001','PUBPRES-COMPLETION-001')][string]$ExpectedMission = 'PUBPRES-PLAYABILITY-001',
    [string]$Destination = '',
    [string]$PackageRoot = '',
    [ValidateSet('Verify','Open')][string]$Action = 'Verify',
    [ValidateSet('Candidate','Integration','Main','Donor')][string]$Source = 'Candidate',
    [ValidateSet('Eager','Reachable')][string]$StagingPools = 'Eager',
    [ValidateSet('Safe','Separate')][string]$RenderThread = 'Safe',
    [ValidateSet('Off','On')][string]$SameFrameContinuation = 'Off',
    [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver = 'opengl3',
    [string]$ReopenRun = '',
    [switch]$OwnerProfile,
    [switch]$QuitAfterReady,
    [switch]$Library
)

# Windows PowerShell5.1; the standalone copy also verifies/extracts the nested
# GitHub artifact. No installed Git, Python, Godot or global profile is needed.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$script:PPManifestName = 'PUBPRES-PLAYABILITY-MANIFEST.json'
$script:PPUtf8 = [Text.UTF8Encoding]::new($false)
$script:PPProcessOwnerPath = Join-Path $PSScriptRoot 'process_owner.cs'
$script:PPReferencePins = @{
    M=@('00cdb02f103265b6dc5224c68283e9a0c8cb449f','06b62d73138028d1f7615b83edc9810491bf6287')
    I=@('8503ec19e4d620e125dc6df2c5c6571b1256cb92','ece848ad77c06fafb60d597d87f9f53f7bc211f1')
    D=@('d316c281e0abb575eb6302afc12ec44f211460ba','7a57dc0873dd161abe165f3a60e14e64886d04a8')
}

function Assert-PP([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Read-PPJson([string]$Path) { return [IO.File]::ReadAllText($Path) | ConvertFrom-Json }
function Write-PPJson([string]$Path,$Value) {
    # Pipeline enumeration drops an empty array and collapses a singleton.
    # Pass the actual object so evidence keeps its zero/one/many array shape.
    [IO.File]::WriteAllText($Path,(ConvertTo-Json -InputObject $Value -Depth 100)+"`n",$script:PPUtf8)
}
function Get-PPHash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-PPCanonicalHash([string]$Path) {
    $Bytes = $script:PPUtf8.GetBytes([IO.File]::ReadAllText($Path).Replace("`r`n","`n"))
    $Hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Hash.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() } finally { $Hash.Dispose() }
}
function Get-PPField($Object,[string]$Name,$Default=$null) {
    if ($Object -is [Collections.IDictionary]) { if ($Object.Contains($Name)) { return $Object[$Name] } }
    elseif ($null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $Default
}
function Test-PPSafeName([string]$Name) {
    Assert-PP ($Name.Length -gt 0 -and $Name.Length -le 1024 -and $Name -notmatch '[\\:<>"|?*\x00-\x1f]' -and
        -not $Name.StartsWith('/') -and -not $Name.EndsWith('/')) ('Unsafe payload path: '+$Name)
    foreach ($Part in $Name.Split('/')) {
        Assert-PP ($Part -ne '' -and $Part -ne '.' -and $Part -ne '..' -and -not $Part.EndsWith('.') -and -not $Part.EndsWith(' ') -and
            $Part -notmatch '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') ('Unsafe Windows payload name: '+$Name)
    }
}
function Join-PPSafe([string]$Root,[string]$Name) {
    Test-PPSafeName $Name
    $Base = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]'\/')+[IO.Path]::DirectorySeparatorChar
    $Path = [IO.Path]::GetFullPath((Join-Path $Root $Name))
    Assert-PP ($Path.StartsWith($Base,[StringComparison]::OrdinalIgnoreCase)) 'Path escaped its isolated root'
    return $Path
}
function Assert-PPX64([string]$Path) {
    $Stream = [IO.File]::OpenRead($Path)
    try {
        Assert-PP ($Stream.Length -ge 64) ('Missing PE header: '+$Path)
        $Reader = [IO.BinaryReader]::new($Stream)
        Assert-PP ($Reader.ReadUInt16() -eq 0x5a4d) ('Not a PE binary: '+$Path)
        $Stream.Position = 0x3c; $Offset = $Reader.ReadUInt32()
        Assert-PP ($Offset+6 -le $Stream.Length) ('Invalid PE offset: '+$Path)
        $Stream.Position = $Offset
        Assert-PP ($Reader.ReadUInt32() -eq 0x4550 -and $Reader.ReadUInt16() -eq 0x8664) ('Not a Windows x64 binary: '+$Path)
    } finally { $Stream.Dispose() }
}
function Read-PPChecksum([string]$Path,[string]$Filename) {
    $Value = [IO.File]::ReadAllText($Path).Trim()
    Assert-PP ($Value -cmatch '^([0-9a-f]{64})  ([^\r\n]+)$') 'Checksum sidecar must contain one canonical SHA-256 and exact filename'
    $Hash = $Matches[1]; $Named = $Matches[2]
    Assert-PP ($Named -ceq $Filename) ('Checksum names a different package: '+$Named)
    return $Hash
}
function Get-PPFiles([string]$Root) {
    $Pending = [Collections.Generic.Stack[string]]::new()
    $Pending.Push($Root); [int]$Count=0
    while ($Pending.Count -gt 0) {
        $Directory = $Pending.Pop()
        Assert-PP (((Get-Item -LiteralPath $Directory).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Directory reparse points are forbidden'
        foreach ($Item in Get-ChildItem -LiteralPath $Directory -Force) {
            $Count += 1
            Assert-PP ($Count -le 60000 -and ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'File inventory exceeded bounds or contains a reparse point'
            if ($Item.PSIsContainer) { $Pending.Push($Item.FullName) } else { $Item }
        }
    }
}

function Test-PPPackage([string]$Root,[string]$Candidate) {
    Assert-PP ($Candidate -cmatch '^[0-9a-f]{40}$') 'An exact expected candidate Git SHA is required'
    $Root = [IO.Path]::GetFullPath($Root)
    Assert-PP (((Get-Item -LiteralPath $Root).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Package root cannot be a reparse point'
    $ManifestPath = Join-Path $Root $script:PPManifestName
    $Expected = Read-PPChecksum ($ManifestPath+'.sha256') $script:PPManifestName
    Assert-PP ((Get-PPHash $ManifestPath) -ceq $Expected) 'Package manifest checksum differs'
    $Manifest = Read-PPJson $ManifestPath
    $Completion = $Manifest.schema -ceq 'pubpres-completion-windows-v1'
    $Mission = if ($Completion) { 'PUBPRES-COMPLETION-001' } else { 'PUBPRES-PLAYABILITY-001' }
    Assert-PP (($Completion -or $Manifest.schema -ceq 'pubpres-playability-windows-v2') -and $Manifest.mission -ceq $Mission -and
        $Manifest.candidate_commit -ceq $Candidate -and
        $Manifest.physical_acceptance -ceq 'HOLD' -and $Manifest.production_defaults_changed -eq $false) 'Package identity or HOLD status differs'
    $ExpectedName = 'CyberSand-'+$Mission+'-'+$Candidate.Substring(0,12)+'-Windows.zip'
    Assert-PP ($Manifest.package_filename -ceq $ExpectedName) 'Package uses an incorrect historical or renamed evaluator filename'
    $Inventory = @($Manifest.files_sha256.PSObject.Properties)
    Assert-PP ($Inventory.Count -eq $Manifest.file_count -and $Inventory.Count -gt 0 -and $Inventory.Count -le 30000) 'Payload inventory count differs'
    $Names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Entry in $Inventory) {
        $Path = Join-PPSafe $Root $Entry.Name
        Assert-PP ($Names.Add($Entry.Name) -and $Entry.Value -cmatch '^[0-9a-f]{64}$' -and (Test-Path -LiteralPath $Path -PathType Leaf)) ('Invalid or missing payload: '+$Entry.Name)
        Assert-PP (((Get-Item -LiteralPath $Path).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 -and
            (Get-PPHash $Path) -ceq $Entry.Value) ('Changed/reparse payload: '+$Entry.Name)
    }
    $Names.Add($script:PPManifestName) | Out-Null; $Names.Add($script:PPManifestName+'.sha256') | Out-Null
    foreach ($File in Get-PPFiles $Root) {
        $Relative = $File.FullName.Substring($Root.TrimEnd([char[]]'\/').Length+1).Replace('\','/')
        Assert-PP ($Names.Contains($Relative)) ('Unexpected file in stale/modified package: '+$Relative)
    }
    $SourceKeys = @($Manifest.sources.PSObject.Properties.Name | Sort-Object)
    $ExpectedKeys = if ($Completion) { 'C,D,I,M' } else { 'C,I,M' }
    Assert-PP (($SourceKeys -join ',') -ceq $ExpectedKeys) 'Missing independent source projects'
    $Toolchain = $null
    foreach ($Key in $SourceKeys) {
        $Item = $Manifest.sources.$Key
        Assert-PP ($Item.source_commit -cmatch '^[0-9a-f]{40}$' -and $Item.source_tree -cmatch '^[0-9a-f]{40}$' -and
            $Item.root -ceq ('sources/'+$Key) -and $Item.project -ceq ('sources/'+$Key+'/godot')) 'Source project identity differs'
        if ($Completion -and $script:PPReferencePins.ContainsKey($Key)) {
            $Pin = $script:PPReferencePins[$Key]
            Assert-PP ($Item.source_commit -ceq $Pin[0] -and $Item.source_tree -ceq $Pin[1]) ('Wrong exact Completion reference: '+$Key)
        }
        Assert-PP ($Item.native.path -ceq ($Item.root+'/godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll') -and
            $Item.native.receipt -ceq ($Item.root+'/provenance/PUBPRES-RUNTIME.json') -and
            $Item.rapier.path -ceq ($Item.root+'/godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll') -and
            $Item.rapier.receipt -ceq ($Item.root+'/godot/addons/godot-rapier2d/runtime-provenance.windows.json')) 'Cross-source runtime path substitution'
        foreach ($Runtime in @($Item.native,$Item.rapier)) {
            $Path = Join-PPSafe $Root $Runtime.path
            Assert-PP ((Get-PPHash $Path) -ceq $Runtime.sha256 -and (Get-Item -LiteralPath $Path).Length -eq $Runtime.bytes) 'Runtime bytes differ'
            Assert-PPX64 $Path
        }
        $NativeReceipt = Join-PPSafe $Root $Item.native.receipt
        Assert-PP ((Get-PPHash $NativeReceipt) -ceq $Item.native.receipt_sha256) 'Native build receipt changed'
        $Build = Read-PPJson $NativeReceipt
        Assert-PP ($Build.schema -ceq 'pubpres-playability-native-build-v1' -and $Build.platform -ceq 'windows' -and
            $Build.returncode -eq 0 -and $Build.source_commit -ceq $Item.source_commit -and $Build.source_tree -ceq $Item.source_tree -and
            $Build.runtime_file -ceq 'cybersand_native.windows.x86_64.dll' -and $Build.runtime_sha256 -ceq $Item.native.sha256 -and
            $Build.runtime_bytes -eq $Item.native.bytes -and $Build.production_runtime_promotion -eq $false -and
            $Build.toolchain_drift_allowed -eq $false) 'Native build/source substitution or invalid promotion'
        $InputEntries = @($Build.source_inputs_sha256.PSObject.Properties)
        Assert-PP ($InputEntries.Count -eq $Item.native.source_input_count -and $InputEntries.Count -gt 0) 'Native input closure is incomplete'
        $InputNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($Entry in $InputEntries) {
            Assert-PP ($InputNames.Add($Entry.Name) -and $Entry.Value -cmatch '^[0-9a-f]{64}$' -and
                $Entry.Name -cmatch '^(native/(include|src)|godot/native_extension)/.+\.(c|cc|cpp|cxx|h|hh|hpp|hxx|inc|inl|tpp)$') 'Invalid native source input identity'
            $Path = Join-PPSafe (Join-PPSafe $Root $Item.root) $Entry.Name
            Assert-PP ((Get-PPCanonicalHash $Path) -ceq $Entry.Value) ('Native source input differs: '+$Key+'/'+$Entry.Name)
        }
        foreach ($Scope in @('native/include','native/src','godot/native_extension')) {
            foreach ($File in Get-ChildItem -LiteralPath (Join-PPSafe (Join-PPSafe $Root $Item.root) $Scope) -Recurse -File) {
                if ($File.Extension -in @('.c','.cc','.cpp','.cxx','.h','.hh','.hpp','.hxx','.inc','.inl','.tpp')) {
                    $Relative = $File.FullName.Substring((Join-PPSafe $Root $Item.root).Length+1).Replace('\','/')
                    Assert-PP ($InputNames.Contains($Relative)) ('Native closure omits compiled input: '+$Relative)
                }
            }
        }
        Assert-PP ($Build.build_script -ceq 'tools/build_native_extension_windows.sh' -and
            (Get-PPCanonicalHash (Join-PPSafe (Join-PPSafe $Root $Item.root) $Build.build_script)) -ceq $Build.build_script_sha256 -and
            (Get-PPHash (Join-PPSafe (Join-PPSafe $Root $Item.root) 'provenance/build.log')) -ceq $Build.log_sha256 -and
            (Get-PPHash (Join-PPSafe $Root 'tools/pubpres_playability_build/build_runtime.py')) -ceq $Build.driver_sha256) 'Build script/log/driver evidence differs'
        $DriverNames = @('build_runtime.py','process_owner.py','dependency_custody.py')
        Assert-PP (@($Build.driver_inputs_sha256.PSObject.Properties).Count -eq $DriverNames.Count) 'Incomplete build-driver module closure'
        foreach ($Name in $DriverNames) {
            Assert-PP ((Get-PPCanonicalHash (Join-PPSafe $Root ('tools/pubpres_playability_build/'+$Name))) -ceq $Build.driver_inputs_sha256.$Name) 'Build-driver module differs'
        }
        $DependencyRoot = Join-PPSafe (Join-PPSafe $Root $Item.root) 'provenance'
        $DependencyPath = Join-PPSafe $DependencyRoot 'GODOT-CPP-DEPENDENCY.json'
        Assert-PP ((Get-PPHash $DependencyPath) -ceq $Build.godot_cpp_dependency_sha256) 'Dependency receipt differs'
        $Dependency = Read-PPJson $DependencyPath
        Assert-PP ($Dependency.schema -ceq 'pubpres-godot-cpp-dependency-v1' -and $Dependency.platform -ceq 'windows' -and
            $Dependency.source_commit -ceq $Build.godot_cpp_commit -and $Dependency.source_commit -ceq '101ae38034304346a46ea9ea84ae156d3e860496' -and
            $Dependency.source_tree -cmatch '^[0-9a-f]{40}$' -and $Dependency.builder_commit -ceq $Manifest.candidate_commit -and
            $Dependency.library_sha256 -ceq $Build.godot_cpp_library_sha256 -and
            (Get-PPHash (Join-PPSafe $DependencyRoot 'GODOT-CPP-BUILD.log')) -ceq $Dependency.build_log_sha256 -and
            (Get-PPHash (Join-PPSafe $DependencyRoot 'GODOT-CPP-BUILD.sh')) -ceq $Dependency.build_script_sha256) 'Dependency build inputs/log/source differ'
        Assert-PP (@($Dependency.builder_inputs_sha256.PSObject.Properties).Count -eq 2 -and
            (Get-PPHash (Join-PPSafe $DependencyRoot 'GODOT-CPP-BUILD.sh')) -ceq $Dependency.builder_inputs_sha256.'tools/build_pinned_godot_cpp.sh' -and
            (Get-PPHash (Join-PPSafe $DependencyRoot 'GODOT-CPP-CXX.sh')) -ceq $Dependency.builder_inputs_sha256.'tools/toolchains/g++') 'Dependency builder/helper closure differs'
        foreach ($Name in @('SConstruct','binding_generator.py','include/godot_cpp/core/class_db.hpp','gen/include/godot_cpp/classes/node.hpp','gen/include/gdextension_interface.h','gdextension/gdextension_interface.json','gdextension/extension_api-4-7.json','src/core/class_db.cpp')) {
            Assert-PP ($Dependency.source_inputs_sha256.$Name -cmatch '^[0-9a-f]{64}$') 'Required generated/authored dependency input is absent'
        }
        foreach ($Entry in $Dependency.source_inputs_sha256.PSObject.Properties) {
            Assert-PP ($Entry.Value -cmatch '^[0-9a-f]{64}$' -and $Entry.Name -notmatch '(^/|\\|(^|/)\.\.(/|$))') 'Invalid dependency input identity'
        }
        foreach ($Field in @('godot_cpp_commit','godot_cpp_library_sha256','godot_cpp_dependency_sha256','compiler_command','compiler_version','toolchain_drift_allowed')) {
            Assert-PP ($Build.$Field -ceq $Item.toolchain.$Field) 'Manifest and native toolchain receipt differ'
        }
        Assert-PP ($Build.godot_cpp_commit -cmatch '^[0-9a-f]{40}$' -and $Build.godot_cpp_library_sha256 -cmatch '^[0-9a-f]{64}$' -and
            $Build.compiler_command -and $Build.compiler_version) 'Incomplete toolchain identity'
        $Current = @($Build.godot_cpp_commit,$Build.godot_cpp_library_sha256,$Build.godot_cpp_dependency_sha256,$Build.compiler_command,$Build.compiler_version) -join "`n"
        if ($null -eq $Toolchain) { $Toolchain = $Current } else { Assert-PP ($Toolchain -ceq $Current) 'Source toolchains are unmatched' }
        $Experimental = $Key -cin @('C','D')
        Assert-PP ($Item.features.wave_column_tiles -eq $false -and $Item.features.wave_column_slots -eq 1 -and
            $Item.features.reachable_staging_pools -eq $Experimental -and $Item.features.wave_stage_probe -eq $Experimental -and
            $Item.features.same_frame_continuation -eq $Experimental) 'Unsupported experimental feature advertisement'
        $Rapier = Read-PPJson (Join-PPSafe $Root $Item.rapier.receipt)
        Assert-PP ($Rapier.artifact -ceq 'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll' -and
            $Rapier.sha256 -ceq $Item.rapier.sha256 -and $Rapier.size -eq $Item.rapier.bytes -and
            @($Rapier.source_inputs.PSObject.Properties).Count -gt 0) 'Retained Rapier identity differs'
        foreach ($Entry in $Rapier.source_inputs.PSObject.Properties) {
            Assert-PP ((Get-PPCanonicalHash (Join-PPSafe (Join-PPSafe $Root $Item.root) $Entry.Name)) -ceq $Entry.Value) 'Retained Rapier input differs'
        }
        $Derived = Read-PPJson (Join-PPSafe (Join-PPSafe $Root $Item.root) 'godot/addons/cybersand_native/runtime-provenance.json')
        Assert-PP ($Derived.source_commit -ceq $Item.source_commit -and $Derived.sha256 -ceq $Build.runtime_sha256 -and
            $Derived.build_receipt -ceq $Item.native.receipt -and $Derived.build_receipt_sha256 -ceq $Item.native.receipt_sha256 -and
            $Derived.production_runtime_promotion -eq $false) 'Runtime observation would read stale or misleading provenance'
        Assert-PP (@($Derived.source_inputs.PSObject.Properties).Count -eq $InputEntries.Count) 'Derived source closure differs'
        foreach ($Entry in $InputEntries) { Assert-PP ($Derived.source_inputs.($Entry.Name) -ceq $Entry.Value) 'Derived native source binding differs' }
    }
    Assert-PP ($Manifest.sources.C.source_commit -ceq $Candidate) 'Candidate source mismatch'
    Assert-PP ($Manifest.engine.gui.path -ceq 'Godot_v4.7-stable_win64.exe' -and
        $Manifest.engine.console.path -ceq 'Godot_v4.7-stable_win64_console.exe') 'Engine entrypoint differs'
    foreach ($Engine in @($Manifest.engine.gui,$Manifest.engine.console)) {
        Assert-PP ((Get-PPHash (Join-PPSafe $Root $Engine.path)) -ceq $Engine.sha256) 'Engine identity differs'
        Assert-PPX64 (Join-PPSafe $Root $Engine.path)
    }
    Assert-PP ($Manifest.engine.version -ceq '4.7.stable.official.5b4e0cb0f' -and
        (Get-PPHash (Join-PPSafe $Root 'vcruntime140.dll')) -ceq $Manifest.engine.vc_runtime_sha256) 'Pinned engine/VC runtime differs'
    if ($Completion) {
        Assert-PP ($Manifest.engine.gui.sha256 -ceq 'b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8' -and
            $Manifest.engine.console.sha256 -ceq 'd8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c') 'Completion Godot executable pin differs'
        Assert-PP ($Manifest.owner_command -ceq 'Open Workbench.cmd' -and $Names.Contains($Manifest.owner_command) -and
            $Manifest.owner_material -ceq 'full') 'Completion owner launcher or publication default differs'
        Assert-PP ($Manifest.owner_results_command -ceq 'Collect Results.cmd' -and $Names.Contains($Manifest.owner_results_command) -and
            $Manifest.owner_results_collector -ceq 'tools/pubpres_completion/Collect-PUBPRES-Results.ps1' -and $Names.Contains($Manifest.owner_results_collector) -and
            $Manifest.owner_acceptance -ceq 'ACCEPTANCE.md' -and $Names.Contains($Manifest.owner_acceptance) -and
            $Names.Contains('tools/pubpres_completion/ACCEPTANCE.md')) 'Completion acceptance or result collection entrypoint differs'
        Assert-PP ((Get-PPHash (Join-PPSafe $Root $Manifest.owner_acceptance)) -ceq
            (Get-PPHash (Join-PPSafe $Root 'tools/pubpres_completion/ACCEPTANCE.md'))) 'Acceptance instructions differ from the frozen source'
    }
    $VC = Read-PPJson (Join-PPSafe $Root 'vc-runtime-provenance.json')
    Assert-PP ($VC.schema -eq 1 -and $VC.authenticode.status -ceq 'Valid' -and
        (@($VC.files_sha256.PSObject.Properties.Name | Sort-Object) -join ',') -ceq 'Microsoft-Visual-C-Runtime-LICENSE.docx,Microsoft-Visual-Studio-2022-LICENSE.docx,vcruntime140.dll') 'VC runtime stage differs'
    foreach ($Entry in $VC.files_sha256.PSObject.Properties) { Assert-PP ((Get-PPHash (Join-PPSafe $Root $Entry.Name)) -ceq $Entry.Value) 'VC runtime or license differs' }
    $LegacyRegistration = 'tools/pubpres_playability/campaign.json'
    $Registration = if ($Completion) { 'tools/pubpres_completion/registration.json' } else { $LegacyRegistration }
    Assert-PP ($Manifest.campaign -ceq $Registration -and
        $Manifest.owner_launcher -ceq 'tools/pubpres_playability_windows/Start-PUBPRES-Playability.ps1' -and
        $Manifest.owner_observer -ceq 'tools/pubpres_playability_windows/owner_start.gd' -and
        $Manifest.experimental_defaults.staging_pools -ceq 'eager' -and $Manifest.experimental_defaults.render_thread -ceq 'safe' -and
        $Manifest.experimental_defaults.wave_column_tiles -eq $false -and
        $Manifest.experimental_defaults.same_frame_continuation -ceq 'off') 'Entrypoint or experimental default differs'
    Assert-PP ((Get-PPHash (Join-PPSafe $Root $Manifest.campaign)) -ceq $Manifest.campaign_sha256) 'Registered comparison corpus changed'
    $Campaign = Read-PPJson (Join-PPSafe $Root $Manifest.campaign)
    if ($Completion) {
        Assert-PP ($Campaign.schema -ceq 'pubpres-completion-campaign-v1' -and $Campaign.ordinary_defaults.material_publication -ceq 'full' -and
            $Campaign.predecessor_registration.path -ceq $LegacyRegistration -and
            $Campaign.predecessor_registration.sha256 -ceq '42b0fa3569e3df3cb4f06330c2f24f0c913ef8d1196e494900f59ae1134220ef' -and
            (Get-PPHash (Join-PPSafe $Root $LegacyRegistration)) -ceq $Campaign.predecessor_registration.sha256) 'Completion or predecessor registration differs'
        foreach ($Key in @('M','I','D')) {
            $Item = $Manifest.sources.$Key
            $Registered = $Campaign.reference_sources.$Key
            Assert-PP ($Registered.source_commit -ceq $Item.source_commit -and $Registered.source_tree -ceq $Item.source_tree) 'Registered control source differs'
        }
        $Campaign = Read-PPJson (Join-PPSafe $Root $LegacyRegistration)
    } else {
        Assert-PP ($Campaign.source_commits.main -ceq $Manifest.sources.M.source_commit -and
            $Campaign.source_commits.integration -ceq $Manifest.sources.I.source_commit) 'Comparison source registration differs'
    }
    Assert-PP ($Campaign.schema -ceq 'pubpres-playability-campaign-v3') 'Frozen apparatus schema differs'
    foreach ($Entry in $Campaign.overlay_sha256.PSObject.Properties) {
        Assert-PP ((Get-PPHash (Join-PPSafe (Join-PPSafe $Root $Manifest.sources.C.project) $Entry.Name)) -ceq $Entry.Value) 'Frozen observer overlay differs'
    }
    return $Manifest
}

function Get-PPZipEntries($Archive) {
    $Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    [long]$Total = 0
    [int]$EntryCount = 0
    foreach ($Entry in $Archive.Entries) {
        $EntryCount += 1
        Assert-PP ($EntryCount -le 30000) 'ZIP exceeds evaluator entry count bound'
        $Name = $Entry.FullName
        if ($Name.EndsWith('/')) { Test-PPSafeName ($Name.TrimEnd('/')); continue }
        Test-PPSafeName $Name
        Assert-PP ($Seen.Add($Name) -and $Entry.Length -le 2147483648) 'Duplicate or oversized ZIP member'
        $Total += $Entry.Length
        Assert-PP ($Total -le 6442450944 -and $Seen.Count -le 30000) 'ZIP exceeds evaluator extraction bounds'
        Assert-PP ((($Entry.ExternalAttributes -shr 16) -band 0xF000) -ne 0xA000) 'ZIP symbolic link refused'
    }
}
function Copy-PPZipEntry($Entry,[string]$Path) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    $From = $Entry.Open(); $To = [IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
    try { $From.CopyTo($To) } finally { $To.Dispose(); $From.Dispose() }
}
function Expand-PPEvaluator([string]$ArchivePath,[string]$Sidecar,[string]$KnownHash,[string]$Target,[string]$Candidate,
        [string]$Mission='PUBPRES-PLAYABILITY-001') {
    Assert-PP (-not (Test-Path -LiteralPath $Target)) 'Destination already exists; choose a new folder and preserve earlier evidence'
    Assert-PP ($Mission -cin @('PUBPRES-PLAYABILITY-001','PUBPRES-COMPLETION-001')) 'Unknown evaluator mission'
    $ExpectedName = 'CyberSand-'+$Mission+'-'+$Candidate.Substring(0,12)+'-Windows.zip'
    $Archive = [IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($ArchivePath))
    try {
        Get-PPZipEntries $Archive
        [IO.Directory]::CreateDirectory($Target) | Out-Null
        $IsInner = @($Archive.Entries | Where-Object { $_.FullName -ceq $script:PPManifestName }).Count -eq 1
        if ($IsInner) {
            Assert-PP ([IO.Path]::GetFileName($ArchivePath) -ceq $ExpectedName) 'Inner evaluator ZIP has a wrong or renamed filename'
            if (-not $Sidecar) { $Sidecar = $ArchivePath+'.sha256' }
            $InnerPath = [IO.Path]::GetFullPath($ArchivePath)
        } else {
            Assert-PP (-not $Sidecar) 'An outer GitHub artifact uses its exact nested sidecar'
            $Candidates = @($Archive.Entries | Where-Object { [IO.Path]::GetFileName($_.FullName) -ceq $ExpectedName })
            Assert-PP ($Candidates.Count -eq 1) 'Expected exactly one correctly named nested PUBPRES-PLAYABILITY package'
            $Checksums = @($Archive.Entries | Where-Object { $_.FullName -ceq ($Candidates[0].FullName+'.sha256') })
            Assert-PP ($Checksums.Count -eq 1) 'Exact nested evaluator SHA-256 sidecar is missing or ambiguous'
            $InnerPath = Join-Path $Target $ExpectedName; $Sidecar = $InnerPath+'.sha256'
            Copy-PPZipEntry $Candidates[0] $InnerPath; Copy-PPZipEntry $Checksums[0] $Sidecar
        }
    } finally { $Archive.Dispose() }
    $Expected = Read-PPChecksum $Sidecar $ExpectedName
    if ($KnownHash) { Assert-PP ($KnownHash -cmatch '^[0-9a-f]{64}$' -and $KnownHash -ceq $Expected) 'Independent expected archive SHA differs' }
    Assert-PP ((Get-PPHash $InnerPath) -ceq $Expected) 'Evaluator ZIP is corrupt or differs from its sidecar'
    $Payload = Join-Path $Target 'Payload'
    [IO.Directory]::CreateDirectory($Payload) | Out-Null
    $Archive = [IO.Compression.ZipFile]::OpenRead($InnerPath)
    try {
        Get-PPZipEntries $Archive
        foreach ($Entry in $Archive.Entries) {
            if (-not $Entry.FullName.EndsWith('/')) { Copy-PPZipEntry $Entry (Join-PPSafe $Payload $Entry.FullName) }
        }
    } finally { $Archive.Dispose() }
    $Manifest = Test-PPPackage $Payload $Candidate
    Assert-PP ($Manifest.mission -ceq $Mission) 'Archive contains a mismatched mission'
    Write-PPJson (Join-Path $Target 'verified-download.json') ([ordered]@{schema='pubpres-playability-download-v1'; candidate_commit=$Candidate;
        archive_sha256=$Expected; package_filename=$ExpectedName; source_archive=[IO.Path]::GetFullPath($ArchivePath); physical_acceptance='HOLD'})
    return $Payload
}

function Convert-PPArgument([string]$Value) {
    Assert-PP (-not $Value.Contains('"') -and $Value -notmatch '[\r\n\x00]') 'Invalid application argument'
    return '"'+[regex]::Replace($Value,'(\\+)$','$1$1')+'"'
}
function Get-PPProcessOwnerType {
    $Digest = Get-PPHash $script:PPProcessOwnerPath
    $Namespace = 'CyberSandPubpresProcessOwner_'+$Digest
    $TypeName = $Namespace+'.OwnedProcess'
    $Loaded = $TypeName -as [type]
    if ($null -eq $Loaded) {
        $Code = [IO.File]::ReadAllText($script:PPProcessOwnerPath).Replace('namespace PUBPRES_PROCESS_OWNER','namespace '+$Namespace)
        Add-Type -TypeDefinition $Code -Language CSharp | Out-Null
        $Loaded = $TypeName -as [type]
    }
    Assert-PP ($null -ne $Loaded) 'The exact Windows Job owner helper did not load'
    return $Loaded
}
function Invoke-PPProcess([string]$Engine,[string[]]$Arguments,[string]$Folder,[string]$Profile,$Settings,[string]$SourceSha,
        [int]$TimeoutSeconds=900,[string]$ReadyPath='',[int]$ReadyTimeoutSeconds=300,[string]$CancellationSignalPath='') {
    Assert-PP (-not (Test-Path -LiteralPath $Folder)) 'Process evidence folder already exists'
    [IO.Directory]::CreateDirectory($Folder) | Out-Null
    $Info = [Diagnostics.ProcessStartInfo]::new()
    $Info.FileName = $Engine; $Info.WorkingDirectory = [IO.Path]::GetDirectoryName($Engine)
    $Info.UseShellExecute = $false; $Info.CreateNoWindow = $true
    # The native owner passes only these direct output-file handles and NUL
    # stdin. No inherited console/job handle or pipe-EOF tree heuristic.
    $Info.Arguments = ($Arguments | ForEach-Object { Convert-PPArgument $_ }) -join ' '
    foreach ($Name in @($Info.EnvironmentVariables.Keys)) { if ($Name -match '^CYBERSAND_') { $Info.EnvironmentVariables.Remove($Name) } }
    foreach ($Name in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME')) {
        $Path = Join-Path $Profile $Name; [IO.Directory]::CreateDirectory($Path) | Out-Null
        $Info.EnvironmentVariables[$Name] = $Path
    }
    foreach ($Name in $Settings.Keys) { $Info.EnvironmentVariables[$Name] = [string]$Settings[$Name] }
    $Info.EnvironmentVariables['CYBERSAND_SOURCE_REVISION'] = $SourceSha
    $Info.EnvironmentVariables['CYBERSAND_SOURCE_SHA'] = $SourceSha
    $Owner = $null; $Failure = ''; $CleanupFailure = ''; $Clock = [Diagnostics.Stopwatch]::StartNew()
    $OwnerReceipt = Join-Path $Folder 'process-owner.json'; $ExitCode = $null; $ProcessId = $null
    $Memory = [Collections.Generic.List[object]]::new(); $TimedOut = $false; $Cancelled = $false; $Ready = $false
    $MemoryExhausted = $false
    try {
        $OwnerType = Get-PPProcessOwnerType
        $Owner = $OwnerType::Start($Info,(Join-Path $Folder 'stdout.log'),(Join-Path $Folder 'stderr.log'),$OwnerReceipt)
        $ProcessId = $Owner.Id
        while (-not $Owner.WaitForExit(250)) {
            if ($Owner.CancellationRequested -or ($CancellationSignalPath -and (Test-Path -LiteralPath $CancellationSignalPath -PathType Leaf))) {
                $Owner.RequestCancellation(); $Cancelled = $true; break
            }
            if ($ReadyPath -and (Test-Path -LiteralPath $ReadyPath -PathType Leaf)) { $Ready = $true }
            if (($TimeoutSeconds -gt 0 -and $Clock.Elapsed.TotalSeconds -gt $TimeoutSeconds) -or
                ($ReadyPath -and -not $Ready -and $Clock.Elapsed.TotalSeconds -gt $ReadyTimeoutSeconds)) {
                $TimedOut = $true; break
            }
            try {
                $Process = $Owner.MetricsProcess
                $Process.Refresh()
                if ($Memory.Count -lt 120000) {
                    $Memory.Add([ordered]@{elapsed_ms=$Clock.Elapsed.TotalMilliseconds; pid=$Process.Id; working_set_bytes=$Process.WorkingSet64;
                        peak_working_set_bytes=$Process.PeakWorkingSet64; private_bytes=$Process.PrivateMemorySize64; cpu_ms=$Process.TotalProcessorTime.TotalMilliseconds})
                } else { $MemoryExhausted = $true }
            } catch [InvalidOperationException] { }
        }
        if ($ReadyPath -and (Test-Path -LiteralPath $ReadyPath -PathType Leaf)) { $Ready = $true }
    } catch {
        $Failure = $_.Exception.Message
        throw
    } finally {
        # Always closes the complete Job, including after a zero-exit parent
        # leaves descendants. C# also writes a raw receipt directly, so native
        # cleanup evidence does not depend on a PowerShell pipeline surviving.
        if ($null -ne $Owner) {
            $Cancelled = $Cancelled -or $Owner.CancellationRequested
            try { $Owner.Close() } catch { $CleanupFailure = $_.Exception.Message }
            $ExitCode = $Owner.ExitCode
        }
        $Ownership = $null
        if (Test-Path -LiteralPath $OwnerReceipt -PathType Leaf) {
            $Ownership = Read-PPJson $OwnerReceipt
            $Cancelled = $Cancelled -or $Ownership.cancellation_requested
            if ($null -eq $ProcessId) { $ProcessId = $Ownership.process_id }
            if ($null -eq $ExitCode) { $ExitCode = $Ownership.root_exit_code }
        }
        $Termination = if ($CleanupFailure) { 'cleanup_uncertain' } elseif ($Cancelled) { 'cancelled' } elseif ($TimedOut) { 'timeout' } `
            elseif ($Failure) { 'launch_or_runtime_error' } elseif ($null -ne $Ownership -and $Ownership.zero_exit_with_descendants) { 'orphaned_descendants' } `
            elseif ($ExitCode -ne 0) { 'child_nonzero_exit' } else { 'completed' }
        Write-PPJson (Join-Path $Folder 'process-memory.json') ($Memory.ToArray())
        Write-PPJson (Join-Path $Folder 'process.json') ([ordered]@{schema='pubpres-playability-process-v1';
                command=@($Engine)+$Arguments; source_commit=$SourceSha; process_id=$ProcessId;
                elapsed_seconds=$Clock.Elapsed.TotalSeconds; exit_code=$ExitCode;
                timed_out=$TimedOut; cancelled=$Cancelled; cancelled_or_failed=($Termination -cne 'completed'); termination_reason=$Termination; readiness_observed=$Ready;
                memory_scope='250ms samples of directly launched GUI process, including setup; process_id must match the native application receipt';
                samples=$Memory.Count; memory_allowance_exhausted=$MemoryExhausted; failure=$Failure; cleanup_failure=$CleanupFailure;
                process_owner_sha256=(Get-PPHash $script:PPProcessOwnerPath); ownership=$Ownership; physical_acceptance='HOLD'})
        Assert-PP ($CleanupFailure -eq '') ('Owned process cleanup is uncertain: '+$CleanupFailure+'; raw evidence retained: '+$Folder)
    }
    Assert-PP (-not $Cancelled) ('Application cancelled; complete Job retired and original evidence retained: '+$Folder)
    Assert-PP ($null -ne $Ownership -and $Ownership.assigned_before_resume -eq $true -and $Ownership.initial_thread_resumed -eq $true -and $Ownership.cleanup_established -eq $true -and
        $Ownership.active_after_cleanup -eq 0) ('Application ownership/cleanup is unproven; original evidence retained: '+$Folder)
    Assert-PP (-not $Ownership.zero_exit_with_descendants) ('Zero-exit application left owned descendants; Job retired and original evidence retained: '+$Folder)
    Assert-PP (-not $TimedOut -and $ExitCode -eq 0) ('Application failed; original evidence retained: '+$Folder)
    $Text = [IO.File]::ReadAllText((Join-Path $Folder 'stdout.log'))+[IO.File]::ReadAllText((Join-Path $Folder 'stderr.log'))
    Assert-PP ($Text -notmatch 'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource:|Error initializing GLAD|MakeCurrent failed') 'Godot reported a script/renderer error'
    return Read-PPJson (Join-Path $Folder 'process.json')
}

function Get-PPSettings([string]$Key,[string]$Pools,[string]$Thread,[string]$Driver,[string]$Continuation='off',[bool]$Completion=$false) {
    $Experimental = $Key -cin @('C','D')
    Assert-PP ($Key -cin @('M','I','D','C') -and $Pools -cin @('eager','reachable') -and $Thread -cin @('safe','separate') -and
        $Driver -cin @('opengl3','opengl3_angle') -and ($Pools -ceq 'eager' -or $Experimental) -and
        $Continuation -cin @('off','on') -and ($Continuation -ceq 'off' -or ($Experimental -and $Thread -ceq 'safe'))) 'Unsupported run selectors'
    $Settings = [ordered]@{CYBERSAND_PLAYABILITY_RENDER_THREAD=$Thread;CYBERSAND_DIAG_NATIVE_RENDEZVOUS='0';
        CYBERSAND_DIAG_SAME_FRAME_CONTINUATION=$(if ($Continuation -ceq 'on') {'1'} else {'0'})}
    if ($Key -cne 'M') {
        $Settings['CYBERSAND_MATERIAL_PUBLICATION']='blit'; $Settings['CYBERSAND_DIAG_PHYSICS_PUBLICATION']='early'
        $Settings['CYBERSAND_DIAG_PRESENTATION']='coherent'; $Settings['CYBERSAND_DIAG_MATERIAL_TIMING']='measured'
        $Settings['CYBERSAND_DIAG_RENDER_CADENCE']='repaired'
    }
    if ($Experimental) { $Settings['CYBERSAND_DIAG_MATERIAL_POOL_POLICY']=$Pools }
    if ($Completion -and $Key -ceq 'C') {
        if ($Pools -ceq 'eager') { $Settings['CYBERSAND_MATERIAL_PUBLICATION']='full' }
        else { $Settings['CYBERSAND_DIAG_MATERIAL_RETIREMENT_SOURCE']='target' }
    }
    return $Settings
}
function Get-PPOverride { return "[cybersand]`nexperimental_wave_column_tiles=false`npubpres_wave_column_probe=false`n" }
function Get-PPExpectedRunFiles([string]$Root,$Manifest,[string]$Key) {
    $Files = [ordered]@{}; $Prefix = $Manifest.sources.$Key.root+'/'
    foreach ($Entry in $Manifest.files_sha256.PSObject.Properties) {
        if (-not $Entry.Name.StartsWith($Prefix,[StringComparison]::Ordinal)) { continue }
        $Relative = $Entry.Name.Substring($Prefix.Length)
        if (-not $Relative.StartsWith('godot/.godot/')) { $Files[$Relative]=$Entry.Value }
    }
    Assert-PP (-not $Files.Contains('godot/tests/pubpres_playability_owner_start.gd') -and
        -not $Files.Contains('godot/override.cfg')) 'Run-only observer/settings collide with committed source'
    $Files['godot/tests/pubpres_playability_owner_start.gd']=$Manifest.files_sha256.($Manifest.owner_observer)
    $Hash = [Security.Cryptography.SHA256]::Create()
    try { $Files['godot/override.cfg']=([BitConverter]::ToString($Hash.ComputeHash($script:PPUtf8.GetBytes((Get-PPOverride))))).Replace('-','').ToLowerInvariant() }
    finally { $Hash.Dispose() }
    return $Files
}
function New-PPRun([string]$Root,$Manifest,[string]$Key,[string]$Pools,[string]$Thread,[string]$Driver,
        [string]$Continuation='off',[string]$Run='') {
    $Settings = Get-PPSettings $Key $Pools $Thread $Driver $Continuation ($Manifest.schema -ceq 'pubpres-completion-windows-v1')
    $Item = $Manifest.sources.$Key
    Assert-PP ($Continuation -ceq 'off' -or $Item.features.same_frame_continuation) 'This historical source does not support same-frame continuation'
    Assert-PP ($Pools -ceq 'eager' -or $Item.features.reachable_staging_pools) 'This historical source does not support reachable staging pools'
    if (-not $Run) {
        $Run = Join-Path ([IO.Path]::GetDirectoryName($Root)) ('Runs\'+(Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,12))
    }
    Assert-PP (-not (Test-Path -LiteralPath $Run)) 'Refusing stale run folder'
    [IO.Directory]::CreateDirectory($Run) | Out-Null
    $CopyRoot = Join-Path $Run 'source'; [IO.Directory]::CreateDirectory($CopyRoot) | Out-Null
    $Prefix = $Item.root+'/'
    foreach ($Entry in $Manifest.files_sha256.PSObject.Properties) {
        if (-not $Entry.Name.StartsWith($Prefix,[StringComparison]::Ordinal)) { continue }
        $Relative = $Entry.Name.Substring($Prefix.Length); $Target = Join-PPSafe $CopyRoot $Relative
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Target)) | Out-Null
        [IO.File]::Copy((Join-PPSafe $Root $Entry.Name),$Target,$false)
    }
    $Observer = Join-PPSafe $CopyRoot 'godot/tests/pubpres_playability_owner_start.gd'
    [IO.File]::Copy((Join-PPSafe $Root $Manifest.owner_observer),$Observer,$false)
    $Override = Join-PPSafe $CopyRoot 'godot/override.cfg'
    Assert-PP (-not (Test-Path -LiteralPath $Override)) 'Committed override.cfg must be reviewed explicitly before owner overlay'
    [IO.File]::WriteAllText($Override,(Get-PPOverride),$script:PPUtf8)
    $Files = Get-PPExpectedRunFiles $Root $Manifest $Key
    $Record = [ordered]@{schema='pubpres-playability-owner-run-v2'; candidate_commit=$Manifest.candidate_commit; source=$Key;
        source_commit=$Item.source_commit; package_manifest_sha256=(Get-PPHash (Join-Path $Root $script:PPManifestName));
        staging_pools=$Pools;render_thread=$Thread;render_driver=$Driver;same_frame_continuation=$Continuation;settings=$Settings;files_sha256=$Files;
        wave_column_tiles=$false;profile='profile';project='source/godot';physical_acceptance='HOLD'}
    Write-PPJson (Join-Path $Run 'run.json') $Record
    return $Run
}

function Test-PPRun([string]$Run,[string]$Root,$Manifest) {
    Assert-PP (((Get-Item -LiteralPath $Run).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Run root cannot be a reparse point'
    $Record = Read-PPJson (Join-Path $Run 'run.json')
    Assert-PP ($Record.schema -ceq 'pubpres-playability-owner-run-v2' -and $Record.candidate_commit -ceq $Manifest.candidate_commit -and
        $Record.package_manifest_sha256 -ceq (Get-PPHash (Join-Path $Root $script:PPManifestName)) -and
        $Record.source -cin @($Manifest.sources.PSObject.Properties.Name) -and $Record.source_commit -ceq $Manifest.sources.($Record.source).source_commit -and
        $Record.wave_column_tiles -eq $false -and $Record.project -ceq 'source/godot' -and $Record.profile -ceq 'profile') 'Reopen source/package identity differs'
    $Settings = Get-PPSettings $Record.source $Record.staging_pools $Record.render_thread $Record.render_driver $Record.same_frame_continuation ($Manifest.schema -ceq 'pubpres-completion-windows-v1')
    Assert-PP (@($Record.settings.PSObject.Properties).Count -eq $Settings.Count) 'Unexpected run selector'
    foreach ($Name in $Settings.Keys) { Assert-PP ($Record.settings.$Name -ceq $Settings[$Name]) 'Requested run selectors changed' }
    $Expected = Get-PPExpectedRunFiles $Root $Manifest $Record.source
    Assert-PP (@($Record.files_sha256.PSObject.Properties).Count -eq $Expected.Count) 'Run source inventory differs from the pristine package'
    foreach ($Name in $Expected.Keys) {
        Assert-PP ($Record.files_sha256.$Name -ceq $Expected[$Name] -and
            (Get-PPHash (Join-PPSafe (Join-Path $Run 'source') $Name)) -ceq $Expected[$Name]) ('Changed World/application source refuses reopen: '+$Name)
    }
    $CopyRoot = Join-Path $Run 'source'
    foreach ($File in Get-PPFiles $CopyRoot) {
        $Relative = $File.FullName.Substring($CopyRoot.Length+1).Replace('\','/')
        if ($Relative.StartsWith('godot/.godot/')) { continue }
        # Godot creates UID companions for source scripts imported from older
        # exact references. They identify existing unchanged files only.
        if ($Relative.EndsWith('.uid') -and (Test-Path -LiteralPath ($File.FullName.Substring(0,$File.FullName.Length-4)) -PathType Leaf)) { continue }
        Assert-PP ($Expected.Contains($Relative)) ('Unexpected run source file: '+$Relative)
    }
    return $Record
}

if ($Library) { return }
Assert-PP ($ExpectedCandidate -cmatch '^[0-9a-f]{40}$') 'Supply -ExpectedCandidate with the full frozen Git SHA'
Assert-PP ([Environment]::GetEnvironmentVariable('CYBERSAND_PLAYABILITY_WAVE_COLUMN_TILES') -in @($null,'','0')) 'Wave-column On is a retained rejected experiment and cannot be enabled in this evaluator'
if ($ArtifactZip) {
    Assert-PP (-not $PackageRoot -and $Destination -and -not $ReopenRun) 'Artifact extraction needs a new Destination; choose PackageRoot for reopening'
    $PackageRoot = Expand-PPEvaluator $ArtifactZip $ChecksumFile $ExpectedArchiveSha256 ([IO.Path]::GetFullPath($Destination)) $ExpectedCandidate $ExpectedMission
} else { Assert-PP ($PackageRoot -and -not $Destination -and -not $ChecksumFile -and -not $ExpectedArchiveSha256) 'Supply either ArtifactZip/Destination or a pristine PackageRoot' }
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot).TrimEnd([char[]]'\/')
$Manifest = Test-PPPackage $PackageRoot $ExpectedCandidate
if ($PSBoundParameters.ContainsKey('ExpectedMission')) { Assert-PP ($Manifest.mission -ceq $ExpectedMission) 'Package mission differs' }
$script:PPProcessOwnerPath = Join-PPSafe $PackageRoot 'tools/pubpres_playability_windows/process_owner.cs'
Write-Host ('Verified '+$Manifest.file_count+' files and independent native builds at '+$ExpectedCandidate)
Write-Host 'Physical Windows/NVIDIA acceptance remains HOLD.'
Assert-PP (-not $OwnerProfile -or ($Action -ceq 'Open' -and $Manifest.schema -ceq 'pubpres-completion-windows-v1' -and
    -not $ReopenRun -and $Source -ceq 'Candidate' -and $RenderThread -ceq 'Safe' -and
    $StagingPools -ceq 'Eager' -and $SameFrameContinuation -ceq 'Off')) 'Owner profile requires the ordinary Completion candidate selectors'
if ($Action -eq 'Verify') { return }
$OwnerRun = ''
$OwnerLock = $null
try {
if ($OwnerProfile) {
    $Runs = Join-Path ([IO.Path]::GetDirectoryName($PackageRoot)) 'Runs'
    [IO.Directory]::CreateDirectory($Runs) | Out-Null
    Assert-PP (((Get-Item -LiteralPath $Runs).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Runs location cannot be a reparse point'
    $ManifestHash = Get-PPHash (Join-Path $PackageRoot $script:PPManifestName)
    $Name = 'Workbench-'+$ExpectedCandidate.Substring(0,12)+'-'+$ManifestHash.Substring(0,12)+'-'+$RenderingDriver
    $OwnerRun = Join-PPSafe $Runs $Name
    $LockPath = Join-PPSafe $Runs ($Name+'.lock')
    if (Test-Path -LiteralPath $LockPath) {
        Assert-PP (((Get-Item -LiteralPath $LockPath).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Owner lock cannot be a reparse point'
    }
    try { $OwnerLock = [IO.File]::Open($LockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch { throw ('Cannot lock the owner profile. Close any Workbench using it. '+$_.Exception.Message) }
    if (Test-Path -LiteralPath $OwnerRun) { $ReopenRun = $OwnerRun }
}
if ($ReopenRun) {
    $Run = [IO.Path]::GetFullPath($ReopenRun)
    $RunRecord = Test-PPRun $Run $PackageRoot $Manifest
    if ($OwnerProfile) {
        Assert-PP ($RunRecord.source -ceq 'C' -and $RunRecord.render_thread -ceq 'safe' -and
            $RunRecord.staging_pools -ceq 'eager' -and $RunRecord.same_frame_continuation -ceq 'off' -and
            $RunRecord.render_driver -ceq $RenderingDriver) 'Owner profile selectors changed'
    }
    if ($PSBoundParameters.ContainsKey('Source')) { Assert-PP (@{Candidate='C';Integration='I';Main='M';Donor='D'}[$Source] -ceq $RunRecord.source) 'Explicit reopen source differs' }
    foreach ($Choice in @(@('StagingPools','staging_pools'),@('RenderThread','render_thread'),@('RenderingDriver','render_driver'),@('SameFrameContinuation','same_frame_continuation'))) {
        if ($PSBoundParameters.ContainsKey($Choice[0])) { Assert-PP ((Get-Variable -Name $Choice[0] -ValueOnly).ToLowerInvariant() -ceq $RunRecord.($Choice[1])) 'Explicit reopen selector differs from saved run' }
    }
} else {
    $Key = @{Candidate='C';Integration='I';Main='M';Donor='D'}[$Source]
    Assert-PP ($Key -cin @($Manifest.sources.PSObject.Properties.Name)) 'Source is unavailable in this package'
    $Run = New-PPRun $PackageRoot $Manifest $Key ($StagingPools.ToLowerInvariant()) ($RenderThread.ToLowerInvariant()) $RenderingDriver ($SameFrameContinuation.ToLowerInvariant()) $OwnerRun
    $RunRecord = Test-PPRun $Run $PackageRoot $Manifest
}
$Item = $Manifest.sources.($RunRecord.source)
$Profile = Join-PPSafe $Run $RunRecord.profile; $Project = Join-PPSafe $Run $RunRecord.project
$Launch = Join-Path $Run ('launches/'+[Guid]::NewGuid().ToString('N'))
$Settings = [ordered]@{}; foreach ($Entry in $RunRecord.settings.PSObject.Properties) { $Settings[$Entry.Name]=$Entry.Value }
$Engine = Join-PPSafe $PackageRoot $Manifest.engine.gui.path
Invoke-PPProcess $Engine @('--headless','--path',$Project,'--editor','--import','--audio-driver','Dummy') ($Launch+'-import') $Profile $Settings $Item.source_commit 300 | Out-Null
Test-PPRun $Run $PackageRoot $Manifest | Out-Null
$ReadyPath = Join-Path $Run ('ready-'+[Guid]::NewGuid().ToString('N')+'.json')
$Settings['CYBERSAND_PLAYABILITY_OWNER_RECEIPT'] = $ReadyPath
if ($QuitAfterReady) { $Settings['CYBERSAND_PLAYABILITY_OWNER_QUIT_AFTER_READY']='1' }
Write-Host ('Opening source '+$RunRecord.source+'; staging='+$RunRecord.staging_pools+'; render thread='+$RunRecord.render_thread+'; same-frame continuation='+$RunRecord.same_frame_continuation)
Write-Host ('Save/reopen profile and evidence: '+$Run)
$OverallSeconds = if ($QuitAfterReady) { 360 } else { 0 }
$Process = Invoke-PPProcess $Engine @('--path',$Project,'--rendering-method','gl_compatibility','--rendering-driver',$RunRecord.render_driver,
    '--render-thread',$RunRecord.render_thread,'--audio-driver','Dummy','--script','res://tests/pubpres_playability_owner_start.gd') $Launch $Profile $Settings $Item.source_commit $OverallSeconds $ReadyPath 300
Assert-PP (Test-Path -LiteralPath $ReadyPath -PathType Leaf) 'Application exited without an installed native World receipt'
$Ready = Read-PPJson $ReadyPath
Assert-PP ($Ready.schema -ceq 'pubpres-playability-owner-start-v2' -and $Ready.ready -eq $true -and $Ready.source_commit -ceq $Item.source_commit -and $Ready.process_id -eq $Process.process_id -and
    $Ready.native_sha256 -ceq $Item.native.sha256 -and $Ready.rapier_sha256 -ceq $Item.rapier.sha256 -and
    $Ready.engine_sha256 -ceq $Manifest.engine.gui.sha256 -and $Ready.render_thread_inline -eq ($RunRecord.render_thread -ceq 'safe') -and
    $Ready.render_driver -ceq $RunRecord.render_driver -and
    $Ready.main_sha256 -ceq $RunRecord.files_sha256.'godot/scripts/main.gd' -and
    $Ready.project_sha256 -ceq $RunRecord.files_sha256.'godot/project.godot' -and
    $Ready.observer_sha256 -ceq $RunRecord.files_sha256.'godot/tests/pubpres_playability_owner_start.gd' -and
    $Ready.override_sha256 -ceq $RunRecord.files_sha256.'godot/override.cfg') 'Actual process/source/runtime/thread receipt differs'
if ($RunRecord.source -cin @('C','D')) {
    if ($RunRecord.settings.CYBERSAND_MATERIAL_PUBLICATION -ceq 'full') {
        Assert-PP ($Ready.material_publication.requested_mode -ceq 'full' -and
            $Ready.material_publication.backend -ceq 'full') 'Requested full publication did not reach actual native-pixel publisher'
    } else {
        Assert-PP ($Ready.material_publication.staging_pool_policy -ceq $RunRecord.staging_pools) 'Requested staging policy did not reach actual native-pixel publisher'
    }
    $Continuation = $Ready.same_frame_continuation
    $ExpectedOn = $RunRecord.same_frame_continuation -ceq 'on'
    $ExpectedMode = if ($ExpectedOn) { 'same_frame_once' } else { 'off' }
    Assert-PP ($null -ne $Continuation -and $Continuation.version -eq 1 -and $Continuation.requested -eq $ExpectedOn -and
        $Continuation.enabled -eq $ExpectedOn -and $Continuation.mode -ceq $ExpectedMode -and $Continuation.disabled_reason -ceq '' -and
        $Continuation.maximum_attempts_per_process_frame -eq 1 -and $Continuation.maximum_mailbox_reads_per_attempt -eq 1 -and
        $Continuation.wait_usec -eq 0 -and $Continuation.new_physics_callbacks -eq 0 -and $Continuation.carried_time_credit -eq $false) 'Requested continuation policy did not reach actual Main owner'
} else { Assert-PP ($null -eq $Ready.same_frame_continuation) 'Historical source unexpectedly advertises the new continuation' }
Test-PPRun $Run $PackageRoot $Manifest | Out-Null
Write-PPJson (Join-Path $Launch 'verified-startup.json') $Ready
Write-Host ('Closed verified owner session; evidence retained at '+$Run)
} finally { if ($null -ne $OwnerLock) { $OwnerLock.Dispose() } }
