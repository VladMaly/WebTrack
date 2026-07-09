# Setup-Wizard.ps1 - friendly setup popup: asks for a mint.ca link, saves it,
# installs the background watcher task. Non-coders only ever see small windows.
# Scripted use:  Setup-Wizard.ps1 -Url <link> [-InstallDir <dir>] [-SkipTask]
[CmdletBinding()]
param(
    [string]$Url,
    [string]$InstallDir,
    [switch]$SkipTask
)

$ErrorActionPreference = 'Stop'
$Interactive = [string]::IsNullOrWhiteSpace($Url)
if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA 'WebTrack' }
$ConfigPath   = Join-Path $InstallDir 'products.json'
$UserAgent    = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$SuggestedUrl = 'https://www.mint.ca/en/shop/coins/2026/rose-window-notre-dame-2026-fine-silver-coin'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Message([string]$Text, [string]$Title, [string]$Icon) {
    if ($Interactive) {
        [void][System.Windows.Forms.MessageBox]::Show($Text, $Title,
            [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]$Icon)
    } else {
        Write-Host ('[{0}] {1}' -f $Title, $Text)
    }
}

function Read-UrlDialog([string]$Message, [string]$Prefill) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'WebTrack setup'
    $form.ClientSize = New-Object System.Drawing.Size(520, 140)
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

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Start watching'
    $ok.Location = New-Object System.Drawing.Point(292, 96)
    $ok.Size = New-Object System.Drawing.Size(115, 30)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(415, 96)
    $cancel.Size = New-Object System.Drawing.Size(93, 30)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $form.Controls.AddRange(@($label, $box, $ok, $cancel))
    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    $text = $box.Text
    $form.Dispose()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $text }
    return $null
}

function Get-CleanUrl([string]$Raw) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $u = $Raw.Trim().Trim('"')
    $q = $u.IndexOf('?'); if ($q -ge 0) { $u = $u.Substring(0, $q) }
    $h = $u.IndexOf('#'); if ($h -ge 0) { $u = $u.Substring(0, $h) }
    if ($u -notmatch '^https?://(www\.)?mint\.ca/.+') { return $null }
    return $u
}

try {
    # 1. get the link
    $clean = $null
    if ($Interactive) {
        $prefill = $SuggestedUrl   # pre-filled with the Rose Window coin; replace it with any mint.ca link
        $msg = 'This is the item WebTrack will watch. Keep it, or paste a different mint.ca link, then click Start watching:'
        while ($true) {
            $raw = Read-UrlDialog $msg $prefill
            if ($null -eq $raw) { exit 0 }
            $clean = Get-CleanUrl $raw
            if ($clean) { break }
            $prefill = $raw
            $msg = "That doesn't look like a mint.ca link (it should start with https://www.mint.ca/). Please paste the full link from your browser's address bar:"
        }
    } else {
        $clean = Get-CleanUrl $Url
        if (-not $clean) { Write-Host 'ERROR: not a valid mint.ca link.'; exit 2 }
    }

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

    # 3. add it to the watch list (rebuild fresh if the config is broken)
    $products = @()
    if (Test-Path $ConfigPath) {
        try {
            $cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg -and $cfg.products) { $products = @($cfg.products | Where-Object { $_ -and $_.url }) }
        } catch { $products = @() }
    }
    $already = $false
    foreach ($p in $products) { if ([string]$p.url -eq $clean) { $already = $true; break } }
    if (-not $already) {
        $products = @($products) + @(@{ name = $name; url = $clean })
        if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
        @{ products = $products } | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
    }

    # 4. install / refresh the background task and run a first check right away
    if (-not $SkipTask) {
        $installer = Join-Path $InstallDir 'Install-Task.ps1'
        if (-not (Test-Path $installer)) { throw "Install-Task.ps1 not found in $InstallDir" }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'the background task could not be created.' }
        Start-ScheduledTask -TaskName 'WebTrack Stock Watcher'
    }

    # 5. tell the human what is happening
    $watchList = ($products | ForEach-Object { '  - ' + [string]$_.name }) -join "`r`n"
    $lines = @()
    if ($already) { $lines += 'You were already watching that item - all good.' }
    $lines += 'WebTrack is now watching:'
    $lines += ''
    $lines += $watchList
    $lines += ''
    $lines += 'It quietly checks every minute. The moment an item can be ordered you will get a LOUD notification and the page will open by itself so you can buy it.'
    if (-not $verified) {
        $lines += ''
        $lines += 'Note: that link did not look exactly like a normal product page, but it will be watched anyway.'
    }
    $lines += ''
    $lines += 'To watch another item later, run INSTALL.bat again and paste the new link.'
    Show-Message ($lines -join "`r`n") 'WebTrack is running!' 'Information'
    exit 0
}
catch {
    Show-Message ("Setup hit a problem: " + $_.Exception.Message + "`r`n`r`nPlease send a photo of this message to whoever gave you WebTrack.") 'WebTrack setup problem' 'Error'
    exit 1
}
