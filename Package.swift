// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoveWindowsHome",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MoveWindowsHome", targets: ["MoveWindowsHome"])
    ],
    targets: [
        .executableTarget(
            name: "MoveWindowsHome",
            dependencies: ["AXBridging"],
            path: "Sources/MoveWindowsHome",
            exclude: ["AXBridging"],
            resources: []
        ),
        .target(
            name: "AXBridging",
            path: "Sources/MoveWindowsHome/AXBridging",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "MoveWindowsHomeTests",
            dependencies: ["MoveWindowsHome"],
            path: "Tests/MoveWindowsHomeTests"
        )
    ]
)
