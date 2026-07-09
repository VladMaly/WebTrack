# WebTrack

Watches [mint.ca](https://www.mint.ca) product pages and alerts the moment an item comes in stock:

- **Loud, persistent Windows notification** (stays on screen, looping alarm sound) — click it to open the product page
- **Opens the product page in your browser** automatically the first time stock is detected
- Re-alerts every 15 minutes while the item stays in stock
- If mint.ca throws up a queue/bot-check page (common during hot releases), it alarms immediately — that often means a drop is live
- Warns you if checks keep failing or `products.json` breaks, so it never fails silently

Windows 10/11 only. No admin rights, no dependencies — plain PowerShell + Task Scheduler.

## Install (for everyone)

**Option A — you were sent `WebTrack-Setup.zip`:**
1. Extract it (right-click → *Extract All*)
2. Double-click **`_INSTALL.bat`**
3. A small window pops up with the coin link pre-filled — keep it or paste any other mint.ca product link, click **Start watching**. Done.

**Option B — you were sent this GitHub link:**
1. Click the green **Code** button (top of this page) → **Download ZIP**
2. Then follow Option A from step 1.

Installing also adds Start Menu entries: **"WebTrack - watch another item"** and **"WebTrack - uninstall"**.

To watch **another item later**: Start Menu → *WebTrack - watch another item* (or run `_INSTALL.bat` again) and paste the new link.

To **uninstall**: Start Menu → *WebTrack - uninstall* (or `_UNINSTALL.bat`). Everything is removed.

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

- `app\Setup-Wizard.ps1` — the install popup: takes a mint.ca link, validates it, grabs the product
  name from the page, adds it to `products.json`, registers the Task Scheduler job.
- `app\Watch-Stock.ps1` — the watcher. Every minute it downloads each product page and reads the
  `data-pwr-in-stock="True|False"` flag mint.ca embeds in every product page (the page's JSON-LD
  metadata always claims InStock — it lies — so it is ignored). Falls back to ADD TO CART button
  text if the layout ever changes, and recognizes queue/challenge pages as a "check now" event.
- Everything lives in `%LOCALAPPDATA%\WebTrack` after install: `products.json` (watch list),
  `state.json` (last known status), `watch.log` (history).
- The scheduled task **"WebTrack Stock Watcher"** runs `run-hidden.vbs` → hidden PowerShell,
  every minute while the user is logged in, surviving reboots. Change the cadence with
  `Install-Task.ps1 -IntervalMinutes 5`.
- Test the full alert (toast + alarm + browser): `Watch-Stock.ps1 -TestAlert`

## Limitations

- Alerts only fire while you're **logged in with the PC awake** — checks pause while the machine
  sleeps (buying needs you at the keyboard anyway).
- Windows **Do Not Disturb / Focus Assist** can mute the notification — the browser still opens.
- mint.ca only. Other retailers need their own detection logic.
