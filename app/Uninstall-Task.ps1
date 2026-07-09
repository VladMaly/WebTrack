# Uninstall-Task.ps1 - removes the stock watcher scheduled task.
$ErrorActionPreference = 'Stop'
$TaskName = 'WebTrack Stock Watcher'
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host ("Scheduled task '{0}' removed." -f $TaskName)
