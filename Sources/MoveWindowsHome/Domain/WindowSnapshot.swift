import Foundation

struct WindowSnapshot: Codable, Equatable {
    let bundleID: String
    let pid: Int32
    let windowTitle: String?
    let cgWindowID: UInt32
    let originDisplayUUID: String
    /// Origin of the window relative to the top-left of the origin display.
    let frameInDisplay: CGRect
    let originalSize: CGSize
}

struct SnapshotFile: Codable, Equatable {
    /// Schema version for forward compatibility.
    let version: Int
    let createdAt: Date
    let windows: [WindowSnapshot]

    static let currentVersion = 1
}
