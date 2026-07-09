# Build-Zip.ps1 - rebuilds WebTrack-Setup.zip from the distribution files.
# Run this after changing any script, then commit both the change and the zip.
# Zip layout mirrors the repo: INSTALL/UNINSTALL/readme on top, machinery in app\.
$ErrorActionPreference = 'Stop'
$App  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $App

$stage = Join-Path $env:TEMP ('webtrack-zip-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $stage 'app') -Force | Out-Null
Copy-Item (Join-Path $Root '_INSTALL.bat')      $stage
Copy-Item (Join-Path $Root '_UNINSTALL.bat')    $stage
Copy-Item (Join-Path $App 'README-SIMPLE.txt')  $stage
foreach ($f in 'Setup-Wizard.ps1', 'Watch-Stock.ps1', 'Install-Task.ps1', 'Uninstall-Task.ps1', 'run-hidden.vbs') {
    Copy-Item (Join-Path $App $f) (Join-Path $stage 'app')
}

$zip = Join-Path $Root 'WebTrack-Setup.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip
Remove-Item $stage -Recurse -Force
Write-Host ("Built {0} ({1} bytes)" -f $zip, (Get-Item $zip).Length)
