import AppKit
import CoreGraphics
import Foundation

final class DisplayService {
    var onConfigurationChanged: (() -> Void)?

    private var observer: NSObjectProtocol?

    deinit { stopObserving() }

    func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.display.info("Screen parameters changed")
            self?.onConfigurationChanged?()
        }
    }

    func stopObserving() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    func allDisplays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { DisplayService.makeInfo(from: $0) }
    }

    func builtinDisplay() -> DisplayInfo? {
        allDisplays().first(where: { $0.isBuiltin })
    }

    func externalDisplays() -> [DisplayInfo] {
        allDisplays().filter { !$0.isBuiltin }
    }

    /// Returns the display whose frame contains the given point (global coordinates).
    func display(containing point: CGPoint) -> DisplayInfo? {
        allDisplays().first(where: { $0.frame.contains(point) })
    }

    /// Looks up a currently-connected display by its stable UUID.
    func display(withUUID uuid: String) -> DisplayInfo? {
        allDisplays().first(where: { $0.uuid == uuid })
    }

    // MARK: - Helpers

    private static func makeInfo(from screen: NSScreen) -> DisplayInfo? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else { return nil }
        let displayID = CGDirectDisplayID(number.uint32Value)
        let uuid = Self.uuidString(for: displayID) ?? "display-\(displayID)"
        let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
        return DisplayInfo(
            displayID: displayID,
            uuid: uuid,
            frame: screen.frame,
            isBuiltin: isBuiltin,
            localizedName: screen.localizedName
        )
    }

    private static func uuidString(for displayID: CGDirectDisplayID) -> String? {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, cfUUID) as String?
    }
}
