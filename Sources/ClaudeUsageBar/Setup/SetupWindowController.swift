import AppKit

final class SetupWindowController: NSWindowController {

    var onSetupComplete: (() -> Void)?

    private let viewModel = SetupViewModel()

    // UI elements
    private var chromeRadio: NSButton!
    private var safariRadio: NSButton!
    private var keychainRadio: NSButton!
    private var pasteField: NSTextView!
    private var pasteScroll: NSScrollView!
    private var browserNote: NSTextField!
    private var connectButton: NSButton!
    private var statusLabel: NSTextField!

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Up ClaudeUsageBar"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
        viewModel.onStateChange = { [weak self] state in
            self?.applyState(state)
        }
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - UI construction

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "ClaudeUsageBar")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.frame = NSRect(x: 24, y: 294, width: 392, height: 24)
        content.addSubview(title)

        let subtitle = NSTextField(
            labelWithString: "Shows your claude.ai weekly usage in the menu bar."
        )
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 24, y: 270, width: 392, height: 18)
        content.addSubview(subtitle)

        let divider = NSBox()
        divider.boxType = .separator
        divider.frame = NSRect(x: 0, y: 254, width: 440, height: 1)
        content.addSubview(divider)

        let sourceLabel = NSTextField(labelWithString: "Connect using:")
        sourceLabel.font = .systemFont(ofSize: 13, weight: .medium)
        sourceLabel.frame = NSRect(x: 24, y: 224, width: 392, height: 18)
        content.addSubview(sourceLabel)

        chromeRadio = radio("Chrome", tag: 0, x: 24, y: 198)
        safariRadio = radio("Safari", tag: 1, x: 120, y: 198)
        keychainRadio = radio("Paste manually", tag: 2, x: 210, y: 198, width: 140)
        keychainRadio.state = .on
        [chromeRadio, safariRadio, keychainRadio].forEach { content.addSubview($0!) }

        browserNote = NSTextField(labelWithString:
            "Reads your Chrome cookie database and the \"Chrome Safe Storage\" Keychain item. Allow access when prompted."
        )
        browserNote.font = .systemFont(ofSize: 12)
        browserNote.textColor = .secondaryLabelColor
        browserNote.isHidden = true
        browserNote.frame = NSRect(x: 24, y: 100, width: 392, height: 80)
        browserNote.maximumNumberOfLines = 4
        content.addSubview(browserNote)

        pasteScroll = NSScrollView(frame: NSRect(x: 24, y: 100, width: 392, height: 80))
        pasteScroll.hasVerticalScroller = true
        pasteScroll.borderType = .bezelBorder

        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 392, height: 80))
        tv.isEditable = true
        tv.isRichText = false
        tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.textContainerInset = NSSize(width: 4, height: 6)
        tv.delegate = self
        pasteField = tv
        pasteScroll.documentView = tv
        content.addSubview(pasteScroll)

        let instructions = NSTextField(labelWithString:
            "Open claude.ai → DevTools (⌥⌘I) → Application → Cookies → claude.ai\n" +
            "→ find \"sessionKey\" → copy its value → paste above."
        )
        instructions.font = .systemFont(ofSize: 11)
        instructions.textColor = .secondaryLabelColor
        instructions.maximumNumberOfLines = 3
        instructions.frame = NSRect(x: 24, y: 60, width: 392, height: 36)
        content.addSubview(instructions)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 3
        statusLabel.cell?.wraps = true
        statusLabel.frame = NSRect(x: 24, y: 12, width: 300, height: 42)
        content.addSubview(statusLabel)

        connectButton = NSButton(
            title: "Connect",
            target: self,
            action: #selector(handleConnect)
        )
        connectButton.bezelStyle = .rounded
        connectButton.keyEquivalent = "\r"
        connectButton.frame = NSRect(x: 336, y: 16, width: 88, height: 32)
        connectButton.isEnabled = viewModel.canConnect
        content.addSubview(connectButton)
    }

    private func radio(_ title: String, tag: Int, x: CGFloat, y: CGFloat, width: CGFloat = 100) -> NSButton {
        let b = NSButton(radioButtonWithTitle: title, target: self, action: #selector(handleSourceChange(_:)))
        b.tag = tag
        b.frame = NSRect(x: x, y: y, width: width, height: 20)
        return b
    }

    // MARK: - Actions

    @objc private func handleSourceChange(_ sender: NSButton) {
        let source: CookieSource = sender.tag == 0 ? .chrome : sender.tag == 1 ? .safari : .keychain
        viewModel.selectedSource = source
        let isPaste = source == .keychain
        pasteScroll.isHidden = !isPaste
        browserNote.isHidden = isPaste
        switch source {
        case .chrome:
            browserNote.stringValue = "Reads your Chrome cookie database and the \"Chrome Safe Storage\" Keychain item. Allow access when prompted."
        case .safari:
            browserNote.stringValue = "Reads ~/Library/Cookies/Cookies.binarycookies. Grant Full Disk Access in System Settings → Privacy & Security if this fails."
        case .keychain:
            break
        }
        connectButton.isEnabled = viewModel.canConnect
    }

    @objc private func handleConnect() {
        NSApp.activate(ignoringOtherApps: true)
        viewModel.pastedCookie = pasteField.string
        connectButton.isEnabled = false
        statusLabel.stringValue = "Connecting…"
        Task { await viewModel.connect() }
    }

    // MARK: - State

    private func applyState(_ state: SetupState) {
        switch state {
        case .idle:
            statusLabel.stringValue = ""
            connectButton.isEnabled = viewModel.canConnect
        case .connecting:
            statusLabel.stringValue = "Connecting…"
            connectButton.isEnabled = false
        case .success(let pct):
            statusLabel.stringValue = "Connected — \(Int(pct * 100))% used this week ✓"
            statusLabel.textColor = .systemGreen
            connectButton.isEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.close()
                self?.onSetupComplete?()
            }
        case .failure(let msg):
            statusLabel.stringValue = msg
            statusLabel.textColor = .systemRed
            connectButton.isEnabled = true
        }
    }
}

// MARK: - NSTextViewDelegate

extension SetupWindowController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        viewModel.pastedCookie = pasteField.string
        connectButton.isEnabled = viewModel.canConnect
    }
}
