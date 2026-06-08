# ClaudeUsageBar

A native macOS menu bar app that shows your claude.ai usage at a glance.

```
73% · 3d 14h
```

Built with Swift/AppKit, no third-party dependencies except [Sparkle](https://sparkle-project.org/) for automatic updates.

**For claude.ai subscribers only** (Free, Pro, Max, Teams). Does not apply to Anthropic API usage.

## What it shows

- **Current session** — how much of your active session limit you've used, with time until reset
- **Weekly** — how much of your weekly limit you've used, with time until reset
- **Updated at** timestamp and a Refresh button to pull fresh data on demand

The title bar shows session usage at a glance. Colour shifts to amber at 85%, red at 100%.

## Requirements

- macOS 14 (Sonoma) or later
- A claude.ai account (Free, Pro, Max, or Teams)

## Install

1. Download `ClaudeUsageBar-x.x.x.dmg` from the [latest release](../../releases/latest)
2. Open the DMG and drag **ClaudeUsageBar** to your Applications folder
3. Open the app

### ⚠️ Gatekeeper warning on first launch

macOS will block the app with a message saying it "cannot be opened because the developer cannot be verified." This is expected — the app is open source but not notarized with Apple.

**To open it, do one of the following:**

- **Right-click** (or Control-click) the app in Finder → **Open** → click **Open** in the dialog that appears
- **Or:** go to **System Settings → Privacy & Security** → scroll down to the ClaudeUsageBar section → click **Open Anyway**

You only need to do this once. macOS remembers your choice.

## First launch

A setup window will appear asking for your Claude session cookie:

1. Open [claude.ai](https://claude.ai) in your browser
2. Open DevTools: **⌥⌘I** → **Application** tab → **Cookies** → `https://claude.ai`
3. Find the cookie named `sessionKey` and copy its value
4. Paste it into the setup window → **Connect**

The cookie is saved to your macOS Keychain. Once connected the app polls every 5 minutes automatically.

## Updating

The app checks for updates automatically via Sparkle. When a new version is available you'll see an in-app prompt — click **Update** and it handles the rest.

## Build from source

```bash
git clone https://github.com/patriciagoh/claude-usage-bar
cd claude-usage-bar
make build
open .build/debug/ClaudeUsageBar.app
```

No Dock icon — it's menu-bar only.

## What this app accesses

| Resource | Why | When |
|---|---|---|
| macOS Keychain (`com.patriciagoh.ClaudeUsageBar`) | Store and read your session cookie | Read at each refresh; written only when you paste a new cookie |
| `https://claude.ai/api/organizations` | Discover your organisation ID | Once, on first successful connection |
| `https://claude.ai/api/organizations/{id}/usage` | Fetch usage percentage and reset date | Every 5 minutes |

The app does not read your browser's cookie database, access Chrome or Safari files, or send data anywhere other than claude.ai. See [SECURITY.md](SECURITY.md) for the full threat model.

> **Note:** this app uses an unofficial, undocumented claude.ai internal API. It may stop working if Anthropic changes their API without notice.

## License

MIT — see [LICENSE](LICENSE)
