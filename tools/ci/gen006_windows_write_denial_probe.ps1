[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateSet('apply','denied-probe','restore','positive-probe')][string]$Mode,
    [Parameter(Mandatory = $true)][Alias('Profile')][string]$ProfilePath,
    [Parameter(Mandatory = $true)][Alias('Backup')][string]$BackupPath,
    [Parameter(Mandatory = $true)][Alias('Output')][string]$ReceiptPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{32}$')][string]$Nonce,
    [ValidatePattern('^(?:[0-9a-f]{64})?$')][string]$ExpectedBackupSha256 = ''
)

# Test apparatus only. The caller owns the live child and must call restore in
# its own finally block. This script never changes an ancestor or child ACL.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$accessSection = [Security.AccessControl.AccessControlSections]::Access
$sidType = [Security.Principal.SecurityIdentifier]
$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$backupState = $null
$applied = $false
$leaveDenied = $false
$preparedReceiptSha256 = ''
$exitCode = 1
$receipt = [ordered]@{
    schema = 'gen006-windows-profile-write-denial-v1'
    mode = $Mode; nonce = $Nonce; helper_pid = $PID; sid = $currentSid
    ok = $false; phase = 'starting'; error = ''; cleanup_error = ''; backup_sha256 = ''
    rights = 278; inheritance = 'None'; propagation = 'None'
    scope = 'Directory-only CREATE_NEW refusal; not disk-full or read-only-volume evidence'
}

function Assert-That([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-NewJson([string]$Path, [object]$Value) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $Value -Depth 12) + "`n")
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
        [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}
function Write-FinalReceipt {
    if ($preparedReceiptSha256 -eq '') {
        Write-NewJson $ReceiptPath $receipt
        return
    }
    Assert-That ((Get-Sha256 $ReceiptPath) -ceq $preparedReceiptSha256) 'Prepared control receipt changed.'
    $temporary = $ReceiptPath + '.terminal-' + $Nonce + '.tmp'
    Write-NewJson $temporary $receipt
    # Same-directory atomic replacement; the backup anchor remains unchanged.
    [IO.File]::Replace($temporary, $ReceiptPath, $null, $true)
}
function Assert-NoReparseAncestors([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    while ($null -ne $item) {
        Assert-That (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'Reparse path refused.'
        if ($item -is [IO.DirectoryInfo]) { $item = $item.Parent } else { $item = $item.Directory }
    }
}
function Get-ProfileAcl {
    $value = Get-Acl -LiteralPath $ProfilePath
    return [ordered]@{
        owner = $value.GetOwner($sidType).Value
        access_sddl = $value.GetSecurityDescriptorSddlForm($accessSection)
        protected = $value.AreAccessRulesProtected
        canonical = $value.AreAccessRulesCanonical
    }
}
function Get-ChildrenAcl {
    $items = @(Get-ChildItem -LiteralPath $ProfilePath -Force | Sort-Object Name)
    Assert-That ($items.Count -le 256) 'Profile entry bound exceeded.'
    foreach ($item in $items) {
        Assert-That (!$item.PSIsContainer -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)) 'Expected a flat ordinary native profile.'
        $value = Get-Acl -LiteralPath $item.FullName
        [ordered]@{ name = $item.Name; owner = $value.GetOwner($sidType).Value
            access_sddl = $value.GetSecurityDescriptorSddlForm($accessSection) }
    }
}
function Same-Json([object]$Left, [object]$Right) {
    return (ConvertTo-Json -InputObject $Left -Depth 12 -Compress) -ceq
        (ConvertTo-Json -InputObject $Right -Depth 12 -Compress)
}
function New-WriteProbe {
    $path = Join-Path $ProfilePath ('acl-probe-' + $Nonce + '-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $result = [ordered]@{ ok = $false; path = $path; phase = 'create'; win32_error = 0
        exception_type = ''; hresult = ''; message = ''; created = $false; bytes_written = 0
        flushed_to_disk = $false; cleanup_ok = $true }
    $stream = $null
    try {
        # FileMode.CreateNew maps to CREATE_NEW. This is a real OS write, not a
        # synthetic Store fault or an inference from ACL formatting.
        $stream = [IO.FileStream]::new($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write,
            [IO.FileShare]::None, 4096, [IO.FileOptions]::WriteThrough)
        $result.created = $true
        $result.phase = 'write'
        $bytes = [Text.Encoding]::ASCII.GetBytes('GEN006 directory write probe')
        $stream.Write($bytes, 0, $bytes.Length)
        $result.bytes_written = $bytes.Length
        $result.phase = 'flush'
        $stream.Flush($true)
        $result.flushed_to_disk = $true
        $result.phase = 'complete'
        $result.ok = $true
    } catch {
        $problem = $_.Exception
        while ($null -ne $problem.InnerException) { $problem = $problem.InnerException }
        $result.exception_type = $problem.GetType().FullName
        $result.hresult = ('0x{0:X8}' -f ($problem.HResult -band 0xffffffffL))
        $result.win32_error = [int]($problem.HResult -band 0xffff)
        $result.message = $problem.Message
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        try {
            if (Test-Path -LiteralPath $path) { [IO.File]::Delete($path) }
            $result.cleanup_ok = !(Test-Path -LiteralPath $path)
        } catch { $result.cleanup_ok = $false }
    }
    return $result
}
function Assert-PositiveProbe([object]$Probe) {
    Assert-That ($Probe.ok -and $Probe.created -and $Probe.bytes_written -gt 0 -and
        $Probe.flushed_to_disk -and $Probe.cleanup_ok -and $Probe.win32_error -eq 0) 'Actual create/write/flush probe failed.'
}
function Assert-DeniedProbe([object]$Probe) {
    Assert-That (!$Probe.ok -and !$Probe.created -and $Probe.phase -eq 'create' -and
        $Probe.win32_error -eq 5 -and $Probe.hresult -eq '0x80070005' -and
        $Probe.exception_type -eq 'System.UnauthorizedAccessException' -and $Probe.cleanup_ok) 'Actual CREATE_NEW was not refused with ERROR_ACCESS_DENIED.'
}
function Restore-OriginalAcl {
    Assert-That ($null -ne $backupState) 'No validated immutable ACL backup.'
    $current = Get-ProfileAcl
    Assert-That ($current.owner -ceq $backupState.original.owner) 'Profile owner changed; restore refused.'
    $value = Get-Acl -LiteralPath $ProfilePath
    $value.SetSecurityDescriptorSddlForm([string]$backupState.original.access_sddl, $accessSection)
    Set-Acl -LiteralPath $ProfilePath -AclObject $value
    $restored = Get-ProfileAcl
    Assert-That (Same-Json $restored $backupState.original) 'Exact original DACL/owner was not restored.'
    return $restored
}

try {
    Assert-That ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) 'Windows-only ACL apparatus.'
    $profileFullPath = [IO.Path]::GetFullPath($ProfilePath)
    Assert-That ($profileFullPath.TrimEnd('\') -ine [IO.Path]::GetPathRoot($profileFullPath).TrimEnd('\')) 'A volume root cannot be a test profile.'
    $ProfilePath = $profileFullPath.TrimEnd('\')
    $BackupPath = [IO.Path]::GetFullPath($BackupPath)
    $ReceiptPath = [IO.Path]::GetFullPath($ReceiptPath)
    $profileItem = Get-Item -LiteralPath $ProfilePath -Force
    Assert-That ($profileItem.PSIsContainer -and $null -ne $profileItem.Parent) 'An existing non-root profile directory is required.'
    Assert-That (!$BackupPath.StartsWith($ProfilePath + '\', [StringComparison]::OrdinalIgnoreCase) -and
        !$ReceiptPath.StartsWith($ProfilePath + '\', [StringComparison]::OrdinalIgnoreCase) -and
        $BackupPath -ine $ReceiptPath -and !(Test-Path -LiteralPath $ReceiptPath)) 'Control files must be new and outside the denied profile.'
    Assert-NoReparseAncestors $ProfilePath
    Assert-NoReparseAncestors ([IO.Path]::GetDirectoryName($BackupPath))
    Assert-NoReparseAncestors ([IO.Path]::GetDirectoryName($ReceiptPath))
    $receipt['profile'] = $ProfilePath
    $receipt['backup'] = $BackupPath
    $receipt['acl_before'] = Get-ProfileAcl
    $receipt['children_before'] = @(Get-ChildrenAcl)
    if ($Mode -eq 'apply') {
        Assert-That (!(Test-Path -LiteralPath $BackupPath) -and $ExpectedBackupSha256 -eq '') 'Apply refuses an existing or stale backup.'
        $receipt['baseline_probe'] = New-WriteProbe
        Assert-PositiveProbe $receipt.baseline_probe
        $value = Get-Acl -LiteralPath $ProfilePath
        Assert-That $value.AreAccessRulesCanonical 'Noncanonical original DACL refused.'
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            [Security.Principal.SecurityIdentifier]::new($currentSid),
            [Security.AccessControl.FileSystemRights]::Write,
            [Security.AccessControl.InheritanceFlags]::None,
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Deny)
        $value.AddAccessRule($rule)
        $backupState = [ordered]@{ schema = 'gen006-windows-profile-write-denial-backup-v1'
            nonce = $Nonce; profile = $ProfilePath; sid = $currentSid
            original = $receipt.acl_before; children = @($receipt.children_before)
            denied_access_sddl = $value.GetSecurityDescriptorSddlForm($accessSection) }
        Write-NewJson $BackupPath $backupState
        $receipt.backup_sha256 = Get-Sha256 $BackupPath
        $receipt['phase'] = 'backup-durable-before-denial'
        Write-NewJson $ReceiptPath $receipt
        $preparedReceiptSha256 = Get-Sha256 $ReceiptPath
        # The outer runner can recover this immutable backup hash even if this
        # process dies during Set-Acl, before a successful final receipt exists.
        $applied = $true
        Set-Acl -LiteralPath $ProfilePath -AclObject $value
        $receipt['acl_after'] = Get-ProfileAcl
        Assert-That ($receipt.acl_after.owner -ceq $backupState.original.owner -and
            $receipt.acl_after.access_sddl -ceq $backupState.denied_access_sddl) 'Applied directory ACL differs from the exact rule.'
        $receipt['probe'] = New-WriteProbe
        Assert-DeniedProbe $receipt.probe
        $receipt['children_after'] = @(Get-ChildrenAcl)
        Assert-That (Same-Json @($receipt.children_after) @($backupState.children)) 'A child ACL changed during directory-only denial.'
        $leaveDenied = $true
    } else {
        if (Test-Path -LiteralPath $BackupPath) {
            Assert-That ($ExpectedBackupSha256 -match '^[0-9a-f]{64}$' -and
                (Get-Sha256 $BackupPath) -ceq $ExpectedBackupSha256) 'Immutable ACL backup identity differs.'
            $backupState = Get-Content -Raw -LiteralPath $BackupPath | ConvertFrom-Json
            Assert-That ($backupState.schema -ceq 'gen006-windows-profile-write-denial-backup-v1' -and
                $backupState.nonce -ceq $Nonce -and $backupState.profile -ceq $ProfilePath -and
                $backupState.sid -ceq $currentSid) 'Backup nonce/profile/SID mismatch.'
            $receipt.backup_sha256 = $ExpectedBackupSha256
        } else {
            Assert-That ($Mode -eq 'positive-probe' -and $ExpectedBackupSha256 -eq '') 'Required immutable backup is missing.'
        }
        if ($Mode -eq 'restore') {
            $receipt['acl_after'] = Restore-OriginalAcl
            $receipt['children_after'] = @(Get-ChildrenAcl)
            Assert-That (Same-Json @($receipt.children_after) @($backupState.children)) 'A child ACL changed during the refused save.'
            $receipt['probe'] = New-WriteProbe
            Assert-PositiveProbe $receipt.probe
        } elseif ($Mode -eq 'denied-probe') {
            Assert-That ($receipt.acl_before.owner -ceq $backupState.original.owner -and
                $receipt.acl_before.access_sddl -ceq $backupState.denied_access_sddl) 'Denied directory identity changed.'
            $receipt['probe'] = New-WriteProbe
            Assert-DeniedProbe $receipt.probe
            $receipt['acl_after'] = Get-ProfileAcl
        } else {
            if ($null -ne $backupState) {
                Assert-That (Same-Json $receipt.acl_before $backupState.original) 'Positive retry requires the exact restored DACL.'
            }
            $receipt['probe'] = New-WriteProbe
            Assert-PositiveProbe $receipt.probe
            $receipt['acl_after'] = Get-ProfileAcl
        }
    }
    $receipt['ok'] = $true
    $receipt['phase'] = 'complete'
    $exitCode = 0
} catch {
    $receipt['error'] = $_.Exception.ToString()
    $receipt['phase'] = 'failed'
} finally {
    if ($Mode -eq 'apply' -and $applied -and !$leaveDenied) {
        try { $receipt['rollback_acl'] = Restore-OriginalAcl }
        catch { $receipt['cleanup_error'] = $_.Exception.ToString() }
    }
    try { Write-FinalReceipt }
    catch { Write-Error ('Cannot retain ACL receipt: ' + $_.Exception.ToString()) -ErrorAction Continue; $exitCode = 1 }
}
Write-Output (ConvertTo-Json -InputObject $receipt -Depth 12 -Compress)
exit $exitCode
