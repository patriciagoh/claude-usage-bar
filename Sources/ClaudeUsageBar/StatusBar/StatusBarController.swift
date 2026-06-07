import AppKit

final class StatusBarController {

    private let statusItem: NSStatusItem
    private var lastData: UsageData?

    var onRetry: (() -> Void)?
    var onCookieChanged: (() -> Void)?
    var onCheckForUpdates: (() -> Void)?

    // WCAG AA 2.2 (4.5:1) compliant secondary grey.
    // Light menus (~#ECECEC bg): #595959 → 6.0:1. Dark menus (~#2E2E2E bg): #A1A1A1 → 4.6:1.
    private static let colorSecondary = NSColor(name: nil) { appearance in
        switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
        case .darkAqua: return NSColor(white: 0.63, alpha: 1)
        default:        return NSColor(white: 0.35, alpha: 1)
        }
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Claude"
    }

    // MARK: - Public

    func show(data: UsageData) {
        lastData = data
        updateTitle(data: data)
        rebuildMenu(data: data, error: nil)
    }

    func show(error: Error) {
        statusItem.button?.title = "Claude ⚠"
        rebuildMenu(data: lastData, error: error)
    }

    // MARK: - Title

    private func updateTitle(data: UsageData) {
        let pct = Int((data.session?.percentageUsed ?? 0.0) * 100)
        let resetDate = data.session?.resetDate ?? Date().addingTimeInterval(4 * 3600)
        let reset = countdownString(until: resetDate)
        statusItem.button?.title = "\(pct)% · \(reset)"
    }

    // MARK: - Menu

    private func rebuildMenu(data: UsageData?, error: Error?) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if let data {
            // Current session row — always shown, even when 0% used
            let sessionPct = data.session?.percentageUsed ?? 0.0
            let sessionResetDate = data.session?.resetDate ?? Date().addingTimeInterval(4 * 3600)
            addSection(to: menu, title: "Current session",
                       pct: sessionPct,
                       subtitle: "Resets in \(countdownString(until: sessionResetDate))")
            menu.addItem(.separator())

            // Weekly row
            addSection(to: menu, title: "Weekly",
                       pct: data.weekly.percentageUsed,
                       subtitle: "Resets \(resetLabel(data.weekly.resetDate))")
            menu.addItem(.separator())

            let staleStr = data.isStale ? " (stale)" : ""
            let updated = NSMenuItem()
            updated.attributedTitle = plain(
                "\(timestampString(data.fetchedAt))\(staleStr)", size: 11,
                color: Self.colorSecondary
            )
            updated.isEnabled = false
            menu.addItem(updated)

            let refresh = NSMenuItem(title: "Refresh", action: #selector(handleRetry), keyEquivalent: "r")
            refresh.target = self
            refresh.isEnabled = true
            menu.addItem(refresh)

        } else if let error {
            let msgText: String
            if let pe = error as? PollerError {
                switch pe {
                case .cookieNotFound:
                    msgText = "Session cookie not set.\nUse \"Set session cookie…\" below\nto paste it from DevTools."
                case .cookieExpired:
                    msgText = "Session expired.\nLog into claude.ai in your browser,\nthen click Retry."
                case .notConfigured:
                    msgText = "Not set up yet.\nUse \"Set session cookie…\" below."
                default:
                    msgText = "Could not refresh. Will retry in 5 min."
                }
            } else {
                msgText = "Could not refresh. Will retry in 5 min."
            }
            let msg = NSMenuItem()
            msg.attributedTitle = plain(msgText, size: 12, color: .labelColor)
            msg.isEnabled = false
            menu.addItem(msg)
            menu.addItem(.separator())

            let retry = NSMenuItem(title: "↺  Retry", action: #selector(handleRetry), keyEquivalent: "r")
            retry.target = self
            retry.isEnabled = true
            menu.addItem(retry)
        }

        menu.addItem(.separator())

        let checkUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(handleCheckForUpdates),
            keyEquivalent: ""
        )
        checkUpdates.target = self
        checkUpdates.isEnabled = true
        menu.addItem(checkUpdates)

        let setCookie = NSMenuItem(
            title: "Set session cookie…",
            action: #selector(handleSetCookie),
            keyEquivalent: ""
        )
        setCookie.target = self
        setCookie.isEnabled = true
        menu.addItem(setCookie)

        let openItem = NSMenuItem(
            title: "Open usage page",
            action: #selector(handleOpenUsagePage),
            keyEquivalent: ""
        )
        openItem.target = self
        openItem.isEnabled = true
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit ClaudeUsageBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func addSection(to menu: NSMenu, title: String, pct: Double, subtitle: String) {
        let headerItem = NSMenuItem()
        headerItem.view = makeLabelView(title)
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let barItem = NSMenuItem()
        barItem.view = makeProgressRow(pct: pct, subtitle: subtitle)
        menu.addItem(barItem)
    }

    private func makeLabelView(_ title: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.frame = NSRect(x: 16, y: 3, width: 228, height: 17)
        container.addSubview(label)
        return container
    }

    // MARK: - Actions

    @objc private func handleRetry() { onRetry?() }

    @objc private func handleCheckForUpdates() { onCheckForUpdates?() }

    @objc private func handleOpenUsagePage() {
        if let url = URL(string: "https://claude.ai/new#settings/usage") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func handleSetCookie() {
        let alert = NSAlert()
        alert.icon = NSImage()
        alert.messageText = "Set Claude Session Cookie"
        alert.informativeText = "Open claude.ai → DevTools (⌥⌘I) → Application → Cookies → claude.ai → find \"sessionKey\" → copy its value.\n\nSaved to your macOS Keychain. Never written to disk."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 80))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 80))
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 6)

        scrollView.documentView = textView
        alert.accessoryView = scrollView
        alert.window.initialFirstResponder = textView

        // Switch to regular policy so ⌘V and other keyboard shortcuts work in the dialog.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        NSApp.setActivationPolicy(.accessory)

        guard response == .alertFirstButtonReturn else { return }

        let value = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        try? KeychainManualCookieReader.save(value)
        CookieSourceStore.set(.keychain)
        onCookieChanged?()
    }

    // MARK: - Progress row view

    private func makeProgressRow(pct: Double, subtitle: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 34))

        let bar = ProgressBarView(frame: NSRect(x: 16, y: 20, width: 148, height: 6))
        bar.fraction = pct
        container.addSubview(bar)

        let pctLabel = NSTextField(labelWithString: "\(Int(pct * 100))% used")
        pctLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        pctLabel.textColor = .labelColor
        pctLabel.frame = NSRect(x: 172, y: 16, width: 80, height: 16)
        container.addSubview(pctLabel)

        let sub = NSTextField(labelWithString: subtitle)
        sub.font = NSFont.systemFont(ofSize: 11)
        sub.textColor = Self.colorSecondary
        sub.frame = NSRect(x: 16, y: 2, width: 240, height: 14)
        container.addSubview(sub)

        return container
    }

    // MARK: - Helpers

    private func plain(_ str: String, size: CGFloat, color: NSColor,
                       weight: NSFont.Weight = .regular) -> NSAttributedString {
        NSAttributedString(string: str, attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: size, weight: weight),
        ])
    }

    private func countdownString(until date: Date) -> String {
        let secs = max(0, date.timeIntervalSinceNow)
        let d = Int(secs) / 86400
        let h = (Int(secs) % 86400) / 3600
        let m = (Int(secs) % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func resetLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }

    private func timestampString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "Updated at \(f.string(from: date))"
    }
}

// MARK: - ProgressBarView

private final class ProgressBarView: NSView {
    var fraction: Double = 0

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3)
        NSColor.separatorColor.setFill()
        track.fill()

        let fillWidth = bounds.width * min(max(fraction, 0), 1)
        guard fillWidth > 0 else { return }
        let fill = NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: fillWidth, height: bounds.height),
            xRadius: 3, yRadius: 3
        )
        NSColor.labelColor.setFill()
        fill.fill()
    }
}

// MARK: - NSColor hex init

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
