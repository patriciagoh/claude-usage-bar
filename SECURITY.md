# Security

## What this app accesses

| Resource | Why | When |
|---|---|---|
| macOS Keychain item `com.patriciagoh.ClaudeUsageBar / manual-session-cookie` | Store the session cookie you paste manually | Only when you use "Set session cookie…" in the menu; read at each 5-min refresh |
| `https://claude.ai` | Fetch your usage percentage and reset date | Every 5 minutes, single HTTPS GET |

By default the app does **not** read your browser's cookie store. If you explicitly choose Chrome or Safari mode during setup, it will read that browser's cookie store to obtain your session automatically (Chrome: reads the cookie database and the "Chrome Safe Storage" Keychain item; Safari: reads ~/Library/Cookies/Cookies.binarycookies). In keychain (manual paste) mode, no browser files are accessed.

## What this app does NOT do

- Read your browser's cookie database or access browser Keychain items **unless** you explicitly choose Chrome or Safari mode during setup
- Cache the session cookie in memory between requests
- Write the session cookie anywhere except the Keychain item you explicitly create
- Send data to any server other than claude.ai
- Include analytics, telemetry, or crash reporting
- Log request headers or API responses
- Cache authenticated API responses to disk (uses an ephemeral URLSession)

## Keychain items

The app writes exactly one Keychain item (`manual-session-cookie` under `com.patriciagoh.ClaudeUsageBar`) and only when you explicitly use "Set session cookie…" in the menu or complete the setup flow. It reads that same item at each polling cycle. In Chrome mode, it additionally reads the "Chrome Safe Storage" Keychain item (owned by Chrome) to decrypt the cookie database — this requires a one-time user approval prompt from macOS.

## Threat model

The primary threat is a local attacker with filesystem access. If someone can run arbitrary code as your user, they could read the same browser files this app reads. This app does not make that threat worse — it does not persist the session cookie anywhere beyond what your browser already stores.

The secondary threat is a compromised version of this app. Because it is open source and zero-dependency, you can audit every line. Building from source is more trustworthy than running a pre-built binary.

> **Unofficial API notice:** this app uses an undocumented claude.ai internal endpoint. It is not endorsed by Anthropic and may break without warning.

## Reporting a vulnerability

Open a GitHub issue labelled `security`. Do not include working exploit code in a public issue — describe the vulnerability and we will follow up privately.
