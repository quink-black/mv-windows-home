import XCTest
@testable import MoveWindowsHome

private final class FakeWindowService: WindowMoving {
    var windows: [CGWindowInfo] = []
    private(set) var moveCalls: [(pid: Int32, id: UInt32, origin: CGPoint, size: CGSize)] = []
    var errorForID: UInt32?

    func listVisibleAppWindows() -> [CGWindowInfo] { windows }

    func move(pid: Int32, cgWindowID: UInt32, toTopLeft topLeft: CGPoint, size: CGSize) throws {
        if errorForID == cgWindowID {
            throw WindowServiceError.windowNotFound(cgWindowID: cgWindowID)
        }
        moveCalls.append((pid, cgWindowID, topLeft, size))
    }
}

final class WindowWranglerGeometryTests: XCTestCase {
    private let builtin = DisplayInfo(
        displayID: 1,
        uuid: "UUID-BUILTIN",
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        isBuiltin: true,
        localizedName: "Built-in"
    )
    private let external = DisplayInfo(
        displayID: 2,
        uuid: "UUID-EXT",
        frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440),
        isBuiltin: false,
        localizedName: "Dell"
    )

    func testDisplayForWindowPicksByCenter() {
        let window = CGRect(x: 1500, y: 100, width: 800, height: 600)
        let display = WindowWrangler.display(for: window, among: [builtin, external])
        XCTAssertEqual(display?.uuid, "UUID-EXT")
    }

    func testClampKeepsSizeWhenFits() {
        let rect = WindowWrangler.clampToDisplay(
            size: CGSize(width: 800, height: 600),
            display: builtin
        )
        XCTAssertEqual(rect.size, CGSize(width: 800, height: 600))
        XCTAssertEqual(rect.origin.x, (1440 - 800) / 2)
        XCTAssertEqual(rect.origin.y, (900 - 600) / 2)
    }

    func testClampShrinksWhenWindowLargerThanDisplay() {
        let rect = WindowWrangler.clampToDisplay(
            size: CGSize(width: 3000, height: 2000),
            display: builtin
        )
        XCTAssertEqual(rect.size.width, 1440 * 0.9, accuracy: 0.01)
        XCTAssertEqual(rect.size.height, 900 * 0.9, accuracy: 0.01)
    }
}
