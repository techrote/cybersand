[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Output)
$OutputPath=[IO.Path]::GetFullPath($Output)
$OriginalRoot=$PSScriptRoot
$Evidence=[ordered]@{schema='pubpres-closure-windows-configuration-v1';source=$env:GITHUB_SHA;
    complete=$false;checks=[Collections.Generic.List[object]]::new();failure=$null;
    scope='Actual Windows PowerShell parser and selector refusal; no application or performance qualification.'}
try {
    foreach($File in Get-ChildItem -LiteralPath $OriginalRoot -Filter '*.ps1') {
        $Tokens=$null;$Errors=$null
        [void][Management.Automation.Language.Parser]::ParseFile($File.FullName,[ref]$Tokens,[ref]$Errors)
        if($Errors.Count -gt 0){throw ($File.Name+': '+($Errors -join '; '))}
        $Evidence.checks.Add(@{name=('parser '+$File.Name);passed=$true})
    }
    . (Join-Path $OriginalRoot 'Start-PUBPRES-Final.ps1') -Library
    $ProductionSelectionPath=$script:PFSelectionPath
    $Original=Read-PPJson $ProductionSelectionPath
    $Temporary=Join-Path ([IO.Path]::GetTempPath()) ('pubpres-owner-config-'+[Guid]::NewGuid().ToString('N')+'.json')
    $script:PFSelectionPath=$Temporary
    $Cases=@(
        @('stock_safe','stock','safe',0,0),
        @('atomic_safe0','atomic','safe',1,0),
        @('atomic_separate0','atomic','separate',1,0),
        @('atomic_separate4','atomic','separate',1,4)
    )
    foreach($Case in $Cases) {
        $Value=$Original|ConvertTo-Json -Depth 12|ConvertFrom-Json
        $Value.architecture=$Case[0];$Value.actual_submission=$Case[3];$Value.render_lookahead=$Case[4]
        $Value.experimental_architecture='atomic_separate4';$Value.water_composition=1
        Write-PPJson $Temporary $Value
        $Settings=Get-PFSettings 'C' $Case[1] $Case[2] 2 'opengl3_angle' 'ordinary' 'Selected'
        Assert-PP ($Settings.CYBERSAND_DIAG_ACTUAL_SUBMISSION -ceq [string]$Case[3] -and
            $Settings.CYBERSAND_ENGINE_RENDER_LOOKAHEAD -ceq [string]$Case[4] -and
            $Settings.CYBERSAND_DIAG_WATER_COMPOSITION -ceq '1') 'Selected actual configuration differs'
        $Fallback=Get-PFSettings 'C' 'stock' 'safe' 2 'opengl3_angle' 'ordinary' 'Fallback'
        Assert-PP ($Fallback.CYBERSAND_DIAG_ACTUAL_SUBMISSION -ceq '0' -and
            $Fallback.CYBERSAND_ENGINE_RENDER_LOOKAHEAD -ceq '0' -and $Fallback.CYBERSAND_DIAG_WATER_COMPOSITION -ceq '0' -and
            $Fallback.CYBERSAND_PLAYABILITY_TASK_COMPLETION_BARRIER -ceq '0') 'Fallback enabled a treatment'
        $Experimental=Get-PFSettings 'C' 'atomic' 'separate' 2 'opengl3_angle' 'ordinary' 'Experimental'
        Assert-PP ($Experimental.CYBERSAND_DIAG_ACTUAL_SUBMISSION -ceq '1' -and
            $Experimental.CYBERSAND_ENGINE_RENDER_LOOKAHEAD -ceq '4') 'Experimental mode differs'
        $Refused=$false
        try{Get-PFSettings 'D' $Case[1] $Case[2] 2 'opengl3_angle' 'ordinary' 'Selected'|Out-Null}catch{$Refused=$true}
        Assert-PP $Refused 'Frozen donor accepted Selected mode'
        $Value.render_lookahead=3;Write-PPJson $Temporary $Value
        $Refused=$false
        try{Get-PFRecoverySelection|Out-Null}catch{$Refused=$true}
        Assert-PP $Refused 'Undeclared budget accepted'
        $Evidence.checks.Add(@{name=$Case[0];passed=$true;selected=$Settings;fallback=$Fallback;experimental=$Experimental})
    }
    $Evidence.complete=$true
} catch {$Evidence.failure=$_.Exception.Message}
finally {
    if(Get-Variable -Name ProductionSelectionPath -ErrorAction SilentlyContinue){$script:PFSelectionPath=$ProductionSelectionPath}
    if((Get-Variable -Name Temporary -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $Temporary)){Remove-Item -LiteralPath $Temporary}
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($OutputPath))|Out-Null
    [IO.File]::WriteAllText($OutputPath,(ConvertTo-Json -InputObject $Evidence -Depth 20)+"`n",[Text.UTF8Encoding]::new($false))
}
if(-not $Evidence.complete){throw ('Windows parser/configuration gate failed: '+$Evidence.failure)}
