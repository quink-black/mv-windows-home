import Foundation
import OSLog

enum Log {
    private static let subsystem = "com.local.MoveWindowsHome"

    static let window = Logger(subsystem: subsystem, category: "window")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let permission = Logger(subsystem: subsystem, category: "permission")
    static let store = Logger(subsystem: subsystem, category: "store")
}
