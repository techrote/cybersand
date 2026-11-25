# GENTEK-WINDOWS-FINAL-B | offline Windows owner verifier. PowerShell 5.1, no network/admin/Python.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][ValidateSet('VerifyArchive','Extract','VerifyPayload','Launch','NewChecklist','Collect')][string]$Action,
 [string]$ArchivePath, [string]$ExpectedArchiveSha256, [string]$Destination,
 [string]$PackagePath, [string]$ExpectedSource, [string]$ExpectedManifestSha256, [string]$ResultsDirectory,
 [string]$DecisionsPath, [string[]]$EvidenceFiles=@(), [string]$Renderer='NOT RECORDED',
 [string]$FrameIntervalsCsv, [string]$FrameCaptureTool='NOT RECORDED'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$checks=@('original-archive-sha256','payload-inventory-and-launch','eight-showcase-selections',
 'six-repaired-classic','generate-preview-install','preview-cancellation','paint-erase',
 'seed-variation-return','bay-floor-wall-variation','five-style-project-a','five-style-project-b',
 'negative-origin','save-editable-projects','save-named-starts','close-all-packaged-processes',
 'fresh-process-reopen-all-four','restored-identity-parameters-material','rendered-frame-review',
 'physical-nvidia-performance','legacy-generator-regressions')
function Require-Hash([string]$h,[string]$name) {
 if($h -cnotmatch '^[0-9a-fA-F]{64}$'){throw "$name must be a SHA-256 hex digest"}
}
function Require-Commit([string]$c,[string]$name) {
 if($c -cnotmatch '^[0-9a-f]{40}$'){throw "$name requires an exact 40-digit Git commit"}
}
function Hash([string]$path){
  # .NET stream hashing avoids PowerShell module autoload differences on hosted Windows.
  $f=[IO.File]::OpenRead($path)
  $h=[Security.Cryptography.SHA256]::Create()
  try{ return ([BitConverter]::ToString($h.ComputeHash($f))).Replace('-','').ToLowerInvariant() }
  finally{ $h.Dispose(); $f.Dispose() }
}
function Member([string]$name,[bool]$dir=$false){
 if([string]::IsNullOrWhiteSpace($name)){throw 'Empty archive member'}
 $n=$name.Replace('\','/')
 if($dir){$n=$n.TrimEnd('/')}
 if($n.StartsWith('/') -or $n.Contains('//') -or $n.Contains(':') -or
    $n -match '[\x00-\x1f\x7f<>"|?*]' -or $n.EndsWith('/')){
   throw "Unsafe archive path: $name"
 }
 foreach($part in $n.Split('/')){
   if($part -in @('','.','..') -or $part.EndsWith('.') -or $part.EndsWith(' ') -or
      $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)'){
     throw "Unsafe Windows archive path: $name"
   }
 }
 return $n
}
function Safe-Path([string]$root,[string]$name){
 $b=[IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar)
 $p=[IO.Path]::GetFullPath((Join-Path $b ($name.Replace('/',[IO.Path]::DirectorySeparatorChar))))
 if(-not $p.StartsWith($b+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Escaped archive path: $name"}
 $q=$p
 while($q.Length -ge $b.Length){
   if(Test-Path -LiteralPath $q){
     if((Get-Item -LiteralPath $q -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse point in package path: $name"}
   }
   if($q -eq $b){break}
   $q=[IO.Path]::GetDirectoryName($q)
 }
 return $p
}
function Zip-Checked([string]$archive,[string]$expected){
 Require-Hash $expected 'ExpectedArchiveSha256'
 $p=(Resolve-Path -LiteralPath $archive).Path
 if((Hash $p) -ne $expected.ToLowerInvariant()){throw 'Original ZIP SHA-256 mismatch (independent expected hash required)'}
 $z=[IO.Compression.ZipFile]::OpenRead($p)
 try{
   $names=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   [long]$total=0; $count=0
   foreach($e in $z.Entries){
     $dir=$e.FullName.EndsWith('/') -or $e.FullName.EndsWith('\')
     $name=Member $e.FullName $dir
     if(-not $names.Add($name)){throw "Duplicate or case-conflicting ZIP member: $name"}
     if((($e.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000){throw "Symlink ZIP member rejected: $name"}
     if(-not $dir){
       $count++;$total+=$e.Length
       if($e.Length -gt 536870912 -or ($e.CompressedLength -eq 0 -and $e.Length -gt 0)){throw "Invalid ZIP member size: $name"}
     }
     if($count -gt 10000 -or $total -gt 4294967296){throw 'Excessive ZIP contents'}
   }
   if($count -lt 100 -or -not $names.Contains('candidate-manifest.json')){throw 'Incomplete ZIP inventory'}
   return @{zip=$z; path=$p; count=$count}
 }catch{$z.Dispose();throw}
}
function Verify([string]$root,[string]$expected,[string]$manifestPin=''){
 Require-Commit $expected 'ExpectedSource'
 $base=(Resolve-Path -LiteralPath $root).Path
 $manifest=Safe-Path $base 'candidate-manifest.json'
 # Separately pinning the manifest prevents payload + manifest co-tampering.
 if(-not [string]::IsNullOrWhiteSpace($manifestPin)){
   Require-Hash $manifestPin 'ExpectedManifestSha256'
   if((Hash $manifest) -ne $manifestPin.ToLowerInvariant()){throw 'Independently pinned candidate-manifest SHA-256 mismatch'}
 }
 $m=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
 if($m.schema -ne 1 -or $m.godot_version -cne '4.7.stable.official.5b4e0cb0f'){throw 'Godot/manifest schema mismatch'}
 if($m.source_commit -cne $expected){throw 'Source revision differs from owner-pinned accepted SHA'}
 Require-Commit $m.source_tree 'Source tree'
 Require-Hash $m.native_sha256 'Native runtime'
 $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 $allowedPaths=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 $entries=@($m.files_sha256.PSObject.Properties)
 if($entries.Count -lt 100){throw 'Incomplete file hash manifest'}
 foreach($e in $entries){
   $name=Member $e.Name
   if(-not $seen.Add($name)){throw "Duplicate manifest entry: $name"}
   Require-Hash ([string]$e.Value) "Manifest member $name"
   $path=Safe-Path $base $name
   [void]$allowedPaths.Add([IO.Path]::GetFullPath($path))
   if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing package component: $name"}
   if((Hash $path) -ne ([string]$e.Value).ToLowerInvariant()){throw "Tampered package component: $name"}
 }
 $native='godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll'
 $mandatory=@('Godot_v4.7-stable_win64.exe','Godot_v4.7-stable_win64_console.exe',
   'Open Workbench.cmd','Verify and Open Workbench.cmd','READ-ME.md',
   'OWNER-ACCEPTANCE.md','tools/acceptance/gentek80_owner.ps1',
   'docs/operations/gentek80-physical-owner-acceptance.md',
   'vcruntime140.dll','godot/project.godot',
   'source-built-candidate-provenance.json',$native,
   'godot/addons/godot-rapier2d/bin/libgodot_rapier.windows.x86_64-pc-windows-msvc.dll')
 foreach($name in $mandatory){if(-not $seen.Contains($name)){throw "Missing required component: $name"}}
 if((Hash (Safe-Path $base $native)) -ne $m.native_sha256.ToLowerInvariant()){throw 'Native binary hash/source mismatch'}
 $proof=Get-Content -LiteralPath (Safe-Path $base 'source-built-candidate-provenance.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 if($proof.source_commit -cne $expected -or $proof.source_tree -cne $m.source_tree -or
    $proof.sha256 -cne $m.native_sha256){throw 'Native source/build provenance disagrees with candidate'}
 $cacheRoot=[IO.Path]::GetFullPath((Join-Path $base 'godot/.godot')).TrimEnd('\')+'\'
 foreach($f in Get-ChildItem -LiteralPath $base -File -Recurse -Force){
   $full=[IO.Path]::GetFullPath($f.FullName)
   if($full -eq [IO.Path]::GetFullPath($manifest) -or
      $full.StartsWith($cacheRoot,[StringComparison]::OrdinalIgnoreCase)){continue}
   if(-not $allowedPaths.Contains($full)){
     throw "Unexpected untracked package member: $full (base $base)"
   }
 }
 return @{source=$m.source_commit; tree=$m.source_tree; native=$m.native_sha256;
    gui=(Hash (Safe-Path $base 'Godot_v4.7-stable_win64.exe')); files=$entries.Count; root=$base;
    godot=$m.godot_version}
}
function Write-Json([string]$path,[object]$object){
 $data=ConvertTo-Json -InputObject $object -Depth 14
 [IO.File]::WriteAllText($path,$data+[Environment]::NewLine,[System.Text.UTF8Encoding]::new($false))
}
function Collect([string]$root,[string]$dst,[string]$source,[string]$decisions){
 Require-Commit $source 'ExpectedSource'
 if(Test-Path -LiteralPath $dst){throw 'Refusing to overwrite an existing results directory'}
 $root=(Resolve-Path -LiteralPath $root).Path
 if([IO.Path]::GetFullPath($dst).StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){
   throw 'Results directory must be outside immutable evaluator'
 }
 $d=Get-Content -LiteralPath $decisions -Raw -Encoding UTF8 | ConvertFrom-Json
 $cases=@($d.cases)
 if($d.schema -cne 'gentek80-owner-decisions-v1' -or $cases.Count -ne $checks.Count){throw 'Wrong/incomplete owner decisions schema'}
 for($i=0;$i -lt $checks.Count;$i++){
   if($cases[$i].id -cne $checks[$i] -or $cases[$i].decision -cnotin @('PASS','FAIL','SKIP')){
     throw "Missing explicit PASS/FAIL/SKIP for: $($checks[$i])"
   }
 }
 $identity=$null;$identityError=$null
 try{$identity=Verify $root $source $ExpectedManifestSha256}catch{$identityError=$_.Exception.Message}
 $frameStats=$null
 if($FrameIntervalsCsv){
   $rows=@(Import-Csv -LiteralPath $FrameIntervalsCsv)
   if($rows.Count -lt 100){throw 'Frame CSV requires 100+ original frame_ms samples'}
   $samples=New-Object 'System.Collections.Generic.List[double]'
   foreach($r in $rows){
     if($null -eq $r.PSObject.Properties['frame_ms']){throw 'Frame CSV must contain frame_ms'}
     $v=[double]::Parse([string]$r.frame_ms,[Globalization.CultureInfo]::InvariantCulture)
     if([double]::IsNaN($v) -or [double]::IsInfinity($v) -or $v -le 0 -or $v -gt 60000){throw 'Invalid real frame interval'}
     $samples.Add($v)
   }
   $samples.Sort();$n=$samples.Count
   $frameStats=@{count=$n;p50_ms=$samples[[int][Math]::Ceiling($n*.5)-1];
     p95_ms=$samples[[int][Math]::Ceiling($n*.95)-1];
     p99_ms=$samples[[int][Math]::Ceiling($n*.99)-1]; worst_ms=$samples[$n-1];
     csv_sha256=(Hash ((Resolve-Path -LiteralPath $FrameIntervalsCsv).Path));
     capture_tool_owner_entered=$FrameCaptureTool;scope='Owner-supplied, NOT harness-measured'}
 }
 $copy=@()
 [IO.Directory]::CreateDirectory((Join-Path $dst 'selected-evidence'))|Out-Null
 $names=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
 foreach($p in $EvidenceFiles){
   $i=Get-Item -LiteralPath $p
   if($i.PSIsContainer -or $i.Length -gt 104857600 -or $i.Extension.ToLowerInvariant() -notin @('.png','.jpg','.jpeg','.log','.json','.csv','.txt')){
     throw "Unsupported selected evidence file: $($i.Name)"
   }
   if(-not $names.Add($i.Name)){throw "Duplicate evidence basename: $($i.Name)"}
   $target=Join-Path $dst ('selected-evidence/'+$i.Name)
   Copy-Item -LiteralPath $p -Destination $target
   $copy+=@{name=$i.Name;bytes=$i.Length;sha256=(Hash $target)}
 }
 $os=@{};$gpu=@();$dpi=$null
 try{$o=Get-CimInstance Win32_OperatingSystem;$os=@{name=$o.Caption;build=$o.BuildNumber;version=$o.Version;arch=$o.OSArchitecture}}catch{$os=@{unavailable=$_.Exception.Message}}
 try{$gpu=@(Get-CimInstance Win32_VideoController|ForEach-Object{@{name=$_.Name;driver_version=$_.DriverVersion;driver_date=[string]$_.DriverDate}})}catch{$gpu=@(@{unavailable=$_.Exception.Message})}
 try{$dpi=(Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' -Name LogPixels -ErrorAction Stop).LogPixels}catch{$dpi=$null}
 # PASS labels alone do not establish physical owner acceptance.
 $metadataIssues=New-Object 'System.Collections.Generic.List[string]'
 # A self-consistent package is not evidence of independent archive provenance.
 # This is an owner-PASS admission guard, not a requirement for SKIP/FAIL reports.
 if([string]::IsNullOrWhiteSpace($ExpectedManifestSha256)){
   $metadataIssues.Add('Independently authenticated manifest SHA-256 not supplied')
 }
 if($ArchivePath -and -not $ExpectedArchiveSha256){
   $metadataIssues.Add('Original archive supplied without independently authenticated ZIP SHA-256')
 }
 if(-not $ArchivePath -and $ExpectedArchiveSha256){
   $metadataIssues.Add('Expected ZIP SHA-256 supplied without the original archive')
 }
 $archiveDigest=$null; $archiveError=$null
 if($ArchivePath){
   try {
     $archiveDigest=Hash ((Resolve-Path -LiteralPath $ArchivePath).Path)
     if($ExpectedArchiveSha256){
       Require-Hash $ExpectedArchiveSha256 'ExpectedArchiveSha256'
       if($archiveDigest -ne $ExpectedArchiveSha256.ToLowerInvariant()){
         throw 'Original archive differs from independently authenticated ZIP SHA-256'
       }
       $checkedArchive=Zip-Checked $ArchivePath $ExpectedArchiveSha256
       try{
         # The independently authenticated original ZIP must be the archive
         # that supplied THIS verified extracted package, not merely a second
         # unrelated (but correctly hashed) ZIP from a different build.
         $zipManifest=$checkedArchive.zip.GetEntry('candidate-manifest.json')
         if($null -eq $zipManifest){throw 'Original ZIP lacks root candidate-manifest.json'}
         $stream=$zipManifest.Open()
         $algorithm=[Security.Cryptography.SHA256]::Create()
         try{
           $zipManifestSha=([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant()
         }finally{$stream.Dispose();$algorithm.Dispose()}
         $installedManifestSha=Hash (Safe-Path $root 'candidate-manifest.json')
         if($zipManifestSha -ne $installedManifestSha){
           throw 'Original ZIP manifest does not match verified extracted package manifest'
         }
         $archiveDigest=Hash $checkedArchive.path
       }finally{ $checkedArchive.zip.Dispose() }
     }
   }catch{ $archiveError=$_.Exception.Message }
 }
 $projects=@($d.projects); $maps=@($d.maps)
 if($projects.Count -ne 2 -or $maps.Count -ne 2){
   $metadataIssues.Add('Two projects and two named starts not recorded')
 }else{
   $names=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   $compositions=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   $negative=$false
   foreach($p in $projects){
     if([string]::IsNullOrWhiteSpace([string]$p.name) -or -not $names.Add([string]$p.name)){
       $metadataIssues.Add('Project names missing or duplicates')
     }
     $styles=@($p.styles)
     if($styles.Count -ne 5 -or @($styles | Select-Object -Unique).Count -ne 5 -or
        @($styles | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -gt 0){
       $metadataIssues.Add('Project requires five distinct named styles')
     }
     if(-not $compositions.Add((@($styles | Sort-Object) -join '|'))){
       $metadataIssues.Add('Two project compositions must differ')
     }
     if($null -eq $p.seed){$metadataIssues.Add('Project seed not recorded')}
     $origin=@($p.origin)
     if($origin.Count -ne 2){
       $metadataIssues.Add('Two signed origin coordinates required')
     }elseif(([double]$origin[0] -lt 0) -or ([double]$origin[1] -lt 0)){$negative=$true}
   }
   if(-not $negative){$metadataIssues.Add('Negative origin not recorded')}
   $mapNames=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   foreach($m in $maps){
     if([string]::IsNullOrWhiteSpace([string]$m.name) -or -not $mapNames.Add([string]$m.name) -or
        -not $names.Contains([string]$m.project)){
       $metadataIssues.Add('Both starting map names and project links required')
     }
   }
 }
 if($Renderer -ceq 'NOT RECORDED'){$metadataIssues.Add('Actual renderer not recorded')}
 if(-not $frameStats){$metadataIssues.Add('Original frame interval sample not supplied')}
 if(@($copy | Where-Object {$_.name -match '(?i)\.(png|jpe?g)$'}).Count -eq 0){
   $metadataIssues.Add('No owner-selected genuine screenshots')
 }
 if(@($gpu | Where-Object {$_.name -match '(?i)nvidia'}).Count -eq 0 -or
    [string]$os.name -notmatch '(?i)windows 11'){
   $metadataIssues.Add('No physical Windows 11/NVIDIA environment evidenced')
 }
 $status='OWNER-PASS-RECORDED'
 if(@($cases | Where-Object {$_.decision -eq 'SKIP'}).Count -gt 0 -or
    $metadataIssues.Count -gt 0){$status='INCOMPLETE'}
 if(@($cases | Where-Object {$_.decision -eq 'FAIL'}).Count -gt 0){$status='OWNER-FAILED'}
 if($identityError -or $archiveError){$status='PACKAGE-REJECTED'}
 Write-Json (Join-Path $dst 'gentek80-owner-report.json') @{
   schema='gentek80-physical-owner-evidence-v1';created_utc=(Get-Date).ToUniversalTime().ToString('o');
   status=$status;source_pinned=$source;verification=$identity;verification_error=$identityError;
   decisions=$d;owner_metadata_issues=@($metadataIssues);operating_system=$os;graphics_devices=$gpu;dpi_logical=$dpi;
   renderer_owner_entered=$Renderer;owner_supplied_frame_intervals=$frameStats;evidence_files=$copy;
   archive_sha256=$archiveDigest;
   independent_archive_pin=$(if($ExpectedArchiveSha256){$ExpectedArchiveSha256.ToLowerInvariant()}else{$null});
   archive_verification_error=$archiveError;
   independently_pinned_manifest=(-not [string]::IsNullOrWhiteSpace($ExpectedManifestSha256));
   notice='No upload, synthesized input, screenshot or frame measurements; owner selects files and decisions'
 }
 Write-Output "OWNER EVIDENCE EXPORTED: $dst status=$status"
}
switch($Action){
 'VerifyArchive'{
    $z=Zip-Checked $ArchivePath $ExpectedArchiveSha256
    try{Write-Output "ARCHIVE VERIFIED: $($z.count) files sha256=$($ExpectedArchiveSha256.ToLowerInvariant())"}
    finally{$z.zip.Dispose()}
 }
 'Extract'{
   if(-not $Destination -or (Test-Path -LiteralPath $Destination)){throw 'Extract destination must be new'}
   $z=Zip-Checked $ArchivePath $ExpectedArchiveSha256
   $stage=$null
   try{
     # Stage on the destination volume. Validate every byte and source receipt
     # before a single directory rename makes the final installation visible.
     $final=[IO.Path]::GetFullPath($Destination).TrimEnd('\')
     $parent=[IO.Path]::GetDirectoryName($final)
     if([string]::IsNullOrWhiteSpace($parent)){throw 'Destination parent is required'}
     [IO.Directory]::CreateDirectory($parent)|Out-Null
     $stage=Join-Path $parent ('.gentek80-staging-'+[Guid]::NewGuid().ToString('N'))
     [IO.Directory]::CreateDirectory($stage)|Out-Null
     foreach($e in $z.zip.Entries){
       $dir=$e.FullName.EndsWith('/') -or $e.FullName.EndsWith('\')
       $name=Member $e.FullName $dir
       $path=Safe-Path $stage $name
       if($dir){[IO.Directory]::CreateDirectory($path)|Out-Null;continue}
       [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null
       $out=[IO.File]::Open($path,[IO.FileMode]::CreateNew)
       $input=$e.Open()
       try{$input.CopyTo($out)}finally{$input.Dispose();$out.Dispose()}
     }
     if((Hash $z.path) -ne $ExpectedArchiveSha256.ToLowerInvariant()){throw 'ZIP changed during extraction'}
     $x=Verify $stage $ExpectedSource $ExpectedManifestSha256
     if(Test-Path -LiteralPath $final){throw 'Destination appeared during verification; refusing overwrite'}
     [IO.Directory]::Move($stage,$final)
     $stage=$null
     Write-Output "EXTRACTED AND VERIFIED: source=$($x.source) files=$($x.files)"
   }finally{
     $z.zip.Dispose()
     if($stage -and (Test-Path -LiteralPath $stage)){[IO.Directory]::Delete($stage,$true)}
   }
 }
 'VerifyPayload'{
   if(-not $ExpectedManifestSha256){Write-Warning 'No external manifest pin: self-consistency check only; authenticate the original ZIP independently'}
   $x=Verify $PackagePath $ExpectedSource $ExpectedManifestSha256;Write-Output "PAYLOAD VERIFIED: source=$($x.source) native=$($x.native)"}
 'Launch'{
   if(-not $ExpectedManifestSha256){Write-Warning 'Embedded launcher cannot authenticate itself: use an independently pinned original ZIP or manifest hash'}
   $x=Verify $PackagePath $ExpectedSource $ExpectedManifestSha256
   $gui=Safe-Path $x.root 'Godot_v4.7-stable_win64.exe'
   $console=Safe-Path $x.root 'Godot_v4.7-stable_win64_console.exe'
   $project=Safe-Path $x.root 'godot'
   # Isolate only this evaluator's child processes. The stable source + native
   # identity makes two fresh launches reopen the same test starts without
   # reading or modifying another CyberSand user's ordinary save directory.
   $userBase=[Environment]::GetFolderPath('LocalApplicationData')
   if([string]::IsNullOrWhiteSpace($userBase)){throw 'Windows user-local application data directory unavailable'}
   $tag=$ExpectedSource.Substring(0,12)+'-'+$x.native.Substring(0,12)
   $profileRoot=Join-Path $userBase ('CyberSand-Gentek80-Owner-'+$tag)
   $local=Join-Path $profileRoot 'Local'
   $roaming=Join-Path $profileRoot 'Roaming'
   [IO.Directory]::CreateDirectory($local)|Out-Null
   [IO.Directory]::CreateDirectory($roaming)|Out-Null
   $env:LOCALAPPDATA=$local
   $env:APPDATA=$roaming
   $env:CYBERSAND_SOURCE_REVISION=$ExpectedSource
   $v=(& $console --version|Out-String).Trim()
   if($LASTEXITCODE -ne 0 -or $v -cne $x.godot){throw "Wrong Godot binary/version: $v"}
   & $console --headless --path $project --editor --quit
   if($LASTEXITCODE -ne 0){throw 'Bundled Godot import failed, no GUI started'}
   $null=Verify $x.root $ExpectedSource $ExpectedManifestSha256
   Write-Output "ISOLATED OWNER PROFILE: $profileRoot (source/native matched)"
   $p=Start-Process -FilePath $gui -WorkingDirectory $x.root -ArgumentList @('--path',('"'+$project+'"'),'--','--workbench') -PassThru
   Write-Output "PACKAGED WORKBENCH STARTED: PID=$($p.Id); close this GUI to finish"
   $p.WaitForExit()
   Write-Output "PACKAGED WORKBENCH EXITED: PID=$($p.Id); exit=$($p.ExitCode)"
 }
 'NewChecklist'{
   if(Test-Path -LiteralPath $ResultsDirectory){throw 'Checklist directory must be new'}
   [IO.Directory]::CreateDirectory($ResultsDirectory)|Out-Null
   $cases=@();foreach($id in $checks){$cases+=@{id=$id;decision=$null;notes=''}}
   Write-Json (Join-Path $ResultsDirectory 'owner-decisions.json') @{
     schema='gentek80-owner-decisions-v1';cases=$cases;
     projects=@(@{name='';styles=@();seed=$null;origin=@()},@{name='';styles=@();seed=$null;origin=@()});
     maps=@(@{name='';project=''},@{name='';project=''});
     instructions='Set each decision to explicit PASS, FAIL or SKIP; no automatic owner approval'
   }
   Write-Output "NEW CHECKLIST: $ResultsDirectory"
 }
 'Collect'{Collect $PackagePath $ResultsDirectory $ExpectedSource $DecisionsPath}
}