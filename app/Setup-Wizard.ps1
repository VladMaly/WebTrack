# Setup-Wizard.ps1 - friendly setup popup: asks for a mint.ca link + check
# frequency, saves it, installs the background watcher task.
# Scripted use:  Setup-Wizard.ps1 -Url <link> [-IntervalSeconds N] [-InstallDir <dir>] [-SkipTask]
[CmdletBinding()]
param(
    [string]$Url,
    [int]$IntervalSeconds = 0,
    [int]$JitterPercent = 20,   # 0 = fixed timer; 20 = randomize +/-20%
    [string]$InstallDir,
    [switch]$SkipTask
)

$ErrorActionPreference = 'Stop'
$Interactive = [string]::IsNullOrWhiteSpace($Url)
if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA 'WebTrack' }
$ConfigPath   = Join-Path $InstallDir 'products.json'
$UserAgent    = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$SuggestedUrl = 'https://www.mint.ca/en/shop/coins/2026/rose-window-notre-dame-2026-fine-silver-coin'

# researched safe default polling rate (see README); floor keeps it off block-lists
$DefaultIntervalSeconds = 60
$MinIntervalSeconds      = 15

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# curl.exe emits UTF-8; without this, accented product names arrive garbled
# when launched from a double-clicked .bat (OEM codepage console)
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

function Show-Message([string]$Text, [string]$Title, [string]$Icon) {
    if ($Interactive) {
        [void][System.Windows.Forms.MessageBox]::Show($Text, $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]$Icon)
    } else {
        Write-Host ('[{0}] {1}' -f $Title, $Text)
    }
}

function Read-SetupDialog([string]$Message, [string]$Prefill) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'WebTrack setup'
    $form.ClientSize = New-Object System.Drawing.Size(520, 240)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(12, 12)
    $label.Size = New-Object System.Drawing.Size(496, 36)
    $label.Text = $Message

    $box = New-Object System.Windows.Forms.TextBox
    $box.Location = New-Object System.Drawing.Point(12, 54)
    $box.Size = New-Object System.Drawing.Size(496, 23)
    $box.Text = $Prefill

    $freqLabel = New-Object System.Windows.Forms.Label
    $freqLabel.Location = New-Object System.Drawing.Point(12, 92)
    $freqLabel.Size = New-Object System.Drawing.Size(130, 23)
    $freqLabel.Text = 'Check for stock every:'
    $freqLabel.TextAlign = 'MiddleLeft'

    $num = New-Object System.Windows.Forms.NumericUpDown
    $num.Location = New-Object System.Drawing.Point(148, 90)
    $num.Size = New-Object System.Drawing.Size(70, 23)
    $num.Minimum = 1
    $num.Maximum = 999
    $num.Value = $DefaultIntervalSeconds

    $units = New-Object System.Windows.Forms.ComboBox
    $units.Location = New-Object System.Drawing.Point(226, 90)
    $units.Size = New-Object System.Drawing.Size(100, 23)
    $units.DropDownStyle = 'DropDownList'
    [void]$units.Items.AddRange(@('seconds', 'minutes'))
    $units.SelectedIndex = 0

    $randomize = New-Object System.Windows.Forms.CheckBox
    $randomize.Location = New-Object System.Drawing.Point(12, 120)
    $randomize.Size = New-Object System.Drawing.Size(496, 22)
    $randomize.Checked = ($JitterPercent -gt 0)
    $randomize.Text = 'Randomize the timing by ' + $JitterPercent + '% (recommended - looks less like a bot)'

    $hint = New-Object System.Windows.Forms.Label
    $hint.Location = New-Object System.Drawing.Point(12, 146)
    $hint.Size = New-Object System.Drawing.Size(496, 34)
    $hint.ForeColor = [System.Drawing.Color]::DimGray
    $hint.Text = ("Tip: {0} seconds is a safe default. Much faster can get you rate-limited or blocked by the store." -f $DefaultIntervalSeconds)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Start watching'
    $ok.Location = New-Object System.Drawing.Point(292, 196)
    $ok.Size = New-Object System.Drawing.Size(115, 30)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(415, 196)
    $cancel.Size = New-Object System.Drawing.Size(93, 30)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.Controls.AddRange(@($label, $box, $freqLabel, $num, $units, $randomize, $hint, $ok, $cancel))
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel
    # pre-select the suggested link so typing or pasting replaces it cleanly
    $form.Add_Shown({ $box.Focus(); $box.SelectAll() })

    $result = $form.ShowDialog()
    $text = $box.Text
    $seconds = [int]$num.Value
    if ($units.SelectedItem -eq 'minutes') { $seconds = $seconds * 60 }
    $randomizeOn = $randomize.Checked
    $form.Dispose()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return @{ Url = $text; IntervalSeconds = $seconds; Randomize = $randomizeOn }
    }
    return $null
}

function Get-CleanUrl([string]$Raw) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $u = $Raw.Trim().Trim('"')
    if (([regex]::Matches($u, 'https?://')).Count -gt 1) { return $null }   # two links mashed together
    $q = $u.IndexOf('?'); if ($q -ge 0) { $u = $u.Substring(0, $q) }
    $h = $u.IndexOf('#'); if ($h -ge 0) { $u = $u.Substring(0, $h) }
    if ($u -notmatch '^https?://(www\.)?mint\.ca/.+') { return $null }
    return $u
}

try {
    # 1. get the link + how often to check
    $clean = $null
    if ($Interactive) {
        $prefill = $SuggestedUrl   # pre-filled with the Rose Window coin; replace it with any mint.ca link
        $msg = 'This is the item WebTrack will watch. Keep it, or paste a different mint.ca link, then click Start watching:'
        while ($true) {
            $answer = Read-SetupDialog $msg $prefill
            if ($null -eq $answer) { exit 0 }
            $clean = Get-CleanUrl $answer.Url
            if ($clean) {
                $IntervalSeconds = [int]$answer.IntervalSeconds
                if (-not $answer.Randomize) { $JitterPercent = 0 }
                break
            }
            $prefill = $answer.Url
            $msg = "That doesn't look like a mint.ca link (it should start with https://www.mint.ca/). Please paste the full link from your browser's address bar:"
        }
    } else {
        $clean = Get-CleanUrl $Url
        if (-not $clean) { Write-Host 'ERROR: not a valid mint.ca link.'; exit 2 }
    }

    # clamp the interval to a sane floor (blank/0 -> researched default)
    if ($IntervalSeconds -le 0) { $IntervalSeconds = $DefaultIntervalSeconds }
    if ($IntervalSeconds -lt $MinIntervalSeconds) { $IntervalSeconds = $MinIntervalSeconds }
    # jitter to hand to the installer: -1 means "auto 20%", 0 means off
    if ($JitterPercent -le 0) { $jitterSeconds = 0 }
    else { $jitterSeconds = [Math]::Round($IntervalSeconds * $JitterPercent / 100) }

    # 2. look at the page: grab a friendly name, sanity-check it is a product page
    $name = $null
    $verified = $false
    try {
        $html = (& curl.exe -sL --compressed --max-time 30 -A $UserAgent -- $clean) -join "`n"
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($html)) {
            if ($html -match 'data-pwr-in-stock="') { $verified = $true }
            if ($html -match '<title>([^<]+)</title>') {
                $t = [System.Net.WebUtility]::HtmlDecode($Matches[1])
                $name = ($t -split '\|')[0].Trim()
            }
        }
    } catch { }
    if ([string]::IsNullOrWhiteSpace($name)) {
        $slug = ($clean.TrimEnd('/') -split '/')[-1]
        $name = (($slug -replace '-', ' ')).Trim()
        if ($name.Length -gt 1) { $name = $name.Substring(0, 1).ToUpper() + $name.Substring(1) }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $clean }
    }

    # 3. WebTrack watches exactly what was entered - the new link REPLACES any previous one
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
    @{ products = @(@{ name = $name; url = $clean }) } | ConvertTo-Json -Depth 5 |
        Set-Content -Path $ConfigPath -Encoding UTF8

    # 4. install / refresh the background task and run a first check right away
    if (-not $SkipTask) {
        $installer = Join-Path $InstallDir 'Install-Task.ps1'
        if (-not (Test-Path $installer)) { throw "Install-Task.ps1 not found in $InstallDir" }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -IntervalSeconds $IntervalSeconds -JitterSeconds $jitterSeconds | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'the background task could not be created.' }
        Start-ScheduledTask -TaskName 'WebTrack Stock Watcher'

        # friendly Start Menu entries with real icons (.bat files cannot carry their own icon)
        try {
            $smDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'WebTrack'
            if (-not (Test-Path $smDir)) { New-Item -ItemType Directory -Path $smDir -Force | Out-Null }
            $shell = New-Object -ComObject WScript.Shell
            $oldLnk = Join-Path $smDir 'WebTrack - watch another item.lnk'
            if (Test-Path $oldLnk) { Remove-Item $oldLnk -Force }
            $add = $shell.CreateShortcut((Join-Path $smDir 'WebTrack - change watched item.lnk'))
            $add.TargetPath = Join-Path $InstallDir '_INSTALL.bat'
            $add.WorkingDirectory = $InstallDir
            $add.IconLocation = "$env:SystemRoot\System32\msiexec.exe,0"
            $add.Description = 'Watch a different mint.ca item with WebTrack'
            $add.Save()
            $rem = $shell.CreateShortcut((Join-Path $smDir 'WebTrack - uninstall.lnk'))
            $rem.TargetPath = Join-Path $InstallDir '_UNINSTALL.bat'
            $rem.WorkingDirectory = $InstallDir
            $rem.IconLocation = "$env:SystemRoot\System32\shell32.dll,31"
            $rem.Description = 'Remove WebTrack completely'
            $rem.Save()
        } catch { }

        # webtrack: protocol makes the notifications' "Uninstall WebTrack" button work
        try {
            $protoKey = 'HKCU:\SOFTWARE\Classes\webtrack'
            New-Item -Path "$protoKey\shell\open\command" -Force | Out-Null
            Set-ItemProperty -Path $protoKey -Name '(default)' -Value 'URL:WebTrack'
            Set-ItemProperty -Path $protoKey -Name 'URL Protocol' -Value ''
            Set-ItemProperty -Path "$protoKey\shell\open\command" -Name '(default)' -Value `
                ('powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{0}" "%1"' -f (Join-Path $InstallDir 'Uninstall-Quiet.ps1'))
        } catch { }
    }

    # 5. tell the human what is happening
    if ($IntervalSeconds -ge 60 -and $IntervalSeconds % 60 -eq 0) {
        $mins = $IntervalSeconds / 60
        $every = if ($mins -eq 1) { 'every minute' } else { ('every {0} minutes' -f $mins) }
    } else {
        $every = ('every {0} seconds' -f $IntervalSeconds)
    }
    $randomNote = if ($jitterSeconds -gt 0) { ' (with a little random wobble so it does not look like a bot)' } else { '' }
    $lines = @()
    $lines += ('WebTrack is now watching: {0}' -f $name)
    $lines += ''
    $lines += ('It quietly checks {0}{1}. The moment it can be ordered you will get a Windows notification - click it to open the page and buy.' -f $every, $randomNote)
    if (-not $verified) {
        $lines += ''
        $lines += 'Note: that link did not look exactly like a normal product page, but it will be watched anyway.'
    }
    $lines += ''
    $lines += 'To watch a different item later, open "WebTrack - change watched item" from the Start Menu (or run _INSTALL.bat again). The new link replaces the old one.'
    Show-Message ($lines -join "`r`n") 'WebTrack is running!' 'Information'
    exit 0
}
catch {
    Show-Message ("Setup hit a problem: " + $_.Exception.Message + "`r`n`r`nPlease send a photo of this message to whoever gave you WebTrack.") 'WebTrack setup problem' 'Error'
    exit 1
}
