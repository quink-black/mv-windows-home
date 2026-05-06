import XCTest
@testable import MoveWindowsHome

final class SnapshotStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("move-windows-home-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testRoundTrip() throws {
        let store = SnapshotStore(directory: tempDir)
        let file = SnapshotFile(
            version: SnapshotFile.currentVersion,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            windows: [
                WindowSnapshot(
                    bundleID: "com.apple.finder",
                    pid: 123,
                    windowTitle: "Downloads",
                    cgWindowID: 42,
                    originDisplayUUID: "UUID-A",
                    frameInDisplay: CGRect(x: 10, y: 20, width: 300, height: 200),
                    originalSize: CGSize(width: 300, height: 200)
                )
            ]
        )
        try store.save(file)
        let loaded = store.load()
        XCTAssertEqual(loaded, file)
    }

    func testLoadMissingReturnsNil() {
        let store = SnapshotStore(directory: tempDir)
        XCTAssertNil(store.load())
    }

    func testCorruptedFileReturnsNil() throws {
        let store = SnapshotStore(directory: tempDir)
        let url = tempDir.appendingPathComponent("snapshots.json")
        try "not json".data(using: .utf8)!.write(to: url)
        XCTAssertNil(store.load())
    }

    func testClearRemovesFile() throws {
        let store = SnapshotStore(directory: tempDir)
        let file = SnapshotFile(version: 1, createdAt: Date(), windows: [])
        try store.save(file)
        store.clear()
        XCTAssertNil(store.load())
    }
}
