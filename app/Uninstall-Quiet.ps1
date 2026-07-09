# Uninstall-Quiet.ps1 - one-click uninstall, no questions asked. Runs when the
# user clicks "Uninstall WebTrack" on a notification (webtrack: protocol).
[CmdletBinding()]
param([string]$Uri)

try { Unregister-ScheduledTask -TaskName 'WebTrack Stock Watcher' -Confirm:$false -ErrorAction Stop } catch { }
try { Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'WebTrack') -Recurse -Force -ErrorAction Stop } catch { }

# farewell notification (sent while the WebTrack identity still exists)
try {
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
    $xml = @"
<toast>
  <visual><binding template="ToastGeneric">
    <text>WebTrack is uninstalled</text>
    <text>No more checks, no more alerts.</text>
  </binding></visual>
  <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@
    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml($xml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification($doc)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('WebTrack.Alerts').Show($toast)
} catch { }

foreach ($k in 'HKCU:\SOFTWARE\Classes\webtrack', 'HKCU:\SOFTWARE\Classes\AppUserModelId\WebTrack.Alerts') {
    try { Remove-Item $k -Recurse -Force -ErrorAction Stop } catch { }
}

# delete the install folder last - this script lives inside it
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $env:TEMP
try {
    Remove-Item $dir -Recurse -Force -ErrorAction Stop
} catch {
    Start-Process cmd.exe -ArgumentList ('/c ping -n 3 127.0.0.1 >nul & rd /s /q "{0}"' -f $dir) -WindowStyle Hidden
}
