# Why WebTrack is built the "weird" way (and how it dodges code-signing)

WebTrack looks like it should be a normal little desktop app. It isn't — it's a
bundle of **scripts** (PowerShell + a batch launcher + an HTML page). That was a
deliberate choice to **never ship a file that needs a code-signing certificate**.
Here's the reasoning, because it's genuinely non-obvious.

## The problem: signing tax

The moment you ship a **compiled program** — a Windows `.exe` or a Mac `.app`
(this includes anything built with Electron, Tauri, Flutter, .NET, etc.) — the
operating system treats it as untrusted until it's cryptographically **signed**:

| OS | What an *unsigned* compiled app does | Cost to make it "just work" |
|----|--------------------------------------|-----------------------------|
| **Windows** | Runs, but SmartScreen shows a scary blue "Windows protected your PC" warning | An OV/EV code-signing cert (~$100–400/yr, hardware token) — or Azure Trusted Signing (~$10/mo) |
| **macOS** | **Blocked** by Gatekeeper ("damaged / unidentified developer"); only opens after digging through System Settings | An Apple Developer ID — **$99/yr** — plus notarization |

For a free hobby tool you hand to one non-technical person, paying an annual
"tax" to Apple/a CA just so a coin watcher doesn't look like malware is absurd.

## The workaround: don't compile anything

Signing only applies to **programs**. It does **not** apply to **scripts** run by
components that are *already* trusted and signed by Microsoft. So WebTrack is made
entirely of things Windows already trusts:

- **The UI** is a normal web page — but instead of bundling a browser (Electron,
  ~100 MB) or a WebView SDK (extra DLLs), WebTrack starts a tiny local web server
  and opens the page in the **browser the user already has** (Edge/Chrome), which
  Microsoft/Google already signed. We just borrow it, in a clean app-style window.
- **The launcher** is a `.bat` file. Batch scripts aren't gated like downloaded
  `.exe`s, so double-clicking one doesn't trip SmartScreen the way an unsigned
  program would.
- **The work** is done by **PowerShell** — already installed and signed by
  Microsoft. It does the page checks, writes the config, shows notifications.
- **The "always running" part** is **Windows Task Scheduler** — an OS feature, no
  binary of ours involved.
- **The alerts** are native **Windows notifications**, raised through a registered
  app identity — again, no signed binary of ours.

Net result: nothing WebTrack ships is a compiled program, so **there is nothing to
sign**, no CA, no Apple account, no SmartScreen wall, no Gatekeeper block. The zip
is ~24 KB and runs on a fresh Windows machine with zero setup.

## The honest catch: this trick is Windows-only

The escape hatch above works because Windows lets trusted, pre-signed components
(PowerShell, Task Scheduler, the browser) run our scripts freely.

**macOS has no equivalent free path.** There, even a plain shell script downloaded
from the internet gets quarantined by Gatekeeper, and a compiled cross-platform app
(Flutter/Tauri/etc.) would still need the **$99/yr Apple Developer ID** to run
cleanly on someone else's Mac. So:

- **Free + "just works" is possible on Windows only.**
- A clean **Mac** version would cost **$99/yr** no matter which framework we picked
  — that's Apple's rule, not a limitation of any tool.

We chose to stay Windows-only and pay nothing, rather than build a fancier
cross-platform app and owe Apple every year. If a Mac version is ever needed, the
plan is Flutter + the paid Apple signing (see `UI-OPTIONS.md` for the full
comparison).

## TL;DR

We "beat the system" by **never shipping a binary that needs a signature** —
delivering a modern-looking app out of scripts plus components Windows already
trusts (PowerShell, Task Scheduler, the user's own browser). That buys a free,
warning-free, zero-install experience on Windows. The same move is impossible for
free on macOS, which is the one place the signing tax is unavoidable.
