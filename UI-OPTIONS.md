# WebTrack — UI / platform options & decision

**The hard constraint:** we do **not** want to pay for code-signing. On macOS,
*any* app downloaded from the internet is blocked by Gatekeeper unless it's
signed + notarized with a paid **Apple Developer ID ($99/yr)**. There is **no
free path** to a clean "just double-click and it works" experience on Mac — this
is true for every compiled framework equally (it's Apple's rule, not a framework
limitation). So the moment "works cleanly on a Mac" is required, the answer is
"$99/yr, pick any framework." If we won't pay that, **we are Windows-only** — and
that's fine, because Windows *does* have free, no-signing, no-compile ways to
build a genuinely nice UI.

## The options

| Option | Tech | UI look | Win | Mac | Needs compile/build | Runs free, no signing? | Notes |
|---|---|---|:--:|:--:|:--:|---|---|
| **Current — WinForms** | PowerShell script | Dated (2002 widgets) | ✅ | ❌ | No | ✅ Windows | What we ship now. Works, just looks old. |
| **HTA** | one `.hta` = HTML/CSS/JS | Clean ~2016 web page | ✅ | ❌ | No | ✅ Windows (⚠ `.hta` can trip some antivirus) | "A webpage that runs as an app," full system access via built-in `mshta.exe`. |
| **WebView2** (script-hosted) | HTML/CSS/JS via Edge engine, launched by our `.bat`/PowerShell | Modern, animations, dark mode | ✅ | ❌ | No | ✅ Windows (runtime preinstalled on Win 11) | **Best free "pretty" option.** Real modern web UI, still no compile, keeps the trusted `.bat` launcher. |
| **Tauri** | Rust + system webview | Modern web | ✅ | ✅ | Yes (Rust/Node) | ❌ Mac needs $99/yr; Win shows a click-past warning | Lightweight (~3–10 MB). Great *if* paying to sign. |
| **Wails** | Go + system webview | Modern web | ✅ | ✅ | Yes (Go) | ❌ same as Tauri | Same idea, Go instead of Rust. |
| **Flutter** | Dart, own render engine | **Best / most "fun"** | ✅ | ✅ | Yes (Flutter SDK) | ❌ Mac needs $99/yr | The one we'd *ideally* use — prettiest, one codebase, Win + Mac + mobile. Blocked only by the signing cost. |
| **Avalonia / .NET MAUI** | C# / XAML | Modern native | ✅ | ✅ | Yes (.NET) | ❌ Mac needs $99/yr | Good if we ever go C#. |
| **Electron** | JS + bundled Chromium | Modern web | ✅ | ✅ | Yes | ❌ + heavy (100 MB+) | Rejected up front — too heavy for this. |

**Applies to every row:** the *background watching* (check the page every 90 s,
24/7, even when nothing's on screen) is an OS-level job — Windows Task Scheduler,
macOS launchd. No UI framework changes that; it's separate plumbing per OS.

## What's actually left, given "no paid signing"

Everything with a ✅ in the last column — and they're all **Windows-only**:

1. **WebView2** — modern, animated HTML UI, no compile, no signing. *Recommended.*
2. **HTA** — simplest; a single HTML file. Slightly older look, and `.hta` can
   occasionally get flagged by antivirus.
3. **Current WinForms** — already works, just dated.

The compiled options (Flutter, Tauri, Wails, Avalonia) are **not broken** — they
run fine and look great — they're simply ruled out *by our own rule* of not
paying Apple's $99/yr, because that's the only thing standing between them and a
clean Mac launch.

## Recommendation

**Short term (free, today): upgrade the popup to a WebView2 HTML UI.** We keep the
exact delivery we have — the trusted `.bat` launcher and zero-install ZIP — but
the `.bat` opens a modern HTML/CSS window (cards, our colors, dark mode, proper
Ctrl+A) instead of the dated WinForms box. No compile, no signing, no new cost,
Windows-only (which is where we are anyway).

**If Mac ever becomes a real requirement: pay the $99/yr and build it in Flutter.**
That's the "ideal" version — genuinely nice, genuinely cross-platform — and the
$99/yr is unavoidable no matter which framework we'd pick.

**Do nothing:** the current WinForms popup works fine (Ctrl+A now fixed, cleaner
font/button). Totally acceptable to just leave it.
