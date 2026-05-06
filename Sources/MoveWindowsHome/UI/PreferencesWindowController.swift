import AppKit

/// Minimal preferences window. Shows accessibility status and provides a
/// shortcut reminder; full shortcut recording UI is deferred to a later
/// iteration since defaults already cover the primary use case.
final class PreferencesWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MoveWindowsHome Preferences"
        window.center()
        self.init(window: window)
        window.contentView = makeContentView()
    }

    private func makeContentView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 220))

        let title = NSTextField(labelWithString: "Keyboard shortcuts")
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 20, y: 180, width: 380, height: 20)
        container.addSubview(title)

        let moveLabel = NSTextField(labelWithString: "Move to built-in:   Ctrl + Option + Cmd + H")
        moveLabel.frame = NSRect(x: 20, y: 155, width: 380, height: 18)
        container.addSubview(moveLabel)

        let restoreLabel = NSTextField(labelWithString: "Restore to external: Ctrl + Option + Cmd + R")
        restoreLabel.frame = NSRect(x: 20, y: 133, width: 380, height: 18)
        container.addSubview(restoreLabel)

        let permTitle = NSTextField(labelWithString: "Accessibility")
        permTitle.font = .boldSystemFont(ofSize: 13)
        permTitle.frame = NSRect(x: 20, y: 90, width: 380, height: 20)
        container.addSubview(permTitle)

        let status = NSTextField(labelWithString: AXIsProcessTrusted()
            ? "Granted. Window moves are enabled."
            : "Not granted. Enable in System Settings to move windows.")
        status.frame = NSRect(x: 20, y: 65, width: 380, height: 18)
        container.addSubview(status)

        let button = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openSettings))
        button.frame = NSRect(x: 20, y: 20, width: 260, height: 28)
        button.bezelStyle = .rounded
        container.addSubview(button)

        return container
    }

    @objc private func openSettings() {
        PermissionGuard().openAccessibilitySettings()
    }
}
