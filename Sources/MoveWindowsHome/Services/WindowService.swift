import AppKit
import ApplicationServices
import AXBridging
import CoreGraphics
import Foundation

struct CGWindowInfo {
    let cgWindowID: UInt32
    let pid: Int32
    let ownerName: String
    let title: String?
    let bounds: CGRect
    let layer: Int
}

enum WindowServiceError: Error {
    case applicationNotAccessible(pid: Int32)
    case windowNotFound(cgWindowID: UInt32)
    case axCallFailed(AXError)
}

protocol WindowMoving: AnyObject {
    func listVisibleAppWindows() -> [CGWindowInfo]
    func move(pid: Int32, cgWindowID: UInt32, toTopLeft topLeft: CGPoint, size: CGSize) throws
}

final class WindowService: WindowMoving {
    /// Enumerates all on-screen windows at layer 0 (regular app windows),
    /// skipping Dock, menu bar, wallpaper, IME candidate windows, etc.
    func listVisibleAppWindows() -> [CGWindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let array = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dict in
            guard
                let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                let pidNum = dict[kCGWindowOwnerPID as String] as? Int32,
                let windowID = dict[kCGWindowNumber as String] as? UInt32,
                let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat],
                let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }

            // Skip zero-sized ghost windows.
            if bounds.width < 1 || bounds.height < 1 { return nil }

            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? ""
            let title = dict[kCGWindowName as String] as? String

            return CGWindowInfo(
                cgWindowID: windowID,
                pid: pidNum,
                ownerName: ownerName,
                title: title?.isEmpty == true ? nil : title,
                bounds: bounds,
                layer: layer
            )
        }
    }

    /// Moves a window identified by (pid, cgWindowID) to the given top-left
    /// in global (CG) coordinates and resizes it to `size`. Position is set
    /// before size to reduce flicker when the new origin is valid.
    func move(pid: Int32, cgWindowID: UInt32, toTopLeft topLeft: CGPoint, size: CGSize) throws {
        let appElement = AXUIElementCreateApplication(pid)

        var windowsValue: CFTypeRef?
        let listErr = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard listErr == .success, let windows = windowsValue as? [AXUIElement] else {
            throw WindowServiceError.applicationNotAccessible(pid: pid)
        }

        guard let axWindow = windows.first(where: { Self.cgWindowID(for: $0) == cgWindowID }) else {
            throw WindowServiceError.windowNotFound(cgWindowID: cgWindowID)
        }

        try Self.setPosition(axWindow, to: topLeft)
        try Self.setSize(axWindow, to: size)
    }

    // MARK: - AX helpers

    private static func cgWindowID(for element: AXUIElement) -> UInt32? {
        var windowID: CGWindowID = 0
        let err = _AXUIElementGetWindow(element, &windowID)
        return err == .success ? UInt32(windowID) : nil
    }

    private static func setPosition(_ element: AXUIElement, to point: CGPoint) throws {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else {
            throw WindowServiceError.axCallFailed(.failure)
        }
        let err = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        if err != .success { throw WindowServiceError.axCallFailed(err) }
    }

    private static func setSize(_ element: AXUIElement, to size: CGSize) throws {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else {
            throw WindowServiceError.axCallFailed(.failure)
        }
        let err = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        if err != .success { throw WindowServiceError.axCallFailed(err) }
    }
}

extension NSRunningApplication {
    static func bundleID(forPID pid: Int32) -> String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }
}
