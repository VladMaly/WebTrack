# Watch-Stock.ps1 - polls mint.ca product pages and alerts when an item comes in stock.
# Run manually:  powershell -ExecutionPolicy Bypass -File .\Watch-Stock.ps1
# Test alerts:   powershell -ExecutionPolicy Bypass -File .\Watch-Stock.ps1 -TestAlert
#                (add -TestAlertIndex 2 to simulate the 2nd product in products.json)
[CmdletBinding()]
param(
    [switch]$TestAlert,
    [int]$TestAlertIndex = 1
)

$ErrorActionPreference = 'Continue'
$Root             = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath       = Join-Path $Root 'products.json'
$StatePath        = Join-Path $Root 'state.json'
$LogPath          = Join-Path $Root 'watch.log'
$ConfigAlertStamp = Join-Path $Root 'config-alert.stamp'

$UserAgent           = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$ReAlertMinutes      = 15   # nag again this often while an item stays in stock
$BlockReAlertMinutes = 60   # re-alarm this often while the page stays queue/blocked
$ProblemAlertAfter   = 4    # consecutive quiet failures (~12 min) before a warning toast
$RecentFailWindowMin = 60   # sliding window for counting intermittent failures
$RecentFailLimit     = 8    # intermittent failures within the window that trigger a warning
$ProblemReAlertHrs   = 1
# signatures of queue/challenge/block pages served instead of the product page
$BlockSignatures     = 'queue-it|queueit|Just a moment|cf-chl|challenge-platform|challenge-form|Access Denied|captcha|Pardon Our Interruption'

# curl.exe emits UTF-8; decode it as such regardless of console codepage
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# only one instance at a time
$script:Mutex = New-Object System.Threading.Mutex($false, 'Local\WebTrackStockWatch')
if (-not $script:Mutex.WaitOne(0)) { exit 0 }

function Write-Log([string]$Message) {
    $line = ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message)
    try { Add-Content -Path $LogPath -Value $line -Encoding UTF8 } catch { }
}

function Limit-LogSize {
    try {
        if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 5MB)) {
            Move-Item -Path $LogPath -Destination ($LogPath + '.old') -Force
        }
    } catch { }
}

function ConvertTo-UtcDate([string]$Iso) {
    try {
        return [DateTime]::Parse($Iso, [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    } catch { return $null }
}

# a throttle timestamp is "due" when old enough OR in the future (clock rollback: fail toward alerting)
function Test-Due([string]$LastIso, [double]$ThresholdMinutes, [datetime]$NowUtc) {
    if ([string]::IsNullOrWhiteSpace($LastIso)) { return $true }
    $last = ConvertTo-UtcDate $LastIso
    if (-not $last) { return $true }
    $elapsed = ($NowUtc - $last).TotalMinutes
    return (($elapsed -ge $ThresholdMinutes) -or ($elapsed -lt 0))
}

function Get-PageStatus([string]$Url) {
    $html = $null
    $launchError = $null
    try {
        $html = (& curl.exe -sL --compressed --max-time 25 --retry 2 --retry-delay 2 `
            --retry-all-errors --retry-max-time 40 -A $UserAgent -- $Url) -join "`n"
    } catch { $launchError = $_.Exception.Message }
    if ($launchError) {
        return @{ Status = 'FETCH_ERROR'; Detail = ('curl failed to launch: {0}' -f $launchError) }
    }
    if ($LASTEXITCODE -ne 0) {
        return @{ Status = 'FETCH_ERROR'; Detail = ('curl exit code {0}' -f $LASTEXITCODE) }
    }
    if ([string]::IsNullOrWhiteSpace($html)) {
        return @{ Status = 'FETCH_ERROR'; Detail = 'curl exit code 0 but empty response body' }
    }
    # exactly one data-pwr-in-stock flag exists per product page (verified 2026-07)
    if ($html -match 'data-pwr-in-stock="True"')  { return @{ Status = 'IN_STOCK'; Detail = 'data-pwr-in-stock=True' } }
    if ($html -match 'data-pwr-in-stock="False"') {
        if ($html -match 'AWAITING\s+STOCK') { return @{ Status = 'AWAITING_STOCK'; Detail = '' } }
        if ($html -match 'SOLD\s+OUT')       { return @{ Status = 'SOLD_OUT'; Detail = '' } }
        return @{ Status = 'OUT_OF_STOCK'; Detail = '' }
    }
    # page layout changed: fall back to button text, favouring alerts over silence
    if ($html -match 'ADD\s+TO\s+CART') { return @{ Status = 'IN_STOCK'; Detail = 'fallback match on ADD TO CART text' } }
    # queue/challenge page served instead of the product page - often means a live drop
    if ($html -match $BlockSignatures) { return @{ Status = 'BLOCKED'; Detail = ('block page signature: {0}' -f $Matches[0]) } }
    return @{ Status = 'UNKNOWN'; Detail = 'no stock markers found in page' }
}

function Show-Toast([string]$Title, [string]$Body, [string]$Url, [switch]$Alarm) {
    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
        $xTitle = [Security.SecurityElement]::Escape($Title)
        $xBody  = [Security.SecurityElement]::Escape($Body)
        $xUrl   = [Security.SecurityElement]::Escape($Url)
        $scenario = ''
        $audio    = '<audio src="ms-winsoundevent:Notification.Default"/>'
        if ($Alarm) {
            # reminder scenario keeps the toast on screen until dismissed;
            # normal notification sound (user preference: notification only,
            # no siren, no popup window, no auto-opening browser)
            $scenario = ' scenario="reminder"'
        }
        $xml = @"
<toast activationType="protocol" launch="$xUrl"$scenario>
  <visual>
    <binding template="ToastGeneric">
      <text>$xTitle</text>
      <text>$xBody</text>
    </binding>
  </visual>
  <actions>
    <action content="Open product page" activationType="protocol" arguments="$xUrl"/>
    <action content="Dismiss" activationType="system" arguments="dismiss"/>
  </actions>
  $audio
</toast>
"@
        $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
        $doc.LoadXml($xml)
        $toast = New-Object Windows.UI.Notifications.ToastNotification($doc)
        # own notification identity: shows as "WebTrack", and is immune to the
        # user having turned off notifications for "Windows PowerShell"
        $aumidKey = 'HKCU:\SOFTWARE\Classes\AppUserModelId\WebTrack.Alerts'
        if (-not (Test-Path $aumidKey)) {
            New-Item -Path $aumidKey -Force | Out-Null
            Set-ItemProperty -Path $aumidKey -Name DisplayName -Value 'WebTrack'
        }
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('WebTrack.Alerts').Show($toast)
        return $true
    } catch {
        Write-Log ('WARN toast failed: {0}' -f $_.Exception.Message)
        return $false
    }
}

function Invoke-AlarmFallback {
    try {
        $wav = Join-Path $env:windir 'Media\Alarm01.wav'
        if (Test-Path $wav) {
            $player = New-Object System.Media.SoundPlayer $wav
            1..3 | ForEach-Object { $player.PlaySync() }
        } else {
            1..10 | ForEach-Object { [console]::Beep(1000, 300); [console]::Beep(1500, 300) }
        }
    } catch { }
}

# config problems kill the run before the product loop, so they get their own
# stamp-file throttle - otherwise a bad edit to products.json would be a
# permanent, invisible outage
function Show-ConfigProblemToast([string]$Reason) {
    $now = (Get-Date).ToUniversalTime()
    $due = $true
    try {
        if (Test-Path $ConfigAlertStamp) {
            $due = Test-Due ((Get-Content $ConfigAlertStamp -Raw -ErrorAction Stop).Trim()) ($ProblemReAlertHrs * 60) $now
        }
    } catch { }
    if ($due) {
        $ok = Show-Toast 'WebTrack: watcher is NOT running' `
            ('products.json problem: {0} Fix the file or no stock alerts will ever fire.' -f $Reason) `
            ('file:///' + ($ConfigPath -replace '\\', '/'))
        if (-not $ok) { Invoke-AlarmFallback }
        try { $now.ToString('o') | Set-Content -Path $ConfigAlertStamp -Encoding UTF8 } catch { }
    }
}

Limit-LogSize

if (-not (Test-Path $ConfigPath)) {
    Write-Log 'ERROR products.json not found'
    Show-ConfigProblemToast 'file not found.'
    $script:Mutex.ReleaseMutex()
    exit 1
}
$config = $null
try {
    $config = Get-Content $ConfigPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
} catch {
    Write-Log ('ERROR cannot read/parse products.json: {0}' -f $_.Exception.Message)
    Show-ConfigProblemToast ('JSON error: {0}' -f $_.Exception.Message)
    $script:Mutex.ReleaseMutex()
    exit 1
}
# an empty/truncated file or wrong key parses to $null with NO error in PS 5.1
$productList = @()
if ($config -and $config.products) { $productList = @($config.products | Where-Object { $_ }) }
if ($productList.Count -eq 0) {
    Write-Log 'ERROR products.json has no products - watcher is checking NOTHING'
    Show-ConfigProblemToast 'no products defined (empty or truncated file?).'
    $script:Mutex.ReleaseMutex()
    exit 1
}
# healthy config: re-arm the config warning
try { if (Test-Path $ConfigAlertStamp) { Remove-Item $ConfigAlertStamp -Force } } catch { }

$oldState = @{}
if (Test-Path $StatePath) {
    try {
        $parsed = Get-Content $StatePath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        foreach ($prop in $parsed.PSObject.Properties) { $oldState[$prop.Name] = $prop.Value }
    } catch { Write-Log 'WARN state.json unreadable, starting fresh' }
}

$newState = @{}
$checked  = 0
$seenUrls = @{}
$index    = 0
foreach ($product in $productList) {
    $name = [string]$product.name
    $url  = [string]$product.url
    if ([string]::IsNullOrWhiteSpace($url)) {
        Write-Log ('WARN product "{0}" has no url in products.json - SKIPPED, not being watched' -f $name)
        continue
    }
    if ($seenUrls.ContainsKey($url)) {
        Write-Log ('WARN duplicate url for "{0}" ignored (already watched as "{1}")' -f $name, $seenUrls[$url])
        continue
    }
    $seenUrls[$url] = $name
    $index++

    if ($TestAlert -and $index -eq $TestAlertIndex) {
        $result = @{ Status = 'IN_STOCK'; Detail = 'SIMULATED by -TestAlert' }
    } else {
        $result = Get-PageStatus $url
    }
    $status = $result.Status
    $now    = (Get-Date).ToUniversalTime()

    $prev = $null
    if ($oldState.ContainsKey($url)) { $prev = $oldState[$url] }
    $prevStatus = $null
    if ($prev) { $prevStatus = [string]$prev.status }

    # sliding window of recent failure timestamps (catches intermittent blocking
    # that never produces a long consecutive streak)
    $recentFails = @()
    if ($prev -and $prev.recentFails) {
        foreach ($iso in @($prev.recentFails)) {
            $d = ConvertTo-UtcDate ([string]$iso)
            if ($d) {
                $ageMin = ($now - $d).TotalMinutes
                if ($ageMin -ge 0 -and $ageMin -le $RecentFailWindowMin) { $recentFails += [string]$iso }
            }
        }
    }

    $entry = @{
        name                = $name
        status              = $status
        since               = $now.ToString('o')
        lastAlertUtc        = $null
        lastBlockAlertUtc   = $null
        lastProblemAlertUtc = $null
        failCount           = 0
        recentFails         = $recentFails
        baselineInStock     = $false
    }
    if ($prev) {
        if ($prevStatus -eq $status -and $prev.since) { $entry.since = [string]$prev.since }
        if ($prev.lastAlertUtc)        { $entry.lastAlertUtc        = [string]$prev.lastAlertUtc }
        if ($prev.lastBlockAlertUtc)   { $entry.lastBlockAlertUtc   = [string]$prev.lastBlockAlertUtc }
        if ($prev.lastProblemAlertUtc) { $entry.lastProblemAlertUtc = [string]$prev.lastProblemAlertUtc }
    }

    $isFailure = ($status -eq 'FETCH_ERROR' -or $status -eq 'UNKNOWN' -or $status -eq 'BLOCKED')
    # baseline = the item was ALREADY in stock when the user set it up; carried
    # across fetch blips so a hiccup does not turn it into a full-blown alarm
    $wasBaseline = $false
    if ($prev -and $prev.baselineInStock) { $wasBaseline = $true }

    if ($status -eq 'IN_STOCK') {
        $isFirstSight = ($null -eq $prev -and $result.Detail -notlike '*SIMULATED*')
        if ($isFirstSight -or $wasBaseline) {
            # the user just set this up from the very page that is in stock -
            # one quiet heads-up, no alarm, no browser, no nagging. The full
            # alarm fires only when an item GOES from unavailable to in stock.
            $entry.baselineInStock = $true
            if ($isFirstSight) {
                Write-Log ('INFO {0} is already IN STOCK at setup - quiet heads-up only' -f $name)
                Show-Toast ('Already in stock: {0}' -f $name) 'This item can be ordered right now. Click to open the product page.' $url | Out-Null
                $entry.lastAlertUtc = $now.ToString('o')
            } else {
                Write-Log ('OK {0} still IN_STOCK (since setup), staying quiet' -f $name)
            }
        } else {
            $isNewlyInStock = ($prevStatus -ne 'IN_STOCK')
            $alertDue = $true
            if (-not $isNewlyInStock) {
                $alertDue = Test-Due $entry.lastAlertUtc $ReAlertMinutes $now
            }
            if ($alertDue) {
                Write-Log ('ALERT {0} is IN STOCK ({1})' -f $name, $result.Detail)
                $toastOk = Show-Toast ('IN STOCK: {0}' -f $name) 'Click to open the product page and buy it now.' $url -Alarm
                if (-not $toastOk) { Invoke-AlarmFallback }
                $entry.lastAlertUtc = $now.ToString('o')
            } else {
                Write-Log ('INFO {0} still IN_STOCK, next reminder in <= {1} min' -f $name, $ReAlertMinutes)
            }
        }
    }
    elseif ($isFailure) {
        $entry.baselineInStock = $wasBaseline
        $prevFail = 0
        if ($prev -and $prev.failCount) { $prevFail = [int]$prev.failCount }
        $entry.failCount    = $prevFail + 1
        $entry.recentFails  = @($recentFails) + @($now.ToString('o'))
        Write-Log ('WARN {0} check #{1} failed: {2} ({3})' -f $name, $entry.failCount, $status, $result.Detail)

        # a queue/challenge page replacing a readable product page often means a
        # live drop - that deserves the loud alarm, not an hour of silence.
        # UNKNOWN needs 2 consecutive hits so a one-off 5xx blip stays quiet.
        $suspicious = $false
        if ($status -eq 'BLOCKED') { $suspicious = $true }
        elseif ($status -eq 'UNKNOWN' -and ($prevStatus -eq 'UNKNOWN' -or $prevStatus -eq 'BLOCKED')) { $suspicious = $true }

        if ($suspicious) {
            if (Test-Due $entry.lastBlockAlertUtc $BlockReAlertMinutes $now) {
                Write-Log ('ALERT {0} page is blocked/unreadable - possible live drop ({1})' -f $name, $result.Detail)
                $toastOk = Show-Toast ('CHECK NOW: {0}' -f $name) `
                    'The product page has been replaced by a queue or block page. A release may be happening - open the page yourself right now.' `
                    $url -Alarm
                if (-not $toastOk) { Invoke-AlarmFallback }
                $entry.lastBlockAlertUtc = $now.ToString('o')
            }
        }
        elseif ($entry.failCount -ge $ProblemAlertAfter -or @($entry.recentFails).Count -ge $RecentFailLimit) {
            if (Test-Due $entry.lastProblemAlertUtc ($ProblemReAlertHrs * 60) $now) {
                $toastOk = Show-Toast 'WebTrack: stock checks are failing' `
                    ('{0}: {1} recent checks failed ({2}). Internet down, site blocking us, or page changed.' -f $name, [Math]::Max($entry.failCount, @($entry.recentFails).Count), $result.Detail) `
                    $url
                if (-not $toastOk) { Invoke-AlarmFallback }
                $entry.lastProblemAlertUtc = $now.ToString('o')
            }
        }
    }
    else {
        Write-Log ('OK {0} status={1}' -f $name, $status)
    }

    $newState[$url] = $entry
    $checked++
}

if ($TestAlert) {
    Write-Log 'INFO test alert run complete, state not saved'
}
elseif ($checked -gt 0) {
    try {
        $newState | ConvertTo-Json -Depth 5 | Set-Content -Path $StatePath -Encoding UTF8
    } catch {
        Write-Log ('ERROR could not write state.json: {0}' -f $_.Exception.Message)
    }
}
else {
    Write-Log 'WARN 0 products checked this run; state.json left untouched'
}

$script:Mutex.ReleaseMutex()
