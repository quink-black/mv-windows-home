import CoreGraphics
import Foundation

struct DisplayInfo: Equatable {
    let displayID: CGDirectDisplayID
    let uuid: String
    /// Frame in the global coordinate system (origin at primary display's top-left in Cocoa).
    let frame: CGRect
    let isBuiltin: Bool
    let localizedName: String
}
