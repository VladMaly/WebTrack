# Install-Task.ps1 - registers a Task Scheduler job that runs the stock watcher
# while you are logged in. No admin rights needed.
# Task Scheduler cannot repeat faster than 1 minute, so each run fires
# ChecksPerMinute checks spaced evenly across the minute (default: 6 = every 10s).
[CmdletBinding()]
param(
    [int]$IntervalMinutes = 1,
    [int]$ChecksPerMinute = 6
)

$ErrorActionPreference = 'Stop'
$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$TaskName = 'WebTrack Stock Watcher'
$Launcher = Join-Path $Root 'run-hidden.vbs'

if (-not (Test-Path $Launcher)) { throw "run-hidden.vbs not found next to this script." }

if ($ChecksPerMinute -lt 1) { $ChecksPerMinute = 1 }
$gapSeconds = [Math]::Floor(60 * $IntervalMinutes / $ChecksPerMinute)

$action = New-ScheduledTaskAction -Execute 'wscript.exe' `
    -Argument ('"{0}" {1} {2}' -f $Launcher, $ChecksPerMinute, $gapSeconds)

# repeat every N minutes, effectively forever
$repeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

# also restart the cycle at every logon so it survives reboots
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
try { $logonTrigger.Repetition = $repeatTrigger.Repetition } catch { }

$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $TaskName -Action $action `
    -Trigger $repeatTrigger, $logonTrigger -Settings $settings -Force | Out-Null

Write-Host ("Scheduled task '{0}' installed. It checks about every {1} seconds while you are logged in." -f $TaskName, $gapSeconds)
Write-Host "Remove it any time with:  .\Uninstall-Task.ps1"
