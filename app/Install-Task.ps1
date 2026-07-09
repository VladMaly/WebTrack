# Install-Task.ps1 - registers a Task Scheduler job that runs the stock watcher
# while you are logged in. No admin rights needed.
# Takes ONE number: how many seconds between checks. Task Scheduler cannot
# repeat faster than 1 minute, so for sub-minute intervals each 1-minute run
# fires a burst of evenly-spaced checks; for >=1 minute the trigger itself repeats.
[CmdletBinding()]
param(
    [int]$IntervalSeconds = 60,
    [int]$JitterSeconds = -1   # -1 = auto (20% of interval); 0 = off; N = explicit
)

$ErrorActionPreference = 'Stop'
$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$TaskName = 'WebTrack Stock Watcher'
$Launcher = Join-Path $Root 'run-hidden.vbs'

if (-not (Test-Path $Launcher)) { throw "run-hidden.vbs not found next to this script." }

if ($IntervalSeconds -lt 5)     { $IntervalSeconds = 5 }
if ($IntervalSeconds -gt 86400) { $IntervalSeconds = 86400 }

if ($JitterSeconds -lt 0) { $JitterSeconds = [Math]::Round($IntervalSeconds * 0.2) }
if ($JitterSeconds -gt 30) { $JitterSeconds = 30 }   # cap so sub-minute bursts stay inside the minute

if ($IntervalSeconds -lt 60) {
    # sub-minute: trigger every minute, burst N checks spaced IntervalSeconds apart
    $triggerMinutes = 1
    $checksPerRun   = [Math]::Max(1, [Math]::Round(60 / $IntervalSeconds))
    $gapSeconds     = $IntervalSeconds
    # keep gap - jitter positive and the whole burst inside ~55s
    $maxBurstJitter = [Math]::Max(0, [Math]::Floor($gapSeconds * 0.15))
    if ($JitterSeconds -gt $maxBurstJitter) { $JitterSeconds = $maxBurstJitter }
} else {
    # >=1 minute: let the trigger itself repeat, one check per run
    $triggerMinutes = [Math]::Max(1, [Math]::Round($IntervalSeconds / 60))
    $checksPerRun   = 1
    $gapSeconds     = 0
}

$action = New-ScheduledTaskAction -Execute 'wscript.exe' `
    -Argument ('"{0}" {1} {2} {3}' -f $Launcher, $checksPerRun, $gapSeconds, $JitterSeconds)

# repeat every N minutes, effectively forever
$repeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $triggerMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

# also restart the cycle at every logon so it survives reboots
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
try { $logonTrigger.Repetition = $repeatTrigger.Repetition } catch { }

$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $TaskName -Action $action `
    -Trigger $repeatTrigger, $logonTrigger -Settings $settings -Force | Out-Null

$jitterNote = if ($JitterSeconds -gt 0) { "with +/-$JitterSeconds s randomization" } else { "on a fixed timer" }
Write-Host ("Scheduled task '{0}' installed. It checks about every {1} seconds ({2}) while you are logged in." -f $TaskName, $IntervalSeconds, $jitterNote)
Write-Host "Remove it any time with:  .\Uninstall-Task.ps1"
