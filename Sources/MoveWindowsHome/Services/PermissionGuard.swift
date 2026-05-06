import AppKit
import ApplicationServices
import Foundation

final class PermissionGuard {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Checks accessibility trust; if missing, triggers the system prompt and
    /// optionally shows an explanatory alert with a button to open the
    /// relevant System Settings pane.
    func promptIfNeeded() {
        let options: CFDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if trusted {
            Log.permission.info("Accessibility already trusted")
            return
        }
        Log.permission.info("Accessibility not trusted; user prompted")
        showGuidanceAlert()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func showGuidanceAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility permission required"
            alert.informativeText = """
                MoveWindowsHome needs Accessibility access to move windows.

                Open System Settings -> Privacy & Security -> Accessibility and \
                enable MoveWindowsHome, then relaunch the app.
                """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            }
        }
    }
}
