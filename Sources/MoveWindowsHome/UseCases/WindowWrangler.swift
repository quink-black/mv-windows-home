import AppKit
import CoreGraphics
import Foundation

struct MoveResult {
    let moved: Int
    let failed: Int
    let snapshot: SnapshotFile?
}

struct RestoreResult {
    let restored: Int
    let skipped: Int
    let failed: Int
}

enum WranglerError: Error {
    case noBuiltinDisplay
    case noSnapshot
}

final class WindowWrangler {
    private let displayService: DisplayService
    private let windowService: WindowMoving
    private let snapshotStore: SnapshotStore

    init(displayService: DisplayService,
         windowService: WindowMoving,
         snapshotStore: SnapshotStore) {
        self.displayService = displayService
        self.windowService = windowService
        self.snapshotStore = snapshotStore
    }

    /// Moves every window currently located on an external display to the
    /// built-in display, recording a snapshot for later restoration.
    @discardableResult
    func moveAllToBuiltin() throws -> MoveResult {
        guard let builtin = displayService.builtinDisplay() else {
            throw WranglerError.noBuiltinDisplay
        }
        let displays = displayService.allDisplays()
        let externals = displays.filter { !$0.isBuiltin }
        guard !externals.isEmpty else {
            return MoveResult(moved: 0, failed: 0, snapshot: nil)
        }

        let windows = windowService.listVisibleAppWindows()
        var snapshots: [WindowSnapshot] = []
        var moved = 0
        var failed = 0

        for window in windows {
            guard let originDisplay = Self.display(for: window.bounds, among: displays),
                  !originDisplay.isBuiltin else { continue }

            let relativeOrigin = CGPoint(
                x: window.bounds.origin.x - originDisplay.frame.origin.x,
                y: window.bounds.origin.y - originDisplay.frame.origin.y
            )
            let relativeFrame = CGRect(origin: relativeOrigin, size: window.bounds.size)
            let bundleID = NSRunningApplication.bundleID(forPID: window.pid) ?? window.ownerName

            let snapshot = WindowSnapshot(
                bundleID: bundleID,
                pid: window.pid,
                windowTitle: window.title,
                cgWindowID: window.cgWindowID,
                originDisplayUUID: originDisplay.uuid,
                frameInDisplay: relativeFrame,
                originalSize: window.bounds.size
            )

            let target = Self.clampToDisplay(size: window.bounds.size, display: builtin)
            do {
                try windowService.move(
                    pid: window.pid,
                    cgWindowID: window.cgWindowID,
                    toTopLeft: target.origin,
                    size: target.size
                )
                snapshots.append(snapshot)
                moved += 1
            } catch {
                Log.window.error("Failed to move window pid=\(window.pid, privacy: .public) id=\(window.cgWindowID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                failed += 1
            }
        }

        guard !snapshots.isEmpty else {
            return MoveResult(moved: moved, failed: failed, snapshot: nil)
        }

        let file = SnapshotFile(
            version: SnapshotFile.currentVersion,
            createdAt: Date(),
            windows: snapshots
        )
        do {
            try snapshotStore.save(file)
        } catch {
            Log.store.error("Failed to save snapshot: \(error.localizedDescription, privacy: .public)")
        }
        return MoveResult(moved: moved, failed: failed, snapshot: file)
    }

    /// Restores each recorded window to its original position on the
    /// originally-connected display, provided that display is present again.
    @discardableResult
    func restoreToExternal() throws -> RestoreResult {
        guard let file = snapshotStore.load() else { throw WranglerError.noSnapshot }

        let windows = windowService.listVisibleAppWindows()
        // Index live windows by (bundleID, title) for fallback matching when
        // cgWindowID has rotated since the snapshot was taken.
        let byID = Dictionary(
            uniqueKeysWithValues: windows.map { ($0.cgWindowID, $0) }
        )

        var restored = 0
        var skipped = 0
        var failed = 0

        for snap in file.windows {
            guard let display = displayService.display(withUUID: snap.originDisplayUUID) else {
                skipped += 1
                continue
            }

            let target = CGRect(
                x: display.frame.origin.x + snap.frameInDisplay.origin.x,
                y: display.frame.origin.y + snap.frameInDisplay.origin.y,
                width: snap.originalSize.width,
                height: snap.originalSize.height
            )

            let live = byID[snap.cgWindowID] ?? Self.bestMatch(for: snap, in: windows)
            guard let target_ = live else {
                skipped += 1
                continue
            }

            do {
                try windowService.move(
                    pid: target_.pid,
                    cgWindowID: target_.cgWindowID,
                    toTopLeft: target.origin,
                    size: target.size
                )
                restored += 1
            } catch {
                Log.window.error("Failed to restore window pid=\(target_.pid, privacy: .public) id=\(target_.cgWindowID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                failed += 1
            }
        }
        return RestoreResult(restored: restored, skipped: skipped, failed: failed)
    }

    // MARK: - Geometry helpers

    static func display(for windowBounds: CGRect, among displays: [DisplayInfo]) -> DisplayInfo? {
        let center = CGPoint(x: windowBounds.midX, y: windowBounds.midY)
        if let hit = displays.first(where: { $0.frame.contains(center) }) { return hit }
        // Fall back to largest-area intersection for partially off-screen windows.
        return displays.max { a, b in
            a.frame.intersection(windowBounds).area < b.frame.intersection(windowBounds).area
        }
    }

    /// Clamps a proposed window rect to fit inside the target display. If the
    /// window is larger than the display, it is scaled to 90% of the display
    /// and centered.
    static func clampToDisplay(size: CGSize, display: DisplayInfo) -> CGRect {
        let frame = display.frame
        var w = size.width
        var h = size.height
        if w > frame.width || h > frame.height {
            w = frame.width * 0.9
            h = frame.height * 0.9
        }
        let x = frame.origin.x + (frame.width - w) / 2
        let y = frame.origin.y + (frame.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func bestMatch(for snap: WindowSnapshot, in live: [CGWindowInfo]) -> CGWindowInfo? {
        live.first(where: { window in
            let bundle = NSRunningApplication.bundleID(forPID: window.pid)
            return bundle == snap.bundleID && window.title == snap.windowTitle
        })
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
