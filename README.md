# ClaudeUsageBar

A native macOS menu bar app that shows your claude.ai weekly usage at a glance.

```
73% · 3d 14h
```

Built with Swift/AppKit, zero third-party dependencies, open source.

**For claude.ai subscribers only** (Free, Pro, Max, Teams). Does not apply to Anthropic API usage.

## What it shows

- **Usage %** — how much of your weekly Claude limit you've used
- **Reset countdown** — time until your usage counter resets
- Colour shifts to amber at 85%, red at 100%

## Requirements

- macOS 14 (Sonoma) or later
- Chrome or Safari, logged into claude.ai

## Install

Download `ClaudeUsageBar.zip` from the [latest release](../../releases/latest), unzip, and open the app.

macOS will show a Gatekeeper warning on first launch because the app is not notarized. To open it: right-click the app → **Open** → **Open** in the dialog. You only need to do this once.

## Build from source

```bash
git clone https://github.com/patriciagoh/ClaudeUsageBar
cd ClaudeUsageBar
make build
.build/arm64-apple-macosx/debug/ClaudeUsageBar
```

No Dock icon — it's menu-bar only.

## First launch

On first launch the menu bar will show a "not set up" state. Paste your session cookie once to get started:

1. Open `claude.ai` in Chrome or Safari
2. Open DevTools (⌥⌘I) → Application → Cookies → `https://claude.ai`
3. Find the cookie named `sessionKey` and copy its value
4. Click the menu bar item → **Set session cookie…** → paste → Save

The cookie is saved to your macOS Keychain. The app never reads your browser's cookie store without you explicitly providing the value here.

## What this app accesses

| Resource | Why | When |
|---|---|---|
| `~/Library/Application Support/Google/Chrome/Default/Cookies` | Read the claude.ai session cookie | At each 5-min refresh, read-only copy to temp file |
| `~/Library/Cookies/Cookies.binarycookies` | Read the claude.ai session cookie from Safari | At each 5-min refresh, if Chrome fails |
| macOS Keychain item `"Chrome Safe Storage"` | Decrypt the Chrome cookie (AES-128-CBC key) | At each 5-min refresh |
| macOS Keychain (`com.patriciagoh.ClaudeUsageBar`) | Store a manually-pasted session cookie | Only if you use "Set session cookie…" |
| `https://claude.ai` | Fetch usage percentage and reset date | Every 5 minutes, single HTTPS GET |

See [SECURITY.md](SECURITY.md) for the full threat model.

> **Note:** this app uses an unofficial, undocumented claude.ai internal API. It may stop working if Anthropic changes their API without notice.

## How it works

1. Reads your claude.ai session cookie from Chrome or Safari
2. Makes one HTTPS GET request to claude.ai's usage API
3. Displays the result in the menu bar
4. Repeats every 5 minutes

The session cookie is read at request time and never cached in memory between requests.

## License

MIT — see [LICENSE](LICENSE)
