import AppKit

final class MenuBarController: NSObject {
    private let wrangler: WindowWrangler
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var preferencesController: PreferencesWindowController?

    private let moveItem = NSMenuItem(
        title: "Move external-screen windows to built-in",
        action: #selector(moveToBuiltin),
        keyEquivalent: ""
    )
    private let restoreItem = NSMenuItem(
        title: "Restore windows to external display",
        action: #selector(restoreToExternal),
        keyEquivalent: ""
    )

    init(wrangler: WindowWrangler) {
        self.wrangler = wrangler
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupButton()
        setupMenu()
        refreshState()
    }

    func performMoveToBuiltin() { moveToBuiltin() }
    func performRestoreToExternal() { restoreToExternal() }

    func refreshState() {
        // Restore is only enabled when a snapshot file exists on disk.
        let hasSnapshot = SnapshotStore().load() != nil
        DispatchQueue.main.async {
            self.restoreItem.isEnabled = hasSnapshot
        }
    }

    // MARK: - Setup

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.on.rectangle.slash",
                accessibilityDescription: "MoveWindowsHome"
            )
            button.toolTip = "MoveWindowsHome"
        }
    }

    private func setupMenu() {
        moveItem.target = self
        restoreItem.target = self
        menu.addItem(moveItem)
        menu.addItem(restoreItem)
        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func moveToBuiltin() {
        do {
            let result = try wrangler.moveAllToBuiltin()
            notify(title: "Windows moved", body: "Moved \(result.moved), failed \(result.failed).")
            refreshState()
        } catch WranglerError.noBuiltinDisplay {
            notify(title: "No built-in display", body: "Cannot find the MacBook's built-in screen.")
        } catch {
            notify(title: "Move failed", body: error.localizedDescription)
        }
    }

    @objc private func restoreToExternal() {
        do {
            let result = try wrangler.restoreToExternal()
            notify(
                title: "Windows restored",
                body: "Restored \(result.restored), skipped \(result.skipped), failed \(result.failed)."
            )
        } catch WranglerError.noSnapshot {
            notify(title: "Nothing to restore", body: "No snapshot from a previous move was found.")
        } catch {
            notify(title: "Restore failed", body: error.localizedDescription)
        }
    }

    @objc private func openPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        preferencesController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func notify(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
