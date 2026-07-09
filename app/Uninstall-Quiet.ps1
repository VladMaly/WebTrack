# Uninstall-Quiet.ps1 - windowless uninstall with a confirm box. Runs when the
# user clicks "Uninstall WebTrack" on a notification (webtrack: protocol).
[CmdletBinding()]
param([string]$Uri)

Add-Type -AssemblyName System.Windows.Forms
$answer = [System.Windows.Forms.MessageBox]::Show(
    'Stop watching and completely remove WebTrack from this computer?',
    'WebTrack',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question)
if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { exit 0 }

try { Unregister-ScheduledTask -TaskName 'WebTrack Stock Watcher' -Confirm:$false -ErrorAction Stop } catch { }
try { Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'WebTrack') -Recurse -Force -ErrorAction Stop } catch { }
foreach ($k in 'HKCU:\SOFTWARE\Classes\webtrack', 'HKCU:\SOFTWARE\Classes\AppUserModelId\WebTrack.Alerts') {
    try { Remove-Item $k -Recurse -Force -ErrorAction Stop } catch { }
}

[void][System.Windows.Forms.MessageBox]::Show(
    'WebTrack is uninstalled. No more checks, no more alerts.',
    'WebTrack',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information)

# delete the install folder last - this script lives inside it
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $env:TEMP
try {
    Remove-Item $dir -Recurse -Force -ErrorAction Stop
} catch {
    Start-Process cmd.exe -ArgumentList ('/c ping -n 3 127.0.0.1 >nul & rd /s /q "{0}"' -f $dir) -WindowStyle Hidden
}
