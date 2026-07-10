# Setup-Web.ps1 - modern browser-based setup UI. Serves a small styled page on
# a loopback port, opens it in the user's default browser, and hands the chosen
# link/interval to Setup-Wizard.ps1 to do the actual install. No dependencies,
# no compile - the UI is rendered by the browser the user already has.
# Test headless:  Setup-Web.ps1 -NoBrowser   (prints the URL; drive it with curl)
[CmdletBinding()]
param(
    [string]$InstallDir,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA 'WebTrack' }
$SuggestedUrl           = 'https://www.mint.ca/en/shop/coins/2026/rose-window-notre-dame-2026-fine-silver-coin'
$DefaultIntervalSeconds = 90
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

function HtmlEncode([string]$s) {
    if ($null -eq $s) { return '' }
    # encode the single quote too - our attribute values use single quotes
    return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;').Replace("'",'&#39;')
}

function Get-Page([string]$Token, [string]$Prefill, [string]$ErrorMsg) {
    $err = ''
    if ($ErrorMsg) { $err = "<div class='err'>$(HtmlEncode $ErrorMsg)</div>" }
    $pf = HtmlEncode $Prefill
    @"
<!doctype html><html><head><meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<title>WebTrack setup</title>
<style>
  :root { --accent:#0a7d3c; --accent2:#0c9a4a; --bg:#f4f5f7; --card:#fff; --text:#1c1e21; --muted:#6b7280; --border:#e2e4e8; }
  @media (prefers-color-scheme: dark) {
    :root { --bg:#15171c; --card:#1e2127; --text:#e8eaed; --muted:#9aa0aa; --border:#2c3038; }
  }
  * { box-sizing:border-box; }
  body { margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center;
    background:var(--bg); color:var(--text); font-family:'Segoe UI',system-ui,-apple-system,sans-serif; padding:24px; }
  .card { background:var(--card); width:100%; max-width:520px; border-radius:16px; padding:32px;
    box-shadow:0 10px 40px rgba(0,0,0,.12); border:1px solid var(--border); }
  h1 { margin:0 0 4px; font-size:22px; }
  .sub { color:var(--muted); margin:0 0 24px; font-size:14px; }
  label { display:block; font-weight:600; font-size:13px; margin:18px 0 6px; }
  input[type=url], input[type=number], select { width:100%; padding:11px 13px; font-size:15px;
    border:1px solid var(--border); border-radius:9px; background:var(--bg); color:var(--text); }
  input:focus, select:focus { outline:2px solid var(--accent2); border-color:transparent; }
  .row { display:flex; gap:10px; }
  .row .num { flex:0 0 110px; } .row .unit { flex:1; }
  .check { display:flex; align-items:flex-start; gap:10px; margin-top:18px; font-size:14px; }
  .check input { margin-top:2px; width:18px; height:18px; accent-color:var(--accent); }
  .hint { color:var(--muted); font-size:12.5px; margin-top:6px; line-height:1.5; }
  button { margin-top:26px; width:100%; padding:14px; font-size:16px; font-weight:700; color:#fff;
    background:var(--accent); border:none; border-radius:10px; cursor:pointer; transition:.15s; }
  button:hover { background:var(--accent2); }
  .err { background:#fde8e8; color:#a12020; border:1px solid #f5c2c2; padding:10px 13px;
    border-radius:9px; font-size:13.5px; margin-bottom:12px; }
  @media (prefers-color-scheme: dark){ .err{ background:#3a1e1e; color:#f5b5b5; border-color:#5a2a2a; } }
  .foot { text-align:center; color:var(--muted); font-size:12px; margin-top:18px; }
</style></head><body>
  <form class='card' method='POST' action='/$Token/save'>
    <h1>Watch a Mint item</h1>
    <p class='sub'>WebTrack pings you the moment it comes in stock.</p>
    $err
    <label for='url'>Product link (mint.ca)</label>
    <input type='url' id='url' name='url' value='$pf' required autofocus
      onfocus='this.select()' placeholder='https://www.mint.ca/en/shop/coins/...'>
    <label>Check for stock every</label>
    <div class='row'>
      <input class='num' type='number' name='interval' value='$DefaultIntervalSeconds' min='1' max='999' required>
      <select class='unit' name='units'>
        <option value='seconds' selected>seconds</option>
        <option value='minutes'>minutes</option>
      </select>
    </div>
    <label class='check'><input type='checkbox' name='randomize' checked>
      <span>Randomize the timing by ~20% <span class='hint'>(recommended - looks less like a bot)</span></span></label>
    <p class='hint'>90 seconds is a safe default. Much faster can get you rate-limited or blocked by the store.</p>
    <button type='submit'>Start watching</button>
    <p class='foot'>You can close this tab after it starts.</p>
  </form>
</body></html>
"@
}

function Get-ResultPage([string]$Title, [string]$Body, [bool]$Ok) {
    $accent = if ($Ok) { '#0a7d3c' } else { '#a12020' }
    @"
<!doctype html><html><head><meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'><title>WebTrack setup complete</title>
<style>
  :root{--bg:#f4f5f7;--card:#fff;--text:#1c1e21;--muted:#6b7280;--border:#e2e4e8;}
  @media (prefers-color-scheme: dark){:root{--bg:#15171c;--card:#1e2127;--text:#e8eaed;--muted:#9aa0aa;--border:#2c3038;}}
  body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:var(--bg);
    color:var(--text);font-family:'Segoe UI',system-ui,-apple-system,sans-serif;padding:24px;}
  .card{background:var(--card);max-width:520px;border-radius:16px;padding:36px;text-align:center;
    box-shadow:0 10px 40px rgba(0,0,0,.12);border:1px solid var(--border);border-top:5px solid $accent;}
  h1{margin:0 0 12px;font-size:22px;} p{color:var(--muted);font-size:15px;line-height:1.6;white-space:pre-wrap;margin:0;}
  .big{font-size:52px;margin-bottom:8px;line-height:1;} .closing{color:var(--muted);font-size:12px;margin-top:20px;}
</style></head><body><div class='card'>
  <div class='big'>$(if($Ok){'&#9989;'}else{'&#9888;'})</div>
  <h1>$(HtmlEncode $Title)</h1><p>$(HtmlEncode $Body)</p>
  $(if($Ok){"<p class='closing'>This window closes automatically...</p>"})
</div>
$(if($Ok){"<script>setTimeout(function(){window.close();},3500);</script>"})
</body></html>
"@
}

function Send-Response($Stream, [int]$Status, [string]$ContentType, [string]$Body) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Body)
    $reason = @{200='OK';400='Bad Request';404='Not Found'}[$Status]
    $head = "HTTP/1.1 $Status $reason`r`nContent-Type: $ContentType; charset=utf-8`r`n" +
            "Content-Length: $($bytes.Length)`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n"
    $hb = [Text.Encoding]::ASCII.GetBytes($head)
    $Stream.Write($hb, 0, $hb.Length); $Stream.Write($bytes, 0, $bytes.Length); $Stream.Flush()
}

function Read-Request($Stream) {
    # read headers, honour Content-Length for the body, bounded by a timeout so a
    # stalled/aborted client can never hang the one-shot server
    $ms = New-Object System.IO.MemoryStream
    $buf = New-Object byte[] 16384
    try { $Stream.ReadTimeout = 4000 } catch { }
    $headerEnd = -1
    $contentLength = 0
    $deadline = (Get-Date).AddSeconds(8)
    while ((Get-Date) -lt $deadline) {
        $bytes = $ms.ToArray()
        if ($headerEnd -lt 0) {
            $text = [Text.Encoding]::ASCII.GetString($bytes)
            $idx = $text.IndexOf("`r`n`r`n")
            if ($idx -ge 0) {
                $headerEnd = $idx
                $m = [regex]::Match($text.Substring(0, $idx), '(?im)^Content-Length:\s*(\d+)')
                if ($m.Success) { $contentLength = [int]$m.Groups[1].Value }
            }
        }
        if ($headerEnd -ge 0 -and ($bytes.Length - ($headerEnd + 4)) -ge $contentLength) { break }
        try { $n = $Stream.Read($buf, 0, $buf.Length) } catch { break }
        if ($n -le 0) { break }
        $ms.Write($buf, 0, $n)
    }
    return [Text.Encoding]::UTF8.GetString($ms.ToArray())
}

function ConvertFrom-Form([string]$Body) {
    $h = @{}
    foreach ($pair in $Body.Split('&')) {
        $kv = $pair.Split('=', 2)
        if ($kv.Length -eq 2) {
            $k = [Uri]::UnescapeDataString($kv[0].Replace('+', ' '))
            $v = [Uri]::UnescapeDataString($kv[1].Replace('+', ' '))
            $h[$k] = $v
        }
    }
    return $h
}

$token = [Guid]::NewGuid().ToString('N')

# open the setup page as a clean standalone window (Edge/Chrome "app mode" - no
# tabs, no address bar) using the user's NORMAL profile (no fresh-profile onboarding
# or sync prompt). Fall back to the default browser (a normal tab).
function Open-SetupWindow([string]$Url) {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
    )
    foreach ($exe in $candidates) {
        if ($exe -and (Test-Path $exe)) {
            try { Start-Process $exe -ArgumentList ('--app={0}' -f $Url), '--window-size=580,720'; return } catch { }
        }
    }
    Start-Process $Url   # default browser, normal tab
}

# close our setup window by its title (app-mode window title == the page <title>),
# so we shut only our window without touching the rest of the user's browser
function Close-SetupWindow {
    try {
        if (-not ([System.Management.Automation.PSTypeName]'WtWin').Type) {
            Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WtWin {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
}
'@
        }
        foreach ($t in 'WebTrack setup complete', 'WebTrack setup') {
            $h = [WtWin]::FindWindow($null, $t)
            if ($h -ne [IntPtr]::Zero) { [void][WtWin]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }  # WM_CLOSE
        }
    } catch { }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
try {
    $listener.Start()
    $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $rootUrl = "http://127.0.0.1:$port/$token/"
    if ($NoBrowser) { Write-Host "URL: $rootUrl" } else { Open-SetupWindow $rootUrl }
} catch {
    try { $listener.Stop() } catch { }
    exit 1   # couldn't start -> _INSTALL.bat uses the classic popup
}

$done = $false
$everConnected = $false
$start = Get-Date
$deadline  = $start.AddMinutes(10)   # give up if abandoned
$connectBy = $start.AddSeconds(45)   # browser should have loaded the page by now
try {
    while (-not $done -and (Get-Date) -lt $deadline) {
        if (-not $listener.Pending()) {
            if (-not $everConnected -and (Get-Date) -gt $connectBy) { break }
            Start-Sleep -Milliseconds 150
            continue
        }
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $req = Read-Request $stream
            $line = ($req -split "`r`n")[0]
            $parts = $line.Split(' ')
            $method = $parts[0]; $path = if ($parts.Length -gt 1) { $parts[1] } else { '/' }

            if ($path -notlike "/$token*") {
                Send-Response $stream 404 'text/plain' 'Not found'
            }
            else {
                $everConnected = $true
                if ($method -eq 'GET') {
                    Send-Response $stream 200 'text/html' (Get-Page $token $SuggestedUrl '')
                }
                elseif ($method -eq 'POST') {
                    $bodyStart = $req.IndexOf("`r`n`r`n")
                    $body = if ($bodyStart -ge 0) { $req.Substring($bodyStart + 4) } else { '' }
                    $form = ConvertFrom-Form $body
                    $rawUrl = [string]$form['url']
                    $seconds = 0
                    [int]::TryParse([string]$form['interval'], [ref]$seconds) | Out-Null
                    if ($form['units'] -eq 'minutes') { $seconds = $seconds * 60 }
                    $jitter = if ($form.ContainsKey('randomize')) { 20 } else { 0 }

                    # a real mint.ca link has no spaces, quotes, backslashes or control
                    # chars - reject those before spawning the installer (blocks arg
                    # injection and the empty-url case that would hang the wizard)
                    if ([string]::IsNullOrWhiteSpace($rawUrl) -or $rawUrl -match '[\s"\\\x00-\x1f]') {
                        Send-Response $stream 200 'text/html' (Get-Page $token $rawUrl "That doesn't look like a valid mint.ca link.")
                    } else {
                        $wizard = Join-Path $InstallDir 'Setup-Wizard.ps1'
                        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wizard `
                            -Url $rawUrl -IntervalSeconds $seconds -JitterPercent $jitter `
                            -InstallDir $InstallDir 2>&1
                        $code = $LASTEXITCODE
                        $msg = (($out | ForEach-Object { $_.ToString() }) -join "`n") -replace '^\[[^\]]+\]\s*', ''
                        if ($code -eq 0) {
                            $done = $true   # set before the write, so a closed tab still ends cleanly
                            Send-Response $stream 200 'text/html' (Get-ResultPage 'WebTrack is running!' $msg $true)
                        } else {
                            $errText = if ($msg) { $msg } else { "That doesn't look like a valid mint.ca link." }
                            Send-Response $stream 200 'text/html' (Get-Page $token $rawUrl $errText)
                        }
                    }
                }
                else {
                    Send-Response $stream 404 'text/plain' 'Not found'
                }
            }
        } catch {
            # a flaky/aborted connection must never stop the one-shot server
        } finally {
            try { $client.Close() } catch { }
        }
    }
} finally {
    try { $listener.Stop() } catch { }
}

if (-not $NoBrowser) {
    if ($done) { Start-Sleep -Seconds 4 }   # let the success page be read, then close it
    Close-SetupWindow
}

if ($done) { exit 0 }          # installed
elseif ($everConnected) { exit 2 }   # page opened but user didn't finish
else { exit 3 }                # browser never reached us -> use the classic popup
