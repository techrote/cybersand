[CmdletBinding()]
param(
    [string]$PackageRoot='', [string]$ExpectedCandidate='',
    [ValidateSet('Verify','Open')][string]$Action='Verify',
    [ValidateSet('Candidate','Donor')][string]$Source='Candidate',
    [ValidateSet('Stock','Egl')][string]$Engine='Stock',
    [ValidateSet('Safe','Separate')][string]$RenderThread='Safe',
    [ValidateSet(2,3)][int]$FullImageSlots=2,
    [ValidateSet('opengl3','opengl3_angle')][string]$RenderingDriver='opengl3',
    [ValidateSet('ordinary','wave512','wave1024','wave2048','mixed2048')][string]$Scene='ordinary',
    [string]$ReopenRun='', [switch]$OwnerProfile, [switch]$QuitAfterReady, [switch]$Library
)
# The frozen library supplies bounded path checks and creation-time Windows Job
# ownership. All final-package admission and selector logic lives in this file.
$PFParameters=@{}
foreach($Name in @('PackageRoot','ExpectedCandidate','Action','Source','Engine','RenderThread','FullImageSlots','RenderingDriver','Scene','ReopenRun','OwnerProfile','QuitAfterReady','Library')) {
    $PFParameters[$Name]=Get-Variable -Name $Name -ValueOnly
}
$PFExplicit=@{}; foreach($Name in $PSBoundParameters.Keys) { $PFExplicit[$Name]=$true }
. (Join-Path $PSScriptRoot '../pubpres_playability_windows/Start-PUBPRES-Playability.ps1') -Library
foreach($Name in $PFParameters.Keys) { Set-Variable -Name $Name -Value $PFParameters[$Name] }
$script:PFDonor='c90dbc46e1f57f28e06b1f4205b83467335ff657'
$script:PFMission='PUBPRES-PLAYABILITY-FINAL-001'
$script:PFSchema='pubpres-playability-final-windows-v1'
$script:PFPatchedSha='d6a1e5795205eb7968131df55f39916af112f716ec419fce5f97ccb48990fd45'

function Test-PPPackage([string]$Root,[string]$Candidate) {
    Assert-PP ($Candidate -cmatch '^[0-9a-f]{40}$') 'Supply the exact candidate Git SHA'
    $Root=[IO.Path]::GetFullPath($Root)
    Assert-PP (((Get-Item -LiteralPath $Root).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Package root cannot be a reparse point'
    $Path=Join-Path $Root $script:PPManifestName
    Assert-PP ((Get-PPHash $Path) -ceq (Read-PPChecksum ($Path+'.sha256') $script:PPManifestName)) 'Manifest checksum differs'
    $Manifest=Read-PPJson $Path
    Assert-PP ($Manifest.schema -ceq $script:PFSchema -and $Manifest.mission -ceq $script:PFMission -and
        $Manifest.candidate_commit -ceq $Candidate -and $Manifest.physical_acceptance -ceq 'HOLD' -and
        $Manifest.production_defaults_changed -eq $false) 'Final package identity or HOLD differs'
    Assert-PP ($Manifest.package_filename -ceq ('CyberSand-'+$script:PFMission+'-'+$Candidate.Substring(0,12)+'-Windows.zip')) 'Evaluator filename differs'
    $Defaults=$Manifest.defaults
    Assert-PP (@($Defaults.PSObject.Properties).Count -eq 7 -and $Defaults.source -ceq 'C' -and $Defaults.engine -ceq 'stock' -and
        $Defaults.render_thread -ceq 'safe' -and $Defaults.material -ceq 'full' -and $Defaults.full_image_slots -eq 2 -and
        $Defaults.same_frame_continuation -ceq 'off' -and $Defaults.scene -ceq 'ordinary') 'Ordinary default selectors differ'
    $Inventory=@($Manifest.files_sha256.PSObject.Properties)
    Assert-PP ($Inventory.Count -eq $Manifest.file_count -and $Inventory.Count -gt 0 -and $Inventory.Count -le 30000) 'Inventory count differs'
    $Names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($Entry in $Inventory) {
        $File=Join-PPSafe $Root $Entry.Name
        Assert-PP ($Names.Add($Entry.Name) -and $Entry.Value -cmatch '^[0-9a-f]{64}$' -and
            (Test-Path -LiteralPath $File -PathType Leaf) -and
            ((Get-Item -LiteralPath $File).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 -and
            (Get-PPHash $File) -ceq $Entry.Value) ('Missing/changed/reparse payload: '+$Entry.Name)
    }
    $Names.Add($script:PPManifestName)|Out-Null; $Names.Add($script:PPManifestName+'.sha256')|Out-Null
    foreach($File in Get-PPFiles $Root) {
        $Relative=$File.FullName.Substring($Root.TrimEnd([char[]]'\/').Length+1).Replace('\','/')
        Assert-PP ($Names.Contains($Relative)) ('Unexpected package file: '+$Relative)
    }
    $SourceKeys=@($Manifest.sources.PSObject.Properties.Name|Sort-Object)
    Assert-PP (($SourceKeys -join ',') -cin @('C','C,D')) 'Unregistered source roles'
    $Toolchain = $null
    foreach ($Key in $SourceKeys) {
        $Item = $Manifest.sources.$Key
        Assert-PP ($Item.source_commit -cmatch '^[0-9a-f]{40}$' -and $Item.source_tree -cmatch '^[0-9a-f]{40}$' -and
            $Item.root -ceq ('sources/'+$Key) -and $Item.project -ceq ('sources/'+$Key+'/godot')) 'Source project identity differs'
        if ($Key -ceq 'D') { Assert-PP ($Item.source_commit -ceq $script:PFDonor) 'Frozen donor source differs' }
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
    Assert-PP ($Manifest.sources.C.source_commit -ceq $Candidate) 'Candidate source differs'
    Assert-PP ($Manifest.engine.version -ceq '4.7.stable.official.5b4e0cb0f' -and
        $Manifest.engine.gui.path -ceq 'Godot_v4.7-stable_win64.exe' -and
        $Manifest.engine.console.path -ceq 'Godot_v4.7-stable_win64_console.exe' -and
        $Manifest.engine.gui.sha256 -ceq 'b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8' -and
        $Manifest.engine.console.sha256 -ceq 'd8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c') 'Official 4.7 engine pin differs'
    foreach($Entry in @($Manifest.engine.gui,$Manifest.engine.console)) {
        Assert-PP ((Get-PPHash (Join-PPSafe $Root $Entry.path)) -ceq $Entry.sha256) 'Actual official executable differs'
        Assert-PPX64 (Join-PPSafe $Root $Entry.path)
    }
    $VC=Read-PPJson (Join-PPSafe $Root 'vc-runtime-provenance.json')
    Assert-PP ($VC.schema -eq 1 -and $VC.authenticode.status -ceq 'Valid' -and
        (@($VC.files_sha256.PSObject.Properties.Name|Sort-Object)-join ',') -ceq 'Microsoft-Visual-C-Runtime-LICENSE.docx,Microsoft-Visual-Studio-2022-LICENSE.docx,vcruntime140.dll') 'Signed VC stage differs'
    foreach($Entry in $VC.files_sha256.PSObject.Properties) {
        Assert-PP ((Get-PPHash (Join-PPSafe $Root $Entry.Name)) -ceq $Entry.Value) 'VC binary/licence differs'
    }
    Assert-PP ((Get-PPHash (Join-PPSafe $Root 'vcruntime140.dll')) -ceq $Manifest.engine.vc_runtime_sha256) 'VC engine binding differs'
    if($null -ne $Manifest.patched_engine) {
        $Patch=$Manifest.patched_engine
        Assert-PP ($Patch.root -ceq 'engines/egl' -and $Patch.gui.path -ceq 'Godot-PUBPRES-EGL-4.7.exe' -and
            $Patch.gui.sha256 -ceq $script:PFPatchedSha -and $Patch.default -eq $false -and
            $Patch.version -ceq '4.7.stable.cybersand_egl_handoff.5b4e0cb0f' -and
            $Patch.provenance_sha256 -ceq 'a4be0fa432c77240c49e28ab53cc30b4cb97f898a0064e747e03f445ac04751c' -and
            $Patch.artifact.artifact_sha256 -ceq '34dfdf5769828dc4ae876550864b4c80c3acd5bc960944ce8631d9bf900421be' -and
            $Patch.artifact.artifact_id -eq 14284768334 -and $Patch.artifact.workflow_run -eq 43980022228 -and
            $Patch.artifact.application_source -ceq '4e84820baa021f96c3c1957fb125786fb7ab5e6a') 'Patched engine custody differs'
        $ProofPath=Join-PPSafe $Root 'engines/egl/build-provenance.json'
        Assert-PP ((Get-PPHash $ProofPath) -ceq $Patch.provenance_sha256) 'Original engine proof differs'
        $Proof=Read-PPJson $ProofPath
        Assert-PP ($Proof.complete -eq $true -and $Proof.custom_engine -eq $true -and $Proof.public_api_equivalent -eq $true -and
            $Proof.upstream_commit -ceq '5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88') 'Original engine build/API proof differs'
        foreach($Entry in $Proof.payload_files.PSObject.Properties) {
            $File=Join-PPSafe (Join-PPSafe $Root $Patch.root) $Entry.Name
            Assert-PP ((Get-PPHash $File) -ceq $Entry.Value.sha256 -and (Get-Item -LiteralPath $File).Length -eq $Entry.Value.bytes) 'Recovered engine payload differs'
        }
        Assert-PP ((Get-PPHash (Join-PPSafe $Root $Patch.gui.path)) -ceq $script:PFPatchedSha -and
            (Get-PPHash (Join-PPSafe (Join-PPSafe $Root $Patch.root) $Proof.gui_executable)) -ceq $script:PFPatchedSha) 'Patched executable copy differs'
        Assert-PPX64 (Join-PPSafe $Root $Patch.gui.path)
    }
    Assert-PP ($Manifest.owner_launcher -ceq 'tools/pubpres_final_windows/Start-PUBPRES-Final.ps1' -and
        $Manifest.owner_observer -ceq 'tools/pubpres_final_windows/owner_start.gd' -and
        $Manifest.owner_results_collector -ceq 'tools/pubpres_final_windows/Collect-Results.ps1') 'Final owner entrypoint differs'
    Assert-PP ((Get-PPHash (Join-PPSafe $Root 'ACCEPTANCE.md')) -ceq
        (Get-PPHash (Join-PPSafe $Root 'tools/pubpres_final_windows/ACCEPTANCE.md'))) 'Acceptance instructions differ'
    return $Manifest
}

function Get-PFSettings([string]$Key,[string]$EngineName,[string]$Thread,[int]$Slots,[string]$Driver,[string]$SceneName) {
    Assert-PP ($Key -cin @('C','D') -and $EngineName -cin @('stock','egl') -and $Thread -cin @('safe','separate') -and
        $Slots -in @(2,3) -and ($Slots -eq 2 -or $Key -ceq 'C') -and $Driver -cin @('opengl3','opengl3_angle') -and
        $SceneName -cin @('ordinary','wave512','wave1024','wave2048','mixed2048') -and
        ($Thread -ceq 'safe' -or ($EngineName -ceq 'egl' -and $Driver -ceq 'opengl3_angle'))) 'Unregistered source/engine/slot/renderer selection'
    return [ordered]@{CYBERSAND_MATERIAL_PUBLICATION='full';CYBERSAND_DIAG_FULL_IMAGE_SLOTS=[string]$Slots;
        CYBERSAND_DIAG_PHYSICS_PUBLICATION='early';CYBERSAND_DIAG_PRESENTATION='coherent';
        CYBERSAND_DIAG_MATERIAL_TIMING='measured';CYBERSAND_DIAG_RENDER_CADENCE='repaired';
        CYBERSAND_DIAG_SAME_FRAME_CONTINUATION='0';CYBERSAND_DIAG_NATIVE_RENDEZVOUS='0';
        CYBERSAND_DIAG_MATERIAL_DEADLINE_HZ='0';
        CYBERSAND_DIAG_MATERIAL_POOL_POLICY='eager';CYBERSAND_MATERIAL_QUEUE_THREAD=$Thread;
        CYBERSAND_PLAYABILITY_RENDER_THREAD=$Thread;CYBERSAND_FINAL_SCENE=$SceneName}
}
function Get-PFEngine($Manifest,[string]$Name) {
    if($Name -ceq 'stock') { return $Manifest.engine }
    Assert-PP ($Name -ceq 'egl' -and $null -ne $Manifest.patched_engine) 'Explicit recovered engine is unavailable'
    return $Manifest.patched_engine
}
function New-PFRun([string]$Root,$Manifest,[string]$Key,[string]$EngineName,[string]$Thread,[int]$Slots,[string]$Driver,[string]$SceneName,[string]$Run) {
    Assert-PP ($Key -cin @($Manifest.sources.PSObject.Properties.Name)) 'Source is unavailable'
    $SelectedEngine=Get-PFEngine $Manifest $EngineName
    $Settings=Get-PFSettings $Key $EngineName $Thread $Slots $Driver $SceneName
    Assert-PP (-not (Test-Path -LiteralPath $Run)) 'Run directory already exists'
    [IO.Directory]::CreateDirectory((Join-Path $Run 'source'))|Out-Null
    $Prefix=$Manifest.sources.$Key.root+'/'
    foreach($Entry in $Manifest.files_sha256.PSObject.Properties) {
        if(-not $Entry.Name.StartsWith($Prefix,[StringComparison]::Ordinal)) { continue }
        $Target=Join-PPSafe (Join-Path $Run 'source') $Entry.Name.Substring($Prefix.Length)
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Target))|Out-Null
        [IO.File]::Copy((Join-PPSafe $Root $Entry.Name),$Target,$false)
    }
    $Project=Join-Path $Run 'source/godot'
    Assert-PP (-not (Test-Path -LiteralPath (Join-Path $Project 'override.cfg'))) 'Committed override.cfg requires explicit review before overlay'
    [IO.File]::Copy((Join-PPSafe $Root $Manifest.owner_observer),(Join-PPSafe $Project 'tests/pubpres_playability_owner_start.gd'),$false)
    [IO.File]::WriteAllText((Join-Path $Project 'override.cfg'),(Get-PPOverride),$script:PPUtf8)
    $Record=[ordered]@{schema='pubpres-final-owner-run-v1';candidate_commit=$Manifest.candidate_commit;source=$Key;
        source_commit=$Manifest.sources.$Key.source_commit;package_manifest_sha256=(Get-PPHash (Join-Path $Root $script:PPManifestName));
        engine=$EngineName;engine_sha256=$SelectedEngine.gui.sha256;render_thread=$Thread;full_image_slots=$Slots;
        render_driver=$Driver;scene=$SceneName;settings=$Settings;files_sha256=(Get-PPExpectedRunFiles $Root $Manifest $Key);
        profile='profile';project='source/godot';physical_acceptance='HOLD'}
    Write-PPJson (Join-Path $Run 'run.json') $Record
}
function Test-PFRun([string]$Run,[string]$Root,$Manifest) {
    Assert-PP (((Get-Item -LiteralPath $Run).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Run root cannot be a reparse point'
    $Record=Read-PPJson (Join-Path $Run 'run.json')
    Assert-PP ($Record.schema -ceq 'pubpres-final-owner-run-v1' -and $Record.candidate_commit -ceq $Manifest.candidate_commit -and
        $Record.package_manifest_sha256 -ceq (Get-PPHash (Join-Path $Root $script:PPManifestName)) -and
        $Record.source -cin @($Manifest.sources.PSObject.Properties.Name) -and $Record.source_commit -ceq $Manifest.sources.($Record.source).source_commit -and
        $Record.project -ceq 'source/godot' -and $Record.profile -ceq 'profile' -and $Record.physical_acceptance -ceq 'HOLD') 'Saved run/package/source identity differs'
    $SelectedEngine=Get-PFEngine $Manifest $Record.engine
    Assert-PP ($Record.engine_sha256 -ceq $SelectedEngine.gui.sha256) 'Saved engine identity differs'
    $Settings=Get-PFSettings $Record.source $Record.engine $Record.render_thread $Record.full_image_slots $Record.render_driver $Record.scene
    Assert-PP (@($Record.settings.PSObject.Properties).Count -eq $Settings.Count) 'Unexpected run selector'
    foreach($Name in $Settings.Keys) { Assert-PP ($Record.settings.$Name -ceq $Settings[$Name]) ('Changed selector: '+$Name) }
    $Expected=Get-PPExpectedRunFiles $Root $Manifest $Record.source
    Assert-PP (@($Record.files_sha256.PSObject.Properties).Count -eq $Expected.Count) 'Run inventory differs'
    foreach($Name in $Expected.Keys) {
        Assert-PP ($Record.files_sha256.$Name -ceq $Expected[$Name] -and
            (Get-PPHash (Join-PPSafe (Join-Path $Run 'source') $Name)) -ceq $Expected[$Name]) ('Changed run source: '+$Name)
    }
    $Copy=Join-Path $Run 'source'
    foreach($File in Get-PPFiles $Copy) {
        $Relative=$File.FullName.Substring($Copy.Length+1).Replace('\','/')
        if($Relative.StartsWith('godot/.godot/')) { continue }
        if($Relative.EndsWith('.uid') -and (Test-Path -LiteralPath $File.FullName.Substring(0,$File.FullName.Length-4) -PathType Leaf)) { continue }
        Assert-PP ($Expected.Contains($Relative)) ('Unexpected run source: '+$Relative)
    }
    return $Record
}

if($Library) { return }
$PackageRoot=[IO.Path]::GetFullPath($PackageRoot).TrimEnd([char[]]'\/')
$Manifest=Test-PPPackage $PackageRoot $ExpectedCandidate
$script:PPProcessOwnerPath=Join-PPSafe $PackageRoot 'tools/pubpres_playability_windows/process_owner.cs'
Write-Host ('Verified '+$Manifest.file_count+' source/runtime files. Draft/HOLD; physical NVIDIA acceptance is pending.')
if($Action -ceq 'Verify') { return }
$Key=if($Source -ceq 'Candidate') {'C'} else {'D'}
$EngineName=$Engine.ToLowerInvariant(); $Thread=$RenderThread.ToLowerInvariant()
Get-PFSettings $Key $EngineName $Thread $FullImageSlots $RenderingDriver $Scene|Out-Null
Get-PFEngine $Manifest $EngineName|Out-Null
$Runs=Join-Path ([IO.Path]::GetDirectoryName($PackageRoot)) 'Runs'
[IO.Directory]::CreateDirectory($Runs)|Out-Null
Assert-PP (((Get-Item -LiteralPath $Runs).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Runs cannot be a reparse point'
$Lock=$null
try {
    if($OwnerProfile) {
        Assert-PP (-not $ReopenRun) 'Owner profile and explicit reopen are mutually exclusive'
        $Name='Workbench-'+$ExpectedCandidate.Substring(0,12)+'-'+(Get-PPHash (Join-Path $PackageRoot $script:PPManifestName)).Substring(0,12)+'-'+$Key+'-'+$EngineName+'-'+$Thread+'-slots'+$FullImageSlots+'-'+$RenderingDriver+'-'+$Scene
        $Run=Join-PPSafe $Runs $Name
    } elseif($ReopenRun) { $Run=[IO.Path]::GetFullPath($ReopenRun) }
    else { $Run=Join-PPSafe $Runs ((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,12)) }
    $LockPath=$Run+'.lock'
    if(Test-Path -LiteralPath $LockPath) {
        Assert-PP (((Get-Item -LiteralPath $LockPath).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Profile lock cannot be a reparse point'
    }
    try { $Lock=[IO.File]::Open($LockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch { throw ('Close the Workbench already using this profile. '+$_.Exception.Message) }
    if(-not (Test-Path -LiteralPath $Run)) {
        Assert-PP (-not $ReopenRun) 'Requested reopen directory does not exist'
        New-PFRun $PackageRoot $Manifest $Key $EngineName $Thread $FullImageSlots $RenderingDriver $Scene $Run
    }
    $Record=Test-PFRun $Run $PackageRoot $Manifest
    foreach($Choice in @(@('Source','source',$Key),@('Engine','engine',$EngineName),@('RenderThread','render_thread',$Thread),
            @('FullImageSlots','full_image_slots',$FullImageSlots),@('RenderingDriver','render_driver',$RenderingDriver),@('Scene','scene',$Scene))) {
        if($OwnerProfile -or $PFExplicit.ContainsKey($Choice[0])) { Assert-PP ($Record.($Choice[1]) -ceq $Choice[2]) 'Explicit reopen selection differs' }
    }
    $Item=$Manifest.sources.($Record.source); $SelectedEngine=Get-PFEngine $Manifest $Record.engine
    $Executable=Join-PPSafe $PackageRoot $SelectedEngine.gui.path
    $RunProfile=Join-PPSafe $Run $Record.profile; $Project=Join-PPSafe $Run $Record.project
    $Launch=Join-Path $Run ('launches/'+[Guid]::NewGuid().ToString('N'))
    $Settings=[ordered]@{}; foreach($Entry in $Record.settings.PSObject.Properties) { $Settings[$Entry.Name]=$Entry.Value }
    Invoke-PPProcess $Executable @('--headless','--path',$Project,'--editor','--import','--audio-driver','Dummy','--quit') ($Launch+'-import') $RunProfile $Settings $Item.source_commit 300|Out-Null
    Test-PFRun $Run $PackageRoot $Manifest|Out-Null
    $ImportText=[IO.File]::ReadAllText((Join-Path ($Launch+'-import') 'stdout.log'))+[IO.File]::ReadAllText((Join-Path ($Launch+'-import') 'stderr.log'))
    Assert-PP ($ImportText -notmatch 'ERROR:') 'Strict import diagnostic failure; evidence retained'
    $ReadyPath=Join-Path $Run ('ready-'+[Guid]::NewGuid().ToString('N')+'.json')
    $Settings['CYBERSAND_PLAYABILITY_OWNER_RECEIPT']=$ReadyPath
    if($QuitAfterReady) { $Settings['CYBERSAND_PLAYABILITY_OWNER_QUIT_AFTER_READY']='1' }
    Write-Host ('Opening '+$Record.source+' / '+$Record.engine+' / '+$Record.render_thread+' / Full '+$Record.full_image_slots+' slots / '+$Record.scene)
    Write-Host ('Persistent saves and evidence: '+$Run)
    $Seconds=if($QuitAfterReady) {360} else {0}
    $Process=Invoke-PPProcess $Executable @('--path',$Project,'--rendering-method','gl_compatibility','--rendering-driver',$Record.render_driver,
        '--render-thread',$Record.render_thread,'--audio-driver','Dummy','--script','res://tests/pubpres_playability_owner_start.gd') $Launch $RunProfile $Settings $Item.source_commit $Seconds $ReadyPath 300
    $LaunchText=[IO.File]::ReadAllText((Join-Path $Launch 'stdout.log'))+[IO.File]::ReadAllText((Join-Path $Launch 'stderr.log'))
    Assert-PP ($LaunchText -notmatch 'ERROR:') 'Strict Workbench diagnostic failure; evidence retained'
    Assert-PP (Test-Path -LiteralPath $ReadyPath -PathType Leaf) 'Workbench exited without an installed native World receipt'
    $Ready=Read-PPJson $ReadyPath
    Assert-PP ($Ready.schema -ceq 'pubpres-final-owner-start-v1' -and $Ready.ready -eq $true -and $Ready.source_commit -ceq $Item.source_commit -and
        $Ready.process_id -eq $Process.process_id -and $Ready.native_sha256 -ceq $Item.native.sha256 -and $Ready.rapier_sha256 -ceq $Item.rapier.sha256 -and
        $Ready.engine_sha256 -ceq $SelectedEngine.gui.sha256 -and $Ready.render_thread_inline -eq ($Record.render_thread -ceq 'safe') -and
        $Ready.render_driver -ceq $Record.render_driver -and $Ready.scene -ceq $Record.scene -and
        $Ready.main_sha256 -ceq $Record.files_sha256.'godot/scripts/main.gd' -and
        $Ready.project_sha256 -ceq $Record.files_sha256.'godot/project.godot' -and
        $Ready.observer_sha256 -ceq $Record.files_sha256.'godot/tests/pubpres_playability_owner_start.gd' -and
        $Ready.override_sha256 -ceq $Record.files_sha256.'godot/override.cfg') 'Actual startup process/source/runtime/thread differs'
    $Material=$Ready.material_publication
    Assert-PP ($Material.requested_mode -ceq 'full' -and $Material.backend -ceq 'full' -and $Material.fallback_reason -ceq '') 'Full publication was not installed'
    if($Record.source -ceq 'C') {
        Assert-PP ($Material.full_image_slots -eq $Record.full_image_slots -and $Material.full_image_slots_requested -ceq [string]$Record.full_image_slots) 'Actual Full slot treatment differs'
        $Deadline=$Ready.material_deadline
        Assert-PP ($null -ne $Deadline -and $Deadline.schema -ceq 'pubpres-material-deadline-v1' -and
            $Deadline.requested_hz -eq 0 -and $Deadline.enabled -eq $false -and $Deadline.interval_usec -eq 0 -and
            $Deadline.pending_count -eq 0 -and $Deadline.accepted_uploads -eq 0 -and $Deadline.physical_credit -eq $false) 'Actual material deadline OFF policy differs'
    } else {
        Assert-PP ($null -eq $Ready.material_deadline) 'Frozen donor unexpectedly reports a newer material deadline API'
    }
    $Continuation=$Ready.same_frame_continuation
    Assert-PP ($Continuation.version -eq 1 -and $Continuation.requested -eq $false -and $Continuation.enabled -eq $false -and
        $Continuation.mode -ceq 'off' -and $Continuation.disabled_reason -ceq '' -and $Continuation.wait_usec -eq 0 -and
        $Continuation.new_physics_callbacks -eq 0 -and $Continuation.carried_time_credit -eq $false) 'Continuation OFF policy differs'
    Test-PFRun $Run $PackageRoot $Manifest|Out-Null
    Write-PPJson (Join-Path $Launch 'verified-startup.json') $Ready
    Write-Host ('Closed verified session. Evidence retained: '+$Run)
} finally { if($null -ne $Lock) { $Lock.Dispose() } }
