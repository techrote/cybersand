param([string]$ReviewRoot = $PSScriptRoot, [switch]$SelfTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
function Test-KeyEntry([string]$Value) {
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value.Trim() -notmatch '\s'
}
$form = New-Object System.Windows.Forms.Form
$form.Text = 'CyberSand - local API key'
$form.ClientSize = New-Object System.Drawing.Size(590,200)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true
$label = New-Object System.Windows.Forms.Label
$label.SetBounds(16,14,555,42)
$label.Text = 'Paste your OpenAI project API key. It stays in the local launcher/app environment and is not saved. API calls begin only after Start in CyberSand.'
$form.Controls.Add($label)
$keyBox = New-Object System.Windows.Forms.TextBox
$keyBox.SetBounds(16,64,455,26)
$keyBox.UseSystemPasswordChar = $true
$keyBox.ShortcutsEnabled = $true
$form.Controls.Add($keyBox)
$paste = New-Object System.Windows.Forms.Button
$paste.SetBounds(480,62,92,28)
$paste.Text = 'Paste key'
$paste.Add_Click({ $keyBox.Clear(); $keyBox.Paste(); $keyBox.Focus() })
$form.Controls.Add($paste)
$status = New-Object System.Windows.Forms.Label
$status.SetBounds(16,100,555,30)
$status.Text = 'The key is hidden. Press Launch CyberSand when ready.'
$form.Controls.Add($status)
$launch = New-Object System.Windows.Forms.Button
$launch.SetBounds(300,150,170,32)
$launch.Text = 'Launch CyberSand'
$launch.Add_Click({
    if (-not (Test-KeyEntry $keyBox.Text)) {
        $status.ForeColor = [System.Drawing.Color]::DarkRed
        $status.Text = 'Enter a key first; remove spaces or line breaks inside it.'
        $keyBox.Focus()
        return
    }
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})
$form.Controls.Add($launch)
$form.AcceptButton = $launch
$cancel = New-Object System.Windows.Forms.Button
$cancel.SetBounds(480,150,92,32)
$cancel.Text = 'Cancel'
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancel)
$form.CancelButton = $cancel
$form.Add_Shown({ $keyBox.Focus() })
if ($SelfTest) {
    if (-not $keyBox.UseSystemPasswordChar -or -not $keyBox.ShortcutsEnabled) { throw 'Password control configuration failed' }
    if ((Test-KeyEntry '') -or (Test-KeyEntry 'bad key') -or -not (Test-KeyEntry 'dummy-not-real')) { throw 'Key validation failed' }
    $keyBox.Text = 'dummy-not-real'
    $keyBox.Clear()
    if ($keyBox.Text.Length -ne 0) { throw 'Cleanup failed' }
    $form.Dispose()
    Write-Output 'LOCAL_KEY_DIALOG_SELF_TEST PASS. No dialog, real key, app launch or API call.'
    exit 0
}
$enteredKey = $null
try {
    if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }
    $enteredKey = $keyBox.Text.Trim()
}
finally { $keyBox.Clear(); $form.Dispose() }
if (-not (Test-KeyEntry $enteredKey)) { throw 'No key entered; app was not launched.' }
$engine = Join-Path $ReviewRoot 'Godot_console.exe'
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) { throw 'Bundled engine missing.' }
$previousKey = [Environment]::GetEnvironmentVariable('OPENAI_API_KEY','Process')
try {
    [Environment]::SetEnvironmentVariable('OPENAI_API_KEY',$enteredKey,'Process')
    $enteredKey = $null
    if ([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) { throw 'Local key setup failed; app was not launched.' }
    Write-Host 'Local key loaded (value hidden). Launching a new CyberSand instance.'
    & $engine --path (Join-Path $ReviewRoot 'godot') --rendering-method gl_compatibility --audio-driver Dummy -- --workbench
    $engineExit = $LASTEXITCODE
}
finally {
    [Environment]::SetEnvironmentVariable('OPENAI_API_KEY',$previousKey,'Process')
    $enteredKey = $null
    $previousKey = $null
}
exit $engineExit
