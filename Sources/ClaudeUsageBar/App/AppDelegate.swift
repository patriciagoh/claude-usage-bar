import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBar: StatusBarController!
    private var poller: UsagePoller!
    private var setupWindowController: SetupWindowController?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupEditMenu()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        statusBar = StatusBarController()
        statusBar.onCheckForUpdates = { [weak self] in
            self?.updaterController?.checkForUpdates(nil)
        }

        if isSetupComplete {
            startPoller()
        } else {
            showSetupWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        poller?.stop()
    }

    // MARK: - Setup detection

    private var isSetupComplete: Bool {
        (try? KeychainManualCookieReader().read()) != nil
    }

    private func showSetupWindow() {
        let controller = SetupWindowController()
        controller.onSetupComplete = { [weak self] in
            self?.setupWindowController = nil
            self?.startPoller()
        }
        setupWindowController = controller
        controller.showWindow(nil)
    }

    // MARK: - Poller

    private func startPoller() {
        poller?.stop()
        poller = UsagePoller(
            cookieReader: CookieSourceStore.makeCookieReader(),
            apiClient: ClaudeAPIClient(),
            orgDiscovery: OrgDiscoveryClient()
        )
        poller.onData = { [weak self] data in
            self?.statusBar.show(data: data)
        }
        poller.onError = { [weak self] error in
            self?.statusBar.show(error: error)
        }
        statusBar.onRetry = { [weak self] in
            self?.poller.refreshNow()
        }
        statusBar.onCookieChanged = { [weak self] in
            self?.poller?.stop()
            self?.startPoller()
        }
        poller.start()
    }

    // MARK: - Edit menu (needed for ⌘V in dialogs)

    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut",        action: #selector(NSText.cut(_:)),       keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy",       action: #selector(NSText.copy(_:)),      keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste",      action: #selector(NSText.paste(_:)),     keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }
}
