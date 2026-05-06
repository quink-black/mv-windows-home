import Foundation

/// Persists the most recent window snapshot to
/// ~/Library/Application Support/MoveWindowsHome/snapshots.json.
///
/// Only a single snapshot is kept; each `save` overwrites the previous one to
/// avoid ambiguity between "restore to which move?".
final class SnapshotStore {
    private let fileURL: URL
    private let fm = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let dir = directory ?? SnapshotStore.defaultDirectory()
        self.fileURL = dir.appendingPathComponent("snapshots.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func save(_ file: SnapshotFile) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(file)
        let tmp = fileURL.appendingPathExtension("tmp")
        try data.write(to: tmp, options: .atomic)
        // rename is atomic on the same volume.
        if fm.fileExists(atPath: fileURL.path) {
            _ = try? fm.removeItem(at: fileURL)
        }
        try fm.moveItem(at: tmp, to: fileURL)
    }

    func load() -> SnapshotFile? {
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(SnapshotFile.self, from: data)
        } catch {
            Log.store.error("Failed to load snapshot: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func clear() {
        try? fm.removeItem(at: fileURL)
    }

    private func ensureDirectoryExists() throws {
        let dir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("MoveWindowsHome", isDirectory: true)
    }
}
