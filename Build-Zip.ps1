# Build-Zip.ps1 - rebuilds WebTrack-Setup.zip from the distribution files.
# Run this after changing any script, then commit both the change and the zip.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistFiles = @(
    'INSTALL.bat'
    'UNINSTALL.bat'
    'README-SIMPLE.txt'
    'Setup-Wizard.ps1'
    'Watch-Stock.ps1'
    'Install-Task.ps1'
    'Uninstall-Task.ps1'
    'run-hidden.vbs'
)
$zip = Join-Path $Root 'WebTrack-Setup.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path ($DistFiles | ForEach-Object { Join-Path $Root $_ }) -DestinationPath $zip
Write-Host ("Built {0} ({1} bytes, {2} files)" -f $zip, (Get-Item $zip).Length, $DistFiles.Count)
