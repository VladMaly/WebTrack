# WebTrack

Watches [mint.ca](https://www.mint.ca) product pages and alerts the moment an item comes in stock:

- **Persistent Windows notification** (stays on screen until dismissed) — click it to open the product page
- **You choose how often it checks** (seconds or minutes) with an optional ±20% randomizer so it doesn't look like a bot — 90 s is the researched safe default
- Re-alerts every 15 minutes while the item stays in stock
- If the item is **already in stock when you set it up**, you get one regular heads-up instead
- If mint.ca throws up a queue/bot-check page (common during hot releases), it alarms immediately — that often means a drop is live
- Warns you if checks keep failing or `products.json` breaks, so it never fails silently

Windows 10/11 only. No admin rights, no dependencies — plain PowerShell + Task Scheduler.

## Install (for everyone)

**Option A — you were sent `WebTrack-Setup.zip`:**
1. Extract it (right-click → *Extract All*)
2. Double-click **`_INSTALL.bat`**
3. A small window pops up with the coin link pre-filled — keep it or paste any other mint.ca product link, pick how often to check (30 seconds is the safe default), and click **Start watching**. Done.

**Option B — you were sent this GitHub link:**
1. Click the green **Code** button (top of this page) → **Download ZIP**
2. Then follow Option A from step 1.

Installing also adds Start Menu entries: **"WebTrack - change watched item"** and **"WebTrack - uninstall"**.

To watch a **different item later**: Start Menu → *WebTrack - change watched item* (or run `_INSTALL.bat` again) and paste the new link — it **replaces** the old one; WebTrack always watches exactly what you last entered.

To **uninstall**: click **Uninstall WebTrack** right on any WebTrack notification, or Start Menu → *WebTrack - uninstall* (or `_UNINSTALL.bat`). Everything is removed.

## Sharing workflow (for the maintainer)

Two equally valid ways to give WebTrack to someone:

| Channel | What you send | What they do |
|---|---|---|
| ZIP | `WebTrack-Setup.zip` (email/chat/USB) | extract → `_INSTALL.bat` |
| GitHub | `https://github.com/VladMaly/WebTrack` | Code → Download ZIP → extract → `_INSTALL.bat` |

After changing any script, rebuild the zip so both channels stay in sync, then commit both:

```powershell
powershell -ExecutionPolicy Bypass -File .\app\Build-Zip.ps1
git add -A
git commit -m "describe the change"
git push
```

## How it works

The repo keeps it simple on top: `_INSTALL.bat`, `_UNINSTALL.bat`, the zip, and this README.
All machinery lives in `app\`:

- `app\Setup-Wizard.ps1` — the install popup: takes a mint.ca link + a check interval (seconds or
  minutes), validates the link, grabs the product name from the page, writes it to `products.json`
  (replacing the previous item), registers the Task Scheduler job. (`products.json` supports
  multiple entries if edited by hand; the popup always sets exactly one.)
- `app\Watch-Stock.ps1` — the watcher. On each run it downloads the product page and reads the
  `data-pwr-in-stock="True|False"` flag mint.ca embeds in every product page (the page's JSON-LD
  metadata always claims InStock — it lies — so it is ignored). Falls back to ADD TO CART button
  text if the layout ever changes, and recognizes queue/challenge pages as a "check now" event.
- Everything lives in `%LOCALAPPDATA%\WebTrack` after install: `products.json` (watch list),
  `state.json` (last known status), `watch.log` (history).
- The scheduled task **"WebTrack Stock Watcher"** runs `run-hidden.vbs` → hidden PowerShell while
  the user is logged in, surviving reboots. Interval is chosen in the popup; **30 seconds is the
  default** (a safe rate that won't get the IP rate-limited — see below). Task Scheduler cannot
  repeat faster than 1 minute, so `Install-Task.ps1 -IntervalSeconds N` handles sub-minute rates by
  bursting `round(60/N)` checks per minute and ≥1-minute rates with a repeating trigger.
- Test the alert notification: `Watch-Stock.ps1 -TestAlert`

### Why 90 seconds is the default (researched 2026-07)

mint.ca runs on Optimizely DXP behind **Cloudflare Bot Management** (the `__cf_bm` cookie), with an
ASP.NET/Azure origin. There is no standing per-IP rate limit and no permanent waiting room, but two
things raise your bot score: **volume** (a fixed 10 s poll = 8,640 identical hits/day to one URL
from one IP) and **cookieless requests** (each bare poll mints a fresh session — a textbook bot
tell). Rate limits get switched on *ad hoc* during hot releases, which is exactly when you're
polling hardest, so the goal is to look like an eager human, not a scraper.

WebTrack does that three ways:

- **90 s default** (~960 hits/day) — comfortably polite, and with the ±20% randomizer the real
  spacing wanders ~72–108 s so there's no fixed pattern. Still catches a drop inside ~1.5 min. The
  popup lets you pick anything from 15 s up; **≤30 s is best reserved for the few minutes around a
  launch** (RCM drops go live ~9–10 am ET), since that's when limits tighten.
- **Randomized timing** (the checkbox, ±20% by default) — a perfect metronome is itself a bot
  signature; the wobble makes each check land at an unpredictable moment.
- **Cookie reuse + browser headers** — a `cookies.txt` jar keeps the Cloudflare/session cookies so
  repeated polls look like one returning visitor, plus `Accept`/`Accept-Language` headers.

If the Mint ever does put up a Cloudflare challenge or queue page, WebTrack recognizes it and alarms
so you can step in yourself.

## Limitations

- Alerts only fire while you're **logged in with the PC awake** — checks pause while the machine
  sleeps (buying needs you at the keyboard anyway).
- Windows **Do Not Disturb / Focus Assist** can mute the notification — the browser still opens.
- mint.ca only. Other retailers need their own detection logic.
