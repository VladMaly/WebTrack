# Setup-Bootstrap.ps1 - runs the whole install with NO console window.
# _INSTALL.bat launches this hidden; all feedback is via the browser setup page
# or small message boxes, never a lingering black cmd window.
# Params: -Source <folder _INSTALL.bat ran from>  [-Url <link> for silent install]
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Url
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

function Msg([string]$Text, [string]$Icon = 'Information') {
    [void][System.Windows.Forms.MessageBox]::Show($Text, 'WebTrack',
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]$Icon)
}

# clean a possibly-mangled -Source (a stray quote from batch \" quoting) and make
# sure a hidden crash is never fully silent - show a popup instead of vanishing
$Source = ([string]$Source).Trim().Trim('"')
try {

$dest = Join-Path $env:LOCALAPPDATA 'WebTrack'

# where the program files are: app\ next to the installer, or flat (already installed)
$src = Join-Path $Source 'app'
if (-not (Test-Path (Join-Path $src 'Watch-Stock.ps1'))) { $src = $Source }
if (-not (Test-Path (Join-Path $src 'Watch-Stock.ps1'))) {
    Msg ("WebTrack's setup files weren't found.`r`n`r`nIf you opened this from inside a ZIP, right-click the ZIP, choose `"Extract All`", then run _INSTALL again from the extracted folder.") 'Warning'
    exit 1
}

if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }

# copy program files to the install folder (skip if we're already running there)
if ($src.TrimEnd('\') -ine $dest.TrimEnd('\')) {
    $files = @('Setup-Web.ps1','Setup-Wizard.ps1','Setup-Bootstrap.ps1','Watch-Stock.ps1',
               'Install-Task.ps1','Uninstall-Task.ps1','Uninstall-Quiet.ps1','run-hidden.vbs')
    foreach ($f in $files) {
        $p = Join-Path $src $f
        if (Test-Path $p) { Copy-Item $p $dest -Force }
    }
    foreach ($b in '_INSTALL.bat','_UNINSTALL.bat') {
        $p = Join-Path $Source $b
        if (Test-Path $p) { Copy-Item $p $dest -Force }
    }
}

$webPs    = Join-Path $dest 'Setup-Web.ps1'
$wizardPs = Join-Path $dest 'Setup-Wizard.ps1'

# silent install (a link was passed): straight to the wizard, no UI
if (-not [string]::IsNullOrWhiteSpace($Url)) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wizardPs -Url $Url -InstallDir $dest 2>&1
    if ($LASTEXITCODE -ne 0) { Msg ((($out | ForEach-Object { $_.ToString() }) -join "`n") -replace '^\[[^\]]+\]\s*', '') 'Error' }
    exit $LASTEXITCODE
}

# normal install: the modern browser setup window
& powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $webPs -InstallDir $dest
$code = $LASTEXITCODE

if ($code -eq 0) { exit 0 }                                   # installed
if ($code -eq 2) {                                            # opened but not finished
    Msg "Setup was closed before it finished.`r`n`r`nRun _INSTALL again whenever you're ready." 'Information'
    exit 0
}
# 1 or 3: the browser couldn't open - fall back to the classic popup window
& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File $wizardPs -InstallDir $dest
if ($LASTEXITCODE -eq 1) {
    Msg "Setup didn't finish. Please send a photo of any error to whoever gave you WebTrack." 'Error'
}
exit 0

}
catch {
    Msg ("WebTrack setup ran into a problem:`r`n`r`n" + $_.Exception.Message) 'Error'
    exit 1
}
